local wezterm = require("wezterm")

local config = wezterm.config_builder()

config.check_for_updates = false
config.automatically_reload_config = true

-- Appearance
config.color_scheme = "Catppuccin Mocha"
config.window_decorations = "RESIZE"
config.window_padding = { left = 20, right = 20, top = 20, bottom = 20 }

-- Font
config.font = wezterm.font_with_fallback({
	"JetBrains Mono",
	"FiraCode Nerd Font",
	"Menlo",
})
config.font_size = 16.0

-- Tabs
config.use_fancy_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true
config.tab_bar_at_bottom = true

-- Behavior
config.scrollback_lines = 10000
config.enable_scroll_bar = false
config.audible_bell = "Disabled"

-- Quick copy mode and sane shortcuts
config.keys = {
	{ key = "v", mods = "CMD", action = wezterm.action.PasteFrom("Clipboard") },
	{ key = "c", mods = "CMD", action = wezterm.action.CopyTo("Clipboard") },

	-- Split panes
	{ key = "d", mods = "CMD", action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "D", mods = "CMD|SHIFT", action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }) },

	-- Navigate panes
	{ key = "h", mods = "CMD|ALT", action = wezterm.action.ActivatePaneDirection("Left") },
	{ key = "j", mods = "CMD|ALT", action = wezterm.action.ActivatePaneDirection("Down") },
	{ key = "k", mods = "CMD|ALT", action = wezterm.action.ActivatePaneDirection("Up") },
	{ key = "l", mods = "CMD|ALT", action = wezterm.action.ActivatePaneDirection("Right") },

	-- New tab
	{ key = "t", mods = "CMD", action = wezterm.action.SpawnTab("CurrentPaneDomain") },
}

-- Make sure default shell is zsh if installed
if wezterm.target_triple:find("apple") then
	config.default_prog = { "/bin/zsh", "-l" }
else
	config.default_prog = { "zsh", "-l" }
end

return config
