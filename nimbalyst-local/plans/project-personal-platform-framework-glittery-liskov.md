# Personal Platform Framework — Migration & Build Plan

## Context

Today this repo (`~/dotfiles`, remote `solosoyfranco/dotfiles`) is a simple but capable
Stow + bootstrap setup: a remote `scripts/bootstrap.sh` clones/pulls and runs
`scripts/install.sh`, which detects a package manager, installs a **fixed** tool list,
optionally installs oh-my-zsh/p10k, and stows a handful of packages.

The goal is to evolve this into a **Git-based personal platform** that can rebuild any of
four machine classes — **Omarchy** (primary), **macOS** (secondary), **Debian** (personal
server), **Ubuntu** (work server) — from: install OS → clone repo → `./bootstrap.sh` →
restore secrets → back to work. Guiding rule: *machines are disposable, Git is the source
of truth, secrets never live in Git.*

What's driving the change:
- The installer advertises and supports OSes the user does **not** use (Fedora/RHEL/Rocky/
  Alma/Alpine, dnf/yum/apk). This is unnecessary complexity the user explicitly wants gone.
- Tool/package selection is a single global list — there's no concept of **profiles** or
  **package groups**, so a headless server gets the same intent as a desktop.
- There is no recovery layer (Age recovery pack), no service enablement, no sync setup, and
  the docs claim OS support that contradicts the real target set.

**Decisions locked with the user:**
1. **Phased** delivery — approve/build phase by phase (this plan = Phase 1 in full detail,
   Phases 2–3 outlined; each phase gets its own approval before building).
2. **Split** the consolidated `stow/shell` package into focused packages.
3. Vaultwarden + Atuin servers are **already hosted** by the user → we build **client config
   + bootstrap integration + docs** only, not server deployment.
4. **Omarchy is the first real test target** for the refactored bootstrap.

**Constraint honored throughout:** no files are moved or deleted without an explicit reason
stated in this plan. Stow uses `--no` (dry-run) and `--adopt`/backups so nothing in `$HOME`
is destroyed.

---

## Target repository structure

```
dotfiles/
├── README.md                 # rewritten: only Omarchy/macOS/Debian/Ubuntu
├── bootstrap.sh              # NEW root orchestrator (the "one command")
├── packages/                 # NEW centralized package groups (per-OS lists)
│   ├── common/   {pacman.txt, aur.txt, brew.txt, apt.txt}
│   ├── desktop/  ...
│   ├── server/   ...
│   ├── personal/ ...
│   ├── work/     ...
│   ├── gaming/   ...
│   └── virtualization/ ...
├── profiles/                 # NEW intent definitions (sourced .conf)
│   ├── personal-laptop.conf
│   ├── work-laptop.conf
│   ├── domum-workstation.conf
│   ├── linux-server-personal.conf
│   ├── linux-server-work.conf
│   └── minimal.conf
├── stow/                     # split + new desktop packages
│   ├── zsh/ bash/ shell/ nvim/ btop/ git/ ssh/ tmux/
│   ├── wezterm/ aerospace/ borders/
│   ├── scripts/              # → ~/bin (shared scripts)
│   └── hypr/ waybar/ rofi/   # Omarchy desktop (custom-include strategy)
├── assets/                   # NEW single source of truth
│   ├── wallpapers/
│   └── themes/
├── scripts/                  # logic only, never symlinked
│   ├── bootstrap.sh          # remote curl entrypoint (kept, repointed)
│   ├── lib.sh                # NEW shared logger/need_cmd/dry-run helpers
│   ├── detect-os.sh
│   ├── select-profile.sh
│   ├── install-packages.sh
│   ├── apply-stow.sh
│   ├── enable-services.sh
│   ├── setup-syncing.sh
│   └── generate-recovery-pack.sh   # Phase 2
└── docs/                     # expanded
    ├── omarchy.md  syncthing-tailscale.md  restic.md  vaultwarden.md
    ├── recovery-pack.md  windows-vm.md
    ├── disaster-recovery.md  travel-recovery.md  break-glass-recovery.md
    └── SSH-keys-and-config.md   # already exists, keep
```

