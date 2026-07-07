# Task 17 — Port the wallpaper engine to macOS

Status: todo
Scope: repo-only
Depends on: task-16
Size: M

## Objective
`dotfiles wallpaper rotate|status|open-local` works on lamac using the SAME
conf conventions as Omarchy: repo pool `~/.local/share/wallpapers/shared/`
plus local pool, merged when both exist. Scheduled rotation is opt-in.

## Files involved
- `stow/os-macos/wallpapers/.config/dotfiles/wallpapers.conf` (new)
- `stow/os-macos/wallpapers/.local/bin/dotfiles-wallpaper-rotate` (new, macOS
  implementation of the same interface)
- `stow/os-macos/wallpapers/.local/share/dotfiles/com.dotfiles.wallpaper.plist`
  (new LaunchAgent TEMPLATE, stowed to an inert path)
- `scripts/dotfiles` (`configure_wallpaper_rotation` + wallpaper status/usage
  text: gate the systemd-timer logic to omarchy, add a macos branch)
- `docs/wallpapers.md` (macOS section)

## Reason
Reuse, don't fork, the design that landed in commit 8fa4466. One mental
model, two setters.

## Proposed implementation
- conf: same variables; `WALLPAPER_REPO_DIR="$HOME/.local/share/wallpapers/shared"`,
  `WALLPAPER_LOCAL_DIR="$HOME/Pictures/Wallpapers/local"`,
  `WALLPAPER_ROTATION_ENABLED=0` (opt-in on macOS).
  NOTE: Franco's request said `~/Pictures/local-wallpapers`; the existing
  Omarchy convention is `~/Pictures/Wallpapers/local`. Default to the existing
  convention for cross-machine consistency — it is one conf variable to change
  if Franco prefers the other path. Flag this in your Result section.
- macOS rotate script: copy the Omarchy script's structure (conf loading,
  interval_seconds, state files in `~/.local/state/dotfiles/`, image scan of
  both pools, corrupt-file skip) but replace the setter: `desktoppr <file>`
  when available (declared in os-macos brew.txt), else the osascript
  System Events fallback (header-note its Spaces limitation). No swaybg, no
  omarchy symlink.
- CLI: `configure_wallpaper_rotation` — wrap the systemd enable/disable in an
  omarchy gate; macos branch: create `WALLPAPER_LOCAL_DIR`, and if
  `WALLPAPER_ROTATION_ENABLED=1` print the LaunchAgent install/uninstall
  commands (do NOT auto-install; launchd auto-loads `~/Library/LaunchAgents`
  at login, so stow must never place the plist there — that is why the
  template lives under `~/.local/share/dotfiles/`).
  `open-local` uses `open` on macOS (`xdg-open` path stays for Linux).
- LaunchAgent template: StartInterval 1800 running
  `~/.local/bin/dotfiles-wallpaper-rotate`; the script itself enforces the
  conf interval, mirroring the systemd-timer-wakes-every-minute pattern.

## Safety concerns
Script writes only its state files; never deletes/moves images. Keep it
runnable under the task-03 bash guard. `scripts/dotfiles` edits must not
change Omarchy behavior (diff `dotfiles wallpaper status` output there).

## Validation commands
```bash
shellcheck stow/os-macos/wallpapers/.local/bin/dotfiles-wallpaper-rotate scripts/dotfiles
plutil -lint stow/os-macos/wallpapers/.local/share/dotfiles/com.dotfiles.wallpaper.plist
# On lamac post-apply: dotfiles wallpaper status; dotfiles wallpaper rotate
#   (with and without the local folder populated)
DOTFILES_OS=omarchy bash -n scripts/dotfiles
```

## Rollback notes
Delete the os-macos package; revert the CLI commit;
`launchctl unload && rm` the copied plist if it was enabled.

## Acceptance criteria
On lamac: rotate sets a wallpaper from the merged pool, status reports both
pool counts, open-local opens Finder; LaunchAgent inert until manually
installed; Omarchy wallpaper behavior byte-identical.
