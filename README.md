# Dotfiles — Personal Platform (Franco)

A Git-based personal platform that rebuilds any of my machines from scratch:
**install OS → clone repo → `./bootstrap.sh` → back to work.**

Guiding rule: *machines are disposable, Git is the source of truth, secrets never
live in Git.*

Supported machine classes (and only these):

| Class | OS | Pkg manager | Example profile |
|-------|----|-------------|-----------------|
| Primary desktop | **Omarchy** (Arch/Hyprland) | pacman + yay | `domum-workstation` |
| Secondary laptop | **macOS** | Homebrew | `personal-laptop`, `work-laptop` |
| Personal server | **Debian** | apt | `linux-server-personal` |
| Work server | **Ubuntu** | apt | `linux-server-work` |

------------------------------------------------------------------------

## 🚀 Install / Update

One command, from any supported machine:

``` bash
curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | bash
```

This remote entrypoint installs minimal deps (git, curl, ca-certificates),
clones/updates the repo, then hands off to the repo-root `./bootstrap.sh`.

Once the repo is cloned, run it directly:

``` bash
cd ~/dotfiles
./bootstrap.sh                       # interactive profile pick (or saved choice)
./bootstrap.sh --profile personal-laptop
./bootstrap.sh --dry-run --profile minimal   # preview, change nothing
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
| `--dry-run` | Print intended actions, mutate nothing |
| `--profile NAME` | Use & persist this profile (else interactive / saved / `minimal`) |
| `--enforce` | Also **remove** packages not declared by the profile (destructive, prompts) |
| `--adopt` | Let stow adopt existing real files (review the git diff after) |
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
STOW_PACKAGES=(shell zsh bash nvim btop git ssh tmux scripts hypr waybar rofi)
SERVICES=(tailscale syncthing libvirtd)
```

The chosen profile is persisted per-machine (gitignored) at
`~/.config/dotfiles/profile`.

------------------------------------------------------------------------

## 📂 Repository structure

```
dotfiles/
├── bootstrap.sh            # root orchestrator ("one command")
├── packages/               # package groups (per-OS lists)
├── profiles/               # intent definitions (*.conf)
├── stow/                   # GNU Stow packages → symlinked into $HOME
│   ├── zsh/ bash/ shell/ nvim/ btop/ git/ ssh/ tmux/
│   ├── wezterm/ aerospace/ borders/ scripts/
│   └── hypr/ waybar/ rofi/         # Omarchy desktop (skeletons)
├── assets/                 # wallpapers/ themes/ (single source of truth)
├── scripts/                # logic only, never symlinked
│   ├── bootstrap.sh        # remote curl entrypoint
│   ├── lib.sh detect-os.sh select-profile.sh
│   ├── install-packages.sh apply-stow.sh enable-services.sh
│   └── install.sh          # DEPRECATED shim → ../bootstrap.sh
└── docs/
```

------------------------------------------------------------------------

## 🔒 Machine-specific config & secrets

- Machine-specific shell env (paths, credentials) lives in a **gitignored**
  `~/.config/shell/env.local`, sourced by `env.sh`. Nothing machine-specific is
  committed. (Same idea as `~/.ssh/config.local`.)
- `.gitignore` blocks `*.local`, `*.age`, recovery artifacts, logs, OS cruft.
- Secrets never live in Git. Recovery/secret tooling arrives in Phase 2.

------------------------------------------------------------------------

## 🌐 Remote access (Tailscale)

``` bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --ssh
```

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

- **Phase 1 (done):** bootstrap orchestrator, package groups, profiles, stow refactor.
- **Phase 2:** Age recovery pack + disaster-recovery docs.
- **Phase 3:** Syncthing/Tailscale sync, Atuin client, Omarchy desktop polish.
