---
name: cloudflare-deploy
description: Use when deploying, configuring, or debugging Cloudflare Workers or Pages with Wrangler. Prioritizes Workers for APIs, SSR, backends, and new edge apps; use Pages for existing Pages projects or an explicit Pages request.
license: MIT
compatibility: opencode
metadata:
  author: ricky
  version: "2.0.0"
  domain: deployment
  triggers: cloudflare, workers, pages, wrangler, deploy, deployment, publicar, custom domain, DNS
  role: specialist
---

# Despliegues en Cloudflare Workers y Pages

## Elegir la plataforma

- Inspecciona el proyecto antes de editar o desplegar: framework y versión, package manager, scripts, `wrangler.jsonc`/`wrangler.toml`, adapter, build, assets y bindings. Conserva su estructura; no recrees el proyecto a ciegas.
- Para una integración nueva con Cloudflare sin plataforma ya elegida, evalúa **Workers primero**. Workers es el camino principal para APIs, backends, SSR y lógica edge.
- Conserva **Pages** cuando el proyecto ya tenga configuración o despliegues Pages, o cuando el usuario lo pida expresamente. No migres una aplicación entre Workers y Pages sin que lo solicite.
- No confundas `wrangler deploy` (Workers) con `wrangler pages deploy` (Pages). Usa la guía y configuración de la plataforma elegida; no fuerces una exportación estática ni cambies el adapter sin comprobar la compatibilidad vigente del framework.
- Si falta configuración Wrangler, revisa `wrangler setup` para prepararla sin desplegar. `wrangler deploy` puede detectar frameworks y configurar el proyecto, así que revisa cualquier archivo generado antes de publicar.

## Flujo principal: Workers

1. Usa el Wrangler del proyecto y su package manager. En proyectos Bun, prefiere `bunx wrangler`; en otros, respeta sus scripts y lockfile. No instales Wrangler globalmente por defecto. Consulta la versión instalada y su `--help` antes de usar flags que no existan en el repo.
2. Revisa la configuración activa: nombre del Worker, cuenta, `compatibility_date`, assets, bindings, rutas/domains y entornos. Confirma que staging y producción usan los recursos y secretos correctos; los `vars` de un entorno pueden requerir definición propia.
3. Comprueba autenticación con `wrangler whoami`. Si falta, pide al usuario completar `wrangler login` en su navegador. Nunca solicites que pegue un API token en el chat ni lo guardes en el repo.
4. Ejecuta el build o las comprobaciones que ya declare el proyecto. Para desarrollo local usa `wrangler dev` y verifica el comportamiento pertinente antes del despliegue.
5. Despliega solo cuando el usuario haya pedido publicar. Para un entorno nombrado usa el entorno configurado, por ejemplo `wrangler deploy --env staging`; no asumas que producción es el destino solicitado. La forma base para un Worker es:

   ```sh
   bunx wrangler deploy
   ```

   Sustituye `bunx` por el runner del package manager del proyecto cuando corresponda. Revisa `wrangler deploy --help` y los scripts existentes antes de decidir flags o comandos.
6. Comprueba la salida de Wrangler, el Worker y su endpoint público. Si falla o el comportamiento difiere, inspecciona los logs con el mecanismo disponible (`wrangler tail` o el dashboard) y reporta el error real; no declares éxito solo porque el comando terminó.

## Dominios y rutas de Workers

- Elige un **Custom Domain** cuando el Worker sea el origen de la aplicación. Elige una **Route** cuando deba ejecutarse delante de un servidor de origen existente.
- Inspecciona los DNS y rutas actuales antes de cambiarlos. Un Custom Domain crea el DNS y el certificado necesarios; no puede añadirse sobre un hostname que ya tenga un CNAME. No borres ni sobrescribas registros sin autorización explícita.
- Para producción, verifica que el Worker esté asociado al dominio o ruta solicitada y prueba una URL real; no informes `workers.dev` como dominio personalizado.

## Secrets y variables

- Usa secretos para tokens, claves y contraseñas; no los pongas en `vars` de texto plano, argumentos visibles, logs ni archivos versionados.
- Para crear un secreto de Worker, usa `wrangler secret put <KEY>` con el runner del proyecto. Este comando crea una versión y la despliega inmediatamente; para despliegues graduales, consulta el flujo vigente de `wrangler versions secret put` y `wrangler versions deploy` antes de actuar.
- Para desarrollo local, usa `.dev.vars` o `.env` solo si están ignorados por Git; verifica `.gitignore` antes de escribir valores. En CI, guarda `CLOUDFLARE_API_TOKEN` y el ID de cuenta en el almacén de secretos del proveedor.

## Alternativa: Pages

Usa este flujo si el usuario pide Pages o el proyecto existente ya es Pages.

1. Comprueba la autenticación y revisa los proyectos con `wrangler pages project list`. Reutiliza el proyecto indicado; créalo solo cuando el usuario pidió el despliegue y el nombre/flujo están claros.
2. Si no está definido si usar **Git integration** o **Direct Upload**, pregunta antes de crear el proyecto. Pages no permite convertir un proyecto existente de un modo al otro; elegir el modo equivocado implica crear otro proyecto.
3. Ejecuta el build del proyecto y confirma su directorio de salida leyendo la configuración o la guía oficial del framework. No adivines `dist`, `build` u otra ruta.
4. Git integration y Direct Upload son flujos distintos. No conectes GitHub, crees un repo ni hagas `git push` salvo que el usuario lo haya pedido. Para Direct Upload, confirma el proyecto y entorno antes de subir:

   ```sh
   bunx wrangler pages deploy <DIRECTORIO_BUILD> --project-name <PROYECTO>
   ```

   Para previews se puede usar `--branch=<nombre>`; valida la sintaxis con el Wrangler del proyecto. Un CNAME manual sin asociar el hostname al proyecto Pages puede fallar.
5. Prueba la URL publicada (`*.pages.dev`) y el dominio personalizado solicitado. Informa proyecto, entorno, URL y cualquier verificación pendiente.

## Documentación oficial

### Workers

- Wrangler y comandos: https://developers.cloudflare.com/workers/wrangler/commands/workers/
- Configuración de Wrangler: https://developers.cloudflare.com/workers/wrangler/configuration/
- Entornos: https://developers.cloudflare.com/workers/wrangler/environments/
- Secrets: https://developers.cloudflare.com/workers/configuration/secrets/
- Custom Domains: https://developers.cloudflare.com/workers/configuration/routing/custom-domains/
- Routes: https://developers.cloudflare.com/workers/configuration/routing/routes/

### Pages

- Direct Upload: https://developers.cloudflare.com/pages/get-started/direct-upload/
- Comandos Wrangler Pages: https://developers.cloudflare.com/workers/wrangler/commands/pages/
- Integración Git: https://developers.cloudflare.com/pages/configuration/git-integration/
- Dominios personalizados: https://developers.cloudflare.com/pages/configuration/custom-domains/
- Guías de framework: https://developers.cloudflare.com/pages/framework-guides/
