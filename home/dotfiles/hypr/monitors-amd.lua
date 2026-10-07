-- ===== MONITORES (host: amd) =====
-- RX 7600: el Samsung U28E590 4K esta conectado por DISPLAYPORT => el output
-- ahora es DP-1 (antes HDMI-A-1). Que GANA uno con el DP en este panel:
--   * 3840x2160 @ 60Hz: el HDMI del U28E590 es 1.4 y topa en 4K@30. El DP 1.2
--     si lleva 4K@60 con banda de sobra (RGB 4:4:4, sin compresion).
--   * Nada de VRR/FreeSync: este panel NO lo soporta (confirmado en vivo:
--     DRM "connector DP-1 incapable of vrr"). NO poner vrr=1 aqui.
--   * Hotplug y renegociacion mas fiables que HDMI (menos pantallas negras
--     al despertar del DPMS).
-- 4K NATIVO con scale=2: area logica 1920x1080 (mismo tamano de UI que el
-- viejo 1080p) pero nitido de verdad. Los juegos siguen renderizando a la
-- resolucion que elijas DENTRO del juego (1080p recomendado en la RX 7600);
-- el modo del monitor no los limita. Escala ENTERA => sin borrosidad ni en
-- XWayland. Logical 1920 => HEADLESS-1 encaja pegado a la derecha sin
-- solaparse. (Por HDMI esto era imposible: el 1.4 del panel solo daba 4K@30.)
hl.monitor({ output = "DP-1", mode = "3840x2160@60", position = "0x0", scale = 2 })

-- Monitor fantasma para la partida de mi hermana: se renderiza en la GPU pero
-- no se ve en ningun panel; Sunshine (capSysAdmin + captura KMS) lo transmite
-- a su Moonlight como Display propio. Lo crea headless-setup.sh al iniciar la
-- sesion y lo pone en 1080p60; la declaracion aqui fija el modo en cada carga.
-- position 1920x0: pegado a la derecha del DP-1 (que con scale=2 ocupa justo
-- 1920 logicos), NO en 0x0 (solaparse
-- rompe el hyprland-share-picker de Discord: compartes "screen" y captura el
-- monitor fantasma por quedar el cuadro encima).
hl.monitor({ output = "HEADLESS-1", mode = "1920x1080@60", position = "1920x0", scale = 1 })

-- ===== WORKSPACES ANCLADOS AL MONITOR PRINCIPAL =====
-- El host amd solo tiene un monitor fisico (DP-1): los workspaces quedan anclados a
-- DP-1 (sin esto, cualquier ventana podria caer en HEADLESS-1 y
-- "desaparecer" de la pantalla). UNica excepcion: el 6, que es EL monitor
-- fantasma de mi hermana (ventanas gamescope caen ahi por rule).
hl.workspace_rule({ workspace = "1", monitor = "DP-1", persistent = true })
hl.workspace_rule({ workspace = "2", monitor = "DP-1", persistent = true })
hl.workspace_rule({ workspace = "3", monitor = "DP-1", persistent = true })
hl.workspace_rule({ workspace = "4", monitor = "DP-1", persistent = true })
hl.workspace_rule({ workspace = "5", monitor = "DP-1", persistent = true })
hl.workspace_rule({ workspace = "7", monitor = "DP-1", persistent = true })
hl.workspace_rule({ workspace = "8", monitor = "DP-1", persistent = true })
hl.workspace_rule({ workspace = "9", monitor = "DP-1", persistent = true })
hl.workspace_rule({ workspace = "10", monitor = "DP-1", persistent = true })

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
  fullscreen_state = 2,    -- nivel TRAD del sistema propio de hyprland.lua: cubre TODA
                           -- la pantalla (ignora el area reservada de las barras de
                           -- Caelestia). Con 1 (=maximizar) gamescope se quedaba en
                           -- 1830x1040 y el stream salia con barras negras.
  decorate = false,
  no_focus = true,         -- nunca roba el foco local al nacer (ni despues)
  -- NO_FOCUS (2026-10): su ventana NO toca el teclado/raton locales de Ricky.
  -- El teclado/raton inyectados por sunshine (fake-input, via foco) TAMPOCO
  -- le llegan: ella juega con el mando xone (uinput = evdev global, ignora el
  -- foco) y con el raton del stream (eventos de puntero, tampoco dependen del
  -- foco teclado). Costo: nada del teclado del stream para ella.
})