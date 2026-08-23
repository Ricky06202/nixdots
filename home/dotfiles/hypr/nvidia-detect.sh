#!/usr/bin/env bash
# Detecta la GPU NVIDIA instalada y muestra el comando de rebuild
# con la variable NIXOS_NVIDIA_GPU para que el flake elija el driver correcto.
# Uso: ~/.config/hypr/nvidia-detect.sh

# Buscar el device ID de la NVIDIA (vendor 0x10de)
NVIDIA_ID=$(for d in /sys/class/drm/card*/device/vendor; do
    v=$(cat "$d" 2>/dev/null)
    if [ "$v" = "0x10de" ]; then
        echo "$(cat "$(dirname "$d")/device" 2>/dev/null)"
        break
    fi
done)

if [ -z "$NVIDIA_ID" ]; then
    echo "No se detectó GPU NVIDIA. No hace falta configurar el driver."
    exit 0
fi

echo "NVIDIA device ID: 0x$NVIDIA_ID"

# Tabla de dispositivos NVIDIA conocidos
# 0x1347 = GeForce 940M (Maxwell) -> legacy_470
case "$NVIDIA_ID" in
    1347) GPU="940M Maxwell" ;;
    *)    GPU="modern" ;;
esac

echo "GPU detectada: $GPU"
echo ""
echo "Corre el rebuild con el driver correcto:"
echo "  sudo NIXOS_NVIDIA_GPU=\"$GPU\" nixos-rebuild switch --flake /etc/nixos#nixos"
