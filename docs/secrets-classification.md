# Secrets Classification

This document defines what belongs in Vaultwarden, the Recovery Pack, and Git.

## Tier 1: Vaultwarden

Vaultwarden stores interactive credentials and account recovery material:

- Passwords
- API keys
- MFA seeds
- Recovery codes
- Login notes needed to use accounts safely

Vaultwarden is the right place for secrets that are copied, pasted, scanned, or entered during human account recovery.

Do not store Vaultwarden database exports in Git. If an export is ever included in recovery workflows, it must be encrypted and treated as a separate high-risk artifact.

## Tier 2: Age-Encrypted Recovery Pack

The Recovery Pack stores key material and infrastructure files needed to regain operational access:

- SSH private and public keys
- Age identity files and recipient public keys
- WireGuard configs
- VPN profiles
- Certificates and private keys
- Infrastructure exports
- Small service bootstrap files that cannot be reconstructed from Git or Vaultwarden alone

The Recovery Pack is always encrypted with Age before leaving temporary working storage.

## Tier 3: Git Repository

Git stores reproducible intent and documentation:

- Configuration files
- Profiles
- Package groups
- Scripts
- Inventory
- Architecture docs
- Recovery procedures

Git must not contain private keys, plaintext secrets, recovery pack plaintext, `.age` identity files, VPN secrets, or service credentials.

## Exclusions

Do not include:

- `/var/lib/tailscale`
- Tailscale machine state
- Browser profile cookies
- Full home directory archives
- Package caches
- Generated logs containing secrets
- Unreviewed app data directories

## Classification Rule

If a file is needed to authenticate as a person to a service, it belongs in Vaultwarden.

If a file is needed to authenticate a machine, decrypt backups, connect to infrastructure, or bootstrap access before higher-level services are available, it belongs in the encrypted Recovery Pack.

If a file describes how the system should be rebuilt and contains no secret material, it belongs in Git.
