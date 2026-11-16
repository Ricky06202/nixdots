#!/usr/bin/env bash
# ia-toggle — prende/apaga el modelo local (Spark) de un solo toque.
# Pensado para el lanzador de Caelestia, un atajo de Hyprland o un .desktop.
#
# Contexto: Spark ocupa ~7.5 de los 8 GB de VRAM. Con la IA prendida los juegos
# y Sunshine van mal; con la IA apagada opencode/nini/el celular no tienen
# modelo. Esto cambia entre los dos estados y avisa con una notificacion.
set -uo pipefail

notify() {
  command -v notify-send >/dev/null 2>&1 &&
    notify-send -a "IA local" "$1" "$2" 2>/dev/null
  echo "$1: $2"
}

if systemctl --user is-active --quiet llama-chat; then
  if "$HOME/.local/bin/local-ai" off >/dev/null 2>&1; then
    notify "IA local apagada" "GPU liberada para juegos/streaming."
  else
    notify "No se pudo apagar" "Revisa journalctl --user -u llama-chat."
    exit 1
  fi
else
  if "$HOME/.local/bin/local-ai" chat >/dev/null 2>&1; then
    notify "IA local encendida" "Spark cargado en la GPU (opencode, nini y el celular listos)."
  else
    notify "No se pudo encender" "Revisa journalctl --user -u llama-chat."
    exit 1
  fi
fi
