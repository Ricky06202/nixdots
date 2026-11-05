#!/usr/bin/env bash
# Bloquea la sesion y apaga el monitor tras un margen.
# El idle de Caelestia esta desactivado (timeouts=[]): este es el unico punto
# que apaga la pantalla. Cualquier tecla/raton la vuelve a encender
# (misc.key_press_enables_dpms / misc.mouse_move_enables_dpms).

if ! caelestia shell lock lock >/dev/null 2>&1; then
    hyprctl eval 'hl.dispatch(hl.dsp.global("caelestia:lock"))' >/dev/null 2>&1
fi

sleep 3

if [ "$(caelestia shell lock isLocked 2>/dev/null)" = "true" ]; then
    hyprctl eval 'hl.dispatch(hl.dsp.dpms({ action = "disable" }))' >/dev/null 2>&1
fi
