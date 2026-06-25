# First-Time System Setup

Use this on a fresh Omarchy machine after setting the hostname.

## Bootstrap

```bash
curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/refs/heads/main/scripts/bootstrap.sh | bash
exec zsh
dotfiles status
dotfiles doctor
```

Bootstrap is a first-run command. Daily work should use `dotfiles status`,
`dotfiles update`, and `dotfiles apply`.

Walker is an Omarchy default app launcher. This repo does not install, stow, or
configure Walker.

## GitHub SSH Key

GitHub password authentication over HTTPS does not work anymore. Create an SSH
key and add it to GitHub.

```bash
ssh-keygen -t ed25519 -C "email@gmail.com"
cat ~/.ssh/id_ed25519.pub
```

1. Copy the public key.
2. Go to GitHub.
3. Open Settings -> SSH and GPG keys -> New SSH key.
4. Add the key with the machine name, for example `NOX Omarchy T490` or `FORNAX Omarchy Work Laptop`.

Switch the remote to SSH:

```bash
cd ~/dotfiles
git remote set-url origin git@github.com:jfrancolopez/dotfiles.git
```

Test GitHub SSH auth:

```bash
ssh -T git@github.com
```

Expected success text is generally:

```text
Hi <username>! You've successfully authenticated...
```

Push test:

```bash
git status --short --branch
git push
```

## Profiles

The active profile is derived from `hostname -s` and OS.

- `nox` on Omarchy uses `profile-nox-omarchy`.
- `fornax` on Omarchy uses `profile-fornax-omarchy`.

Check profile selection:

```bash
dotfiles status
```

Temporarily test a profile:

```bash
DOTFILES_PROFILE=profile-nox-omarchy dotfiles apply --dry-run
```

## Common Recovery

If `dotfiles` is not on PATH yet:

```bash
~/dotfiles/scripts/dotfiles status
~/dotfiles/scripts/dotfiles update --dry-run
```

If Git says the repo is dirty:

```bash
cd ~/dotfiles
git status --short --branch
git diff --name-only
```

Then rerun:

```bash
dotfiles update
```

Choose the safe default to skip pull if you are unsure. Stash only if you want
Git to save the local changes for manual review. Reset only if you are certain
the local changes are disposable.

## Validate

```bash
dotfiles status
dotfiles doctor
hyprctl configerrors
hyprctl monitors
hyprctl getoption general:col.active_border
hyprctl binds | grep -Ei "SUPER|CTRL|screenshot|workspace|quake|note"
command -v ghostty firefox atuin zoxide yazi satty tailscale
git status --short --branch
```
