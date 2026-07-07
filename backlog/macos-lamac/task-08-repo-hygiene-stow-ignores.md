# Task 08 — Repo hygiene: xdg-terminal-exec layer move + .stowrc ignores

Status: done
Scope: repo-only
Depends on: none
Size: S

## Objective
Linux-only config leaves the global layer; a manual `stow` from repo root
cannot grab non-stow directories.

## Files involved
- `stow/global/xdg-terminal-exec/` -> `stow/os-omarchy/xdg-terminal-exec/` (git mv)
- `.stowrc` (add ignores)

## Reason
`xdg-terminals.list` implements a Linux XDG spec and would stow clutter onto
macOS. `.stowrc` currently ignores docs/scripts/packages but not `backlog`,
`tests`, `bootstrap.sh`, `CLAUDE.md`, and friends.

## Proposed implementation
```bash
git mv stow/global/xdg-terminal-exec stow/os-omarchy/xdg-terminal-exec
```
Append to `.stowrc` (same style as existing lines):
`^backlog$`, `^tests$`, `^bootstrap\.sh$`, `^CLAUDE\.md$`,
`^skills-lock\.json$`, `^\.githooks$`, `^\.agents$`, `^\.repo$`,
`^\.gitignore$`, `^\.claude$`

## Safety concerns
On Omarchy machines the existing `~/.config/xdg-terminals.list` symlink points
into the global layer path; after the move, the next `dotfiles apply` re-stows
it from os-omarchy — the conflict wizard may prompt (choose backup). Note this
for task 28. `cmd_doctor` greps the target file path (`~/.config/xdg-terminals.list`),
which is unchanged — verify no repo code references the old layer path:
`grep -rn 'global/xdg-terminal-exec' scripts/ docs/`.

## Validation commands
```bash
grep -rn 'xdg-terminal-exec' scripts/ docs/ .stowrc || true   # no stale layer refs
shellcheck -x scripts/dotfiles scripts/lib/*.sh
scripts/dotfiles apply --dry-run   # on whatever machine runs this
```

## Rollback notes
`git revert` (git mv is tracked).

## Acceptance criteria
File lives under os-omarchy; .stowrc covers the listed top-level entries;
dry-run apply works.

## Result
xdg-terminal-exec moved to os-omarchy (git mv); docs/where-to-edit.md path
updated; .stowrc gained ignores for backlog/tests/bootstrap.sh/CLAUDE.md/
skills-lock.json/.githooks/.agents/.repo/.gitignore/.claude. Validated
2026-07-07: no stale refs, shellcheck clean, apply --dry-run runs (reports
only the known lamac legacy conflicts). Omarchy machines will see one
conflict prompt for ~/.config/xdg-terminals.list at next apply (task 28).
