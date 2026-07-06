# Omarchy Wallpapers

This repo manages base Omarchy wallpapers and a user timer for automatic rotation.
It only applies to Omarchy profiles through the `stow/os-omarchy` layer.

The design is intentionally simple:

- Git tracks the small base wallpaper set.
- Personal pictures stay local on each machine.
- Rotation uses both sources when both exist.
- The setter follows Omarchy's current background symlink plus `swaybg` behavior.
- Debian, Ubuntu, and future non-Omarchy profiles do not get this system.

## Locations

Repo-managed wallpapers live here:

```text
stow/os-omarchy/wallpapers/.config/omarchy/backgrounds/tokyo-night/
```

After stow, Omarchy sees them here:

```text
~/.config/omarchy/backgrounds/tokyo-night/
```

Local personal wallpapers go here and are not in Git:

```text
~/Pictures/Wallpapers/local/
```

`dotfiles update` creates the local folder automatically on Omarchy machines.
The managed repo folder follows the current Omarchy theme audited on this host,
`tokyo-night`, so Omarchy's own background cycling includes these images too.

Add repo-managed wallpapers by copying images into:

```text
stow/os-omarchy/wallpapers/.config/omarchy/backgrounds/tokyo-night/
```

Then commit them to Git.

Add private local wallpapers by copying images into:

```text
~/Pictures/Wallpapers/local/
```

Do not commit personal images. That folder lives outside the repo.

## Rotation

Configuration lives in:

```text
~/.config/dotfiles/wallpapers.conf
```

Change the interval by editing:

```bash
WALLPAPER_ROTATION_INTERVAL="15m"
```

Supported suffixes are `s`, `m`, `h`, and `d`. The default is `15m`.

Examples:

```bash
WALLPAPER_ROTATION_INTERVAL="5m"
WALLPAPER_ROTATION_INTERVAL="30m"
WALLPAPER_ROTATION_INTERVAL="2h"
WALLPAPER_ROTATION_INTERVAL="1d"
```

Apply config changes with:

```bash
dotfiles apply
dotfiles update
```

Disable rotation by setting:

```bash
WALLPAPER_ROTATION_ENABLED=0
```

Then run:

```bash
systemctl --user disable --now dotfiles-wallpaper-rotate.timer
```

Enable it again with:

```bash
systemctl --user enable --now dotfiles-wallpaper-rotate.timer
```

If you only changed `WALLPAPER_ROTATION_ENABLED`, `dotfiles update` will also
enable or disable the timer for you.

## Supported Images

Rotation includes these file types from both wallpaper folders:

- `jpg`
- `jpeg`
- `png`
- `webp`

Broken or empty files are skipped when ImageMagick's `magick` or `identify`
command is available. If no valid wallpaper exists, rotation exits without
crashing.

## Commands

Rotate now:

```bash
dotfiles wallpaper rotate
```

Show wallpaper state:

```bash
dotfiles wallpaper status
```

Open the local folder:

```bash
dotfiles wallpaper open-local
```

The rotation script follows the behavior audited from Omarchy's background
command: update `~/.config/omarchy/current/background`, then run `swaybg` with
that symlink.

Omarchy's own command is:

```bash
omarchy theme bg set <image>
```

The dotfiles script does the restart itself so a failed `swaybg` launch can be
detected. If the new background fails to start, it restores the previous
background instead of leaving the desktop black.

Omarchy's manual background cycling still works with:

```text
Super + Ctrl + Space
```

Because repo wallpapers are placed under Omarchy's user background folder for
the active theme, Omarchy can include them in its own background choices.

## Systemd Timer

The timer files are stowed to:

```text
~/.config/systemd/user/dotfiles-wallpaper-rotate.service
~/.config/systemd/user/dotfiles-wallpaper-rotate.timer
```

Check the timer with:

```bash
systemctl --user status dotfiles-wallpaper-rotate.timer
```

The systemd timer wakes every minute. The script enforces the configured
`WALLPAPER_ROTATION_INTERVAL`, which keeps interval changes in one file.

## Troubleshooting

Show current state:

```bash
dotfiles wallpaper status
```

Verify paths exist:

```bash
ls ~/.config/omarchy/backgrounds/tokyo-night
ls ~/Pictures/Wallpapers/local
```

Rotate manually and watch for errors:

```bash
dotfiles wallpaper rotate
```

Reload and restart the timer:

```bash
systemctl --user daemon-reload
systemctl --user restart dotfiles-wallpaper-rotate.timer
```
