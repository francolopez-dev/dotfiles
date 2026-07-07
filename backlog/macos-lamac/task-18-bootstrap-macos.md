# Task 18 — bootstrap.sh macOS branch

Status: todo
Scope: repo-only
Depends on: task-02, task-03
Size: M

## Objective
`bootstrap.sh` runs on a fresh Mac: verifies Homebrew, installs prereqs,
then hands off to the normal flow (omz, p10k, shell stow, `dotfiles update`).
Honest `--dry-run`.

## Files involved
- `scripts/bootstrap.sh` (`install_bootstrap_prereqs` macos case,
  `print_diagnostics` Darwin guards, `bootstrap_summary` mac wording)

## Reason
Bootstrap currently dies with "Unsupported OS" on Darwin. Homebrew is the
package source; installing Homebrew itself (Xcode CLT + sudo + license) is a
human decision — bootstrap must stop and instruct, not curl-pipe it.

## Proposed implementation
`install_bootstrap_prereqs` gains:
```
macos)
  command -v brew >/dev/null 2>&1 || die \
    "Homebrew is required on macOS." \
    "Install it from https://brew.sh, then rerun bootstrap."
  # prereqs: git stow zsh bash (brew list --versions check, brew install missing)
```
- Ensure brew's bin dir is on PATH inside the script even when invoked from a
  bare login shell (`eval "$(/opt/homebrew/bin/brew shellenv)"` if brew exists
  there but not in PATH).
- `print_diagnostics`: skip the pacman/os-release sections on Darwin (guard
  with the detected OS, not `command -v pacman` alone).
- `bootstrap_summary`: on macos, "Needs manual action" says Tailscale.app
  login (no `sudo tailscale up`), atuin login, recovery pack; drop
  Linux-specific lines.
- The oh-my-zsh/p10k/plugin installers and
  `apply_bootstrap_shell_config` are already portable — verify, don't rewrite.

## Safety concerns
Dry-run must not install anything (follow the existing omarchy dry-run
pattern). Never auto-install Homebrew.

## Validation commands
```bash
shellcheck -x scripts/bootstrap.sh
# On lamac: ./bootstrap.sh --dry-run   (readable plan, no changes, exit 0)
DOTFILES_BOOTSTRAP_OS=debian bash -n scripts/bootstrap.sh   # syntax across branches
```

## Rollback notes
Single commit; revert.

## Acceptance criteria
Dry-run on lamac completes with an accurate plan; on a Mac without brew the
script stops with the brew.sh instruction; Linux branches byte-identical in
behavior.
