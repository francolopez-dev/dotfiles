# Where to edit

"I want to change X → edit file Y." Pick the **lowest** layer that makes the
change true everywhere it should apply.

| I want to change… | Edit here |
|---|---|
| A global shell alias / env var | `stow/global/shell/.config/shell/aliases.sh` (or `env.sh`) |
| Zsh config / prompt | `stow/global/zsh/.zshrc`, `stow/global/zsh/.p10k.zsh` |
| Git ignore / config | `stow/global/git/.config/git/` |
| tmux | `stow/global/tmux/.tmux.conf` |
| SSH client config | `stow/global/ssh/.ssh/config` |
| Hyprland keybinds (all Omarchy machines) | `stow/os-omarchy/hyprland/.config/hypr/conf.d/99-omarchy-keymap.conf` |
| Hyprland look/feel (all Omarchy machines) | `stow/os-omarchy/hyprland/.config/hypr/conf.d/99-personal.conf` |
| Waybar | `stow/os-omarchy/waybar/.config/waybar/` |
| Rofi | `stow/os-omarchy/rofi/.config/rofi/` |
| Ghostty terminal | `stow/os-omarchy/ghostty/.config/ghostty/config` |
| Atuin | `stow/os-omarchy/atuin/.config/atuin/config.toml` |
| Neovim | `stow/os-omarchy/neovim/.config/nvim/` |
| **Monitor scale/resolution (one machine)** | `stow/profile-<hostname>-omarchy/hyprland/.config/hypr/conf.d/20-monitors.conf` |
| Autostart apps (one machine) | `stow/profile-<hostname>-omarchy/hyprland/.config/hypr/conf.d/30-autostart.conf` |
| Add a package everywhere | `packages/global.list` |
| Add a package on all Omarchy machines | `packages/os-omarchy.list` |
| Add a package on one machine | `packages/profile-<hostname>-<os>.list` |

## Rules of thumb

- **Monitor config is always machine-specific.** It belongs in the profile
  layer's `20-monitors.conf`, never in `os-omarchy`. (Putting it in the OS layer
  was the old "scale not applying" bug.)
- The OS layer and the profile layer both drop files into `conf.d/`, but with
  **distinct filenames**, so Stow merges them without conflict.
- After editing anything, run `dotfiles apply`.
