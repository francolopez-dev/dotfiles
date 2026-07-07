# Task 06 — brew/cask support in the packages library

Status: todo
Scope: repo-only
Depends on: task-02
Size: M

## Objective
The packages layer understands macOS: `brew.txt` (formulae) and `cask.txt`
(casks) resolve per layer, drift is detectable, declarations validate.

## Files involved
- `scripts/lib/packages.sh`
- `scripts/lib/common.sh` (`resolve_package_lists` macos branch)
- `scripts/dotfiles` (`_pkg_installed` macos branch)

## Reason
Mirrors the existing pacman/aur and apt conventions so `status`, `doctor`,
and `update` work identically on macOS.

## Proposed implementation
In `packages.sh`:
```bash
desired_brew_packages() { resolve_package_files brew | package_file_items | dedupe_packages; }
desired_cask_packages() { resolve_package_files cask | package_file_items | dedupe_packages; }
```
- `desired_packages`: add `macos) { desired_brew_packages; desired_cask_packages; } | dedupe_packages ;;`
- `pkg_manager`: `macos) echo "brew install" ;;` (used for formulae; casks get
  their own command in task 19)
- `validate_macos_package_declarations`: fail if a name appears in both
  brew.txt and cask.txt (`comm -12`, same pattern as
  `validate_package_source_overlap`).
In `common.sh` `resolve_package_lists`: `macos) resolve_package_files brew "$@" ;;`
In `scripts/dotfiles` `_pkg_installed`:
```bash
macos) brew list --formula --versions "$1" >/dev/null 2>&1 \
    || brew list --cask --versions "$1" >/dev/null 2>&1 ;;
```
Note: for tap-qualified names like `felixkratz/formulae/borders`,
`brew list --versions` accepts the short name only — strip the tap prefix
(`${pkg##*/}`) before the installed check, but keep the full name for
install commands.

## Safety concerns
Nothing installs here; resolution/validation only. Do not touch the omarchy
or apt branches.

## Validation commands
```bash
shellcheck -x scripts/dotfiles scripts/lib/*.sh
# On any OS (lists may not exist yet; expect empty output, exit 0):
DOTFILES_OS=macos bash -c '. scripts/lib/common.sh; . scripts/lib/packages.sh; desired_packages'
bash tests/package-bootstrap.sh
```

## Rollback notes
Single commit; revert.

## Acceptance criteria
With sample brew/cask lists in a temp layer, `desired_packages` under
`DOTFILES_OS=macos` prints the concatenated deduped set in layer order;
overlap validation fails when a name is in both files; Linux paths untouched.
