# Sistema: NixOS de Ricky

Instrucciones globales para asistir en este equipo. Léelas siempre que trabajes aquí.

## Datos del sistema
- SO: NixOS con **flakes**. La config vive en el repo público `~/Dev/nixdots`
  (https://github.com/Ricky06202/nixdots), estructura multi-host.
- Hosts definidos en un solo flake:
  - `laptop` — Intel HD 5500 (iGPU) + NVIDIA 940M (PRIME offload, driver legacy_580)
  - `amd` — Ryzen 5 5500 (6c/12t, sin iGPU — 1 sola GPU) + RX 7600 8GB, B550M, 32GB DDR4, NVMe 1TB (amdgpu nativo)
  - `omen` — HP Omen 17t: i7-11800H + RTX 3070 Laptop (gaming machine, NVIDIA modesetting)
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

## Memoria persistente (IMPORTANTE)
- Datos en `~/.config/opencode/memory/` (locales, NUNCA al repo). Al iniciar
  cualquier sesión, leer `MEMORY.md` y `reminders.md` ANTES de lo demás: lo que
  hay ahí es contexto válido sin que el usuario lo repita.
- Si aparece información duradera en la charla (preferencias, personas,
  proyectos, fechas, acuerdos): actualizar `MEMORY.md` de inmediato con la
  skill `memory`, sin pedir permiso.
- Recordatorios con hora: usar la skill `memory` (timers systemd user +
  `~/.local/bin/reminder-fire.sh`). JAMÁS decir "te lo recordaré" sin haber
  creado y verificado el timer (`systemctl --user list-timers 'remind-*'`).

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
  `hyprctl eval '...'` o `hl.dsp.*` dentro del lua. OJO: los `hl.dsp.X{...}`
  son FABRICAS de despachadores (devuelven objeto, no ejecutan). Ejecutar de
  verdad: `hyprctl eval 'hl.dispatch(hl.dsp.focus({window = "address:0x..."}))'`
  (patrón verificado en source v0.56.2 y en vivo 2026-10: es la forma de
  reenfocar la ventana de ella si pierde el input). `hl.config` SOLO declara
  opciones custom; setear en runtime no existe por Lua. Métodos w:focus NO hay.
- API Lua 0.56 (verificado en source v0.56.2): `hl.dsp.focus{window="address:X"}`
  NO ejecuta — devuelve un OBJETO dispatcher; ejecutar con
  `hyprctl eval 'hl.dispatch(hl.dsp.focus({window="address:X"}))'`.
  Mismo patron para todos los dsp con argumentos. `hl.config` es para DECLARAR
  opciones custom, no para setear en runtime. Métodos de ventana (w:focus) NO
  existen.

## Detalles por host / trampas conocidas
- **RustDesk**: envuelto con `symlinkJoin + wrapProgram` para forzar XWayland
  (bug upstream: el grab de teclado usa APIs X11). No "simplificar" quitando el wrapper.
- **Steam laptop**: envuelto con variables PRIME offload. En amd no existe ese wrapper.
- **MangoHUD**: laptop = `fps_limit=30,0` + `no_display` (mostrar con Shift_R+F4);
  amd = sin límite. Vars `MANGOHUD_CONFIGFILE`/`MANGOHUD_DLSYM` son sessionVariables globales.
- **zsh**: NO añadir alias `z` (pisa la función de zoxide y rompe el salto).
  Highlight/autosuggestions/zoxide/fzf son nativos de home-manager, NO plugins de omz.
- **Sunshine (amd, MODO SIMPLE 2026-10)**: game-stream host para la laptop de
  ella via Moonlight. TODO bajo el usuario **ricky** (user-unit del modulo,
  autoStart default): captura wl-screencopy sobre TU Hyprland (socket propio,
  sin ACLs), apps via gamescope => window rule class=gamescope (ws6,
  HEADLESS-1, fullscreen, NO_FOCUS: nunca roba el teclado/raton locales).
  Ella juega con SU cuenta de
  Steam dentro de TU usuario: un solo Steam online a la vez (acordado).
  - ricky necesita grupo `uinput` (mando xone) + `input`; lo pone
    hosts/amd/configuration.nix (users.users.ricky.extraGroups) y el modulo
    hardware.uinput.enable.
  - **NO volver a la arquitectura de usuaria separada `ella`**: murio por (a)
    wine exige pfx PROPIEDADE del usuario (los ACLs no valen) y (b) 2 steam
    simultaneos exigen uid real. prefijos compartidos = sin sentido.
  - Audio: stream_audio=false (juego mudo en stream, sin fugas).
  - Sin guards/scripts de foco (focus-guard y pad-focus BORRADOS: fragiles
    con la API Lua 0.56). La rule usa `no_focus = true` (campo Lua de
    hl.window_rule en 0.56): la ventana gamescope jamas toma foco teclado.
    Implicacion: teclado/raton INYECTADOS por sunshine (fake-input, siguen el
    foco) no llegan a su Steam => ella juega con mando xone (uinput=evdev
    global, ignora foco) y raton del stream (eventos de puntero, idem).
  - Steam app del menu: gamescope -w 1920 -h 1080 --force-windows-fullscreen
    -- steam (el anidado llena el area util; HEADLESS-1 es 1080p y es lo que
    se captura). OJO: Caelestia reserva 60+10px en TODOS los monitores =>
    la ventana util real es 1830x1040; el stream lo ve con barras. Para
    1080p limpios habria que excluir HEADLESS-1 de las barras de caelestia.
  - Web UI: https://127.0.0.1:47990. Logs: journalctl --user -u sunshine.
    Apps se editan EN EL REPO (services.sunshine.applications); el editor
    web deja de guardar cuando estan declaradas.
## Git
- Identity se configura POR REPO (no global): user.name "Ricky06202",
  email ricardosanjurg@gmail.com.
- Otros repos del usuario viven planos en `~/Dev/`.
