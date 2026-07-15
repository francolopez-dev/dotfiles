# Recovery Pack

The recovery pack is the encrypted backup for material that must not live in
Git. Dotfiles can rebuild system intent; the recovery pack restores private keys
and credential exports after laptop loss, disk failure, or a full rebuild.

The normal path is the wizard:

```bash
dotfiles recovery setup
dotfiles recovery send
```

The command is not OS-gated. It works on any machine where the required tools are
installed: `age`, `tar`, `base64`, and `msmtp` for email sending.

## What Goes Where

| Item | Git dotfiles | Recovery pack |
|---|---|---|
| Shell, git, tmux, SSH client config | yes | optional |
| Private SSH keys | no | yes |
| Public SSH keys | no, usually local | yes, useful |
| `authorized_keys` from servers | no | yes |
| `~/.ssh/config.local` | no | yes, if useful |
| Lan Mouse TLS private key | no | yes |
| Tailscale trusted-network local config | no | yes |
| Vaultwarden export | no | yes, added manually |
| Tailscale/admin exports | no | yes, if available |
| Gmail app password | no | local config and encrypted pack |
| AGE recovery identity | no | no, unless you already have another offline copy |

Secrets, private keys, `.age` files, logs, recovery-pack working directories,
and `~/.config/dotfiles/recovery.local` must never be committed.

## Keys To Store Securely

Store these outside the machine, ideally in Vaultwarden plus an offline USB or
printed emergency copy:

- `~/.config/age/recovery.txt`: the AGE private identity. This is the secret
  required to decrypt every recovery pack encrypted to its recipient.
- `age1...`: the AGE public recipient printed by `age-keygen -y`. This is safe
  to use in scripts, but keep a copy with your recovery notes so setup can be
  recreated.
- Gmail app password: the SMTP credential used by `msmtp`. This is not your
  normal Gmail password. Create it from the Google account with 2FA enabled.
- Recovery-pack email account access: Gmail stores the encrypted `.age`
  attachments. Keep account recovery current.

Do not put the only copy of `recovery.txt` inside the recovery pack. Without the
AGE identity, the encrypted pack cannot be opened.

## Setup Wizard

Run once per machine that should send recovery packs:

```bash
dotfiles recovery setup
```

The wizard:

- Creates or reuses `~/.config/age/recovery.txt`.
- Prints the AGE recipient and the keys you must store securely.
- Prompts for Gmail SMTP values and an app password.
- Writes local-only config to `~/.config/dotfiles/recovery.local` with mode
  `0600`.

Use the full Gmail address for `RECOVERY_SMTP_USER` unless Google explicitly
shows a different SMTP username. Do not use only the part before `@gmail.com`.

The local config looks like this:

```bash
RECOVERY_EMAIL_TO='you@gmail.com'
RECOVERY_EMAIL_FROM='you@gmail.com'
RECOVERY_SMTP_HOST=smtp.gmail.com
RECOVERY_SMTP_PORT=587
RECOVERY_SMTP_USER='you@gmail.com'
RECOVERY_SMTP_PASSWORD='gmail app password'
RECOVERY_AGE_RECIPIENT='age1...'
RECOVERY_AGE_IDENTITY='/home/you/.config/age/recovery.txt'
RECOVERY_OUTPUT_DIR='/home/you/recovery'
RECOVERY_SEND_INTERVAL_DAYS='30'
```

This file contains secrets and is ignored by Git.

## Send A Pack

```bash
dotfiles recovery send
```

This builds a plaintext working directory in a temporary location, writes a
manifest, encrypts it with AGE, verifies decryption, emails it with Gmail SMTP,
and deletes the plaintext working directory.

The email subject is deterministic so it is easy to identify during disaster
recovery:

```text
recovery pack from <hostname>
```

The encrypted attachment name includes the host and timestamp:

```text
recovery-pack-<hostname>-YYYY-MM-DD-HHMMSS.tar.gz.age
```

## Automatic Send

Install a daily due-check scheduler:

```bash
dotfiles recovery install-timer --days 30
```

The timer runs daily but only sends when `RECOVERY_SEND_INTERVAL_DAYS` has
elapsed since the last successful send:

```bash
dotfiles recovery send --if-due --no-prompt
```

Schedulers are local machine state, not stowed config:

- systemd user timer when `systemctl` is available.
- LaunchAgent when `launchctl` is available.

Remove it with:

```bash
dotfiles recovery uninstall-timer
```

## What The Wizard Collects

Automatically, when present:

- `~/.ssh/id_*`, `~/.ssh/*.pub`, `~/.ssh/authorized_keys`,
  `~/.ssh/config.local`.
- Reachable SSH hosts' `~/.ssh/authorized_keys` from `~/.ssh/config` entries.
- `~/.config/lan-mouse/lan-mouse.pem`.
- `~/.config/dotfiles/tailscale-networks.local`.
- `~/.config/gh/hosts.yml`.
- `~/.kube/config`.
- Syncthing cert/key/config files.
- KDE Connect config.
- Local keyrings, Restic config, and rclone config when present.
- The local recovery SMTP config, inside the encrypted pack.

The AGE identity itself is intentionally not included. The manifest records that
it was skipped.

The wizard also asks for manual export files or directories. Use that prompt for
Vaultwarden, registrar/DNS, Tailscale admin exports, infrastructure notes, or
anything else that should be encrypted into the pack.

## Verify A Pack

```bash
dotfiles recovery verify ~/recovery/recovery-pack-<hostname>-YYYY-MM-DD-HHMMSS.tar.gz.age
```

Verification decrypts into a temporary directory, lists contents, and removes the
temporary plaintext copy.

## Restore On A New Machine

Bootstrap dotfiles first:

```bash
curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | bash
```

Decrypt the pack with your offline AGE identity:

```bash
tmp="$(mktemp -d)"
age -d -i /path/to/recovery.txt /path/to/recovery-pack-YYYY-MM-DD-HHMMSS.tar.gz.age \
  | tar -C "$tmp" -xzf -
```

Restore laptop SSH keys:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
cp -p "$tmp/recovery-pack/ssh"/id_* ~/.ssh/ 2>/dev/null || true
cp -p "$tmp/recovery-pack/ssh/config.local" ~/.ssh/ 2>/dev/null || true
chmod 600 ~/.ssh/id_* ~/.ssh/config.local 2>/dev/null || true
chmod 644 ~/.ssh/*.pub 2>/dev/null || true
```

Restore service-specific credentials deliberately, only onto the machine that
owns them. Clean up extracted plaintext when finished:

```bash
rm -rf "$tmp"
```

## Rotation Checklist

Send a new recovery pack whenever any of these change:

- A new laptop SSH key is created or renamed.
- A server `authorized_keys` file changes.
- Vaultwarden export is refreshed.
- Tailscale, DNS, registrar, or infrastructure recovery data changes.
- Lan Mouse or other local service credentials rotate.
- A machine is retired and its key should no longer be recoverable.

After rotation:

```bash
git -C ~/dotfiles status --short
dotfiles recovery status
```

The recovery pack and local config should not appear in Git status. If they do,
stop and move them outside the repo before committing anything.
