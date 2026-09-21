#!/usr/bin/env bash
# Rota el wallpaper de Caelestia cada hora (systemd user timer).
# Los servicios del manager de usuario heredan el entorno de la sesión gráfica
# (uwsm lo importa al iniciar la sesión), así que 'hyprctl reload' y el CLI de
# Caelestia funcionan directamente.
# Antes se rastreaba el entorno desde /proc/<pid>/environ con `pgrep -x Hyprland`,
# que fallaba por dos motivos: uwsm lanza Hyprland como '.Hyprland-wrapp'
# (pgrep -x no lo ve) y yama.ptrace_scope=1 deniega leer /proc/<pid>/environ
# desde fuera del proceso padre.

if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
    # Fallback: derivar la firma desde el socket de Hyprland si el entorno no
    # la trajo importada (p.ej. sesión iniciada sin uwsm).
    SOCK=$(ls -d "$XDG_RUNTIME_DIR"/hypr/*/ 2>/dev/null | head -n1)
    if [ -n "$SOCK" ]; then
        export HYPRLAND_INSTANCE_SIGNATURE="$(basename "$SOCK")"
    else
        exit 0
    fi
fi

exec "$HOME/.config/hypr/wallpaper-pick.sh"