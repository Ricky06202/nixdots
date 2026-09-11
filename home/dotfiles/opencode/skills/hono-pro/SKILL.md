---
name: hono-pro
description: Construye APIs de producción con Hono — validación con Zod, base de datos con Drizzle/pg, autenticación JWT, OpenAPI tipado y despliegue en Bun, Node, Cloudflare Workers o Deno. Use when building a Hono API, REST or RPC backend, BFF, edge API, or full-stack app with Hono in TypeScript. Cubre scaffolding, estructura de proyecto, middleware, errores, testing y despliegue. Complementa a rest-api-methodology con detalles específicos de Hono.
license: MIT
metadata:
  author: opencode-ricky
  version: "1.0"
  domain: backend
  role: specialist
  scope: implementation
  output-format: code
---

# Hono Pro — APIs de producción con Hono

Guía de implementación avanzada de **Hono** (framework web de estándares Web, TypeScript-first) en proyectos reales. Para el diseño metodológico de la API (endpoints, errores, paginación), consulta la skill `rest-api-methodology`. Aquí va la parte de implementación.

## Cuándo usar esta skill

- Crear una API nueva con Hono (Bun/Node/Workers/Deno).
- Estructurar un proyecto Hono limpio y mantenible.
- Validación tipada, error handling, auth JWT, rate limiting, CORS.
- DB con Drizzle (Postgres/SQLite) o `pg`/`better-sqlite3`.
- OpenAPI tipado desde el código, testing y despliegue.

## 1. Scaffolding

```bash
# Bun (preferido por Ricky)
bun init -y
bun add hono @hono/zod-validator zod
bun add -d @types/bun

# (Opcional) DB con Drizzle
bun add drizzle-orm pg
bun add -d drizzle-kit

# (Opcional) OpenAPI + tipos compartidos
bun add @hono/zod-openapi openapi-typescript
```

`src/index.ts` mínimo:
```ts
import { Hono } from "hono";
const app = new Hono();
app.get("/", (c) => c.json({ ok: true, service: "api" }));
export default { fetch: app.fetch, port: 3000 }; // compatible con `bun run src/index.ts`
```

## 2. Estructura de proyecto recomendada

```
src/
├── index.ts            # bootstrap, registra routers y middleware global
├── env.ts              # schema de entorno con zod (valida en boot)
├── lib/
│   ├── db.ts           # pool de Drizzle/pg (cerrado al apagar)
│   └── http.ts         # helpers: ok(), fail(), requestId()
├── middleware/
│   ├── auth.ts         # JWT bearer
│   ├── rate-limit.ts
│   ├── error.ts        # error handler global
│   └── request-id.ts   # genera request_id para logs y errores
├── routes/
│   ├── auth.routes.ts
│   └── users.routes.ts
├── schemas/
│   └── user.schema.ts  # zod: input (create/update) + output
├── services/           # lógica de negocio (opcional)
└── db/
    ├── schema.ts       # tablas Drizzle
    └── migrations/
```

## 3. Validación tipada (siempre en el borde)

```ts
import { zValidator } from "@hono/zod-validator";
import { z } from "zod";

const createUserSchema = z.object({
  name: z.string().trim().min(2).max(80),
  email: z.string().email().toLowerCase(),
  password: z.string().min(8).max(128),
});

app.post("/users", zValidator("json", createUserSchema), async (c) => {
  const data = c.req.valid("json"); // tipado como z.infer<typeof createUserSchema>
  const user = await createUser(data);
  return c.json({ data: user }, 201);
});
```

Reglas:
- Usa `zValidator("json" | "query" | "param" | "header" | "cookie", schema)` en cada entrada.
- NUNCA confíes en `c.req.json()` sin validar.
- Esquemas de entrada (Create/Update) y de salida (con `password` nunca incluido) por separado.
- Filtra siempre la salida: no serializar campos internos (`password`, `hash`, `owner_id` de más).

## 4. Error handler global (formato estándar)

```ts
import { ZodError } from "zod";
import { HTTPException } from "hono/http-exception";

app.onError((err, c) => {
  if (err instanceof ZodError) {
    return c.json(
      { error: { code: "VALIDATION_ERROR", message: "Datos inválidos.",
                 details: err.issues.map(i => ({ field: i.path.join("."), issue: i.message })) } },
      400);
  }
  if (err instanceof HTTPException) {
    return c.json({ error: { code: err.status === 401 ? "UNAUTHORIZED" : "HTTP_ERROR",
                             message: err.message } }, err.status);
  }
  console.error(`[${c.get("requestId")}]`, err); // log con request_id
  return c.json({ error: { code: "INTERNAL", message: "Error interno" } }, 500);
});

// En el código: `throw new HTTPException(404, { message: "Usuario no encontrado" })`
```

Usa `hono/http-exception` en vez de `return c.json(..., 404)` cuando sea un error de negocio: el handler central lo formatea y lo loguea uniforme.

## 5. Middleware de autenticación (JWT)

