# Recovery Pack Usage

This document covers Phase 2A only: local Recovery Pack generation, dry-run,
and restore validation. It does not copy artifacts to NAS, Restic, email, or
Hetzner.

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

## Build

Build an encrypted local artifact:

```bash
./scripts/generate-recovery-pack.sh --output-dir /tmp/recovery-pack-output
```

Output format:

```text
recovery-pack-YYYY-MM-DD-HHMMSS.tar.gz.age
```

The script uses `mktemp`, writes plaintext only under the temporary workspace,
and cleans that workspace with a trap. It does not write plaintext into the
repository.

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
`tests/recovery-pack/fixtures`. They do not read real user secrets.
