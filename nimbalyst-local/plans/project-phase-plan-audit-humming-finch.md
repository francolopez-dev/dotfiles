# Phase 1 Cleanup + Phased Roadmap — Audit & Plan

## Context

The dotfiles repo (`~/dotfiles`, `jfrancolopez/dotfiles`) completed a Phase 1 refactor
(bootstrap orchestrator, package groups, profiles, Stow split). A real-world test on a
**Lenovo work laptop running Omarchy** exposed that the repo's *device model* predates that
hardware: it assumes "work laptop = macOS." This plan fixes the resulting safety and modeling
gaps before any further phases.

**Root problems found in the audit:**

1. **Profiles model the wrong OS.** `profiles/work-laptop.conf` stows macOS-only packages
   (`aerospace`, `borders`) and uses the macOS `desktop` set, but the work laptop is Omarchy.
   Profile names don't make their OS explicit, so picking the wrong one is easy.
2. **No OS-aware Stow filtering.** `scripts/apply-stow.sh` stows every package in
   `STOW_PACKAGES` regardless of detected OS. On Omarchy it would try to stow `aerospace`/
   `borders` (macOS-only) and has no notion that `hypr`/`waybar`/`rofi` are Linux-only.
   `bootstrap.sh` never even passes `--os` to `apply-stow.sh`.
3. **Unsafe / silent conflict handling.** `apply-stow.sh:37-47` only backs up hardcoded
   `.bashrc`/`.zshrc`. For everything else (e.g. Omarchy-shipped `nvim`, `btop`, `hypr`
   configs) Stow just fails and the script emits a vague `warn "stow reported issues"` — the
   user can't tell what was or wasn't linked.
4. **Profile selection is not remote-friendly.** `scripts/select-profile.sh:63-73` uses a
   `select` menu bound to stdin, which is the piped script under `curl | bash`, so it silently
   falls back to `minimal`. There is no first-run wizard and no OS-based suggestion.
5. **No profile validation.** Nothing checks that a profile references real package groups /
   stow packages / known services.
6. **Docs describe the old device model** and there are no Lenovo-specific notes.

**Decided with the user:**
- Rename profiles so each one's OS is explicit; add a **first-run wizard** that auto-runs only
  when no profile is configured, re-runnable via `--first-time`.
- Stow conflicts: **always prompt interactively** (skip / backup+stow / adopt); fall back to
  **skip + clear report** when non-interactive.
- Plan all three phases now; **implement Phase 1 only** this session.
- Constraints: Bash only. No Ansible/Nix/templating. Git + Stow + Bootstrap. Default behavior
  must be non-destructive. Don't over-build (esp. Lenovo driver fixes — docs only).

---

## Phase 1 — Cleanup (implement now)

### 1. Rename profiles for OS clarity  *(priorities 1 & 2)*
`git mv` the profile files to OS-explicit names and update their comment headers. Proposed map
(names adjustable on approval):

| Old | New | OS | Notes |
|-----|-----|----|-------|
| `domum-workstation.conf` | `desktop-omarchy.conf` | Omarchy | primary workstation |
| `work-laptop.conf` (macOS) | `work-omarchy.conf` | **Omarchy** | **rebuilt** for the Lenovo: `(common desktop-linux work)`, stow `hypr waybar rofi` instead of `aerospace borders` |
| `personal-laptop.conf` | `personal-macos.conf` | macOS | unchanged content |
| *(new, kept as "other")* | `work-macos.conf` | macOS | preserves a macOS work option |
| `linux-server-personal.conf` | `server-debian.conf` | Debian | unchanged content |
| `linux-server-work.conf` | `server-ubuntu.conf` | Ubuntu | unchanged content |
| `minimal.conf` | `minimal.conf` | any | unchanged |

- `work-omarchy.conf` becomes: `PACKAGE_GROUPS=(common desktop work)`,
  `STOW_PACKAGES=(shell zsh bash nvim btop git ssh tmux scripts hypr waybar rofi wezterm)`,
  `SERVICES=(tailscale)`. (OS-aware filtering — step 2 — drops anything not valid on Omarchy.)
