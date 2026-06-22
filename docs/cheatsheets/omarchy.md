# Omarchy Cheatsheet

## Shortcuts

| Shortcut | Action | Scope | Config file |
|---|---|---|---|
| `Super+C` | Copy | Terminal/app-specific | `stow/ghostty`, `stow/alacritty` |
| `Super+V` | Paste | Terminal/app-specific | `stow/ghostty`, `stow/alacritty` |
| `Super+X` | Not globally mapped | Terminal safety | This document |
| `Super+A` | Select all | Ghostty only | `stow/ghostty` |
| `Super+Z` | Not globally mapped | Terminal safety | This document |
| `Super+Shift+Z` | Not globally mapped | Terminal safety | This document |
| `Super+Q` | Close focused window/app | All Omarchy profiles | `stow/hypr/.config/hypr/conf.d/99-omarchy-keymap.conf` |
| `Super+Shift+4` | Region screenshot | All Omarchy profiles | `stow/hypr/.config/hypr/conf.d/99-omarchy-keymap.conf` |
| `Super+Space` | Walker app launcher | All Omarchy profiles | `stow/hypr/.config/hypr/conf.d/99-omarchy-keymap.conf` |
| `Super+Alt+Space` | Omarchy menu | Omarchy default | `~/.local/share/omarchy/default/hypr/bindings/utilities.conf` |
| `Ctrl+1..9` | Switch workspace | All Omarchy profiles | `stow/hypr/.config/hypr/conf.d/99-omarchy-keymap.conf` |
| `Ctrl+Shift+1..9` | Move focused window to workspace and follow | All Omarchy profiles | `stow/hypr/.config/hypr/conf.d/99-omarchy-keymap.conf` |
| `Super+Return` | Terminal (Ghostty via xdg-terminal-exec) | All Omarchy profiles | `stow/hypr/.config/hypr/conf.d/99-omarchy-keymap.conf` |
| `Alt+Return` | Terminal (Ghostty via xdg-terminal-exec) | All Omarchy profiles | `stow/hypr/.config/hypr/conf.d/99-omarchy-keymap.conf` |
| `Alt+Shift+Return` | Alacritty (direct fallback) | All Omarchy profiles | `stow/hypr/.config/hypr/conf.d/99-omarchy-keymap.conf` |
| `Alt+B` | Vivaldi | All Omarchy profiles | `stow/hypr/.config/hypr/conf.d/99-omarchy-keymap.conf` |
| `Alt+Shift+B` | Firefox | All Omarchy profiles | `stow/hypr/.config/hypr/conf.d/99-omarchy-keymap.conf` |
| `Alt+G` | ChatGPT desktop app | All Omarchy profiles | `stow/hypr/.config/hypr/conf.d/99-omarchy-keymap.conf` |
| `Alt+E` | Thunderbird | All Omarchy profiles | `stow/hypr/.config/hypr/conf.d/99-omarchy-keymap.conf` |
| `Ctrl+\`` | Quake terminal | All Omarchy profiles | `stow/hypr/.config/hypr/conf.d/99-omarchy-keymap.conf` |
| `Ctrl+Shift+\`` | Quick notes | All Omarchy profiles | `stow/hypr/.config/hypr/conf.d/99-omarchy-keymap.conf` |
| `Ctrl+Alt+\`` | Todo drawer | All Omarchy profiles | `stow/hypr/.config/hypr/conf.d/99-omarchy-keymap.conf` |
| `Super+Shift+N` | Quick note capture | All Omarchy profiles | `stow/hypr/.config/hypr/conf.d/99-omarchy-keymap.conf` |

## Commands

| Command | Action |
|---|---|
| `hyprctl reload` | Reload Hyprland |
| `hyprctl configerrors` | Show Hyprland config errors |
| `dotfiles desktop reload waybar` | Reload Waybar through dotfiles helper |
| `omarchy restart waybar` | Reload Waybar fallback |
| `dotfiles update` | Update dotfiles platform |
| `dotfiles doctor` | Run dotfiles diagnostics |
| `xdg-terminal-exec --print-id` | Show active default terminal |
| `xdg-terminal-exec --print-cmd` | Show active terminal launch command |
| `z dotfiles` | Jump to a frequent directory with Zoxide |
| `y` | Open Yazi |
| `atuin status` | Check Atuin login/sync state |

## Terminal

Ghostty is the default Omarchy terminal. It is installed from the official Arch
repo (`ghostty` in `packages/desktop/pacman.txt`) and configured at
`stow/ghostty/.config/ghostty/config`.

The default terminal is resolved at runtime via `xdg-terminal-exec`. Bootstrap
writes `~/.config/xdg-terminals.list` and a local desktop entry for Ghostty
through `scripts/configure-omarchy-terminal.sh`.

To verify terminal integration:

```bash
xdg-terminal-exec --print-id      # expected: com.mitchellh.ghostty.desktop
xdg-terminal-exec --print-cmd     # expected: ghostty ...
ghostty --version
```

Alacritty is available as a direct fallback via `Alt+Shift+Return`.

WezTerm is not stowed or installed on Omarchy. It remains available for macOS
profiles only.

## Screenshot Behavior

`Super+Shift+4` runs `omarchy-capture-screenshot region`. It opens a mouse-drag
region selector, captures the selected area, saves through Omarchy's screenshot
convention, copies the image to the clipboard, and shows a notification.
Cancelling the selection saves nothing.

## Notes Workflow

| Search / Shortcut | Action |
|---|---|
| `Ctrl+Shift+\`` | Toggle `~/Documents/Notes/inbox.md` |
| `Ctrl+Alt+\`` | Toggle `~/Documents/Notes/todo.txt` |
| Walker: `Open Notes Inbox` | Open inbox drawer |
| Walker: `Open Todo` | Open todo drawer |
| Walker: `Open Daily Note` | Create/open today's daily markdown note |
| Walker: `Open Notes Projects` | Open projects notes in Yazi |

Notes live in plain files only:

```text
~/Documents/Notes/inbox.md
~/Documents/Notes/todo.txt
~/Documents/Notes/daily/
~/Documents/Notes/projects/
~/Documents/Notes/archive/
```

## Terminal Limitations

Super copy and paste are handled inside Ghostty and Alacritty at the app level.
Super+A (select all) is mapped in Ghostty; Alacritty does not expose a direct
select-all action in its current keybinding API. The dotfiles do not globally
translate Super shortcuts to Ctrl shortcuts because that would break terminal
programs:

| Shortcut | Why it is not globally translated |
|---|---|
| `Super+C -> Ctrl+C` | Would interrupt shell commands |
| `Super+V -> Ctrl+V` | Would trigger shell literal-next behavior |
| `Super+A -> Ctrl+A` | Would jump to line start in shells/readline |
| `Super+Z -> Ctrl+Z` | Would suspend foreground jobs |

## Browser Options

Firefox and Vivaldi are installed across Omarchy profiles. Both continue to support Linux-native `Ctrl+C`, `Ctrl+V`,
`Ctrl+X`, `Ctrl+A`, `Ctrl+Z`, and `Ctrl+Shift+Z` by default.

If browser-only Super shortcuts are required, use a browser extension or a
carefully scoped `xremap` service that targets browser windows only and excludes
terminal classes such as `com.mitchellh.ghostty`, `Alacritty`,
`omarchy-quake-terminal`, and `omarchy-quick-notes`. This repo documents that
option but does not enable an input-remapping daemon by default.
