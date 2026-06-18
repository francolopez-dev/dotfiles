# Unified `dotfiles` CLI — Audit, Design & Migration Plan

## Context

Today the platform is driven by a handful of scripts the user must remember and
invoke by path (`./bootstrap.sh`, `scripts/generate-recovery-pack.sh`,
`scripts/recovery-pack-health.sh`, …). The user wants to evolve toward **one
stable, discoverable command** — `dotfiles` — with subcommands, so day-to-day
work never requires knowing script names or repo file locations.

`curl … | bash` stays, but is reframed as the **installer / first-machine /
emergency-repair** path only. After install, the preferred surface is
`dotfiles update`, `dotfiles status`, `dotfiles doctor`, etc.

This document is the **audit + design** the user asked to review **before any
implementation**. Decisions already confirmed by the user:
- `dotfiles update` = **pull + apply** in one step (with `--no-apply` to pull only).
- **No** standalone `dotfiles-*` commands or compat shims — only `dotfiles`.
- The remote `curl | bash` entrypoint and root `./bootstrap.sh` **keep working**
  as internal/recovery paths; `dotfiles bootstrap` becomes the front door.

---

## 1. Audit — current command surface

Source: full repo inventory (see `scripts/`, `bootstrap.sh`, `stow/scripts/`).

### User-facing today (run by path)
| Script | Purpose | Becomes |
|--------|---------|---------|
| `scripts/bootstrap.sh` (remote `curl\|bash`) | install deps, clone/update repo, hand off | **kept** (installer/recovery) |
| root `./bootstrap.sh` | orchestrator: detect→profile→install→stow→services→sync | internal orchestrator behind `dotfiles bootstrap` |
| `scripts/generate-recovery-pack.sh` | build/verify encrypted recovery pack | `dotfiles recovery build` / `verify` |
| `scripts/recovery-pack-health.sh` | NAS artifact health | `dotfiles recovery health` |
| `scripts/recovery-pack-retention.sh` | prune old NAS artifacts | `dotfiles recovery retention` |

### Internal-only (sourced or called by orchestrator — stay internal)
`scripts/lib.sh`, `detect-os.sh`, `select-profile.sh`, `install-packages.sh`,
`apply-stow.sh`, `enable-services.sh`, `setup-syncing.sh`,
`validate-profiles.sh`, `cleanup-stale-stow-links.sh`.
These keep their current `--profile/--os/...` contracts and are **not** exposed
directly; `dotfiles` subcommands wrap them.

### Naming-collision check
No collisions. There are **no existing** `dotfiles`, `dotfiles-update`,
`dotfiles-doctor`, `dotfiles-status`, etc. `stow/scripts/bin/` is an empty
placeholder (`.gitkeep` only). `~/bin` is already prepended to PATH by
`stow/shell/.config/shell/env.sh`, so a single `stow/scripts/bin/dotfiles`
file is all that needs to land in PATH. Subcommand names are namespaced
(`recovery health` vs top-level `doctor` vs `sync doctor`) so no clashes.

---

## 2. Proposed command tree

```
dotfiles                         # no args → short help + status hint
dotfiles help [SUBCOMMAND]       # help; per-subcommand help
dotfiles version                 # repo HEAD short sha + branch

dotfiles update [--stash|--stash-rebase|--reset --confirm]
                [--no-apply] [--dry-run] [--profile NAME]
                                 # pull repo (safe by default) then re-apply

dotfiles bootstrap [--first-time] [--dry-run] [--profile NAME]
                   [--enforce] [--adopt] [--backup-conflicts]
                                 # apply config only (no git pull) = root bootstrap.sh

dotfiles status                  # read-only summary (OS, profile, git, stow, services, sync)
dotfiles doctor                  # read-only diagnostics across the whole platform

dotfiles profile show            # print active/saved profile + its declarations
dotfiles profile select          # interactive picker (persists)  → select-profile.sh
dotfiles profile reconfigure     # re-run wizard even if saved     → select-profile.sh --first-time
dotfiles profile validate        # validate-profiles.sh (all or active)

dotfiles recovery build [--dry-run] [pass-through flags]   → generate-recovery-pack.sh
dotfiles recovery verify ARTIFACT.age                      → generate-recovery-pack.sh --verify
dotfiles recovery health [--max-age N]                     → recovery-pack-health.sh
dotfiles recovery retention [--keep N] [--dry-run]         → recovery-pack-retention.sh

dotfiles sync status             # show tailscale/atuin/syncthing state (read-only)
dotfiles sync setup              # (re)run setup-syncing.sh for active profile
dotfiles sync doctor             # diagnose sync agents (login state, service units)
```

