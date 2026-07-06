# hypr stow package (Omarchy desktop)

This package provides small top-level Omarchy override files plus personal
include files under `~/.config/hypr/conf.d/`. Do not fork Omarchy's main
Hyprland config in this repo.

Omarchy's main `~/.config/hypr/hyprland.conf` sources these user files after its
defaults:

```conf
source = ~/.config/hypr/monitors.conf
source = ~/.config/hypr/input.conf
source = ~/.config/hypr/bindings.conf
source = ~/.config/hypr/looknfeel.conf
source = ~/.config/hypr/autostart.conf
```

The stowed top-level files source the matching dotfiles fragments in `conf.d/`.

Keep machine-specific monitor and workspace choices out of this layer. Put them
in `stow/profile-<hostname>-omarchy/hyprland/.config/hypr/conf.d/`.

## Optional input features

Omarchy profiles may opt into optional Omarchy-only stow layers via:

```text
profiles/profile-<hostname>-omarchy/stow-layers.txt
```

To make ALT behave as SUPER/Windows for one machine, add this line to that
machine's manifest:

```text
os-omarchy-alt-super
```

Then run `dotfiles update`. The update flow reloads Hyprland with
`hyprctl reload`; if the key remap does not take effect immediately, log out and
back in. To disable it, remove or comment that line and rerun `dotfiles update`.
