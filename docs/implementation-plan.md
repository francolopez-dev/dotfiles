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

- Phase 2 stabilization: review Recovery Pack failure semantics, service path
  assumptions, and real-machine configuration before final release.
- Phase 3A: sync layer (Tailscale, Syncthing, Atuin).
- Phase 3A: Omarchy desktop enhancements (wallpapers, themes, Hyprland/Waybar/Rofi overrides).
- Phase 3B: Firefox sync strategy, VM backup strategy, Omarchy postinstall, developer workstation bootstrap.

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

## Phase 2B-1 Status

Complete as of 2026-06-17. Implemented explicit NAS copy for encrypted
Recovery Pack artifacts and safe sidecars only.

Completed in Phase 2B-1:

- Added `--copy-to-nas` to `scripts/generate-recovery-pack.sh`.
- Added `--nas-dir` override for tests and one-off runs.
- Added `RECOVERY_PACK_NAS_PATH` to `config/recovery-pack.conf`, defaulting to
  `/storage/backups/recovery-pack/`.
- Added manifest and encrypted-artifact checksum sidecars:
  - `recovery-pack-YYYY-MM-DD-HHMMSS.manifest.txt`
  - `recovery-pack-YYYY-MM-DD-HHMMSS.sha256`
- Validates that the NAS target already exists and is writable.
- Dry-run reports the NAS copy target and copy plan without creating archives
  or copying files.
- Copies only:
  - encrypted `.tar.gz.age` artifact
  - `.manifest.txt` sidecar
  - `.sha256` sidecar
- Kept Restic, email, Hetzner, scheduling, monitoring, and retention out of
  scope.

Phase 2B-1 validation:

- `shellcheck -x scripts/*.sh tests/recovery-pack/run-tests.sh`: PASS
- `tests/recovery-pack/run-tests.sh`: PASS
  - dry-run test
  - NAS dry-run test
  - NAS validation test
  - build test
  - verify test
  - NAS copy test
  - cleanup test

## Phase 2B-2 Status

Complete as of 2026-06-17. Implemented optional Restic secondary backup.

Completed in Phase 2B-2:

- Added `--restic` to `scripts/generate-recovery-pack.sh`.
- Added `RECOVERY_PACK_RESTIC_ENABLED`, `RECOVERY_PACK_RESTIC_REPOSITORY`,
  `RECOVERY_PACK_RESTIC_PASSWORD_FILE`, and `RECOVERY_PACK_RESTIC_TAG` to
  `config/recovery-pack.conf`.
- Restic is activated by `--restic` flag or `RECOVERY_PACK_RESTIC_ENABLED=1`.
- Uses standard Restic environment variables if config overrides are empty.
- Validates Restic availability, repository, and password before build.
- Stages encrypted artifact and sidecars in a temporary directory before
  `restic backup`.
- Dry-run reports Restic backup plan without running Restic.

Phase 2B-2 validation:

- `shellcheck -x scripts/*.sh tests/recovery-pack/run-tests.sh`: PASS
- `tests/recovery-pack/run-tests.sh`: PASS (restic tests require restic installed)
  - restic-dry-run
  - restic-validation
  - restic-backup

## Phase 2B-3 Status

Complete as of 2026-06-17. Implemented email reporting.

Completed in Phase 2B-3:

- Added `--email` to `scripts/generate-recovery-pack.sh`.
- Added `RECOVERY_PACK_EMAIL_ENABLED`, `RECOVERY_PACK_EMAIL_TO`,
  `RECOVERY_PACK_EMAIL_FROM`, and `RECOVERY_PACK_EMAIL_ATTACH` to
  `config/recovery-pack.conf`.
- Report includes: timestamp, hostname, profile, artifact name, size,
  checksum, NAS/Restic/Hetzner status, and warnings.
- No secrets in email body.
- Encrypted attachment disabled by default; requires explicit
  `RECOVERY_PACK_EMAIL_ATTACH=1`.
- Supports mail, sendmail, and msmtp.
- Email failure does not invalidate NAS/Restic success.

Phase 2B-3 validation:

- `shellcheck -x scripts/*.sh tests/recovery-pack/run-tests.sh`: PASS
- `tests/recovery-pack/run-tests.sh`: PASS
  - email-dry-run
  - email-build (uses mock mail command)

