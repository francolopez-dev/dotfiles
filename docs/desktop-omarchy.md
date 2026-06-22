# Omarchy Desktop Layer

The Omarchy desktop layer is stowed through `profiles/stow-os-base` for every
Omarchy profile:

```text
omarchy: hypr waybar rofi wallpapers themes
```

Omarchy desktop packages are declared in `packages/desktop/pacman.txt`. The base
browser set is Firefox and Vivaldi on every Omarchy profile.

## Waybar

Waybar is managed in:

```text
stow/waybar/.config/waybar/config.jsonc
stow/waybar/.config/waybar/style.css
```

The current config is a cleaned-up Omarchy-friendly bar with workspaces, clock,
tray, bluetooth, network, audio, and battery. It imports the active Omarchy theme
colors from `../omarchy/current/theme/waybar.css` and avoids over-custom styling.

Edit/save workflow:

```bash
cd ~/dotfiles
$EDITOR stow/waybar/.config/waybar/config.jsonc stow/waybar/.config/waybar/style.css
dotfiles desktop reload waybar
git diff
git add stow/waybar/.config/waybar/config.jsonc stow/waybar/.config/waybar/style.css docs/desktop-omarchy.md
git commit -m "Polish Omarchy desktop layer"
git push
```

On another system:

```bash
dotfiles update
dotfiles desktop reload waybar
```

Fallback reload command if the helper is not available:

```bash
omarchy restart waybar
```

Manual backup import, if needed:

```bash
cp ~/.dotfiles-backup/2026-06-18-083542/.config/waybar/config.jsonc stow/waybar/.config/waybar/config.jsonc
cp ~/.dotfiles-backup/2026-06-18-083542/.config/waybar/style.css stow/waybar/.config/waybar/style.css
git diff
dotfiles desktop reload waybar
```

Do not modify or overwrite files inside `~/.dotfiles-backup/`.

## Hyprland

This repo owns shared Omarchy includes under:

```text
stow/hypr/.config/hypr/conf.d/99-omarchy-keymap.conf
```

The live Omarchy config must include:

```conf
source = ~/.config/hypr/conf.d/*.conf
```

The shared keymap applies to every Omarchy profile, including work profiles. It
keeps physical Alt and Super keys unchanged while using Super for macOS-style
window/app muscle memory where Hyprland can do so safely.

Keymap highlights:

