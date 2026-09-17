#!/usr/bin/env bash
# Rota el wallpaper de Caelestia cada hora (systemd user timer).
# Los servicios de usuario NO heredan el entorno de la sesión gráfica, así
# que importamos las vars de Hyprland desde su proceso (PID -> /proc) para que
# 'hyprctl reload' y el CLI de Caelestia funcionen fuera de la sesión.

HYPRPID=$(pgrep -x Hyprland 2>/dev/null | head -n1)
if [ -z "$HYPRPID" ]; then
    exit 0
fi

# Importar solo las variables que necesita el script de rotación.
for var in DISPLAY HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY XDG_RUNTIME_DIR; do
    val=$(tr '\0' '\n' < /proc/$HYPRPID/environ 2>/dev/null | grep -E "^$var=" | cut -d= -f2-)
    if [ -n "$val" ]; then
        export "$var=$val"
    fi
done

exec "$HOME/.config/hypr/wallpaper-pick.sh"