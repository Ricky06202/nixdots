local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.default_prog = { 'zellij' }

config.hide_tab_bar_if_only_one_tab = true
config.enable_tab_bar = false
config.window_close_confirmation = 'NeverPrompt'

config.font = wezterm.font('IosevkaTerm Nerd Font')
config.font_size = 11.0
config.line_height = 1.15

config.window_background_opacity = 0.88
config.macos_window_background_blur = 0

return config
