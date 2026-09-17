local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- Scheme Caelestia (Material You): usar el mismo accent que los bordes de
-- Hyprland. Caelestia regenera ~/.config/hypr/scheme/current.lua al rotar
-- wallpaper; vigilamos ese archivo para recargar en caliente (WezTerm solo).
local schemePath = os.getenv("HOME") .. "/.config/hypr/scheme/current.lua"
local okCa, CaScheme = pcall(dofile, schemePath)
if not okCa or type(CaScheme) ~= "table" then
    CaScheme = { primary = "6750A4", primaryDim = "4f378b", onPrimary = "ffffff" }
end
local primary   = "#" .. (CaScheme.primary or "6750A4")
local primaryDim = "#" .. (CaScheme.primaryDim or "4f378b")
local onPrimary = "#" .. (CaScheme.onPrimary or "ffffff")
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

-- Material You desde Caelestia: accent primary en el cursor, la selección,
-- el scrollbar y la barra de título. Se actualiza en caliente al rotar wallpaper.
config.colors = {
    cursor_bg = primary,
    cursor_fg = onPrimary,
    cursor_border = primary,
    selection_bg = primaryDim,
    selection_fg = onPrimary,
    compose_cursor = primary,
    scrollbar_thumb = primaryDim,
    tab_bar = {
        background = primaryDim,
        active_tab = {
            bg_color = primary,
            fg_color = onPrimary,
            intensity = 'Bold',
        },
        inactive_tab = {
            bg_color = primaryDim,
            fg_color = '#f8e0de',
        },
        inactive_tab_edge = primaryDim,
    },
}
config.window_frame = {
    active_titlebar_bg = primary,
    active_titlebar_fg = onPrimary,
    inactive_titlebar_bg = primaryDim,
    inactive_titlebar_fg = '#f8e0de',
    active_titlebar_border_bottom = primary,
    inactive_titlebar_border_bottom = 'transparent',
}

-- Suprime los "toasts" que WezTerm genera al recibir secuencias OSC 9/777.
-- Alguna app dentro de la terminal (zellij/opencode) emite secuencias VACÍAS
-- y se veían como burbujas de notificación sin texto. Valores posibles:
--   AlwaysShow (default), SuppressFromFocusedPane/Tab/Window, NeverShow.
config.notification_handling = 'NeverShow'

return config
