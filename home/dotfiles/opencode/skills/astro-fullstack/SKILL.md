---
name: astro-fullstack
description: Metodología para crear y mantener proyectos full-stack con Astro + React + Tailwind CSS + Bun. Use when starting a new Astro project, adding React islands, integrating Tailwind, setting up content collections, SSG/SSR, API routes, or deploying an Astro site. Cubre scaffolding con Bun, islands architecture, content collections, View Transitions, optimización de rendimiento y despliegue.
license: MIT
metadata:
  author: opencode-ricky
  version: "1.0"
  domain: frontend
  role: methodology
  scope: project-setup-and-development
  output-format: code
---

# Astro Fullstack — Astro + React + Tailwind + Bun

Metodología de proyecto para el stack web principal de Ricky: **Astro** (islands, contenido y rendimiento) + **React** (islas interactivas) + **Tailwind CSS** (estilo) + **Bun** (runtime y package manager).

## Cuándo usar esta skill

- Inicializar un proyecto Astro nuevo (sitio de contenido, landing, blog, docs, e-commerce, app).
- Decidir entre SSG/SSR y qué islas de React usar.
- Configurar Tailwind, content collections, View Transitions, API routes o i18n.
- Optimizar rendimiento y Core Web Vitals.
- Desplegar (Vercel, Cloudflare, Netlify, servidor propio).

## Principios del stack

1. **Zero JS por defecto.** Astro solo envía JS donde hace falta (islas). Si algo puede ser estático o un `<script>` vanilla, no uses una isla React.
2. **Bun para todo.** `bun create astro@latest` para iniciar, `bun install`, `bun run dev/build/preview`. Bun es el gestor y el runtime; no usar npm salvo que algo exija Node específicamente.
3. **Tailwind v4+ como capa de estilo.** CSS nativo + `@theme` para tokens. Definir la identidad visual (ver web-design-pro) en tokens de Tailwind, no clases sueltas.
4. **Contenido modelado.** Todo contenido estructurado vive en Content Collections (con `zod` para validar el schema), nunca en componentes hardcodeados.
5. **Rendimiento es una feature.** Astro ya es rápido; no lo rompas con islas innecesarias, imágenes pesadas o JS de terceros.

## Fase 1 — Scaffolding

```bash
bun create astro@latest mi-proyecto -- --template minimal --install --no-git
cd mi-proyecto
bunx astro add tailwind react
bun install
bun run dev   # http://localhost:4321
```

- ¿SSG o SSR? **SSG** por defecto (más rápido, más barato, mejor SEO). Cambia a **SSR** (`output: 'server'`) solo si necesitas rutas dinámicas, auth, formularios en servidor o datos de usuario. Para SSR: añade el adapter del host (`bunx astro add vercel|cloudflare|netlify`).
- Directorio `src/components` (islas React), `src/layouts`, `src/pages`, `src/content` (collections), `src/lib`.

## Fase 2 — Configuración de Astro

`astro.config.mjs` recomendado (ajustar a lo que aplique):
```js
import { defineConfig } from "astro/config";
import tailwindcss from "@tailwindcss/vite";
import react from "@astrojs/react";

export default defineConfig({
  output: "static",            // o "server" con adapter
  integrations: [react(), tailwindcss()],
  site: "https://tudominio.com",
  i18n: { defaultLocale: "es", locales: ["es", "en"] },
  image: { service: compactService } // v5: servicio local
});
```

## Fase 3 — Tailwind v4 + sistema de diseño

- Tailwind v4 se integra con el plugin Vite (`@tailwindcss/vite`), sin `tailwind.config.js` obligatorio.
- Define tokens en CSS (`src/styles/global.css`):
  ```css
  @import "tailwindcss";
  @theme {
    --color-brand: #e2a03f;
    --color-ink: #17151a;
    --font-display: "Clash Display", sans-serif;
  }
  ```
- Usa `@theme` para colores/fuentes de marca (ver skill `web-design-pro` para definir el gancho visual). Los utilitarios derivados (`bg-brand`, `font-display`) salen solos.

## Fase 4 — Islands de React (reglas)

