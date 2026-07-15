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

## Quick Start

Bootstrap is for the first run on a new machine. It clones `~/dotfiles`,
installs prerequisites, installs Oh My Zsh, links `~/.local/bin/dotfiles`, and
runs `dotfiles update`. It is safe to rerun. Existing config is never silently
overwritten: pick the recommended backup option and files land in
`~/.dotfiles-backup/YYYY-MM-DD-HHMMSS/`.

### Omarchy desktop

Set the hostname first so the right profile is selected (current profiles:
`nox`, `fornax`).

```bash
curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/refs/heads/main/scripts/bootstrap.sh | bash
exec zsh
dotfiles status
dotfiles doctor
```

### Mac

Install Homebrew from `https://brew.sh`, then follow
[`macos-first-time-setup.md`](macos-first-time-setup.md). The personal Mac uses
hostname `lamac` and profile `profile-lamac-macos`.

### Debian/Ubuntu server (minimal)

Headless servers get the terminal-only experience (zsh + shared aliases +
tmux/TDL + Neovim + Yazi when available from apt), never desktop packages:

```bash
curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/refs/heads/main/scripts/bootstrap.sh | bash -s -- --minimal
```

`--minimal` is a guard, not a separate mode: on Debian/Ubuntu the flow is
identical to plain bootstrap; on Omarchy/macOS it refuses to run. Details,
work-vs-personal guidance, and hardening: [`server-minimal.md`](server-minimal.md).

## Daily Use

```bash
dotfiles status    # machine, layers, package drift, sync state
dotfiles update    # pull, install missing packages, re-stow layers
dotfiles apply     # re-stow only, after editing configs locally
dotfiles doctor    # health checks
dotfiles recovery  # encrypted recovery-pack setup/status/send
```

Use dry runs before risky changes:

```bash
dotfiles update --dry-run
dotfiles apply --dry-run
```

Forgot a shortcut or alias? The registry is searchable:

```bash
dotfiles commands search tmux
```

Omarchy desktop window-manager shortcuts are documented in
[`omarchy-keybindings.md`](omarchy-keybindings.md).

Fallback if PATH is broken:

```bash
~/dotfiles/scripts/dotfiles status
```

## Profiles

The profile comes from `hostname -s` plus detected OS:

```text
stow/profile-<hostname>-<os>/
packages/profile-<hostname>-<os>/
```

Examples: `profile-nox-omarchy`, `profile-fornax-omarchy`,
`profile-lamac-macos`. If the profile directory does not exist, only `global`
and `os-<os>` apply (this is how minimal servers work).

To test another profile without renaming the machine:

```bash
DOTFILES_PROFILE=profile-nox-omarchy dotfiles apply --dry-run
```

To switch permanently, rename the host or create the matching stow and
package directories.

## Package Policy

Always prefer prebuilt binaries: official repository packages first, then
official binary packages, then maintained AUR `*-bin` packages. Source builds
(including `*-git`) are last-resort only and must be explicitly allowed in
validation.

A binary AUR helper can still lag current Arch libraries: bootstrap tries
`paru-bin` first and falls back to source-built `paru` when the binary is
linked against an unavailable pacman/libalpm. Declared repo AUR packages are
trusted bootstrap inputs and install with paru `--noconfirm --skipreview` when
`DOTFILES_ASSUME_YES=1` is active.

On Debian/Ubuntu, package lists stay stock-repo-only; anything needing a
third-party apt repo is a per-machine profile opt-in.

## Git And SSH

GitHub needs SSH (HTTPS password auth is gone). The guided path:

```bash
dotfiles git setup-ssh
```

It walks through key generation, adding the key to GitHub, and switching the
repo remote — prompting before every change. Manual steps and troubleshooting:
[`git-github-cheatsheet.md`](git-github-cheatsheet.md).

For server access from a new laptop, see
[`server-minimal.md#add-a-new-laptop-ssh-key-to-a-server`](server-minimal.md#add-a-new-laptop-ssh-key-to-a-server).
Private keys belong in the encrypted recovery pack, not Git; see
[`recovery-pack.md`](recovery-pack.md).

Recovery packs are built and emailed with:

```bash
dotfiles recovery setup
dotfiles recovery send
```

Store `~/.config/age/recovery.txt`, the printed `age1...` recipient, and the
Gmail app password securely outside the machine.

If `dotfiles update` finds local changes in the repo, it skips the pull and
asks: continue without pulling (recommended), stash then pull, or reset
(destructive, explicit confirmation only). Inspect first:

```bash
git status --short --branch
git diff --name-only
```

## Validate The System

Any machine:

```bash
dotfiles status
dotfiles doctor
git -C ~/dotfiles status --short --branch
```

Omarchy only:

```bash
hyprctl configerrors
hyprctl monitors
command -v ghostty firefox atuin zoxide yazi satty tailscale
```

Repo checks after editing scripts or packages:

```bash
shellcheck -x bootstrap.sh scripts/*.sh scripts/lib/*.sh
scripts/validate-profiles.sh
./bootstrap.sh --dry-run --profile profile-fornax-omarchy
./bootstrap.sh --dry-run --profile profile-nox-omarchy
DOTFILES_BOOTSTRAP_OS=debian ./bootstrap.sh --dry-run --minimal
```

Walker is an Omarchy default app launcher; this repo does not install, stow,
or configure it.

## All Docs

Setup and rebuild:

- [`first-time-setup.md`](first-time-setup.md) — new Omarchy machine walkthrough.
- [`first-time-system.md`](first-time-system.md) — OS install steps before bootstrap.
- [`macos-first-time-setup.md`](macos-first-time-setup.md) — new Mac walkthrough.
- [`macos-personal.md`](macos-personal.md) — personal Mac specifics.
- [`server-minimal.md`](server-minimal.md) — headless Debian/Ubuntu servers, hardening, work vs personal.
- [`recovery-pack.md`](recovery-pack.md) — encrypted backup for SSH keys, exports, and disaster recovery material.

Terminal workflow:

- [`terminal-cheatsheet.md`](terminal-cheatsheet.md) — daily terminal commands, aliases, fzf, zoxide, delta, tmux/TDL, history, diagnostics.
- [`git-github-cheatsheet.md`](git-github-cheatsheet.md) — git commands and GitHub SSH.

Desktop and machines:

- [`where-to-edit.md`](where-to-edit.md) — which file to touch for a given change.
- [`autostart.md`](autostart.md) — login/startup item management.
- [`wallpapers.md`](wallpapers.md) — wallpaper rotation.
- [`kvm-sharing.md`](kvm-sharing.md) — lan-mouse keyboard/mouse sharing between machines.
- [`omarchy-virtualization.md`](omarchy-virtualization.md) — Windows VMs on Omarchy.
- [`omarchy-dockurr-windows.md`](omarchy-dockurr-windows.md) — dockurr-based Windows with RDP.
- [`omarchy-dualboot-windows.md`](omarchy-dualboot-windows.md) — native Windows dual boot (manual, optional).
