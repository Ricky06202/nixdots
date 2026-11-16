---
name: sveltekit
description: 'Convenciones para construir apps con SvelteKit 2 + Svelte 5 (runes), Bun, Tailwind v4 y Drizzle/PostgreSQL. Usar al crear rutas, load functions, form actions, endpoints, componentes con $state/$derived/$props, o al revisar código SvelteKit. Cubre separación server/client, progresive enhancement, errores/redirects y las trampas típicas del modelo de datos de SvelteKit.'
license: MIT
compatibility: opencode
allowed-tools: Read, Grep, Glob, Edit, Write, Bash
metadata:
  author: ricky
  version: "1.0.0"
  domain: web
  triggers: svelte, sveltekit, runes, +page, +layout, form action, load function, drizzle, tailwind, bun
  role: specialist
---

# SvelteKit 2 + Svelte 5

Stack de referencia: **SvelteKit 2**, **Svelte 5 (runes)**, **Bun**, **Tailwind v4**, **Drizzle + PostgreSQL**.

## Estructura de rutas

```
src/routes/
  +layout.svelte          # shell de la app (nav, providers)
  +layout.server.ts       # datos comunes (usuario, sesión)
  +page.svelte            # UI de la ruta
  +page.server.ts         # load con secretos/DB + form actions
  +page.ts                # load universal (corre en server Y cliente)
  +server.ts              # endpoints HTTP (GET/POST/...)
  api/…/+server.ts
  hooks.server.ts         # auth, locals, headers
```

Regla de oro: **si toca la base, filesystem o secretos → `.server.ts`**. `+page.ts` corre también en el navegador: nunca importes ahí código con secretos.

## Svelte 5: runes, no stores

```svelte
<script lang="ts">
  let { user, items = [] }: { user: User; items: Item[] } = $props();
  let query = $state("");
  const filtered = $derived(items.filter(i => i.name.includes(query)));
  $effect(() => { console.log(filtered.length); });
</script>

<button onclick={() => (query = "")}>Limpiar</button>
```

- `$props()` en lugar de `export let`; `$state()` en lugar de `let` reactivo; `$derived()` en lugar de `$:`. No los mezcles en el mismo archivo nuevo.
- Eventos: `onclick={...}`, no `on:click`. Sin `createEventDispatcher`.
- Componentes hijos con `{@render children()}` y snippets (`{#snippet}`), no slots.
- `$app/state` (`page.url`, `page.data`) en vez de `$app/stores` en código nuevo. Ojo: `page.data` en cliente puede venir desactualizado hasta navegar.

## load y datos

```ts
// src/routes/posts/+page.server.ts
export const load = async ({ locals, url }) => {
  const page = Number(url.searchParams.get("page") ?? 1);
  const [rows, total] = await Promise.all([
    db.select().from(posts).limit(20).offset((page - 1) * 20),
    db.select({ n: count() }).from(posts),
  ]);
  return { rows, total: total[0].n };
};
```

- Devuelve solo datos serializables (nada de clases, `Date` sí, `Map`/`Set` no).
- `load` server se ejecuta en cada navegación que la use; usa `depends()` + `invalidate()` para controlar cuándo se re-corre.
- Para datos que cambian seguido y son públicos, `export const prerender = false` explícito.
- Tipá `PageData`/`PageServerData` con `./$types` (`import type { PageData } from './$types'`).

## Form actions (SvelteKit 2)

```ts
// +page.server.ts
import { fail, redirect } from "@sveltejs/kit";

export const actions = {
  create: async ({ request, locals }) => {
    const data = Object.fromEntries(await request.formData());
    const parsed = schema.safeParse(data);
    if (!parsed.success) return fail(400, { errors: parsed.error.flatten().fieldErrors });
    const [row] = await db.insert(posts).values(parsed.data).returning();
    redirect(303, `/posts/${row.id}`);
  },
};
```

- En SvelteKit 2 `redirect()` y `error()` se **llaman**, no se lanzan con `throw`.
- `fail(400, {...})` para errores de validación; el objeto queda en `form` del `+page.svelte`.
- En el componente: `<form method="POST" action="?/create" use:enhance>`. `enhance` da progresive enhancement sin JS propio.
- Todo lo que devuelve la action debe ser serializable.

## Endpoints

```ts
// src/routes/api/posts/+server.ts
export const GET = async ({ url }) => json(await list(url.searchParams.get("q")));
export const POST = async ({ request }) => {
  const body = await request.json();
  return json(await create(body), { status: 201 });
};
```

## Base de datos (Drizzle)

- Esquema en `src/lib/server/db/schema.ts`; cliente en `src/lib/server/db/index.ts` (import `$env/dynamic/private` para la URL).
- **Nunca** importes `$lib/server/*` desde un `.svelte` o desde `+page.ts`: SvelteKit lo bloquea y falla en build (es una protección, no un bug).
- Queries con el query builder o `sql` template; nunca concatenes strings del usuario.
- `limit + 1` para saber si hay página siguiente (evita un `count(*)` extra).

## Tailwind v4

- Plugin `@tailwindcss/vite` + `@import "tailwindcss";` en el CSS. No hace falta `tailwind.config.js` para lo básico (`@theme` en CSS para tokens).
- Clases condicionales: `clsx` o `cn()`; evita ternarios anidados ilegibles.

## Comandos (Bun)

```bash
bunx sv create .          # scaffold
bun run dev               # Vite dev
bun run build && bun run preview
bunx drizzle-kit generate && bunx drizzle-kit migrate
bunx vitest run           # unit
bunx playwright test      # e2e
```

## Trampas que rompen builds

1. Importar `$lib/server/…` en código de cliente → error de build.
2. Usar `$app/stores` y runes a la vez en un componente nuevo → comportamiento raro; elegí runes.
3. `let x = 0` esperando reactividad: en Svelte 5 hace falta `$state(0)`.
4. `throw redirect(...)` → en SK2 es `redirect(...)` sin throw.
5. Devolver `Date` dentro de un objeto de `load` funciona, pero `Map`, `Set`, clases y funciones no.
6. Mutar `page.data` o el objeto de `load` en el cliente: es de solo lectura; usá `invalidateAll()` para refrescar.
