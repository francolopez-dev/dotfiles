# Dotfiles — Personal Platform (Franco)

A Git-based personal platform that rebuilds any of my machines from scratch:
**install OS → install dotfiles once → `dotfiles update` → back to work.**

Guiding rule: *machines are disposable, Git is the source of truth, secrets never
live in Git.*

Supported machine classes (and only these):

| Class | OS | Pkg manager | Example profile |
|-------|----|-------------|-----------------|
| Personal desktop | **Omarchy** (Arch/Hyprland) | pacman + yay | `desktop-personal-omarchy` |
| Work desktop | **Omarchy** (Arch/Hyprland) | pacman + yay | `desktop-work-omarchy` |
| Personal laptop | **Omarchy** (Lenovo/Hyprland) | pacman + yay | `laptop-personal-omarchy` |
| Work laptop | **Omarchy** (Lenovo/Hyprland) | pacman + yay | `laptop-work-omarchy` |
| Personal laptop | **macOS** | Homebrew | `personal-macos` |
| Work laptop | **macOS** | Homebrew | `work-macos` |
| Personal server | **Debian** | apt | `server-debian` |
| Work server | **Ubuntu** | apt | `server-ubuntu` |

------------------------------------------------------------------------

## 🚀 Install / Update

After the repo has been installed and stowed, use the unified CLI for normal
work:

```bash
dotfiles update       # pull latest config and re-apply it
dotfiles status       # quick read-only machine summary
dotfiles doctor       # deeper read-only diagnostics
```

The remote `curl | bash` path is still supported, but it is the installer,
first-machine, and emergency-repair entrypoint. From any supported machine:

``` bash
curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | bash
```

This remote entrypoint installs minimal deps (git, curl, ca-certificates),
clones/updates the repo, then hands off to the repo-root `./bootstrap.sh`.
If the repo already exists, the default update mode is safe:

- clean and behind `origin/main`: fast-forward automatically
- dirty working tree: stop with status and instructions
- unpushed local commits: stop with status and instructions
- diverged branch: stop with status and instructions

The remote bootstrap never merges, rebases, stashes, or resets by default.

Remote bootstrap flags must be passed either with environment variables **placed
on `bash`, after the pipe**:

```bash
curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | DOTFILES_FIRST_TIME=1 bash
curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | DOTFILES_PROFILE=laptop-work-omarchy bash
curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | DOTFILES_BACKUP_CONFLICTS=1 bash
```

or with Bash's `-s --` argument separator:

```bash
curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | bash -s -- --first-time
curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | bash -s -- --profile laptop-work-omarchy
```

> **Important — env placement.** In a pipeline, `VAR=val curl … | bash` applies
> `VAR` only to the **`curl`** process, *not* to `bash`. So
> `DOTFILES_UPDATE_MODE=stash curl … | bash` is silently ignored and runs in
> `safe` mode. Put the env var on `bash` (after the pipe) as shown above, or use
> the `bash -s -- --flag` form. Do not use `bash --first-time`; Bash treats that
> as an option to Bash itself.

### Remote update modes

Normal safe update:

```bash
curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | bash
```

Force first-time wizard:

```bash
curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | DOTFILES_FIRST_TIME=1 bash
```

Auto-stash dirty files, then fast-forward:

```bash
# env form (placed on bash, after the pipe)
curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | DOTFILES_UPDATE_MODE=stash bash
# flag form (also pipe-safe)
curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | bash -s -- --update-mode stash
```

Rebase local commits onto `origin/main`, stashing dirty files first if needed:

```bash
curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | DOTFILES_UPDATE_MODE=stash-rebase bash
curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | bash -s -- --update-mode stash-rebase
```

Emergency reset to `origin/main`:

```bash
curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | DOTFILES_UPDATE_MODE=reset DOTFILES_CONFIRM_RESET=1 bash
curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | bash -s -- --update-mode reset --confirm-reset
```

Reset mode discards local commits and working-tree changes. The legacy
`DOTFILES_BOOTSTRAP_AUTO_STASH=1` and `--auto-stash` paths map to
`DOTFILES_UPDATE_MODE=stash`.

Once the repo is cloned, prefer the unified CLI:

