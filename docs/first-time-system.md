# First-Time System Setup

This is the boring new-machine path for a trusted laptop, desktop, or server.

The rule: Git stores the system intent. Private keys and secrets do not live in
Git. Each trusted machine normally gets its own SSH key.

## Fresh Trusted Machine

1. Install the OS.

2. Run the remote bootstrap:

```bash
curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | bash
```

3. Choose the correct profile when prompted.

Examples:

- `laptop-personal-omarchy`
- `laptop-work-omarchy`
- `personal-macos`
- `server-debian`

4. Let bootstrap install packages and stow configs.

5. Generate a machine-specific SSH key if this machine does not already have one:

```bash
ssh-keygen -t ed25519 -C "machine-name-or-email"
```

Use a clear comment, such as `lenovo-omarchy-personal` or your email address.
Use a passphrase.

6. Show the public key:

```bash
cat ~/.ssh/id_ed25519.pub
```

7. Add the public key to GitHub.

Open GitHub, then go to:

```text
Settings -> SSH and GPG keys -> New SSH key
```

Suggested titles:

- `Lenovo Omarchy Laptop`
- `Desktop Omarchy Workstation`
- `MacBook Work`

Only paste the `.pub` public key. Never paste a private key into GitHub.

8. Switch this repo to SSH:

```bash
cd ~/dotfiles
```

9. Test GitHub SSH and Git push:

```bash
ssh -T git@github.com
```

The first SSH connection may ask whether to trust GitHub's host key. Confirm only
if the host is `github.com` and the fingerprint matches GitHub's published SSH
key fingerprints.

10. Run diagnostics:

```bash
dotfiles doctor
```

If `dotfiles` is not on PATH yet, open a new terminal or run:

```bash
~/bin/dotfiles doctor
```

## Does Every New System Need To Authenticate Again?

Yes. Each new trusted machine should normally generate its own SSH key and add
the public key to GitHub.

Do not reuse the same private SSH key everywhere by default. Per-machine keys are
easier to revoke when one laptop is lost, sold, or rebuilt.

The Recovery Pack can restore keys for disaster recovery or emergency rebuilds,
but that is not the default convenience path.

## Existing Machine Or Daily Update

Use the unified CLI:

```bash
dotfiles update
```

This safely updates the repo and reapplies the saved profile.

## Emergency Recovery Machine

Use this only when rebuilding from a real failure.

1. Restore or unlock an Age bootstrap identity that exists outside the Recovery
   Pack.
2. Retrieve the encrypted Recovery Pack from the NAS, restic target, or another
   approved encrypted backup location.
3. Decrypt only on a trusted machine.
4. Restore SSH keys only if needed to regain access.
5. Rejoin Tailscale manually with `sudo tailscale up` instead of restoring
   Tailscale machine state.
6. Rotate restored keys after recovery if the machine was temporary, borrowed, or
   otherwise untrusted.

## What Not To Do

- Do not use GitHub password authentication for Git pushes.
- Do not paste private keys into GitHub.
- Do not reuse one SSH private key on every laptop by default.
- Do not store private keys in Git.
- Do not copy `/var/lib/tailscale` between machines.
- Do not auto-login to GitHub, Tailscale, or Atuin from bootstrap.
