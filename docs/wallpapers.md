# Wallpapers

One command, `dotfiles-wallpaper`, owns wallpaper config, source merging,
selection, state, and status across supported OSes. OS-specific code only sets
the selected image.

## Locations

Shared repo wallpapers live in:

```text
stow/global/wallpapers/.local/share/wallpapers/shared/
```

After stow, all OSes read them from:

```text
~/.local/share/wallpapers/shared/
```

Local personal wallpapers go here on every OS and are never committed:

```text
~/Pictures/local-wallpapers/
```

The engine merges the local folder only when it exists. `dotfiles update`
creates it for managed Omarchy/macOS machines; `dotfiles wallpaper open-local`
also creates it on demand.

Migration note for the day-one Omarchy engine: move any existing local images
from `~/Pictures/Wallpapers/local/` to `~/Pictures/local-wallpapers/`.

## Config

Configuration is stowed from `stow/global/wallpapers/.config/dotfiles/wallpapers.conf` to:

```text
~/.config/dotfiles/wallpapers.conf
```

Supported settings:

```bash
WALLPAPER_ROTATION_ENABLED=1
WALLPAPER_ROTATION_INTERVAL="15m"
WALLPAPER_ROTATION_MODE="random" # random or sequential
WALLPAPER_REPO_DIR="$HOME/.local/share/wallpapers/shared"
WALLPAPER_LOCAL_DIR="$HOME/Pictures/local-wallpapers"
```

Intervals support `s`, `m`, `h`, and `d` suffixes.

## Commands

```bash
dotfiles wallpaper status
dotfiles wallpaper rotate
dotfiles wallpaper set /path/to/image.jpg
dotfiles wallpaper open-local
```

Supported image types are `jpg`, `jpeg`, `png`, and `webp`. Empty or corrupt
images are skipped when ImageMagick's `magick` or `identify` command is
available.

## Omarchy Backend

Omarchy keeps the audited behavior: update `~/.config/omarchy/current/background`,
restart `swaybg`, and restore the previous background if `swaybg` fails.

The systemd user timer remains in `stow/os-omarchy/wallpapers/` and runs:

```bash
dotfiles-wallpaper rotate
```

`dotfiles update` enables or disables `dotfiles-wallpaper-rotate.timer` based on
`WALLPAPER_ROTATION_ENABLED`.

## macOS Backend

macOS uses `desktoppr` when installed, with an `osascript` fallback that may not
cover every Space. `desktoppr` is declared in the macOS package lists.

The scheduler is opt-in. The LaunchAgent template is deliberately stowed to an
inert path:

```text
~/.local/share/dotfiles/com.dotfiles.wallpaper.plist
```

Enable it manually with:

```bash
cp ~/.local/share/dotfiles/com.dotfiles.wallpaper.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.dotfiles.wallpaper.plist
```

Disable it with:

```bash
launchctl unload ~/Library/LaunchAgents/com.dotfiles.wallpaper.plist
rm ~/Library/LaunchAgents/com.dotfiles.wallpaper.plist
```

The LaunchAgent wakes every 30 minutes; the engine's interval check remains the
authority.

## Git Guardrails

Repo wallpapers must be curated `jpg`, `jpeg`, `png`, or `webp` files at or
below 8 MB. Personal images belong in `~/Pictures/local-wallpapers/`.
