# Dotfiles — Personal Platform (Franco)

A Git-based personal platform that rebuilds any of my machines from scratch:
**install OS → clone repo → `./bootstrap.sh` → back to work.**

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

One command, from any supported machine:

``` bash
curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | bash
```

This remote entrypoint installs minimal deps (git, curl, ca-certificates),
clones/updates the repo, then hands off to the repo-root `./bootstrap.sh`.
If the repo already exists with local changes, it stops instead of stashing or
overwriting work. Use `DOTFILES_BOOTSTRAP_AUTO_STASH=1` or `--auto-stash` only
when you explicitly want the remote entrypoint to stash, update, and pop.

Remote bootstrap flags must be passed either with environment variables:

```bash
DOTFILES_FIRST_TIME=1 curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | bash
DOTFILES_PROFILE=laptop-work-omarchy curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | bash
DOTFILES_BACKUP_CONFLICTS=1 curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | bash
```

or with Bash's `-s --` argument separator:

```bash
curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | bash -s -- --first-time
curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | bash -s -- --profile laptop-work-omarchy
```

Do not use `bash --first-time`; Bash will treat that as an option to Bash itself.

Once the repo is cloned, run it directly:

``` bash
cd ~/dotfiles
./bootstrap.sh                       # first-run wizard (or saved choice)
./bootstrap.sh --first-time          # re-run the wizard
./bootstrap.sh --profile personal-macos
./bootstrap.sh --dry-run --profile minimal   # preview, change nothing and save nothing
```

Safe to run multiple times — it is idempotent.

------------------------------------------------------------------------

## 🧩 How it works

```
curl bootstrap.sh | bash         (scripts/bootstrap.sh — remote entrypoint)
        │  install min deps, clone/update repo
        ▼
./bootstrap.sh                   (root orchestrator)
        │
        ├─ scripts/detect-os.sh        → omarchy | macos | debian | ubuntu
        ├─ scripts/select-profile.sh   → choose & persist a profile
        ├─ scripts/install-packages.sh → install profile's package groups
        ├─ scripts/apply-stow.sh       → symlink profile's stow packages
        └─ scripts/enable-services.sh  → enable profile's services
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

## 🎛 Profiles (`profiles/*.conf`)

A profile is a small sourced shell file declaring **intent** — which package
groups, stow packages, and services a machine wants:

``` sh
PACKAGE_GROUPS=(common desktop personal gaming virtualization)
STOW_PACKAGES=(shell zsh bash nvim btop git ssh tmux scripts wezterm recovery-pack)
SERVICES=(tailscale libvirtd)
```

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

Phase 3A stow packages for Atuin, Syncthing, and Omarchy desktop polish are
present as parked skeletons but are not enabled in active profiles during Phase
2 stabilization.

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
│   └── stow-os.map         # OS allow-list for desktop-specific stow packages
├── stow/                   # GNU Stow packages → symlinked into $HOME
│   ├── zsh/ bash/ shell/ nvim/ btop/ git/ ssh/ tmux/
│   ├── wezterm/ aerospace/ borders/ scripts/
│   ├── recovery-pack/              # systemd user automation for Recovery Pack
│   └── atuin/ syncthing/ hypr/ waybar/ rofi/ wallpapers/ themes/
│                                   # parked Phase 3A skeletons
├── assets/                 # wallpapers/ themes/ (single source of truth)
├── scripts/                # logic only, never symlinked
│   ├── bootstrap.sh        # remote curl entrypoint
│   ├── lib.sh detect-os.sh select-profile.sh
│   ├── install-packages.sh apply-stow.sh enable-services.sh
│   ├── validate-profiles.sh
│   └── install.sh          # DEPRECATED shim → ../bootstrap.sh
└── docs/
```

------------------------------------------------------------------------

## 🔒 Machine-specific config & secrets

- Machine-specific shell env (paths, credentials) lives in a **gitignored**
  `~/.config/shell/env.local`, sourced by `env.sh`. Nothing machine-specific is
  committed. (Same idea as `~/.ssh/config.local`.)
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
- **Phase 3:** Syncthing/Tailscale sync, Atuin client, Omarchy desktop polish.
