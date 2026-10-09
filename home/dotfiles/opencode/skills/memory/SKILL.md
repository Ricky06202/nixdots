---
name: memory
description: Memoria persistente y recordatorios programados. Use when the user asks to remember something ("recuerda", "no olvides", "apunta que"), to set/consult/modify/cancel a timed reminder ("recuérdame el viernes a las 8 hacer X", "alarmas", "avisame"), or when the conversation reveals durable facts, preferences, people, projects or agreements worth keeping across sessions.
---

# Memoria persistente y recordatorios

La memoria vive en `~/.config/opencode/memory/` (archivos de texto locales,
FUERA del repo nixdots: nunca commitear hechos personales). opencode los lee
al inicio de cada sesión porque `INSTRUCTIONS.md` lo ordena.

## Archivos

| Archivo                | Propósito                                          |
|------------------------|----------------------------------------------------|
| `MEMORY.md`            | Hechos duraderos (preferencias, personas, etc.)   |
| `reminders.md`         | Registro de recordatorios y su estado              |
| `fired.log`            | Historial de disparos (lo escribe el script)       |

## Reglas de oro

1. **Nunca inventar memoria**: antes de responder "¿qué recuerdas de...?", leer
   `MEMORY.md`/`reminders.md` con Read.
2. Hecho duradero detectado en la charla → guardar INMEDIATAMENTE sin pedir
   permiso; confirmar en una línea.
3. No guardar contraseñas, tokens ni claves (ni en memoria).
4. Buscar duplicados antes de agregar: si ya existe algo equivalente,
   ACTUALIZAR la línea en vez de agregar otra.
5. Toda entrada lleva fecha ISO: `- [2026-10-08] texto`.
6. Un recordatorio NO existe hasta que su timer de systemd existe. Verificar
   con `list-timers` antes de darlo por hecho.

## Formato de MEMORY.md

```markdown
## Preferencias
- [2026-10-08] Le gusta que las respuestas sean cortas.
## Personas
- [2026-10-08] Mamá: usa su propio bot con opencode + modelo alibaba.
## Proyectos
## Compromisos
## Notas
```

Secciones fijas; si el hecho no encaja, usar `## Notas`.

## Recordatorios (systemd user timers)

Zona horaria del sistema: los timers usan la local (`America/Panama`).
Para fechas relativas ("el viernes a las 8") SIEMPRE validar con
`date -d "next friday" +%A` antes de asumir el día.

Flujo para crear `recordatorio: "<texto>" a las <hora> <día/fecha>`:

1. `id="r$(date +%s)"` (ej: `r1760000000`); modo `once` o `repeat`.
2. Escribir `~/.config/systemd/user/remind-<id>.service`:

```ini
[Unit]
Description=Recordatorio <id>: <texto>

[Service]
Type=oneshot
ExecStart=%h/.local/bin/reminder-fire.sh <id> <once|repeat> "<texto>"
```

3. Escribir `~/.config/systemd/user/remind-<id>.timer`:

```ini
[Unit]
Description=Timer recordatorio <id>

[Timer]
# one-shot:   OnCalendar="2026-10-09 20:00:00"
# semanal:    OnCalendar="Fri *-*-* 20:00:00"
OnCalendar=<expresión>
Persistent=true

[Install]
WantedBy=timers.target
```

4. Activar:

```bash
systemctl --user daemon-reload
systemctl --user enable --now remind-<id>.timer
systemctl --user list-timers 'remind-*' --no-pager   # confirmar que existe
```

5. Registrar en `reminders.md` (fuente de verdad legible):

```markdown
- id=r1760000000 | when=2026-10-09T20:00 | mode=once | status=active | text=Llamar al dentista
- id=r1760000111 | when=Fri 20:00      | mode=repeat | status=active | text=Pasar aspiradora
```

Reglas del texto: sin comillas dobles ni `%` (rompen systemd); máx ~100 chars.
Para one-shot el propio script se autoelimina al disparar y marca `status=done`.

### Gestionar

- **Listar**: leer `reminders.md` + `systemctl --user list-timers 'remind-*' --no-pager`
  (comparar ambos; si difieren, reparar creando la unidad que falte).
- **Cancelar**: `systemctl --user disable --now remind-<id>.timer && rm ~/.config/systemd/user/remind-<id>.{service,timer} && systemctl --user daemon-reload`; marcar `status=cancelled` en `reminders.md`.
- **Modificar**: cancelar y recrear con el mismo texto actualizado.
- **Pausar**: `systemctl --user stop remind-<id>.timer` (status=paused).

### Fallback (máquina sin systemd --user, ej. el bot de mamá en otro SO)

Guardar la cita en `reminders.md` con `status=active` y avisar que la
notificación dependerá de que el usuario revise la lista ("revisa mis
recordatorios"). En Android: sugerir Tasker/Shortcuts; en macOS: `launchd` o
Reminders. No prometer popup donde no hay daemon de notificaciones.

## Repaso proactivo

- Si en una sesión aparecen preferencias nuevas ("siempre prefiero X",
  "a mamá llámala..."), actualizar MEMORY.md sin que lo pidan.
- Si `reminders.md` tiene `status=active` con fecha ya pasada y no hay timer
  (falló el disparo, PC apagada con `Persistent=false`...), ofrecer reprogramar.