## Phase 2B-4 Status

Complete as of 2026-06-17. Implemented optional Hetzner Storage Box copy.

Completed in Phase 2B-4:

- Added `--hetzner` to `scripts/generate-recovery-pack.sh`.
- Added `RECOVERY_PACK_HETZNER_ENABLED`, `RECOVERY_PACK_HETZNER_TARGET`,
  and `RECOVERY_PACK_HETZNER_PORT` to `config/recovery-pack.conf`.
- Disabled by default. Requires explicit target configuration.
- Uses scp for encrypted artifacts and sidecars only.
- Failure warns and continues without breaking NAS/Restic success.

Phase 2B-4 validation:

- `shellcheck -x scripts/*.sh tests/recovery-pack/run-tests.sh`: PASS
- `tests/recovery-pack/run-tests.sh`: PASS
  - hetzner-validation

## Phase 2C Status

Complete as of 2026-06-17. Implemented automation, retention, and health.

Completed in Phase 2C:

- Added systemd user timer and service at
  `stow/recovery-pack/.config/systemd/user/recovery-pack.{service,timer}`.
- Timer runs weekly with randomized delay and persistent catch-up.
- Service runs full pipeline: `--copy-to-nas --restic --email`.
- Added `scripts/recovery-pack-retention.sh`:
  - Removes old NAS artifacts keeping N most recent sets (default 5).
  - Removes artifact, manifest sidecar, and checksum sidecar together.
  - `--dry-run` support.
- Added `scripts/recovery-pack-health.sh`:
  - Verifies NAS has at least one recent artifact.
  - Checks checksum sidecar consistency.
  - Validates artifact age against configurable max (default 14 days).
- Manual trigger: `systemctl --user start recovery-pack.service`.

Phase 2C validation:

- `shellcheck -x scripts/*.sh tests/recovery-pack/run-tests.sh`: PASS
- `tests/recovery-pack/run-tests.sh`: PASS (17 tests total)
  - retention-dry-run
  - retention-execute
  - health-pass
  - health-empty

## Phase 2 Design Checkpoint

Created design documents first, then implemented the Phase 2 Recovery Pack
pipeline in scoped increments.

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

Phase 2A implemented Recovery Pack artifact generation:

- inventory collection
- manifest generation
- checksums
- temporary directory cleanup
- Age encryption
- dry-run mode
- restore test

Phase 2B implemented distribution mechanisms:

- Phase 2B-1: NAS copy. Complete.
- Phase 2B-2: Restic integration. Complete.
- Phase 2B-3: email reports. Complete.
- Phase 2B-4: optional Hetzner uploads. Complete.

Phase 2C implemented operational automation:

- scheduling
- monitoring
- retention

Phase 3A skeleton files exist for review, but active profiles do not enable
Atuin, Syncthing, wallpapers, themes, Hyprland, Waybar, or Rofi overrides during
Phase 2 stabilization.

## Phase 2B-fix Status (remote bootstrap mode forwarding)

Complete as of 2026-06-17. Fixed the broken remote update-mode command.

Root cause: in `VAR=val curl … | bash`, the `VAR=val` prefix applies only to the
`curl` process; `bash` runs as a separate pipeline element and never inherits it.
So `DOTFILES_UPDATE_MODE=stash curl … | bash` always ran in `safe` mode. The
literal form cannot be fixed (shell semantics); it is documented as a known
limitation and guarded by a regression test.

Completed:

- Added `--update-mode`, `--update-mode=`, and `--confirm-reset` argument
  forwarding in `scripts/bootstrap.sh` (pipe-safe via `bash -s -- …`).
- Kept legacy `--auto-stash` and `DOTFILES_BOOTSTRAP_AUTO_STASH=1`; the legacy
  env fallback now only fires when no env or flag set a mode.
- Fixed every README example to the correct env-after-pipe form plus a flag form.
- Fixed in-script `block_update` suggested commands to env-after-pipe form.
- Added pipe-aware tests reproducing real `curl | bash` semantics.

Phase 2B-fix validation:

- `shellcheck -x bootstrap.sh scripts/*.sh tests/*/run-tests.sh`: PASS
- `tests/bootstrap-update/run-tests.sh`: PASS (12 tests)
  - flag-update-mode-stash, flag-update-mode-stash-rebase, flag-confirm-reset
  - env-after-pipe-stash, legacy-auto-stash
  - regression-env-before-pipe-is-safe

