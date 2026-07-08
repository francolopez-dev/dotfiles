# Task 09 — Promote neovim and atuin config to the global layer

Status: done
Scope: repo-only
Depends on: none
Size: S

## Objective
The LazyVim config and atuin config apply on every machine, including lamac.

## Files involved
- `stow/os-omarchy/neovim/` -> `stow/global/neovim/` (git mv, whole tree)
- `stow/os-omarchy/atuin/` -> `stow/global/atuin/` (git mv)
- `.gitignore` (update the `lazy-lock.json` path:
  `stow/os-omarchy/neovim/...` -> `stow/global/neovim/...`)

## Reason
Both configs are OS-agnostic (`~/.config/nvim`, `~/.config/atuin`) and wanted
on macOS. Config without the binary is inert on Debian servers, so global is
safe.

## Proposed implementation
Two `git mv` commands plus the `.gitignore` path fix. Then grep for stale
references: `grep -rn 'os-omarchy/neovim\|os-omarchy/atuin' scripts/ docs/ .gitignore`.

## Safety concerns
Existing Omarchy machines have `~/.config/nvim/*` and `~/.config/atuin/*`
symlinks pointing at the OLD layer path; they dangle until the next
`dotfiles apply`, where the conflict wizard prompts — choose backup. Record
this in your Result section so task 28 verifies it on nox/fornax. There is an
UNTRACKED `lazy-lock.json` inside the nvim tree on some machines (gitignored);
`git mv` only moves tracked files — fine, but do not delete local
lazy-lock.json files.

## Validation commands
```bash
git status --short   # only renames + .gitignore
grep -rn 'os-omarchy/neovim\|os-omarchy/atuin' scripts/ docs/ .gitignore  # empty
scripts/dotfiles apply --dry-run
```

## Rollback notes
`git revert`.

## Acceptance criteria
Both packages under `stow/global/`; no stale path references; gitignore still
covers lazy-lock.json at its new path.

## Result
Implemented by an agent session on 2026-07-07 without flipping this status;
verified and closed during the same-day re-audit (see commits
51ce1ab/95892bc/7394a40/1b2ec4e/df81054):
neovim+atuin live under stow/global, old dirs gone, .gitignore path updated,
no stale references. Omarchy machines still owe the backup-wizard pass (task 28).
