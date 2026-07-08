# Task 30 — SketchyBar as the primary bar (hide native menu bar)

Status: done
Scope: repo + mac-local (executed on lamac 2026-07-08, Franco present)
Depends on: tasks 13-15, 27 (partial state was enough)
Size: M

## Objective
SketchyBar is the only visible top bar during normal use: the native macOS
menu bar auto-hides, SketchyBar looks like a solid native bar, windows never
tile underneath it, and the whole thing survives reboot/login.

## Decisions
- Mechanism: `defaults write -g _HIHideMenuBar -bool true` plus
  `AppleMenuBarVisibleInFullscreen -bool false` — the same user-domain keys
  System Settings > Menu Bar ("Automatically hide and show the menu bar:
  Always") writes. Stable Big Sur through macOS 26; per-user; no sudo; no
  SIP/private-API hacks. Verified live on macOS 26.5.1.
  Live application uses `osascript` System Events (`set autohide menu bar of
  dock preferences to true`) because `defaults` alone only affects apps
  launched afterwards. Wired into `scripts/macos-defaults.sh` as a new
  confirm-gated "Menu bar" group per repo policy (defaults are never applied
  automatically by bootstrap/apply).
- Opacity: near-opaque (`BAR_BG` alpha 0xc7 -> 0xf0, ~94%) plus
  `blur_radius=20`. Mimics the native translucent-material bar without
  wallpaper bleed-through. Dynamic wallpaper-adaptive color was rejected:
  needs a watcher daemon, violates "simple, reliable".
- AeroSpace pairing: per-monitor top gap
  `outer.top = [{ monitor.'built-in' = 5 }, 38]`. External monitors reserve
  28px bar + margins; the notched built-in keeps 5 because macOS reserves the
  notch strip even with the menu bar hidden.

## What changed (repo)
- `stow/os-macos/sketchybar/.config/sketchybar/colors.sh`: BAR_BG alpha.
- `stow/os-macos/sketchybar/.config/sketchybar/sketchybarrc`: bar
  `blur_radius=20`; removed invalid `env=` property (sketchybar 2.24 rejects
  it — date/clock items were erroring at every start); workspace items now
  use `icon.highlight_color` + plugin-side `icon.highlight=on/off`.
- `plugins/aerospace.sh`: highlight toggle instead of `$DEFAULT_COLOR` env.
- `plugins/clock.sh`: format derived from `$NAME` (date vs clock) instead of
  `$DATE_FORMAT` env.
- `stow/os-macos/aerospace/.config/aerospace/aerospace.toml`: per-monitor
  `outer.top`.
- `scripts/macos-defaults.sh`: new confirm-gated `apply_menu_bar` group.
- `docs/macos-first-time-setup.md`: new "Menu Bar" section; services section
  now documents `brew trust felixkratz/formulae` (Homebrew 6+ refuses
  services from untrusted taps — this is why `brew services` never listed
  sketchybar/borders).

## What changed (lamac, local)
- Wrote both defaults keys and live-applied via System Events.
- Moved legacy `~/.aerospace.toml` (old default template, March) to
  `~/.dotfiles-backup/legacy-2026-07-07-211258/` — it was shadowing the
  stowed config ("Ambiguous config error"), so AeroSpace was silently running
  the DEFAULT config. Named workspaces load correctly now.
- `brew trust felixkratz/formulae`.
- Bootstrapped `homebrew.mxcl.sketchybar` LaunchAgent (it was not loaded
  after the morning reboot); state=running, RunAtLoad + KeepAlive set.

## Validation (run on lamac, 2026-07-08)
```bash
defaults read -g _HIHideMenuBar                    # 1
defaults read -g AppleMenuBarVisibleInFullscreen   # 0
osascript -e 'tell application "System Events" to get autohide menu bar of dock preferences'  # true
pgrep -x sketchybar && pgrep -x borders            # both running
aerospace list-workspaces --all                    # named workspaces, not 1-9/A-Z defaults
sketchybar --query bar                             # blur_radius=20, color=0xf006070d, height=28
cat /opt/homebrew/var/log/sketchybar/sketchybar.err.log  # empty after reload
launchctl print "gui/$(id -u)/homebrew.mxcl.sketchybar" | grep state  # running
```
All passed. Visual double-check (no double bars, no flicker) and a reboot
pass are Franco's to confirm; fold the reboot check into task 28.

## Rollback
```bash
defaults write -g _HIHideMenuBar -bool false
osascript -e 'tell application "System Events" to set autohide menu bar of dock preferences to false'
```
Then revert the repo commit (bar cosmetics + gaps) and `sketchybar --reload`;
restore `~/.aerospace.toml` from the backup dir if ever wanted (it isn't).

## Notes / follow-ups
- Center `media` island sits behind the physical notch on the built-in
  display. If it bothers, move it to sketchybar position `e` (right of
  notch). Left as-is for now.
- Menu bar stays reachable by pushing the cursor to the top edge; it slides
  over SketchyBar temporarily — expected, not a bug.
- Apps already running before the defaults change keep their menu bar until
  relaunched; one logout/login makes the session fully consistent.

## Result
Done on repo and lamac in one sitting (2026-07-08). Root causes fixed along
the way: invalid `env=` sketchybar property (config error on every start),
stray `~/.aerospace.toml` masking the managed AeroSpace config, and the
Homebrew 6 untrusted-tap policy explaining why `brew services` ignored
sketchybar/borders. Not pushed, per protocol.

## Continuation summary (if picking this up cold)
Repo commit contains everything; lamac already has it applied and running.
Remaining human steps live in tasks 27/28: `brew install --cask desktoppr`
(needs terminal sudo), Tailscale/atuin logins, reboot + visual pass
(menu bar stays hidden, sketchybar up via LaunchAgent, aerospace named
workspaces, no double bars), then Omarchy regression pass, then task 29 push.
