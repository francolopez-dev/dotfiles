# Recovery Pack

The recovery pack is the encrypted, offline backup for material that must not
live in Git. Dotfiles can rebuild system intent; the recovery pack restores the
private keys and exports needed after a laptop loss, disk failure, or full
machine rebuild.

This repo does not currently build the recovery pack automatically. Use this
manual runbook until a dedicated helper exists.

## What Goes Where

| Item | Git dotfiles | Recovery pack |
|---|---|---|
| Shell, git, tmux, SSH client config | yes | optional |
| Private SSH keys | no | yes |
| Public SSH keys | no, usually local | yes, useful |
| `authorized_keys` from servers | no | yes |
| `~/.ssh/config.local` | no | yes, if useful |
| Vaultwarden export | no | yes |
| Tailscale/admin exports | no | yes, if available |
| Recovery instructions | yes | yes |
| Browser/session/cache files | no | no |

Secrets, private keys, `.age` files, logs, and recovery-pack working
directories must never be committed.

## Install Tools

On managed Omarchy/macOS machines, `age` is already declared. On a Debian or
Ubuntu server, install it before creating or opening a pack:

```bash
sudo apt update
sudo apt install age tar
```

Verify locally:

```bash
command -v age
command -v tar
```

## Create A Recovery Identity

Do this once on the machine that will decrypt recovery packs. Store the
identity somewhere safer than the laptop itself, such as an offline USB drive or
printed emergency copy.

```bash
mkdir -p ~/.config/age
chmod 700 ~/.config/age

test -f ~/.config/age/recovery.txt || age-keygen -o ~/.config/age/recovery.txt
chmod 600 ~/.config/age/recovery.txt

age-keygen -y ~/.config/age/recovery.txt
```

The last command prints the public recipient, which starts with `age1...`. That
recipient is safe to use in scripts and commands. The identity file
`~/.config/age/recovery.txt` is the secret.

Do not put the only copy of `recovery.txt` inside the recovery pack. Without
that identity, the encrypted pack cannot be opened.

## Build The Pack

Create a temporary working directory:

```bash
pack="$HOME/recovery-pack"
stamp="$(date +%Y-%m-%d)"

rm -rf "$pack"
mkdir -p "$pack/ssh" "$pack/notes" "$pack/exports"
chmod 700 "$pack"
```

Copy SSH material. This copies common key names and skips missing files:

```bash
cp -p ~/.ssh/id_* "$pack/ssh/" 2>/dev/null || true
cp -p ~/.ssh/authorized_keys "$pack/ssh/" 2>/dev/null || true
cp -p ~/.ssh/config.local "$pack/ssh/" 2>/dev/null || true
```

If you use a named laptop key such as `id_ed25519-fornax`, confirm it is in the
pack:

```bash
ls -la "$pack/ssh"
```

Collect server `authorized_keys` from any server you can currently reach. This
is useful after a server rebuild because it tells you which laptop keys were
trusted. Skip hosts that are offline or unreachable:

```bash
ssh domum-core 'cat ~/.ssh/authorized_keys 2>/dev/null' > "$pack/ssh/domum-core-authorized_keys" || true
```

Add a simple restore note:

```bash
cat > "$pack/README.txt" <<'EOF'
Recovery pack contents are secrets.

Restore SSH keys:
  mkdir -p ~/.ssh
  chmod 700 ~/.ssh
  cp -p ssh/id_* ~/.ssh/ 2>/dev/null || true
  cp -p ssh/config.local ~/.ssh/ 2>/dev/null || true
  chmod 600 ~/.ssh/id_* ~/.ssh/config.local 2>/dev/null || true
  chmod 644 ~/.ssh/*.pub 2>/dev/null || true

Restore server authorized_keys only on the server that owns them.
Never commit this pack or its extracted files to Git.
EOF
```

Add manual exports as needed:

```bash
# Put Vaultwarden exports, registrar/DNS exports, Tailscale notes, or other
# manual files under "$pack/exports" before encrypting.
ls -la "$pack/exports"
```

Do not store the recovery identity itself in `"$pack"` unless another offline
copy already exists.

Encrypt the pack. Replace `age1REPLACE_WITH_YOUR_RECIPIENT` with the recipient
from `age-keygen -y ~/.config/age/recovery.txt`:

```bash
tar -C "$HOME" -czf - recovery-pack \
  | age -r 'age1REPLACE_WITH_YOUR_RECIPIENT' \
  > "$HOME/recovery-pack-$stamp.tar.gz.age"

chmod 600 "$HOME/recovery-pack-$stamp.tar.gz.age"
```

Remove the unencrypted working copy after verifying the encrypted file exists:

```bash
ls -lh "$HOME/recovery-pack-$stamp.tar.gz.age"
rm -rf "$pack"
```

Move the encrypted `.age` file to offline storage. Do not leave the only copy on
the machine it is meant to recover.

## Verify The Pack

Test decryption in a temporary directory before trusting it:

```bash
tmp="$(mktemp -d)"
age -d -i ~/.config/age/recovery.txt "$HOME/recovery-pack-$stamp.tar.gz.age" \
  | tar -C "$tmp" -xzf -

find "$tmp/recovery-pack" -maxdepth 3 -type f -print
rm -rf "$tmp"
```

If decryption fails, the recovery identity does not match the recipient used to
encrypt the pack.

## Restore On A New Machine

Bootstrap dotfiles first, then restore secrets:

```bash
curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | bash
```

Decrypt the pack:

```bash
tmp="$(mktemp -d)"
age -d -i /path/to/recovery.txt /path/to/recovery-pack-YYYY-MM-DD.tar.gz.age \
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

Test access:

```bash
ssh domum-core
```

Clean up the extracted copy when finished:

```bash
rm -rf "$tmp"
```

## Rotation Checklist

Rebuild the recovery pack whenever any of these change:

- A new laptop SSH key is created or renamed.
- A server `authorized_keys` file changes.
- Vaultwarden export is refreshed.
- Tailscale, DNS, registrar, or infrastructure recovery data changes.
- A machine is retired and its key should no longer be recoverable.

After rotation:

```bash
git -C ~/dotfiles status --short
```

The recovery pack should not appear in Git status. If it does, stop and move it
outside the repo before committing anything.
