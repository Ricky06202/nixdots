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
# opencode (agente de codigo): ventana propia, siempre en el ws 5 por la regla de
# hyprland.lua. OJO: el MODELO no arranca solo — Spark ocupa 7.5 de los 8 GB de
# VRAM y compite con juegos/Sunshine; se levanta con `local-ai chat` cuando se va
# a programar (sin eso la app abre pero el modelo local da error de conexión).
if command -v opencode-desktop >/dev/null 2>&1; then
  setsid nohup opencode-desktop >/dev/null 2>&1 &
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
