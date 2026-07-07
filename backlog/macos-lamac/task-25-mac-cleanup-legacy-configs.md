# Task 25 — lamac cleanup 2/3: legacy real configs + env.local handoff

Status: todo
Scope: mac-local (run on lamac, human present)
Depends on: task-24
Size: M

## Objective
Legacy real config files the new layers will own are backed up and removed;
machine-specific shell lines survive in `~/.config/shell/env.local`.

## Files involved
On lamac, moved into `~/.dotfiles-backup/legacy-<ts>/` (reuse task 24's dir):
`~/.zprofile`, `~/.config/alacritty/`, `~/.config/nvim/` (residue),
`~/.config/sketchybar/`, `~/.config/neofetch/`. Created:
`~/.config/shell/env.local`.

## Reason
Clean slate: the repo replaces all of these (global alacritty + nvim,
os-macos zprofile + sketchybar). The old sketchybar config is kept in the
backup as design reference only.

## Proposed implementation
1. env.local handoff FIRST — create `~/.config/shell/env.local` containing the
   machine-specific lines currently in `~/.zprofile`:
   JetBrains Toolbox PATH, `source ~/.orbstack/shell/init.zsh 2>/dev/null || :`,
   pipx `~/.local/bin` PATH (drop this one — env.sh already adds
   `~/.local/bin`). Do NOT copy the brew shellenv line (os-macos .zprofile
   owns it).
2. `mv` each legacy path into the backup dir, preserving structure.
3. `~/.config/nvim`: task 24 removed the dangling file links; move whatever
   remains (lazy-lock.json, lua/ leftovers, plugin state) to backup so stow
   lays down a clean tree.

## Safety concerns
Between this task and task 27 the Mac has NO `.zprofile` (brew missing from
login-shell PATH) and no editor config. Run tasks 25 -> 26 -> 27 in one
sitting. If interrupted: `eval "$(/opt/homebrew/bin/brew shellenv)"` manually
in any shell. Verify env.local is never staged in git
(`git -C ~/dotfiles status` — it's outside the repo anyway; the `*.local`
gitignore rule covers accidents).

## Validation commands
```bash
ls ~/.dotfiles-backup/legacy-*/          # contains zprofile, alacritty, nvim, sketchybar
[ ! -e ~/.zprofile ] && [ ! -e ~/.config/alacritty ] && echo cleared
grep -c orbstack ~/.config/shell/env.local   # >= 1
zsh -lic 'command -v brew'   # brew still resolvable in this transition shell? if not, note it — expected until task 27
```

## Rollback notes
Everything is a `mv`; restore any path from the backup dir verbatim.

## Acceptance criteria
Legacy paths cleared, backup complete, env.local carries Toolbox + OrbStack
lines, and the follow-on tasks are run the same day.
