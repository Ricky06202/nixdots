#!/usr/bin/env bash
# Reinicia el shell de Caelestia al despertar de la suspensión.
#
# Fix quickshell#989: tras suspender/resumir, Hyprland no re-emite por el
# event socket (.socket2.sock) y Caelestia queda congelada (workspaces sin
# actualizar / blur) hasta reiniciar el shell. Este watcher escucha el signal
# PrepareForSleep de systemd-logind en el bus del sistema y relanza el shell
# al despertar, esperando a que el compositor responda antes de kill+start.

export PATH="$PATH:/run/current-system/sw/bin:/etc/profiles/per-user/$USER/bin"

# Fallback de firma si uwsm no la importó (mismo criterio que rotate-wallpaper.sh).
if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    SOCK=$(ls -d "$XDG_RUNTIME_DIR"/hypr/*/ 2>/dev/null | head -n1)
    if [ -n "$SOCK" ]; then
        export HYPRLAND_INSTANCE_SIGNATURE="$(basename "$SOCK")"
    fi
fi

restart_caelestia() {
    # Solo actuar dentro de una sesión gráfica viva (compositor respondiendo).
    hyprctl activeworkspace >/dev/null 2>&1 || return 0

    caelestia shell -k 2>/dev/null
    sleep 1
    setsid caelestia-shell -d </dev/null >/dev/null 2>&1 &
}

dbus-monitor --system "type='signal',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'" |
    while read -r line; do
        case "$line" in
            *"boolean false"*)  # despertando de la suspensión
                sleep 5
                restart_caelestia
                ;;
        esac
    done