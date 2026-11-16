---
name: cloudflare-pages-deploy
description: Deployar sitios web en Cloudflare Pages con Wrangler, revisar builds, proyectos y dominios personalizados. Usar al publicar un sitio, ejecutar `wrangler pages` o configurar un subdominio en Cloudflare.
license: MIT
compatibility: opencode
metadata:
  author: ricky
  version: "1.0.0"
  domain: deployment
  triggers: cloudflare, pages, wrangler, deploy, publicar, custom domain, DNS
  role: specialist
---

# Despliegues en Cloudflare Pages

## Reglas principales

- Inspecciona el proyecto antes de editar o desplegar: framework y versión, package manager, scripts, configuración de Cloudflare, build y directorio de salida. Conserva su estructura; no recrees el proyecto a ciegas.
- No confundas Cloudflare Pages con GitHub Projects. Crear un repo público, hacer `git push`, conectar GitHub o crear un proyecto Pages son acciones distintas; no las hagas salvo que el usuario las haya pedido.
- Pregunta si no está claro si se usará **Git integration** o **Direct Upload**. Cloudflare no permite convertir luego un proyecto Direct Upload a Git integration.
- Elige Pages para el flujo solicitado y consulta la guía vigente del framework si necesita SSR o funciones. No fuerces una exportación estática ni cambies el adapter sin comprobar compatibilidad.
- No declares éxito hasta comprobar el build, la URL publicada y el dominio solicitado.

## Flujo con Wrangler / Direct Upload

1. Comprueba la versión local de Wrangler y consulta su `--help`/documentación actual para cualquier comando o flag que no exista en la configuración del repo. Respeta el package manager y lockfile existentes. Para Bun, si Wrangler debe quedar reproducible en el proyecto, agrégalo como dependencia de desarrollo (`bun add -d wrangler`); no lo instales globalmente por defecto.
2. Comprueba acceso con `bunx wrangler whoami` (o el runner del package manager existente). Si falta autenticación, pide al usuario que complete `wrangler login` en su navegador. Nunca solicites que pegue un API token en el chat ni lo guardes en el repo.
3. Inspecciona los proyectos existentes con `wrangler pages project list`. Reutiliza el proyecto indicado si existe. Solo crea uno cuando el usuario pidió el despliegue y el nombre/flujo están claros; usa la ayuda vigente para `pages project create`.
4. Ejecuta el build definido por el proyecto. Confirma cuál es el directorio de salida leyendo su configuración o la guía oficial; no adivines `dist`, `build` u otra ruta. Haz una comprobación local del sitio compilado antes de subirlo.
5. Publica solo al entorno solicitado. Para un preview, usa `--branch=<nombre>`; antes de producción verifica el nombre del proyecto y la rama/entorno objetivo. La forma usual de Direct Upload es:

   ```sh
   bunx wrangler pages deploy <DIRECTORIO_BUILD> --project-name <PROYECTO>
   ```

   Confirma sintaxis y flags con la versión instalada. Git integration es otra ruta y no se configura creando un GitHub Project.

## Dominios personalizados y DNS

- Primero asocia el dominio al proyecto en **Cloudflare → Workers & Pages → proyecto → Custom domains**. Un CNAME manual sin asociar el hostname en Pages puede fallar (por ejemplo, 522).
- Para un subdominio, verifica quién administra su DNS y que el usuario tiene acceso. Si la zona está en la misma cuenta Cloudflare, el proceso puede crear el CNAME automáticamente; con DNS externo se necesita apuntar el CNAME al hostname `*.pages.dev` del proyecto.
- Antes de modificar DNS, inspecciona los registros existentes. No sobrescribas ni borres registros sin autorización explícita. Verifica que el dominio resuelva y sirva el proyecto después de asociarlo.

## Seguridad y reglas de este equipo

- Mantén OAuth/API tokens fuera del repo, logs y argumentos visibles. Para CI, usa el almacén de secretos del proveedor, no archivos commiteados.
- Wrangler por proyecto se declara en su manifest/lockfile. Si el usuario pide disponibilidad global en NixOS, revisa y modifica `~/Dev/nixdots` de forma declarativa; no uses una instalación temporal como solución permanente.
- Nunca ejecutes `sudo nixos-rebuild`. Si modificaste `nixdots`, valida con `nix flake check` y entrega al usuario el comando de rebuild del host; no lo ejecutes.

## Comprobación y reporte

- Revisa el resultado del despliegue y prueba con HTTP la URL `*.pages.dev` y el dominio personalizado solicitado.
- Informa el proyecto, entorno, URL y verificaciones realizadas. Distingue claramente lo desplegado de lo que aún espera autenticación, configuración DNS o aprobación del usuario.

## Documentación oficial

- Direct Upload: https://developers.cloudflare.com/pages/get-started/direct-upload/
- Comandos Wrangler Pages: https://developers.cloudflare.com/workers/wrangler/commands/pages/
- Dominios personalizados: https://developers.cloudflare.com/pages/configuration/custom-domains/
- Guías de framework: https://developers.cloudflare.com/pages/framework-guides/
