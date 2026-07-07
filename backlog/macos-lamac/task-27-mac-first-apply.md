# Task 27 — lamac first full apply

Status: todo
Scope: mac-local (run on lamac, human present, same sitting as 25/26)
Depends on: tasks 02-23 all done, plus 24, 25, 26
Size: M

## Objective
lamac is fully managed: three layers stowed, declared packages installed,
services running, `dotfiles` on PATH.

## Files involved
Repo -> `$HOME` via stow; brew installs. No repo edits except the task file.

## Reason
The moment the clean slate meets the new structure.

## Proposed implementation
In order, reviewing output at each step:
```bash
cd ~/dotfiles && git pull --ff-only
./bootstrap.sh --dry-run          # read the whole plan
scripts/dotfiles update --dry-run # packages + stow preview; expect ghostty/aerospace/... in missing
./bootstrap.sh                    # real run (installs brew bash if task 03/18 wired it)
```
Conflict wizard guidance: choose "backup" for everything (originals land in
`~/.dotfiles-backup/<ts>/`); nothing should be adopted. Then:
```bash
brew services start felixkratz/formulae/borders
brew services start felixkratz/formulae/sketchybar
open -a Ghostty                   # grant permissions prompts as they appear
exec zsh
```
Expected permission prompts (approve): AeroSpace/Rectangle Accessibility,
SketchyBar automation for Spotify (first media event).

## Safety concerns
Do not run with `DOTFILES_STOW_CONFLICTS=adopt`. If bootstrap fails midway it
is rerunnable (repo guarantees); read the error before rerunning. Keep the
terminal that launched bootstrap open until a NEW terminal is verified
working.

## Validation commands
```bash
dotfiles status          # profile-lamac-macos, all layers, no drift, stow clean
dotfiles doctor          # exit 0
git config --global --list | head -3          # gitconfig restored
readlink ~/.zshrc        # -> dotfiles/stow/global/zsh/.zshrc
ls -la ~/.config/aerospace ~/.config/sketchybar ~/.config/ghostty
ssh -G github.com >/dev/null && echo ssh-config-ok
```

## Rollback notes
`stow -D` per layer/package reverses symlinks; restore pre-apply files from
the wizard's `~/.dotfiles-backup/<ts>/`; brew packages stay (harmless) or
uninstall manually.

## Acceptance criteria
All validation commands pass in a NEW terminal; Ghostty opens with the repo
theme; AeroSpace workspaces switch and SketchyBar reflects them; borders
visible.
