# Autostart Audit

Use `dotfiles autostart` to audit login/startup items and decide whether they
belong in Git, should stay local, or should be removed.

## Status

```bash
dotfiles autostart status
```

The status view reports:

- Managed Hyprland `exec-once` entries from the active stow layers.
- Local Hyprland `exec-once` entries not declared in dotfiles.
- User XDG autostart desktop files in `~/.config/autostart/`.
- System XDG autostart desktop files in `/etc/xdg/autostart/`.
- Enabled, linked, or masked user systemd units.

Each item is printed with an item id such as `hypr:uwsm-app -- slack`,
`xdg:walker.desktop`, `xdg-system:org.fcitx.Fcitx5.desktop`, or
`systemd:synergy.service`.

## Add A Managed Login App

```bash
dotfiles autostart add uwsm-app -- slack
dotfiles autostart apply
```

This appends an `exec-once` entry to the current machine profile:

```text
stow/profile-<hostname>-omarchy/hyprland/.config/hypr/conf.d/30-autostart.conf
```

## Adopt A Local Item

For a local Hyprland command shown by status:

```bash
dotfiles autostart adopt hypr 'uwsm-app -- slack'
dotfiles autostart apply
```

For a user XDG desktop file shown by status:

```bash
dotfiles autostart adopt xdg walker.desktop
dotfiles autostart apply
```

XDG adoption reads `Exec=` and stores it as a managed Hyprland startup command.

## Keep Something Local

```bash
dotfiles autostart ignore xdg:walker.desktop
dotfiles autostart ignore systemd:synergy.service
dotfiles autostart apply
```

Ignored items are stored in the current profile at:

```text
stow/profile-<hostname>-omarchy/dotfiles/.config/dotfiles/autostart.ignore
```

Remove an ignore rule with:

```bash
dotfiles autostart unignore xdg:walker.desktop
```

## Remove

Remove a managed Hyprland command:

```bash
dotfiles autostart remove 'uwsm-app -- slack'
dotfiles autostart apply
```

Remove a user XDG autostart file:

```bash
dotfiles autostart remove xdg:walker.desktop
```

System XDG entries under `/etc/xdg/autostart` are read-only. User systemd
mutation is intentionally not implemented yet; use status to audit them and
`ignore` for units that should remain local.
