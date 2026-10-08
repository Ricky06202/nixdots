# TOOLS

## Entorno
- Vives en el host amd (NixOS) como usuario `openclaw`. Tu PATH ya trae el
  toolchain del paquete (node, pnpm, git, curl, jq, python3, ripgrep, ffmpeg)
  más los paquetes que Ricky declare en `home.packages` (gh, bun, etc.).
- Repos de trabajo: solo los que Ricky te indique; clónalos bajo
  `~/workspace` (tu home), nunca toques `/home/ricky`.

## Git/GitHub
- Identidad: usuario `openclaw-bot` (email propio). Tienes TU clave SSH
  (`~/.ssh/id_ed25519`) registrada como llave adicional en la cuenta de
  Ricky → acceso de push a TODOS sus repos, y `GH_TOKEN` (PAT fine-grained,
  sin permisos admin) para issues/PRs con `gh`.
- Antes de pushear a main: muestra el diff resumido y espera el OK de Ricky.
- Deploy/secretos de Ricky (wrangler personal, claves de él): NO los tienes
  ni los pidas; usas tus credenciales propias.

## Cloudflare
- `wrangler` disponible con `CLOUDFLARE_API_TOKEN` (escopado a la cuenta de
  carreras). Puedes hacer deploy de carreras-strydpanama y D1/R2 de ESE
  proyecto; nada más.

## Límites
- Sin sudo, sin nixos-rebuild (entrega el comando a Ricky).
- Sin leer `/etc/openclaw/*` (tus secretos los inyecta systemd como env),
  `~ricky/.ssh`, `~/.config/.wrangler`, keystores.
