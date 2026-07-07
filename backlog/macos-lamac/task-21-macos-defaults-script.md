# Task 21 — Notable macOS defaults: documented + selectively applied

Status: todo
Scope: repo-only (script only runs when a human invokes it)
Depends on: none
Size: S

## Objective
The macOS settings that matter are written down with exact commands, and a
small confirm-gated script can apply the reviewed-safe subset. Nothing runs
automatically.

## Files involved
- `scripts/macos-defaults.sh` (new, executable)
- `docs/macos-personal.md` ("Notable defaults" section; create the file if
  task 22 hasn't yet)

## Reason
Franco's rule: document defaults, selectively apply only when safe, never
over-automate system settings.

## Proposed implementation
Documented + applied by the script (current lamac values, idempotent):
- Dock: `defaults write com.apple.dock autohide -bool true`,
  `orientation left`, `tilesize -int 47`; `killall Dock`
- Finder: `AppleShowAllFiles -bool true`,
  `defaults write -g AppleShowAllExtensions -bool true`; `killall Finder`
- Trackpad: `com.apple.AppleMultitouchTrackpad Clicking -bool true`
Documented ONLY (commented out in the script, off by default):
- `-g KeyRepeat 2`, `-g InitialKeyRepeat 15`, `ApplePressAndHoldEnabled false`
  (lamac currently uses OS defaults — do not change silently)
Script behavior: prints each group with current vs target value, asks y/N per
group (reuse the confirm() pattern from scripts/lib/common.sh), `--dry-run`
prints only. Header states it is NEVER called by bootstrap/update.

## Safety concerns
`defaults write` typos can wedge UI behavior — every key must be copied
exactly from the documented list, and the script must `defaults read` the
current value first so the user sees the change. No `sudo` anywhere.

## Validation commands
```bash
shellcheck scripts/macos-defaults.sh
scripts/macos-defaults.sh --dry-run   # on lamac: shows current vs target, changes nothing
grep -rn 'macos-defaults' scripts/bootstrap.sh scripts/dotfiles   # empty (never wired in)
```

## Rollback notes
Each doc entry lists the revert command (`defaults delete <domain> <key>` or
writing the old value) — include them in the doc table.

## Acceptance criteria
Dry-run accurate; per-group confirmation works; doc table has
setting/command/revert columns; script referenced nowhere in automated flows.
