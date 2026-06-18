# hypr stow package (Omarchy desktop)

This package only provides personal include files under
`~/.config/hypr/conf.d/`. Do not fork Omarchy's main Hyprland config in this
repo.

For this layer to apply, the live Omarchy `~/.config/hypr/hyprland.conf` must
source the include directory:

```conf
source = ~/.config/hypr/conf.d/*.conf
```

Keep machine-specific monitor and workspace choices commented unless they are
safe for every Omarchy machine using `profiles/stow-os-base`.
