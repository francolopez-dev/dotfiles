# hypr stow package (Omarchy desktop)

This package provides Omarchy 4 Lua overrides. Do not fork Omarchy's main
Hyprland config in this repo.

Omarchy's main `~/.config/hypr/hyprland.lua` requires these user modules after
its defaults:

```lua
require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")
```

Keep machine-specific monitor and workspace choices out of this layer. Put them
in `stow/profile-<hostname>-omarchy/hyprland/.config/hypr/*.lua`.

## Profile input features

Profile-local input options live with each Omarchy profile, for example:

```text
stow/profile-<hostname>-omarchy/hyprland/.config/hypr/input.lua
```

To make ALT behave as SUPER/Windows for one machine, set the profile input
option:

```lua
hl.config({ input = { kb_options = "compose:caps,altwin:swap_alt_win" } })
```

Then run `dotfiles update`. The update flow reloads Hyprland with
`hyprctl reload`; if the key remap does not take effect immediately, log out and
back in. To disable it, comment the block again and rerun `dotfiles update`.

## Display panel persistence

The Fornax profile uses Omarchy's generic monitor scale variables so the shell
Display panel can persist scale changes. Managed wrappers in
`stow/os-omarchy/scripts/.local/bin/` preserve Stow symlinks when Omarchy updates
monitor scale or profile-managed terminal font sizes.
