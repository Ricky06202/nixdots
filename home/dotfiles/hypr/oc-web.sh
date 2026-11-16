#!/usr/bin/env bash
# oc-web [puerto] — interfaz web de opencode (v2) contra el modelo local.
#
# Hace las tres cosas: levanta Spark en :8091 si hace falta (`local-ai chat`),
# arranca `opencode serve` en :4096 y abre el navegador ya autenticado.
# Es la misma config de opencode (agentes, provider `local`, permisos): solo
# cambia la interfaz.
#
# OJO con la clave: `opencode serve` genera una password aleatoria en cada
# arranque y la web la pide en un login. Acá se fija con
# OPENCODE_SERVER_PASSWORD y se abre http://opencode:<pw>@127.0.0.1:<puerto>/
# (HTTP Basic), así el navegador la manda sola. Solo escucha en loopback.
set -uo pipefail

PORT="${1:-4096}"
URL="http://127.0.0.1:${PORT}/"
PASSWORD="spark"

# 1. El modelo local primero: si no esta, la UI abre pero no responde nada.
if ! systemctl --user is-active --quiet llama-chat; then
  "$HOME/.local/bin/local-ai" chat || exit 1
fi

# 2. Servidor web de opencode con password fija.
running=no
curl -sf -m 2 -u "opencode:$PASSWORD" "$URL" >/dev/null 2>&1 && running=yes
if [ "$running" = no ]; then
  # Si hay otra instancia con password aleatoria, se reemplaza por la nuestra.
  systemctl --user stop opencode-web.service >/dev/null 2>&1 || true
  systemctl --user reset-failed opencode-web.service >/dev/null 2>&1 || true
  systemd-run --user --unit=opencode-web --collect \
    --setenv="OPENCODE_SERVER_PASSWORD=$PASSWORD" \
    opencode serve --hostname 127.0.0.1 --port "$PORT" >/dev/null || {
    echo "no se pudo arrancar opencode serve"
    exit 1
  }
  for _ in $(seq 1 40); do
    curl -sf -m 2 -u "opencode:$PASSWORD" "$URL" >/dev/null 2>&1 && break
    sleep 1
  done
fi

if ! curl -sf -m 2 -u "opencode:$PASSWORD" "$URL" >/dev/null 2>&1; then
  echo "la web de opencode no respondio. Revisa: journalctl --user -u opencode-web -n 40"
  exit 1
fi

AUTH_URL="http://opencode:${PASSWORD}@127.0.0.1:${PORT}/"
echo "opencode web: $AUTH_URL"
echo "clave       : $PASSWORD  (si el navegador la pide a mano)"
echo "modelo      : local/spark-4b (elegilo en /models si no esta seleccionado)"
command -v xdg-open >/dev/null 2>&1 &&
  setsid nohup xdg-open "$AUTH_URL" >/dev/null 2>&1 < /dev/null &