## Phase 3A Status (layered config + sync step)

Complete as of 2026-06-17.

Completed:

- Added three-tier stow model: `profiles/stow-base` (global) and
  `profiles/stow-os-base` (per-OS), merged with per-profile `STOW_PACKAGES` in
  `scripts/apply-stow.sh` (deduped, bash-3.2 portable), with the per-package
  `stow-os.map` gate unchanged.
- Slimmed all `profiles/*.conf` to apps + profile-only extras; shared dotfiles
  removed from every profile. `recovery-pack` kept where it resolves.
- Added optional `SYNC=()` to profiles; `STOW_PACKAGES`/`SYNC` are now optional.
- Added `scripts/setup-syncing.sh` (Tailscale/Syncthing/Atuin), idempotent and
  non-destructive, wired in as bootstrap step 7. Adding an agent = one `case`
  branch + `SYNC=()` entry.
- Updated `scripts/validate-profiles.sh`: optional `STOW_PACKAGES`, validates
  `stow-base`/`stow-os-base` references, recognizes `SYNC` agents.
- Added `docs/extending.md` cheatsheet with future-improvement notes.

Constraints honored: Recovery Pack logic untouched; NetworkManager behavior
untouched; sync logins remain manual with no credential storage.

Phase 3A validation:

- `shellcheck -x bootstrap.sh scripts/*.sh tests/*/run-tests.sh`: PASS
- `scripts/validate-profiles.sh`: PASS (base manifests + all 9 profiles)
- `tests/recovery-pack/run-tests.sh`: PASS (unchanged, green)
- `tests/stow-cleanup/run-tests.sh`: PASS
- Dry-run per profile: global base stows on all (incl. minimal), OS-base
  shortcuts stow only on the matching OS, no duplicate stow lines, step 7
  (setup-syncing) runs.

## Phase 3B Status (unified CLI)

Implemented as of 2026-06-18.

Completed:

- Added `stow/scripts/bin/dotfiles` as the single day-to-day CLI entrypoint.
- Added `scripts/update-repo.sh` as the shared internal implementation for
  safe, stash, stash-rebase, and confirmed reset update modes.
- Refactored `scripts/bootstrap.sh` to load and call the shared update helper
  instead of carrying a duplicate git-update implementation.
- Added `dotfiles update` as pull + apply by default, with `--no-apply`,
  `--dry-run`, `--stash`, `--stash-rebase`, and `--reset --confirm`.
- Added routing for `bootstrap`, `profile`, `recovery`, and `sync`
  subcommands while leaving existing scripts callable by path.
- Added read-only `status`, `doctor`, and `sync status` summaries for OS,
  profile, git, stow preview, services, and sync agents.
- Updated README and extending docs to make `dotfiles` the preferred surface
  and keep `curl | bash` framed as installer/recovery.
- Repointed `recovery-pack.service` `ExecStart` to route through
  `%h/bin/dotfiles recovery build` (absolute path; `--user` units do not load
  the shell `PATH`) instead of calling `generate-recovery-pack.sh` directly.
  Behavior-preserving: the same flags reach the same script.

Phase 3B validation:

- `shellcheck -x bootstrap.sh scripts/*.sh stow/scripts/bin/dotfiles tests/*/run-tests.sh`: PASS
- `tests/bootstrap-update/run-tests.sh`: PASS
- `tests/cli/run-tests.sh`: PASS
- `dotfiles help`, `dotfiles help update`, `dotfiles version`, `dotfiles status`,
  and `dotfiles update --dry-run --no-apply`: PASS

## Known Issues

- Lenovo built-in Intel I226-V Ethernet may freeze intermittently; use USB Ethernet or Wi-Fi if it remains unstable.
- Stow `--adopt` intentionally mutates files in the repo. Always review `git diff` after using it.

## Next Prompt

Stabilize and review Phase 2 before starting new Phase 3 work. Confirm the
Lenovo work laptop passes bootstrap with `laptop-work-omarchy`, decide Restic
failure semantics, decide the long-term systemd service path strategy, and
complete Recovery Pack Age bootstrap setup. After that, begin Phase 3A as a
separate change set.
