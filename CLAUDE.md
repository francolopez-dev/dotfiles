# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Repo Is

A Git-based personal platform for rebuilding and maintaining my machines.Core rule: Git is the source of truth for system intent. Secrets and private keys do not live in Git.Design Principles
Machines are disposable.
Git is the source of truth for scripts, profiles, configuration intent, and documentation.
Vaultwarden is the source of truth for interactive credentials.
The Age-encrypted Recovery Pack is the source of truth for key material and infrastructure exports that must exist before services can be restored.
At least one Age identity capable of decrypting the Recovery Pack must exist outside the Recovery Pack at all times.
NAS is the primary storage target for recovery artifacts.
Restic is the secondary backup path.
Hetzner Storage Box is optional and must not be required for the design to work.
Email is not primary backup storage. It exists for reports and audit trail. Encrypted emergency attachments are disabled by default and require explicit opt-in.
## Commands

**Validation and smoke tests — run these after any change:**

```bash
# Profile validation (required after any profile/package/service/sync change)
scripts/validate-profiles.sh

# Shell lint
shellcheck -x bootstrap.sh scripts/*.sh stow/scripts/bin/dotfiles tests/*/run-tests.sh

# Orchestration smoke test (safe, no side effects)
./bootstrap.sh --dry-run --profile minimal

# Focused test suites
tests/cli/run-tests.sh
tests/bootstrap-update/run-tests.sh
tests/stow-cleanup/run-tests.sh
tests/recovery-pack/run-tests.sh   # requires age, age-keygen, tar; restic cases skip if not installed
```

**Daily operation (for reference/testing):**

```bash
dotfiles update              # pull + re-apply
dotfiles status              # machine/profile/repo/services/sync summary
dotfiles doctor              # read-only diagnostics
dotfiles bootstrap --dry-run --profile <name>
dotfiles profile show | select | validate
```

## Architecture

### Bootstrap pipeline

Root `./bootstrap.sh` executes these scripts in fixed order:

```
detect-os → select-profile → validate-profiles → install-packages →
validate-installed-packages → cleanup-stale-stow-links → apply-stow →
configure-omarchy-terminal → enable-services → setup-syncing →
validate-terminal-integration
```

`scripts/bootstrap.sh` is the remote `curl | bash` entrypoint that clones/updates the repo and hands off to the root `./bootstrap.sh`. Keep these two separate; do not merge their concerns.

### Three-tier stow model

Effective stow packages resolve as:

```
profiles/stow-base (global) + profiles/stow-os-base (per-OS) + profile STOW_PACKAGES
```

- `stow-base`: shared terminal/shell dotfiles for every profile on every OS (shell, zsh, bash, git, ssh, tmux, scripts, atuin)
- `stow-os-base`: OS-wide desktop config (hypr, waybar, rofi, etc. on Omarchy)
- `STOW_PACKAGES` in a profile `.conf`: genuinely profile-specific dotfiles only
- `profiles/stow-os.map`: OS allowlist — packages listed here are filtered to their declared OS

### Profiles

Profiles live in `profiles/*.conf` and are sourced shell files declaring:

```sh
PACKAGE_GROUPS=(common desktop work)
STOW_PACKAGES=(nvim btop wezterm)
SERVICES=(tailscale)
SYNC=(tailscale atuin)
```

Active profile is stored per-machine at `~/.config/dotfiles/profile` — this file is gitignored. Optional display/hardware keys (`DISPLAY_CLASS`, `DISPLAY_MODES`, `HARDWARE_PACKAGE_GROUPS`) are written to `~/.config/dotfiles/profile.env` by bootstrap.

### `dotfiles` CLI

`stow/scripts/bin/dotfiles` is stowed to `~/bin/dotfiles`. It discovers the repo via `$DOTFILES_DIR`, symlink resolution, or `~/dotfiles` fallback. Keep it a thin dispatcher: each `cmd_<name>` function parses args and calls the owning script. To add a subcommand, add `cmd_<name>()`, a dispatch case, and help text in that one file.

### Package groups

Packages are grouped by purpose under `packages/<group>/` with one file per manager: `pacman.txt`, `aur.txt`, `brew.txt`, `brew-cask.txt`, `apt.txt`. Profiles reference groups by name in `PACKAGE_GROUPS=()`.

## How to Add Things

| Task | Where |
|------|-------|
| New app | `packages/<group>/<manager>.txt` |
| Global alias/shell tweak | `stow/shell`, `stow/zsh`, or `stow/bash` (auto-applies everywhere) |
| Omarchy keyboard shortcut | `stow/hypr` (applies to all Omarchy profiles via `stow-os-base`) |
| Profile-specific dotfile | Add stow package to that profile's `STOW_PACKAGES=()` |
| New profile | Create `profiles/<name>.conf`, update `profile_os()` in `scripts/validate-profiles.sh`, update wizard in `scripts/select-profile.sh`, run `scripts/validate-profiles.sh` |
| New service (non-obvious unit name) | Map it in `scripts/enable-services.sh`; validate-profiles only allows known names |
| New sync agent | Update `scripts/setup-syncing.sh`, profile `SYNC=()`, and `known_sync_agent()` in `scripts/validate-profiles.sh` |
| New `dotfiles` subcommand | Add `cmd_<name>()` + dispatch case + help text in `stow/scripts/bin/dotfiles` |

## Safety Rules

- Never commit secrets, private keys, or machine-local state. `.gitignore` blocks `*.local`, `*.age`, logs, recovery artifacts, and `.config/dotfiles/profile`.
- Stow conflicts are non-destructive: interactive runs prompt, non-interactive skip, `--backup-conflicts` backs up to `~/.dotfiles-backup/<timestamp>/`, `--adopt` requires `git diff` review afterward.
- `dotfiles update --reset` and remote reset mode are destructive and require explicit `--confirm` / `DOTFILES_CONFIRM_RESET=1`.
- Generic Arch is rejected unless Omarchy markers exist or `DOTFILES_ASSUME_OMARCHY=1` is set.
- Remote bootstrap env vars must go on `bash` after the pipe: `curl ... | DOTFILES_UPDATE_MODE=stash bash` — not `VAR=... curl ... | bash` (ignored by Bash).

## Desktop Notes

- Omarchy desktop config lives in `stow/hypr`, `stow/waybar`, `stow/rofi`, `stow/wallpapers`, `stow/themes` — these are OS-base packages, not per-profile.
- After editing Waybar config, use `dotfiles desktop reload waybar` rather than manually killing processes.
- Do not create GUI windows during normal validation — use `dotfiles doctor terminal` for terminal integration checks.
- Keep machine-specific display/hardware details in `profiles/*.conf` metadata keys, not in shared desktop files.
