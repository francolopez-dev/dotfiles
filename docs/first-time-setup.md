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
curl -fsSL <raw-url>/scripts/bootstrap.sh | bash
```

Bootstrap clones or updates `~/dotfiles`, checks out `main` by default, applies the
ordered Stow layers, and links `scripts/dotfiles` to `~/.local/bin/dotfiles`.
It installs the bootstrap prerequisites (`git`, `stow`, `bash`, `curl`) before
Stow runs.

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

## 5. New Machine Profile

If a machine needs overrides, copy the closest existing profile and rename it:

```bash
cp -a stow/profile-fornax-omarchy stow/profile-$(hostname -s)-omarchy
cp packages/profile-fornax-omarchy.list packages/profile-$(hostname -s)-omarchy.list
```

Then edit `20-monitors.conf`, `30-autostart.conf`, and package list entries for
that machine.
