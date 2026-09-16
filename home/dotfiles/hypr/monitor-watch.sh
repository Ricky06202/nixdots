#!/usr/bin/env bash
# Vigila la conexion del monitor externo:
# - si HDMI-A-2 esta conectado -> eDP-1 (portatil) se apaga
# - si HDMI-A-2 se desconecta  -> eDP-1 se enciende de nuevo
# (comandos en formato Lua porque Hyprland ya no usa hyprctl keyword)
#
# Solo tiene sentido en el laptop (eDP-1 + HDMI-A-2): si no existe un panel
# eDP-1 (host amd, RX 7600 con HDMI-A-1) el script es un no-op para no estar
# lanzando `hyprctl eval` a un monitor inexistente cada 3 segundos.
hyprctl monitors 2>/dev/null | grep -q 'eDP-1' || exit 0

last=""
while true; do
    if hyprctl monitors 2>/dev/null | grep -q 'HDMI-A-2'; then
        if [ "$last" != "ext" ]; then
            hyprctl eval 'hl.monitor({ output = "eDP-1", disabled = true })'
            last="ext"
        fi
    else
        if [ "$last" != "laptop" ]; then
            hyprctl eval 'hl.monitor({ output = "eDP-1", mode = "1920x1080@60", position = "1920x0", scale = 1 })'
            last="laptop"
        fi
    fi
    sleep 3
done
