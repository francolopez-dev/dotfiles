# Implementation Plan Tracking

## Phase 1 Status

Complete as of 2026-06-17 after the audit-blocker fixes documented in
`docs/phase1-audit.md`.

## Completed in Phase 1

- Renamed profiles to OS-explicit names.
- Rebuilt `work-omarchy` for the Lenovo Omarchy work laptop.
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

## Validation Checkpoint

- `shellcheck -x bootstrap.sh scripts/*.sh`: PASS
- `scripts/validate-profiles.sh`: PASS
- `./bootstrap.sh --dry-run --profile minimal`: PASS
- `./bootstrap.sh --dry-run --profile work-omarchy`: PASS
- `./bootstrap.sh --dry-run --profile personal-macos`: PASS
- `OS_OVERRIDE=omarchy ./bootstrap.sh --dry-run --profile work-omarchy`: PASS
- Dry-run temporary-HOME state test: PASS, no profile file and no default log/home mutation.
- Wizard cancellation pseudo-terminal test: PASS, exit code 2 and no profile file.
- Non-interactive conflict test: PASS, conflict reported and skipped without backup.
- `--backup-conflicts` test: PASS, conflict backed up only when explicitly requested.
- Remote dirty-repo bootstrap test: PASS, stopped without auto-stashing.

## Remaining Work

- Phase 2: encrypted recovery pack generation and disaster-recovery docs.
- Phase 3: sync setup, Atuin client config, and Omarchy desktop polish.

## Known Issues

- Lenovo built-in Intel I226-V Ethernet may freeze intermittently; use USB Ethernet or Wi-Fi if it remains unstable.
- Stow `--adopt` intentionally mutates files in the repo. Always review `git diff` after using it.

## Next Prompt

Plan Phase 2 from `nimbalyst-local/plans/project-phase-plan-audit-humming-finch.md`.
Do not implement yet. Produce a detailed implementation plan for Vaultwarden strategy,
Age encryption strategy, Recovery Pack design, NAS storage, Restic integration, email
reporting, optional encrypted email attachment, optional Hetzner Storage Box support,
disaster recovery docs, travel recovery docs, and break-glass recovery docs. Preserve
the decided architecture: Vaultwarden stores credentials/MFA/recovery codes; the
Age-encrypted Recovery Pack stores SSH keys, Age keys, VPN/WireGuard configs,
certificates, and infrastructure exports; Git stores documentation, inventory,
configuration, profiles, and scripts. Primary storage is NAS; secondary is Restic;
Hetzner is optional; email is for reports, audit trail, and emergency recovery copy.