- Note: `desktop` package group currently mixes macOS + Linux GUI tools. Keep the single
  `desktop` group; OS-correctness comes from per-manager package lists (`brew.txt` vs
  `pacman.txt`) which already exist, plus stow OS filtering.

### 2. OS-aware Stow filtering  *(priority 3)*
- Add a small data file `profiles/stow-os.map` (pkg → comma OS list; unlisted = all):
  ```
  aerospace macos
  borders   macos
  hypr      omarchy
  waybar    omarchy
  rofi      omarchy
  ```
- `bootstrap.sh:82-84`: pass `--os "$OS"` to `apply-stow.sh` (currently omitted).
- `scripts/apply-stow.sh`: accept `--os`, load the map, and skip packages whose OS list
  doesn't include the detected OS, printing e.g. `skip: aerospace (macos-only, host is omarchy)`.
- Add a `read_map`-style helper to `scripts/lib.sh` (reuse `read_list` parsing style).

### 3. Interactive, safe Stow conflict handling  *(priority 4 + work-laptop notes 1 & 2)*
Rework `scripts/apply-stow.sh` `main()` and delete the hardcoded `backup_conflicts()`:
- For each (OS-filtered) package, first simulate: `stow --no -v --no-folding -t "$HOME" PKG`,
  and parse conflict lines (`existing target is …`) into a list of real conflicting paths.
- **No conflicts** → stow normally.
- **Conflicts + interactive** (prompt via `/dev/tty` so it works under `curl | bash`) → per
  package ask: `[s]kip / [b]ackup+stow / [a]dopt`.
  - backup: `mv` each conflicting file to `~/.dotfiles-backup/<timestamp>/` preserving relative
    path, print exactly what moved where, then stow.
  - adopt: `stow --adopt` + warn to review `git diff`.
- **Conflicts + non-interactive** → honor flags (`--backup-conflicts` → backup+stow,
  `--adopt` → adopt) else **skip + report** the conflicting paths clearly.
- Add `--backup-conflicts` to `apply-stow.sh` and to root `bootstrap.sh` (forwarded).
- Keep `--adopt` working as today. Default remains non-destructive.

### 4. First-run wizard + automatic profile selection  *(priority 5)*
Rework `scripts/select-profile.sh` (keep the file; expand logic):
- Resolution order becomes: `--profile NAME` → (if `--first-time`) wizard → saved profile →
  (if no saved profile) wizard → `minimal` fallback.
- **Wizard** (`run_wizard`): read/write `/dev/tty` (not stdin) so it works under `curl | bash`.
  Uses detected `$OS` to show only sensible choices (Omarchy → `desktop-omarchy` /
  `work-omarchy`; macOS → `personal-macos` / `work-macos`; debian → `server-debian`;
  ubuntu → `server-ubuntu`; plus `minimal`). Asks a single device-role question, maps to a
  profile, confirms, persists to `~/.config/dotfiles/profile`.
- Add `--first-time` (alias `--reconfigure`) to `select-profile.sh` and root `bootstrap.sh`:
  forces the wizard even when a profile is already saved. Without it, an existing saved profile
  means "just apply repo updates" (no prompt) — matching the user's intended steady-state UX.
- `bootstrap.sh` must pass `$OS` into `select-profile.sh` (so the wizard can filter by OS).

### 5. Profile validation  *(priority 6)*
- New `scripts/validate-profiles.sh`: for every `profiles/*.conf`, source it and assert each
  `PACKAGE_GROUPS` entry has a `packages/<group>/` dir, each `STOW_PACKAGES` entry has a
  `stow/<pkg>/` dir, and arrays are well-formed. Print a per-profile PASS/FAIL summary; exit
  non-zero on any failure. Reuse `lib.sh` loggers.
- Wire a lightweight check into `bootstrap.sh` (validate just the selected profile before
  mutating anything; hard `die` on failure). Full-repo validation stays a manual/CI command.

### 6. Docs  *(priority 7 + work-laptop note 3)*
- **`docs/work-laptop-lenovo.md`** (new): built-in Intel I226-V Ethernet intermittent freeze;
  USB Ethernet adapter reliable; Wi-Fi stable in testing; keep built-in Ethernet disabled if
  unstable. Notes only — no driver automation.
