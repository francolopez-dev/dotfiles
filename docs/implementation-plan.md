# Implementation Plan Tracking

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

## Remaining Work

- Phase 2: encrypted recovery pack generation and disaster-recovery docs.
- Phase 3: sync setup, Atuin client config, and Omarchy desktop polish.

## Known Issues

- Lenovo built-in Intel I226-V Ethernet may freeze intermittently; use USB Ethernet or Wi-Fi if it remains unstable.
- Stow `--adopt` intentionally mutates files in the repo. Always review `git diff` after using it.

## Next Prompt

Implement Phase 2 from `nimbalyst-local/plans/project-phase-plan-audit-humming-finch.md`: recovery pack generation and disaster-recovery documentation. Do not start Phase 3.
