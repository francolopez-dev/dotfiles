# Break-Glass Recovery

This is the emergency recovery procedure for losing a primary machine or needing to regain access from a clean install.

## Assumptions

- GitHub access or a local repo copy is available.
- At least one Age bootstrap identity capable of decrypting the Recovery Pack is available outside the Recovery Pack.
- Vaultwarden access is available or can be restored through its own recovery path.
- The encrypted Recovery Pack exists on NAS, Restic, explicitly enabled email emergency copy, or optional Hetzner.

## Procedure

1. Install a supported OS: Omarchy, macOS, Debian, or Ubuntu.
2. Clone the dotfiles repo.
3. Run bootstrap with the correct profile.
4. Retrieve the encrypted Recovery Pack from NAS, Restic, explicitly enabled
   email emergency copy, or optional Hetzner.
5. Retrieve the Age bootstrap identity from its out-of-band location.
6. Decrypt the Recovery Pack with Age.
7. Restore SSH keys.
8. Restore additional Age identities if needed.
9. Restore VPN and WireGuard configs as needed.
10. Restore certificates as needed.
11. Log in to Tailscale and rejoin the tailnet.
12. Verify SSH access to critical hosts.
13. Verify Vaultwarden access.
14. Rotate any credentials that may have been exposed during the incident.

## Borrowed Computer, No NAS, No VPN

Use this path when Franco has no laptop, no NAS access, no VPN, and only a
borrowed computer.

1. Use the borrowed computer only long enough to recover access. Prefer a live
   USB environment or private browser session if available.
2. Sign in to email using the emergency recovery method.
3. Retrieve the encrypted Recovery Pack from the explicitly enabled email
   emergency copy, Restic offsite path, or optional Hetzner target.
4. Retrieve the Age bootstrap identity from the encrypted USB drive, future
   YubiKey resident key, or other approved out-of-band path. Do not rely on the
   Recovery Pack for this identity.
5. Install Age if needed.
6. Decrypt the Recovery Pack into temporary storage only.
7. Restore the minimum SSH key or VPN/WireGuard config needed to reach a trusted
   machine or provision a replacement.
8. Clone the dotfiles repo on the replacement or trusted machine.
9. Run bootstrap with the minimal or appropriate laptop profile.
10. Rejoin Tailscale through normal login. Do not restore Tailscale machine
    state.
11. Delete all plaintext recovery material from the borrowed computer.
12. After returning to trusted hardware, rotate any keys exposed to the borrowed
    computer.

## Tailscale

Do not restore `/var/lib/tailscale` or Tailscale machine state.

Use:

```bash
sudo systemctl enable --now tailscaled
sudo tailscale up
```

Machines are disposable. Rejoining the tailnet is safer than restoring internal Tailscale state.

## SSH Restore Notes

After restoring SSH keys:

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_*
chmod 644 ~/.ssh/*.pub
```

Review `~/.ssh/config` and any local overrides before connecting.

## Age Restore Notes

Age identity files should be readable only by the owner. At least one decrypting
Age identity must remain outside the Recovery Pack at all times.

```bash
chmod 600 <age-identity-file>
```

Verify decryption before deleting temporary recovery media.

## Completion Criteria

Recovery is complete when:

- Dotfiles bootstrap completed.
- SSH access to critical hosts works.
- Age can decrypt the latest Recovery Pack.
- Tailscale is rejoined.
- Vaultwarden is accessible.
- Any incident-specific credential rotations are tracked.
