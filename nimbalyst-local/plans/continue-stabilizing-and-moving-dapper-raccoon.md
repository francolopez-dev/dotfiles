# Continue Stabilizing & Move to Phase 3 — Personal Platform

## Context

Lenovo validation surfaced a real defect: the documented remote command

```
DOTFILES_UPDATE_MODE=stash curl -fsSL .../scripts/bootstrap.sh | bash
```

reports `Update: safe` and refuses a dirty repo instead of stashing.

**Root cause (shell semantics, not a script logic bug):** in a pipeline,
`VAR=val curl … | bash`, the `VAR=val` prefix is applied **only to the `curl`
process**. `bash` runs as a separate pipeline element and never inherits it.
So `scripts/bootstrap.sh` (executing inside `bash`) reads
`${DOTFILES_UPDATE_MODE:-safe}` → `safe`. The literal command can therefore
**never** work as written. This affects *every* env-prefixed example in the
README (profile, first-time, backup-conflicts, update-mode, reset). The
existing `tests/bootstrap-update/run-tests.sh` never caught it because it
invokes the script directly with the env set on the *script* process
(`DOTFILES_UPDATE_MODE=… "$SCRIPT_UNDER_TEST"`), which is not how `curl | bash`
behaves.

**Decision (confirmed with user):**
- Remediation = **Both**: add `bash -s --` argument forwarding *and* fix docs to
  show the correct env placement.
- Phase 3 scope = **finish all phases to production**.

**Design north star (user guidance):** This is the one go-to script for setting
up every machine. Keep it **simple and user-friendly** — *not* over-engineered.
Adding a new app, a new service, or a new shortcut must be a one-place,
obvious edit. Capture anything fancy as "future improvement" notes rather than
building it now.

**Three-tier config model (the core architectural ask — kill duplication):**
| Tier | What | Scope | Lives in |
|------|------|-------|----------|
| Global base | terminal/shell config, aliases | **every** profile incl. `minimal`, every OS | `profiles/stow-base` → `stow/{shell,zsh,bash,git,ssh,tmux,scripts,atuin}` |
| OS base | keyboard shortcuts, desktop/WM config | **per OS**, regardless of profile | `profiles/stow-os-base` → omarchy: `hypr waybar rofi wallpapers themes`; macos: `aerospace borders` |
| Profile | apps to install (+ rare per-profile dotfiles) | per profile | `profiles/*.conf` `PACKAGE_GROUPS` (+ optional `STOW_PACKAGES` extras) |

Today every `profiles/*.conf` re-lists `shell zsh bash git ssh tmux …` — that is
the duplication to remove. After the refactor, profiles declare **apps only**;
shared dotfiles and per-OS shortcuts are resolved automatically.

Constraints (from task): do **not** change Recovery Pack logic; do **not**
change NetworkManager behavior.

---

## Part 1 — Fix remote bootstrap mode forwarding (Phase 2B finish)

### 1a. `scripts/bootstrap.sh` — add argument forwarding for update modes

Current arg loop (lines 20-25) only handles `--auto-stash`. Extend it so the
pipe-safe form works: `curl … | bash -s -- --update-mode stash`.

Add cases to the `while` loop:
- `--update-mode) UPDATE_MODE="$2"; shift 2 ;;` and `--update-mode=*)`
- `--confirm-reset) CONFIRM_RESET=1; shift ;;`
- keep `--auto-stash` (sets `UPDATE_MODE=stash`) for legacy.

Precedence rule to implement clearly (env is the documented primary path, CLI
flag overrides since it is explicit and pipe-safe):
1. Start `UPDATE_MODE` from `${DOTFILES_UPDATE_MODE:-safe}` and
   `CONFIRM_RESET` from `${DOTFILES_CONFIRM_RESET:-0}` (already done, lines
   16-17).
2. Legacy `DOTFILES_BOOTSTRAP_AUTO_STASH=1` fallback already handled (lines
   27-29) — keep, but make sure it only fires when neither env nor flag set
   stash/other mode.
3. CLI flags (`--update-mode`, `--confirm-reset`, `--auto-stash`) override env.

`validate_update_mode` (lines 39-48) already covers `safe|stash|stash-rebase|
reset` — no change needed; it will now also guard flag-supplied values.

### 1b. Fix docs in README + `docs/implementation-plan.md`

Replace every broken `VAR=… curl … | bash` example with a correct form.
Standardize on the **env-after-pipe** form as primary and add the flag form:

```
# env form (correct placement — after the pipe, on bash)
curl -fsSL .../scripts/bootstrap.sh | DOTFILES_UPDATE_MODE=stash bash

# flag form (also pipe-safe)
curl -fsSL .../scripts/bootstrap.sh | bash -s -- --update-mode stash
```

