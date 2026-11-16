#!/usr/bin/env bash
# local-ai chat|off|status — maneja el unico modelo local de la maquina.
#
#   chat   Spark-X2.6 4B Q4_K_M, ctx 131072, KV q8_0 ... ~7.5 GB (GPU entera)
#
# Lo usa el provider `local` de opencode (:8091) y el panel de agente de Zed.
# El servicio `llama-chat` lo declara nixdots (home/default.nix, solo host amd)
# y NO arranca solo: lo levanta este script.
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
  echo "uso: local-ai chat|off|status"
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
  ;;
*) usage ;;
esac
