# Task 17 — macOS wallpaper backend + opt-in scheduler

Status: done
Scope: repo-only
Depends on: task-16
Size: S

## Objective
Fill in `set_wallpaper_macos` in the unified engine and provide the opt-in
LaunchAgent so lamac rotates wallpapers with the exact same command, conf,
and pools as Omarchy.

## Files involved
- `stow/global/wallpapers/.local/bin/dotfiles-wallpaper` (replace the task-16
  macOS stub)
- `stow/os-macos/wallpapers/.local/share/dotfiles/com.dotfiles.wallpaper.plist`
  (new LaunchAgent TEMPLATE, deliberately stowed to an inert path)
- `scripts/dotfiles` (`configure_wallpaper_rotation` macos branch: create
  `WALLPAPER_LOCAL_DIR` like the omarchy path does, and when
  `WALLPAPER_ROTATION_ENABLED=1` print the LaunchAgent install commands — do
  not install anything)
- `docs/wallpapers.md` (macOS section)

## Reason
Backend-only per Franco's architecture: platform-independent engine (task 16),
per-OS setter. macOS scheduling must be opt-in — launchd auto-loads everything
in `~/Library/LaunchAgents` at login, so stow must never place the plist
there.

## Proposed implementation
- `set_wallpaper_macos`: `desktoppr "$file"` when `command -v desktoppr`
  (declared in os-macos brew.txt by task 07); else fallback
  `osascript -e 'tell application "System Events" to set picture of every desktop to POSIX file "..."'`
  with a comment that the fallback may not cover all Spaces. Return nonzero on
  failure so the engine's restore logic behaves like the omarchy backend.
- LaunchAgent template: StartInterval 1800 running
  `$HOME/.local/bin/dotfiles-wallpaper rotate`; the engine's own interval
  check (conf) is authoritative, mirroring the systemd timer-wakes-often
  pattern. Documented install/uninstall:
  `cp ~/.local/share/dotfiles/com.dotfiles.wallpaper.plist ~/Library/LaunchAgents/ && launchctl load ...`
- docs: macOS section = same commands as Omarchy, backend differences,
  opt-in scheduler, local pool `~/Pictures/local-wallpapers`.

## Safety concerns
Engine writes only its state files; backend never deletes images. Behavior on
Omarchy must be untouched — diff `dotfiles wallpaper status` output there
before/after.

## Validation commands
```bash
shellcheck stow/global/wallpapers/.local/bin/dotfiles-wallpaper scripts/dotfiles
plutil -lint stow/os-macos/wallpapers/.local/share/dotfiles/com.dotfiles.wallpaper.plist
# On lamac post-apply:
#   dotfiles wallpaper rotate && dotfiles wallpaper status   (repo pool only)
#   mkdir -p ~/Pictures/local-wallpapers; cp <img> there; rotate again (merged pool)
```

## Rollback notes
Revert; `launchctl unload && rm` the copied plist if it was enabled.

## Acceptance criteria
On lamac: rotate sets the desktop from the merged pool (repo-only when the
local folder is absent); status shows both pool counts; scheduler inert until
manually installed; Omarchy output byte-identical.

## Result
Implemented macOS backend with desktoppr and osascript fallback, added inert
LaunchAgent template under ~/.local/share/dotfiles, and made dotfiles update
print opt-in launchctl commands instead of installing it. plutil lint and
shellcheck pass; status shows repo/local counts and scheduler state on macOS.
