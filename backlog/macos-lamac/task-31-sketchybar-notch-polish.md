# Task 31 — SketchyBar notch polish (media island)

Status: done
Scope: repo + mac-local validation (lamac, 2026-07-08)
Depends on: task-30
Size: S

## Objective
The media island no longer hides behind the camera notch on the built-in
display now that SketchyBar is the primary bar.

## What changed
- `stow/os-macos/sketchybar/.config/sketchybar/sketchybarrc`: `media` item
  moved from position `center` to `e` (right of the notch on notched
  displays; starts at the center line on external monitors). Also documents
  the menu-bar auto-hide defaults in the `docs/macos-personal.md` Notable
  Defaults table (task-30 leftover).

## Validation (lamac)
```bash
sketchybar --reload   # err log stays empty
sketchybar --query media   # "position": "e"
```
Passed. Visual check with Spotify playing is Franco's when convenient.

## Rollback
Change position `e` back to `center` in sketchybarrc, `sketchybar --reload`.

## Result
Done. One-line item move plus docs table row; no plugin changes needed.
