-- Shared Omarchy 4 keybinding overrides.

local function bind_exec(keys, description, command)
  o.bind(keys, description, command)
end

local function unbind(keys)
  hl.unbind(keys)
end

local function send_shortcut_once(mods, key)
  return function()
    hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "down" }))
    hl.timer(function()
      hl.dispatch(hl.dsp.send_key_state({ mods = mods, key = key, state = "up" }))
    end, { timeout = 50, type = "oneshot" })
  end
end

local function active_window_is_terminal()
  local window = hl.get_active_window()
  if not window then return false end
  for _, tag in ipairs(window.tags or {}) do
    if tag:gsub("%*$", "") == "terminal" then return true end
  end
  return false
end

local function universal_shortcut(default_mods, default_key, terminal_mods, terminal_key)
  return function()
    if active_window_is_terminal() then
      send_shortcut_once(terminal_mods, terminal_key)()
    else
      send_shortcut_once(default_mods, default_key)()
    end
  end
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
unbind("ALT + A")
unbind("ALT + C")
unbind("ALT + V")
unbind("SUPER + Q")
unbind("ALT + Q")
unbind("SUPER + W")
unbind("ALT + W")
unbind("SUPER + SHIFT + RETURN")
unbind("SUPER + SHIFT + V")
unbind("ALT + SHIFT + V")
unbind("SUPER + SHIFT + N")
unbind("SUPER + T")

bind_exec("SUPER + RETURN", "Terminal", "omarchy-launch-terminal")
bind_exec("ALT + RETURN", "Terminal", "omarchy-launch-terminal")
bind_exec("ALT + SHIFT + RETURN", "Ghostty", 'uwsm-app -- ghostty --working-directory="$(omarchy-cmd-terminal-cwd)"')
bind_exec("SUPER + SHIFT + RETURN", "Alacritty", 'uwsm-app -- alacritty --working-directory "$(omarchy-cmd-terminal-cwd)"')
o.bind("SUPER + A", "Select all", universal_shortcut("CTRL", "A", "SUPER", "A"))
o.bind("ALT + A", "Select all", universal_shortcut("CTRL", "A", "SUPER", "A"))
o.bind("ALT + C", "Universal copy", universal_shortcut("CTRL", "C", "CTRL", "Insert"))
o.bind("ALT + V", "Universal paste", universal_shortcut("CTRL", "V", "SHIFT", "Insert"))
bind_exec("SUPER + W", "Close window/tab", "omarchy-close-window")
bind_exec("ALT + W", "Close window/tab", "omarchy-close-window")
bind_exec("SUPER + Q", "Quit app", "omarchy-quit-app")
bind_exec("ALT + Q", "Quit app", "omarchy-quit-app")
bind_exec("SUPER + SHIFT + V", "Clipboard manager", "omarchy-shell shell toggle omarchy.clipboard")
bind_exec("ALT + SHIFT + V", "Clipboard manager", "omarchy-shell shell toggle omarchy.clipboard")
bind_exec("SUPER + SHIFT + N", "Quick capture", "omarchy-launch-terminal --title='Quick capture' -- omarchy-notes-capture")

-- Quick surfaces.
bind_exec("CTRL + grave", "Quake terminal", "omarchy-quake toggle")
bind_exec("CTRL + SHIFT + grave", "Quick notes", "omarchy-notes toggle")
bind_exec("CTRL + ALT + grave", "Todo drawer", "omarchy-todo toggle")
o.bind("CTRL + SHIFT + Z", "Toggle floating", hl.dsp.window.float({ action = "toggle" }))

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
unbind("SUPER + SHIFT + LEFT")
unbind("SUPER + SHIFT + RIGHT")
unbind("SUPER + SHIFT + UP")
unbind("SUPER + SHIFT + DOWN")
o.bind("CTRL + H", "Focus window left", hl.dsp.focus({ direction = "l" }))
o.bind("CTRL + J", "Focus window down", hl.dsp.focus({ direction = "d" }))
o.bind("CTRL + K", "Focus window up", hl.dsp.focus({ direction = "u" }))
o.bind("CTRL + L", "Focus window right", hl.dsp.focus({ direction = "r" }))
o.bind("CTRL + SHIFT + H", "Move window left", hl.dsp.window.swap({ direction = "l" }))
o.bind("CTRL + SHIFT + J", "Move window down", hl.dsp.window.swap({ direction = "d" }))
o.bind("CTRL + SHIFT + K", "Move window up", hl.dsp.window.swap({ direction = "u" }))
o.bind("CTRL + SHIFT + L", "Move window right", hl.dsp.window.swap({ direction = "r" }))

