#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# nixdots Installer v1.0
# Instalación automatizada de NixOS multi-host (laptop / amd / omen)
#
# Uso desde la ISO de NixOS:
#   bash <(curl -sL https://raw.githubusercontent.com/Ricky06202/nixdots/main/install.sh)
#   o local: bash install.sh
# ============================================================================

# ── Colores ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

# ── Configuración ────────────────────────────────────────────────────────────
REPO_URL="https://github.com/Ricky06202/nixdots.git"
REPO_DIR="/tmp/nixdots"
MNT="/mnt"
LOG="/tmp/nixdots-install.log"

# Hosts disponibles y su swap (GB)
declare -A HOST_SWAP=(
    [laptop]=8
    [amd]=4
    [omen]=4
)

# ── Utilidades ───────────────────────────────────────────────────────────────

log() { echo "[$(date +%H:%M:%S)] $*" >> "$LOG"; }
info()    { echo -e "${BLUE}▸${NC} $1"; log "INFO: $1"; }
success() { echo -e "${GREEN}✔${NC} $1"; log "OK: $1"; }
warn()    { echo -e "${YELLOW}⚠${NC} $1"; log "WARN: $1"; }
error()   { echo -e "${RED}✖${NC} $1"; log "ERROR: $1"; }
die()     { error "$1"; exit 1; }

banner() {
    clear
    cat <<'EOF'

  ╔═══════════════════════════════════════════════════════╗
  ║           nixdots installer — NixOS multi-host        ║
  ║   laptop · amd · omen                                ║
  ╚═══════════════════════════════════════════════════════╝

EOF
}

confirm() {
    local msg="${1:-¿Continuar?}"
    echo -en "${YELLOW}  ↳ ${msg} [s/N]: ${NC}"
    read -r reply
    [[ "$reply" =~ ^[sS]y?$ ]] || [[ "$reply" =~ ^[sS]$ ]]
}

divider() { echo -e "${CYAN}─────────────────────────────────────────────────────────${NC}"; }

# ── Fase 0: Verificaciones previas ───────────────────────────────────────────

preflight() {
    info "Verificando entorno..."

    [ "$(id -u)" -eq 0 ] || die "Ejecuta como root: sudo bash install.sh"

    command -v parted >/dev/null || die "Falta 'parted'. ¿Estás en la ISO de NixOS?"
    command -v btrfs >/dev/null || die "Falta 'btrfs-progs'. ¿Estás en la ISO de NixOS?"
    command -v nixos-install >/dev/null || die "Falta 'nixos-install'. ¿Estás en la ISO de NixOS?"

    info "Verificando conexión a internet..."
    if ping -c1 -W3 github.com &>/dev/null; then
        success "Internet OK"
    else
        die "Sin internet. Conéctate primero (nmtui, wpa_supplicant, etc.)"
    fi

    echo "$$" > /tmp/.nixdots-install.pid
    log "=== Installer iniciado (PID $$) ==="
}

# ── Fase 1: Selección de host ────────────────────────────────────────────────

select_host() {
    banner
    echo -e "  ${BOLD}¿Qué máquina vas a instalar?${NC}\n"

    local hosts=($(echo "${!HOST_SWAP[@]}" | tr ' ' '\n' | sort))
    for i in "${!hosts[@]}"; do
        local h="${hosts[$i]}"
        local swap="${HOST_SWAP[$h]}"
        echo -e "    $((i+1)))  ${BOLD}${h}${NC}  (swap: ${swap}GB)"
    done
    echo

    while true; do
        echo -en "  Selecciona (1-${#hosts[@]}): "
        read -r choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#hosts[@]} )); then
            HOST="${hosts[$((choice-1))]}"
            SWAP_GB="${HOST_SWAP[$HOST]}"
            success "Host: ${HOST} · swap: ${SWAP_GB}GB"
            return 0
        fi
        error "Opción inválida"
    done
}

# ── Fase 2: Selección de disco ───────────────────────────────────────────────

