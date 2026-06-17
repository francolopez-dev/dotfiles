# Recovery Pack Specification

The Recovery Pack is an Age-encrypted archive containing the minimum non-password material needed to regain infrastructure access after a machine loss or disaster.

The Phase 2A generator is implemented in `scripts/generate-recovery-pack.sh`.

## Goals

- Capture critical key material and infrastructure exports.
- Keep plaintext only in temporary working storage.
- Encrypt before copying to NAS, Restic, explicitly enabled email emergency
  copy, or optional Hetzner.
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
  - Cloudflare zone exports
  - Tailscale ACL/config export, excluding machine state
  - router backup
  - firewall backup
  - Proxmox cluster config
  - Vaultwarden backup metadata, excluding plaintext vault exports
  - Restic repository info needed to locate and verify repositories

## Age Identity Bootstrap

Recovery must not depend on an Age identity that exists only inside the
Recovery Pack. At least one Age identity capable of decrypting the latest
Recovery Pack must exist outside the Recovery Pack at all times.

Primary Age identity options:

- Encrypted USB drive kept separate from the Recovery Pack.
- YubiKey resident key, when implemented.
- Printed recovery seed, only if the selected Age identity method supports it.

Secondary Age identity:

- Stored on NAS as a separately managed secret, not only inside the Recovery
  Pack artifact.

Recovery rule:

- The Recovery Pack may contain Age identities for restoring a full working
  environment, but it must never be the only place where a decrypting identity
  exists.

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
- Refuse to run unless at least one configured decrypting identity path exists
  outside the Recovery Pack, or dry-run mode explicitly skips that check.
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

## Fixed Paths

Default NAS destination:

```text
/storage/backups/recovery-pack/
```

The generator should allow this to be overridden by config or environment, but
the documented default path is fixed so automation and tests have a stable
target.

Default local Age identity directory:

```text
~/.config/age/
```

## Generation Model

Recovery Pack generation is config-file driven. The generator reads explicit
allow-lists from `config/recovery-pack.conf` and does not discover secret paths
automatically.
