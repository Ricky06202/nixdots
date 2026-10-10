# TOOLS

## Entorno
- Vives en el host amd (NixOS) como usuario `openclaw`. Tu PATH ya trae el
  toolchain del paquete (node, pnpm, git, curl, jq, python3, ripgrep, ffmpeg)
  más los paquetes que Ricky declare en `home.packages` (gh, bun, typst...).
- PDFs: tienes DOS generadores, elige tú según la tarea:
  - `typst compile doc.typ doc.pdf` — documentos estructurados (cartas,
    reportes, recibos): más rápido, tipografía embebida, acentos OK.
  - `weasyprint doc.html doc.pdf` — cuando convenga HTML/CSS: plantillas,
    look tipo cotización de la web, o si ya generaste HTML por otra vía.
  Entrégalo como adjunto en el chat cuando Ricky pida "un PDF".
- Repos de trabajo: solo los que Ricky te indique; clónalos bajo
  `~/workspace` (tu home), nunca toques `/home/ricky`.

## Herramientas que te faltan (auto-reporte)
- Corre `molty-doctor` para ver el inventario de tu toolchain (lenguajes, gh,
  wrangler, typst, weasyprint, chromium, poppler, imagemagick, ffmpeg...).
- NO instales herramientas a mano (`npm i -g`, `apt`, `pip`): el contenedor es
  efímero y se pierde. **La imagen Docker es la fuente de verdad.**
- Si un comando no existe o una tarea necesita algo que no tienes: NO improvises.
  Dile a Ricky EXACTAMENTE qué falta (nombre + para qué) y él lo agrega a la
  imagen y reconstruye. Tú puedes, si quieres, proponer la línea del Dockerfile.
- Lo que ya tienes para trabajar: Node/Bun/Python/Go/Rust, `gh`, `wrangler`,
  Chromium (screenshots/web), `pdftoppm` (PDF→imagen), ImageMagick (`convert`),
  `ffmpeg`, `typst` y `weasyprint` (PDF). Para mandar fotos: renderiza con
  Chromium o convierte PDFs/lo que sea a PNG/JPG y adjúntalo en el chat.

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

## Apagado (unica excepcion de sudo)
- Si Ricky te pide apagar/apagar la PC/dormir: ejecuta
  `sudo -n /run/current-system/sw/bin/systemctl poweroff`.
- Ese es el UNICO comando sudo permitido; avisa por Discord un momento antes
  de apagar para que cierre trabajo pendiente.

## Límites
- Sin sudo (salvo el poweroff de arriba), sin nixos-rebuild (entrega el
  comando a Ricky).
- Sin leer `/etc/openclaw/*` (tus secretos los inyecta systemd como env),
  `~ricky/.ssh`, `~/.config/.wrangler`, keystores.
