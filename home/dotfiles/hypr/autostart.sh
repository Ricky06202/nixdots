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
# Jan ya NO arranca solo: sus modelos (TwIL 8B y Qwen3-VL) se borraron el
# 2026-11-16 y el unico modelo local es Spark-X2.6 4B, que se levanta a mano con
# `local-ai chat` (ocupa la GPU entera). Jan queda instalado pero vacio.
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