| Command | Purpose |
|---------|---------|
| `dotfiles update` | Pull latest config and re-apply it to this machine |
| `dotfiles update --no-apply` | Pull only |
| `dotfiles bootstrap` | Apply config without pulling |
| `dotfiles status` | Show OS, profile, git, stow, services, and sync summary |
| `dotfiles doctor` | Run read-only diagnostics |
| `dotfiles profile show` | Show active profile and declarations |
| `dotfiles profile select` | Pick and persist a profile |
| `dotfiles recovery build` | Build an encrypted Recovery Pack |
| `dotfiles recovery health` | Check NAS Recovery Pack health |
| `dotfiles sync status` | Show sync agent state |
| `dotfiles sync setup` | Re-run sync setup for the active profile |
| `dotfiles desktop reload waybar` | Restart Waybar after editing Omarchy desktop files |

The root orchestrator remains available for installer/recovery internals:

``` bash
cd ~/dotfiles
./bootstrap.sh                       # first-run wizard (or saved choice)
./bootstrap.sh --first-time          # re-run the wizard
./bootstrap.sh --profile personal-macos
./bootstrap.sh --dry-run --profile minimal   # preview, change nothing and save nothing
```

Both `dotfiles bootstrap` and `./bootstrap.sh` are safe to run multiple times;
the root orchestrator is idempotent.

------------------------------------------------------------------------

## 🧩 How it works

```
curl bootstrap.sh | bash         (scripts/bootstrap.sh — installer/recovery entrypoint)
        │  install min deps, clone/update repo
        ▼
./bootstrap.sh                   (root orchestrator)
        │
        ├─ scripts/detect-os.sh        → omarchy | macos | debian | ubuntu
        ├─ scripts/select-profile.sh   → choose & persist a profile
        ├─ scripts/install-packages.sh → install profile's package groups
        ├─ scripts/apply-stow.sh       → symlink base + OS-base + profile stow packages
        ├─ scripts/configure-profile-settings.sh → write profile metadata env
        ├─ scripts/enable-services.sh  → enable profile's services
        └─ scripts/setup-syncing.sh    → set up profile's sync agents (Tailscale/Syncthing/Atuin)

dotfiles                         (stow/scripts/bin/dotfiles — day-to-day CLI)
        ├─ update / bootstrap / status / doctor
        ├─ profile show | select | reconfigure | validate
        ├─ recovery build | verify | health | retention
        ├─ sync status | setup | doctor
        └─ desktop reload [waybar]
```

### Flags (root `bootstrap.sh`)

| Flag | Meaning |
|------|---------|
| `--dry-run` | Print intended actions, mutate nothing; default log file and saved profile writes are disabled |
| `--profile NAME` | Use & persist this profile unless `--dry-run` is set |
| `--first-time`, `--reconfigure` | Run the OS-aware first-run wizard even if a profile is saved |
| `--enforce` | Also **remove** packages not declared by the profile (destructive, prompts) |
| `--adopt` | Let stow adopt existing real files (review the git diff after) |
| `--backup-conflicts` | Back up stow conflicts to `~/.dotfiles-backup/<timestamp>/` instead of prompting/skipping |
| `--log FILE` | Tee output here (default `~/.cache/dotfiles/bootstrap-<ts>.log`) |

------------------------------------------------------------------------

## 📦 Packages (`packages/`)

Package selection is split into **groups**, each with **per-manager plain-text
lists** (one package per line, `#` comments):

```
packages/<group>/{pacman.txt, aur.txt, brew.txt, brew-cask.txt, apt.txt}
```

Groups: `common, desktop, server, personal, work, gaming, virtualization`.
Per-manager lists cleanly handle cross-distro name drift without a mapping table.

## 🎛 Profiles (`profiles/*.conf`) and the three-tier stow model

Dotfiles resolve in **three tiers** so nothing is duplicated across profiles:

| Tier | What | Scope | Lives in |
|------|------|-------|----------|
| Global base | shell/terminal config, aliases | every profile, every OS (incl. `minimal`) | `profiles/stow-base` |
| OS base | keyboard shortcuts, desktop/WM config | every profile on that OS | `profiles/stow-os-base` |
| Profile | apps to install (+ rare profile-only dotfiles) | per profile | `profiles/*.conf` |

