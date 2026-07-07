# Task 10 — Recover AeroSpace and JankyBorders configs into os-macos

Status: todo
Scope: repo-only
Depends on: none
Size: S

## Objective
Franco's working AeroSpace and borders configs, deleted with the old flat
layout, live again under `stow/os-macos/`.

## Files involved
- `stow/os-macos/aerospace/.config/aerospace/aerospace.toml` (new, recovered)
- `stow/os-macos/borders/.config/borders/bordersrc` (new, recovered, executable)

## Reason
These are the only legacy Mac configs worth keeping (decision in CONTEXT.md).
They were deleted by commit `cedc5d2` and exist at `cedc5d2~1`.

## Proposed implementation
```bash
mkdir -p stow/os-macos/aerospace/.config/aerospace stow/os-macos/borders/.config/borders
git show cedc5d2~1:stow/aerospace/.config/aerospace/aerospace.toml \
  > stow/os-macos/aerospace/.config/aerospace/aerospace.toml
git show cedc5d2~1:stow/borders/.config/borders/bordersrc \
  > stow/os-macos/borders/.config/borders/bordersrc
chmod +x stow/os-macos/borders/.config/borders/bordersrc
```
Review pass (do not redesign, just sanity):
- aerospace.toml keeps `exec-on-workspace-change` triggering sketchybar —
  correct, the new bar (task 13) subscribes to that event.
- aerospace.toml's `after-startup-command` runs `~/.config/borders/bordersrc`;
  borders ALSO runs as a brew service on this Mac. Pick ONE owner: keep the
  brew service, remove the aerospace after-startup borders line, and note it.
- Check both files for absolute `/Users/franco.lopez` paths; replace with `~`
  or `$HOME` where syntax allows.

## Safety concerns
Read-only recovery from git history; no $HOME changes. bordersrc is an
executed script — read every line before committing (it is short).

## Validation commands
```bash
git diff --stat
shellcheck stow/os-macos/borders/.config/borders/bordersrc
grep -n '/Users/franco.lopez' stow/os-macos/ -r    # expect empty
```

## Rollback notes
Delete the two files.

## Acceptance criteria
Both files tracked under os-macos, reviewed, no hardcoded user paths, single
borders owner documented in the file header.
