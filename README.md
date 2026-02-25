# Dotfiles (Franco)

Reproducible shell + CLI environment across macOS, Raspberry Pi, and
Linux servers using **GNU Stow** and a smart bootstrap installer.

------------------------------------------------------------------------

## 🚀 Install / Update

Run this on any machine:

``` bash
curl -fsSL https://raw.githubusercontent.com/solosoyfranco/dotfiles/main/scripts/bootstrap.sh | bash
```

This bootstrap will:

- Install minimal dependencies (git, curl, certificates)
- Clone the repo if missing
- Pull latest changes if it already exists
- Auto-stash local changes before updating
- Run the installer
- Apply Stow packages

You can safely run it multiple times.

------------------------------------------------------------------------

## 🧠 Architecture Overview

                     ┌────────────────────────────┐
                     │        GitHub Repo         │
                     │  (dotfiles + scripts)      │
                     └─────────────┬──────────────┘
                                   │
                                   ▼
                        curl bootstrap.sh | bash
                                   │
                     ┌─────────────▼──────────────┐
                     │        Bootstrap           │
                     │ - Install minimal deps     │
                     │ - Clone or pull repo       │
                     │ - Auto-stash if needed     │
                     │ - Run install.sh           │
                     └─────────────┬──────────────┘
                                   │
                                   ▼
                     ┌────────────────────────────┐
                     │         install.sh         │
                     │ - Install CLI tools        │
                     │ - Optional zsh + p10k      │
                     │ - Auto-start zsh           │
                     │ - Apply GNU Stow           │
                     └─────────────┬──────────────┘
                                   │
                                   ▼
                     ┌────────────────────────────┐
                     │        GNU Stow            │
                     │  Symlinks stow/* → $HOME   │
                     └────────────────────────────┘

Result: consistent environment across all machines.

------------------------------------------------------------------------

## 📦 What Gets Installed

### CLI Tools

git, stow, tmux, fzf, ripgrep, jq, bat, eza, fastfetch, btop, htop,
neovim, zsh, curl, wget, nano

### Optional

- oh-my-zsh
- powerlevel10k

### Stow Packages

- `shell` (zsh, bash, nvim, btop, env, aliases)
- `git` (global config + global ignore)
- `ssh` (config only, never private keys)
- `tmux`
- `wezterm` (desktop only)
- `aerospace` (macOS only)

------------------------------------------------------------------------

## 📂 Repository Structure

    dotfiles/
    ├── stow/
    │   ├── shell/
    │   ├── git/
    │   ├── ssh/
    │   ├── tmux/
    │   └── wezterm/
    ├── scripts/
    │   ├── bootstrap.sh
    │   └── install.sh
    └── .stowrc

- `stow/` → symlinked into `$HOME`
- `scripts/` → logic only (never symlinked)

------------------------------------------------------------------------

## 🖥 OS Support

### macOS

Uses Homebrew automatically. Installs desktop configs (wezterm +
aerospace).

### Raspberry Pi OS / Debian / Ubuntu

Uses apt automatically. Skips GUI configs on headless systems.

### Fedora / RHEL / Rocky / Alma

Uses dnf or yum.

### Arch

Uses pacman.

### Alpine

Uses apk.

------------------------------------------------------------------------

## 🔄 Updating

Recommended:

``` bash
curl -fsSL https://raw.githubusercontent.com/solosoyfranco/dotfiles/main/scripts/bootstrap.sh | bash
```

Manual:

``` bash
cd ~/dotfiles
git pull
./scripts/install.sh
```

------------------------------------------------------------------------

## 🛠 Customizing Installation

Edit:

`scripts/install.sh`

- Modify `TOOLS_WANTED=(...)`
- Modify `STOW_PACKAGES=(...)`

------------------------------------------------------------------------

Built for consistency across Mac, Linux workstations, and headless
servers.

