#!/usr/bin/env bash
# Lanzador de Steam robusto y rápido: comprueba PipeWire/audio y la red con
# re-chequeo continuo (sin esperas fijas largas) y arranca Steam con flags
# ligeros para abrir antes.

# Esperar a que PipeWire esté disponible (máx ~15s)
for i in $(seq 1 15); do
    if pactl info >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

# Esperar red (máx ~15s). Si no hay nmcli, saltamos.
if command -v nmcli >/dev/null 2>&1; then
    for i in $(seq 1 15); do
        if nmcli -t -f STATE g | grep -q connected; then
            break
        fi
        sleep 1
    done
fi

# Pequeña pausa para que el entorno Wayland esté asentado
sleep 2

# -no-browser: sin navegador webhelper (ahorra RAM y acelera el arranque)
# -no-shaderbackgrounddownload: no baja shaders en background al abrir
exec steam -no-browser -no-shaderbackgrounddownload
