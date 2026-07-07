# Task 04 — Safe macOS inventory script

Status: done
Scope: repo-only (script is read-only when run)
Depends on: none
Size: M

## Objective
`scripts/macos-inventory.sh`: a rerunnable, read-only inventory of a Mac that
prints everything useful for auditing and NOTHING secret.

## Files involved
- `scripts/macos-inventory.sh` (new)

## Reason
The 2026-07-07 audit was ad hoc; future rebuilds and drift checks need the
same data reproducibly.

## Proposed implementation
Bash (works under 3.2 OR add the task-03 guard; prefer 3.2-safe since this may
run before brew). Sections, all read-only:
- system: `sw_vers`, `uname -m`, `sysctl -n machdep.cpu.brand_string`,
  `scutil --get LocalHostName`
- shell: `$SHELL`, `/bin/bash --version | head -1`, `zsh --version`
- brew: `brew --version`, `brew tap`, `brew leaves --installed-on-request`,
  `brew list --cask`, `brew services list`
- symlink audit: dangling links in `$HOME` (maxdepth 1) and `~/.config`
  (maxdepth 3) with their targets
- ssh: `ls ~/.ssh` NAMES ONLY; `grep -E '^\s*(Host|Include)\b' ~/.ssh/config`
- LaunchAgents: `ls ~/Library/LaunchAgents`
- apps: `ls /Applications`
- key defaults: dock autohide/tilesize/orientation, finder
  AppleShowAllFiles/AppleShowAllExtensions, trackpad Clicking, `-g KeyRepeat`,
  `-g InitialKeyRepeat` (each `2>/dev/null || echo unset`)

Hard rules, stated in a header comment: never cat anything under `~/.ssh`
except the Host/Include grep above; never print env vars; never read
`.npmrc`, `.netrc`, keychains, browser profiles.

## Safety concerns
The script must not take write actions of any kind (no mkdir, no tee).
Self-test: pipe output through
`grep -E 'PRIVATE KEY|ghp_|xox[bap]-|AKIA'` and expect no matches.

## Validation commands
```bash
shellcheck scripts/macos-inventory.sh
scripts/macos-inventory.sh | grep -cE 'PRIVATE KEY|ghp_|xox[bap]-|AKIA'  # 0
scripts/macos-inventory.sh | head -40   # sane output on a Mac
```

## Rollback notes
Delete the file.

## Acceptance criteria
Runs clean on macOS, exits 0, output contains all sections and zero secret
patterns; on Linux it exits early with a polite "macOS only" message.

## Result
Added scripts/macos-inventory.sh (bash-3.2-safe, macOS-gated, read-only).
Validated on lamac 2026-07-07: shellcheck clean, runs under /bin/bash 3.2,
secret-pattern self-test = 0 matches, correctly reports the legacy dangling
symlinks that task 24 will clean.
