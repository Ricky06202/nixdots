#!/usr/bin/env bash
# Desmonta y elimina el loop device de una imagen montada (inverso de mount-iso.sh).
# Con un .iso: busca el loop ligado al archivo (losetup -j).
# Con una carpeta: busca el loop cuyo mountpoint es esa carpeta (findmnt -T).
# El "eject" de Nemo solo desmonta y deja el loop colgado en Dispositivos;
# esta acción lo desmonta Y lo borra de una.
# Uso: unmount-iso.sh [imagen-o-carpeta...]

set -u

find_loop_for_file() {
  losetup -j "$1" 2>/dev/null | sed -n '1s/:.*//p'
}

find_loop_for_dir() {
  local src
  src="$(findmnt -n -T "$1" -o SOURCE 2>/dev/null)" || return 1
  case "$src" in
    /dev/loop*) echo "$src" ;;
  esac
}

for TARGET in "$@"; do
  LOOP=""
  if [ -f "$TARGET" ]; then
    LOOP="$(find_loop_for_file "$TARGET")"
  elif [ -d "$TARGET" ]; then
    LOOP="$(find_loop_for_dir "$TARGET")"
  fi

  if [ -z "$LOOP" ]; then
    notify-send -a Nemo "Desmontar imagen" "Sin loop device para: $TARGET" -t 4000
    continue
  fi

  udisksctl unmount -b "$LOOP" --no-user-interaction >/dev/null 2>&1 || true
  if udisksctl loop-delete -b "$LOOP" --no-user-interaction >/dev/null 2>&1; then
    notify-send -a Nemo "Desmontar imagen" "Desmontada y eliminada: $LOOP" -t 4000
  else
    notify-send -a Nemo "Desmontar imagen" "No se pudo eliminar $LOOP (¿se sigue usando?)" -t 4000
  fi
done