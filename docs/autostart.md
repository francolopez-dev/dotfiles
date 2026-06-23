# Autostart Audit

Use `dotfiles autostart` to audit login/startup items and decide whether they
belong in Git, should stay local, or should be removed.

## Status

```bash
dotfiles autostart status
dotfiles autostart status --all
```

The status view reports:

- Managed Hyprland `exec-once` entries from the active stow layers.
- Items that need a keep/adopt/remove decision.
- Ignored local decisions.
- Read-only system defaults.

By default, read-only system XDG defaults are summarized. Use `--all` to list
them with their `Exec=` commands.

Items that need a decision include local Hyprland `exec-once` entries, user XDG
desktop files in `~/.config/autostart/`, and enabled, linked, or masked user
systemd units.

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

Disable and stop a user systemd unit:

```bash
dotfiles autostart remove synergy.service
# same as:
dotfiles autostart remove systemd:synergy.service
```

System XDG entries under `/etc/xdg/autostart` are read-only.
