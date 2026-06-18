# Finish the Unified `dotfiles` CLI — Remaining Work

## Context

A prior multi-session effort implemented almost all of the "Unified `dotfiles`
CLI" plan (`pasted-text-2026-06-18t01-34-22-txt-enchanted-kettle.md`), but ran
out of budget before finishing verification. This plan re-audits the repo,
records what is already done, and lists only the work that remains.

The original goal stands: one stable, discoverable command — `dotfiles` — with
subcommands, so day-to-day work never requires knowing script paths. `curl |
bash` remains the installer / first-machine / emergency-repair path.

## Audit — current state (2026-06-18)

Verified by reading the files and running read-only checks. **Already complete:**

- `scripts/update-repo.sh` — new internal helper holding the shared
  safe/stash/stash-rebase/reset git logic. Runnable standalone (`--mode`,
  `--confirm-reset`) and sourceable.
- `scripts/bootstrap.sh` — refactored to `source` `update-repo.sh` via
  `load_update_repo()`, with a three-way resolution (script dir → repo →
  curl `$UPDATE_REPO_URL` fallback for the piped path). No more duplicated git
  logic.
- `stow/scripts/bin/dotfiles` — full dispatcher: `help`, `version`, `update`
  (pull+apply, `--no-apply`, `--dry-run`, `--stash`, `--stash-rebase`,
  `--reset --confirm`), `bootstrap`, `status`, `doctor`, `profile`
  (show/select/reconfigure/validate), `recovery` (build/verify/health/
  retention), `sync` (status/setup/doctor). Includes read-only `_stow_status`,
  `_services_status`, `_sync_status` helpers and robust repo discovery
  (`DOTFILES_DIR` → symlink resolve → `$HOME/dotfiles`).
- Docs: `README.md`, `docs/extending.md`, `docs/implementation-plan.md`
  (Phase 3B block), `stow/scripts/README.md` all updated.

**Verification already passing:**

- `shellcheck -x bootstrap.sh scripts/*.sh stow/scripts/bin/dotfiles tests/*/run-tests.sh` → clean
- `tests/bootstrap-update/run-tests.sh` → 12 PASS
- `tests/recovery-pack/run-tests.sh` → 8 PASS
- `tests/stow-cleanup/run-tests.sh` → 2 PASS
- `scripts/validate-profiles.sh` → all 8 profiles PASS
- CLI smoke tests (`help`, `help update`, `version`, unknown→exit 2, `status`,
  `update --dry-run --no-apply`, `profile show`, `sync status`) → all pass
- Symlink resolution (invoke via a symlink with `DOTFILES_DIR` unset) → resolves repo
- `bootstrap --dry-run --profile minimal` → routes to root orchestrator

## Remaining work

### 1. Add `tests/cli/run-tests.sh` (Verification §6 — the main gap)

A focused dispatch test suite, following the existing harness convention used by
`tests/bootstrap-update/run-tests.sh` and `tests/recovery-pack/run-tests.sh`:

- `TEST_DIR`/`REPO_DIR` from `BASH_SOURCE`; `WORK_DIR="$TEST_DIR/.tmp"`;
  `fail()`/`pass()` helpers; clean up `.tmp` at the end.
- Run the dispatcher as `DOTFILES_DIR="$REPO_DIR" bash "$REPO_DIR/stow/scripts/bin/dotfiles" …`
  so it never depends on `~/dotfiles`.

Cases (each asserts exit code and/or output substring):
1. `help` → exit 0, output contains `Usage: dotfiles`.
2. `help update` → exit 0, output contains `dotfiles update —`.
3. `version` → exit 0, output matches `dotfiles <sha> @ <branch>`.
4. unknown command (`frobnicate`) → exit 2 **and** output contains the help
   banner (`Usage: dotfiles`).
5. `update --reset` without `--confirm` → non-zero exit (guards the destructive
   path); `update --reset --confirm --dry-run` → exit 0.
6. `bootstrap --dry-run --profile minimal` → exit 0, output contains
   `Personal Platform bootstrap` and `DRY-RUN` (proves routing to root
   orchestrator).
7. **No-mutation**: build a tiny temp repo (à la bootstrap-update harness) —
   `git init`, one commit, plus a `bootstrap.sh` stub and `scripts/lib.sh`
   (copied from the real repo) so `_validate_repo` passes — then run
   `DOTFILES_DIR=<tmp> dotfiles update --no-apply --dry-run`; assert exit 0 and
   that `git -C <tmp> rev-parse HEAD` and `git status --porcelain` are unchanged.
8. Symlink resolution: `ln -s` the dispatcher into a temp dir, run `version`
   with `DOTFILES_DIR` unset, assert it still reports the real `REPO_DIR`.

Make the file executable (`chmod +x`).

### 2. Repoint the recovery-pack systemd unit (Migration §6 — user-approved)

File: `stow/recovery-pack/.config/systemd/user/recovery-pack.service`.

Current:
```
ExecStart=%h/dotfiles/scripts/generate-recovery-pack.sh --copy-to-nas --restic --email --profile %H
```
Change to use the CLI by **absolute path** (systemd `--user` units do not load
the shell `PATH`, so `~/bin/dotfiles` must be spelled out):
```
ExecStart=%h/bin/dotfiles recovery build --copy-to-nas --restic --email --profile %H
```
This is behavior-preserving: `dotfiles recovery build <flags>` does
`exec bash "$SCRIPTS/generate-recovery-pack.sh" <flags>` (see
`stow/scripts/bin/dotfiles:457`), so the same flags reach the same script. It
does add a dependency: the `scripts` stow package must be stowed (creating
`~/bin/dotfiles`) on any machine that runs the timer — which is already the
norm. Check `recovery-pack.timer` needs no change (it only references the
service unit).

### 3. Update the Phase 3B validation note

File: `docs/implementation-plan.md` (Phase 3B Status block). Add
`tests/cli/run-tests.sh: PASS` to the validation list and note the
`recovery-pack.service` ExecStart now routes through `dotfiles recovery build`.

## Out of scope / guardrails

- No changes to Recovery Pack logic, NetworkManager, or any internal step
  script's path-callable contract (additive only).
- No standalone `dotfiles-*` commands.
- Do not alter the working git-update logic in `update-repo.sh` /
  `bootstrap.sh`; it is covered by the bootstrap-update suite.

## Critical files

- `tests/cli/run-tests.sh` — **new** (the deliverable).
- `stow/recovery-pack/.config/systemd/user/recovery-pack.service` — one-line ExecStart edit.
- `docs/implementation-plan.md` — Phase 3B validation note.
- Reuse: harness pattern from `tests/bootstrap-update/run-tests.sh`; dispatcher
  at `stow/scripts/bin/dotfiles`; `scripts/lib.sh` for the temp-repo stub.

## Verification (run from repo root)

1. `shellcheck -x bootstrap.sh scripts/*.sh stow/scripts/bin/dotfiles tests/*/run-tests.sh` → clean (now includes `tests/cli/run-tests.sh`).
2. `tests/cli/run-tests.sh` → all PASS.
3. Re-run the regression suites to confirm no breakage:
   `tests/bootstrap-update/run-tests.sh`, `tests/recovery-pack/run-tests.sh`,
   `tests/stow-cleanup/run-tests.sh`, `scripts/validate-profiles.sh` → all green.
4. Sanity-check the unit edit: `systemd-analyze verify` is not available for
   `%h`-templated user units offline, so instead confirm by inspection that the
   flags match and that `dotfiles recovery build --help`-style passthrough hits
   `generate-recovery-pack.sh` unchanged.
