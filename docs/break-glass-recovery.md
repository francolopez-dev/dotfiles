# Break-Glass Recovery

This is the emergency recovery procedure for losing a primary machine or needing to regain access from a clean install.

## Assumptions

- GitHub access or a local repo copy is available.
- At least one Age identity capable of decrypting the Recovery Pack is available.
- Vaultwarden access is available or can be restored through its own recovery path.
- The encrypted Recovery Pack exists on NAS, Restic, email, or optional Hetzner.

## Procedure

1. Install a supported OS: Omarchy, macOS, Debian, or Ubuntu.
2. Clone the dotfiles repo.
3. Run bootstrap with the correct profile.
4. Retrieve the encrypted Recovery Pack from NAS, Restic, email, or optional Hetzner.
5. Decrypt the Recovery Pack with Age.
6. Restore SSH keys.
7. Restore Age identities.
8. Restore VPN and WireGuard configs as needed.
9. Restore certificates as needed.
10. Log in to Tailscale and rejoin the tailnet.
11. Verify SSH access to critical hosts.
12. Verify Vaultwarden access.
13. Rotate any credentials that may have been exposed during the incident.

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

Age identity files should be readable only by the owner.

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
