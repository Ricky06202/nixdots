# AGENTS.md — nixdots

Guía para IAs (opencode, etc.) que trabajen en este repo.

## Qué es este repo

Config NixOS **multi-host** con flakes. Un solo flake define dos máquinas:

- `laptop` — Intel HD 5500 (iGPU) + NVIDIA 940M (PRIME offload, legacy_580)
- `amd` — CPU + GPU AMD (amdgpu nativo)

**Ya NO hay branches por máquina**: el host se elige con `#laptop` o `#amd`.

## Reglas de oro

1. Todo es declarativo. Nada de editar paquetes a mano.
2. Lo compartido va en `shared/default.nix` y `home/default.nix`.
   Lo específico de una máquina, SOLO en `hosts/<nombre>/`.
3. Si un cambio aplica a ambos hosts, edítalo UNA vez (para eso existe este repo).
4. Cosas por-host dentro de `home/` se resuelven con el argumento `hostName`
   (ej: MangoHUD conf distinto, aliases `nvidia-offload` solo en laptop).
5. `hardware-configuration.nix` NO se copia entre hosts — cada uno genera el
   suyo (`nixos-generate-config`) y no se toca salvo que cambie el disco.
6. Repo PÚBLICO: jamás commitear tokens, passwords o claves.

## Validar cambios

```bash
# Evaluar ambos hosts (rápido, no compila):
nix flake check

# Buildear solo evaluación del host amd sin aplicar:
nix build .#nixosConfigurations.amd.config.system.build.toplevel --dry-run
```

## Aplicar

```bash
sudo nixos-rebuild switch --flake .#laptop   # en el laptop
sudo nixos-rebuild switch --flake .#amd      # en la PC AMD
```

## Notas técnicas importantes

- **RustDesk**: envuelto con `symlinkJoin + wrapProgram` para forzar XWayland
  (bug upstream: el grab de teclado usa APIs X11 y falla como app Wayland).
  No "simplificar" quitando el wrapper.
- **Steam laptop**: envuelto con PRIME offload vars para usar la NVIDIA desde
  el launcher. En amd NO existe ese wrapper.
- **MangoHUD**: conf por host vía `hostName`. Laptop = fps_limit 30 +
  no_display. AMD = sin límite.
- **zsh**: oh-my-zsh via home-manager; NO añadir alias `z` (pisa la función de
  zoxide y rompe el salto de directorios). Highlight/autosuggest son nativos
  de home-manager, NO plugins de omz.
- **Caelestia/caelestia-cli**: inputs de flake, no paquetes de nixpkgs.
- El alias `update` reconstruye el host local automáticamente.
