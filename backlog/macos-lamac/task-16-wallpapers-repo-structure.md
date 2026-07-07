# Task 16 — Make the wallpaper collection OS-neutral + add commit guardrails

Status: todo
Scope: repo-only
Depends on: none
Size: M

## Objective
The repo's wallpaper system (added in commit 8fa4466, Omarchy-only today)
gets an OS-neutral shared collection that macOS can also use, plus guardrails
so oversized files and local wallpapers can never be committed.

## Files involved
- `stow/os-omarchy/wallpapers/.config/omarchy/backgrounds/walls` (tracked
  placeholder — MOVES to global)
- `stow/global/wallpapers/.local/share/wallpapers/shared/` (new home + README)
- `stow/os-omarchy/wallpapers/.config/dotfiles/wallpapers.conf`
  (`WALLPAPER_REPO_DIR` default)
- `stow/os-omarchy/wallpapers/.local/bin/dotfiles-wallpaper-rotate`
  (same default, ~line 13)
- `stow/os-omarchy/wallpapers/.local/share/wallpapers/.gitkeep` (drop; the
  global layer owns that path now)
- `docs/wallpapers.md` (locations section)
- `.gitignore`, `.githooks/pre-commit` (guardrails)

## Reason
An Omarchy wallpaper engine already exists: conf at
`~/.config/dotfiles/wallpapers.conf`, `dotfiles wallpaper rotate|status|open-local`,
systemd user timer, repo+local merge. But its repo collection lives at the
Omarchy-specific path `~/.config/omarchy/backgrounds/walls`. Franco wants ONE
base collection shared by macOS and Omarchy. Do NOT build a second system;
relocate the collection.

## Proposed implementation
1. New shared home, stowed by the global layer on every machine:
   `stow/global/wallpapers/.local/share/wallpapers/shared/` -> stows to
   `~/.local/share/wallpapers/shared/`. Add a README.md there: how to add
   (commit an image, jpg/png/webp, <= 8 MB, keep the set curated — git history
   keeps images forever) vs local-only (`WALLPAPER_LOCAL_DIR`, never
   committed).
2. Point the Omarchy engine at it: change `WALLPAPER_REPO_DIR` default to
   `$HOME/.local/share/wallpapers/shared` in BOTH wallpapers.conf and the
   rotate script; update docs/wallpapers.md paths. The engine is
   theme-independent (it sets `~/.config/omarchy/current/background`
   directly), so nothing else changes.
3. Guardrails: `.gitignore` add `._*` and `.thumbnails/`; pre-commit (append,
   coordinate with task 23): staged files under `stow/global/wallpapers/`
   must match `jpg|jpeg|png|webp` and be <= 8 MB.

## Safety concerns
Omarchy machines that already stowed the old walls path will have a dangling
`~/.config/omarchy/backgrounds/walls` link after this lands — next
`dotfiles apply` prompts (choose backup); add to task 28's Linux checklist.
Do not rename conf variables — machines may have local conf edits.

## Validation commands
```bash
shellcheck stow/os-omarchy/wallpapers/.local/bin/dotfiles-wallpaper-rotate
grep -rn 'backgrounds/walls' stow/ scripts/ docs/   # only historical mentions in docs, no live defaults
bash .githooks/pre-commit
# negative test: stage a 9MB fake jpg under stow/global/wallpapers -> hook rejects
```

## Rollback notes
`git revert`; conf default change is backward-compatible (machines with the
old conf keep working — the variable is user-overridable).

## Acceptance criteria
Shared dir exists in the global layer with README; Omarchy engine defaults
point at it; guardrail negative test rejects; `dotfiles wallpaper status` on
an Omarchy machine still reports sane counts after its next apply.
