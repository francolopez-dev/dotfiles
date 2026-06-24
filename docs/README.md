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

See [first-time-setup.md](first-time-setup.md) and [where-to-edit.md](where-to-edit.md).

## Cheatsheet

```text
Setup
  curl -fsSL <raw-url>/scripts/bootstrap.sh | bash         first-time install
  DOTFILES_BRANCH=<branch> bash                            pick a branch

Daily
  dotfiles status         dashboard: host, layers, drift, sync, recovery
  dotfiles update         pull + re-stow + install missing packages
  dotfiles apply          re-stow layers after editing configs

Dry-run flags
  dotfiles update --dry-run   preview without changing anything
  dotfiles apply  --dry-run   preview stow without touching files

Validation
  shellcheck -x scripts/dotfiles scripts/bootstrap.sh scripts/lib/*.sh
  scripts/validate-profiles.sh

Layer order
  stow/global  →  stow/os-<os>  →  stow/profile-<hostname>-<os>
```
