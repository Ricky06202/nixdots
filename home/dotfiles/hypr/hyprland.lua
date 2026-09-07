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
-- ===== FULLSCREEN (percepcion por niveles) =====
-- Boton de la app -> IN-PLACE determinista (internal=0 client=2): la ventana se
--                    queda en su hueco del layout y la app cree que esta a
--                    pantalla completa (el video llena su ventanita).
-- SUPER+F          -> GRANDE normal (internal=1 client=1, maximizar): la app NO
--                     se entera del fullscreen -> el navegador conserva sus tabs.
--                     Conserva gaps, borde, rounding y transparencia.
-- SUPER+SHIFT+F    -> CONCENTRACION (internal=1 client=2): fullscreen real para
--                     la app (esconde tabs/UI); opaca, sin gaps, sin borde.
-- SUPER+CONTROL+F  -> TRADICIONAL (internal=2 client=2): cubre TODA la pantalla.
-- Solo SHIFT+F y CONTROL+F notifican fullscreen a la app; F solo agranda.
-- Siempre action="set" con estado explicito: nunca dependemos del toggle de la app.
local GAPS_OUT = 10
local GAPS_IN = 5
local BORDER_SIZE = 2

-- address -> "big" | "conc" | "trad"  (el in-place de la app y el F normal no se registran)
local mode = {}

-- Regla de estilo para el modo CONCENTRACION: se activa/desactiva segun el modo.
-- Nota: el match de estados fullscreen es fragil con juegos (Wine/Proton lanzan
-- ventanas con estados distintos), asi que el border se maneja GLOBALMENTE en
-- sync_perception (este rule solo pulles el rounding y la opacidad).
local conc_rule = hl.window_rule({
    name = "fake-fullscreen-style",
    match = { fullscreen_state_internal = 1 },
    rounding = 0,
    opacity = "1.0 override 1.0 override 1.0 override",
})
conc_rule:set_enabled(false)

local function any_mode(m)
    for _, v in pairs(mode) do
        if v == m then return true end
    end
    return false
end

-- Aplica percepcion global segun los modos activos.
-- conc (SHIFT+F): SIN gaps ni borde (immersivo, el juego llena la pantalla).
-- big (SUPER+F) y normal: conservan gaps (GAPS_OUT/GAPS_IN) y borde.
local function sync_perception()
    if any_mode("conc") then
        hl.config({ general = { gaps_out = 0, gaps_in = 0, border_size = 0 } })
        conc_rule:set_enabled(true)
    else
        hl.config({ general = { gaps_out = GAPS_OUT, gaps_in = GAPS_IN, border_size = BORDER_SIZE } })
        conc_rule:set_enabled(false)
    end
end

local function set_window_mode(w, m)
    mode[w.address] = m
    local internal = 0
    local client = 2
    if m == "big" then
        internal = 1
        client = 1   -- la app NO se entera del fullscreen (conserva tabs/UI)
    elseif m == "conc" then
        internal = 1
        client = 2   -- la app SI ve fullscreen (esconde su UI)
    elseif m == "trad" then
        internal = 2
        client = 2   -- fullscreen total
    end
    hl.dispatch(hl.dsp.window.fullscreen_state({ internal = internal, client = client, action = "set", window = w }))
    sync_perception()
end

local function clear_window_mode(w)
    mode[w.address] = nil
    hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 0, client = 0, action = "set", window = w }))
    sync_perception()
end

-- Por si cierra una ventana en modo activo (evita gaps=0 clavados).
hl.on("window.destroy", function(w)
    if w and mode[w.address] then
        mode[w.address] = nil
        sync_perception()
    end
end)

hl.bind(mainMod .. " + F", function()
    local w = hl.get_active_window()
    if not w then return end
    if mode[w.address] == "big" then
        clear_window_mode(w)
        return
    end
    set_window_mode(w, "big")
end)

hl.bind(mainMod .. " + SHIFT + F", function()
    local w = hl.get_active_window()
    if not w then return end
    if mode[w.address] == "conc" then
        clear_window_mode(w)
    else
        set_window_mode(w, "conc")
    end
end)

hl.bind(mainMod .. " + CONTROL + F", function()
    local w = hl.get_active_window()
    if not w then return end
    if mode[w.address] == "trad" then
        clear_window_mode(w)
    else
        set_window_mode(w, "trad")
    end
end)

-- Cuando la app pide fullscreen real -> la convertimos a IN-PLACE determinista
-- (internal=0 client=2): la ventana conserva su hueco y la app ve fullscreen.
-- Si la app sale sola del fullscreen -> limpiamos el estado (forzamos (0,0)).
hl.on("window.fullscreen", function(w)
    if not w then return end
    if mode[w.address] then
        if w.fullscreen_client == 0 then
            if mode[w.address] == "big" then
                -- Estando en SUPER+F y la app sale de su propio fullscreen:
                -- re-aplicamos big (internal=1 client=1) para que se quede en
                -- el mismo tamanio grande, no colapse a ventana chiquita.
                set_window_mode(w, "big")
            else
                mode[w.address] = nil
                hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 0, client = 0, action = "set", window = w }))
                sync_perception()
            end
        end
        return
    end
    if w.fullscreen == 2 or w.fullscreen == 3 then
        hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 0, client = 2, action = "set", window = w }))
    end
end)

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
