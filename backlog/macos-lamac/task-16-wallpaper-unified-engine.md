# Task 16 — Unify the wallpaper engine: one command, per-OS backends

Status: done
Scope: repo-only
Depends on: none
Size: M

## Objective
One `dotfiles-wallpaper` command in the global layer owns all
platform-independent logic (config, source merging, random/sequential
selection, state, status). The only per-OS code is a small "set this image"
backend. Shared pool moves to an OS-neutral path. Commit guardrails added.

## Files involved
- `stow/global/wallpapers/.local/bin/dotfiles-wallpaper` (new — the engine)
- `stow/global/wallpapers/.config/dotfiles/wallpapers.conf` (moved from
  os-omarchy, now shared)
- `stow/global/wallpapers/.local/share/wallpapers/shared/` (new pool home + README)
- `stow/os-omarchy/wallpapers/` — KEEPS only the systemd
  `dotfiles-wallpaper-rotate.{service,timer}` units (ExecStart updated to
  `dotfiles-wallpaper rotate`); its old rotate script, conf, and
  `backgrounds/walls` placeholder are removed/relocated
- `scripts/dotfiles` (`dotfiles wallpaper <cmd>` becomes a thin delegation to
  the engine; `configure_wallpaper_rotation` systemd logic gated to omarchy)
- `docs/wallpapers.md` (rewrite locations + architecture section)
- `.gitignore`, `.githooks/pre-commit` (guardrails)

## Reason
The engine that landed in commit 8fa4466 is Omarchy-only and my earlier plan
duplicated its conf-parsing/pool/state logic into a second macOS script.
Franco's direction: one platform-independent engine, swap only the setter.
This also relocates the pool off the Omarchy-specific
`~/.config/omarchy/backgrounds/walls` path so all OSes share it.

## Proposed implementation
Engine `dotfiles-wallpaper` (bash, subcommands `set <file> | rotate | status |
open-local`), logic lifted from the existing
`stow/os-omarchy/wallpapers/.local/bin/dotfiles-wallpaper-rotate`:
- conf `~/.config/dotfiles/wallpapers.conf` (same variable names, new
  defaults + one addition):
  `WALLPAPER_REPO_DIR="$HOME/.local/share/wallpapers/shared"`,
  `WALLPAPER_LOCAL_DIR="$HOME/Pictures/local-wallpapers"`,
  `WALLPAPER_ROTATION_ENABLED`, `WALLPAPER_ROTATION_INTERVAL`,
  `WALLPAPER_ROTATION_MODE="random"` (`random|sequential`; sequential walks
  the sorted merged list via the state file).
- pool = repo dir, plus local dir ONLY if it exists (never auto-create it from
  the engine; `open-local` and the omarchy update hook may create it);
  jpg/jpeg/png/webp, recursive, corrupt-skip via `magick identify` when
  available — all behavior carried over from the existing script.
- backend dispatch at the end only:
  `case "$(uname -s)" in Darwin) set_wallpaper_macos ;; Linux) set_wallpaper_omarchy ;; esac`
  - `set_wallpaper_omarchy`: the EXISTING audited behavior verbatim — update
    `~/.config/omarchy/current/background`, restart swaybg, restore previous
    on failure. (Note: Omarchy uses swaybg via its current/background symlink,
    NOT hyprpaper — keep the audited behavior, do not switch compositors' 
    wallpaper daemons.) Guard: if not an omarchy host, print "no wallpaper
    backend for this OS" and exit 0.
  - `set_wallpaper_macos`: stub in this task —
    `err "macOS backend lands in task 17"` — so the engine is testable on
    Omarchy immediately.
- `scripts/dotfiles`: `cmd wallpaper rotate|status|open-local` execs the
  engine (keep `configure_wallpaper_rotation`'s systemd enable/disable, gated
  to omarchy; its local-dir creation uses the conf value).
- Pool move + guardrails: shared README (add = commit image <= 8 MB
  jpg/png/webp, curated — git history keeps images forever; local =
  `~/Pictures/local-wallpapers`, never committed); `.gitignore` add
  `local-wallpapers/`, `._*`, `.thumbnails/`; pre-commit: staged files under
  `stow/global/wallpapers/.local/share/wallpapers/` must be
  jpg/jpeg/png/webp and <= 8 MB.

## Safety concerns
- Omarchy machines re-stow: old conf/script/walls symlinks become conflicts —
  conflict wizard, choose backup (add to task 28 Linux checklist).
- LOCAL DIR PATH CHANGE: the day-old engine used
  `~/Pictures/Wallpapers/local`; new default is `~/Pictures/local-wallpapers`
  (Franco's explicit decision). docs/wallpapers.md must tell existing machines
  to move any images: `mv ~/Pictures/Wallpapers/local/* ~/Pictures/local-wallpapers/`.
- Keep conf variable NAMES stable; only defaults change.

## Validation commands
```bash
shellcheck stow/global/wallpapers/.local/bin/dotfiles-wallpaper scripts/dotfiles
grep -rn 'backgrounds/walls\|Wallpapers/local' stow/ scripts/ docs/  # only migration notes in docs
bash .githooks/pre-commit   # + the 9MB negative test from the guardrail section
# On an Omarchy machine after apply: dotfiles wallpaper status && dotfiles wallpaper rotate
```

## Rollback notes
`git revert`; conf variable names unchanged, so a revert restores old
behavior cleanly.

## Acceptance criteria
One engine file contains all shared logic; the only OS-specific code is the
two setter functions; Omarchy rotate/status/timer work as before (new paths);
mode=sequential cycles deterministically; guardrail negative test rejects.

## Result
Created global dotfiles-wallpaper engine and shared wallpapers.conf/pool path,
updated dotfiles wallpaper delegation and Omarchy systemd ExecStart, removed
the Omarchy-only rotate script/config/pool placeholder, rewrote docs, and added
wallpaper pre-commit guardrails. Shellcheck clean; status works on macOS;
oversized staged wallpaper negative test rejects as required.