Design rules:
- **Subcommand, not flag, for verbs.** `dotfiles update`, not `dotfiles --update`.
- **Read-only by default** for `status`, `doctor`, `*show`, `sync status`.
- **Destructive actions are explicit** (`update --reset --confirm`,
  `recovery retention` without `--dry-run`).
- Unknown subcommand → error + `dotfiles help` + exit 2.

---

## 3. Help output examples

```
$ dotfiles
dotfiles — your machine's config, in one command

Usage: dotfiles <command> [options]

Common:
  update        Pull latest config and re-apply it to this machine
  status        Show what this machine is and whether it's in sync
  doctor        Diagnose common problems (read-only)

Manage:
  bootstrap     Apply config without pulling (first-time / dry-run)
  profile       show | select | reconfigure | validate
  recovery      build | verify | health | retention
  sync          status | setup | doctor

Other:
  help [cmd]    Show help (optionally for one command)
  version       Show repo branch and commit

Run 'dotfiles help <command>' for details.
```

```
$ dotfiles help update
dotfiles update — pull the latest config and re-apply it.

Usage: dotfiles update [options]

  (default)            safe pull (fast-forward only) then apply
  --stash              stash local changes, pull, pop
  --stash-rebase       stash + rebase local commits onto origin/main
  --reset --confirm    discard local changes/commits, hard reset (DESTRUCTIVE)
  --no-apply           update the repo only; do not re-apply config
  --dry-run            show what would happen, change nothing
  --profile NAME       apply a specific profile

Examples:
  dotfiles update
  dotfiles update --stash
  dotfiles update --no-apply
```

```
$ dotfiles status
Machine:   omarchy (pacman)          profile: laptop-work-omarchy
Repo:      ~/dotfiles  branch main   clean · up to date with origin/main
Stow:      28 links healthy · 0 conflicts
Services:  tailscale ✓
Sync:      tailscale ✓   atuin (not logged in)   syncthing (n/a)
Tip:       run 'dotfiles doctor' for a full check.
```

---

## 4. Implementation design

### 4a. The dispatcher — `stow/scripts/bin/dotfiles` (new)
- A single bash script; stowed via the existing `scripts` stow package →
  `~/bin/dotfiles` (already on PATH). No new stow package, no profile change.
- **Locate the repo** robustly: resolve the script's own path through the
  symlink (`readlink`) up to repo root; allow `DOTFILES_DIR` override; fall back
  to `$HOME/dotfiles`. Validate the dir contains `bootstrap.sh` + `scripts/lib.sh`.
- Source `scripts/lib.sh` for logging/`run`/`need_cmd`/`read_list`.
- Parse `$1` as the command, dispatch to a `cmd_<name>()` function; each handler
  re-parses its own remaining args and exec/calls the relevant internal script
  with the existing flag contract. Keep the dispatcher thin — **no business
  logic duplicated**, it only routes + composes.
- `set -euo pipefail`; unknown command → help + exit 2.

### 4b. Extract shared git-update logic — `scripts/update-repo.sh` (new, internal)
The git fetch/ff/stash/rebase/reset logic currently lives inside
`scripts/bootstrap.sh` (`update_existing_repo` + helpers). Extract it into
`scripts/update-repo.sh` (args: `--mode safe|stash|stash-rebase|reset`,
`--confirm-reset`, honors `REPO_DIR`). Then:
- `scripts/bootstrap.sh` sources/calls it (no behavior change — existing
  `tests/bootstrap-update/run-tests.sh` must stay green).
- `dotfiles update` calls it, then (unless `--no-apply`) calls root
  `bootstrap.sh`. This is the one piece of real refactor; everything else is
  routing. *(If extraction proves risky, fallback: `dotfiles update` shells the
  local repo update inline using the same git commands — but extraction is
  preferred to keep one source of truth.)*

### 4c. New thin status/doctor helpers
- `dotfiles status` / `doctor` / `sync status` need read-only summaries that
  don't exist yet. Implement them **inside the dispatcher** (small functions
  reusing `detect-os.sh`, the saved profile file `~/.config/dotfiles/profile`,
  `git -C`, and `apply-stow.sh`'s dry-run/preview for conflict counts). Keep each
  under ~30 lines; no new heavyweight scripts. `doctor` aggregates:
  `validate-profiles.sh`, a stow dry-run conflict scan, tool presence checks,
  `recovery health` (if configured), and `sync doctor`.

