#!/usr/bin/env bash
# reminder-fire.sh <id> <once|repeat> "<texto>"
# Lo invoca el timer systemd user remind-<id>.timer. Notifica, deja constancia
# en fired.log y, si es one-shot, se autoelimina y marca el recordatorio done.
set -u

id="${1:-}"
mode="${2:-repeat}"
shift 2 2>/dev/null || true
text="${*:-Recordatorio}"
[ -z "$id" ] && exit 1

memdir="$HOME/.config/opencode/memory"
mkdir -p "$memdir"

# Ambiente D-Bus (los timers no heredan el entorno gráfico de la sesión).
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$XDG_RUNTIME_DIR/bus}"

find_cmd() {
  local c
  for c in "$1" "$HOME/.local/bin/$1" \
           "/etc/profiles/per-user/$(id -un)/bin/$1" \
           "/run/current-system/sw/bin/$1"; do
    command -v "$c" >/dev/null 2>&1 && { printf '%s' "$c"; return 0; }
  done
  return 1
}

sent=0
# Canal nativo del shell Caelestia (popup propio, no depende de DISPLAY).
if CAE="$(find_cmd caelestia)" && [ -n "$CAE" ]; then
  if timeout 10 "$CAE" shell toaster info "Recordatorio" "$text" "" >/dev/null 2>&1; then
    sent=1
  fi
fi
# Fallback estándar.
if [ "$sent" -eq 0 ]; then
  if NS="$(find_cmd notify-send)" && [ -n "$NS" ]; then
    timeout 10 "$NS" -A opencode -u critical "Recordatorio" "$text" \
      >/dev/null 2>&1 || true
  fi
fi

echo "$(date -Is) $id $text" >> "$memdir/fired.log"

if [ "$mode" = "once" ]; then
  systemctl --user disable --now "remind-$id.timer" || true
  rm -f "$HOME/.config/systemd/user/remind-$id.service" \
        "$HOME/.config/systemd/user/remind-$id.timer"
  systemctl --user daemon-reload || true
  [ -f "$memdir/reminders.md" ] && \
    sed -i "s/^\(- id=$id .*status=\\)active/\\1done/" "$memdir/reminders.md"
fi
