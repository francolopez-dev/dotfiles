# Task — Tailscale Trusted-Network Policy

Status: implemented
Scope: profile-lamac-macos, Omarchy workstations, shared global policy command

## Architecture

One shared Bash policy engine lives at
`~/.local/bin/dotfiles-tailscale-policy`. Platform triggers are thin:
macOS uses a per-user LaunchAgent; Omarchy uses a per-user systemd timer.

## Matching

Trusted SSID matches are strongest. Trusted subnet matches are supported for
wired networks, but subnet-only trust is explicitly weak because unrelated
private networks can reuse the same CIDR. The config supports stronger future
checks through gateways, DNS suffixes, and marker hosts.

## Security

The committed config is disabled and contains no real private network names.
Actual SSIDs, gateways, DNS suffixes, BSSIDs, and marker hosts belong in the
gitignored `~/.config/dotfiles/tailscale-networks.local` file. The recurring
policy does not use sudo, auth keys, ACL changes, or reauthentication flows.

## Manual Override

`dotfiles tailscale-policy pause [duration]` stops automatic up/down actions.
`resume` clears the pause. `force-up` and `force-down` are one-time actions.

## Validation

Mocked tests cover disabled config, trusted and untrusted SSIDs, subnet trust,
no network, idempotent states, dry-run, and pause/resume. Live validation must
be performed separately on each device because it changes network/Tailscale
state.

## Rollback

Run `dotfiles tailscale-policy uninstall`, then set
`TAILSCALE_NETWORK_POLICY_ENABLED=false` or remove the local override.
