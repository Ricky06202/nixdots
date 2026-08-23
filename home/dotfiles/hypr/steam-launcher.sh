#!/usr/bin/env bash
# Lanzador de Steam robusto: espera a que PipeWire/audio y la red estén listos
# antes de arrancar, para que no muera en el inicio del sistema.
# Se lanza al final del autostart con nohup.

# Esperar hasta 45s a que PipeWire esté disponible
for i in $(seq 1 45); do
    if pactl info >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

# Esperar red (Steam lo necesita para el login)
if command -v nmcli >/dev/null 2>&1; then
    for i in $(seq 1 30); do
        if nmcli -t -f STATE g | grep -q connected; then
            break
        fi
        sleep 1
    done
fi

# Pequeña pausa extra para que el entorno Wayland esté asentado
sleep 5

exec steam
