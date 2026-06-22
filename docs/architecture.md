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
+-- Age Keys for environment restore
+-- VPN Profiles
+-- WireGuard Configs
+-- Certificates
+-- Infrastructure Exports

Age Bootstrap Identity
|
+-- Encrypted USB drive
+-- Future YubiKey resident key
+-- Optional printed recovery seed

Backup Targets
|
+-- NAS (Primary)
+-- Restic Repository
+-- Email Recovery Copy (Disabled by Default)
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
- At least one Age identity capable of decrypting the Recovery Pack must exist outside the Recovery Pack at all times.
- NAS is the primary storage target for recovery artifacts.
- Restic is the secondary backup path.
- Hetzner Storage Box is optional and must not be required for the design to work.
- Email is not primary backup storage. It exists for reports and audit trail. Encrypted emergency attachments are disabled by default and require explicit opt-in.

## Data Ownership

| Area | Owns | Must Not Own |
|------|------|--------------|
| Git | docs, inventory, package lists, profiles, scripts, stow config | secrets, private keys, recovery pack plaintext |
| Vaultwarden | passwords, API keys, MFA, recovery codes | SSH private keys, Age identity files, OS state |
| Recovery Pack | SSH keys, Age keys, VPN configs, WireGuard configs, certificates, infrastructure exports | passwords, MFA seeds, Tailscale machine state |
| Age bootstrap identity | one decrypting identity outside the Recovery Pack | broad secret archives, password vault exports |
| NAS | encrypted recovery pack artifacts, reports, restic target or restic source data | unencrypted recovery pack contents |
| Restic | encrypted secondary backup | unencrypted secrets outside restic encryption |
| Email | status reports, audit trail, explicitly enabled encrypted emergency copy | plaintext secrets, default backup target status |

## Explicit Non-Goals

- Do not back up `/var/lib/tailscale`.
- Do not restore Tailscale internal machine state.
- Do not store Vaultwarden exports in Git.
- Do not store recovery pack plaintext on persistent disk.
- Do not implement Phase 3 sync setup as part of Phase 2.

## Tailscale Recovery Model

Tailscale machines are disposable. Recovery should be:

1. Use the Age bootstrap identity to decrypt the Recovery Pack.
2. Restore SSH keys.
3. Restore additional Age identities if needed.
4. Log in to Tailscale.
5. Rejoin the tailnet.

Do not copy or restore Tailscale internal databases.

## Recovery Levels

Level 1 recovery covers a lost laptop. Required access:

- Vaultwarden.
- Age bootstrap identity.
- Dotfiles repository.

Level 2 recovery covers a lost laptop and phone. Required access:

- Recovery Pack.
- Email access.
- Age bootstrap identity.
- Dotfiles repository.

Level 3 recovery covers house or NAS destruction. Required access:

- Email emergency path, if explicitly enabled.
- Restic offsite path or optional Hetzner Storage Box.
- Age bootstrap identity stored away from the destroyed site.

## Phase Boundaries

Phase 1 is bootstrap safety and profile correctness.

Phase 2 is recovery design and, after separate approval, recovery implementation.

Phase 3 is sync and workstation polish, including Omarchy postinstall automation such as Tailscale, NetworkManager, Atuin, Syncthing, Firefox, and Ghostty terminal setup.
