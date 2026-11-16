#!/usr/bin/env bash
# local-ai chat|off|status — reparte la RX 7600 (8 GB) entre dos cosas que NO
# caben juntas:
#   jan    Jan/TwIL 8B, ctx 131072 ... ~7.5 GB  (chat largo, 16 tok/s)
#   chat   Spark-X2.6 4B, ctx 131072 .. ~7.5 GB  (local, 54 tok/s corto)
#
#   local-ai chat    -> apara Jan, levanta llama-chat (:8091), espera /health
#   local-ai off     -> para el modelo, arranca Jan y precarga TwIL
#   local-ai status  -> que hay cargado y cuanto ocupa la GPU
#
# Lo usa el provider `local` de opencode (http://127.0.0.1:8091/v1).
# El servicio `llama-chat` lo declara nixdots (home/default.nix, solo host amd)
# y no arranca solo: lo levanta este script.
set -uo pipefail

CHAT_UNIT=llama-chat
CHAT_PORT=8091
CHAT_MODEL="$HOME/Dev/models/Spark-X2.6-4B-Q4_K_M.gguf"
VRAM_FREE_LIMIT=3000000000   # 3 GB: por debajo se asume que Jan ya solto la GPU

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

# Apara Jan y espera a que la GPU quede libre.
free_gpu() {
  if systemctl --user is-active --quiet jan-desktop; then
    echo "aparcando Jan (TwIL) para liberar VRAM..."
    systemctl --user stop jan-desktop
    for _ in $(seq 1 30); do
      pgrep -f 'jan-llama-worker --preset' >/dev/null || break
      sleep 1
    done
  fi
  for _ in $(seq 1 20); do
    [ "$(vram_used)" -lt "$VRAM_FREE_LIMIT" ] && return 0
    sleep 1
  done
}

start_model() {
  local unit=$1 port=$2 model=$3 label=$4
  [ -f "$model" ] || { echo "falta el modelo: $model"; exit 1; }
  systemctl --user cat "$unit" >/dev/null 2>&1 || {
    echo "no existe el servicio $unit."
    echo "aplica el rebuild: sudo nixos-rebuild switch --flake ~/Dev/nixdots#amd"
    exit 1
  }
  if systemctl --user is-active --quiet "$unit"; then
    echo "$label ya esta corriendo en http://127.0.0.1:$port/v1"
    exit 0
  fi
  free_gpu
  echo "levantando $label..."
  systemctl --user start "$unit" || { echo "fallo al iniciar $unit"; exit 1; }
  for _ in $(seq 1 90); do
    curl -sf -m 2 "http://127.0.0.1:$port/health" >/dev/null 2>&1 && break
    sleep 2
  done
  if ! curl -sf -m 2 "http://127.0.0.1:$port/health" >/dev/null 2>&1; then
    echo "$label no respondio. Revisa: journalctl --user -u $unit -n 50"
    exit 1
  fi
  echo "$label listo: http://127.0.0.1:$port/v1  (VRAM $(vram_human))"
}

start_jan() {
  if systemctl --user is-active --quiet jan-desktop; then
    echo "Jan ya esta corriendo."
  elif command -v Jan-Desktop >/dev/null 2>&1; then
    echo "arrancando Jan..."
    systemd-run --user --unit=jan-desktop --collect \
      --description="Jan (asistente local)" Jan-Desktop >/dev/null 2>&1 || true
  else
    echo "Jan-Desktop no esta en PATH; no arranco nada."
    return 0
  fi
  echo "precargando TwIL (jan-preload)..."
  JAN_PRELOAD_DELAY=0 setsid nohup "$HOME/.config/hypr/jan-preload.sh" \
    >/dev/null 2>&1 < /dev/null &
  echo "listo: Jan vuelve a estar disponible para chatear."
}

status_one() {
  local unit=$1 port=$2 label=$3
  printf '%-7s (:%s): ' "$label" "$port"
  if systemctl --user is-active --quiet "$unit"; then
    local m
    m=$(curl -sf -m 3 "http://127.0.0.1:$port/v1/models" 2>/dev/null |
      sed -n 's/.*"id":"\([^"]*\)".*/\1/p' | head -1)
    echo "activo (${m:-?})"
  else
    echo "parado"
  fi
}

case "${1:-}" in
chat)   start_model "$CHAT_UNIT" "$CHAT_PORT" "$CHAT_MODEL" "chat (spark 4B)" ;;
off)
  if systemctl --user is-active --quiet "$CHAT_UNIT"; then
    echo "parando $CHAT_UNIT..."
    systemctl --user stop "$CHAT_UNIT"
  fi
  start_jan
  ;;
status)
  status_one "$CHAT_UNIT" "$CHAT_PORT" "chat"
  printf '%-7s: ' "jan"
  if systemctl --user is-active --quiet jan-desktop; then
    pgrep -f 'jan-llama-worker --preset' >/dev/null &&
      echo "activo (worker arriba)" || echo "activo (sin worker)"
  else
    echo "parado"
  fi
  echo "vram   : $(vram_human)"
  ;;
*) usage ;;
esac
