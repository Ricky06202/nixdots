#!/usr/bin/env bash
# caelestia-dark-guard — devuelve Caelestia a modo oscuro si algo lo pasa a claro.
#
# Por que: al cambiar el wallpaper desde la GUI de Caelestia el modo "smart"
# elige dark/light segun la luminancia de la imagen, y con fondos claros te
# deja la interfaz en claro. La rotacion por timer ya fuerza dark (wallpaper-pick
# usa --no-smart), pero la GUI no, asi que este guardia cierra ese agujero.
#
# Lo dispara un systemd path unit sobre ~/.local/state/caelestia/scheme.json:
# cada vez que el esquema se reescribe, se mira el modo. Si quedo en light, se
# fuerza dark conservando nombre/flavour/variant.
set -uo pipefail

SCHEME="${XDG_STATE_HOME:-$HOME/.local/state}/caelestia/scheme.json"
[ -r "$SCHEME" ] || exit 0

# "mode": "light" (con o sin espacios). Evita depender de jq.
grep -Eq '"mode"[[:space:]]*:[[:space:]]*"light"' "$SCHEME" || exit 0

caelestia scheme set -m dark >/dev/null 2>&1 || {
  echo "caelestia-dark-guard: no pude forzar dark (caelestia no responde)" >&2
  exit 1
}
echo "caelestia-dark-guard: modo claro detectado, restaurado a oscuro"
