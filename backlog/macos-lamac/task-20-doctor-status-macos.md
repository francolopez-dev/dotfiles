# Task 20 — doctor and status speak macOS

Status: done
Scope: repo-only
Depends on: task-02, task-06
Size: M

## Objective
`dotfiles doctor` and `dotfiles status` give accurate, noise-free reports on
macOS.

## Files involved
- `scripts/dotfiles` (`cmd_doctor`, `cmd_status`, `_waybar_status`,
  `_tailscaled_daemon_status`, `print_next_steps`)

## Reason
Today status on a Mac prints waybar/tailscaled/systemd noise and doctor checks
omarchy package files. Both must gate by OS like the omarchy sections already
do.

## Proposed implementation
- doctor, macos case: profile package lists exist
  (`packages/profile-lamac-macos/{brew,cask}.txt`); brew present; bash >= 4
  resolvable; `ghostty` cask installed (check
  `brew list --cask --versions ghostty` — do not rely on a `ghostty` CLI in
  PATH); aerospace/rectangle/raycast apps present (`[ -d /Applications/... ]`);
  borders + sketchybar via `brew services list | grep started`; declared
  package drift via the task-06 helpers; stow dry-run (honest after task 05).
- status: gate `_waybar_status` and `_tailscaled_daemon_status` to omarchy;
  add a macos "Service state" section: `brew services list` filtered to
  borders/sketchybar; tailscale login state via the Tailscale.app CLI if
  found, else "install/open Tailscale.app".
- `print_next_steps` macos wording (Tailscale.app, atuin login, exec zsh).
- Keep the omarchy-only checks (hypr border color etc.) untouched.

## Safety concerns
Read-only reporting; no installs or service mutations from doctor/status.

## Validation commands
```bash
shellcheck -x scripts/dotfiles
# On lamac: scripts/dotfiles status && scripts/dotfiles doctor
#   -> no waybar/systemd/hyprland lines, mac services shown
DOTFILES_OS=omarchy scripts/dotfiles status | grep -c waybar   # still present for omarchy
```

## Rollback notes
Revert commit.

## Acceptance criteria
On lamac both commands are accurate and mention nothing Linux-only; on
Omarchy output is unchanged (diff status output before/after with
DOTFILES_OS=omarchy where feasible).

## Result
Added macOS doctor checks for profile brew/cask lists, Homebrew, bash >= 4,
Ghostty cask, key apps, brew services, and wallpaper status. Status now gates
waybar/tailscaled to Omarchy, shows macOS brew service state, and uses
Tailscale.app login wording. Validated with shellcheck and macOS status output;
Omarchy status still reports waybar.
