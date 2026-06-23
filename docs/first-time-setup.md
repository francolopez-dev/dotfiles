# First-time setup

Steps to bring a fresh machine online.

## 1. Run bootstrap

```bash
curl -fsSL <raw-url>/scripts/bootstrap.sh | bash
```

This will:
1. Clone the repo to `~/dotfiles` (or update it if present).
2. Check out the working branch.
3. Apply the stow layers for this machine (`global → os-<os> → profile-<hostname>-<os>`).
4. Symlink the `dotfiles` CLI to `~/.local/bin/dotfiles` and ensure that dir is on `PATH`.

Restart your shell (or `source ~/.zshrc`) so `dotfiles` is found.

## 2. Verify

```bash
dotfiles status
```

Check that the hostname, OS, and active layers are what you expect, and review
any reported package drift.

## 3. Create a profile layer (if this machine needs overrides)

If `dotfiles status` shows no `profile-<hostname>-<os>` layer but this machine
needs machine-specific config (monitors, autostart):

```bash
mkdir -p stow/profile-$(hostname -s)-<os>/hyprland/.config/hypr/conf.d
# add 20-monitors.conf, 30-autostart.conf, etc.
dotfiles apply
```

Copy an existing profile (e.g. `stow/profile-aether-omarchy/`) as a template.

## 4. Install missing packages

`dotfiles status` lists declared-but-missing packages. Install them with the
native package manager (pacman/yay on Omarchy, apt on Debian/Ubuntu).

## 5. Sync & secrets (manual, never automated)

- Authenticate Tailscale: `sudo tailscale up`
- Log in to Atuin: `atuin login`
- Restore SSH/WireGuard keys from the Age recovery pack (see
  [recovery-pack-usage.md](recovery-pack-usage.md)).
- Passwords come from Vaultwarden — never from Git.
