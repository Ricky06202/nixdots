#!/usr/bin/env bash
# Apps de inicio con arranque escalonado para no saturar la RAM.
# Cada app cae en su workspace automáticamente por window rules (hyprland.lua).
# OBS se abre manual (saturaba la GPU al inicio).

/run/current-system/sw/libexec/polkit-gnome-authentication-agent-1 &
xsettingsd &
librewolf &
blueman-applet &
sleep 8
vesktop &
zapzap &
# Jan (asistente local: TwIL 8B + Qwen3-VL) sustituye a ChatGPT en el arranque
# y en el ws 5. Su wrapper es bubblewrap con --die-with-parent: si se lanza como
# hijo directo de este script muere al terminar (y `setsid` deja una carrera con
# PDEATHSIG). Como unidad transitoria de systemd --user el padre es estable y
# además queda el log en `journalctl --user -u jan-desktop`. Solo existe en amd.
if command -v Jan-Desktop >/dev/null 2>&1; then
  systemd-run --user --unit=jan-desktop --collect \
    --description="Jan (asistente local)" \
    Jan-Desktop >/dev/null 2>&1 || true
fi
disown -a

# --- Feishin (musica) al inicio ------------------------------------------------
# Feishin (cliente Navidrome) reemplazo a Spotify.
# Steam ya NO auto-arranca (modo simple 2026-10): con UN solo uid hay UN solo
# cliente, y quien lo abra define la cuenta online. Arrancandolo desde el menu
# de Moonlight, ella inicia/usa SU cuenta; Ricky abre el suyo cuando juega
# (cambiar de cuenta = Steam > Salir, sin matar nada). Un Steam online a la vez.
nohup feishin >/dev/null 2>&1 &

# --- Motrix (gestor de descargas) ----------------------------------------------
nohup motrix-next >/dev/null 2>&1 &
disown -a