scan_disks() {
    divider
    echo -e "\n  ${BOLD}Discos detectados:${NC}\n"
    printf "  ${BOLD}%-4s  %-18s  %-8s  %s${NC}\n" "#" "NOMBRE" "TAMAÑO" "MODELO / TIPO"
    divider

    DISKS=()
    local i=1
    while IFS= read -r line; do
        local name size model path type
        name=$(echo "$line" | awk '{print $1}')
        size=$(echo "$line" | awk '{print $2}')
        model=$(echo "$line" | awk '{$1=$2=""; print $0}' | xargs)
        path="/dev/${name}"

        # Detectar tipo
        if [[ "$name" == nvme* ]]; then
            type="NVMe SSD"
        elif [[ "$name" == sd* ]]; then
            # Rotacional o SSD?
            if [ -f "/sys/block/${name}/queue/rotational" ]; then
                local rot
                rot=$(cat "/sys/block/${name}/queue/rotational")
                [ "$rot" = "1" ] && type="HDD" || type="SATA SSD"
            else
                type="SATA"
            fi
        elif [[ "$name" == vd* ]]; then
            type="Virtual"
        else
            type="?"
        fi

        DISKS+=("$path")
        printf "  %-4s  %-18s  %-8s  %s\n" "$((i)))" "$name" "$size" "${model} (${type})"
        ((i++))
    done < <(lsblk -d -n -o NAME,SIZE,MODEL -b | awk '{
        size_bytes=$2
        if (size_bytes >= 1099511627776) printf "%s %.1fT %s\n", $1, size_bytes/1099511627776, substr($0, index($0,$3))
        else if (size_bytes >= 1073741824) printf "%s %.0fG %s\n", $1, size_bytes/1073741824, substr($0, index($0,$3))
        else printf "%s %s %s\n", $1, size_bytes, substr($0, index($0,$3))
    }' | grep -E '^(sd|nvme|vd)')

    divider
}

