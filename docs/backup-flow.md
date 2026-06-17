# Backup Flow

This document defines the intended Phase 2 backup flow for the encrypted Recovery Pack.

## Storage Priority

1. NAS: primary storage target.
2. Restic: secondary encrypted backup path.
3. Email: audit trail and status reports. Encrypted emergency copy is disabled by default.
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
  -> attach encrypted artifact to email only when explicitly enabled
  -> optionally copy to Hetzner Storage Box
```

## NAS Target

NAS is the primary destination for encrypted artifacts.

Default path:

```text
/storage/backups/recovery-pack/
```

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

## Disabled-by-Default Encrypted Email Attachment

The encrypted `.age` artifact may be attached for emergency recovery only if explicitly enabled.

Rules:

- Attachment is encrypted before email.
- Default is report-only.
- Enabling attachments makes email a backup target and must be an intentional
  configuration choice.
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
- No configured Age bootstrap identity outside the Recovery Pack, unless explicitly running dry-run mode.
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
