# Sistema: NixOS de Ricky

Instrucciones globales para asistir en este equipo. Léelas siempre que trabajes aquí.

## Datos del sistema
- SO: NixOS con **flakes**. La config vive en el repo público `~/Dev/nixdots`
  (https://github.com/Ricky06202/nixdots), estructura multi-host.
- Hosts definidos en un solo flake:
  - `laptop` — Intel HD 5500 (iGPU) + NVIDIA 940M (PRIME offload, driver legacy_580)
  - `amd` — Ryzen 7 5700 (8c/16t) + RX 7600 8GB, B550M, 32GB DDR4, NVMe 1TB (amdgpu nativo)
- Home-manager integrado como módulo del flake (NO standalone).
- Shell: zsh + oh-my-zsh (vía home-manager).
- Escritorio: Hyprland (Wayland) + Caelestia Shell. Login gráfico: ReGreet sobre cage.
  Ya NO existe GNOME/GDM.
- Zona horaria `America/Panama`, locale `es_PA.UTF-8`.
- RAM: laptop 7.2 GB (zram 50% + swapfile 8GB); PC AMD 32 GB (zram 25% + swapfile 8GB en @swap).

## Reglas de oro
1. **Todo es declarativo**: los cambios van al repo `~/Dev/nixdots` y se aplican con
   `sudo nixos-rebuild switch --flake ~/Dev/nixdots#<host>`. sudo pide contraseña:
   NO lo ejecutes tú, dale al usuario el comando exacto para su terminal.
2. Estructura del repo: `shared/default.nix` = común a ambos hosts (editar UNA vez
   beneficia a ambos). `hosts/<nombre>/configuration.nix` = específico por máquina.
   `home/default.nix` = home-manager compartido; lo por-host se resuelve con el
   parámetro `hostName` (ej: MangoHUD conf distinto, aliases solo laptop).
3. `hardware-configuration.nix` NO se copia entre hosts ni se toca salvo cambio de disco.
4. Alias `update` en zsh reconstruye el host local. Para actualizar inputs:
   `nix flake update` en el repo + rebuild. OJO: cada update puede disparar
   recompilaciones largas de inputs git (ver sección Caelestia).
5. `nixpkgs.config.allowUnfree = true` ya está activo.
6. Para probar paquetes temporalmente: `nix profile install nixpkgs#<paquete>`
   (se actualiza con `nix profile upgrade`; el rebuild NO lo toca).
7. Validar opciones nuevas contra el nixpkgs del lock antes de escribirlas
   (`nix eval`, o leer los módulos en el source de nixpkgs).
8. El repo es PÚBLICO: jamás commitear tokens, passwords o claves.
9. Validar cambios antes de pedir rebuild: `nix flake check` y/o
   `nix build .#nixosConfigurations.<host>.config.system.build.toplevel --dry-run`
10. Keystores (ej: exports Android/Godot) y secretos similares van en `~/Dev/keys/`,
    FUERA de cualquier repo: jamás dentro del proyecto ni commiteados.

## Caelestia (IMPORTANTE)
- Se arma en `flake.nix` (`caelestiaShell`) usando el **quickshell precompilado de
  nixpkgs** (wrapper `qsPrebuilt` que replica el passthru `withModules` del flake
  oficial de outfoxxed). Compila en minutos, no horas.
- **NUNCA usar `caelestia.packages.*`**: eso compila quickshell-git desde fuente
  (~1h local; no existe caché binaria pública para ese input).
- El CLI va incluido vía `withCli = true` — no instalar `caelestia-cli.packages` aparte.
- Launcher: SUPER+R. Lock: SUPER+L. Arranque: `caelestia-shell -d` en hyprland.lua.

## Hyprland
- La config real es `~/.config/hypr/hyprland.lua` (formato Lua de Hyprland 0.56);
  el `hyprland.conf` es un stub. Los dotfiles se gestionan desde `home/dotfiles/`.
- En Hyprland 0.56 `hyprctl dispatch` interpreta args como Lua: usar
  `hyprctl eval '...'` o `hl.dsp.*` dentro del lua.

## Detalles por host / trampas conocidas
- **RustDesk**: envuelto con `symlinkJoin + wrapProgram` para forzar XWayland
  (bug upstream: el grab de teclado usa APIs X11). No "simplificar" quitando el wrapper.
- **Steam laptop**: envuelto con variables PRIME offload. En amd no existe ese wrapper.
- **MangoHUD**: laptop = `fps_limit=30,0` + `no_display` (mostrar con Shift_R+F4);
  amd = sin límite. Vars `MANGOHUD_CONFIGFILE`/`MANGOHUD_DLSYM` son sessionVariables globales.
- **zsh**: NO añadir alias `z` (pisa la función de zoxide y rompe el salto).
  Highlight/autosuggestions/zoxide/fzf son nativos de home-manager, NO plugins de omz.

## Git
- Identity se configura POR REPO (no global): user.name "Ricky06202",
  email ricardosanjurg@gmail.com.
- Otros repos del usuario viven planos en `~/Dev/`.
