# SSH keys and config 


## Concept
- One SSH keypair per workstation (MacBook, home Linux desktop, work laptop, etc.)
- Servers accept multiple public keys (one per device)
- `~/.ssh/config` is predictable, readable, and supports LAN + Tailscale hostnames
- Works with your stow package: `stow/ssh/.ssh/config`

---

### Private key vs public key
- **Private key**: `~/.ssh/id_ed25519_<device>`  
  Must stay secret and local to the device.
- **Public key**: `~/.ssh/id_ed25519_<device>.pub`  
  This gets copied to servers (appended into `~/.ssh/authorized_keys` on the server).

### `IdentityFile` in `~/.ssh/config`
`IdentityFile` points to a *private key file* that SSH should try.

---

### 1) Use one key per device
Naming:

- MacBook (personal): `~/.ssh/id_ed25519_franco_mac`
- Linux desktop: `~/.ssh/id_ed25519_franco_linux`
- Work laptop: `~/.ssh/id_ed25519_franco_work`


---

## Generate a key (per device)

Run this on the device you are setting up:

```bash
ssh-keygen -t ed25519 -a 64 -C "franco-macbook-2026" -f ~/.ssh/id_ed25519_franco_mac
```

Notes:
- `-a 64` increases KDF rounds (better protection if key is stolen).
- Use a passphrase.

Verify files were created:

```bash
ls -l ~/.ssh/id_ed25519*
```

You should see:
- `id_ed25519_franco_mac` (private)
- `id_ed25519_franco_mac.pub` (public)

---

## Install the public key on a server

### Option A: ssh-copy-id
From your workstation:

```bash
ssh-copy-id -i ~/.ssh/id_ed25519_franco_mac.pub jfranco@domum-core
```

### Option B: manual append
```bash
cat ~/.ssh/id_ed25519_franco_mac.pub | ssh jfranco@domum-core \
  'mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'
```

---

## A clean `~/.ssh/config`


We will do that with:

- Stowed: `~/.ssh/config`
- Local: `~/.ssh/config.local`

### 1) Add this to your stowed `~/.ssh/config`

```sshconfig
# ~/.ssh/config (stowed from dotfiles)
# Keep this file cross-device and generic.

Host *
  ServerAliveInterval 30
  ServerAliveCountMax 3
  AddKeysToAgent yes
  UseKeychain yes
  IdentitiesOnly yes
  PreferredAuthentications publickey

# Load per-device overrides (NOT tracked)
Include ~/.ssh/config.local

# --- Common hosts ---
# LAN
Host domum-core
  HostName 10.0.10.2
  User jfranco
  Port 22

# Tailscale (direct IP)
Host domum-core-tail
  HostName 100.91.33.21
  User jfranco
  Port 22

# If you use Tailscale MagicDNS, prefer this instead:
# Host domum-core-tail
#   HostName domum-core
#   User jfranco
#   Port 22
```

### 2) On EACH device, create `~/.ssh/config.local`

This file is device-specific and never committed.

**MacBook example** (`~/.ssh/config.local`):

```sshconfig
# ~/.ssh/config.local (NOT in git)
# Keys that exist on THIS device only.

Host domum-core domum-core-tail 10.0.10.2 100.91.33.21
  IdentityFile ~/.ssh/id_ed25519_franco_mac
```

**Linux desktop example**:

```sshconfig
Host domum-core domum-core-tail 10.0.10.2 100.91.33.21
  IdentityFile ~/.ssh/id_ed25519_franco_linux
```


---

## Another way


```sshconfig
Host domum-core
  IdentityFile ~/.ssh/id_ed25519_franco_mac
  IdentityFile ~/.ssh/id_ed25519_franco_linux
```


If a key file doesn’t exist, SSH will log warnings and waste time trying it. Not harmful, just noisy.

**Better:** keep keys per-device in `config.local` like shown above.

---

## How to use ssh-agent (recommended)

### macOS
Add the key to the agent and keychain:

```bash
ssh-add --apple-use-keychain ~/.ssh/id_ed25519_franco_mac
```

### Linux
Start an agent (most desktops already do), then:

```bash
ssh-add ~/.ssh/id_ed25519_franco_linux
```

---

## Rotating or revoking a device key

If you lose a device or want to revoke access:
1. Remove that device’s public key from each server:
   ```bash
   nano ~/.ssh/authorized_keys
   ```
2. Delete only the line that matches the lost device key comment.


---

## Server-side hygiene checklist

On each server:
```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

In `/etc/ssh/sshd_config` (optional hardening):
- `PasswordAuthentication no` (only after keys work)
- `PermitRootLogin no` (if appropriate)

Restart SSH:
```bash
sudo systemctl restart ssh
```

---

## Quick workflow for adding a new workstation

1. Generate key on the workstation:
   ```bash
   ssh-keygen -t ed25519 -a 64 -C "franco-<device>-<year>" -f ~/.ssh/id_ed25519_franco_<device>
   ```
2. Add the public key to each server:
   ```bash
   ssh-copy-id -i ~/.ssh/id_ed25519_franco_<device>.pub jfranco@domum-core
   ```
3. Create `~/.ssh/config.local` pointing to the key.
4. Test:
   ```bash
   ssh -v domum-core
   ```



