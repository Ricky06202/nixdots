#!/usr/bin/env bash
# Rota el wallpaper de Caelestia: elige una foto aleatoria de ~/Imágenes/wallpapers
# y delega en el CLI nativo (caelestia wallpaper -f), que regenera los colores
# Material You (dynamic) y el thumbnail, igual que la rotación desde la GUI.
# También copia el wallpaper a ~/.cache/hypr/wallpaper.jpg para que hyprlock
# (pantalla de bloqueo) muestre el mismo fondo.

WALL_DIR="$HOME/Imágenes/wallpapers"
LOCK_WALL="$HOME/.cache/hypr/wallpaper.jpg"
STATE_DIR="$HOME/.local/state/caelestia/wallpaper"

mkdir -p "$(dirname "$LOCK_WALL")"

if [ ! -d "$WALL_DIR" ] || [ -z "$(ls -A "$WALL_DIR" 2>/dev/null)" ]; then
    exit 0
fi

# Elige una imagen al azar (los wallpapers son symlinks al store: usar find -L /
# -type f o -type l para no dejarlos fuera, y excluir los .hm-bak de home-manager).
# Incluye los videos animados de Animated/ (maxdepth 2): el CLI de Caelestia ya
# distingue is_video y genera su thumbnail. Mezcla natural (1 video en el pool).
PICK=$(find -L "$WALL_DIR" -maxdepth 2 -type f ! -name "*.hm-bak" \
    \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \
       -o -iname "*.mp4" -o -iname "*.webm" -o -iname "*.mkv" \) 2>/dev/null | shuf -n 1)

if [ -n "$PICK" ]; then
    # Delegar en el CLI nativo (actualiza current/path.txt/thumbnail y regenera
    # los colores dynamic). Si el CLI no está en el PATH, volver al symlink a mano.
    if command -v caelestia >/dev/null 2>&1; then
        # Asegurar scheme dynamic en modo OSCURO: la rotación devuelve colores
        # Material You sin salirse del dark (aunque el state traiga light).
        caelestia scheme set -n dynamic -m dark 2>/dev/null || true
        # --no-smart: regenera colores dynamic desde el wallpaper sin cambiar a
        # modo claro (evita flashbang). El modo/variant se mantienen como están.
        caelestia wallpaper -f "$PICK" --no-smart
        # Re-evaluar hyprland.lua: relee scheme/current.lua y actualiza bordes.
        # El autostart está en hl.on('hyprland.start'), así que no se repite.
        hyprctl reload
    else
        STATE_DIR="$HOME/.local/state/caelestia/wallpaper"
        mkdir -p "$STATE_DIR"
        ln -sf "$PICK" "$STATE_DIR/current"
        echo "$PICK" > "$STATE_DIR/path.txt"
    fi
    # hyprlock solo muestra imágenes: si el elegido es video, copiar el
    # thumbnail que Caelestia genera (está como symlink actual en el state).
    case "${PICK##*.}" in
        mp4|webm|mkv)   cp "$STATE_DIR/thumbnail.jpg" "$LOCK_WALL" ;;
        *)              cp "$PICK" "$LOCK_WALL" ;;
    esac
fi