# Task 01 — Rename the Mac to "lamac"

Status: todo
Scope: mac-local (run on the Mac, needs sudo)
Depends on: none
Size: S

## Objective
Rename the Mac from auto-generated "Mac-2"/"Mac" to `lamac` so the standard
`profile-<hostname>-<os>` convention resolves to `profile-lamac-macos` with no
override mechanism.

## Files involved
None in the repo. System hostname only.

## Reason
"Mac-2" is an mDNS collision artifact macOS can silently bump to "Mac-3",
which would flip the active profile. A stable name keeps the repo's
hostname-derived profile mechanism untouched.

## Proposed implementation
```bash
sudo scutil --set LocalHostName lamac
sudo scutil --set ComputerName lamac
sudo scutil --set HostName lamac
```
Open a new terminal afterwards (cached hostname).

## Safety concerns
Harmless; changes the name shown on the network/AirDrop/Sharing. Synergy or
other peer tools that reference the old name may need re-pairing.

## Validation commands
```bash
hostname -s          # -> lamac
scutil --get LocalHostName   # -> lamac
```
After task 02 lands, also: `scripts/dotfiles status` shows
`profile : profile-lamac-macos`.

## Rollback notes
Re-run the same three commands with the old names (`Mac-2` / `Mac`).

## Acceptance criteria
`hostname -s` prints `lamac` in a fresh terminal.
