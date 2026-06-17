# Phase 1 Audit

Date: 2026-06-17

Scope: critical PR-style audit of the Phase 1 cleanup implementation against
`nimbalyst-local/plans/project-phase-plan-audit-humming-finch.md`.

Conclusion: Phase 1 was close but not complete when this audit was written. The
audit blockers below have now been addressed, and the validation checkpoint in
`docs/implementation-plan.md` records the passing checks. Phase 2 implementation
has not started.

## Resolution Update

- Resolved: `--dry-run` no longer writes saved profile state or a default log file.
- Resolved: wizard cancellation exits without persisting `minimal`.
- Resolved: root bootstrap now prints validation details instead of hiding them.
- Resolved: profile validation now requires `PACKAGE_GROUPS`, `STOW_PACKAGES`, and
  `SERVICES` to be arrays.
- Resolved: profile validation now checks stow package OS compatibility against
  `profiles/stow-os.map`.
- Resolved: stow conflict handling skips safely if a preview indicates conflict but
  paths cannot be parsed.
- Resolved: remote bootstrap refuses to update a dirty repo unless auto-stash is
  explicitly requested.
- Resolved: generic Arch is no longer silently labeled Omarchy; Omarchy markers or
  `DOTFILES_ASSUME_OMARCHY=1` are required.

## Findings

### High: `--dry-run` still persists profile state

Evidence:

- `bootstrap.sh` advertises `--dry-run` as "mutate nothing".
- `bootstrap.sh` always calls `scripts/select-profile.sh` the same way in dry-run and real runs.
- `scripts/select-profile.sh` always calls `persist "$selected"` at the end.
- Verified with a temporary HOME: `./bootstrap.sh --dry-run --profile minimal` created
  `~/.config/dotfiles/profile` containing `minimal`.

Risk:

- A preview run can silently change the machine's saved profile.
- On a first-run Omarchy work laptop, a failed/non-interactive dry run can persist `minimal`,
  causing later real runs to skip the wizard and use the wrong profile.

Recommendation:

- Add a `--no-persist` or `--dry-run` mode to `select-profile.sh`.
- In root `bootstrap.sh`, pass that mode whenever `DRY_RUN=1`.
- Persist explicit `--profile` only on real runs, or document and separate a deliberate
  `--save-profile` action.

Proposed fix:

- `select-profile.sh --dry-run` should choose and print the profile but never write
  `~/.config/dotfiles/profile`.
- Wizard confirmation text should say whether the selection will be saved.

### Medium: selected-profile validation errors are hidden by root bootstrap

Evidence:

- `bootstrap.sh` runs `validate-profiles.sh --profile "$PROFILE" >/dev/null`.
- If validation fails, the user only sees `Profile validation failed: <profile>`, not the
  missing package group, stow package, or service.

Risk:

- The new validator can catch useful configuration errors, but the normal bootstrap flow
  suppresses the actionable part.

Recommendation:

- Let validator output through, or capture it and print it on failure.

Proposed fix:

- Replace the redirected command with a visible validation step:
  `bash "$SCRIPTS/validate-profiles.sh" --profile "$PROFILE" || die ...`.

### Medium: profile validation does not actually assert arrays are well-formed

Evidence:

- The plan requires arrays to be well-formed.
- `validate-profiles.sh` sources profiles and then checks directory existence and known
  services, but does not verify that `PACKAGE_GROUPS`, `STOW_PACKAGES`, and `SERVICES`
  are arrays rather than scalars.
- It temporarily disables nounset for all loops, which can hide some malformed state.

Risk:

- A malformed profile may pass or fail with confusing output.
- Future profile edits could accidentally use scalar syntax and not get a clear diagnostic.

Recommendation:

- Use `declare -p NAME` and assert the declaration starts with `declare -a` or `declare -ax`.
- Report "missing array" or "not an array" explicitly.

Proposed fix:

- Add a helper such as `require_array PROFILE VAR_NAME`.

### Medium: stow conflict parsing remains format-fragile

Evidence:

- `apply-stow.sh` parses human-oriented Stow output with string patterns.
- One actual GNU Stow message format already required a follow-up parser adjustment:
  `cannot stow ... over existing target ... since ...`.
- Other Stow versions or conflict classes may produce different wording.

Risk:

- A conflict can be missed and fall through to a real `stow`, resulting in the older
  vague `stow reported issues` behavior.
- Backup and adopt decisions depend on correct path extraction.

Recommendation:

- Keep the current parser, but add a regression test fixture for known Stow conflict
  output forms.
- Treat any failed preview that contains "WARNING! stowing ... would cause conflicts"
  but yields no parsed paths as a hard skip with the full preview output.

Proposed fix:

- Have `stow_preview` return both output and status.
- If preview output indicates conflicts and `conflicts_for_pkg` extracts no paths,
  skip the package and print the full preview instead of attempting a real stow.

### Medium: remote bootstrap still has a broad auto-stash/update behavior

Evidence:

