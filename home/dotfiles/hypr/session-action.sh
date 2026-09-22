#!/usr/bin/env bash
# Apaga/reinicia cerrando primero las apps con estado (LibreWolf) de forma
# limpia, con la sesión gráfica todavía viva. Así Firefox guarda la sesión y
# no aparece el "no se cerró correctamente" al volver a abrirlo.
# Uso: session-action.sh [poweroff|reboot|suspend]   (default: poweroff)

ACTION="${1:-poweroff}"

# Pedir cierre limpio de LibreWolf y esperar a que termine solo (máx ~8s).
pkill -TERM -x librewolf 2>/dev/null || true
for _ in $(seq 1 8); do
    pgrep -x librewolf >/dev/null 2>&1 || break
    sleep 1
done

case "$ACTION" in
    reboot)  systemctl reboot ;;
    suspend) systemctl suspend ;;
    *)       systemctl poweroff ;;
esac
