#!/usr/bin/env bash
# llama-guard — mantiene Spark rapido solo, sin que Ricky corra nada.
#
# Sintoma que corrige: con la PC horas prendida, el escritorio (LibreWolf,
# Bitwarden, QtWebEngine...) empuja parte de los buffers del modelo a GTT (RAM
# del sistema) y la generacion cae de ~50 a ~5 tok/s. Reiniciar llama-chat
# reasigna todo a VRAM; medido: 5.5 -> 50.8 tok/s.
#
# OJO: GTT NO sirve como señal (medido 2.7 GB con el modelo a 48 tok/s), asi que
# se mide la velocidad real: se pide una respuesta minima y se mira cuantos
# tok/s da. Si esta por debajo de SPEED_MIN (20), esta degradado.
#
# Nunca corta trabajo en curso: primero mira /slots y, si hay algo procesando,
# espera al proximo ciclo del timer (10 min).
set -uo pipefail

UNIT=llama-chat
PORT=8091
SPEED_MIN="${SPEED_MIN:-20}"

systemctl --user is-active --quiet "$UNIT" || exit 0

# Si hay una peticion en curso, no molestamos (el probe haria cola y ademas
# mediria despues de la del usuario).
slots=$(curl -sf -m 3 "http://127.0.0.1:$PORT/slots" 2>/dev/null || echo "")
[ -z "$slots" ] && exit 0
if printf '%s' "$slots" | grep -q '"is_processing":true'; then
  exit 0
fi

probe=$(curl -sf -m 120 "http://127.0.0.1:$PORT/v1/chat/completions" \
  -H "content-type: application/json" \
  -d '{"model":"spark-4b","messages":[{"role":"user","content":"ok"}],"max_tokens":16,"temperature":0,"chat_template_kwargs":{"enable_thinking":false}}' 2>/dev/null || echo "")

if [ -z "$probe" ]; then
  # No respondio en 120 s con el modelo cargado y sin trabajo en curso: se
  # considera colgado y se reinicia.
  echo "llama-guard: el servidor no respondio al probe; reiniciando $UNIT"
else
  tg=$(printf '%s' "$probe" |
    sed -n 's/.*"predicted_per_second":\([0-9.]*\).*/\1/p' | head -1)
  [ -z "$tg" ] && exit 0
  if awk -v t="$tg" -v m="$SPEED_MIN" 'BEGIN { exit !(t < m) }'; then
    echo "llama-guard: generacion a ${tg} tok/s (< ${SPEED_MIN}); reiniciando $UNIT"
  else
    exit 0
  fi
fi

systemctl --user restart "$UNIT" || exit 1
for _ in $(seq 1 60); do
  curl -sf -m 2 "http://127.0.0.1:$PORT/health" >/dev/null 2>&1 && break
  sleep 1
done

if curl -sf -m 2 "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
  command -v notify-send >/dev/null 2>&1 &&
    notify-send -a Spark -u low "Spark reiniciado solo" \
      "El modelo se habia degradado; ya esta de nuevo en la GPU." 2>/dev/null
  echo "llama-guard: listo otra vez"
else
  echo "llama-guard: no volvio a responder; revisar journalctl --user -u $UNIT"
  exit 1
fi
