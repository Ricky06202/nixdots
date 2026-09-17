local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- Scheme Caelestia (Material You): usar el mismo accent que los bordes de
-- Hyprland. Caelestia regenera ~/.config/hypr/scheme/current.lua al rotar
-- wallpaper; vigilamos ese archivo para recargar en caliente (WezTerm solo).
local schemePath = os.getenv("HOME") .. "/.config/hypr/scheme/current.lua"
local okCa, CaScheme = pcall(dofile, schemePath)
if not okCa or type(CaScheme) ~= "table" then
    CaScheme = {
        primary = "6750A4", primaryDim = "4f378b", onPrimary = "ffffff",
        base = "161521", text = "e6e0e9", term0 = "545151", term1 = "f28b82",
        term2 = "8ae98b", term3 = "fff370", term4 = "8ab4f8", term5 = "d18ea5",
        term6 = "78d9ec", term7 = "f8f8f8", term8 = "7b7676", term9 = "f28b82",
        term10 = "8ae98b", term11 = "fff370", term12 = "8ab4f8", term13 = "d18ea5",
        term14 = "78d9ec", term15 = "ffffff",
    }
end
local function h(x)
    return "#" .. (x or "000000")
end
local primary   = h(CaScheme.primary)
local primaryDim = h(CaScheme.primaryDim)
local onPrimary = h(CaScheme.onPrimary)
local terminalBG = h(CaScheme.base)
local terminalFG = h(CaScheme.text)
local term = {}
for i = 0, 15 do
    term[i] = h(CaScheme["term" .. i])
end
wezterm.add_to_config_reload_watch_list(schemePath)

config.default_prog = { 'zellij' }

config.hide_tab_bar_if_only_one_tab = true
config.enable_tab_bar = false
config.window_close_confirmation = 'NeverPrompt'

config.font = wezterm.font('IosevkaTerm Nerd Font')
config.font_size = 11.0
config.line_height = 1.15

config.window_background_opacity = 0.88
config.macos_window_background_blur = 0

-- Material You desde Caelestia: palette ANSI completa (term0..15 de Caelestia)
-- + fondo/texto (base/text) + accent primary en cursor/selección/barra.
-- Se actualiza en caliente al rotar wallpaper.
config.colors = {
    background = terminalBG,
    foreground = terminalFG,
    cursor_bg = primary,
    cursor_fg = onPrimary,
    cursor_border = primary,
    selection_bg = primaryDim,
    selection_fg = onPrimary,
    compose_cursor = primary,
    scrollbar_thumb = primaryDim,
    ansi = {
        term[0], term[1], term[2], term[3],
        term[4], term[5], term[6], term[7],
    },
    brights = {
        term[8], term[9], term[10], term[11],
        term[12], term[13], term[14], term[15],
    },
    tab_bar = {
        background = primaryDim,
        active_tab = {
            bg_color = primary,
            fg_color = onPrimary,
            intensity = 'Bold',
        },
        inactive_tab = {
            bg_color = primaryDim,
            fg_color = terminalFG,
        },
        inactive_tab_edge = primaryDim,
    },
}
config.window_frame = {
    active_titlebar_bg = primary,
    active_titlebar_fg = onPrimary,
    inactive_titlebar_bg = primaryDim,
    inactive_titlebar_fg = terminalFG,
    active_titlebar_border_bottom = primary,
    inactive_titlebar_border_bottom = 'transparent',
}

-- Suprime los "toasts" que WezTerm genera al recibir secuencias OSC 9/777.
-- Alguna app dentro de la terminal (zellij/opencode) emite secuencias VACÍAS
-- y se veían como burbujas de notificación sin texto. Valores posibles:
--   AlwaysShow (default), SuppressFromFocusedPane/Tab/Window, NeverShow.
config.notification_handling = 'NeverShow'

return config
