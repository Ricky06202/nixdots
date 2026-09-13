#!/usr/bin/env bash
# Rota el wallpaper de Caelestia: elige una foto aleatoria de ~/Imágenes/wallpapers
# y delega en el CLI nativo (caelestia wallpaper -f), que regenera los colores
# Material You (dynamic) y el thumbnail, igual que la rotación desde la GUI.
# También copia el wallpaper a ~/.cache/hypr/wallpaper.jpg para que hyprlock
# (pantalla de bloqueo) muestre el mismo fondo.

WALL_DIR="$HOME/Imágenes/wallpapers"
LOCK_WALL="$HOME/.cache/hypr/wallpaper.jpg"

mkdir -p "$(dirname "$LOCK_WALL")"

if [ ! -d "$WALL_DIR" ] || [ -z "$(ls -A "$WALL_DIR" 2>/dev/null)" ]; then
    exit 0
fi

# Elige una imagen al azar
PICK=$(find "$WALL_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | shuf -n 1)

if [ -n "$PICK" ]; then
    # Delegar en el CLI nativo (actualiza current/path.txt/thumbnail y regenera
    # los colores dynamic). Si el CLI no está en el PATH, volver al symlink a mano.
    if command -v caelestia >/dev/null 2>&1; then
        # Asegurar scheme dynamic para que la rotación devuelva colores Material You
        caelestia scheme set -n dynamic 2>/dev/null || true
        # --no-smart: regenera colores dynamic desde el wallpaper sin cambiar a
        # modo claro (evita flashbang). El modo/variant se mantienen como están.
        caelestia wallpaper -f "$PICK" --no-smart
    else
        STATE_DIR="$HOME/.local/state/caelestia/wallpaper"
        mkdir -p "$STATE_DIR"
        ln -sf "$PICK" "$STATE_DIR/current"
        echo "$PICK" > "$STATE_DIR/path.txt"
    fi
    cp "$PICK" "$LOCK_WALL"
fi