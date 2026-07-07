# Backlog: macOS profile for lamac

Goal: rebuild the personal MacBook Pro ("lamac", M2 Pro, macOS 26) as a cleanly
managed machine in this repo's layered structure (`global` -> `os-macos` ->
`profile-lamac-macos`), replacing the broken legacy flat-layout setup.

Read `CONTEXT.md` before executing any task. It contains the audit findings
every task assumes.

## Execution protocol (one task per agent/session)

1. Read `CLAUDE.md` (repo root), then `backlog/macos-lamac/CONTEXT.md`, then
   your task file. Do ONLY what the task file says. Anything else you notice
   goes in a note at the bottom of the task file, not in the diff.
2. Tasks marked `Scope: repo-only` must not modify anything outside the repo.
   Tasks marked `Scope: mac-local` mutate `$HOME` on lamac and must be run on
   that machine with a human present.
3. Respect `Depends on:`. Do not start a task whose dependencies are not
   `done`.
4. Run every command in the task's Validation section before finishing.
5. Flip `Status: todo` to `Status: done` in the task file, append a short
   `## Result` section (what changed, anything surprising), and commit the
   task's changes together with the task-file update as ONE commit:
   `<area>: <imperative summary>` (matches repo history style, e.g.
   `packages: add brew/cask support for macos`).
6. Never push. Pushing happens once, in task 29, after everything is green.
7. Never commit secrets, keys, tokens, `*.local` files, or anything from
   `~/Library` except where a task explicitly says otherwise.

## Task index and order

Phase 0 — foundations
- [ ] 01 rename-hostname-lamac (mac-local, S)
- [ ] 02 macos-os-detection (repo, M)
- [ ] 03 bash-version-guard (repo, S)
- [ ] 04 macos-inventory-script (repo, M)
- [ ] 05 fix-status-conflict-visibility (repo, M)

Phase 1 — packages plumbing
- [ ] 06 packages-lib-brew-support (repo, M) — needs 02
- [ ] 07 packages-macos-lists (repo, S) — needs 06

Phase 2 — stow layers
- [ ] 08 repo-hygiene-stow-ignores (repo, S)
- [ ] 09 promote-neovim-atuin-to-global (repo, S)
- [ ] 10 recover-aerospace-borders (repo, S)
- [ ] 11 macos-layer-skeleton (repo, S) — absorbs former task 12; there is no
      task 12

Phase 3 — SketchyBar (Waybar-inspired)
- [ ] 13 sketchybar-core (repo, M) — needs 10
- [ ] 14 sketchybar-system-plugins (repo, M) — needs 13
- [ ] 15 sketchybar-network-media-plugins (repo, M) — needs 13

Phase 4 — wallpapers
- [ ] 16 wallpaper-unified-engine (repo, M)
- [ ] 17 wallpaper-macos-backend (repo, S) — needs 16

Phase 5 — bootstrap + CLI
- [ ] 18 bootstrap-macos (repo, M) — needs 02, 03
- [ ] 19 cli-brew-install-logic (repo, M) — needs 06, 07
- [ ] 20 doctor-status-macos (repo, M) — needs 02, 06

Phase 6 — docs + guardrails
- [ ] 21 macos-defaults-script (repo, S)
- [ ] 22 docs-macos-setup (repo, S)
- [ ] 23 secrets-guardrails (repo, S)

Phase 7 — apply on lamac (mac-local, human present, in this exact order)
- [ ] 24 mac-cleanup-dangling-links (mac-local, S) — needs 01
- [ ] 25 mac-cleanup-legacy-configs (mac-local, M) — needs 24
- [ ] 26 mac-cleanup-services-apps (mac-local, S) — needs 24
- [ ] 27 mac-first-apply (mac-local, M) — needs ALL repo tasks + 25, 26
- [ ] 28 e2e-validation (mac-local + linux check, M) — needs 27
- [ ] 29 final-review-and-push (repo, S) — needs 28

Size: S = small mechanical change, any model. M = needs judgment; use a
stronger model. Phase 7 tasks mutate a real machine: strongest model, human
watching.

Repo-only phases 1-6 can be executed in any order that respects the listed
dependencies; phases 0 and 7 bracket them.