select_disk() {
    scan_disks

    [ ${#DISKS[@]} -gt 0 ] || die "No se encontraron discos de instalación"

    while true; do
        echo -en "  Disco destino (1-${#DISKS[@]}): "
        read -r choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#DISKS[@]} )); then
            DISK="${DISKS[$((choice-1))]}"
            success "Disco: ${DISK}"
            return 0
        fi
        error "Opción inválida"
    done
}

# ── Fase 3: Confirmación destructiva ─────────────────────────────────────────

confirm_wipe() {
    local disk_label="${DISK##*/}"
    echo
    echo -e "  ${RED}╔══════════════════════════════════════════════════════╗"
    echo -e "  ║              ⚠  CONFIRMAR BORRADO  ⚠              ║"
    echo -e "  ║                                                    ║"
    echo -e "  ║  Se van a BORRAR TODOS los datos de:               ║"
    echo -e "  ║  ${BOLD}${DISK}${NC}"
    echo -e "  ║                                                    ║"
    echo -e "  ║  Tabla GPT · ESP 512MB · Root Btrfs               ║"
    echo -e "  ║  Subvolúmenes: @ @home @nix @swap                  ║"
    echo -e "  ║                                                    ║"
    echo -e "  ║  Esta acción es ${BOLD}IRREVERSIBLE${NC}.                  ║"
    echo -e "  ╚══════════════════════════════════════════════════════╝${NC}"
    echo
    echo -en "  Escribe ${BOLD}${disk_label}${NC} para confirmar el borrado: "
    read -r confirm_text

    [ "$confirm_text" = "$disk_label" ] || { error "Confirmación incorrecta. Abortando."; return 1; }
    success "Borrado confirmado"
}

# ── Fase 4: Particionado Btrfs ───────────────────────────────────────────────

partition_disk() {
    local disk="$1"
    local disk_label="${disk##*/}"

    divider
    echo -e "\n  ${BOLD}▸ Fase 1/5: Particionado${NC}\n"

    info "Limpiando ${disk}..."
    wipefs -af "$disk" 2>/dev/null
    sgdisk --zap-all "$disk" 2>/dev/null

    info "Creando tabla GPT..."
    parted -s "$disk" -- mklabel gpt

    info "Creando partición ESP (512MB, FAT32)..."
    parted -s "$disk" -- mkpart ESP fat32 1MiB 513MiB
    parted -s "$disk" -- set 1 esp on

    info "Creando partición raíz (resto del disco)..."
    parted -s "$disk" -- mkpart primary 513MiB 100%

    # Esperar al kernel
    partprobe "$disk"
    sleep 2

    # Nombres de particiones (NVMe: p1/p2, SATA: 1/2)
    if [[ "$disk" == *"nvme"* ]] || [[ "$disk" == *"loop"* ]]; then
        PART_ESP="${disk}p1"
        PART_ROOT="${disk}p2"
    else
        PART_ESP="${disk}1"
        PART_ROOT="${disk}2"
    fi

    [ -b "$PART_ESP" ]  || die "Partición ESP no encontrada: ${PART_ESP}"
    [ -b "$PART_ROOT" ] || die "Partición root no encontrada: ${PART_ROOT}"

    success "Particiones: ${PART_ESP} (ESP) + ${PART_ROOT} (root Btrfs)"
}

# ── Fase 5: Formateo y montaje ──────────────────────────────────────────────

format_and_mount() {
    echo -e "\n  ${BOLD}▸ Fase 2/5: Sistema de archivos${NC}\n"

    info "Formateando ESP (FAT32)..."
    mkfs.fat -F 32 -n BOOT "$PART_ESP"

    info "Formateando root (Btrfs, compresión zstd)..."
    mkfs.btrfs -f -L nixos "$PART_ROOT"

    # Crear subvolúmenes
    info "Creando subvolúmenes Btrfs..."
    mount "$PART_ROOT" "$MNT"
    btrfs subvolume create "$MNT/@"        >/dev/null
    btrfs subvolume create "$MNT/@home"    >/dev/null
    btrfs subvolume create "$MNT/@nix"     >/dev/null
    btrfs subvolume create "$MNT/@swap"    >/dev/null
    umount "$MNT"

    # Montar con opciones correctas
    info "Montando subvolúmenes..."
    mount -o subvol=@,compress=zstd,noatime "$PART_ROOT" "$MNT"

    mkdir -p "$MNT/home" "$MNT/nix" "$MNT/swap" "$MNT/boot"

    mount -o subvol=@home,compress=zstd,noatime "$PART_ROOT" "$MNT/home"
    mount -o subvol=@nix,compress=zstd,noatime  "$PART_ROOT" "$MNT/nix"
    mount -o subvol=@swap,compress=no,noDB      "$PART_ROOT" "$MNT/swap"
    mount "$PART_ESP" "$MNT/boot"

    success "Subvolúmenes montados en ${MNT}"
    mount | grep "$MNT" | sed 's/^/    /'
    echo

    # Crear swap file
    info "Creando swap file (${SWAP_GB}GB)..."
    truncate -s 0 "$MNT/swap/swapfile"
    chattr +C "$MNT/swap/swapfile"
    fallocate -l "${SWAP_GB}G" "$MNT/swap/swapfile"
    chmod 600 "$MNT/swap/swapfile"
    mkswap "$MNT/swap/swapfile"
    success "Swap listo: ${SWAP_GB}GB"
}

# ── Fase 6: Clonar repo ──────────────────────────────────────────────────────

clone_repo() {
    echo -e "\n  ${BOLD}▸ Fase 3/5: Repositorio nixdots${NC}\n"

    if [ -d "$REPO_DIR/.git" ]; then
        warn "Repo existente en ${REPO_DIR}"
        if confirm "¿Usar el existente o clonar de nuevo? (s=nuevo)"; then
            rm -rf "$REPO_DIR"
        else
            info "Actualizando repo existente..."
            (cd "$REPO_DIR" && git pull --quiet) || warn "git pull falló, usando versión local"
            success "Repo listo en ${REPO_DIR}"
            return 0
        fi
    fi

    info "Clonando ${REPO_URL}..."
    git clone --quiet "$REPO_URL" "$REPO_DIR"
    success "Repo clonado en ${REPO_DIR}"
}

# ── Fase 7: Generar hardware-configuration.nix ────────────────────────────────

generate_hardware() {
    local host="$1"
    echo -e "\n  ${BOLD}▸ Fase 4/5: Detección de hardware${NC}\n"

    local hw_file="$REPO_DIR/hosts/${host}/hardware-configuration.nix"
    local hw_generated
    hw_generated=$(nixos-generate-config --root "$MNT" --show-hardware-config)

    echo "$hw_generated" > "$hw_file"
    success "hardware-configuration.nix generado para ${host}"
    info "Archivo: ${hw_file}"
}

# ── Fase 8: nixos-install ────────────────────────────────────────────────────

install_nixos() {
    local host="$1"
    echo -e "\n  ${BOLD}▸ Fase 5/5: Instalación de NixOS${NC}\n"

    info "Ejecutando: nixos-install --flake ${REPO_DIR}#${host} --no-root-passwd"
    info "Esto puede tardar 10–30 minutos dependiendo de la conexión..."

    if nixos-install --flake "$REPO_DIR#${host}" --no-root-passwd 2>&1 | tee -a "$LOG"; then
        echo
        success "¡NixOS instalado exitosamente!"
    else
        error "nixos-install falló — revisa ${LOG}"
        return 1
    fi
}

# ── Limpieza y errores ───────────────────────────────────────────────────────

cleanup() {
    local code=$?
    rm -f /tmp/.nixdots-install.pid

    if [ $code -ne 0 ]; then
        echo
        echo -e "  ${RED}╔══════════════════════════════════════════════════════╗"
        echo -e "  ║           Instalación interrumpida (exit ${code})         ║"
        echo -e "  ╚══════════════════════════════════════════════════════╝${NC}"
        echo
        warn "Log guardado en: ${LOG}"

        if [ -d "$MNT" ] && mountpoint -q "$MNT" 2>/dev/null; then
            if confirm "¿Desmontar todo y limpiar?"; then
                umount -R "$MNT" 2>/dev/null || true
                success "Mounts limpiados"
            fi
        fi

        if confirm "¿Reintentar la instalación?"; then
            main
        else
            echo
            info "Puedes reintentar manualmente:"
            echo "    bash $(realpath "$0")"
            echo "    # o paso a paso:"
            echo "    nixos-install --flake ${REPO_DIR:-/tmp/nixdots}#${HOST:-HOST} --no-root-passwd"
        fi
    fi
}

# ── Resumen final ────────────────────────────────────────────────────────────

summary() {
    echo
    divider
    cat <<EOF

  ${GREEN}${BOLD}╔══════════════════════════════════════════════════════════╗
  ║              Instalación completada ✔                   ║
  ╠══════════════════════════════════════════════════════════╣${NC}
  ${GREEN}║${NC}  Host:       ${BOLD}${HOST}${NC}
  ${GREEN}║${NC}  Disco:      ${DISK}
  ${GREEN}║${NC}  Swap:       ${SWAP_GB}GB
  ${GREEN}║${NC}  Repo:       ${REPO_DIR}
  ${GREEN}${BOLD}╠══════════════════════════════════════════════════════════╣
  ${GREEN}║${NC}  Siguiente paso:                                       ${GREEN}║${NC}
  ${GREEN}║${NC}                                                          ${GREEN}║${NC}
  ${GREEN}║${NC}    nixos-enter --flake ${REPO_DIR}#${HOST}            ${GREEN}║${NC}
  ${GREEN}║${NC}                                                          ${GREEN}║${NC}
  ${GREEN}║${NC}  O simplemente:  ${BOLD}reboot${NC}                              ${GREEN}║${NC}
  ${GREEN}${BOLD}╚══════════════════════════════════════════════════════════╝${NC}

EOF
    divider
    echo -e "  Log completo: ${LOG}"
    echo
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
    trap cleanup EXIT

    banner
    preflight

    select_host
    select_disk
    confirm_wipe || exit 1

    partition_disk "$DISK"
    format_and_mount
    clone_repo
    generate_hardware "$HOST"
    install_nixos "$HOST"

    trap - EXIT
    summary
}

main "$@"
