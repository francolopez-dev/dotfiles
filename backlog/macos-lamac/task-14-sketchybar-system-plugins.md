# Task 14 — SketchyBar system plugins (cpu, memory, battery, volume)

Status: todo
Scope: repo-only
Depends on: task-13
Size: M

## Objective
Right-side system items matching the Waybar modules' behavior contract:
cpu %, memory %, battery with state colors, volume on native events.

## Files involved
- `stow/os-macos/sketchybar/.config/sketchybar/plugins/{cpu.sh,memory.sh,battery.sh,volume.sh}` (new)
- `sketchybarrc` (register the items)

## Reason
Waybar shows 󰍛 cpu% (warm 60 / hot 85), 󰘚 mem% (warm 70 / hot 88), battery
with thresholds 60/30/15 and charging icons, and volume with mute state. Keep
the same thresholds and icon language so both machines feel identical.

## Proposed implementation
- cpu.sh: `top -l 1 -n 0 | awk '/CPU usage/...'` or
  `ps -A -o %cpu | awk '{s+=$1} END {...}'` normalized by core count;
  update_freq 3; color by threshold from colors.sh; click opens btop:
  `open -na Ghostty --args -e btop` (verify flag syntax against
  `ghostty +help` during task 28; fall back to `open -a Ghostty`).
- memory.sh: percent from `vm_stat` pages (active+wired)/total or
  `memory_pressure -Q`; update_freq 5.
- battery.sh: `pmset -g batt` -> capacity + charging state; icon ramp and
  states medium 60 / warning 30 / critical 15 like Waybar.
- volume.sh: subscribe to the native `volume_change` event ($INFO carries the
  volume);  muted /   ramp; click toggles mute via
  `osascript -e 'set volume output muted not (output muted of (get volume settings))'`.
No GPU item — Apple Silicon has no discrete-GPU analog to Waybar's gpu.sh;
deliberately dropped.

## Safety concerns
Plugins run every few seconds forever: no network calls, no writes outside
/tmp, each must finish <100ms (avoid `system_profiler` — it is slow).

## Validation commands
```bash
shellcheck stow/os-macos/sketchybar/.config/sketchybar/plugins/*.sh
# Each plugin runs standalone on a Mac and prints/sets something sane:
#   bash plugins/battery.sh (with NAME=battery exported)
time bash stow/os-macos/sketchybar/.config/sketchybar/plugins/cpu.sh  # < 0.3s
```

## Rollback notes
Remove the plugin files and their registrations.

## Acceptance criteria
All four items live on lamac after task 27 with correct threshold colors;
each plugin is shellcheck-clean and fast.
