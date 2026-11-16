#!/usr/bin/env bash
# oc-web [puerto] — interfaz web de opencode (v2) contra el modelo local.
#
# Hace las tres cosas: levanta Spark en :8091 si hace falta (`local-ai chat`),
# arranca `opencode serve` en :4096 y abre el navegador.
# Es la misma config de opencode (agentes, provider `local`, permisos): solo
# cambia la interfaz.
set -uo pipefail

PORT="${1:-4096}"
URL="http://127.0.0.1:${PORT}/"

# 1. El modelo local primero: si no esta, la UI abre pero no responde nada.
if ! systemctl --user is-active --quiet llama-chat; then
  "$HOME/.local/bin/local-ai" chat || exit 1
fi

# 2. Servidor web de opencode (idempotente: si ya responde, no hace nada).
if ! curl -sf -m 2 "$URL" >/dev/null 2>&1; then
  systemctl --user reset-failed opencode-web.service >/dev/null 2>&1 || true
  systemd-run --user --unit=opencode-web --collect \
    opencode serve --hostname 127.0.0.1 --port "$PORT" >/dev/null || {
    echo "no se pudo arrancar opencode serve"
    exit 1
  }
  for _ in $(seq 1 40); do
    curl -sf -m 2 "$URL" >/dev/null 2>&1 && break
    sleep 1
  done
fi

if ! curl -sf -m 2 "$URL" >/dev/null 2>&1; then
  echo "la web de opencode no respondio. Revisa: journalctl --user -u opencode-web -n 40"
  exit 1
fi

echo "opencode web: $URL"
echo "modelo      : local/spark-4b (elegilo en /models si no esta seleccionado)"
command -v xdg-open >/dev/null 2>&1 &&
  setsid nohup xdg-open "$URL" >/dev/null 2>&1 < /dev/null &
