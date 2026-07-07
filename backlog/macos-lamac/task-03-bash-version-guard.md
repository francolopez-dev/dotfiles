# Task 03 — Bash >= 4 guard with Homebrew re-exec

Status: done
Scope: repo-only
Depends on: none
Size: S

## Objective
`scripts/dotfiles` and `scripts/bootstrap.sh` never run their main logic under
bash 3.2. On macOS they transparently re-exec with Homebrew bash when
available, otherwise fail with the exact fix.

## Files involved
- `scripts/dotfiles` (top, right after the shebang/set line)
- `scripts/bootstrap.sh` (same)

## Reason
macOS ships bash 3.2; the libs use `mapfile` and `${var,,}`. Today the scripts
would die midway (worst case: inside the stow conflict-backup path). Fail
early and clearly instead.

## Proposed implementation
Near the top of both scripts (bash-3.2-safe syntax only):
```bash
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
  for b in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    if [ -x "$b" ] && [ -z "${DOTFILES_BASH_REEXEC:-}" ]; then
      DOTFILES_BASH_REEXEC=1 exec "$b" "$0" "$@"
    fi
  done
  printf 'err this tool needs bash >= 4; on macOS run: brew install bash\n' >&2
  exit 1
fi
```
`DOTFILES_BASH_REEXEC` prevents an exec loop if the found bash is somehow
still old.

## Safety concerns
Must be syntactically valid bash 3.2 (it is: no arrays beyond BASH_VERSINFO
read, no mapfile). Keep it before any `source` of lib files.

## Validation commands
```bash
shellcheck -x scripts/dotfiles scripts/bootstrap.sh
/bin/bash scripts/dotfiles status   # on macOS pre-brew-bash: clear error or clean re-exec
bash tests/bootstrap-first-run.sh
```

## Rollback notes
Single commit; revert.

## Acceptance criteria
Under bash 3.2 with no brew bash: one-line actionable error, exit 1. With brew
bash installed: command works transparently. Linux unaffected.

## Result
Implemented in commit 2802d20 (status flipped retroactively). Validated
2026-07-07 on lamac: under /bin/bash 3.2 with no brew bash the guard printed
the actionable error; after `brew install bash` (part of the declared global
baseline) the CLI transparently re-execs — `dotfiles status` now reports
lamac/macos/profile-lamac-macos.