---

## Phase 1 — Foundation (bootstrap + packages + profiles + stow refactor)

This is the phase to build first and fully. It does **not** touch secrets/recovery/sync.

### 1.1 Drop unsupported-OS complexity
- `scripts/detect-os.sh` (new): print a single OS id — `omarchy | macos | debian | ubuntu`
  — plus the package manager. Detection:
  - macOS: `uname` = `Darwin` → `macos`/`brew`.
  - Arch (`ID=arch` in `/etc/os-release`) → `omarchy`/`pacman`+`yay`.
  - `/etc/os-release` `ID=debian` → `debian`/`apt`; `ID=ubuntu` → `ubuntu`/`apt`.
  - Anything else → hard error with a clear message (we intentionally don't support it).
- **Remove** the dnf/yum/apk branches and the Fedora/RHEL/Alpine claims. They currently live
  in `scripts/install.sh:81-107`, `scripts/install.sh:117-218`, `scripts/bootstrap.sh:40-115`,
  and `README.md:108-131`. *Reason: the user explicitly listed only these four OSes and asked
  to avoid generic-distro support; the extra branches are untested maintenance burden.*
- Drop the Raspberry Pi / Cockpit special-case (`scripts/install.sh:262-289`). *Reason: not in
  the supported set; can be reintroduced later as a `server` package group + service if needed.*

### 1.2 Centralized package groups (`packages/`)
- One directory per group: `common, desktop, server, personal, work, gaming, virtualization`.
- Inside each group, **per-manager plain-text lists** (one package per line, `#` comments):
  `pacman.txt`, `aur.txt` (Omarchy), `brew.txt` (+ optional `brew-cask.txt` for GUI apps),
  `apt.txt` (Debian/Ubuntu). This cleanly solves cross-distro name drift (e.g. `bat`→`batcat`,
  `eza`/`fd` availability) without a `case` mapping table.
- Seed `common/` from the existing `TOOLS_WANTED` (`scripts/install.sh:30-48`).
  Seed `desktop/brew-cask.txt` from the macOS casks (`scripts/install.sh:236`):
  `wezterm aerospace borders`.

### 1.3 Profiles (`profiles/*.conf`)
- Each profile is a small **sourced** shell file defining intent (no raw package names):
  ```sh
  PACKAGE_GROUPS=(common desktop personal gaming virtualization)
  STOW_PACKAGES=(shell zsh bash nvim btop git ssh tmux scripts hypr waybar rofi)
  SERVICES=(tailscale syncthing libvirtd)
  ```
- `scripts/select-profile.sh`: pick a profile (arg `--profile NAME`, else interactive list,
  else fall back to `minimal`) and persist the choice to a **machine-local, gitignored** state
  file `~/.config/dotfiles/profile`. *Reason: which profile a machine is depends on the
  machine, not the repo — keep it out of Git.*

### 1.4 Root orchestrator (`bootstrap.sh`) — the "one command"
- New repo-root `bootstrap.sh` runs, in order:
  `detect-os` → `select-profile` → `install-packages` → `apply-stow` → `enable-services`
  (→ `setup-syncing` in Phase 3).
- Flags: `--dry-run` (no mutations, print intended actions), `--profile NAME`, `--enforce`,
  `--log FILE` (default `~/.cache/dotfiles/bootstrap-<ts>.log`). Idempotent and re-runnable.
- `--enforce` (optional): additionally **remove** packages not declared by the selected
  profile's groups. Implemented narrowly against a computed manifest, **off by default**, with
  a confirmation prompt; documented as the only destructive package operation.
- `scripts/bootstrap.sh` (remote curl entrypoint) is **kept** but repointed: install minimal
  deps + clone/update, then exec the **root** `./bootstrap.sh` instead of the old
  `scripts/install.sh`. *Reason: preserves the existing `curl | bash` UX in README.md:13.*

### 1.5 Decompose `install.sh` into focused scripts
`scripts/install.sh` is **retired by decomposition**, not deleted blindly. Its logic moves to:
- `install-packages.sh` ← package loop + idempotency checks + dry-run + enforce
  (from `scripts/install.sh:159-218`, generalized to read group/per-OS lists).
- `apply-stow.sh` ← conflict backup + stow (from `scripts/install.sh:376-414`), gaining
  `--dry-run` via `stow --no -v` and `--adopt` as an opt-in.
- `enable-services.sh` ← new: enable a profile's `SERVICES` via `systemctl --user`/`systemctl`
  on Linux and `brew services` on macOS (tailscale, syncthing, libvirtd, borders).
- oh-my-zsh/p10k install (`scripts/install.sh:298-348`) moves into `install-packages.sh` as an
  optional desktop step, gated by env flags (kept as-is for now).
- `scripts/lib.sh` ← shared `log`/`need_cmd`/dry-run guard, replacing the duplicated copies in
  both current scripts.
- Keep `scripts/install.sh` as a thin shim that calls `../bootstrap.sh` for one release cycle
  (deprecation note), then remove. *Reason: avoid breaking any muscle-memory/automation.*

### 1.6 Split `stow/shell` into focused packages
Current `stow/shell` bundles zsh + bash + nvim + btop + `.config/shell/*`. Split so profiles
(esp. servers) stow only what they need:
- `stow/zsh/` ← `.zshrc`, `.p10k.zsh`
- `stow/bash/` ← `.bashrc`
- `stow/shell/` ← `.config/shell/{aliases.sh,env.sh}` (sourced by both shells; stays shared)
- `stow/nvim/` ← `.config/nvim/**`
- `stow/btop/` ← `.config/btop/btop.conf`
- New: `stow/scripts/bin/*` → `~/bin`; `stow/hypr`, `stow/waybar`, `stow/rofi` (Phase 1 creates
  empty/skeleton packages; real Omarchy configs land when testing on Omarchy).
- `git`, `ssh`, `tmux`, `wezterm`, `aerospace`, `borders` are unchanged.
- *Files are git-`mv`'d (history preserved); each move is listed in the commit body.*

### 1.7 Pull machine-specific env out of committed dotfiles
`stow/shell/.zshrc:67-74` commits machine-specific paths (a `GOOGLE_APPLICATION_CREDENTIALS`
path under OneDrive, LM Studio + pipx PATHs). These break on every other machine.
- Move them to a **gitignored** `~/.config/shell/env.local`, sourced by `.zshrc` after
  `env.sh` (the file already sources `~/.config/shell/env.sh` at line 28 — same pattern).
- *Reason: machine-specific config must not be in Git; this is the env-equivalent of the
  existing `~/.ssh/config.local` pattern documented in `docs/SSH-keys-and-config.md:119`.*

### 1.8 `.gitignore` + `.stowrc` hardening
- Add ignores: `*.local`, `~/.config/dotfiles/profile` artifacts, `recovery-pack/` working dir,
  `*.tar.gz.age`, `*.age`, `logs/`, OS cruft. *Reason: guarantee secrets/working artifacts can
  never be committed.*
- `.stowrc` already ignores `atuin/*` and `.DS_Store` — keep; revisit in Phase 3.
- Note: there is an **untracked** `stow/git/.config/git/ignore` in the working tree (user WIP).
  The plan will not modify or stage it; flagged here so it isn't lost.

---

## Phase 2 — Recovery & disaster docs (outline; detailed before building)

- `scripts/generate-recovery-pack.sh`: collect `ssh/ age/ wireguard/ vpn/ certificates/ exports/`
  from configured source paths into a temp dir on tmpfs → `tar` → `age` encrypt (recipients =
  Age **public** keys listed in a config; public keys are safe to keep in repo) →
  `recovery-pack-YYYY-MM.tar.gz.age` → copy to NAS path → `restic` backup → optional Hetzner →
  email status report (timestamp, checksum, size, status). Plaintext only ever exists in the
  temp dir and is `shred`'d; no unencrypted secret leaves generation.
- Age over GPG (per spec). Hetzner is config-toggled and the whole flow works without it.
- Docs to author: `recovery-pack.md`, `disaster-recovery.md`, `travel-recovery.md`,
  `break-glass-recovery.md`, `restic.md`, `vaultwarden.md`, `windows-vm.md` (3 recovery levels +
  break-glass scenarios: stolen laptop, NAS down, limited internet, international travel).

## Phase 3 — Sync, Atuin, services polish (outline)

- `scripts/setup-syncing.sh`: Tailscale up (`--ssh`), Syncthing folders (Documents, Projects,
  Notes, Wallpapers) kept local-first; NAS as hub/backup/archive. Obsidian vault via Syncthing.
- Atuin **client** config as a stow package (server already hosted): `atuin login` + sync; keep
  raw histfiles unsynced. Reconcile with the existing `.stowrc` `atuin/*` ignore.
- `docs/omarchy.md` + `docs/syncthing-tailscale.md`; Omarchy custom-include strategy
  (`~/.config/hypr/custom.conf`, `keybinds-custom.conf`) so customizations survive updates —
  never fork or edit Omarchy core.

---

## Critical files

| File | Action |
|------|--------|
| `bootstrap.sh` (root) | **create** — orchestrator |
| `scripts/lib.sh` | **create** — shared helpers |
| `scripts/detect-os.sh` | **create** — 4-OS detection, drops dnf/yum/apk |
| `scripts/{select-profile,install-packages,apply-stow,enable-services}.sh` | **create** from decomposed `install.sh` |
| `scripts/bootstrap.sh` | **edit** — repoint to root `bootstrap.sh`, drop extra pkg mgrs |
| `scripts/install.sh` | **shrink to deprecation shim**, then remove next cycle |
| `packages/*/{pacman,aur,brew,apt}.txt` | **create** — seeded from `install.sh` lists |
| `profiles/*.conf` | **create** — 6 profiles |
| `stow/shell` → `zsh/bash/shell/nvim/btop` | **git mv** split (history kept) |
| `stow/{scripts,hypr,waybar,rofi}` | **create** skeletons |
| `stow/shell/.zshrc` | **edit** — source `env.local`, remove machine paths |
| `README.md` | **rewrite** — only the 4 supported OSes |
| `.gitignore` | **edit** — secrets/artifacts ignores |

---

## Verification (Phase 1)

1. **Static/dry-run first (no mutations):**
   `./bootstrap.sh --dry-run --profile minimal` — confirm it prints detected OS, chosen profile,
   the package lists it *would* install, and `stow --no -v` symlink previews with zero changes.
2. **macOS sanity (machine in front of us):** run `./bootstrap.sh --profile personal-laptop`
   on the current Mac; verify Stow symlinks resolve, `.zshrc` sources `env.local`, and no
   machine-specific paths remain committed. Re-run to confirm **idempotency** (second run = all
   "OK already", no diffs).
3. **Omarchy (primary target):** in an Omarchy VM/box, run
   `./bootstrap.sh --profile domum-workstation`; verify pacman+yay groups install, desktop stow
   packages link, and Hypr/Waybar/Rofi custom-include files don't clobber Omarchy core.
4. **Server path:** on a Debian VM, `./bootstrap.sh --profile linux-server-personal` installs
   only `common`+`server` groups and stows no desktop/editor packages.
5. `shellcheck scripts/*.sh bootstrap.sh` clean; `git status` shows only intended moves/edits
   and the untracked WIP `stow/git/.config/git/ignore` left untouched.

Phases 2 and 3 will each get their own detailed plan + verification before any code is written.
