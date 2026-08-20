-- Shared Omarchy 4 keybinding overrides.

local function bind_exec(keys, description, command)
  o.bind(keys, description, command)
end

local function unbind(keys)
  hl.unbind(keys)
end

-- Default terminal for Omarchy launchers that read $TERMINAL directly.
hl.env("TERMINAL", "ghostty")

-- Keep Omarchy's new dynamic keybinding system, but make Super+K show the
-- combined dotfiles registry plus live Omarchy bindings.
unbind("SUPER + K")
bind_exec("SUPER + K", "Dotfiles keybindings and commands", "dotfiles-discovery-menu")

-- Restore the previous terminal and app muscle memory.
unbind("SUPER + RETURN")
unbind("ALT + RETURN")
unbind("SUPER + A")
unbind("SUPER + C")
unbind("SUPER + V")
unbind("SUPER + Q")
unbind("SUPER + W")
unbind("SUPER + SHIFT + RETURN")
unbind("SUPER + SHIFT + V")
unbind("SUPER + SHIFT + N")

bind_exec("SUPER + RETURN", "Terminal", 'uwsm-app -- xdg-terminal-exec --dir="$(omarchy-cmd-terminal-cwd)"')
bind_exec("ALT + RETURN", "Terminal", 'uwsm-app -- xdg-terminal-exec --dir="$(omarchy-cmd-terminal-cwd)"')
bind_exec("ALT + SHIFT + RETURN", "Ghostty", 'uwsm-app -- ghostty --working-directory="$(omarchy-cmd-terminal-cwd)"')
bind_exec("SUPER + SHIFT + RETURN", "Alacritty", 'uwsm-app -- alacritty --working-directory "$(omarchy-cmd-terminal-cwd)"')
bind_exec("SUPER + A", "Select all", "omarchy-terminal-shortcut select-all")
bind_exec("SUPER + C", "Copy", "omarchy-terminal-shortcut copy")
bind_exec("SUPER + V", "Paste", "omarchy-terminal-shortcut paste")
bind_exec("SUPER + W", "Close window/tab", "omarchy-close-window")
bind_exec("SUPER + Q", "Quit app", "omarchy-quit-app")
bind_exec("SUPER + SHIFT + V", "Clipboard manager", "omarchy-launch-walker -m clipboard")
bind_exec("SUPER + SHIFT + N", "Quick capture", "omarchy-notes-capture")

-- Quick surfaces.
bind_exec("CTRL + code:49", "Quake terminal", "omarchy-quake toggle")
bind_exec("CTRL + SHIFT + code:49", "Quick notes", "omarchy-notes toggle")
bind_exec("CTRL + ALT + code:49", "Todo drawer", "omarchy-todo toggle")
bind_exec("CTRL + SHIFT + Z", "Toggle floating", "hyprctl dispatch togglefloating")

-- Omarchy 4 top bar toggle replacement for the old Waybar toggle.
bind_exec("CTRL + SHIFT + B", "Toggle menu bar", "omarchy toggle bar")

-- Region screenshot.
unbind("SUPER + SHIFT + code:13")
unbind("SUPER + SHIFT + 4")

-- Keep the old root-menu shortcut in addition to Omarchy 4's Super+Space.
unbind("SUPER + ALT + SPACE")
bind_exec("SUPER + ALT + SPACE", "Omarchy menu", "omarchy-menu toggle root")

-- Neovim-style window focus and movement.
unbind("SUPER + LEFT")
unbind("SUPER + RIGHT")
unbind("SUPER + UP")
unbind("SUPER + DOWN")
bind_exec("CTRL + H", "Focus window left", "hyprctl dispatch movefocus l")
bind_exec("CTRL + J", "Focus window down", "hyprctl dispatch movefocus d")
bind_exec("CTRL + K", "Focus window up", "hyprctl dispatch movefocus u")
bind_exec("CTRL + L", "Focus window right", "hyprctl dispatch movefocus r")
bind_exec("CTRL + SHIFT + H", "Move window left", "hyprctl dispatch swapwindow l")
bind_exec("CTRL + SHIFT + J", "Move window down", "hyprctl dispatch swapwindow d")
bind_exec("CTRL + SHIFT + K", "Move window up", "hyprctl dispatch swapwindow u")
bind_exec("CTRL + SHIFT + L", "Move window right", "hyprctl dispatch swapwindow r")

