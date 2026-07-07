# Task 11 — os-macos zsh package (.zprofile with brew shellenv)

Status: todo
Scope: repo-only
Depends on: none
Size: S

## Objective
Every Mac gets a managed `~/.zprofile` that wires Homebrew into login shells;
machine-specific PATH lines live in gitignored `env.local`.

## Files involved
- `stow/os-macos/zsh-macos/.zprofile` (new)

## Reason
Today lamac's `.zprofile` is an unmanaged real file mixing the universal brew
line with machine-specific ones (JetBrains Toolbox, OrbStack, pipx). The brew
line is identical on every Apple Silicon Mac -> os-macos layer.

## Proposed implementation
```zsh
# ~/.zprofile — managed by dotfiles (stow/os-macos/zsh-macos).
# Machine-specific PATH/init lines belong in ~/.config/shell/env.local,
# which env.sh sources — never edit this file locally.
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
```
Note: env.local is sourced by `~/.config/shell/env.sh` from `.zshrc`
(interactive shells). The OrbStack/pipx/Toolbox lines are PATH-only and work
fine from there; the migration of those lines happens on the Mac in task 25,
not here.

## Safety concerns
Stowing this over the existing real `~/.zprofile` will trigger the conflict
wizard at first apply (task 27) — expected; the backup keeps the original.

## Validation commands
```bash
zsh -n stow/os-macos/zsh-macos/.zprofile
scripts/dotfiles apply --dry-run   # no effect on non-mac machines
```

## Rollback notes
Delete the package dir; restore the backed-up original on the Mac if already
applied.

## Acceptance criteria
File tracked; `zsh -n` clean; contains no machine-specific paths.
