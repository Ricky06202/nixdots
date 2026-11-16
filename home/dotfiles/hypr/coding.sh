#!/usr/bin/env bash
# coding on|off|status — alterna la GPU entre Jan (TwIL 8B, chat) y el coder
# local (Qwen3-Coder-30B-A3B, llama.cpp/Vulkan).
#
# Por que existe: la RX 7600 tiene 8 GB. TwIL con ctx 131072 ocupa ~7.4 GB y el
# coder MoE ~7 GB con --n-cpu-moe 40. No caben juntos, asi que se aparca uno
# mientras se usa el otro.
#
#   coding on    -> para Jan, levanta llama-coder (:8090) y espera /health
#   coding off   -> para el coder, arranca Jan y precarga TwIL
#   coding status-> que hay cargado y cuanto ocupa la GPU
#
# El servicio `llama-coder` lo declara nixdots (home/default.nix, solo host amd);
# no arranca solo: se inicia a mano con `coding on`.
set -uo pipefail

UNIT=llama-coder
PORT=8090
MODEL="$HOME/Dev/models/Qwen3-Coder-30B-A3B-Instruct-UD-Q4_K_XL.gguf"
VRAM_LIMIT_FREE=3000000000   # 3 GB: por debajo se asume que Jan ya solto la GPU

vram_used() {
  for f in /sys/class/drm/card*/device/mem_info_vram_used; do
    [ -r "$f" ] && { cat "$f"; return; }
  done
  echo 0
}

vram_human() {
  local b
  b=$(vram_used)
  awk -v b="$b" 'BEGIN { printf "%.1f GB", b/1073741824 }'
}

usage() {
  echo "uso: coding on|off|status"
  exit 2
}

case "${1:-}" in
on)
  [ -f "$MODEL" ] || { echo "falta el modelo: $MODEL"; exit 1; }
  systemctl --user cat "$UNIT" >/dev/null 2>&1 || {
    echo "no existe el servicio $UNIT."
    echo "aplica el rebuild: sudo nixos-rebuild switch --flake ~/Dev/nixdots#amd"
    exit 1
  }
  if systemctl --user is-active --quiet "$UNIT"; then
    echo "el coder ya esta corriendo en http://127.0.0.1:$PORT/v1"
    exit 0
  fi

  if systemctl --user is-active --quiet jan-desktop; then
    echo "aparcando Jan (TwIL) para liberar VRAM..."
    systemctl --user stop jan-desktop
    for _ in $(seq 1 30); do
      pgrep -f 'jan-llama-worker --preset' >/dev/null || break
      sleep 1
    done
  fi
  for _ in $(seq 1 20); do
    [ "$(vram_used)" -lt "$VRAM_LIMIT_FREE" ] && break
    sleep 1
  done

  echo "levantando el coder (carga ~16 GB por mmap, tarda un poco)..."
  systemctl --user start "$UNIT" || { echo "fallo al iniciar $UNIT"; exit 1; }
  for _ in $(seq 1 180); do
    curl -sf -m 2 "http://127.0.0.1:$PORT/health" >/dev/null 2>&1 && break
    sleep 2
  done
  if ! curl -sf -m 2 "http://127.0.0.1:$PORT/health" >/dev/null 2>&1; then
    echo "el coder no respondio. Revisa: journalctl --user -u $UNIT -n 50"
    exit 1
  fi
  echo "coder listo: http://127.0.0.1:$PORT/v1  (modelo: qwen3-coder, VRAM $(vram_human))"
  ;;

off)
  if systemctl --user is-active --quiet "$UNIT"; then
    echo "parando el coder..."
    systemctl --user stop "$UNIT"
  fi
  if ! systemctl --user is-active --quiet jan-desktop; then
    if command -v Jan-Desktop >/dev/null 2>&1; then
      echo "arrancando Jan..."
      systemd-run --user --unit=jan-desktop --collect \
        --description="Jan (asistente local)" \
        Jan-Desktop >/dev/null 2>&1 || true
    else
      echo "Jan-Desktop no esta en PATH; no arranco nada."
      exit 0
    fi
  fi
  echo "precargando TwIL (jan-preload)..."
  JAN_PRELOAD_DELAY=0 nohup "$HOME/.config/hypr/jan-preload.sh" >/dev/null 2>&1 &
  echo "listo: Jan vuelve a estar disponible para chatear."
  ;;

status)
  printf 'coder  (:%s): ' "$PORT"
  if systemctl --user is-active --quiet "$UNIT"; then
    models=$(curl -sf -m 3 "http://127.0.0.1:$PORT/v1/models" 2>/dev/null | sed -n 's/.*"id":"\([^"]*\)".*/\1/p' | head -1)
    echo "activo (modelo ${models:-?})"
  else
    echo "parado"
  fi
  printf 'jan           : '
  if systemctl --user is-active --quiet jan-desktop; then
    loaded=$(pgrep -f 'jan-llama-worker --preset' >/dev/null && echo "worker arriba" || echo "sin worker")
    echo "activo ($loaded)"
  else
    echo "parado"
  fi
  echo "vram          : $(vram_human)"
  ;;

*)
  usage
  ;;
esac
