# Task 11 — macOS stow layer skeleton (os-macos zsh + profile-lamac-macos)

Status: done
Scope: repo-only
Depends on: none
Size: S

(Absorbs former tasks 11 and 12 — they were two trivial layer-scaffold tasks.)

## Objective
The os-macos and profile-lamac-macos layers exist with their two seed
packages: the managed `.zprofile` (every Mac) and lamac's Ghostty overrides.

## Files involved
- `stow/os-macos/zsh/.zprofile` (new)
- `stow/profile-lamac-macos/ghostty/.config/ghostty/profile-overrides` (new)

## Reason
- `.zprofile`: the brew shellenv line is identical on every Mac -> os layer.
  lamac's current real `.zprofile` mixes it with machine junk (task 25 splits
  that into env.local).
- Ghostty overrides: the global config's
  `config-file = ?~/.config/ghostty/profile-overrides` is the established
  per-machine hook (fornax/nox pattern); macOS-specific keys belong here, not
  in the global file. No alacritty override: Ghostty is the standard terminal
  (alacritty is not installed on managed Macs; the global alacritty config
  stows harmlessly for machines that still have it).

## Proposed implementation
`stow/os-macos/zsh/.zprofile` (package name `zsh` is fine — the layer scopes
it; no stow clash with global/zsh because the file sets are disjoint:
global owns `.zshrc`/`.p10k.zsh`, os-macos owns `.zprofile`):
```zsh
# ~/.zprofile — managed by dotfiles (stow/os-macos/zsh).
# Machine-specific PATH/init lines belong in ~/.config/shell/env.local
# (sourced by env.sh) — never edit this file locally.
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
```
`profile-overrides`:
```
# Profile Ghostty overrides for lamac (MacBook Pro 14" M2 Pro).
# This file wins over the shared config on this machine.
font-size = 13
macos-option-as-alt = true
```
(font-size 13 is a starting point; tuning later is a one-line edit.)

## Safety concerns
Stowing over lamac's existing real `.zprofile` triggers the conflict wizard at
first apply (task 27) — expected; backup keeps the original.

## Validation commands
```bash
zsh -n stow/os-macos/zsh/.zprofile
DOTFILES_OS=macos DOTFILES_PROFILE=profile-lamac-macos \
  bash -c '. scripts/lib/common.sh; resolve_layers macos lamac'
# expect: global, os-macos, profile-lamac-macos
```

## Rollback notes
Delete both package dirs.

## Acceptance criteria
Both layers resolve for lamac; `.zprofile` contains nothing machine-specific;
profile-overrides carries exactly font-size + macos-option-as-alt.

## Result
Implemented by an agent session on 2026-07-07 without flipping this status;
verified and closed during the same-day re-audit (see commits
51ce1ab/95892bc/7394a40/1b2ec4e/df81054):
os-macos/zsh/.zprofile (brew shellenv only) and lamac ghostty
profile-overrides (font-size 13 + macos-option-as-alt) match the spec.
