#!/usr/bin/env bash
# Monta imágenes de disco (ISO/IMG/MDF) vía udisksctl (ya parte de NixOS, verbatim
# de udisks2). Pensada para la acción "Montar imagen" de Nemo:
# right-click en el .iso → se monta como loop device → se abre el contenido en Nemo.
# Para desmontar: botón de expulsar (eject) en la barra lateral de Nemo.
# Uso: mount-iso.sh [imagen...]

set -u

for ISO in "$@"; do
  [ -f "$ISO" ] || continue

  LOOP="$(udisksctl loop-setup -f "$ISO" --no-user-interaction 2>/dev/null | grep -oE '/dev/loop[0-9]+' | head -n1)"
  if [ -z "$LOOP" ]; then
    notify-send -a Nemo "Montar imagen" "No se pudo crear el loop device para: $ISO" -t 4000
    continue
  fi

  MNT="$(udisksctl mount -b "$LOOP" --no-user-interaction 2>/dev/null | grep -oE '/\S+' | tail -n1)"
  if [ -n "$MNT" ]; then
    notify-send -a Nemo "Montar imagen" "Montada en $MNT" -t 4000
    setsid xdg-open "$MNT" >/dev/null 2>&1 &
  else
    udisksctl loop-delete -b "$LOOP" >/dev/null 2>&1 || true
    notify-send -a Nemo "Montar imagen" "No se pudo montar: $ISO" -t 4000
  fi
done