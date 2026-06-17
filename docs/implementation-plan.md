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

- Phase 2: encrypted recovery pack implementation after design-doc review.
- Phase 3: sync setup, Atuin client config, and Omarchy desktop polish.

## Phase 2 Planning Checkpoint

Created design documents only. No recovery scripts have been implemented.

- `docs/architecture.md`: platform boundaries and source-of-truth model.
- `docs/secrets-classification.md`: Tier 1 Vaultwarden, Tier 2 Recovery Pack, Tier 3 Git.
- `docs/recovery-pack-spec.md`: Recovery Pack contents, exclusions, archive layout, encryption expectations.
- `docs/backup-flow.md`: NAS primary, Restic secondary, email reporting, optional encrypted email attachment, optional Hetzner.
- `docs/break-glass-recovery.md`: emergency recovery procedure.
- `docs/travel-recovery.md`: travel recovery procedure.

Design decisions captured:

- Do not back up `/var/lib/tailscale`.
- Do not restore Tailscale machine state.
- Tailscale recovery is login/rejoin based.
- Recovery Pack stores SSH, Age, WireGuard, VPN, certificates, and infrastructure exports.
- Vaultwarden stores passwords, API keys, MFA, and recovery codes.
- Git stores documentation, inventory, configuration, profiles, and scripts.
- NAS remains primary storage; Restic is secondary; Hetzner is optional; email is reports/audit trail/emergency encrypted copy.

## Known Issues

- Lenovo built-in Intel I226-V Ethernet may freeze intermittently; use USB Ethernet or Wi-Fi if it remains unstable.
- Stow `--adopt` intentionally mutates files in the repo. Always review `git diff` after using it.

## Next Prompt

Review the Phase 2 design docs: `docs/architecture.md`,
`docs/secrets-classification.md`, `docs/recovery-pack-spec.md`,
`docs/backup-flow.md`, `docs/break-glass-recovery.md`, and
`docs/travel-recovery.md`. After review, implement Phase 2 recovery tooling in
a separate session. Start with `scripts/generate-recovery-pack.sh`, but preserve
the documented architecture and exclusions. Do not include Tailscale machine
state.
