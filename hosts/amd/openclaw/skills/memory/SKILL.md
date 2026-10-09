---
name: memory
description: >
  Memoria persistente y recordatorios con avisos. Use when the user asks to remember something,
  save a fact or preference, or set/list/change/cancel a reminder or timed notice
  ("recuérdame el viernes a las 8...", "no olvides que...", "avísame mañana"), or when the
  conversation reveals durable facts, people, agreements or project decisions worth keeping.
  Also use before answering anything about past conversations ("¿qué sabes de...?", "¿te acuerdas...?").
license: MIT
metadata:
  author: Ricky06202
  version: "1.0"
---

# Memoria profesional y recordatorios

## Arquitectura de memoria (OpenClaw nativo — respétala)

| Capa | Archivo | Carga |
|------|---------|-------|
| Hechos duraderos | `MEMORY.md` (workspace) | automática al inicio de sesión |
| Notas del día | `memory/YYYY-MM-DD.md` | hoy+ayer con `/new`; siempre indexadas para búsqueda |
| Búsqueda | tool `memory_search` / `memory_get` | bajo demanda |
| Preferencias estables | `USER.md` | **declarativo del repo: NO lo edites (un rebuild lo revierte)** |

Reglas:

1. **Nunca inventar memoria.** Antes de responder sobre algo pasado, `memory_search` +
   leer `MEMORY.md`. Si no está en disco, di que no lo sabes o pregunta.
2. Lo que no se escribe, se olvida: detectado un hecho duradero, GUARDA INMEDIATAMENTE
   sin que lo pidan y confirma en media línea.
3. JAMÁS guardar contraseñas, tokens, claves ni datos de tarjetas (ni en memoria).

## Qué escribir y dónde

- Hecho duradero (persona, relación, acuerdo, decisión de proyecto, dato recurrente):
  una línea destilada en `MEMORY.md` bajo sección temática, con fecha `[YYYY-MM-DD]`.
- Detalle del día, tarea en curso, contexto tosco: appending a `memory/YYYY-MM-DD.md`.
- Cambio de preferencia: busca la línea anterior y REPLÁZALA (sin duplicados ni
  contradicciones); la fecha antigua va como `(desde ...; actualizado ...)`.
- Al cerrar una tarea larga: 2-3 líneas de resultado en la nota diaria.
- Si `MEMORY.md` pasa de ~120 líneas: consolida (fusiona afines, mueve detalle a
  diarias). El dreaming barre solo, pero ayúdalo cuando lo notes gordo.

## Recordatorios (tool `cron` / `openclaw cron`)

Zona horaria del gateway: America/Panama. **Trampa**: un `--at` sin zona se lee en UTC;
pon siempre offset explícito (`-05:00`) o `--tz America/Panama`.

Pasos para "recuérdame X a las Y":

1. Resuelve la fecha real ANTES de agendar (verifica día/hora actuales con `date`).
2. Crea el job con la tool `cron` (o exec `openclaw cron add`):
   - **Un solo disparo**: `--at "2026-10-09T20:00:00-05:00" --delete-after-run`
   - **Recurrente**: `--cron "0 20 * * 5"` (viernes 8pm; sin `--tz` usa la del gateway)
   - **Payload**: `--message "Suavizar y enviar aviso de recordatorio a Ricky por Discord: <qué y contexto>. Máximo 2 líneas."`
   - **Entrega**: `--announce --channel last` (el último chat = Discord con Ricky).
3. VERIFICA: lista los jobs (`cron` tool action list / `openclaw cron list`) y confirma
   que el job existe. Solo entonces responde:
   `Hecho: te aviso el vie 9 oct, 8:00 PM.`
4. Un recordatorio prometido sin job verificado ES un fallo; trátalo como bug y créalo.

Gestión: listar = tool list (no `--all` a menos que pregunte desactivados); cancelar =
delete + confirmar; cambiar = borrar y recrear (no hay edición parcial fiable).
Recordatorios recurrentes que Ricky cancele: anótalo en la nota diaria para no
recrearlos por accidente.

## Al despertar (sesión nueva)

`MEMORY.md` y las diarias de hoy/ayer llegan solas al contexto. Úsalas como hechos
conocidos SIN resumirlas en pantalla; solo menciona lo relevante a lo que te preguntan.
