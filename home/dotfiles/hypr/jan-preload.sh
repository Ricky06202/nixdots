#!/usr/bin/env bash
# Precarga el modelo de Jan (por defecto TwIL 8B) unos segundos despues de
# arrancar la sesion, para que la carga del modelo no compita con el escritorio
# cuando empiezas a escribir.
#
# Por que: cargar TwIL (5.3 GB de pesos + KV de 131k) satura la GPU ~6 s (79-100%
# de gpu_busy) y en ese rato Hyprland pierde frames. Cargando al inicio, cuando
# aun no hay nada que hacer, el tiron no se nota.
#
# Se apoya en el router del propio worker de Jan: busca su puerto y su API key
# (variables de entorno del proceso) y pide /models/load. Si ya hay un modelo
# cargado (p. ej. cambiaste a Qwen a mano) no hace nada.
#
# Env: JAN_PRELOAD_MODEL (def. twil-8b), JAN_PRELOAD_DELAY (def. 25 s),
#      JAN_PRELOAD=0 para desactivar.

set -uo pipefail

[ "${JAN_PRELOAD:-1}" = "0" ] && exit 0
model=${JAN_PRELOAD_MODEL:-twil-8b}
delay=${JAN_PRELOAD_DELAY:-25}
sleep "$delay"

for _ in $(seq 1 30); do
  pid=$(pgrep -f 'jan-llama-worker --preset' | head -1)
  [ -z "$pid" ] && { sleep 2; continue; }

  port=$(ss -ltnp 2>/dev/null | awk -v p="pid=$pid," '$0 ~ p {print $4}' | sed 's/.*://' | head -1)
  key=$(tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | sed -n 's/^JAN_LLAMA_API_KEY=//p')
  [ -z "$port" ] || [ -z "$key" ] && { sleep 2; continue; }

  models=$(curl -sf -m 3 -H "Authorization: Bearer $key" "http://127.0.0.1:$port/models" 2>/dev/null)
  [ -z "$models" ] && { sleep 2; continue; }

  # si ya hay algo cargado, respetamos la eleccion del usuario
  if ! printf '%s' "$models" | grep -q '"loaded"'; then
    echo "jan-preload: cargando $model en :$port"
    curl -s -m 300 -X POST -H "Authorization: Bearer $key" \
      -H 'Content-Type: application/json' \
      -d "{\"model\":\"$model\"}" "http://127.0.0.1:$port/models/load"
    echo
  fi
  exit 0
done

echo "jan-preload: no encontre el router de Jan, nada que hacer" >&2
exit 0
