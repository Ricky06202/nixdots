---
name: rest-api-methodology
description: Metodología completa para diseñar y construir APIs REST de producción con Hono, FastAPI (Python) o Go, con PostgreSQL o SQLite. Use when building, designing, or refactoring REST APIs, backend endpoints, CRUD, auth, pagination, or when starting a new backend project. Covers resource design, validation, error handling, pagination, filtering, sorting, authentication, migrations, OpenAPI docs, testing, and project structure across the three stacks.
license: MIT
metadata:
  author: opencode-ricky
  version: "1.0"
  domain: backend
  role: methodology
  scope: design-and-implementation
  output-format: code
---

# REST API Methodology

Metodología unificada para construir APIs REST de producción. Se aplica a cualquier backend, con guías concretas para los tres stacks que usa Ricky: **Hono (TS/Bun)** como primera opción, **FastAPI (Python)** y **Go**. Bases de datos: **PostgreSQL** en producción, **SQLite** para prototipos y pruebas.

## Cuándo usar esta skill

- Empezar un proyecto de backend nuevo.
- Diseñar endpoints, modelar recursos, decidir rutas y errores.
- Implementar CRUD, autenticación, paginación, filtros, ordenamiento.
- Escribir OpenAPI/Swagger, migraciones o tests de la API.
- Refactorizar una API existente con endpoints inconsistentes.

## Principios rectores

1. **Los endpoints expresan el recurso, no la acción.** `POST /users` no `POST /createUser`. Una acción compleja se modela como sub-recurso (`POST /orders/:id/cancel`) o verbo de dominio en casos justificados.
2. **Consistencia sobre inventiva.** Misma convención de nombres, mismos formatos de error, misma forma de paginar en TODA la API. Define una vez, repite.
3. **La validación vive en el borde.** Todo input se valida y tipa en la capa de entrada (schema/parser). Nada no validado toca la lógica de negocio.
4. **Contratos explícitos.** La API tiene OpenAPI generado del código (no a mano) y el frontend consume los tipos desde ahí.
5. **Seguridad por defecto.** Auth, rate limiting, CORS restringido, nunca loguear secretos, IDs con scope (el usuario A no puede leer recursos del usuario B).

## Fase 1 — Diseño del contrato

1. **Inventario de recursos** y sus relaciones (users, products, orders, reviews...).
2. **Definir endpoints** por recurso (colección + item) y acciones anidadas.
3. **Elegir respuesta de cada verbo**:
   - `GET /items` → `200` lista (objeto con `data`, `meta` para paginación, NUNCA array pelado si hay paginación).
   - `GET /items/:id` → `200` objeto; `404` con error estándar si no existe.
   - `POST /items` → `201` + objeto creado + header `Location`; `400` si el body no valida; `409` si hay conflicto (duplicado).
   - `PUT /items/:id` → reemplazo completo; `PATCH` → parcial; `204` o `200`+objeto.
   - `DELETE /items/:id` → `204` sin body (o `200` si borrado lógico con recurso devuelto).
4. **Paginación**: query params `page`/`limit` (offset) o `cursor` (claveset para datasets grandes). Respuesta: `{ "data": [...], "meta": { "page", "limit", "total" } }`.
5. **Filtrado y orden**: `?status=active&category=tech&sort=-created_at&fields=id,name`. Sufijo `-` para descendente.
6. **Formato de error único** (unificado en toda la API):
   ```json
   {
     "error": {
       "code": "VALIDATION_ERROR",
       "message": "Los siguientes campos son inválidos.",
       "details": [ { "field": "email", "issue": "Formato de correo inválido" } ],
       "request_id": "9f3..."
     }
   }
   ```
   Códigos HTTP: `400` validación, `401` no autenticado, `403` sin permiso, `404` no existe, `409` conflicto, `422` semántica inválida, `429` rate limit, `500` error interno (sin detalles hacia el cliente).

## Fase 2 — Estructura de proyecto

```
src/
├── app.ts|py|main.go      # bootstrap, middleware, enrutado raíz
├── routes/                # routers/mux por recurso (users, orders, ...)
├── handlers|controllers/  # lógica por endpoint
├── schema|schemas/        # validación de entrada (zod/pydantic)
├── services/              # lógica de negocio (opcional si hace falta capa)
├── repository/            # acceso a datos (queries) aislado
├── db/                    # pool, conexión, migraciones
├── middleware/            # auth, logging, rate limit, errores
└── types/                 # tipos compartidos / contractos
```

Separación: **rutas → validación → servicio/lógica → datos**. El handler no habla SQL directo; la capa de datos no expone lógica de negocio.

## Fase 3 — Implementación por stack

### Hono + Bun (opción preferida)
- Proyecto: `bun init` + `bun add hono @hono/zod-validator zod drizzle-orm` (o `pg` directo).
- Validación con `@hono/zod-validator`:
  ```ts
  import { zValidator } from "@hono/zod-validator";
  import { z } from "zod";
  const userSchema = z.object({ name: z.string().min(2), email: z.email() });
  app.post("/users", zValidator("json", userSchema), (c) => {
    const data = c.req.valid("json");
    return c.json({ data }, 201);
  });
  ```
