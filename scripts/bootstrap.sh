#!/usr/bin/env bash
# bootstrap.sh — curl-friendly first-run setup.
#   curl -fsSL <raw-url>/scripts/bootstrap.sh | bash
#
# Clones (or updates) the repo, checks out the working branch, applies the
# stow layers for this machine, and symlinks `dotfiles` onto PATH.
set -euo pipefail

REPO_URL="${DOTFILES_REPO_URL:-https://github.com/jfrancolopez/dotfiles.git}"
export DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
BRANCH="${DOTFILES_BRANCH:-main}"
BIN_DIR="$HOME/.local/bin"
DRY_RUN=0

say() { printf '\033[34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33mwarn\033[0m %s\n' "$*" >&2; }

repo_dirty() {
  [[ -n "$(git -C "$DOTFILES_DIR" status --porcelain 2>/dev/null || true)" ]]
}

show_repo_dirty_help() {
  warn "repo has local changes; skipping bootstrap pull to protect your work"
  git -C "$DOTFILES_DIR" status --short --branch || true
  printf '\nRun these diagnostics:\n'
  printf '  cd ~/dotfiles\n'
  printf '  git status --short --branch\n'
  printf '  git diff --name-only\n'
  printf '\nThen run:\n'
  printf '  ~/dotfiles/scripts/dotfiles update\n\n'
}

usage() {
  cat <<'EOF'
Usage: bootstrap.sh [--dry-run] [--profile profile-<host>-<os>]

Environment:
  DOTFILES_REPO_URL  Git repo URL (default: jfrancolopez/dotfiles)
  DOTFILES_DIR       Checkout path (default: ~/dotfiles)
  DOTFILES_BRANCH    Git branch (default: main)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --profile)
      [[ -n "${2:-}" ]] || { warn "--profile requires a value"; exit 2; }
      export DOTFILES_PROFILE="$2"
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *) warn "unknown option: $1"; usage; exit 2 ;;
  esac
done

detect_bootstrap_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    local id="${ID-}" id_like="${ID_LIKE-}"
    case "${id,,}:${id_like,,}" in
      arch:*|*:*arch*) echo "omarchy" ;;
      ubuntu:*) echo "ubuntu" ;;
      debian:*|*:*debian*) echo "debian" ;;
      *) echo "unknown" ;;
    esac
  else
    echo "unknown"
  fi
}

install_bootstrap_prereqs() {
  local missing=() cmd
  for cmd in git stow bash curl zsh; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  [[ ${#missing[@]} -eq 0 ]] && return 0

  say "Installing bootstrap prerequisites: ${missing[*]}"
  if [[ $DRY_RUN -eq 1 ]]; then
    warn "dry-run: would install ${missing[*]}"
    return 0
  fi

  case "$(detect_bootstrap_os)" in
    omarchy)
      if command -v yay >/dev/null 2>&1; then
        yay -S --needed --noconfirm "${missing[@]}"
      else
        sudo pacman -S --needed --noconfirm "${missing[@]}"
      fi
      ;;
    debian|ubuntu)
      sudo apt-get update
      sudo apt-get install -y "${missing[@]}"
      ;;
    *)
      warn "cannot install prerequisites automatically on this OS: ${missing[*]}"
      return 1
      ;;
  esac
}

install_bootstrap_prereqs

install_oh_my_zsh() {
  local omz_dir="$HOME/.oh-my-zsh"
  if [[ -r "$omz_dir/oh-my-zsh.sh" ]]; then
    return 0
  fi

  say "Installing Oh My Zsh"
  if [[ $DRY_RUN -eq 1 ]]; then
    warn "dry-run: would clone Oh My Zsh to $omz_dir"
    return 0
  fi

  git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$omz_dir"
}

install_oh_my_zsh

# 1. clone or update
if [[ -d "$DOTFILES_DIR/.git" ]]; then
  say "Updating existing repo at $DOTFILES_DIR"
  if [[ $DRY_RUN -eq 1 ]]; then
    git -C "$DOTFILES_DIR" fetch --dry-run || true
  else
    git -C "$DOTFILES_DIR" fetch --all --prune
  fi
else
  say "Cloning $REPO_URL -> $DOTFILES_DIR"
  if [[ $DRY_RUN -eq 1 ]]; then
    warn "dry-run: would clone $REPO_URL to $DOTFILES_DIR"
  else
    git clone "$REPO_URL" "$DOTFILES_DIR"
  fi
fi
if [[ -d "$DOTFILES_DIR/.git" ]]; then
  if [[ $DRY_RUN -eq 0 ]]; then
    if repo_dirty; then
      show_repo_dirty_help
    else
      if git -C "$DOTFILES_DIR" rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
        git -C "$DOTFILES_DIR" checkout "$BRANCH"
      else
        git -C "$DOTFILES_DIR" checkout -b "$BRANCH" "origin/$BRANCH"
      fi
      git -C "$DOTFILES_DIR" pull --ff-only origin "$BRANCH"
    fi
  else
    say "Dry-run branch: $BRANCH"
  fi
fi

# 2. symlink the CLI onto PATH before stow so fallback exists if conflicts occur.
mkdir -p "$BIN_DIR"
if [[ $DRY_RUN -eq 1 ]]; then
  say "Would link dotfiles -> $BIN_DIR/dotfiles"
else
  ln -sf "$DOTFILES_DIR/scripts/dotfiles" "$BIN_DIR/dotfiles"
fi
say "Linked dotfiles -> $BIN_DIR/dotfiles"

# 3. ~/.local/bin is added by stow/global/shell/.config/shell/env.sh once the
# shell layer is stowed. Do not edit ~/.zshrc here; it is repo-managed.
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) warn "$BIN_DIR is not on PATH in this shell yet; restart shell after stow" ;;
esac

# 4. install declared packages before stow, then apply layers with conflict wizard.
say "Running dotfiles update"
if [[ $DRY_RUN -eq 1 ]]; then
  if [[ -x "$DOTFILES_DIR/scripts/dotfiles" ]]; then
    "$DOTFILES_DIR/scripts/dotfiles" update --dry-run
  else
    warn "dry-run: repo checkout is not present, so dotfiles update cannot be simulated"
    warn "dry-run: would run $DOTFILES_DIR/scripts/dotfiles update --dry-run after clone"
  fi
else
  "$DOTFILES_DIR/scripts/dotfiles" update
fi

say "Done. Run: dotfiles status"
