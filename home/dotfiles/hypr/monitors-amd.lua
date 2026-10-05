-- ===== MONITORES (host: amd) =====
-- RX 7600: salida HDMI-A-1 (Samsung U28E590 4K). No hay panel interno (eDP-1
-- no existe en este host), asi que no se declara ningun segundo monitor.
-- En 1080p para que todo se vea mas grande (4K nativo se deja via escala/otros usos).
hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60", position = "0x0", scale = 1 })

-- Monitor fantasma para la partida de mi hermana: se renderiza en la GPU pero
-- no se ve en ningun panel; Sunshine (capSysAdmin + captura KMS) lo transmite
-- a su Moonlight como Display propio. Lo crea headless-setup.sh al iniciar la
-- sesion y lo pone en 1080p60; la declaracion aqui fija el modo en cada carga.
-- position 1920x0: pegado a la derecha del HDMI-A-1, NO en 0x0 (solaparse
-- rompe el hyprland-share-picker de Discord: compartes "screen" y captura el
-- monitor fantasma por quedar el cuadro encima).
hl.monitor({ output = "HEADLESS-1", mode = "1920x1080@60", position = "1920x0", scale = 1 })

-- ===== WORKSPACES ANCLADOS AL MONITOR PRINCIPAL =====
-- El host amd solo tiene un monitor fisico: los workspaces quedan anclados a
-- HDMI-A-1 (sin esto, cualquier ventana podria caer en HEADLESS-1 y
-- "desaparecer" de la pantalla). UNica excepcion: el 6, que es EL monitor
-- fantasma de mi hermana (ventanas gamescope caen ahi por rule).
hl.workspace_rule({ workspace = "1", monitor = "HDMI-A-1", persistent = true })
hl.workspace_rule({ workspace = "2", monitor = "HDMI-A-1", persistent = true })
hl.workspace_rule({ workspace = "3", monitor = "HDMI-A-1", persistent = true })
hl.workspace_rule({ workspace = "4", monitor = "HDMI-A-1", persistent = true })
hl.workspace_rule({ workspace = "5", monitor = "HDMI-A-1", persistent = true })
hl.workspace_rule({ workspace = "7", monitor = "HDMI-A-1", persistent = true })
hl.workspace_rule({ workspace = "8", monitor = "HDMI-A-1", persistent = true })
hl.workspace_rule({ workspace = "9", monitor = "HDMI-A-1", persistent = true })
hl.workspace_rule({ workspace = "10", monitor = "HDMI-A-1", persistent = true })

-- ===== SETUP MOONLIGHT (hermana) =====
-- Crea HEADLESS-1 si falta (idempotente, seguro en cada reload).
hl.exec_cmd("$HOME/.config/hypr/headless-setup.sh")

-- ws 6 = trono del monitor fantasma.
hl.workspace_rule({ workspace = "6", monitor = "HEADLESS-1", persistent = true })

-- Su sesion se lanza envuelta en gamescope (app "Steam" de sunshine), así
-- que su ventana externa es class=gamescope y cae solita en el workspace 6.
-- Si alguna vez usas gamescope para TI, lanzalo con --title "gs-mio" y ajusta
-- el match, o moverá tu juego al monitor fantasma.
hl.window_rule({
  match = { class = "^gamescope$" },
  workspace = 6,
  fullscreen = true,       -- FS al mapear (bool rule)
  fullscreen_state = 1,    -- interno/compositor (el client FS de gamescope no hace falta)
  decorate = false,
  no_focus = true,         -- nunca roba el foco local al nacer (ni despues)
  -- NO_FOCUS (2026-10): su ventana NO toca el teclado/raton locales de Ricky.
  -- El teclado/raton inyectados por sunshine (fake-input, via foco) TAMPOCO
  -- le llegan: ella juega con el mando x360 (uinput = evdev global, ignora el
  -- foco) y con el raton del stream (eventos de puntero, tampoco dependen del
  -- foco teclado). Costo: nada del teclado del stream para ella.
})