### 4d. Wrappers (pure routing, no new logic)
`profile`, `recovery`, `sync setup` map 1:1 onto existing scripts with the
active profile/OS auto-filled (resolve OS via `detect-os.sh`, profile via the
saved profile file). Pass through unknown flags so power users keep full control.

### 4e. Docs
- `docs/extending.md`: add a "Run things via `dotfiles`" section + "add a
  subcommand = add one `cmd_<name>()` in `stow/scripts/bin/dotfiles`".
- `README.md`: lead the Install/Update section with `dotfiles update` as the
  day-to-day path; reframe `curl|bash` as installer/recovery; add a command
  table mirroring §2.
- `docs/implementation-plan.md`: add a "Phase 3B — Unified CLI" status block.

---

## 5. Migration plan (script → CLI)

| Step | Action | Back-compat |
|------|--------|-------------|
| 1 | Add `scripts/update-repo.sh`; refactor `scripts/bootstrap.sh` to use it | bootstrap-update tests stay green |
| 2 | Add `stow/scripts/bin/dotfiles` dispatcher with `help`/`version`/`bootstrap`/`update` | root `./bootstrap.sh` still works |
| 3 | Add `status` + `doctor` + `profile` + `sync` routing | scripts still callable by path |
| 4 | Add `recovery` routing over the 3 recovery scripts | recovery scripts unchanged |
| 5 | Update docs (README, extending, implementation-plan) | `curl\|bash` unchanged, just reframed |
| 6 | (optional, later) update `recovery-pack.service` ExecStart to call `dotfiles recovery build` instead of the script path | systemd unit only; leave as-is if risky |

No standalone `dotfiles-*` commands are created (user-confirmed). Nothing is
removed: internal scripts keep working by path so existing tests, systemd units,
and muscle memory don't break. The CLI is purely **additive routing** plus one
small shared-logic extraction.

---

## 6. Critical files
- `stow/scripts/bin/dotfiles` — **new** dispatcher (the whole CLI surface).
- `scripts/update-repo.sh` — **new** internal; extracted git-update logic.
- `scripts/bootstrap.sh` — refactor to call `update-repo.sh` (no behavior change).
- `stow/scripts/README.md` — note the `dotfiles` entrypoint.
- `README.md`, `docs/extending.md`, `docs/implementation-plan.md` — docs.
- Unchanged: root `bootstrap.sh`, all `scripts/*` internal step scripts,
  recovery-pack scripts, profiles. (Recovery Pack & NetworkManager logic untouched.)

---

## 7. Verification

Run from repo root:
1. `shellcheck -x bootstrap.sh scripts/*.sh stow/scripts/bin/dotfiles tests/*/run-tests.sh`
2. `tests/bootstrap-update/run-tests.sh` — must stay green (proves the
   `update-repo.sh` extraction preserved remote-update behavior).
3. `tests/recovery-pack/run-tests.sh` and `tests/stow-cleanup/run-tests.sh` — green.
4. `scripts/validate-profiles.sh` — green.
5. CLI smoke tests (after stowing `scripts` into a temp HOME, or by running the
   file directly):
   - `dotfiles help`, `dotfiles help update`, `dotfiles version`
   - `dotfiles status` (read-only) on this machine
   - `dotfiles doctor` (read-only)
   - `dotfiles bootstrap --dry-run --profile minimal` == root
     `./bootstrap.sh --dry-run --profile minimal` (identical effect)
   - `dotfiles update --no-apply --dry-run` (no mutation)
   - `dotfiles profile show`, `dotfiles sync status`
6. Add a focused `tests/cli/run-tests.sh` covering dispatch: unknown command →
   exit 2 + help; `help`/`version` exit 0; `bootstrap --dry-run` routes to root
   orchestrator; `update --no-apply --dry-run` performs no git mutation
   (use a temp repo like the bootstrap-update harness).
7. Confirm `~/bin/dotfiles` resolves the repo correctly when invoked via the
   stow symlink (not just by direct path).

## 8. Out of scope / guardrails
- No changes to Recovery Pack logic or NetworkManager behavior.
- No standalone `dotfiles-*` commands; single `dotfiles` surface only.
- Internal step scripts keep their path-callable contracts (additive change).
- The literal `VAR=… curl … | bash` limitation (documented previously) is
  unaffected; `dotfiles update` is the in-repo replacement that avoids it.
