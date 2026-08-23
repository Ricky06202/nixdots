# nixdots

Configuración NixOS multi-host de Ricky — un solo flake, dos máquinas.

| Host | Máquina | GPU |
|------|---------|-----|
| `laptop` | Laptop con Intel HD 5500 + NVIDIA 940M | PRIME offload (driver legacy_580) |
| `amd` | PC con CPU + GPU AMD | amdgpu/Mesa nativos |

Escritorio: Hyprland + Caelestia Shell. Login gráfico con ReGreet (cage).
Shell: zsh + oh-my-zsh. Home-manager integrado en el flake (sin standalone).

## Instalar desde cero

Arranca el USB instalador oficial de NixOS y sigue estos pasos (todo desde
la terminal del ISO):

```bash
# 1. Internet (WiFi):
nmcli dev wifi connect "TU_RED" password "xxx"

# 2. Particionar y montar (ajusta el disco; lo de abajo borra TODO nvme0n1):
sudo parted /dev/nvme0n1 -- mklabel gpt \
  mkpart ESP fat32 1MiB 513MiB set 1 esp on \
  mkpart primary 513MiB 100%
sudo mkfs.fat -F32 /dev/nvme0n1p1
sudo mkfs.ext4 /dev/nvme0n1p2
sudo mount /dev/nvme0n1p2 /mnt
sudo mkdir -p /mnt/boot && sudo mount /dev/nvme0n1p1 /mnt/boot

# 3. Clonar el repo (el ISO no trae git):
nix-shell -p git
git clone https://github.com/Ricky06202/nixdots /root/nixdots && cd /root/nixdots

# 4. REGENERAR el hardware-configuration.nix del host (los UUID del disco son únicos):
sudo nixos-generate-config --root /mnt --dir hosts/amd   # o hosts/laptop
rm hosts/amd/configuration.nix   # genera uno de más; el del repo ya sirve

# 5. Instalar TODO desde el flake:
sudo nixos-install --flake .#amd   # o .#laptop

# 6. Contraseña del usuario (el install solo pide la de root):
sudo nixos-enter --root /mnt -c 'passwd ricky'

# 7. Reiniciar — el sistema completo ya está configurado (zsh, Hyprland,
#    Caelestia, Steam, apps, alias update...). Sin pasos post-instalación.
```

Si ya tienes NixOS funcionando y quieres adoptar esta config:

```bash
git clone https://github.com/Ricky06202/nixdots.git ~/Dev/nixdots
cd ~/Dev/nixdots
# regenera tu hardware-configuration.nix si el disco no coincide
sudo nixos-rebuild switch --flake ~/Dev/nixdots#amd   # o #laptop
```

> OJO: `hardware-configuration.nix` es específico de cada disco. Si el tuyo
> es distinto, regenera con `nixos-generate-config` antes de instalar.

## Reconstruir (día a día)

En las máquinas de Ricky el repo vive en `~/Dev/nixdots`:

```bash
sudo nixos-rebuild switch --flake ~/Dev/nixdots#laptop   # laptop
sudo nixos-rebuild switch --flake ~/Dev/nixdots#amd      # PC AMD

# Actualizar todos los inputs (nixpkgs, home-manager, caelestia):
cd ~/Dev/nixdots && nix flake update && sudo nixos-rebuild switch --flake .#<host>
```

Alias listo en zsh: `update` (reconstruye el host local apuntando al clon).
`/etc/nixos` ya no existe para nada.

## Estructura

```
flake.nix                  # 2 hosts: laptop + amd (mkHost)
hosts/
├── laptop/
│   ├── configuration.nix  # NVIDIA PRIME offload, thermald, wrapper Steam
│   └── hardware-configuration.nix
└── amd/
    ├── configuration.nix  # amdgpu nativo, blacklist nouveau
    └── hardware-configuration.nix
shared/default.nix         # TODO lo común: paquetes, servicios, GRUB, redes...
home/default.nix           # home-manager compartido (zsh/omz, dotfiles...)
home/dotfiles/             # hypr, wezterm, zellij, mangohud (conf por host)
home/assets/               # tema GRUB Himeko-Nova + wallpaper
home/scripts/              # scripts auxiliares (pick-wallpaper, nini)
```

Lo que cambia por máquina vive SOLO en `hosts/<nombre>/`. Todo lo demás es
compartido: una edición beneficia a ambas PCs.

## Detalles que valen la pena saber

- **RustDesk** va envuelto con `symlinkJoin` para correr bajo XWayland: sin eso,
  como app Wayland nativa no captura el teclado al controlar otros equipos.
- **Steam (laptop)** va envuelto con variables PRIME (`__NV_PRIME_RENDER_OFFLOAD`,
  etc.) para usar la NVIDIA aunque lo lances desde el menú de aplicaciones.
- **MangoHUD**: conf distinto por host — laptop limita a 30 FPS oculto
  (`no_display`, muestra con `Shift_R+F4`); AMD sin límite.
- **Caelestia** se arma en `flake.nix` con el **quickshell precompilado de
  nixpkgs** (no se compila el git master de outfoxxed: ~1h local). El CLI va
  incluido en el mismo paquete. No usar `caelestia.packages.*`.
