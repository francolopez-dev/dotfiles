# macOS-like Omarchy keybindings

This repo applies these bindings from the shared Omarchy stow layer, so they
apply to Omarchy desktops such as FORNAX and NOX. Debian/Ubuntu server profiles
and macOS profiles do not load this layer.

## Managed file

```text
stow/os-omarchy/hyprland/.config/hypr/bindings.lua
stow/profile-fornax-omarchy/hyprland/.config/hypr/input.lua
```

Fornax swaps Alt and Super with `altwin:swap_alt_win`, so the physical Alt key
acts as Hyprland `SUPER` and the physical Super/Windows key acts as Hyprland
`ALT`. Important Command-style shortcuts are bound to both logical `SUPER` and
logical `ALT` where practical, so either physical key works for copy/paste.

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

These match the working Fornax split from the pre-Omarchy-4 config: workspaces
1-4 use plain `Ctrl`, and workspaces 5-8 use `Ctrl+Super`. On Fornax, because
Alt/Super are swapped, `Ctrl+Alt+1-4` is also bound as a physical-Super alias
for workspaces 5-8.

| Keys | Action |
|---|---|
| `Ctrl+1` | Workspace 1 |
| `Ctrl+2` | Workspace 2 |
| `Ctrl+3` | Workspace 3 |
| `Ctrl+4` | Workspace 4 |
| `Ctrl+Super+1` / `Ctrl+Alt+1` | Workspace 5 |
| `Ctrl+Super+2` / `Ctrl+Alt+2` | Workspace 6 |
| `Ctrl+Super+3` / `Ctrl+Alt+3` | Workspace 7 |
| `Ctrl+Super+4` / `Ctrl+Alt+4` | Workspace 8 |

The Shift variants move the focused window and follow it:

| Keys | Action |
|---|---|
| `Ctrl+Shift+1` | Move window to workspace 1 |
| `Ctrl+Shift+2` | Move window to workspace 2 |
| `Ctrl+Shift+3` | Move window to workspace 3 |
| `Ctrl+Shift+4` | Move window to workspace 4 |
| `Ctrl+Super+Shift+1` / `Ctrl+Alt+Shift+1` | Move window to workspace 5 |
| `Ctrl+Super+Shift+2` / `Ctrl+Alt+Shift+2` | Move window to workspace 6 |
| `Ctrl+Super+Shift+3` / `Ctrl+Alt+Shift+3` | Move window to workspace 7 |
| `Ctrl+Super+Shift+4` / `Ctrl+Alt+Shift+4` | Move window to workspace 8 |

## Command-Style Shortcuts

| Keys | Action |
|---|---|
| `Super+A` / `Alt+A` | Select all through `omarchy-terminal-shortcut` |
| `Super+C` / `Alt+C` | Copy through `omarchy-terminal-shortcut` |
| `Super+V` / `Alt+V` | Paste through `omarchy-terminal-shortcut` |
| `Super+W` / `Alt+W` | Close window/tab |
| `Super+Q` / `Alt+Q` | Quit app |
| `Super+Shift+V` / `Alt+Shift+V` | Clipboard manager |
| `Super+Return` / `Alt+Return` | Default terminal via `xdg-terminal-exec` |

Ghostty is the default terminal through both `$TERMINAL=ghostty` and
`~/.config/xdg-terminals.list`.

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
hyprctl binds -j | jq -r '.[] | select((.description // "") | test("Workspace|Copy|Paste|Select all|Terminal")) | [.modmask,.key,.description] | @tsv'
```
