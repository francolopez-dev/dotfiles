# Troubleshooting

Common failures and safe fixes.

## GitHub HTTPS Password Auth Failed

Symptom:

```text
remote: Support for password authentication was removed
fatal: Authentication failed
```

Cause: GitHub no longer accepts account passwords for Git over HTTPS.

Preferred fix: use SSH.

```bash
cd ~/dotfiles
ssh -T git@github.com
git push
```

## Missing GitHub Public Key

If SSH says `Permission denied (publickey)`, check whether this machine has a
key:

```bash
ls -l ~/.ssh/*.pub
```

If no suitable key exists, create one:

```bash
ssh-keygen -t ed25519 -C "machine-name-or-email"
cat ~/.ssh/id_ed25519.pub
```

Add the public key to GitHub:

```text
GitHub -> Settings -> SSH and GPG keys -> New SSH key
```

Do not paste the private key. Only paste the `.pub` key.

## Permission Denied Publickey

Run:

```bash
ssh -T git@github.com
ssh -vT git@github.com
```

Check:

- The repo remote is SSH: `git remote -v`.
- The public key is present in GitHub.
- The private key exists locally and has safe permissions.
- Your `~/.ssh/config.local` points at the right per-machine key if needed.

Safe permissions:

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
```

## Bad UseKeychain Option On Linux

Symptom:

```text
Bad configuration option: usekeychain
```

Cause: `UseKeychain yes` is a macOS-specific SSH option. It must not be in the
shared Linux-safe SSH config.

Fix: remove `UseKeychain yes` from shared config and put macOS-only behavior in
local untracked config, such as:

```text
~/.ssh/config.local
```

The stowed shared config should include only cross-platform options and:

```sshconfig
Include ~/.ssh/config.local
```

## Known Hosts First Connection Prompt

The first SSH connection to GitHub may ask:

```text
The authenticity of host 'github.com' can't be established.
Are you sure you want to continue connecting?
```

This is normal on a new machine. Confirm only when the host is `github.com` and
the fingerprint matches GitHub's published SSH key fingerprints.

## Tailscale Service Unit Not Found

Bootstrap maps friendly service name `tailscale` to `tailscaled.service`.

Check package and unit state:

```bash
command -v tailscale
pacman -Qi tailscale
systemctl list-unit-files 'tailscaled.service'
systemctl cat tailscaled.service
test -f /usr/lib/systemd/system/tailscaled.service && echo present
```

If the unit exists, enable the service:

```bash
sudo systemctl enable --now tailscaled.service
```

Then join manually:

```bash
sudo tailscale up
```

Do not restore `/var/lib/tailscale` from another machine.

## WezTerm Or Terminal Launcher Fails

Run the non-GUI terminal diagnostic:

```bash
dotfiles doctor terminal
```

Manual checks:

```bash
wezterm --version
xdg-terminal-exec --print-id
xdg-terminal-exec --print-path
xdg-terminal-exec --print-cmd
hyprctl binds
```

Normal bootstrap should not launch a GUI terminal window during validation.
