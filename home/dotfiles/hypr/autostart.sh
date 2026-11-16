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
# Jan esta desinstalado (2026-11-16): era solo chat, sin herramientas. El unico
# modelo local es Spark-X2.6 4B y se levanta a mano con `local-ai chat`.
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
