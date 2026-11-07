#!/usr/bin/env bash
# Lanza un juego con el layout US activo desde ANTES de arrancar.
# Crystar y Code Vein leen el layout XKB al iniciar el proceso y no reaccionan
# a cambios posteriores (por eso forzarlo al enfocar la ventana no servia).
# Restaura el layout previo al cerrar el juego.
#
# Uso en Steam (Propiedades > Opciones de lanzamiento):
#   ~/.config/hypr/game-us.sh %command%

if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    SOCK=$(ls -d "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/hypr/*/ 2>/dev/null | head -n1)
    [ -n "$SOCK" ] && export HYPRLAND_INSTANCE_SIGNATURE="$(basename "$SOCK")"
fi

prev=0
if hyprctl devices 2>/dev/null | grep -q "Colemak"; then
    prev=0
else
    prev=1
fi

hyprctl switchxkblayout all 1 >/dev/null 2>&1

restore() {
    hyprctl switchxkblayout all "$prev" >/dev/null 2>&1
}
trap restore EXIT INT TERM HUP

"$@"
