# Recovery Pack Usage

This document covers Phase 2 Recovery Pack generation, distribution, scheduled
automation, retention, and health checks.

## Config Setup

Recovery Pack contents are configured in:

```bash
config/recovery-pack.conf
```

The default config is safe by default and contains no active personal secret
paths. Add explicit allow-list entries before building a real artifact.

Supported category arrays:

- `AGE_IDENTITIES`
- `SSH_PATHS`
- `WIREGUARD_PATHS`
- `VPN_PATHS`
- `CERTIFICATE_PATHS`
- `INFRA_EXPORT_PATHS`

Matching `OPTIONAL_*` arrays are warn-only. Non-optional arrays are required
when entries are present.

Entry format:

```bash
"/absolute/path|classification|reason"
```

Bare paths are also accepted:

```bash
"$HOME/.ssh/id_ed25519"
```

Bare paths get a default classification and reason based on the category.

## NAS Target

The generator can copy the encrypted artifact and safe sidecars to the NAS
target when explicitly requested.

Default target:

```bash
RECOVERY_PACK_NAS_PATH="/storage/backups/recovery-pack/"
```

The target must already exist and be writable. The generator does not create
the NAS directory and does not copy plaintext Recovery Pack contents.

## Recipient Setup

Configure public Age recipients in `AGE_RECIPIENTS`:

```bash
AGE_RECIPIENTS=(
  "age1example..."
)
```

Configure at least one decrypting bootstrap identity outside the Recovery Pack:

```bash
AGE_BOOTSTRAP_IDENTITIES=(
  "$HOME/.config/age/keys.txt|age-bootstrap-identity|Decrypt latest Recovery Pack"
)
```

This prevents the circular failure case where the only decrypting identity is
inside the encrypted artifact.

## Dry Run

Dry-run validates configuration and prints the planned archive contents without
creating archives or encrypting anything:

```bash
./scripts/generate-recovery-pack.sh --dry-run
```

Use a test config:

```bash
./scripts/generate-recovery-pack.sh --dry-run --config tests/recovery-pack/.tmp/recovery-pack.test.conf
```

Dry-run output includes:

- configured recipients
- archive structure
- included files
- missing optional files
- missing required files
- NAS copy target and copy plan when `--copy-to-nas` is used
- Restic plan when `--restic` or `RECOVERY_PACK_RESTIC_ENABLED=1` is used
- email report plan when `--email` or `RECOVERY_PACK_EMAIL_ENABLED=1` is used
- Hetzner copy plan when `--hetzner` or `RECOVERY_PACK_HETZNER_ENABLED=1` is used

## Build

Build an encrypted local artifact:

```bash
./scripts/generate-recovery-pack.sh --output-dir /tmp/recovery-pack-output
```

Output format:

```text
recovery-pack-YYYY-MM-DD-HHMMSS.tar.gz.age
```

Safe sidecars are generated next to the encrypted artifact:

```text
recovery-pack-YYYY-MM-DD-HHMMSS.manifest.txt
recovery-pack-YYYY-MM-DD-HHMMSS.sha256
```

The script uses `mktemp`, writes plaintext only under the temporary workspace,
and cleans that workspace with a trap. It does not write plaintext into the
repository.

## NAS Copy

Copy the encrypted artifact and safe sidecars to the configured NAS target:

```bash
./scripts/generate-recovery-pack.sh --copy-to-nas --output-dir /tmp/recovery-pack-output
```

Override the target for a one-off run or test:

```bash
./scripts/generate-recovery-pack.sh --copy-to-nas --nas-dir /tmp/recovery-pack-nas-test
```

Dry-run the NAS copy path:

```bash
./scripts/generate-recovery-pack.sh --dry-run --copy-to-nas
```

NAS copy includes only:

- `recovery-pack-YYYY-MM-DD-HHMMSS.tar.gz.age`
- `recovery-pack-YYYY-MM-DD-HHMMSS.manifest.txt`
- `recovery-pack-YYYY-MM-DD-HHMMSS.sha256`

It does not copy plaintext staging directories, extracted archives, Restic
data, email reports, or Hetzner uploads.

## Restic Backup

Back up the encrypted artifact and sidecars to a Restic repository:

```bash
./scripts/generate-recovery-pack.sh --restic --output-dir /tmp/recovery-pack-output
```

Restic can also be enabled in `config/recovery-pack.conf` with
`RECOVERY_PACK_RESTIC_ENABLED=1`. The repository and password can come from
standard Restic environment variables or the Recovery Pack config overrides.

Current stabilization note: Restic is designed as a secondary backup path, but
the implementation currently treats a runtime `restic backup` failure as fatal.
Review this before final Phase 2 release.

## Email Report

Send a status report after generation:

```bash
./scripts/generate-recovery-pack.sh --email --output-dir /tmp/recovery-pack-output
```

Email reports include artifact metadata and target status. They must not include
plaintext secrets. Encrypted artifact attachments are disabled by default and
require `RECOVERY_PACK_EMAIL_ATTACH=1`.

## Optional Hetzner Copy

Copy the encrypted artifact and sidecars to a configured Hetzner Storage Box:

```bash
./scripts/generate-recovery-pack.sh --hetzner --output-dir /tmp/recovery-pack-output
```

Hetzner is optional and disabled by default. It copies only encrypted artifacts
and safe sidecars.

## Automation, Retention, and Health

The `recovery-pack` stow package provides:

```text
~/.config/systemd/user/recovery-pack.service
~/.config/systemd/user/recovery-pack.timer
```

Manual trigger:

```bash
systemctl --user start recovery-pack.service
```

Retention:

```bash
./scripts/recovery-pack-retention.sh --dry-run
./scripts/recovery-pack-retention.sh --keep 5
```

Health check:

```bash
./scripts/recovery-pack-health.sh
```

## Verify

Validate an encrypted artifact without restoring files onto the system:

```bash
./scripts/generate-recovery-pack.sh --verify /tmp/recovery-pack-output/recovery-pack-YYYY-MM-DD-HHMMSS.tar.gz.age
```

Verification:

- decrypts into a temporary workspace
- extracts the archive there
- checks required archive structure
- confirms `MANIFEST.txt` exists
- verifies `CHECKSUMS.sha256`
- removes temporary decrypted material on exit

## Tests

Run the dummy fixture test suite:

```bash
tests/recovery-pack/run-tests.sh
```

The tests generate a temporary Age identity and use only files under
`tests/recovery-pack/fixtures`. They do not read real user secrets. NAS copy
tests use a temporary directory under `tests/recovery-pack/.tmp`.
