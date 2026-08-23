#!/usr/bin/env bash
# Rota el wallpaper de Caelestia: elige una foto aleatoria de ~/Imágenes/wallpapers
# y apunta el symlink ~/.local/state/caelestia/wallpaper/current hacia ella.
# También copia el wallpaper a ~/.cache/hypr/wallpaper.jpg para que hyprlock
# (pantalla de bloqueo) muestre el mismo fondo.

WALL_DIR="$HOME/Imágenes/wallpapers"
STATE_DIR="$HOME/.local/state/caelestia/wallpaper"
LOCK_WALL="$HOME/.cache/hypr/wallpaper.jpg"

mkdir -p "$STATE_DIR" "$(dirname "$LOCK_WALL")"

if [ ! -d "$WALL_DIR" ] || [ -z "$(ls -A "$WALL_DIR" 2>/dev/null)" ]; then
    exit 0
fi

# Elige una imagen al azar
PICK=$(find "$WALL_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | shuf -n 1)

if [ -n "$PICK" ]; then
    ln -sf "$PICK" "$STATE_DIR/current"
    echo "$PICK" > "$STATE_DIR/path.txt"
    cp "$PICK" "$LOCK_WALL"
    # Regenerar colores Material You (Caelestia) desde el nuevo wallpaper
    command -v caelestia >/dev/null 2>&1 && caelestia scheme set -n dynamic
fi
