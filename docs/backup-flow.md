# Backup Flow

This document defines the intended Phase 2 backup flow for the encrypted Recovery Pack.

## Storage Priority

1. NAS: primary storage target.
2. Restic: secondary encrypted backup path.
3. Email: audit trail, status reports, and optional encrypted emergency copy.
4. Hetzner Storage Box: optional offsite target.

The design must work when Hetzner is disabled.

## High-Level Flow

```text
collect approved inputs
  -> build plaintext staging directory in temporary storage
  -> write manifest and checksums
  -> create tar.gz
  -> Age-encrypt archive
  -> remove plaintext staging directory
  -> copy encrypted artifact to NAS
  -> include encrypted artifact in Restic backup
  -> send email report
  -> optionally attach encrypted artifact to email
  -> optionally copy to Hetzner Storage Box
```

## NAS Target

NAS is the primary destination for encrypted artifacts.

Expected behavior:

- Verify the NAS path exists before generation or fail with a clear error.
- Copy only encrypted artifacts and safe sidecars.
- Keep retention simple at first, such as monthly or last-N artifacts.
- Do not store plaintext staging data on NAS.

## Restic Integration

Restic is the secondary path.

Expected behavior:

- Back up encrypted recovery artifacts and safe sidecars.
- Use existing restic repository configuration from local environment or config.
- Do not require Hetzner for Restic to work.
- Report restic success or failure in email.

## Email Reporting

Email is not primary backup storage.

Default email should include:

- timestamp
- hostname
- profile
- artifact name
- artifact size
- checksum
- NAS copy status
- Restic status
- optional Hetzner status
- warnings and skipped optional paths

Email must not include plaintext secrets.

## Optional Encrypted Email Attachment

The encrypted `.age` artifact may be attached for emergency recovery if explicitly enabled.

Rules:

- Attachment is encrypted before email.
- Default can be report-only.
- Email attachment failures must not invalidate NAS/Restic success.
- Reports must clearly state whether an attachment was sent.

## Optional Hetzner Storage Box

Hetzner is an optional offsite target.

Rules:

- Disabled by default unless configured.
- Failure should be reported but should not break the core NAS + Restic flow.
- Copy only encrypted artifacts and safe sidecars.

## Failure Modes

Hard fail:

- No Age recipients.
- Encryption fails.
- Plaintext cleanup fails in a way that leaves files behind.
- NAS primary copy fails, unless explicitly running a test mode.

Warn and continue:

- Optional source path missing.
- Email report fails.
- Optional email attachment fails.
- Optional Hetzner copy fails.

## Implementation Notes

The future script should be Bash-only and conservative. Prefer explicit path lists and simple config files over discovery-heavy behavior.