Apply to README.md lines ~46-48, 65, 71, 77, 83, 89 (profile, first-time,
backup, update-mode stash / stash-rebase / reset+confirm). Reset example:
`… | DOTFILES_UPDATE_MODE=reset DOTFILES_CONFIRM_RESET=1 bash` or
`… | bash -s -- --update-mode reset --confirm-reset`.

### 1c. Update in-script suggested commands

The `block_update` suggestion strings in `scripts/bootstrap.sh` (lines 191,
196, 209, 214, 242) currently print the broken `VAR=… curl … | bash` form.
Update them to the corrected env-after-pipe form so error output is
copy-pasteable.

### 1d. Tests — cover real pipe semantics

Extend `tests/bootstrap-update/run-tests.sh` with a remote-style runner that
**reproduces the pipeline behavior** rather than setting env on the script
process:

- New helper `run_bootstrap_piped` that does
  `DOTFILES_UPDATE_MODE=$mode cat "$SCRIPT_UNDER_TEST" | env REPO_DIR=… REPO_URL=… DOTFILES_BOOTSTRAP_SKIP_HANDOFF=1 bash -s -- <flags>`
  — i.e. env on the left of the pipe is deliberately **dropped**, mode passed
  via flags, mirroring `curl … | bash -s --`.
- New helper `run_bootstrap_env_after_pipe` that puts the env var on `bash`
  (the corrected documented form) to prove it is honored.
- New tests:
  - `flag-update-mode-stash` — `--update-mode stash` stashes/pops a dirty repo.
  - `flag-update-mode-stash-rebase` — rebases an ahead branch, restores dirty.
  - `flag-confirm-reset` — `--update-mode reset --confirm-reset` discards.
  - `env-after-pipe-stash` — `| DOTFILES_UPDATE_MODE=stash bash` honored.
  - `legacy-auto-stash` — `DOTFILES_BOOTSTRAP_AUTO_STASH=1` (env-after-pipe)
    still maps to stash.
  - `regression-env-before-pipe-is-safe` — assert that the *broken* form falls
    back to safe (documents the shell-semantics limitation so it can't silently
    regress).

Reuse existing `setup_remote` / `clone_local` / `remote_commit` helpers.

---

## Part 2 — Layered config model (kill duplication, make extension trivial)

This is the user's main architectural ask. Resolve the final stow list as
**global base + OS base + profile extras**, deduped, then apply the existing
per-package OS gate (`stow-os.map`). Profiles shrink to apps.

### 2a. Two tiny manifest files (one package per line, `#` comments allowed)
- `profiles/stow-base` — global dotfiles for every profile/OS:
  `shell zsh bash git ssh tmux scripts atuin`
- `profiles/stow-os-base` — per-OS shortcut/desktop dotfiles:
  ```
  omarchy: hypr waybar rofi wallpapers themes
  macos:   aerospace borders
  ```
  (Format mirrors the simple line parsing already used by `read_map`/
  `stow-os.map`; reuse that helper — do not invent a new parser.)

### 2b. `scripts/apply-stow.sh` — merge the tiers
After sourcing the profile, build the effective list:
`base (from stow-base) + os-base (matching $OS) + STOW_PACKAGES (profile)`,
dedupe preserving order, then run the existing loop unchanged (the per-package
`stow-os.map` gate + conflict handling stay exactly as-is). Add a small
`read_lines`/reuse-`read_map` helper; keep it ~15 lines, no new abstractions.

### 2c. Slim the profiles
`profiles/*.conf` drop the shared dotfiles from `STOW_PACKAGES`. Keep only:
- `PACKAGE_GROUPS=(…)` — apps (unchanged, already per-profile)
- `SERVICES=(…)` — unchanged
- `STOW_PACKAGES=(…)` — **optional**, only genuinely profile-specific dotfiles
  (most profiles → empty or omitted)
- `SYNC=(…)` — new, see Part 3
Example after: `laptop-work-omarchy.conf` → `PACKAGE_GROUPS=(common desktop work)`,
`SERVICES=(tailscale)`, `SYNC=(tailscale atuin)`, no `STOW_PACKAGES` needed
(shell/git/ssh/tmux now global; hypr/waybar/rofi now omarchy-base;
`recovery-pack` stays — keep it where it currently resolves, do not touch its
logic).

### 2d. `scripts/validate-profiles.sh`
- Treat `STOW_PACKAGES` as **optional** now (was required).
- Validate the new `stow-base` / `stow-os-base` reference real `stow/<pkg>` dirs.
- Recognize optional `SYNC` array (allowed: `tailscale syncthing atuin`).

---

## Part 3 — Phase 3A: `setup-syncing` step (simple + extensible)

Wire the parked sync step in. `bootstrap.sh` line 113 reserves step 7. Skeletons
exist: `stow/atuin`, `stow/syncthing`.

### 3a. New `scripts/setup-syncing.sh`
- Same shape as `enable-services.sh` (args `--profile --os`, honors `DRY_RUN`,
  uses `lib.sh`). Reads optional `SYNC=()`; empty → info + no-op.
