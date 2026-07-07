# Task 13 — SketchyBar core (Waybar-inspired bar, workspaces, front app, clock)

Status: todo
Scope: repo-only
Depends on: task-10
Size: M

## Objective
A managed SketchyBar setup under `stow/os-macos/sketchybar/` that mirrors the
Omarchy Waybar experience: left = workspaces + focused app, right = date +
clock, shared color/font language. (System/network/media items land in tasks
14-15.)

## Files involved
- `stow/os-macos/sketchybar/.config/sketchybar/sketchybarrc` (new, executable)
- `stow/os-macos/sketchybar/.config/sketchybar/colors.sh` (new)
- `stow/os-macos/sketchybar/.config/sketchybar/plugins/` (aerospace.sh,
  front_app.sh, clock.sh)

## Reason
Decision: rebuild inspired by `stow/os-omarchy/waybar/`, not copy the old Mac
config (which references missing plugins). Same visual identity, native
SketchyBar mechanics.

## Proposed implementation
`colors.sh` — translate the Waybar palette
(`stow/os-omarchy/waybar/.config/waybar/style.css`) to `0xAARRGGBB` exports:
BAR_BG=0xc706070d (bar-bg @78%), SURFACE=0xff11131f, TEXT=0xffd7dcff,
TEXT_SOFT=0xffaeb7e8, MUTED=0xff6b7280, PURPLE=0xffbd93f9, BLUE=0xff7dd3fc,
CYAN=0xff67e8f9, GREEN=0xff50fa7b, YELLOW=0xfff1fa8c, ORANGE=0xffffb86c,
RED=0xffff6e6e (plus the battery-soft/warm/low trio).

`sketchybarrc` (zsh or bash, source colors.sh):
- bar: position top, height 28, color $BAR_BG, JetBrainsMono Nerd Font
  defaults (icon ~15, label ~12), per-item padding echoing Waybar's rhythm.
- workspaces: `sketchybar --add event aerospace_workspace_change`; one item
  per workspace from `aerospace list-workspaces --all`; plugin
  `aerospace.sh` highlights the focused one ( active /  default icons, same
  as Waybar). The recovered aerospace.toml already triggers this event.
- front_app: item subscribed to `front_app_switched`, label = app name,
  truncate ~36 chars (Waybar's max-length).
- clock right: `%I:%M %p` + a date item `%b%d`, update_freq 10/60; click:
  `open -a Calendar`.
Run mechanism: brew service (`brew services start sketchybar`) — document in
the rc header; do NOT autostart from aerospace.

## Safety concerns
Repo-only. Plugins are executed code — keep them dependency-free (no jq needs
beyond what brew installs; jq is in global brew list anyway).

## Validation commands
```bash
shellcheck stow/os-macos/sketchybar/.config/sketchybar/sketchybarrc \
  stow/os-macos/sketchybar/.config/sketchybar/plugins/*.sh stow/os-macos/sketchybar/.config/sketchybar/colors.sh
# On a Mac with sketchybar installed:
#   sketchybar --reload && sketchybar --query bar
```

## Rollback notes
Delete the package dir; `brew services stop sketchybar`.

## Acceptance criteria
shellcheck clean; on lamac (post task 27) the bar shows workspaces that follow
AeroSpace focus, the focused app name, and clock/date, in the Waybar palette.
