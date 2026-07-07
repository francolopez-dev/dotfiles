# Task 02 — Add macOS OS detection

Status: todo
Scope: repo-only
Depends on: none
Size: M

## Objective
`detect_os()` and `detect_bootstrap_os()` return `macos` on Darwin. All
env-override whitelists accept `macos`. Linux behavior unchanged.

## Files involved
- `scripts/lib/common.sh` (detect_os, DOTFILES_OS/DOTFILES_BOOTSTRAP_OS/
  DOTFILES_PROFILE whitelists)
- `scripts/bootstrap.sh` (detect_bootstrap_os, same whitelist)
- `tests/` (add a detection check)

## Reason
On macOS there is no `/etc/os-release`; detection currently returns `unknown`
and bootstrap dies. Everything downstream (layers, packages, doctor) keys off
this value.

## Proposed implementation
In both detect functions, before the `/etc/os-release` branch:
```bash
if [[ "$(uname -s)" == "Darwin" ]]; then echo "macos"; return 0; fi
```
Add `macos` to the `case` whitelists for `DOTFILES_OS`,
`DOTFILES_BOOTSTRAP_OS`, and add `profile-*-macos) echo "macos"` to the
`DOTFILES_PROFILE` inference in `detect_os`. Do NOT touch
`resolve_package_lists` yet (task 06 owns package resolution). Keep the
bash-3.2 caveat in mind: do not add `${var,,}`-style expansions outside the
existing Linux-only branches.

Add a tiny test (follow the style of existing `tests/*.sh`): assert
`DOTFILES_OS=macos detect_os == macos`, `DOTFILES_OS=omarchy == omarchy`, and
that sourcing common.sh under `bash --posix`-less bash 3.2 semantics is not
required (test runs with whatever bash the runner has; the Darwin branch uses
only bash-3-safe syntax).

## Safety concerns
The Darwin branch must come BEFORE the os-release check but AFTER the env
overrides, so `DOTFILES_OS=omarchy` still wins on a Mac (used for testing).

## Validation commands
```bash
shellcheck -x scripts/dotfiles scripts/bootstrap.sh scripts/lib/*.sh
DOTFILES_OS=macos bash -c '. scripts/lib/common.sh; detect_os'   # macos
bash -c '. scripts/lib/common.sh; detect_os'   # macos on Darwin, distro id on Linux
bash tests/bootstrap-first-run.sh   # still passes
```

## Rollback notes
Single commit; `git revert` it.

## Acceptance criteria
`detect_os` prints `macos` on Darwin and is unchanged on Linux; whitelists
accept `macos`; shellcheck clean; tests pass.
