# dotfiles

A small, layered, GNU Stow based personal platform for rebuilding and
maintaining machines. Git is the source of truth for system intent. Secrets do
not live here: Vaultwarden owns passwords and the encrypted recovery pack owns
key material.

## Philosophy

- Machines are disposable.
- Every managed config is a real file under `stow/`.
- Directory names explain scope: global, OS, then hostname profile.
- Bash and Stow only. No Ansible, Nix, templates, or generated config files.

## Layers

Configs apply in strict order:

```text
stow/global
stow/os-<os>
stow/profile-<hostname>-<os>
```

The supported OS IDs are `omarchy`, `debian`, and `ubuntu`. The profile name is
derived from `hostname -s`, so this work Lenovo named `fornax` on Omarchy uses
`stow/profile-fornax-omarchy/`. If that directory does not exist, only global and
OS layers apply.

## Current Profiles

- `profile-nox-omarchy`: personal Lenovo T490.
- `profile-fornax-omarchy`: work Lenovo.

## Quickstart

```bash
curl -fsSL <raw-url>/scripts/bootstrap.sh | bash
dotfiles status
dotfiles update
```

See [first-time-setup.md](first-time-setup.md), [where-to-edit.md](where-to-edit.md),
and [terminal-ux.md](terminal-ux.md).

## Cheatsheet

```text
Setup
  curl -fsSL <raw-url>/scripts/bootstrap.sh | bash         first-time install
  DOTFILES_BRANCH=<branch> bash                            pick a branch

Daily
  dotfiles status         dashboard: host, layers, drift, sync, recovery
  dotfiles update         pull + re-stow + install missing packages
  dotfiles apply          re-stow layers after editing configs

Terminal UX
  ..                      go up one directory
  gs                      git status
  gp                      git pull
  dps                     docker ps
  dcu                     docker compose up -d
  dcd                     docker compose down
  ff                      fastfetch, quiet if unavailable
  v                       nvim
  y                       yazi file manager
  l                       compact colored box table listing
  ll                      same as l
  la                      same as l --all
  lt                      two-level tree
  l --created             table using created date
  l --accessed            table using accessed date
  l --changed             table using changed date
  l --raw <eza flags>     raw eza long listing for extra columns
  z                       zoxide jump
  atuin                   shell history
  cls                     clear screen and scrollback

Dry-run flags
  dotfiles update --dry-run   preview without changing anything
  dotfiles apply  --dry-run   preview stow without touching files

Validation
  shellcheck -x scripts/dotfiles scripts/bootstrap.sh scripts/lib/*.sh
  scripts/validate-profiles.sh

Layer order
  stow/global  →  stow/os-<os>  →  stow/profile-<hostname>-<os>
```
