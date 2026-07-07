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

## Profile input features

Profile-local input options live with each Omarchy profile, for example:

```text
stow/profile-<hostname>-omarchy/hyprland/.config/hypr/conf.d/50-input-alt-super.conf
```

To make ALT behave as SUPER/Windows for one machine, uncomment the input block in
that profile's `50-input-alt-super.conf`:

```conf
input {
    kb_options = compose:caps,altwin:swap_alt_win
}
```

Then run `dotfiles update`. The update flow reloads Hyprland with
`hyprctl reload`; if the key remap does not take effect immediately, log out and
back in. To disable it, comment the block again and rerun `dotfiles update`.
