#!/usr/bin/env bash
# Salida HEADLESS de Hyprland: monitor fantasma donde se renderiza la
# instancia de Warframe de mi hermana. Sunshine (capSysAdmin) la captura por
# KMS igual que un monitor fisico, pero no se ve en el HDMI-A-1: cero pelea
# de foco con la partida mia.
#
# Idempotente: se ejecuta en cada carga/reload de la config y solo crea la
# salida si no existe.

# Primer headless que exista (HEADLESS-1 normally; si reload, el nombre puede
# conservar el ya creado y no hace falta nada).
if hyprctl monitors 2>/dev/null | grep -q '^Monitor HEADLESS'; then
  exit 0
fi

created=""
for _ in 1 2 3 4 5; do
  hyprctl output create headless 2>/dev/null || true
  sleep 0.3
  if out="$(hyprctl monitors 2>/dev/null | grep -oP '^Monitor \KHEADLESS-\d+' | head -n1)"; then
    created="$out"
    break
  fi
  sleep 0.4
done

[ -n "$created" ] || exit 0

# La cabecera monitors-amd.lua ya declara el modo 1920x1080@60 para
# HEADLESS-1; se re-aplica explicitamente por si la salida nacio con el
# default de 1280x720. Formato Lua (Hyprland 0.56 ya no usa keyword).
# OJO a la posicion: 1920x0 (pegado a la DERECHA del HDMI-A-1). Si queda en
# 0x0 se solapa con el monitor real y el hyprland-share-picker de Discord
# dibuja dos cuadros encima: compartias "tu pantalla" y capturabas el monitor
# fantasma de ella.
hyprctl eval "hl.monitor({ output = \"$created\", mode = \"1920x1080@60\", position = \"1920x0\", scale = 1 })" 2>/dev/null || true
