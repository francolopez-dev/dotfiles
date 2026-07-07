# Where to edit

"I want to change X → edit file Y." Pick the **lowest** layer that makes the
change true everywhere it should apply.

| I want to change… | Edit here |
|---|---|
| A global shell alias / env var | `stow/global/shell/.config/shell/aliases.sh` (or `env.sh`) |
| Terminal UX cheat sheet / audit | `docs/terminal-ux.md` |
| Zsh config / prompt | `stow/global/zsh/.zshrc`, `stow/global/zsh/.p10k.zsh` |
| Git config | `stow/global/git/.gitconfig` |
| Global Git ignore | `stow/global/git/.gitignore_global` |
| tmux | `stow/global/tmux/.tmux.conf` |
| SSH client config | `stow/global/ssh/.ssh/config` |
| Hyprland keybinds (all Omarchy machines) | `stow/os-omarchy/hyprland/.config/hypr/conf.d/99-omarchy-keymap.conf` |
| Hyprland look/feel (all Omarchy machines) | `stow/os-omarchy/hyprland/.config/hypr/conf.d/99-personal.conf` |
| Optional ALT-as-SUPER on one Omarchy machine | `stow/profile-<hostname>-omarchy/hyprland/.config/hypr/conf.d/50-input-alt-super.conf` |
| Waybar | `stow/os-omarchy/waybar/.config/waybar/` |
| Ghostty terminal style/shortcuts | `stow/global/ghostty/.config/ghostty/config` |
| Alacritty terminal style/shortcuts | `stow/global/alacritty/.config/alacritty/alacritty.toml` |
| Terminal font overrides for one machine | `stow/profile-<hostname>-<os>/{ghostty,alacritty}/.config/<terminal>/profile-overrides*` |
| Default terminal launcher | `stow/os-omarchy/xdg-terminal-exec/.config/xdg-terminals.list` |
| Atuin | `stow/global/atuin/.config/atuin/config.toml` |
| Neovim | `stow/global/neovim/.config/nvim/` |
| Monitor scale/resolution for `nox` | `stow/profile-nox-omarchy/hyprland/.config/hypr/conf.d/20-monitors.conf` |
| Monitor scale/resolution for `fornax` | `stow/profile-fornax-omarchy/hyprland/.config/hypr/conf.d/20-monitors.conf` |
| Autostart apps (one machine) | `stow/profile-<hostname>-omarchy/hyprland/.config/hypr/conf.d/30-autostart.conf` |
| Autostart audit ignore list | `stow/profile-<hostname>-omarchy/dotfiles/.config/dotfiles/autostart.ignore` |
| Add an Omarchy pacman package everywhere | `packages/global/pacman.txt` |
| Add an Omarchy AUR package everywhere | `packages/global/aur.txt` |
| Add a package on all Omarchy machines | `packages/os-omarchy/{pacman,aur}.txt` |
| Add a package on one machine | `packages/profile-<hostname>-<os>/{pacman,aur}.txt` |

## Rules of thumb

- **Monitor config is always machine-specific.** It belongs in the profile
  layer's `20-monitors.conf`, never in `os-omarchy`. Putting it in the OS layer
  was the old scale bug.
- **App launcher config stays with Omarchy.** Do not stow launcher config or
  package entries here unless there is a specific new need.
- The OS layer and profile layer both drop files into `conf.d/`, but with
  distinct filenames, so Stow merges them without conflict.
- Optional machine-specific Omarchy features belong in the matching profile
  layer, disabled by default when appropriate.
- After editing anything, run `dotfiles apply`.
- To audit login apps and local startup drift, run `dotfiles autostart status`.