| Shortcut | Action |
|---|---|
| `Super+Q` | Close focused window/app |
| `Super+Shift+Z` | Toggle focused window floating/tiling |
| `Super+Shift+4` | Region screenshot through `omarchy-capture-screenshot region` |
| `Super+Space` | Walker app launcher |
| `Ctrl+1..9` | Switch to workspace 1 through 9 |
| `Ctrl+Shift+1..9` | Move focused window to workspace 1 through 9 and follow it |
| `Alt+B` | Launch Vivaldi |
| `Alt+Shift+B` | Launch Firefox |
| `Alt+G` | Launch ChatGPT desktop app |
| `Alt+E` | Launch Thunderbird |
| `Alt+Shift+Return` | Launch Alacritty |
| `Ctrl+`` | Quake terminal |
| `Ctrl+Shift+`` | Quick notes drawer |
| `Ctrl+Alt+`` | Todo drawer |

Keep machine-specific monitor layouts commented unless they are safe across all
Omarchy profiles.

Profile display metadata belongs in `profiles/<profile>.conf`, not in this
shared Hypr include. Bootstrap exports that metadata to:

```text
~/.config/dotfiles/profile.env
```

Quick notes and quake terminal source that file for sizing preferences, then use
live `hyprctl monitors -j` data to size themselves on the active monitor. This is
intentional for docked laptops and multi-monitor desktops where the actual screen
layout changes during the day.

Supported quick-surface monitor modes:

```text
focused
largest
primary
named:<monitor-name>
```

Use `focused` for laptops unless a fixed dock setup needs a named monitor.

Validate live Hypr changes with:

```bash
hyprctl reload
hyprctl configerrors
```

## Terminal

Ghostty is the default Omarchy terminal. Alacritty is available as a fast
fallback (`Alt+Shift+Return`). WezTerm is macOS-only and is not stowed on
Omarchy.

The terminal stack:

| Terminal | Role | Installed by |
|---|---|---|
| Ghostty | Default (`Super+Return`, `Alt+Return`) | `packages/desktop/pacman.txt` |
| Alacritty | Fallback (`Alt+Shift+Return`) | `packages/desktop/pacman.txt` |

`xdg-terminal-exec` is configured to prefer Ghostty by `configure-omarchy-terminal.sh`,
which runs during bootstrap. The Hyprland `Super+Return` / `Alt+Return` bindings
use `xdg-terminal-exec`, so switching the preferred terminal only requires
re-running that script and reloading Hyprland.

### Terminal Keymap

Ghostty and Alacritty map Super copy/paste inside the terminal rather than
globally translating Super to Ctrl. Ghostty also maps Super+A (select all),
Super+T (new tab), Ctrl+Tab (next tab), and Ctrl+Shift+Tab (previous tab).
This avoids breaking shell, Tmux, Neovim, and job-control behavior.

`Super+X` and `Super+Z` are intentionally not mapped in terminals. Use
app-native editing shortcuts inside GUI apps and terminal-native shortcuts
inside terminal programs.

The terminal productivity stack also includes Atuin for shell history, Zoxide for
directory jumping, and Yazi for terminal file management. Zoxide initializes from
`~/.zshrc`; Yazi is available as `y`.

### Quake Terminal

`Ctrl+`` toggles a Ghostty-backed quake terminal. It attaches to a persistent
Tmux session named `quake`, so hiding the drawer does not lose shell state.

## Notes Workflow

Notes are filesystem-only markdown/text files under:

```text
~/Documents/Notes/
inbox.md
todo.txt
daily/
projects/
archive/
```

The quick notes script creates this structure automatically when opened.

| Shortcut / Action | Behavior |
|---|---|
| `Ctrl+Shift+`` | Toggle `inbox.md` in the quick notes drawer |
| `Ctrl+Alt+`` | Toggle `todo.txt` in the todo drawer |
| `Super+Shift+N` | Capture a new markdown note under `~/Documents/Notes/inbox/` |
| Walker: `Open Notes Inbox` | Open `inbox.md` in the quick notes drawer |
| Walker: `Open Todo` | Open `todo.txt` in the todo drawer |
| Walker: `Open Daily Note` | Create/open `daily/YYYY-MM-DD.md` |
| Walker: `Open Notes Projects` | Open `projects/` in Yazi inside Ghostty |

The notes and todo drawers use separate Ghostty classes and Neovim sockets, so
they can be visible at the same time.

## Walker

Walker remains the primary launcher. `Super+Space` explicitly launches Walker via
`omarchy-launch-walker`; Omarchy's menu remains available on `Super+Alt+Space`.

Notes actions are low-maintenance `.desktop` entries stowed into
`~/.local/share/applications/`. Walker finds them through its normal desktop
application provider, so no custom Walker plugin is required.

## Rofi

`stow/rofi` contains a small safe launcher override only. It should not replace
Omarchy's theme system.

## Wallpapers And Themes

`stow/wallpapers` and `stow/themes` are shared library directories:

```text
~/.local/share/wallpapers
~/.local/share/themes
```

Use them for files that are safe to share across Omarchy machines. Do not store
secrets or machine-specific assets here.

## Lenovo Notes

The Waybar network module shows Wi-Fi, wired, or offline state without enabling
or changing NetworkManager. If the Lenovo Ethernet adapter freezes, use Wi-Fi or
USB Ethernet and keep the desktop config unchanged.