- One small `case` per agent, **idempotent, non-destructive, no auto-login**:
  - `tailscale`: if not up, print `sudo tailscale up` hint (no NetworkManager).
  - `syncthing`: ensure `~/.config/syncthing` exists; service enable stays in
    `enable-services.sh`.
  - `atuin`: if installed & not logged in, print `atuin login && atuin sync`.
- **Adding a new sync agent = add one `case` branch + list it in `SYNC=()`.**
  Document that pattern in a header comment.

### 3b. Wire into `bootstrap.sh`
Add after `enable-services.sh`; remove the "not yet implemented" placeholder:
```
bash "$SCRIPTS/setup-syncing.sh" --profile "$PROFILE" --os "$OS"
```

---

## Part 4 — User-friendly docs + future-improvement notes

The whole point: future-me edits one place. Add a single concise
`docs/extending.md` (the "how do I add X" cheatsheet):
- **Add an app** → add to a `packages/<group>` list (+ profile's
  `PACKAGE_GROUPS` if new group).
- **Add a global alias / shell tweak** → edit `stow/shell` (or zsh/bash);
  applies everywhere automatically.
- **Add/change an OS keyboard shortcut** → edit `stow/hypr` (omarchy) /
  `stow/aerospace` (macos); applies to all that-OS profiles automatically.
- **Add a profile-only dotfile** → add the package to that profile's
  `STOW_PACKAGES`.
- **Add a sync agent** → new `case` in `setup-syncing.sh` + `SYNC=()`.
- **Add a service** → add to profile `SERVICES`; map units in
  `enable-services.sh` if non-standard.

Each section ≤ 5 lines. Also add a short **"Future improvements"** list at the
bottom (e.g. per-host overrides, secret-aware sync automation, Firefox sync,
VM/Omarchy postinstall) so we don't over-build now.

Update `docs/implementation-plan.md` with the Phase 2B-fix + Phase 3A status and
validation checkpoints.

### Phase 3 desktop polish (content only, low risk)
Populate parked skeletons as real config when ready: `stow/hypr/conf.d`,
`stow/waybar`, `stow/rofi`, `stow/wallpapers`, `stow/themes`. Pure stow content,
no orchestration changes. Anything needing real secrets stays a manual/doc step.

---

## Critical files
- `scripts/bootstrap.sh` — arg forwarding (1a), suggested-command strings (1c).
- `bootstrap.sh` — wire step 7 (3b).
- `tests/bootstrap-update/run-tests.sh` — pipe-aware tests (1d).
- `scripts/apply-stow.sh` — tier merge (2b).
- `scripts/setup-syncing.sh` — **new** (3a).
- `scripts/validate-profiles.sh` — optional STOW_PACKAGES + base/SYNC checks (2d).
- `profiles/stow-base`, `profiles/stow-os-base` — **new** manifests (2a).
- `profiles/*.conf` — slimmed; add `SYNC=()` (2c, 3a).
- `README.md`, `docs/extending.md` (**new**), `docs/implementation-plan.md`.
- `stow/{hypr,waybar,rofi,wallpapers,themes}/…` — Part 4 content.

## Verification

Run all from repo root:

1. `shellcheck -x bootstrap.sh scripts/*.sh tests/recovery-pack/run-tests.sh tests/stow-cleanup/run-tests.sh tests/bootstrap-update/run-tests.sh`
2. `scripts/validate-profiles.sh`
3. `tests/recovery-pack/run-tests.sh`  (must stay green — Recovery Pack untouched)
4. `tests/stow-cleanup/run-tests.sh`
5. `tests/bootstrap-update/run-tests.sh`  (now includes pipe-aware + flag + legacy cases)
6. `./bootstrap.sh --dry-run --profile laptop-work-omarchy` and `--profile minimal`
   — confirm: global base dotfiles stow on **both** (incl. minimal), omarchy-base
   shortcuts stow only on omarchy profiles, no duplicate stow lines, and step 7
   (setup-syncing) runs in dry-run. Repeat dry-run for each profile to confirm
   the slimmed configs resolve the same effective package set as before.
7. Manual remote-style dirty test (corrected form):
   1. append a temporary line to `README.md`
   2. `curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | DOTFILES_UPDATE_MODE=stash bash`
      *(and/or)* `curl … | bash -s -- --update-mode stash`
   3. confirm banner says `Update: stash`
   4. confirm dirty state is stashed → updated → popped (or clear conflict report)
   5. restore `README.md`
8. Spot-check legacy `DOTFILES_BOOTSTRAP_AUTO_STASH=1` (after pipe) → stash; and
   `--update-mode reset --confirm-reset` discards as expected.

## Out of scope / guardrails
- No changes to Recovery Pack logic or NetworkManager behavior.
- Sensitive logins (Tailscale/Atuin) remain manual; no credential storage.
- The literal `VAR=… curl … | bash` cannot be fixed; it is documented as a
  known limitation and guarded by a regression test.
