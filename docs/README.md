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
curl -fsSL <raw-url>/scripts/bootstrap.sh | DOTFILES_BRANCH=clean-layers bash
dotfiles status
dotfiles apply
```

See [first-time-setup.md](first-time-setup.md) and [where-to-edit.md](where-to-edit.md).
