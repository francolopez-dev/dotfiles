# Implementation Plan Tracking

## Phase 1 Status

Complete as of 2026-06-17 after the audit-blocker fixes documented in
`docs/phase1-audit.md`.

## Completed in Phase 1

- Renamed profiles to OS-explicit names.
- Rebuilt Omarchy profiles around device + purpose + OS:
  `desktop-personal-omarchy`, `desktop-work-omarchy`,
  `laptop-personal-omarchy`, and `laptop-work-omarchy`.
- Preserved a separate `work-macos` profile.
- Added `profiles/stow-os.map` for OS-aware stow filtering.
- Added safe per-package stow conflict handling with skip, backup, and adopt flows.
- Added `/dev/tty` first-run profile wizard with OS-filtered choices.
- Added `--first-time`, `--reconfigure`, and `--backup-conflicts` root bootstrap flags.
- Added selected-profile validation in `bootstrap.sh`.
- Added `scripts/validate-profiles.sh` for full profile validation.
- Added Lenovo work laptop notes.
- Fixed dry-run state mutation: dry-runs no longer write saved profile state or
  default log files.
- Fixed wizard cancellation: cancel exits without persisting `minimal`.
- Surfaced selected-profile validation errors during bootstrap.
- Strengthened profile validation for required array declarations and stow OS compatibility.
- Hardened stow conflict handling so uncertain conflict parsing skips safely.
- Changed remote bootstrap dirty-repo behavior to stop unless auto-stash is explicitly requested.
- Tightened Arch detection so generic Arch is not silently labeled Omarchy.
- Added saved-profile migration for old names such as `work-laptop`,
  `personal-laptop`, `domum-workstation`, and the interim Omarchy profile names.
- Added `networkmanager` and `tailscale` to the Omarchy desktop package set.
- Added skipped-conflict summary output for Stow packages.
- Added OS-aware service unit mapping so `tailscale` enables `tailscaled.service`
  on Omarchy/Arch.
- Documented and supported remote bootstrap configuration via `DOTFILES_PROFILE`,
  `DOTFILES_FIRST_TIME`, and `DOTFILES_BACKUP_CONFLICTS`.

## Validation Checkpoint

- `shellcheck -x bootstrap.sh scripts/*.sh`: PASS
- `scripts/validate-profiles.sh`: PASS
- `./bootstrap.sh --dry-run --profile minimal`: PASS
- `./bootstrap.sh --dry-run --profile laptop-work-omarchy`: PASS
- `./bootstrap.sh --dry-run --profile laptop-personal-omarchy`: PASS
- `./bootstrap.sh --dry-run --profile desktop-personal-omarchy`: PASS
- `./bootstrap.sh --dry-run --profile desktop-work-omarchy`: PASS
- `./bootstrap.sh --dry-run --profile personal-macos`: PASS
- `./bootstrap.sh --dry-run --profile work-macos`: PASS
- `OS_OVERRIDE=omarchy ./bootstrap.sh --dry-run --profile laptop-work-omarchy`: PASS
- Dry-run temporary-HOME state test: PASS, no profile file and no default log/home mutation.
- Wizard cancellation pseudo-terminal test: PASS, exit code 2 and no profile file.
- Non-interactive conflict test: PASS, conflict reported and skipped without backup.
- `--backup-conflicts` test: PASS, conflict backed up only when explicitly requested.
- Remote dirty-repo bootstrap test: PASS, stopped without auto-stashing.
- Saved profile migration tests: PASS for `work-laptop` and `domum-workstation`.
- Repeated run after migration: PASS, uses saved profile without wizard.
- `--first-time` wizard override: PASS, opens wizard even with a saved profile.
- Service mapping dry-run: PASS, `tailscale -> tailscaled.service`.
- Remote-style `bash -s --` argument forwarding: PASS.
- Environment variable profile and first-time forwarding: PASS.

## Remaining Work

- Phase 2B: recovery pack distribution mechanisms.
- Phase 2C: automation, scheduling, monitoring, and retention.
- Phase 3: sync setup, Atuin client config, and Omarchy desktop polish.

## Phase 2A Status

