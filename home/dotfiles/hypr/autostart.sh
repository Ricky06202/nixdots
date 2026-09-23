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
karere &
disown -a

# --- Spotify y Steam al inicio ------------------------------------------------
# Spotify directo; Steam vía steam-launcher.sh (espera PipeWire + red).
nohup spotify >/dev/null 2>&1 &
nohup "$HOME/.config/hypr/steam-launcher.sh" >/dev/null 2>&1 &

# --- Motrix (gestor de descargas) ----------------------------------------------
nohup motrix-next >/dev/null 2>&1 &
disown -a
