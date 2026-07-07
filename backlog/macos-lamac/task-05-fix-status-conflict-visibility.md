# Task 05 — Fix: status/doctor hide stow conflicts in dry-run

Status: todo
Scope: repo-only (fixes all OSes, not just macOS)
Depends on: none
Size: M

## Objective
`dotfiles status` and `dotfiles doctor` must never report "stow dry-run clean"
when conflicts exist.

## Files involved
- `scripts/lib/stow.sh` (`stow_one_package`, the `--no` early-return path)
- `scripts/dotfiles` (`cmd_status`, `cmd_doctor`, `cmd_update` dry-run — audit
  the callers of the changed return code)

## Reason
Observed on the Mac 2026-07-07: every home symlink was dangling/conflicting,
yet `dotfiles status` printed `ok stow dry-run clean`. Cause: in
`stow_one_package`, when conflicts are detected and args contain `--no`, it
warns and `return 0`, so `apply_all_layers` exits 0 and callers print "clean"
while the warning text is discarded. This is the exact signal the lamac
migration relies on.

## Proposed implementation
In the `--no` conflict branch of `stow_one_package`, `return 1` instead of
`return 0` (keep printing the conflict list to stderr). Then check every
caller:
- `cmd_status` / `cmd_doctor`: already branch on the exit code and print the
  captured output on failure — they start telling the truth for free.
- `cmd_update` dry-run: already treats nonzero as `stow_failed` with a warn —
  verify wording still makes sense.
- `bootstrap.sh` `apply_bootstrap_shell_config` dry-run path: sets `failed=1`;
  verify a dry-run with conflicts still completes the report (it should — it
  already warns).
Distinguishing "conflict" from "hard error" is out of scope; both are nonzero.

## Safety concerns
Behavior change on Linux machines too: a status/doctor that used to say clean
may now warn. That is the point, but confirm no script treats status exit
codes as fatal in automation (grep for `dotfiles status` in repo/hooks).

## Validation commands
```bash
shellcheck -x scripts/dotfiles scripts/lib/*.sh
# Manufacture a conflict in a sandbox HOME:
tmp=$(mktemp -d); touch "$tmp/.zshrc"
HOME="$tmp" DOTFILES_OS=macos scripts/dotfiles status | grep -A3 'Stow state'
# expect: warn + the conflicting path listed; NOT "clean"
rm -rf "$tmp"
```

## Rollback notes
Single commit; revert restores the (buggy) lenient behavior.

## Acceptance criteria
Sandbox test shows the conflict; a machine with no conflicts still shows
`ok stow dry-run clean`; update/bootstrap dry-runs still complete.
