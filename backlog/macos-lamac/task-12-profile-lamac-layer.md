# Task 12 — Create the profile-lamac-macos stow layer

Status: todo
Scope: repo-only
Depends on: none
Size: S

## Objective
Machine-specific layer for lamac exists with the Ghostty override hook, in the
same shape as profile-nox/fornax.

## Files involved
- `stow/profile-lamac-macos/ghostty/.config/ghostty/profile-overrides` (new)
- `stow/profile-lamac-macos/alacritty/.config/alacritty/profile-font-size.toml` (new)

## Reason
The global Ghostty config ends with
`config-file = ?~/.config/ghostty/profile-overrides` — the established
per-machine hook (see fornax). macOS-specific Ghostty behavior belongs here,
not in the global file (its comments say exactly this).

## Proposed implementation
`profile-overrides`:
```
# Profile Ghostty overrides for lamac (MacBook Pro 14" M2 Pro).
# This file wins over the shared config on this machine.
font-size = 13
macos-option-as-alt = true
```
(13 is a starting point for the 14" panel; tuning it later is a one-line edit.)

`profile-font-size.toml`: copy the pattern from
`stow/profile-nox-omarchy/alacritty/.config/alacritty/profile-font-size.toml`
with a lamac comment. Alacritty stays the managed fallback terminal; kitty
remains unmanaged.

## Safety concerns
None; new files in a layer no machine resolves until lamac is renamed
(task 01) and detection lands (task 02).

## Validation commands
```bash
DOTFILES_OS=macos DOTFILES_PROFILE=profile-lamac-macos \
  bash -c '. scripts/lib/common.sh; resolve_layers macos lamac'
# expect: global, os-macos (once it has packages), profile-lamac-macos
```

## Rollback notes
Delete the directory.

## Acceptance criteria
Layer resolves for host lamac + os macos; Ghostty override file carries
font-size and macos-option-as-alt only.
