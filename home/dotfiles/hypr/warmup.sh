#!/usr/bin/env bash
# Precalienta la cache de pagina (page cache) con los binarios de las apps
# habituales para que arranquen mas rapido en frio.
# Uso: se lanza desde exec-once de Hyprland. La cache se evacua sola si se
# necesita RAM, asi que es inofensivo para la memoria disponible.

sleep 4

for app in vivaldi discord karere spotify steam; do
    cmd=$(command -v "$app" 2>/dev/null) || continue
    dd if="$cmd" of=/dev/null bs=4M 2>/dev/null
    ldd "$cmd" 2>/dev/null | awk '/=> \//{print $3}' | while read -r lib; do
        dd if="$lib" of=/dev/null bs=4M 2>/dev/null
    done
done
