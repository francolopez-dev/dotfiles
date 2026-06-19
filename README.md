# Dotfiles — Personal Platform

A Git-based personal platform for rebuilding and maintaining my machines:

```text
install OS -> bootstrap dotfiles -> dotfiles update -> back to work
```

Core rule: Git is the source of truth for system intent. Secrets and private keys
do not live in Git.

## Quick Start

Fresh trusted machine:

```bash
curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | bash
```

Then follow `docs/first-time-system.md` for SSH/GitHub setup and first checks.

Existing machine:

```bash
dotfiles update
```

## Daily Commands

| Command | Purpose |
|---------|---------|
| `dotfiles update` | Pull latest config and re-apply it |
| `dotfiles bootstrap` | Apply config without pulling |
| `dotfiles status` | Show machine, profile, repo, services, and sync state |
| `dotfiles doctor` | Run read-only diagnostics |
| `dotfiles doctor terminal` | Check terminal integration without launching a GUI window |
| `dotfiles profile show` | Show active profile and declarations |
| `dotfiles profile select` | Pick and persist a profile |
| `dotfiles recovery build` | Build an encrypted Recovery Pack |
| `dotfiles recovery health` | Check Recovery Pack health |
| `dotfiles sync status` | Show Tailscale/Atuin/Syncthing state |
| `dotfiles sync setup` | Re-run sync setup for the active profile |
| `dotfiles desktop reload waybar` | Restart Waybar after editing Omarchy desktop files |
| `dotfiles desktop doctor` | Check Omarchy desktop terminal integration |

If `dotfiles` is not on PATH yet, open a new terminal or use:

```bash
~/bin/dotfiles doctor
```

## Supported Profiles

| Class | OS | Package manager | Example profile |
|-------|----|-----------------|-----------------|
| Personal desktop | Omarchy | pacman + yay | `desktop-personal-omarchy` |
| Work desktop | Omarchy | pacman + yay | `desktop-work-omarchy` |
| Personal laptop | Omarchy | pacman + yay | `laptop-personal-omarchy` |
| Work laptop | Omarchy | pacman + yay | `laptop-work-omarchy` |
| Personal laptop | macOS | Homebrew | `personal-macos` |
| Work laptop | macOS | Homebrew | `work-macos` |
| Personal server | Debian | apt | `server-debian` |
| Work server | Ubuntu | apt | `server-ubuntu` |

## Docs Index

| File | Purpose |
|------|---------|
| `docs/first-time-system.md` | New-machine onboarding |
| `docs/profiles.md` | Profile and stow model |
| `docs/recovery-pack-usage.md` | Recovery Pack usage |
| `docs/sync.md` | Tailscale, Atuin, and Syncthing |
| `docs/desktop-omarchy.md` | Hyprland, Waybar, WezTerm, and Rofi |
| `docs/troubleshooting.md` | Common failures and fixes |
| `docs/machines/lenovo-work-laptop.md` | Machine-specific Lenovo work laptop notes |
| `docs/SSH-keys-and-config.md` | SSH key and config model |
| `docs/extending.md` | How to add packages, profiles, services, and config |
| `docs/architecture.md` | Platform boundaries and data ownership |
| `DESIGN.md` | UX and safety principles |

Historical planning and audit docs may remain under `docs/`, but the files above
are the current operating guides.

## How It Works

```text
curl bootstrap.sh | bash
  -> scripts/bootstrap.sh clones or safely updates the repo
  -> ./bootstrap.sh detects OS, selects profile, installs packages, applies stow
  -> dotfiles is stowed to ~/bin/dotfiles for daily use
```

Root bootstrap remains available for installer and recovery internals:

```bash
cd ~/dotfiles
./bootstrap.sh --first-time
./bootstrap.sh --profile laptop-personal-omarchy
./bootstrap.sh --dry-run --profile laptop-work-omarchy
```

Both `dotfiles bootstrap` and `./bootstrap.sh` are designed to be safe to rerun.

## Safety Rules

- Do not store private keys, credentials, or plaintext Recovery Pack contents in Git.
- Generate one SSH key per trusted machine by default.
- Use the Recovery Pack for disaster recovery, not everyday private-key copying.
- Do not use GitHub password authentication for Git pushes.
- Do not auto-login to GitHub, Tailscale, Atuin, or password stores from bootstrap.
- Do not restore `/var/lib/tailscale`; rejoin with `sudo tailscale up`.

## Repository Layout

```text
bootstrap.sh                 root orchestrator
scripts/                     install, validation, recovery, sync logic
stow/                        GNU Stow packages linked into $HOME
packages/                    package groups per OS/package manager
profiles/                    machine intent declarations
config/                      safe default configs for tooling
tests/                       shell test suites
```

## Troubleshooting

Start with:

```bash
dotfiles doctor
dotfiles doctor terminal
```

Then see `docs/troubleshooting.md`.
