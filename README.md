# Dotfiles (Franco)

This repo manages my shell and tooling setup across macOS, Raspberry Pi, and Linux servers using **GNU Stow**.

## What this does

- Installs common CLI tools (git, stow, tmux, fzf, ripgrep, jq, bat, eza, btop, neovim, etc.)
- Optionally installs **oh-my-zsh** + **powerlevel10k**
- Applies config via Stow packages:
  - `shell` (zsh + shared aliases/env, nvim, btop)
  - `git` (global git config + global ignore)
  - `ssh` (only `~/.ssh/config`, never private keys)
  - `tmux` (`~/.tmux.conf`)
  - `wezterm` (`~/.config/wezterm/wezterm.lua`)

## Repo layout

- `stow/` contains the **packages** that will be symlinked into `$HOME`
- `scripts/` contains installer scripts (not symlinked)
- `.stowrc` lives at repo root so `stow` works without extra flags

## Quick start

### 1) Clone the repo
```bash
git clone https://github.com/solosoyfranco/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

### 2) Run installer
```bash
./scripts/install.sh
```

### 3) Open a new terminal (or reload)
```bash
source ~/.zshrc
```

## OS-specific notes

### macOS (Apple Silicon or Intel)

**Requirements**
- Homebrew installed

If you don't have Homebrew:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Install + stow:
```bash
cd ~/dotfiles
./scripts/install.sh
```

Notes:
- The script uses `brew` automatically.
- `terminal-notifier` is used only if installed (Pomodoro functions still work without it).
- WezTerm config uses `~/.config/wezterm/wezterm.lua`.

### Raspberry Pi OS / Debian / Ubuntu (apt)

Install + stow:
```bash
cd ~/dotfiles
./scripts/install.sh
```

If you want to skip oh-my-zsh and powerlevel10k on servers:
```bash
INSTALL_OHMYZSH=0 INSTALL_P10K=0 ./scripts/install.sh
```

Notes:
- The script uses `apt-get` automatically.
- Some packages might not exist on older releases. The script will skip failures and continue.

### Fedora / RHEL / Rocky / Alma (dnf or yum)

```bash
cd ~/dotfiles
./scripts/install.sh
```

Skip zsh extras if you want:
```bash
INSTALL_OHMYZSH=0 INSTALL_P10K=0 ./scripts/install.sh
```

### Arch (pacman)

```bash
cd ~/dotfiles
./scripts/install.sh
```

### Alpine (apk)

```bash
cd ~/dotfiles
./scripts/install.sh
```

## Using Stow manually

This repo is configured so you can run `stow` from the repo root:

```bash
cd ~/dotfiles
stow -n -v shell git ssh tmux wezterm   # dry run
stow -v shell git ssh tmux wezterm      # apply
```

To remove symlinks for a package:
```bash
cd ~/dotfiles
stow -D shell
```

## What gets symlinked where

- `stow/shell/.zshrc` -> `~/.zshrc`
- `stow/shell/.bashrc` -> `~/.bashrc`
- `stow/shell/.config/shell/*` -> `~/.config/shell/*`
- `stow/shell/.config/nvim/*` -> `~/.config/nvim/*`
- `stow/git/.gitconfig` -> `~/.gitconfig`
- `stow/git/.gitignore_global` -> `~/.gitignore_global`
- `stow/ssh/.ssh/config` -> `~/.ssh/config`
- `stow/tmux/.tmux.conf` -> `~/.tmux.conf`
- `stow/wezterm/.config/wezterm/wezterm.lua` -> `~/.config/wezterm/wezterm.lua`



## Changing what gets installed

Edit `scripts/install.sh`:
- Add/remove tools in `TOOLS_WANTED=(...)`
- Add/remove stow packages in `STOW_PACKAGES=(...)`

## Updating on a machine

```bash
cd ~/dotfiles
git pull
./scripts/install.sh
```

