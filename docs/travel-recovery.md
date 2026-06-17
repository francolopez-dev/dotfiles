# Travel Recovery

Travel recovery covers the case where the primary machine is unavailable while away from home.

## Goals

- Recover enough access to work safely from a temporary or replacement machine.
- Avoid carrying unnecessary plaintext secrets.
- Keep NAS as primary when reachable, with Restic/email/Hetzner as fallback paths.

## Before Travel

- Confirm Vaultwarden access from a second device.
- Confirm at least one Age identity is available through a safe path.
- Confirm latest encrypted Recovery Pack exists.
- Confirm NAS and Restic backups have recent successful reports.
- Confirm Tailscale login method works without the lost machine.
- Carry only encrypted recovery artifacts when needed.

## During Travel

1. Install or borrow a supported machine.
2. Clone the dotfiles repo.
3. Run bootstrap with a minimal or appropriate laptop profile.
4. Retrieve the encrypted Recovery Pack from the best available target:
   - NAS over VPN/Tailscale if available
   - Restic
   - encrypted email copy
   - optional Hetzner
5. Decrypt only what is needed.
6. Restore SSH and Age keys.
7. Log in to Tailscale; do not restore Tailscale state.
8. Restore VPN/WireGuard only if needed.

## Minimum Travel Recovery Set

- Age identity capable of decrypting the Recovery Pack.
- Vaultwarden access.
- SSH key for critical infrastructure.
- Tailscale login path.
- Current dotfiles repo.

## Safety Rules

- Do not decrypt the full Recovery Pack on an untrusted machine unless unavoidable.
- Delete plaintext staging directories after use.
- Prefer temporary access keys for borrowed hardware.
- Rotate keys after returning home if recovery happened on a machine you do not control.

## Not Included

Travel recovery does not attempt to clone a full workstation state. It restores access, not comfort.
