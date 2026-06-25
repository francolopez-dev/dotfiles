# dotfiles

Personal machine rebuild kit using Git, Bash, and GNU Stow.

Git records system intent. Secrets do not live here: Vaultwarden owns passwords,
and the encrypted recovery pack owns keys and infrastructure exports.

## Rules

- Machines are disposable.
- Every managed config is a real file under `stow/`.
- Layers go from broad to specific: global, OS, hostname profile.
- Keep Omarchy defaults on Omarchy. Do not stow app launcher config or package
  entries unless there is a specific reason to override upstream.
- No Ansible, Nix, templates, generated configs, private keys, logs, or recovery
  packs.

## Layers

```text
stow/global
stow/os-<os>
stow/profile-<hostname>-<os>
```

Supported OS IDs: `omarchy`, `debian`, `ubuntu`.

The profile is derived from `hostname -s`. A machine named `fornax` on Omarchy
uses `stow/profile-fornax-omarchy/` and
`packages/profile-fornax-omarchy.list`. If the profile does not exist, only the
global and OS layers apply.

Current profiles:

- `profile-nox-omarchy`: personal Lenovo T490.
- `profile-fornax-omarchy`: work Lenovo.

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

First install:

```bash
curl -fsSL <raw-url>/scripts/bootstrap.sh | bash
```

## Where Things Go

- Shared shell, Git, SSH, tmux, terminals: `stow/global/`.
- Shared Omarchy desktop config: `stow/os-omarchy/`.
- Machine-specific monitors, autostart, idle, and lock config:
  `stow/profile-<hostname>-omarchy/`.
- Packages for every machine: `packages/global.list`.
- Packages for every Omarchy machine: `packages/os-omarchy.list`.
- Packages for one machine: `packages/profile-<hostname>-<os>.list`.

For exact edit locations, see [where-to-edit.md](where-to-edit.md).

## Checks

```bash
shellcheck -x scripts/dotfiles scripts/bootstrap.sh scripts/lib/*.sh
scripts/validate-profiles.sh
scripts/dotfiles status
scripts/dotfiles apply --dry-run
```

More docs: [first-time-setup.md](first-time-setup.md),
[autostart.md](autostart.md), and [terminal-ux.md](terminal-ux.md).
