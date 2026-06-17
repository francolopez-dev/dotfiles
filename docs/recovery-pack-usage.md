# Recovery Pack Usage

This document covers Phase 2A local Recovery Pack generation and Phase 2B-1
NAS copy. It does not implement Restic, email, Hetzner, scheduling, monitoring,
or retention.

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

Phase 2B-1 can copy the encrypted artifact and safe sidecars to the NAS target
when explicitly requested.

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