- **`README.md`**: rewrite the machine-class table + profile examples for the new names and the
  Omarchy work laptop; document the wizard, `--first-time`, `--backup-conflicts`, OS-aware
  filtering, and the new interactive conflict flow; update the repo-structure tree.
- **`docs/implementation-plan.md`** (new tracking file): completed/remaining/known-issues + the
  exact next prompt, per the continuation requirement, so work is resumable.

### Files touched (Phase 1)
- `bootstrap.sh` — pass `--os` to apply-stow & select-profile; add `--first-time` /
  `--backup-conflicts`; pre-apply profile validation.
- `scripts/lib.sh` — add map-reading helper; possibly a `/dev/tty` prompt helper.
- `scripts/apply-stow.sh` — OS filtering + interactive conflict handling (largest change).
- `scripts/select-profile.sh` — wizard + automatic/OS-aware selection + `--first-time`.
- `scripts/validate-profiles.sh` — **new**.
- `profiles/*.conf` — `git mv` renames + `work-omarchy.conf` rebuild + new `work-macos.conf`.
- `profiles/stow-os.map` — **new**.
- `README.md`, `docs/work-laptop-lenovo.md` (**new**), `docs/implementation-plan.md` (**new**).

---

## Phase 2 — Recovery & disaster docs (outline; detailed before building)
- `scripts/generate-recovery-pack.sh`: gather `ssh/age/wireguard/vpn/certificates/exports`
  into a tmpfs temp dir → `tar` → **age**-encrypt to public recipients → `recovery-pack-YYYY-MM.tar.gz.age`
  → copy to NAS → `restic` → optional Hetzner Storage Box → email status report. Plaintext only
  in the shredded temp dir.
- Optional encrypted email attachment support; optional Hetzner toggle (flow works without it).
- Docs: `recovery-pack.md`, `vaultwarden.md`, `disaster-recovery.md`, `break-glass-recovery.md`,
  `travel-recovery.md`, `restic.md`.
- **Do not start until Phase 1 is clean and validated.**

## Phase 3 — Sync, Atuin, Omarchy polish (outline)
- `scripts/setup-syncing.sh`: Tailscale `up --ssh`; Syncthing folders (Documents/Projects/
  Notes/Wallpapers) local-first with NAS hub.
- Atuin **client** config as a stow package (server already hosted); reconcile `.stowrc`
  `atuin/*` ignore.
- Omarchy desktop polish: wallpapers, themes, Hyprland custom includes
  (`~/.config/hypr/custom.conf`), keybindings, Waybar/Rofi — via custom-include strategy so
  Omarchy core updates survive. **Never before Phase 1 safety fixes land.**

---

## Verification (Phase 1)
1. `shellcheck bootstrap.sh scripts/*.sh` clean.
2. `scripts/validate-profiles.sh` → all profiles PASS.
3. `./bootstrap.sh --dry-run --profile minimal` → prints OS, profile, would-install lists, and
   `stow --no -v` previews; mutates nothing.
4. macOS (this machine): `./bootstrap.sh --dry-run --profile personal-macos` → confirms
   `aerospace`/`borders` kept, `hypr`/`waybar`/`rofi` filtered out by OS map.
5. Simulate Omarchy filtering: `OS_OVERRIDE=omarchy ./bootstrap.sh --dry-run --profile work-omarchy`
   → confirms `aerospace`/`borders` skipped, desktop Linux packages kept.
6. Conflict flow: create a dummy real `~/.config/btop/btop.conf`, run a real stow of `btop`,
   verify the interactive prompt appears and `[b]ackup` moves it under `~/.dotfiles-backup/<ts>/`
   with clear output; non-interactive run skips + reports.
7. Wizard: remove `~/.config/dotfiles/profile`, run `./bootstrap.sh --dry-run` with no
   `--profile` → wizard prompts via tty, OS-filtered choices, persists selection. Re-run →
   no prompt (uses saved). `--first-time` → prompts again.
8. `git status` shows only intended renames/edits; untracked `stow/git/.config/git/ignore`
   left untouched.

## Checkpoint / resumability
On finishing Phase 1, update `docs/implementation-plan.md` with completed work, remaining work,
known issues, and the exact next prompt to begin Phase 2. Commit only when the user asks.
