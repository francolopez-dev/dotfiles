# dotfiles

A layered, [GNU Stow](https://www.gnu.org/software/stow/)-based personal platform
for rebuilding and maintaining machines. Git is the source of truth for system
intent. Secrets never live in Git (Vaultwarden owns passwords; the Age recovery
pack owns key material).

## Philosophy

- **Machines are disposable.** A fresh machine is one `bootstrap.sh` away.
- **Every config is a real file you can edit.** No generated files, no templating.
- **The directory name tells you what a thing is.** Read the tree, understand the system.
- **Bash + Stow only.** No Ansible, no Nix, no frameworks.

## Layers

Configs are applied in strict order. Later layers add to (never overwrite) earlier ones:

```
global              # universal: git, zsh, bash, tmux, ssh, shell aliases
  └─ os-<os>        # per-OS desktop/server: omarchy, debian, ubuntu
       └─ profile-<hostname>-<os>   # machine-specific: monitors, autostart, …
```

The profile layer is derived from the machine's **hostname** and detected **OS**.
If `stow/profile-<hostname>-<os>/` exists, that machine has overrides; if not,
only `global` + `os-<os>` apply (headless / simple cases).

## Repository structure

```
stow/        ALL managed configs, one stow package per app, grouped by layer
packages/    plain-text package lists, one per layer (*.list)
scripts/     bootstrap.sh, the dotfiles CLI, and lib/ helpers
docs/        this documentation
```

## Quickstart

```bash
# First machine setup (clones, stows, links the CLI onto PATH):
curl -fsSL <raw-url>/scripts/bootstrap.sh | bash

# Day to day:
dotfiles status     # machine identity, active layers, package drift
dotfiles apply      # re-stow all layers for this machine
```

See [first-time-setup.md](first-time-setup.md) and [where-to-edit.md](where-to-edit.md).