- Una isla = `import MiComponente from "../components/MiComponente.tsx"` y usarla como `<MiComponente client:load />`.
- Directivas según necesidad:
  - `client:visible` → hidrata cuando entra en viewport (por defecto para la mayoría).
  - `client:idle` → cuando el navegador descansa (widgets secundarios).
  - `client:only="react"` → solo para componentes que dependen 100% de browser (context, hooks DOM).
  - `client:load` → inmediato (header con navegación, buscadores).
- **Props serializables**: la isla recibe props (JSON) desde Astro; no le pases funciones. Toda data pesada se pasa ya "cocinada".
- Si el componente no necesita estado ni eventos, es markup puro → NO es isla, queda en `.astro`.

## Fase 5 — Content Collections

```ts
// src/content.config.ts (Astro 5)
import { defineCollection, z } from "astro:content";
const blog = defineCollection({
  loader: glob({ pattern: "**/*.md", base: "./src/content/blog" }),
  schema: z.object({
    title: z.string(),
    pubDate: z.coerce.date(),
    tags: z.array(z.string()).default([]),
    draft: z.boolean().default(false),
  }),
});
export const collections = { blog };
```

- Valida con zod: typos y datos rotos se detectan en build, no en producción.
- Consulta con `getCollection`, render con `<Content />` o `render()`.
- `Astro.glob` para archivos sin schema estricto.

## Fase 6 — Rendimiento y SEO

- **Imágenes**: componente `<Image />`/`<Picture />` de `astro:assets` (formato moderno, srcset, lazy automático). El hero: `eager` + `fetchpriority="high"`.
- **View Transitions**: `import { ViewTransitions } from "astro:transitions"` en el layout → transiciones nativas entre páginas sin SPA. Solo si el sitio lo amerita (MIMO).
- **Fonts**: fuentes display con `font-display: swap` y `preload`. Idealmente auto-hospedadas (no Google Fonts CDN).
- **SEO**: `astro:head` con `title`/`meta`/`og:` por página (o el componente `<Head />`), JSON-LD para datos estructurados, sitemap (`bunx astro add sitemap`).
- **JS de terceros**: analytics con `astro:analytics`-compatible, loader diferido o `data-astro-rerun`, nunca bloquear el render.

## Fase 7 — Formularios, datos y SSR

- Formularios: si solo hay envío, hazlos con `actions` de Astro (Server Actions) en SSR, o `netlify forms`/`formspree` si es estático. Con API propia: `fetch` a tu backend Hono (ver skill `rest-api-methodology`).
- API routes: `src/pages/api/[...].ts` solo si la lógica es mínima; si tienes un backend real, mantén la API separada (Hono) y consume desde Astro.
- **Tipos compartidos**: si usas Hono con `@hono/zod-openapi`, genera tipos y consume en la isla React con `openapi-fetch` o `hc()`.

## Fase 8 — Despliegue

- **Vercel**: `bunx astro add vercel` (adapter). En Vercel el runtime por defecto es Node — si quieres Edge/Bun, configura el adapter.
- **Cloudflare Pages**: `bunx astro add cloudflare` → deploy con wrangler (`bunx wrangler pages deploy dist`).
- **Netlify**: adapter oficial.
- **Servidor propio**: build `dist/` estático servido por nginx/caddy, o `output: 'server'` con `node`/`bun` + `PM2`/`systemd`.
- CI: build + `bun run check` (typecheck) en cada PR.

## Checklist final

- [ ] Proyecto creado con Bun, islas mínimas (cero JS donde no hace falta).
- [ ] Tokens de marca en `@theme` de Tailwind v4, no clases sueltas.
- [ ] Content collections con schema zod para todo contenido.
- [ ] Imágenes con `astro:assets`, hero optimizado.
- [ ] Core Web Vitals: LCP < 2.5s, CLS < 0.1, INP < 200ms.
- [ ] SEO (title/desc/OG/JSON-LD) en todas las páginas clave.
- [ ] `bun run build` y `bun run check` sin errores.
- [ ] Desplegado con adapter correcto según el host.
