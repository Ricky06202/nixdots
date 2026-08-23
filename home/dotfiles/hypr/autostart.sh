#!/usr/bin/env bash
# Apps de inicio con arranque escalonado para no saturar la RAM (7.2 GB).
# Cada app cae en su workspace automáticamente por window rules (hyprland.lua).
# OBS se abre manual (saturaba la GPU al inicio).
# Steam/Spotify se abren manual (ahorran ~500MB al inicio).

/run/current-system/sw/libexec/polkit-gnome-authentication-agent-1 &
xsettingsd &
brave --renderer-process-limit=4 --disable-features=TabDiscarding --js-flags="--max-old-space-size=512" &
blueman-applet &
sleep 8
vesktop &
karere &
disown -a
