#!/usr/bin/env bash
# Selecciona un wallpaper aleatorio de ~/Imágenes/wallpapers/ y lo pone para el greeter ReGreet.
# Se ejecuta como servicio systemd antes de greetd.service.

WALLPAPER_DIR="/home/ricky/Imágenes/wallpapers"
REGREET_BG="/var/lib/regreet/background.jpg"

# Crear directorio si no existe
mkdir -p "$(dirname "$REGREET_BG")"

if [ -d "$WALLPAPER_DIR" ]; then
  WALLPAPERS=()
  for ext in jpg jpeg png webp; do
    while IFS= read -r -d '' img; do
      WALLPAPERS+=("$img")
    done < <(find "$WALLPAPER_DIR" -maxdepth 1 -iname "*.$ext" -print0 2>/dev/null)
  done

  if [ ${#WALLPAPERS[@]} -gt 0 ]; then
    RANDOM_WP="${WALLPAPERS[$(( RANDOM % ${#WALLPAPERS[@]} ))]}"
    cp "$RANDOM_WP" "$REGREET_BG"
    chmod 644 "$REGREET_BG"
  fi
fi