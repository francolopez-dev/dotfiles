# Omarchy Desktop Layer

The Omarchy desktop layer is stowed through `profiles/stow-os-base` for every
Omarchy profile:

```text
omarchy: hypr waybar rofi wallpapers themes
```

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

This repo only owns shared personal includes under:

```text
stow/hypr/.config/hypr/conf.d/99-personal.conf
```

The live Omarchy config must include:

```conf
source = ~/.config/hypr/conf.d/*.conf
```

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