-- Move Omarchy's plus/minus resize behavior from Super to Ctrl.
unbind("SUPER + code:20")
unbind("SUPER + code:21")
unbind("SUPER + SHIFT + code:20")
unbind("SUPER + SHIFT + code:21")
bind_exec("CTRL + code:21", "Horizontal resize active window", "hyprctl dispatch resizeactive 100 0")
bind_exec("CTRL + SHIFT + code:21", "Horizontal resize active window", "hyprctl dispatch resizeactive 100 0")
bind_exec("CTRL + code:20", "Horizontal resize active window opposite", "hyprctl dispatch resizeactive -100 0")

-- Aerospace-style workspace navigation.
for workspace = 1, 10 do
  local stock_key = "code:" .. tostring(workspace + 9)
  unbind("SUPER + " .. stock_key)
  unbind("SUPER + SHIFT + " .. stock_key)
  unbind("SUPER + ALT + SHIFT + " .. stock_key)
  unbind("SUPER + SHIFT + ALT + " .. stock_key)
  unbind("SUPER + " .. tostring(workspace))
  unbind("SUPER + SHIFT + " .. tostring(workspace))
  unbind("SUPER + ALT + SHIFT + " .. tostring(workspace))
  unbind("SUPER + SHIFT + ALT + " .. tostring(workspace))
end

bind_exec("SUPER + SHIFT + code:13", "Region screenshot", "omarchy-capture-screenshot region")
bind_exec("SUPER + SHIFT + 4", "Region screenshot", "omarchy-capture-screenshot region")

for workspace = 1, 4 do
  local key = "code:" .. tostring(workspace + 9)
  unbind("CTRL + " .. key)
  unbind("CTRL + SHIFT + " .. key)
  bind_exec("CTRL + " .. key, "Workspace " .. workspace, "hyprctl dispatch workspace " .. workspace)
  bind_exec("CTRL + SHIFT + " .. key, "Move window to workspace " .. workspace, "sh -lc 'hyprctl dispatch movetoworkspace " .. workspace .. " && hyprctl dispatch workspace " .. workspace .. "'")
end

for workspace = 5, 8 do
  local key = "code:" .. tostring(workspace + 5)
  unbind("CTRL + SUPER + " .. key)
  unbind("CTRL + SUPER + SHIFT + " .. key)
  bind_exec("CTRL + SUPER + " .. key, "Workspace " .. workspace, "hyprctl dispatch workspace " .. workspace)
  bind_exec("CTRL + SUPER + SHIFT + " .. key, "Move window to workspace " .. workspace, "sh -lc 'hyprctl dispatch movetoworkspace " .. workspace .. " && hyprctl dispatch workspace " .. workspace .. "'")
end

-- App launchers.
bind_exec("ALT + B", "Brave", "uwsm-app -- brave")
bind_exec("ALT + SHIFT + B", "Firefox", "uwsm-app -- firefox")

-- Keep quick surfaces clean and reusable.
o.window("^(omarchy-quick-notes|omarchy-todo-drawer|omarchy-quake-terminal)$", { float = true })
o.window("^(omarchy-quick-notes|omarchy-todo-drawer|omarchy-quake-terminal)$", { border_size = 0 })
o.window("^omarchy-quick-notes$", { opacity = "0.96 0.92" })
o.window("^omarchy-todo-drawer$", { opacity = "0.96 0.92" })
o.window("^omarchy-quake-terminal$", { opacity = "0.97 0.94" })
