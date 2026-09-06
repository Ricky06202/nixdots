-- ===== MONITORES =====
-- formato: hl.monitor({ output = NOMBRE, mode = "RESOLUCION@REFRESCO", position = "XxY", scale = N })
-- HDMI-A-2 declarado primero -> es el monitor principal (ID 0)
hl.monitor({ output = "HDMI-A-2", mode = "1920x1080@60", position = "0x0", scale = 1 })
hl.monitor({ output = "eDP-1", mode = "1920x1080@60", position = "1920x0", scale = 1 })

-- ===== CURSOR (Bibata Modern Classic: negro, bordes redondeados) =====
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")

-- ===== GENERAL =====
hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 10,
        border_size = 2,
        col = {
            active_border = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },
        layout = "dwindle",
    },
    -- ===== DECORACION =====
    decoration = {
        rounding = 8,
        active_opacity = 0.92,
        inactive_opacity = 0.82,
        fullscreen_opacity = 1,
        blur = {
            enabled = true,
            size = 5,
            passes = 2,
        },
    },
    -- ===== MOUSE =====
    misc = {
        mouse_move_enables_dpms = true,
        key_press_enables_dpms = true,
        on_focus_under_fullscreen = 1,
    },
    cursor = {
        sync_gsettings_theme = true,
        inactive_timeout = 5,
    },
    -- ===== INPUT =====
    input = {
        repeat_delay = 200,
        repeat_rate = 50,
    },
})

-- ===== ANIMACIONES =====
hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.animation({ leaf = "windows", enabled = true, speed = 7, bezier = "myBezier" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 7, bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "fade", enabled = true, speed = 7, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "default", style = "slidevert" })

-- ===== ATAJOS =====
local mainMod = "SUPER"

hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("wezterm"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("nemo"))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
-- ===== FULLSCREEN (tres modos, transiciones deterministas) =====
-- SUPER+F          -> maximizar normal: llena el espacio conservando gaps, bordes,
--                     rounding y transparencia (modo "no veo bien").
-- SUPER+SHIFT+F    -> falso fullscreen / concentracion: llena EXACTAMENTE el area
--                     de trabajo de Caelestia, sin gaps, sin borde, opaca. La app
--                     cree que esta en fullscreen real (client=2).
-- SUPER+CONTROL+F  -> fullscreen TRADICIONAL (cubrir toda la pantalla, esconde
--                     Caelestia). Casi no se usa: por eso va detras de CONTROL.
-- Siempre se usa action="set" (el toggle esta roto en 0.55/0.56 y desincroniza
-- internal/client). Cada tecla decide por el estado ACTUAL de la ventana.
local GAPS_OUT = 10
local GAPS_IN = 5

-- Addresses de ventanas puestas a fullscreen tradicional a mano: el listener
-- automatico NO debe reconvertirlas a concentracion.
local manual_real_fs = {}

local function is_fake_fullscreen(w)
    return w ~= nil and w.fullscreen == 1 and w.fullscreen_client == 2
end

-- Sincroniza los gaps globales con la realidad: si hay alguna ventana en falso
-- fullscreen -> 0; si no -> valores por defecto.
local function sync_gaps()
    for _, win in ipairs(hl.get_windows()) do
        if is_fake_fullscreen(win) then
            hl.config({ general = { gaps_out = 0, gaps_in = 0 } })
            return
        end
    end
    hl.config({ general = { gaps_out = GAPS_OUT, gaps_in = GAPS_IN } })
end

hl.bind(mainMod .. " + F", function()
    local w = hl.get_active_window()
    if not w then return end
    if w.fullscreen == 1 and w.fullscreen_client == 1 then
        hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 0, client = 0, action = "set" }))
    else
        hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 1, client = 1, action = "set" }))
    end
    sync_gaps()
end)

hl.bind(mainMod .. " + SHIFT + F", function()
    local w = hl.get_active_window()
    if not w then return end
    if is_fake_fullscreen(w) then
        hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 0, client = 0, action = "set" }))
    else
        hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 1, client = 2, action = "set" }))
    end
    sync_gaps()
end)

hl.bind(mainMod .. " + CONTROL + F", function()
    local w = hl.get_active_window()
    if not w then return end
    if w.fullscreen == 2 or w.fullscreen == 3 then
        manual_real_fs[w.address] = nil
        hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 0, client = 0, action = "set" }))
    else
        manual_real_fs[w.address] = true
        hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 2, client = 2, action = "set" }))
    end
    sync_gaps()
end)