The effective stow list is `stow-base + stow-os-base (for the host OS) +
the profile's STOW_PACKAGES`, deduped, with the per-package `stow-os.map` gate
still applied on top.

A profile is a small sourced shell file declaring **intent** — package groups,
*profile-only* stow extras, services, and sync agents:

``` sh
PACKAGE_GROUPS=(common desktop personal gaming virtualization)
STOW_PACKAGES=(nvim btop wezterm recovery-pack)  # optional; shared dotfiles come from stow-base
SERVICES=(tailscale libvirtd)
SYNC=(tailscale atuin)                            # optional; see setup-syncing.sh
```

To add a global alias edit `stow/shell`; to add an OS shortcut edit
`stow/hypr` (omarchy) or `stow/aerospace` (macOS) — it applies to every
that-OS profile automatically. See [`docs/extending.md`](docs/extending.md).

The chosen profile is persisted per-machine (gitignored) at
`~/.config/dotfiles/profile`.

On first run, or when `--first-time` is passed, the profile wizard reads from
`/dev/tty` so it still works when the installer is launched through
`curl | bash`. It filters profile choices by detected OS:

- Omarchy: `desktop-personal-omarchy`, `desktop-work-omarchy`, `laptop-personal-omarchy`, `laptop-work-omarchy`, `minimal`
- macOS: `personal-macos`, `work-macos`, `minimal`
- Debian: `server-debian`, `minimal`
- Ubuntu: `server-ubuntu`, `minimal`

The wizard also reports detected chassis when available and orders Omarchy
choices for laptop or desktop hardware. Canceling the wizard exits without
saving a profile. Non-interactive first-run fallbacks use `minimal` for that run
only and do not persist it.

Old saved profile names are migrated automatically:

- `work-laptop` or `work-omarchy` on Omarchy -> `laptop-work-omarchy`
- `personal-laptop` on Omarchy -> `laptop-personal-omarchy`
- `domum-workstation` or `desktop-omarchy` on Omarchy -> `desktop-personal-omarchy`
- `personal-laptop` on macOS -> `personal-macos`
- `work-laptop` on macOS -> `work-macos`
- `linux-server-personal` on Debian -> `server-debian`
- `linux-server-work` on Ubuntu -> `server-ubuntu`

Validate every profile manually with:

```bash
scripts/validate-profiles.sh
```

## 🔗 Stow safety

Stow packages can be OS-scoped in `profiles/stow-os.map`. Unlisted packages
apply everywhere; current desktop-specific filters are:

- macOS only: `aerospace`, `borders`
- Omarchy only: `hypr`, `waybar`, `rofi`, `wallpapers`, `themes`, `recovery-pack`

As of Phase 3A, `atuin` ships in the global base (`profiles/stow-base`) and the
Omarchy desktop dotfiles (`hypr`, `waybar`, `rofi`, `wallpapers`, `themes`) ship
in the per-OS base (`profiles/stow-os-base`). They are stowed automatically for
the relevant OS. `syncthing` config is managed via `SYNC=()` /
`scripts/setup-syncing.sh` rather than stow.

Before a real stow, the script simulates each package and detects conflicts.
With a tty it asks per package: skip, backup then stow, or adopt. Without a tty,
the default is non-destructive skip with a clear conflict report. `--adopt` and
`--backup-conflicts` provide explicit non-interactive behavior.

If packages are skipped due to conflicts, bootstrap prints a summary and a
follow-up command such as:

```bash
./bootstrap.sh --profile laptop-work-omarchy --backup-conflicts
```

## 🖥 OS detection

Supported OS ids are `omarchy`, `macos`, `debian`, and `ubuntu`. Generic Arch or
Arch-derived systems are not silently treated as Omarchy; Omarchy markers must be
present. For a known Omarchy-compatible Arch-like system without detectable
markers, set `DOTFILES_ASSUME_OMARCHY=1` explicitly.

------------------------------------------------------------------------

## 📂 Repository structure