- `scripts/bootstrap.sh` stashes all local changes, fetches, checks out `main`, pulls,
  and then pops the stash.

Risk:

- This can surprise users with local work in the dotfiles repo.
- If `stash pop` conflicts, the remote bootstrap leaves the repo in a conflict state
  before the root bootstrap can run.

Recommendation:

- This predates Phase 1 and is not a blocker for the profile model, but it should be
  documented as a remote-bootstrap risk.
- For a safer future change, prompt via `/dev/tty` before stashing when interactive,
  and fail closed when non-interactive unless an explicit `--auto-stash` flag is used.

Proposed fix:

- Add a remote-bootstrap safety section to README.
- Consider replacing auto-stash with clear stop-and-instruct behavior.

### Medium: OS detection treats all Arch-like systems as `omarchy`

Evidence:

- `detect-os.sh` maps `ID=arch` or `ID_LIKE=*arch*` to `omarchy`.
- Remote bootstrap comments say supported target is `omarchy(arch)`.

Risk:

- A plain Arch or other Arch-derived machine could be offered Omarchy desktop profiles
  and package assumptions even if it is not Omarchy.

Recommendation:

- Decide whether `omarchy` means "any Arch/Hyprland target" or the Omarchy distro specifically.
- If it means true Omarchy, detect Omarchy-specific markers and otherwise fail or call it `arch`.

Proposed fix:

- Rename OS id to `arch` if generic Arch support is intended, or tighten detection and docs.

### Medium: package group model still mixes desktop role with OS-specific GUI packages

Evidence:

- The plan explicitly chose to keep one `desktop` group.
- `work-omarchy` and `work-macos` both use `PACKAGE_GROUPS=(common desktop work)`.
- OS correctness relies on per-manager package files and stow OS filtering.

Risk:

- The design is acceptable for Phase 1, but future additions can easily leak a macOS-only
  cask or Omarchy-only package into a shared group without tests.

Recommendation:

- Keep the current model for now, but add validation that every profile/package group
  combination has an expected per-manager file.
- Add a simple profile matrix test that runs dry-run collection for all profiles under
  their intended OS ids.

Proposed fix:

- Add a `scripts/test-profile-matrix.sh` or extend `validate-profiles.sh --matrix`.

### Low: wizard choice labels are profile names, not role-first prompts

Evidence:

- The plan says the wizard asks a single device-role question and maps to a profile.
- Current wizard displays profile names directly, e.g. `work-omarchy - Omarchy work laptop`.

Risk:

- This is workable for the repo owner, but less friendly on a fresh machine.

Recommendation:

- Change wizard labels to role names, with profile names as secondary detail.

Proposed fix:

- For Omarchy: `Desktop workstation`, `Work laptop`, `Minimal`.

### Low: wizard cancellation persists `minimal`

Evidence:

- If a user answers "no" to confirmation, `run_wizard` prints `minimal`.
- The caller always persists the selected value.

Risk:

- A canceled setup is treated as an affirmative minimal selection.

Recommendation:

- Either exit non-zero on cancellation or ask a second confirmation before saving `minimal`.

Proposed fix:

- Return a distinct cancellation status and have root bootstrap stop.

### Low: `is_interactive` is clever and should be simplified

Evidence:

- `is_interactive` tests `/dev/tty` by opening it for input and output with shell redirections.

Risk:

- It works in current tests, but the helper is not obvious and can be misread as writing
  to the terminal.

Recommendation:

- Prefer a clearer helper that opens `/dev/tty` once or uses a tiny `read -t 0 </dev/tty`
  style check where portable.

Proposed fix:

- Keep behavior, add a short comment explaining why `-t 0` is insufficient under
  `curl | bash`.

### Low: docs already call Phase 1 "done"

Evidence:

- README Roadmap says `Phase 1 (done)`.
- `docs/implementation-plan.md` lists Phase 1 as completed.

Risk:

- This overstates the implementation state while unresolved audit findings remain.

Recommendation:

- Do not mark Phase 1 complete until the high and medium findings are fixed or explicitly
  accepted.

Proposed fix:

- After fixes, update `docs/implementation-plan.md` with audit resolution and then mark
  Phase 1 complete.

## Hidden Assumption Search

Searched for:

- `work-laptop`
- `personal-laptop`
- `macos`
- `aerospace`
- `borders`

Results:

- Active profiles and scripts no longer reference old profile names `work-laptop` or
  `personal-laptop`.
- Old names remain only in older local plan documents under `nimbalyst-local/plans/`.
- `aerospace` and `borders` remain intentionally in macOS profiles, macOS package lists,
  stow packages, README, `profiles/stow-os.map`, and validator known services.
- The current active model no longer assumes "work laptop = macOS"; it preserves
  `work-macos` as an explicit separate option.

## Lenovo Omarchy Notes Review

Current notes in `docs/work-laptop-lenovo.md` are sufficient for Phase 1:

- They identify the Lenovo work laptop target profile as `work-omarchy`.
- They document Intel I226-V Ethernet instability.
- They document stable Wi-Fi in testing.
- They document USB Ethernet as reliable.
- They explicitly avoid driver/kernel automation.