-- Move Omarchy's plus/minus resize behavior from Super to Ctrl.
unbind("SUPER + code:20")
unbind("SUPER + code:21")
unbind("SUPER + SHIFT + code:20")
unbind("SUPER + SHIFT + code:21")
o.bind("CTRL + equal", "Horizontal resize active window", hl.dsp.window.resize({ x = 100, y = 0, relative = true }))
o.bind("CTRL + SHIFT + equal", "Horizontal resize active window", hl.dsp.window.resize({ x = 100, y = 0, relative = true }))
o.bind("CTRL + minus", "Horizontal resize active window opposite", hl.dsp.window.resize({ x = -100, y = 0, relative = true }))

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

bind_exec("SUPER + SHIFT + 4", "Region screenshot", "omarchy-capture-screenshot region")

-- Omarchy 4.0.0 registers its code:N workspace defaults with blank keys.
-- Recreate the switch bindings with symbolic number-row keys.
for workspace = 1, 10 do
  local key = workspace == 10 and "0" or tostring(workspace)
  o.bind("SUPER + " .. key, "Switch to workspace " .. workspace, hl.dsp.focus({ workspace = tostring(workspace) }))
end

for workspace = 1, 4 do
  local key = tostring(workspace)
  unbind("CTRL + " .. key)
  unbind("CTRL + SHIFT + " .. key)
  o.bind("CTRL + " .. key, "Workspace " .. workspace, hl.dsp.focus({ workspace = tostring(workspace) }))
  o.bind("CTRL + SHIFT + " .. key, "Move window to workspace " .. workspace, hl.dsp.window.move({ workspace = tostring(workspace) }))
end

for workspace = 5, 8 do
  local key = tostring(workspace - 4)
  unbind("CTRL + SUPER + " .. key)
  unbind("CTRL + ALT + " .. key)
  unbind("CTRL + SUPER + SHIFT + " .. key)
  unbind("CTRL + ALT + SHIFT + " .. key)
  o.bind("CTRL + SUPER + " .. key, "Workspace " .. workspace, hl.dsp.focus({ workspace = tostring(workspace) }))
  o.bind("CTRL + ALT + " .. key, "Workspace " .. workspace, hl.dsp.focus({ workspace = tostring(workspace) }))
  o.bind("CTRL + SUPER + SHIFT + " .. key, "Move window to workspace " .. workspace, hl.dsp.window.move({ workspace = tostring(workspace) }))
  o.bind("CTRL + ALT + SHIFT + " .. key, "Move window to workspace " .. workspace, hl.dsp.window.move({ workspace = tostring(workspace) }))
end

-- Repair the remaining Omarchy 4.0.0 defaults whose code:N keys register as
-- blank bindings under Hyprland 0.56.
local resize_repairs = {
  { "SUPER + ALT", "minus", "Expand window left a little", -25, 0 },
  { "SUPER + ALT", "equal", "Shrink window left a little", 25, 0 },
  { "SUPER + SHIFT + ALT", "minus", "Shrink window up a little", 0, -25 },
  { "SUPER + SHIFT + ALT", "equal", "Expand window down a little", 0, 25 },
  { "SUPER + CTRL", "minus", "Expand window left a lot", -300, 0 },
  { "SUPER + CTRL", "equal", "Shrink window left a lot", 300, 0 },
  { "SUPER + CTRL + SHIFT", "minus", "Shrink window up a lot", 0, -300 },
  { "SUPER + CTRL + SHIFT", "equal", "Expand window down a lot", 0, 300 },
}

for _, repair in ipairs(resize_repairs) do
  o.bind(
    repair[1] .. " + " .. repair[2],
    repair[3],
    hl.dsp.window.resize({ x = repair[4], y = repair[5], relative = true })
  )
end

for index = 1, 5 do
  o.bind("SUPER + ALT + " .. index, "Switch to group window " .. index, hl.dsp.group.active({ index = index }))
end

bind_exec("SUPER + SHIFT + F23", "Omarchy menu", "omarchy-menu toggle root")
bind_exec("SUPER + ALT + bracketleft", "Make webcam overlay smaller", "omarchy-capture-webcam-resize smaller")
bind_exec("SUPER + ALT + bracketright", "Make webcam overlay larger", "omarchy-capture-webcam-resize larger")

for panel = 1, 9 do
  local keys = panel <= 4 and "SUPER + CTRL + ALT + " .. panel or "SUPER + CTRL + " .. panel
  bind_exec(keys, "Bar panel " .. panel, "omarchy-shell -q shell togglePanelAt right " .. panel)
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
