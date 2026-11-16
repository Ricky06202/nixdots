#!/usr/bin/env bash
# llama-guard — mantiene Spark rapido solo, sin que Ricky corra nada.
#
# Sintoma que corrige: con la PC horas prendida, el escritorio (LibreWolf,
# Bitwarden, QtWebEngine...) empuja parte de los buffers del modelo a GTT (RAM
# del sistema) y la generacion cae de ~50 a ~5 tok/s. Reiniciar llama-chat
# reasigna todo a VRAM; medido: GTT 2.4 -> 1.3 GB y 5.5 -> 50.8 tok/s.
#
# Corre por timer cada 10 min (systemd user). Solo reinicia si:
#   - GTT supera el umbral (2.5 GB; normal ronda 1.3-1.5), y
#   - el servidor NO esta procesando (is_processing=false en /slots), para no
#     cortar una respuesta en curso. Si esta ocupado, espera al proximo ciclo.
set -uo pipefail

UNIT=llama-chat
PORT=8091
GTT_FILE=/sys/class/drm/card1/device/mem_info_gtt_used
LIMIT="${GTT_LIMIT:-2500000000}" # 2.5 GB

[ -r "$GTT_FILE" ] || exit 0
systemctl --user is-active --quiet "$UNIT" || exit 0

gtt=$(cat "$GTT_FILE")
[ "$gtt" -lt "$LIMIT" ] && exit 0

# Degradado: solo actuar si no hay trabajo en curso.
slots=$(curl -sf -m 3 "http://127.0.0.1:$PORT/slots" 2>/dev/null || echo "")
if [ -z "$slots" ]; then
  # No responde: el propio servicio (Restart) o el usuario lo levantan.
  exit 0
fi
if printf '%s' "$slots" | grep -q '"is_processing":true'; then
  echo "llama-guard: degradado (GTT $(numfmt --to=iec <<<"$gtt")) pero ocupado; espero."
  exit 0
fi

echo "llama-guard: GTT $(numfmt --to=iec <<<"$gtt") > umbral; reiniciando $UNIT"
systemctl --user restart "$UNIT" || exit 1
for _ in $(seq 1 60); do
  curl -sf -m 2 "http://127.0.0.1:$PORT/health" >/dev/null 2>&1 && break
  sleep 1
done

if curl -sf -m 2 "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
  command -v notify-send >/dev/null 2>&1 &&
    notify-send -a Spark -u low "Spark reiniciado solo" \
      "El modelo habia caido a RAM (GTT $(numfmt --to=iec <<<"$gtt")). Ya esta de nuevo en la GPU." 2>/dev/null
  echo "llama-guard: listo otra vez"
else
  echo "llama-guard: no volvio a responder; revisar journalctl --user -u $UNIT"
  exit 1
fi