Recommendation:

- Keep this documentation-only approach. Do not add driver workarounds until there is
  repeatable evidence, kernel logs, and a known fix.
- Optional documentation improvement: record hardware details as observed context:
  Lenovo, Intel Core Ultra 9, RTX 5080, Intel I226-V Ethernet, Intel WiFi 7.

## Phase 1 Completion Checklist

### Bootstrap flow

Status: Partially verified.

- Verified `./bootstrap.sh --dry-run --profile minimal` runs through detect, profile,
  validation, package preview, stow preview, services, and completion.
- Not complete because the same dry run persisted profile state.

### First-time setup flow

Status: Partially verified.

- Verified non-interactive fallback persists `minimal` when no tty is available.
- Interactive `/dev/tty` wizard was not fully tested in this audit environment.
- Risk: cancellation persists `minimal`; dry-run also persists.

### Saved-profile flow

Status: Verified at script level.

- With a temporary HOME, `select-profile.sh --profile work-omarchy` persisted the profile.
- A second `select-profile.sh --os omarchy` reused the saved profile without prompting.
- Root bootstrap saved-profile behavior was not separately tested with a real tty.

### Remote bootstrap flow

Status: Static-reviewed, not live-tested.

- Verified `scripts/bootstrap.sh` forwards arguments to root bootstrap.
- Not live-tested because it would clone/update from GitHub `main`, while the Phase 1
  implementation is currently local and uncommitted.
- Risk: auto-stash/update behavior can surprise users with local changes.

### OS-aware stow filtering

Status: Verified.

- `OS_OVERRIDE=omarchy ./bootstrap.sh --dry-run --profile work-macos` skipped
  `aerospace` and `borders`.
- `OS_OVERRIDE=macos ./bootstrap.sh --dry-run --profile work-omarchy` skipped
  `hypr`, `waybar`, and `rofi`.
- `personal-macos` kept `aerospace` and `borders` on macOS.
- `work-omarchy` kept `hypr`, `waybar`, and `rofi` on Omarchy.

### Package group logic

Status: Partially verified.

- Verified dry-run package flows for `minimal`, `personal-macos`, `work-omarchy`,
  `server-debian`, and `server-ubuntu`.
- Did not install packages for real.
- Did not validate every profile/OS matrix combination beyond declared intended profiles
  and mismatch stow filtering checks.

### Profile validation

Status: Partially verified.

- `scripts/validate-profiles.sh` passes for all current profiles.
- `shellcheck -x bootstrap.sh scripts/*.sh` passes.
- Validation does not yet prove array well-formedness and root bootstrap hides validation
  details on failure.

### Backup-conflict workflow

Status: Partially verified.

- Non-interactive conflict skip was verified with a temporary HOME and preserved the
  conflicting file.
- `--backup-conflicts` was previously verified with a temporary HOME: conflicting
  `btop.conf` moved under `.dotfiles-backup/<timestamp>/` and package was stowed.
- Interactive `[b]ackup` prompt was not fully tested in this audit environment.

### Omarchy workflow

Status: Dry-run verified.

- `OS_OVERRIDE=omarchy ./bootstrap.sh --dry-run --profile work-omarchy` selected pacman,
  loaded `common desktop work`, previewed Omarchy stow packages, and reached completion.
- Not tested on actual Lenovo hardware in this audit.

### macOS workflow

Status: Dry-run verified on the current macOS machine.

- `./bootstrap.sh --dry-run --profile personal-macos` selected brew, loaded
  `common desktop personal`, kept `aerospace` and `borders`, and reached completion.
- Real package install/service start was not performed.

### Debian workflow

Status: Dry-run verified with OS override.

- `OS_OVERRIDE=debian ./bootstrap.sh --dry-run --profile server-debian` selected apt,
  loaded `common server`, previewed stow packages, and reached completion.
- Not tested on an actual Debian host.

### Ubuntu workflow

Status: Dry-run verified with OS override.

- `OS_OVERRIDE=ubuntu ./bootstrap.sh --dry-run --profile server-ubuntu` selected apt,
  loaded `common server work`, previewed stow packages, and reached completion.
- Not tested on an actual Ubuntu host.

## Recommended Fix Order

1. Fix dry-run persistence in `select-profile.sh` and `bootstrap.sh`.
2. Let selected-profile validation details print in root bootstrap.
3. Strengthen `validate-profiles.sh` to assert array declarations.
4. Harden stow conflict handling for unparsed conflict output.
5. Decide whether generic Arch equals Omarchy; update OS naming/detection/docs accordingly.
6. Improve wizard cancellation behavior and role-first labels.
7. Add a profile matrix verification command.
8. Update `docs/implementation-plan.md` and README only after the above are fixed or
   explicitly accepted.

## Phase 2 Status

Phase 2 implementation planning is intentionally deferred. The user requested Phase 2
planning only if Phase 1 is truly complete. This audit found unresolved Phase 1 issues.