```ts
import { sign, verify } from "hono/jwt";

const JWT_SECRET = env.JWT_SECRET; // desde env.ts, nunca hardcodeado

export const auth = async (c, next) => {
  const header = c.req.header("Authorization");
  if (!header?.startsWith("Bearer ")) throw new HTTPException(401, { message: "No autenticado" });
  try {
    const payload = await verify(header.slice(7), JWT_SECRET);
    c.set("userId", payload.sub as string); // los handlers leen c.get("userId")
  } catch {
    throw new HTTPException(401, { message: "Token inválido o expirado" });
  }
  await next();
};

app.use("/api/v1/users/*", auth);
```

- JWT con `sub` = id del usuario, `iat`/`exp` (15 min), y opcional `scope`.
- Passwords: `bun add bcryptjs` (o `argon2`), hash con cost factor por defecto; nunca en claro.
- Login: `POST /auth/login` → access (15 min) + refresh (7 días); refresh en cookie `HttpOnly` o rotado.

## 6. Base de datos (Drizzle)

```ts
// lib/db.ts
import { drizzle } from "drizzle-orm/node-postgres";
import { Pool } from "pg";
const pool = new Pool({ connectionString: env.DATABASE_URL });
export const db = drizzle(pool);
```

```ts
// db/schema.ts
import { pgTable, serial, text, timestamp } from "drizzle-orm/pg-core";
export const users = pgTable("users", {
  id: serial("id").primaryKey(),
  name: text("name").notNull(),
  email: text("email").notNull().unique(),
  passwordHash: text("password_hash").notNull(),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});
```

- Migraciones: `drizzle-kit generate` + `migrate`. En producción ejecútalas como paso del deploy, nunca en el arranque de la app.
- Queries en capa de datos (`repository/`), no en el handler.
- SQLite: `drizzle-orm/better-sqlite3` para prototipos; cambiar a Postgres en producción es transparente si el schema es portátil (evita features exclusivas de un motor en el modelo).

## 7. OpenAPI tipado y cliente RPC

Opción A — **RPC (`hc`)**: define rutas con `app.route`, importa `type AppType` y usa `hc()` en el cliente: tipos end-to-end sin spec.
```ts
export type AppType = typeof routes;
// frontend: import { hc } from "hono/client"; const client = hc<AppType>("/api");
```

Opción B — **OpenAPI** (`@hono/zod-openapi`): define rutas como `createRoute` con `request`/`responses` zod, genera spec en `/openapi`, y documentación interactiva en `/docs` con **Scalar** (`@scalar/hono-api-reference`). El frontend genera tipos con `openapi-typescript`.

Recomendación: RPC si el frontend es tuyo y está en el mismo monorepo; OpenAPI si hay clientes externos o documentación pública.

## 8. Middleware de plataforma

```ts
import { logger } from "hono/logger";
import { cors } from "hono/cors";

app.use("*", logger());                       // logs por request
app.use("/api/*", cors({ origin: env.ALLOWED_ORIGINS, credentials: true })); // orígenes explícitos
app.use("*", requestId);                      // request_id para logs y errores
```

- **CORS**: lista blanca de orígenes desde env; nunca `"*"` con credentials.
- **Rate limit**: en auth y endpoints sensibles (manual con `@upstash/ratelimit` o un contador en memoria para prototipos).
- **Security headers**: añade los básicos (`X-Content-Type-Options`, `X-Frame-Options`, CSP) vía middleware propio.

## 9. Testing

```ts
// tests/users.test.ts — Bun test + app sin red
import { test, expect } from "bun:test";
const app = await import("../src/routes").then(m => m.buildApp());

test("POST /users con email duplicado → 409", async () => {
  const res = await app.request("/users", { method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ name: "Ana", email: "ana@x.com", password: "segura123" }) });
  expect(res.status).toBe(409);
});
```

- `app.request()` no abre puerto → tests rápidos y deterministas.
- DB de test: SQLite en memoria o Postgres temporal; seed por test, limpieza después.
- `bun test` como comando de CI.

## 10. Despliegue

- **Bun/Node**: `bun run src/index.ts` (export con `port`) → sirve con `bun` o compila `bun build --compile`. Con Node: `bun build ./src/index.ts --target=node` o usar `@hono/node-server`.
- **Cloudflare Workers**: `wrangler init` + `app.fetch` compatible; Hono corre nativo.
- **Docker**: imagen `oven/bun:alpine`, `COPY . .`, `CMD ["bun","run","src/index.ts"]`, exponer puerto, healthcheck a `/health`.
- Base de datos gestionada (Neon/Supabase/RDS) → `DATABASE_URL` por env var. Nunca en el repo.

## Checklist final

- [ ] Entorno validado con zod al boot (`env.ts`).
- [ ] Todo input pasa por `zValidator`; errores con formato estándar vía `app.onError`.
- [ ] Auth JWT con expiración corta y refresh; passwords hasheados.
- [ ] Capa de datos separada; migraciones versionadas.
- [ ] OpenAPI o RPC tipado consumible desde el frontend.
- [ ] Tests de integración con `app.request()` verdes.
- [ ] Sin secretos en el repo; CORS y security headers configurados.
