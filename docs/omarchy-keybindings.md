# macOS-like Omarchy keybindings

This repo applies these bindings from the shared Omarchy stow layer, so they
apply to Omarchy desktops such as FORNAX and NOX. Debian/Ubuntu server profiles
and macOS profiles do not load this layer.

## Managed file

```text
stow/os-omarchy/hyprland/.config/hypr/conf.d/40-macos-like-keybindings.conf
stow/os-omarchy/hyprland/.config/hypr/conf.d/99-omarchy-keymap.conf
```

Rollback is a one-file change: remove that file, or remove its `source` line
from `stow/os-omarchy/hyprland/.config/hypr/bindings.conf`, then run
`dotfiles apply` and `hyprctl reload`.

## Focus movement

| Keys | Action |
|---|---|
| `Ctrl+H` | Focus tiled window left |
| `Ctrl+J` | Focus tiled window down |
| `Ctrl+K` | Focus tiled window up |
| `Ctrl+L` | Focus tiled window right |

The direct Omarchy focus bindings are intentionally disabled:

| Disabled keys | Former action |
|---|---|
| `Super+Left` | Focus tiled window left |
| `Super+Right` | Focus tiled window right |
| `Super+Up` | Focus tiled window up |
| `Super+Down` | Focus tiled window down |

Workspace switching, monitor movement, grouped-window movement, and mouse window
movement are not disabled by this override.

## Workspace Switching

These match the macOS AeroSpace split used by this repo: workspaces 1-4 use
`Ctrl+Super`, and workspaces 5-8 use plain `Ctrl`.

| Keys | Action |
|---|---|
| `Ctrl+Super+1` | Workspace 1 |
| `Ctrl+Super+2` | Workspace 2 |
| `Ctrl+Super+3` | Workspace 3 |
| `Ctrl+Super+4` | Workspace 4 |
| `Ctrl+1` | Workspace 5 |
| `Ctrl+2` | Workspace 6 |
| `Ctrl+3` | Workspace 7 |
| `Ctrl+4` | Workspace 8 |

The Shift variants move the focused window and follow it:

| Keys | Action |
|---|---|
| `Ctrl+Super+Shift+1` | Move window to workspace 1 |
| `Ctrl+Super+Shift+2` | Move window to workspace 2 |
| `Ctrl+Super+Shift+3` | Move window to workspace 3 |
| `Ctrl+Super+Shift+4` | Move window to workspace 4 |
| `Ctrl+Shift+1` | Move window to workspace 5 |
| `Ctrl+Shift+2` | Move window to workspace 6 |
| `Ctrl+Shift+3` | Move window to workspace 7 |
| `Ctrl+Shift+4` | Move window to workspace 8 |

## Window resize

| Keys | Action |
|---|---|
| `Ctrl+equal` | Horizontal resize with Hyprland `resizeactive 100 0` |
| `Ctrl+plus` | Same as `Ctrl+equal` on common Linux keyboard layouts |
| `Ctrl+minus` | Horizontal resize with Hyprland `resizeactive -100 0` |

Hyprland receives `equal` as `code:21` and `minus` as `code:20` on the current
Omarchy setup. `plus` is usually `Shift+equal`, so both `Ctrl+equal` and
`Ctrl+Shift+equal` are bound.

This uses Omarchy's existing `resizeactive` dispatcher rather than scripts or
key injection. It is predictable and works globally, but it is directional: in
some layouts the visual effect is tied to the active window's position in the
split tree rather than a universal app-level "make this larger" operation. If
that proves wrong for daily use, the next safe variant to test is Hyprland's
`splitratio` dispatcher.

The old Omarchy resize bindings are intentionally disabled so `Super+plus/minus`
is not consumed by window resizing:

| Disabled keys | Former action |
|---|---|
| `Super+minus` | Omarchy horizontal resize |
| `Super+equal` | Omarchy horizontal resize |
| `Super+Shift+minus` | Omarchy vertical resize |
| `Super+Shift+equal` | Omarchy vertical resize |

## Font and text zoom

`Super+plus/minus` is intentionally not implemented as global font/text zoom.
Hyprland can resize windows globally, but text zoom is app-specific. Omarchy has
a compositor cursor zoom binding (`Super+Ctrl+Z`), terminal font settings, and
theme/font commands, but no stable app-aware command that means "increase text
size in whatever app is focused".

This repo does not use `wtype`, `ydotool`, or other global key injection hacks
to fake browser or terminal zoom. Add app-specific native bindings later only
where the app supports them cleanly.

## Known conflicts

Hyprland global bindings intercept keys before applications receive them.

| Binding | Conflict |
|---|---|
| `Ctrl+plus/minus` | Browser and many app zoom shortcuts |
| `Ctrl+H/J/K/L` | Terminal, shell, tmux, editor, and readline commands, especially `Ctrl+L` clear-screen |

These conflicts are intentional tradeoffs for macOS-like tiling muscle memory.
If an app needs the original keys, remove or change the binding in the managed
file above and reload Hyprland.

## Reload and verify

```bash
cd ~/dotfiles
dotfiles apply
hyprctl reload
hyprctl configerrors
hyprctl binds | grep -Ei "movefocus|resizeactive|CTRL|SUPER|equal|minus|plus|h|j|k|l"
```
