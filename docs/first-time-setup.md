# First-time setup

## 1. Choose the hostname

Set a human hostname before bootstrapping. The repo does not force a naming
scheme; it only derives the profile directory from the hostname and OS.

Examples:

```bash
hostname -s
# nox, fornax, domu-core, ...
```

## 2. Run bootstrap

```bash
curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/refs/heads/main/scripts/bootstrap.sh | bash
```

Bootstrap clones or updates `~/dotfiles`, checks out `main` by default, applies the
ordered Stow layers, and links `scripts/dotfiles` to `~/.local/bin/dotfiles`.
It installs the bootstrap prerequisites (`git`, `stow`, `bash`, `curl`, `zsh`)
and Oh My Zsh before Stow runs.

Walker is an Omarchy default app launcher. This repo does not install, stow, or
configure Walker.

If bootstrap hits local config conflicts, choose the recommended
`backup existing files and stow repo version` option. Backups are written under
`~/.dotfiles-backup/YYYY-MM-DD-HHMMSS/`.

If the shell cannot find `dotfiles` after an interrupted bootstrap, use the
source checkout directly:

```bash
~/dotfiles/scripts/dotfiles status
~/dotfiles/scripts/dotfiles update
```

## 3. Verify

```bash
dotfiles status
```

Confirm the hostname, OS, and active layers. For this work Lenovo, the active
profile should be `profile-fornax-omarchy`. For the personal T490 named `nox`,
the active profile should be `profile-nox-omarchy`.

## 4. Manual post-bootstrap steps

- Authenticate Tailscale manually: `sudo tailscale up`.
- Log in to Atuin manually: `atuin login`.
- Restore private keys only from the encrypted recovery pack.
- Keep passwords in Vaultwarden, never in Git.

## 5. GitHub SSH

GitHub password authentication over HTTPS does not work anymore. Use SSH.

```bash
ssh-keygen -t ed25519 -C "email@gmail.com"
cat ~/.ssh/id_ed25519.pub
```

Copy the public key, then go to GitHub -> Settings -> SSH and GPG keys -> New
SSH key. Use a machine name such as `NOX Omarchy T490` or `FORNAX Omarchy Work
Laptop`.

```bash
cd ~/dotfiles
git remote set-url origin git@github.com:jfrancolopez/dotfiles.git
ssh -T git@github.com
git status --short --branch
git push
```

Expected SSH success text is generally:

```text
Hi <username>! You've successfully authenticated...
```

## 6. New Machine Profile

If a machine needs overrides, copy the closest existing profile and rename it:

```bash
cp -a stow/profile-fornax-omarchy stow/profile-$(hostname -s)-omarchy
cp packages/profile-fornax-omarchy.list packages/profile-$(hostname -s)-omarchy.list
```

Then edit `20-monitors.conf`, `30-autostart.conf`, and package list entries for
that machine.