-- Falso fullscreen automatico: si una app pide fullscreen real (cubrir todo),
-- se convierte a llenar el workarea para no esconder Caelestia. Excepto si la
-- ventana fue puesta a fullscreen tradicional a mano (manual_real_fs).
-- Repara el desync del toggle (#14531): si el cliente queda en fullscreen (2)
-- pero la ventana se encoge (internal=0) -> "fullscreen en chiquito". En ese
-- caso la app pide fullscreen de nuevo: se re-aplica (1,2) para llenar el área.
hl.on("window.fullscreen", function(w)
    if not w then return end
    local fs = w.fullscreen
    if fs == 2 or fs == 3 then
        if not manual_real_fs[w.address] then
            hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 1, client = 2, action = "set", window = w }))
        end
    elseif fs == 0 and w.fullscreen_client == 2 then
        hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 1, client = 2, action = "set", window = w }))
    else
        manual_real_fs[w.address] = nil
    end
    sync_gaps()
end)

-- Ventanas en falso fullscreen ESTABLE (internal=1 Y client=2): sin borde,
-- sin rounding, opacas. Definida con nombre para que la reevaluacion de la
-- regla al cambiar el estado fullscreen sea predecible.
hl.window_rule({
    name = "fake-fullscreen-style",
    match = { float = false, fullscreen_state_internal = 1, fullscreen_state_client = 2 },
    border_size = 0,
    rounding = 0,
    opacity = "1.0 override 1.0 override 1.0 override",
})
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("grim -g \"$(slurp)\" - | wl-copy --type image/png"))
hl.bind(mainMod .. " + CONTROL + E", hl.dsp.exit())
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))
hl.bind(mainMod .. " + CONTROL + S", hl.dsp.exec_cmd("systemctl suspend"))
hl.bind(mainMod .. " + CONTROL + ESCAPE", hl.dsp.exec_cmd("systemctl poweroff"))
hl.bind(mainMod .. " + CONTROL + R", hl.dsp.exec_cmd("systemctl reboot"))
hl.bind(mainMod .. " + L", hl.dsp.global("caelestia:lock"))
hl.bind(mainMod .. " + SHIFT + P", hl.dsp.exec_cmd("hyprpicker"))
hl.bind(mainMod .. " + R", hl.dsp.global("caelestia:launcher"), { release = true })

-- Guardar clip del buffer de repeticion de OBS (tecla grave `)
hl.bind("grave", hl.dsp.exec_cmd("OBS_WEBSOCKET_URL=obsws://localhost:4444/btL9G6EhSPwg2U0q obs-cmd replay save"))

-- mover/resize ventanas con el raton (SUPER + clic izq / der)
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- cambiar workspace (1-10)
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- cambiar workspace con la rueda del raton (SUPER + scroll)
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- mover ventana a workspace siguiente/anterior (SUPER + SHIFT + J/K)
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.move({ workspace = "+1" }))
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.move({ workspace = "-1" }))

-- enfocar con flechas
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

-- mover ventanas con flechas
hl.bind(mainMod .. " + SHIFT + left", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + SHIFT + up", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + SHIFT + down", hl.dsp.window.move({ direction = "down" }))

-- navegacion con vim (h, j, k, l)
hl.bind(mainMod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + L", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + J", hl.dsp.focus({ direction = "down" }))

-- mover ventanas con vim (SUPER + SHIFT + h/j/k/l)
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }))

-- rotar entre ventanas del workspace (Alt + Tab), funciona incluso en fullscreen
hl.bind("ALT + Tab", hl.dsp.window.cycle_next(), { dont_inhibit = true })
hl.bind("ALT + SHIFT + Tab", hl.dsp.window.cycle_next({ prev = true }), { dont_inhibit = true })

-- ===== APPS POR WORKSPACE =====
hl.window_rule({ match = { class = "brave-browser" }, workspace = 1 })
hl.window_rule({ match = { class = "vivaldi-stable" }, workspace = 1 })
hl.window_rule({ match = { class = "^vesktop$" }, workspace = 2 })
hl.window_rule({ match = { class = "io.github.tobagin.karere" }, workspace = 2 })
hl.window_rule({ match = { class = "^(steam|steamwebhelper)$" }, workspace = 3, float = false, center = true })
hl.window_rule({ match = { class = "^Spotify$" }, workspace = 4 })
hl.window_rule({ match = { class = "^com.obsproject.Studio$" }, workspace = 5 })

-- ===== INICIO (autostart) =====
hl.on("hyprland.start", function()
    hl.exec_cmd("caelestia-shell -d")
    hl.exec_cmd("/home/ricky/.config/hypr/autostart.sh")
    hl.exec_cmd("/home/ricky/.config/hypr/wallpaper-pick.sh")
    hl.exec_cmd("/home/ricky/.config/hypr/warmup.sh")
    hl.exec_cmd("/home/ricky/.config/hypr/monitor-watch.sh")
end)