```
dotfiles/
├── bootstrap.sh            # root orchestrator ("one command")
├── packages/               # package groups (per-OS lists)
├── profiles/               # intent definitions (*.conf)
│   ├── stow-base           # global base stow packages (every profile/OS)
│   ├── stow-os-base        # per-OS base stow packages (shortcuts/desktop)
│   └── stow-os.map         # OS allow-list for desktop-specific stow packages
├── stow/                   # GNU Stow packages → symlinked into $HOME
│   ├── zsh/ bash/ shell/ nvim/ btop/ git/ ssh/ tmux/
│   ├── wezterm/ aerospace/ borders/ scripts/
│   ├── recovery-pack/              # systemd user automation for Recovery Pack
│   └── atuin/ syncthing/ hypr/ waybar/ rofi/ wallpapers/ themes/
│                                   # Phase 3A app + Omarchy desktop layer
├── assets/                 # wallpapers/ themes/ (single source of truth)
├── scripts/                # logic only, never symlinked
│   ├── bootstrap.sh        # remote curl entrypoint
│   ├── lib.sh detect-os.sh select-profile.sh
│   ├── install-packages.sh apply-stow.sh enable-services.sh
│   ├── setup-syncing.sh    # sync agents (Tailscale/Syncthing/Atuin)
│   ├── validate-profiles.sh
│   └── install.sh          # DEPRECATED shim → ../bootstrap.sh
└── docs/
```

------------------------------------------------------------------------

## 🔒 Machine-specific config & secrets

- Machine-specific shell env (paths, credentials) lives in a **gitignored**
  `~/.config/shell/env.local`, sourced by `env.sh`. Nothing machine-specific is
  committed. (Same idea as `~/.ssh/config.local`.)
- Profile display and hardware hints are generated at bootstrap into
  `~/.config/dotfiles/profile.env` for helper scripts. They are non-secret and
  come from `profiles/*.conf`.
- `.gitignore` blocks `*.local`, `*.age`, recovery artifacts, logs, OS cruft;
  stow-managed XDG `.local` trees are explicitly trackable.
- Secrets never live in Git. Recovery Pack tooling is implemented in Phase 2;
  configure local recipients and bootstrap identities outside Git before real use.

------------------------------------------------------------------------

## 🌐 Remote access (Tailscale)

``` bash
sudo systemctl enable --now tailscaled
sudo tailscale up
```

Profiles use friendly service names such as `tailscale`; on Omarchy/Arch this
maps to `tailscaled.service`.

See [`docs/sync.md`](docs/sync.md) for Atuin and Syncthing setup notes.

------------------------------------------------------------------------

## 🧑‍💻 Omarchy desktop editing

Omarchy desktop dotfiles live in the per-OS base layer and apply to Omarchy
profiles automatically. The main files are:

```text
stow/hypr/.config/hypr/conf.d/99-personal.conf
stow/waybar/.config/waybar/config.jsonc
stow/waybar/.config/waybar/style.css
stow/rofi/.config/rofi/config.rasi
```

After editing Waybar, reload it with:

```bash
dotfiles desktop reload waybar
```

See [`docs/desktop-omarchy.md`](docs/desktop-omarchy.md) for the edit, commit,
push, and `dotfiles update` workflow.

------------------------------------------------------------------------
## Troubleshooting

### sudo installed but user cannot use sudo

Symptoms:

```bash
sudo apt update
```

Returns:

```text
<username> is not in the sudoers file.
```

Verify the user belongs to the sudo group:

```bash
groups
```

If `sudo` is not listed, switch to root:

```bash
su -
```

On some minimal Debian installations, the `usermod` binary may not be in the default PATH for root.

Use the full path:

```bash
/usr/sbin/usermod -aG sudo <username>
```

Example:

```bash
/usr/sbin/usermod -aG sudo jfranco
```

Verify:

```bash
groups <username>
```

Expected:

```text
jfranco : jfranco sudo
```

Log out and back in (or reboot):

```bash
reboot
```

Test:

```bash
sudo whoami
```

Expected:

```text
root
```
------------------------------------------------------------------------

## 🗺 Roadmap

- **Phase 1 (complete):** bootstrap orchestrator, package groups, device/role/OS-explicit profiles, safe stow.
- **Phase 2:** Age Recovery Pack + disaster-recovery docs, distribution, timer, retention, health.
- **Phase 3A (in progress):** layered stow model (base/OS-base/profile),
  `setup-syncing` step (Tailscale/Syncthing/Atuin), Omarchy desktop polish.
  See [`docs/extending.md`](docs/extending.md) for the "how do I add X" cheatsheet.
