# Tailscale Trusted-Network Policy

This is an optional per-user controller for personal macOS and Omarchy devices.
It decides whether to run `tailscale up` or `tailscale down` from the current
local network. It is disabled by default.

## Enable

Create `~/.config/dotfiles/tailscale-networks.local`:

```bash
TAILSCALE_NETWORK_POLICY_ENABLED=true

TRUSTED_SSIDS=(
  "your-home-ssid"
)

TRUSTED_SUBNETS=(
  "198.51.100.0/24"
)

# Stronger wired validation, when confirmed:
TRUSTED_GATEWAYS=()
TRUSTED_DNS_SUFFIXES=()
TRUSTED_MARKER_HOSTS=()
```

Then install the scheduler:

```bash
dotfiles tailscale-policy install
```

## Matching

Precedence is deterministic:

1. Exact trusted SSID match means trusted.
2. Trusted subnet plus optional corroboration means trusted.
3. Configured subnet-only matches are allowed, but weak.
4. Everything else is untrusted.

SSID, gateway, BSSID, local DNS suffix, and marker-host values identify private
networks and belong in `tailscale-networks.local`, which is gitignored.

Subnet-only matching is weaker because many unrelated networks reuse common
private ranges such as `192.168.1.0/24`. Prefer adding a confirmed gateway,
DNS suffix, or LAN-only marker host for wired networks.

The policy ignores loopback, Tailscale `100.64.0.0/10`, link-local, Docker,
bridge, VM, and inactive/default-route-less networks.

## Commands

```bash
dotfiles tailscale-policy status --verbose
dotfiles tailscale-policy evaluate --dry-run
dotfiles tailscale-policy pause
dotfiles tailscale-policy pause 2h
dotfiles tailscale-policy resume
dotfiles tailscale-policy force-up
dotfiles tailscale-policy force-down
dotfiles tailscale-policy uninstall
```

Normal status hides SSIDs and other local identifiers. Use `--verbose` only
when you intentionally want to inspect them.

While paused, automatic evaluations do not run `tailscale up` or
`tailscale down`. Force commands are one-time manual actions; the next automatic
evaluation may change state unless the policy is paused.

## Recovery

If Tailscale does not reconnect, pause or uninstall the scheduler and connect
manually:

```bash
dotfiles tailscale-policy pause
tailscale up
```

Rollback removes only the scheduler:

```bash
dotfiles tailscale-policy uninstall
```

To disable the policy without removing scheduler files, set:

```bash
TAILSCALE_NETWORK_POLICY_ENABLED=false
```
