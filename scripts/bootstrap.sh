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
  for cmd in git stow bash curl; do
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

# 1. clone or update
if [[ -d "$DOTFILES_DIR/.git" ]]; then
  say "Updating existing repo at $DOTFILES_DIR"
  if [[ $DRY_RUN -eq 1 ]]; then
    git -C "$DOTFILES_DIR" fetch --dry-run 2>&1 | sed 's/^/  /' || true
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
    if git -C "$DOTFILES_DIR" rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
      git -C "$DOTFILES_DIR" checkout "$BRANCH"
    else
      git -C "$DOTFILES_DIR" checkout -b "$BRANCH" "origin/$BRANCH"
    fi
    git -C "$DOTFILES_DIR" pull --ff-only origin "$BRANCH"
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

# 3. ensure ~/.local/bin is on PATH via .zshrc
ZSHRC="$HOME/.zshrc"
# shellcheck disable=SC2016
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
[[ $DRY_RUN -eq 1 ]] || touch "$ZSHRC"
if [[ -f "$ZSHRC" ]] && ! grep -qF "$PATH_LINE" "$ZSHRC"; then
  if [[ $DRY_RUN -eq 1 ]]; then
    say "Would add ~/.local/bin to PATH in .zshrc"
  else
    printf '\n# Added by dotfiles bootstrap\n%s\n' "$PATH_LINE" >> "$ZSHRC"
    say "Added ~/.local/bin to PATH in .zshrc (restart shell)"
  fi
fi

# 4. install declared packages before stow, then apply layers with conflict wizard.
say "Running dotfiles update"
if [[ $DRY_RUN -eq 1 ]]; then
  "$DOTFILES_DIR/scripts/dotfiles" update --dry-run
else
  "$DOTFILES_DIR/scripts/dotfiles" update
fi

say "Done. Run: dotfiles status"