Complete as of 2026-06-17. Implemented a safe, config-driven Recovery Pack
generation framework that can run against dummy test fixtures without reading
real user secrets.

Completed in Phase 2A:

- Added `scripts/generate-recovery-pack.sh`.
- Added safe default config at `config/recovery-pack.conf`.
- Added usage documentation at `docs/recovery-pack-usage.md`.
- Added dummy fixture tests under `tests/recovery-pack/`.
- Implemented dry-run mode with config validation, planned input listing,
  missing optional path reporting, archive structure output, and recipient
  output.
- Implemented manifest generation with category, source path, archive path,
  classification, and reason.
- Implemented `CHECKSUMS.sha256` generation.
- Implemented archive creation and Age encryption.
- Implemented `--verify` restore validation without restoring files onto the
  system.
- Implemented temporary workspace cleanup via trap.
- Kept NAS, Restic, email, Hetzner, scheduling, monitoring, and retention out
  of scope.

Phase 2A validation:

- `shellcheck -x scripts/generate-recovery-pack.sh tests/recovery-pack/run-tests.sh`: PASS
- `tests/recovery-pack/run-tests.sh`: PASS
  - dry-run test
  - build test
  - verify test
  - cleanup test

## Phase 2 Planning Checkpoint

Created design documents first, then implemented only the Phase 2A local
generation framework.

- `docs/architecture.md`: platform boundaries and source-of-truth model.
- `docs/secrets-classification.md`: Tier 1 Vaultwarden, Tier 2 Recovery Pack, Tier 3 Git.
- `docs/recovery-pack-spec.md`: Recovery Pack contents, exclusions, archive layout, encryption expectations.
- `docs/backup-flow.md`: NAS primary, Restic secondary, email reporting, disabled-by-default encrypted email attachment, optional Hetzner.
- `docs/break-glass-recovery.md`: emergency recovery procedure.
- `docs/travel-recovery.md`: travel recovery procedure.

Design decisions captured:

- Do not back up `/var/lib/tailscale`.
- Do not restore Tailscale machine state.
- Tailscale recovery is login/rejoin based.
- Recovery Pack stores SSH, Age, WireGuard, VPN, certificates, and infrastructure exports.
- At least one Age bootstrap identity must exist outside the Recovery Pack at all times.
- Day-1 infrastructure exports are Cloudflare zones, Tailscale ACL/config export without machine state, router backup, firewall backup, Proxmox cluster config, Vaultwarden backup metadata, and Restic repository info.
- Vaultwarden stores passwords, API keys, MFA, and recovery codes.
- Git stores documentation, inventory, configuration, profiles, and scripts.
- NAS remains primary storage at `/storage/backups/recovery-pack/`; Restic is secondary; Hetzner is optional; email is reports/audit trail, with encrypted emergency attachments disabled by default.

## Phase 2 Scope Split

Phase 2A implements only Recovery Pack artifact generation:

- inventory collection
- manifest generation
- checksums
- temporary directory cleanup
- Age encryption
- dry-run mode
- restore test

Phase 2A does not implement:

- NAS copy
- Restic integration
- email reports
- Hetzner uploads

Phase 2B adds distribution mechanisms:

- NAS copy
- Restic integration
- email reports
- optional Hetzner uploads

Phase 2C adds operational automation:

- scheduling
- monitoring
- retention

## Known Issues

- Lenovo built-in Intel I226-V Ethernet may freeze intermittently; use USB Ethernet or Wi-Fi if it remains unstable.
- Stow `--adopt` intentionally mutates files in the repo. Always review `git diff` after using it.

## Next Prompt

Review the Phase 2 design docs: `docs/architecture.md`,
`docs/secrets-classification.md`, `docs/recovery-pack-spec.md`,
`docs/backup-flow.md`, `docs/break-glass-recovery.md`, and
`docs/travel-recovery.md`, plus `docs/recovery-pack-usage.md`. After review,
implement Phase 2B distribution in a separate session. Add NAS copy first, then
Restic integration, then email reports, then optional Hetzner upload. Preserve
the Phase 2A generator boundary: do not add scheduling, monitoring, or
retention until Phase 2C. Do not include Tailscale machine state.
