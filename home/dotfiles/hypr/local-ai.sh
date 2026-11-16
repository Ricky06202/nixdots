#!/usr/bin/env bash
# local-ai chat|restart|off|status — maneja el unico modelo local de la maquina.
#
#   chat    Spark-X2.6 4B Q4_K_M, ctx 131072, KV q8_0 ... ~7.5 GB (GPU entera)
#   restart reinicia el servidor (corrige la caida a ~5 tok/s por spill a GTT)
#   off     lo para (libera la GPU para jugar/streaming)
#   status  que hay cargado, VRAM y GTT
#
# Lo usa el provider `local` de opencode (:8091), el panel de Zed y nini.
# El servicio `llama-chat` lo declara nixdots (home/default.nix, solo host amd)
# y arranca solo al iniciar sesion; este script lo maneja a mano cuando hace
# falta. OJO: ocupa 7.5 de los 8 GB de VRAM, asi que para jugar hay que apagarlo.
set -uo pipefail

CHAT_UNIT=llama-chat
CHAT_PORT=8091
CHAT_MODEL="$HOME/Dev/models/Spark-X2.6-4B-Q4_K_M.gguf"

vram_used() {
  for f in /sys/class/drm/card*/device/mem_info_vram_used; do
    [ -r "$f" ] && { cat "$f"; return; }
  done
  echo 0
}

vram_human() {
  awk -v b="$(vram_used)" 'BEGIN { printf "%.1f GB", b/1073741824 }'
}

usage() {
  echo "uso: local-ai chat|restart|off|status"
  exit 2
}

case "${1:-}" in
chat)
  [ -f "$CHAT_MODEL" ] || { echo "falta el modelo: $CHAT_MODEL"; exit 1; }
  systemctl --user cat "$CHAT_UNIT" >/dev/null 2>&1 || {
    echo "no existe el servicio $CHAT_UNIT."
    echo "aplica el rebuild: sudo nixos-rebuild switch --flake ~/Dev/nixdots#amd"
    exit 1
  }
  if systemctl --user is-active --quiet "$CHAT_UNIT"; then
    echo "ya esta corriendo en http://127.0.0.1:$CHAT_PORT/v1"
    exit 0
  fi
  echo "levantando spark 4B..."
  systemctl --user start "$CHAT_UNIT" || { echo "fallo al iniciar $CHAT_UNIT"; exit 1; }
  for _ in $(seq 1 90); do
    curl -sf -m 2 "http://127.0.0.1:$CHAT_PORT/health" >/dev/null 2>&1 && break
    sleep 2
  done
  if ! curl -sf -m 2 "http://127.0.0.1:$CHAT_PORT/health" >/dev/null 2>&1; then
    echo "no respondio. Revisa: journalctl --user -u $CHAT_UNIT -n 50"
    exit 1
  fi
  echo "listo: http://127.0.0.1:$CHAT_PORT/v1  (VRAM $(vram_human))"
  ;;
restart)
  # Sintoma tipico: la generacion cae de ~50 a ~5 tok/s porque el modelo quedo
  # parcialmente en GTT (RAM del sistema) cuando otra app pidio VRAM. Reiniciar
  # reasigna los buffers en VRAM y vuelve a la velocidad normal.
  echo "reiniciando $CHAT_UNIT..."
  systemctl --user restart "$CHAT_UNIT" || { echo "fallo el restart"; exit 1; }
  for _ in $(seq 1 60); do
    curl -sf -m 2 "http://127.0.0.1:$CHAT_PORT/health" >/dev/null 2>&1 && break
    sleep 2
  done
  if ! curl -sf -m 2 "http://127.0.0.1:$CHAT_PORT/health" >/dev/null 2>&1; then
    echo "no respondio. Revisa: journalctl --user -u $CHAT_UNIT -n 50"
    exit 1
  fi
  echo "listo: VRAM $(vram_human)"
  ;;
off)
  if systemctl --user is-active --quiet "$CHAT_UNIT"; then
    echo "parando $CHAT_UNIT..."
    systemctl --user stop "$CHAT_UNIT"
  else
    echo "$CHAT_UNIT ya estaba parado."
  fi
  echo "VRAM libre: $(vram_human) en uso"
  ;;
status)
  printf '%-7s (:%s): ' "chat" "$CHAT_PORT"
  if systemctl --user is-active --quiet "$CHAT_UNIT"; then
    local_m=$(curl -sf -m 3 "http://127.0.0.1:$CHAT_PORT/v1/models" 2>/dev/null |
      sed -n 's/.*"id":"\([^"]*\)".*/\1/p' | head -1)
    echo "activo (${local_m:-?})"
  else
    echo "parado"
  fi
  echo "vram   : $(vram_human)"
  # GTT = buffers del modelo que cayeron a RAM del sistema. Si crece (> 2 GB)
  # la generacion se arrastra: `local-ai restart` lo corrige.
  if [ -r /sys/class/drm/card1/device/mem_info_gtt_used ]; then
    echo "gtt    : $(awk -v b="$(cat /sys/class/drm/card1/device/mem_info_gtt_used)" 'BEGIN { printf "%.1f GB", b/1073741824 }')"
  fi
  ;;
*) usage ;;
esac
