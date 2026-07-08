# dotfiles

Personal machine rebuild kit using Git, Bash, and GNU Stow.

Git is the source of truth for system intent. Secrets, private keys, recovery
packs, logs, and machine-local credentials do not live in this repo.

## What This Does

- Installs declared packages for Omarchy, Debian/Ubuntu, and macOS machines.
- Applies real config files from `stow/` into `$HOME` with GNU Stow.
- Uses layers: `global`, `os-<os>`, then `profile-<hostname>-<os>`.
- Provides one daily command: `dotfiles`.
- Avoids Ansible, Nix, templates, and generated config frameworks.

## Bootstrap A New Omarchy System

Set the hostname first so the right profile is selected. Current Omarchy
profiles are `profile-nox-omarchy` and `profile-fornax-omarchy`.

```bash
curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/refs/heads/main/scripts/bootstrap.sh | bash
exec zsh
dotfiles status
dotfiles doctor
```

Bootstrap is for first run on a new machine. It clones `~/dotfiles`, installs
bootstrap prerequisites, installs Oh My Zsh, links `~/.local/bin/dotfiles`, and
runs `dotfiles update`.

Package policy: always prefer prebuilt binaries. Use official repository
packages first, then official binary packages, then maintained AUR `*-bin`
packages. Source-built AUR packages, including `*-git`, are last-resort only and
must be explicitly allowed in validation.

Some binary AUR packages can still be incompatible with current Arch libraries.
For example, bootstrap tries `paru-bin` first, but falls back to source-built
`paru` when the binary helper is linked to an unavailable pacman/libalpm version.
Declared repo AUR packages are trusted bootstrap inputs and install with paru
`--noconfirm --skipreview` when `DOTFILES_ASSUME_YES=1` is active.

If Stow finds existing Omarchy config, choose the recommended backup option.
Backups go under `~/.dotfiles-backup/YYYY-MM-DD-HHMMSS/`.

## Bootstrap A New Mac

Install Homebrew from `https://brew.sh`, then follow
[`macos-first-time-setup.md`](macos-first-time-setup.md). The personal Mac uses
hostname `lamac` and profile `profile-lamac-macos`.

## Daily Use

```bash
dotfiles status
dotfiles update
dotfiles apply
```

Use dry runs before risky changes:

```bash
dotfiles update --dry-run
dotfiles apply --dry-run
```

Fallback if PATH is broken:

```bash
~/dotfiles/scripts/dotfiles status
~/dotfiles/scripts/dotfiles update --dry-run
```

## Choose Or Switch Profile

The default profile comes from `hostname -s` and OS:

```text
stow/profile-<hostname>-<os>/
packages/profile-<hostname>-<os>/
```

Examples:

- `nox` on Omarchy uses `profile-nox-omarchy`.
- `fornax` on Omarchy uses `profile-fornax-omarchy`.
- `lamac` on macOS uses `profile-lamac-macos`.

To test another profile without renaming the machine:

```bash
DOTFILES_PROFILE=profile-nox-omarchy dotfiles status
DOTFILES_PROFILE=profile-nox-omarchy dotfiles apply --dry-run
```

To permanently switch, rename the host or create the matching stow profile and
package declaration directories.

## Git And SSH Fixes

GitHub password authentication over HTTPS does not work anymore. Use SSH.

```bash
ssh-keygen -t ed25519 -C "email@gmail.com"
cat ~/.ssh/id_ed25519.pub
```

Copy the public key, open GitHub, then go to Settings -> SSH and GPG keys -> New
SSH key. Name it after the machine, for example `NOX Omarchy T490` or `FORNAX
Omarchy Work Laptop`.

Switch the repo remote to SSH:

```bash
cd ~/dotfiles
git remote set-url origin git@github.com:jfrancolopez/dotfiles.git
ssh -T git@github.com
```

Expected success text is generally:

```text
Hi <username>! You've successfully authenticated...
```

Then verify push state:

```bash
git status --short --branch
git push
```

If update stops because the repo is dirty, inspect before changing anything:

```bash
git status --short --branch
git diff --name-only
```

`dotfiles update` will offer to skip pull, stash local changes, or reset only
with explicit confirmation.

## Validate The System

```bash
dotfiles status
dotfiles doctor
hyprctl configerrors
hyprctl monitors
hyprctl getoption general:col.active_border
command -v ghostty firefox atuin zoxide yazi satty tailscale
git status --short --branch
```

Repo checks after edits:

```bash
shellcheck -x bootstrap.sh scripts/*.sh scripts/lib/*.sh
scripts/validate-profiles.sh
./bootstrap.sh --dry-run --profile profile-fornax-omarchy
./bootstrap.sh --dry-run --profile profile-nox-omarchy
```

Walker is an Omarchy default app launcher. This repo does not install, stow, or
configure Walker.

More docs: [first-time-setup.md](first-time-setup.md), [first-time-system.md](first-time-system.md),
[macos-first-time-setup.md](macos-first-time-setup.md), [macos-personal.md](macos-personal.md),
[git-github-cheatsheet.md](git-github-cheatsheet.md), [autostart.md](autostart.md),
[wallpapers.md](wallpapers.md), [terminal-ux.md](terminal-ux.md), and [where-to-edit.md](where-to-edit.md).
