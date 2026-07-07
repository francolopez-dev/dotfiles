# Task 07 — Seed macOS package lists

Status: done
Scope: repo-only
Depends on: task-06
Size: S

## Objective
Declare the curated macOS baseline: `packages/global/brew.txt`,
`packages/os-macos/{brew,cask}.txt`, `packages/profile-lamac-macos/{brew,cask}.txt`.

## Files involved
All four/five files above (new).

## Reason
Package lists concatenate global -> os -> profile like every other OS. The
global brew list must mirror `packages/global/pacman.txt` so the shared CLI
baseline is identical across machines.

## Proposed implementation
`packages/global/brew.txt` — same set as global pacman.txt:
git stow tmux fzf ripgrep jq bat eza fastfetch btop htop neovim zsh curl bash
wget nano

`packages/os-macos/brew.txt` (comment each group):
shellcheck atuin zoxide yazi age restic terminal-notifier timer desktoppr
mas duti felixkratz/formulae/borders felixkratz/formulae/sketchybar

`packages/os-macos/cask.txt`:
ghostty nikitabobko/tap/aerospace rectangle raycast
font-jetbrains-mono-nerd-font font-fira-code-nerd-font
(No alacritty: Ghostty is the standard terminal on managed Macs — do not
install a second managed terminal on new machines. No wezterm. Zen browser:
add as a COMMENT only — Zen.app was installed manually and
`brew install --cask zen` fails over an existing app; adopting it into brew is
a manual later step, note it in the file.)

`packages/profile-lamac-macos/{brew,cask}.txt`: header comment + "(none yet)".
Work/k8s tooling (helm, kubectl, terraform, azure-cli, ...) stays UNDECLARED
deliberately: declared lists are the managed baseline, brew never removes
extras. Say so in the os-macos brew.txt header.

NO wezterm, NO minidlna anywhere.

## Safety concerns
Do not dump `brew list` output wholesale; only the curated set above.
Formulae vs casks must land in the right file (task 06 validation catches
overlap but not misplacement — double-check `ghostty` and `alacritty` are
casks, `borders`/`sketchybar` are formulae).

## Validation commands
```bash
DOTFILES_OS=macos DOTFILES_PROFILE=profile-lamac-macos \
  bash -c '. scripts/lib/common.sh; . scripts/lib/packages.sh; desired_packages'
# on the Mac additionally: brew info --cask ghostty >/dev/null && echo ok
```

## Rollback notes
Delete the files.

## Acceptance criteria
Lists resolve in layer order; every name verifiable via `brew info`
(spot-check at least the tap-qualified ones); no wezterm/minidlna present.

## Result
Created packages/global/brew.txt (mirrors global pacman baseline),
packages/os-macos/{brew,cask}.txt, packages/profile-lamac-macos/{brew,cask}.txt.
Every name verified against `brew info` 2026-07-07; two spec corrections found
during validation: `timer` is tap-only (declared caarlos0/tap/timer) and
`desktoppr` is a cask, not a formula (moved to cask.txt). zen left commented
with the --adopt hint. Overlap validation passes; `dotfiles status` on lamac
now shows honest drift (atuin, ghostty, desktoppr, fonts... missing).
