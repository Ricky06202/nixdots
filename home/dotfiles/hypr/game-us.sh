#!/usr/bin/env bash
# Los juegos de Proton corren en XWayland y leen el keymap del servidor X.
# Hyprland lo inicializa en Colemak-DH (XKB_DEFAULT_VARIANT), y cambiar el
# layout del compositor con `hyprctl switchxkblayout` NO toca ese keymap: hay
# que usar `setxkbmap`. Este wrapper pone US en XWayland ANTES de lanzar el
# juego y restaura Colemak al salir. Las apps Wayland no se tocan.
#
# Uso en Steam (Propiedades > Opciones de lanzamiento):
#   /home/ricky/.config/hypr/game-us.sh %command%

layout="${XKB_DEFAULT_LAYOUT:-us,us}"
variant="${XKB_DEFAULT_VARIANT:-colemak_dh,}"
options="${XKB_DEFAULT_OPTIONS:-}"

restore() {
    if [ -n "$options" ]; then
        setxkbmap -layout "$layout" -variant "$variant" -option "$options" >/dev/null 2>&1
    else
        setxkbmap -layout "$layout" -variant "$variant" >/dev/null 2>&1
    fi
}
trap restore EXIT INT TERM HUP

setxkbmap -layout us >/dev/null 2>&1 || true

"$@"
