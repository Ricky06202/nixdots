# nixdots

Configuración NixOS multi-host de Ricky — un solo flake, dos máquinas.

| Host | Máquina | GPU |
|------|---------|-----|
| `laptop` | Laptop con Intel HD 5500 + NVIDIA 940M | PRIME offload (driver legacy_580) |
| `amd` | PC con CPU + GPU AMD | amdgpu/Mesa nativos |

Escritorio: Hyprland + Caelestia Shell (también GNOME disponible en GDM).
Shell: zsh + oh-my-zsh. Home-manager integrado en el flake (sin standalone).

## Instalar desde cero

Arranca el USB instalador oficial de NixOS (canal estable o unstable da igual,
el flake trae el suyo) y corre:

```bash
# Particiona/monta tus discos en /mnt primero (o usa disko en el futuro)
sudo mount /dev/disk/by-label/NIXOS /mnt   # ejemplo

# Instalar directamente desde GitHub SIN clonar ni loguearte:
sudo nixos-install --flake github:Ricky06202/nixdots#amd
# o para el laptop:
sudo nixos-install --flake github:Ricky06202/nixdots#laptop
```

Si ya tienes NixOS instalado y quieres adoptar esta config:

```bash
sudo mv /etc/nixos /etc/nixos.bak
git clone https://github.com/Ricky06202/nixdots.git /etc/nixos
sudo nixos-rebuild switch --flake /etc/nixos#amd   # o #laptop
```

> OJO: `hardware-configuration.nix` de cada host se generó con la instalación
> original de esa máquina. Si tu disco es diferente, regenera el tuyo con
> `nixos-generate-config --dir /tmp` y reemplázalo antes de instalar.

## Reconstruir (día a día)

Clona el repo donde quieras trabajar (en la máquina de Ricky vive en
`~/Documentos/Programacion/Publico/nixdots`) y reconstruye desde ahí:

```bash
# En el laptop:
sudo nixos-rebuild switch --flake ~/Documentos/Programacion/Publico/nixdots#laptop

# En la PC AMD:
sudo nixos-rebuild switch --flake ~/Documentos/Programacion/Publico/nixdots#amd

# Actualizar todos los inputs (nixpkgs, home-manager, caelestia):
nix flake update && sudo nixos-rebuild switch --flake .#<host>
```

Alias listo en zsh: `update` (reconstruye el host local apuntando al clon).
`/etc/nixos` ya no es necesario para nada.

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
- **Caelestia** viene de flakes upstream, no de nixpkgs.
