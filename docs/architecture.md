# Personal Platform Architecture

This document is the source of truth for the platform boundaries. It defines
where each class of data belongs and what should not cross those boundaries.

## System Map

```text
Git Repository
|
+-- Profiles
+-- Packages
+-- Stow Config
+-- Scripts
+-- Documentation

Vaultwarden
|
+-- Passwords
+-- API Keys
+-- MFA Seeds
+-- Recovery Codes

Recovery Pack
|
+-- SSH Keys
+-- Age Keys
+-- VPN Profiles
+-- WireGuard Configs
+-- Certificates
+-- Infrastructure Exports

Backup Targets
|
+-- NAS (Primary)
+-- Restic Repository
+-- Email Recovery Copy
+-- Optional Hetzner Storage Box

Sync Layer
|
+-- Tailscale
+-- Syncthing
+-- Atuin

Client Platforms
|
+-- Omarchy
+-- macOS
+-- Debian
+-- Ubuntu
```

## Design Principles

- Machines are disposable.
- Git is the source of truth for scripts, profiles, configuration intent, and documentation.
- Vaultwarden is the source of truth for interactive credentials.
- The Age-encrypted Recovery Pack is the source of truth for key material and infrastructure exports that must exist before services can be restored.
- NAS is the primary storage target for recovery artifacts.
- Restic is the secondary backup path.
- Hetzner Storage Box is optional and must not be required for the design to work.
- Email is not primary backup storage. It exists for reports, audit trail, and optional emergency recovery copy.

## Data Ownership

| Area | Owns | Must Not Own |
|------|------|--------------|
| Git | docs, inventory, package lists, profiles, scripts, stow config | secrets, private keys, recovery pack plaintext |
| Vaultwarden | passwords, API keys, MFA, recovery codes | SSH private keys, Age identity files, OS state |
| Recovery Pack | SSH keys, Age keys, VPN configs, WireGuard configs, certificates, infrastructure exports | passwords, MFA seeds, Tailscale machine state |
| NAS | encrypted recovery pack artifacts, reports, restic target or restic source data | unencrypted recovery pack contents |
| Restic | encrypted secondary backup | unencrypted secrets outside restic encryption |
| Email | status reports, optional encrypted emergency copy | plaintext secrets |

## Explicit Non-Goals

- Do not back up `/var/lib/tailscale`.
- Do not restore Tailscale internal machine state.
- Do not store Vaultwarden exports in Git.
- Do not store recovery pack plaintext on persistent disk.
- Do not implement Phase 3 sync setup as part of Phase 2.

## Tailscale Recovery Model

Tailscale machines are disposable. Recovery should be:

1. Restore Age identity.
2. Restore SSH keys.
3. Log in to Tailscale.
4. Rejoin the tailnet.

Do not copy or restore Tailscale internal databases.

## Phase Boundaries

Phase 1 is bootstrap safety and profile correctness.

Phase 2 is recovery design and, after separate approval, recovery implementation.

Phase 3 is sync and workstation polish, including Omarchy postinstall automation such as Tailscale, NetworkManager, Atuin, Syncthing, Firefox, and WezTerm installation.
