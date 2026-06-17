# Recovery Pack Specification

The Recovery Pack is an Age-encrypted archive containing the minimum non-password material needed to regain infrastructure access after a machine loss or disaster.

This document is a specification only. It intentionally does not implement `generate-recovery-pack.sh`.

## Goals

- Capture critical key material and infrastructure exports.
- Keep plaintext only in temporary working storage.
- Encrypt before copying to NAS, Restic, email, or optional Hetzner.
- Make recovery testable and boring.
- Avoid backing up disposable machine state.

## Inputs

Candidate input classes:

- SSH:
  - `~/.ssh/id_*`
  - selected host keys if explicitly needed
  - SSH config fragments required for recovery
- Age:
  - Age identity files
  - Age recipient public keys
- VPN:
  - WireGuard configs
  - other VPN profiles
- Certificates:
  - TLS certificates
  - private keys
  - CA files
- Infrastructure exports:
  - service inventories
  - DNS/provider exports
  - router/firewall exports
  - small bootstrap files that cannot be recreated from Git

## Explicit Exclusions

Do not include:

- `/var/lib/tailscale`
- Tailscale machine state
- Vaultwarden plaintext exports by default
- browser profiles
- package caches
- full home directory backups
- unencrypted logs
- arbitrary `.config` directories

Tailscale recovery is login-based: restore keys, log in to Tailscale, rejoin the tailnet.

## Archive Layout

Proposed internal archive structure:

```text
recovery-pack/
|-- MANIFEST.txt
|-- CHECKSUMS.sha256
|-- metadata/
|   |-- created-at.txt
|   |-- hostname.txt
|   |-- profile.txt
|   `-- tool-versions.txt
|-- ssh/
|-- age/
|-- vpn/
|-- wireguard/
|-- certificates/
`-- infrastructure-exports/
```

`MANIFEST.txt` should list every included file, source path, destination path, classification, and reason for inclusion.

## Encryption

The pack should be encrypted with Age recipients configured outside the script, likely in a git-tracked public recipient list and local private identities outside Git.

Required behavior:

- Refuse to run without at least one recipient.
- Encrypt before copying to persistent targets.
- Never write plaintext pack contents into the repo.
- Use a temporary working directory and clean it on exit.
- Prefer tmpfs when available.

## Output Naming

Recommended artifact name:

```text
recovery-pack-YYYY-MM-DD-HHMMSS.tar.gz.age
```

Optional sidecar files:

```text
recovery-pack-YYYY-MM-DD-HHMMSS.manifest.txt
recovery-pack-YYYY-MM-DD-HHMMSS.sha256
```

Sidecars must not leak secret values. The manifest can include filenames and classifications, but not private key contents.

## Validation

Generation should validate:

- Age is installed.
- Recipients exist.
- Selected source paths exist or are explicitly optional.
- Plaintext temp directory is removed.
- Encrypted artifact exists and is non-empty.
- Checksum exists.

Recovery should validate:

- Artifact decrypts with at least one intended identity.
- Archive extracts.
- Manifest and checksums match.
- SSH and Age files have safe permissions after restore.

## Open Decisions Before Implementation

- Exact local path for Age identities.
- Exact NAS mount/path.
- Whether email emergency copy sends the full encrypted artifact or only reports by default.
- Which infrastructure exports are required on day one.
- Whether Recovery Pack generation should be interactive or config-file driven.