- **Error handler central**: captura `ZodError` y lo transforma al formato de error estándar con `400`. Nunca dejar que una validación rebote como 500.
- **DB**: Drizzle (tipado) con `pg` o `better-sqlite3` para SQLite. Migraciones con `drizzle-kit`.
- **OpenAPI**: `@hono/zod-openapi` para definir rutas tipadas y generar la spec; exponer en `/openapi` y `/docs` (Scalar UI).
- **Middleware**: `hono/logger`, `hono/cors` con origen específico, `helmet` equivalente (headers seguros), rate limit manual o de plataforma.

### FastAPI + Python
- Proyecto: `uv init` + `uv add fastapi uvicorn[standard] sqlalchemy pydantic pydantic-settings`.
- Validación nativa con **Pydantic**: `pydantic.BaseModel` en `schemas/`. Respuestas con `response_model` → tipos y OpenAPI automáticos.
- **Modelo**: SQLAlchemy 2.0 (`Mapped`/`mapped_column`), migraciones con Alembic.
- Estructura: `app/api/v1/routes/*.py` con `APIRouter(prefix="/users", tags=["users"])`, `app/schemas/*.py`, `app/core/*.py` (config, security, db).
- Errores: `HTTPException` con `detail` estándar o exception handler global que formatea todo igual.
- OpenAPI automático en `/docs`; configurar `servers` y metadatos en `FastAPI(...)`.

### Go
- Proyecto: `go mod init` + router `chi` o `net/http` nativo (evita frameworks pesados innecesarios).
- Validación: `go-playground/validator` con tags `validate:"required,email"` y estructura de respuesta de error uniforme.
- DB: `database/sql` + `pgx` (Postgres) o `modernc.org/sqlite` para SQLite; migraciones con `goose` o `atlas`.
- Estructura típica: `cmd/api/main.go`, `internal/handler/`, `internal/service/`, `internal/repository/`, `internal/model/`, `internal/http/middleware/`.
- Middleware: `httprouter`-style chains: logging, recover, auth, CORS, rate limit.
- OpenAPI: `ogen`/`oapi-codegen` para generar handlers desde spec, o `swag` comentarios.

## Fase 4 — Autenticación (patrón por defecto)

- **Tokens**: JWT firmados con `HS256` (secreto en env var, nunca en el código) o `RS256`. Expiración corta (15 min) + refresh token.
- **Password**: solo hash con **bcrypt**/**argon2** (nunca SHA/MD5), cost factor estándar.
- **Endpoints**: `POST /auth/register`, `POST /auth/login` (devuelve access+refresh), `POST /auth/refresh`, `POST /auth/logout` (revoca).
- **Protección**: middleware que valida Bearer token en `/api/v1/*` salvo rutas públicas; scope check en recursos propios (`owner_id`).
- **Rate limit** en auth (login/register) contra fuerza bruta.

## Fase 5 — Pruebas

- **Unitarias**: validación de schemas, servicios puros.
- **Integración**: subir la app en memoria/testing (SQLite para CI, Postgres de test en local), llamar endpoints con el HTTP client (hono: `app.request()`; fastapi: `TestClient`; go: `httptest`).
- **End-to-end**: flujo completo (register → login → CRUD) contra una BD temporal.
- Nombra los tests según el comportamiento, no la función: `test_crear_usuario_con_email_duplicado_devuelve_409`.
- Casos siempre cubiertos: validación fallida (400), no autenticado (401), no encontrado (404), duplicado (409), paginación, filtros, CORS.

## Fase 6 — Operación y documentación

- **OpenAPI** como fuente de verdad del contrato. El frontend genera sus tipos con `openapi-typescript` o el cliente RPC.
- **Logging estructurado** (JSON) con `request_id` por request; el mismo id viaja en los errores.
- **Health checks**: `GET /health` y `GET /health/ready` (con estado de DB) para orquestadores.
- **Entorno**: `.env` con `DATABASE_URL`, `JWT_SECRET`, `ALLOWED_ORIGINS`; nunca commitear secretos.
- **Migraciones**: versionadas y aplicadas en orden; rollback probado; nunca auto-migrar en producción.

## Checklist final

- [ ] Nombres de recursos y verbos consistentes, sin acciones como rutas.
- [ ] Formato de error único en toda la API.
- [ ] Validación en el borde (zod/pydantic/validator) y nunca en el cliente.
- [ ] Paginación + filtros + sort en toda colección.
- [ ] Auth con hash de contraseñas y tokens de corta duración.
- [ ] OpenAPI generado del código, con tipos consumibles desde el frontend.
- [ ] Tests de integración verdes; casos de error cubiertos.
- [ ] Sin secretos en el repo; logging sin datos sensibles.
