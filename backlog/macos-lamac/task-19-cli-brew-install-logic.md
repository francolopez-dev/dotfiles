# Task 19 — dotfiles CLI: brew install/apply logic

Status: todo
Scope: repo-only
Depends on: task-06, task-07
Size: M

## Objective
`dotfiles update` on macOS installs missing declared formulae then casks,
confirm-gated, mirroring the pacman-then-AUR two-phase flow. `apply`/update
refreshes do the right (minimal) thing on macOS.

## Files involved
- `scripts/dotfiles` (`install_missing_packages` macos dispatch, new
  `install_missing_macos_packages`, `cmd_update` plan text,
  `refresh_after_apply` macos hook, `_pkg_installed` from task 06)

## Reason
Parity with the daily `dotfiles status/update/apply` loop on Omarchy.

## Proposed implementation
`install_missing_macos_packages "$dry"`:
1. `validate_macos_package_declarations || return 1`
2. formulae: diff `desired_brew_packages` against installed
   (`brew list --formula --versions`, short-name compare per task 06);
   print missing; dry-run prints `would run: brew install <...>`; else
   confirm + `brew install "${missing[@]}"`.
3. casks: same with `desired_cask_packages` and `brew install --cask`.
Rules: NEVER `brew upgrade`, NEVER uninstall, never `--force`. A cask that
fails because the app already exists in /Applications gets a warn with the
manual adoption hint (`brew install --cask --adopt <name>`), not a retry.
`cmd_update` plan text for macos: "2. install brew formulae 3. install brew
casks" wording.
`refresh_after_apply`: on macos run `sketchybar --reload` if
`pgrep -x sketchybar`, and `borders` reload is unnecessary (service picks up
bordersrc on restart — leave a dim note). Existing Linux refreshes are already
guarded by `command -v`; verify none misfire on macOS (fc-cache exists via
brew sometimes — restrict the desktop-cache block to non-Darwin).

## Safety concerns
Casks can be huge downloads; the confirm prompt must list what will install.
Respect `DOTFILES_ASSUME_YES=1` the same way the omarchy path does.

## Validation commands
```bash
shellcheck -x scripts/dotfiles scripts/lib/*.sh
# On lamac (pre-apply is fine): scripts/dotfiles update --dry-run
#   -> lists missing ghostty/aerospace/... with "would run" lines, changes nothing
```

## Rollback notes
Revert commit. Installed packages are not auto-removed by design; uninstall
manually if a test install happened.

## Acceptance criteria
Dry-run output exact and side-effect-free; real run installs only missing
declared packages after confirmation; sketchybar reloads after apply when
running.
