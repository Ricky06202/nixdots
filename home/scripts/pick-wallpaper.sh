#!/usr/bin/env bash
# Selecciona un wallpaper aleatorio de ~/Imágenes/wallpapers/ y lo pone para el greeter ReGreet.
# Se ejecuta como servicio systemd antes de greetd.service.
# USO DE GLOBS (no find): en este sistema find no puede leer el contenido de
# ese directorio (lo ve vacío) y el greeter se quedaba en negro.

WALLPAPER_DIR="/home/ricky/Imágenes/wallpapers"
REGREET_BG="/var/lib/regreet/background.jpg"

mkdir -p "$(dirname "$REGREET_BG")"

WALLPAPERS=()
if [ -d "$WALLPAPER_DIR" ]; then
  for pattern in '*.jpg' '*.jpeg' '*.png' '*.webp' '*.JPG' '*.JPEG' '*.PNG' '*.WEBP'; do
    for img in "$WALLPAPER_DIR"/$pattern; do
      [ -f "$img" ] && WALLPAPERS+=("$img")
    done
  done
fi

if [ ${#WALLPAPERS[@]} -gt 0 ]; then
  RANDOM_WP="${WALLPAPERS[$(( RANDOM % ${#WALLPAPERS[@]} ))]}"
  cp "$RANDOM_WP" "$REGREET_BG"
  chmod 644 "$REGREET_BG"
  echo "pick-wallpaper: copiado '$RANDOM_WP' -> $REGREET_BG" >&2
else
  echo "pick-wallpaper: sin wallpapers en $WALLPAPER_DIR" >&2
fi