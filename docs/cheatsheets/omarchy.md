# Omarchy Cheatsheet

## Shortcuts

| Shortcut | Action | Scope | Config file |
|---|---|---|---|
| `Super+C` | Copy | Terminal/app-specific | `stow/wezterm`, `stow/ghostty`, `stow/alacritty` |
| `Super+V` | Paste | Terminal/app-specific | `stow/wezterm`, `stow/ghostty`, `stow/alacritty` |
| `Super+X` | Not globally mapped | Terminal safety | This document |
| `Super+A` | Select all / copy-mode select all | WezTerm and Ghostty | `stow/wezterm`, `stow/ghostty` |
| `Super+Z` | Not globally mapped | Terminal safety | This document |
| `Super+Shift+Z` | Not globally mapped | Terminal safety | This document |
| `Super+Q` | Close focused window/app | All Omarchy profiles | `stow/hypr/.config/hypr/conf.d/99-omarchy-keymap.conf` |
| `Super+Shift+4` | Region screenshot | All Omarchy profiles | `stow/hypr/.config/hypr/conf.d/99-omarchy-keymap.conf` |
| `Ctrl+1..9` | Switch workspace | All Omarchy profiles | `stow/hypr/.config/hypr/conf.d/99-omarchy-keymap.conf` |
| `Ctrl+Shift+1..9` | Move focused window to workspace and follow | All Omarchy profiles | `stow/hypr/.config/hypr/conf.d/99-omarchy-keymap.conf` |
| `Super+Return` | Terminal | All Omarchy profiles | `stow/hypr/.config/hypr/conf.d/99-omarchy-keymap.conf` |
| `Alt+Return` | Terminal | All Omarchy profiles | `stow/hypr/.config/hypr/conf.d/99-omarchy-keymap.conf` |
| `Alt+Shift+Return` | Alacritty | All Omarchy profiles | `stow/hypr/.config/hypr/conf.d/99-omarchy-keymap.conf` |
| `Alt+B` | Vivaldi | All Omarchy profiles | `stow/hypr/.config/hypr/conf.d/99-omarchy-keymap.conf` |
| `Alt+Shift+B` | Firefox | All Omarchy profiles | `stow/hypr/.config/hypr/conf.d/99-omarchy-keymap.conf` |
| `Alt+G` | ChatGPT desktop app | All Omarchy profiles | `stow/hypr/.config/hypr/conf.d/99-omarchy-keymap.conf` |
| `Alt+E` | Thunderbird | All Omarchy profiles | `stow/hypr/.config/hypr/conf.d/99-omarchy-keymap.conf` |
| `Ctrl+\`` | Quake terminal | All Omarchy profiles | `stow/hypr/.config/hypr/conf.d/99-omarchy-keymap.conf` |
| `Ctrl+Shift+\`` | Quick notes | All Omarchy profiles | `stow/hypr/.config/hypr/conf.d/99-omarchy-keymap.conf` |
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

## Screenshot Behavior

`Super+Shift+4` runs `omarchy-capture-screenshot region`. It opens a mouse-drag region selector, captures the selected area, saves through Omarchy's screenshot convention, copies the image to the clipboard, and shows a notification. Cancelling the selection saves nothing.

## Terminal Limitations

Super copy and paste are handled inside WezTerm, Ghostty, and Alacritty. Super select-all is configured where the terminal exposes a safe action; Alacritty does not currently expose a direct select-all action in its keybinding API. The dotfiles do not globally translate Super shortcuts to Ctrl shortcuts because that would break terminal programs:

| Shortcut | Why it is not globally translated |
|---|---|
| `Super+C -> Ctrl+C` | Would interrupt shell commands |
| `Super+V -> Ctrl+V` | Would trigger shell literal-next behavior |
| `Super+A -> Ctrl+A` | Would jump to line start in shells/readline |
| `Super+Z -> Ctrl+Z` | Would suspend foreground jobs |

## Browser Options

Firefox and Vivaldi continue to support Linux-native `Ctrl+C`, `Ctrl+V`, `Ctrl+X`, `Ctrl+A`, `Ctrl+Z`, and `Ctrl+Shift+Z` by default.

If browser-only Super shortcuts are required, use a browser extension or a carefully scoped `xremap` service that targets browser windows only and excludes terminal classes such as WezTerm, Alacritty, Ghostty, `omarchy-quake-terminal`, and `omarchy-quick-notes`. This repo documents that option but does not enable an input-remapping daemon by default.
