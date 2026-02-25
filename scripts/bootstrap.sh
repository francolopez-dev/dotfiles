#!/usr/bin/env bash
set -euo pipefail
# -e  : exit on error
# -u  : error on unset variables
# -o pipefail : fail if any command in a pipe fails

# -----------------------------
# Configuration (can be overridden via env vars)
# -----------------------------

# Repository URL to clone
REPO_URL="${REPO_URL:-https://github.com/solosoyfranco/dotfiles.git}"

# Where to place the repo locally
REPO_DIR="${REPO_DIR:-$HOME/dotfiles}"

# Relative path to the main installer script inside the repo
INSTALL_SCRIPT_REL="${INSTALL_SCRIPT_REL:-scripts/install.sh}"

# -----------------------------
# Helper functions
# -----------------------------

# Simple logger
log() { printf "%s\n" "$*"; }

# Check if a command exists
need_cmd() { command -v "$1" >/dev/null 2>&1; }

# -----------------------------
# Detect available package manager
# -----------------------------
# We support most common systems:
# - macOS (brew)
# - Debian/Ubuntu/Raspberry Pi OS (apt)
# - Fedora/RHEL (dnf/yum)
# - Arch (pacman)
# - Alpine (apk)

detect_pkg_mgr() {
  if need_cmd brew; then
    echo "brew"
    return
  fi
  if need_cmd apt-get; then
    echo "apt"
    return
  fi
  if need_cmd dnf; then
    echo "dnf"
    return
  fi
  if need_cmd yum; then
    echo "yum"
    return
  fi
  if need_cmd pacman; then
    echo "pacman"
    return
  fi
  if need_cmd apk; then
    echo "apk"
    return
  fi
  echo ""
}

# -----------------------------
# Install minimal dependencies
# -----------------------------
# We only install what is strictly necessary to proceed:
# - git (to clone repo)
# - curl (network fetches)
# - ca-certificates (HTTPS support)

install_min_deps() {
  local mgr="$1"

  case "$mgr" in
  brew)
    log "Using Homebrew"
    brew update || true
    brew install git curl ca-certificates || true
    ;;
  apt)
    log "Using apt"
    sudo apt-get update -y
    sudo apt-get install -y git curl ca-certificates
    ;;
  dnf)
    log "Using dnf"
    sudo dnf -y makecache || true
    sudo dnf -y install git curl ca-certificates
    ;;
  yum)
    log "Using yum"
    sudo yum -y makecache || sudo yum -y check-update || true
    sudo yum -y install git curl ca-certificates
    ;;
  pacman)
    log "Using pacman"
    sudo pacman -Sy --noconfirm
    sudo pacman -S --noconfirm --needed git curl ca-certificates
    ;;
  apk)
    log "Using apk"
    sudo apk update
    sudo apk add --no-cache git curl ca-certificates
    ;;
  *)
    log "ERROR: No supported package manager found."
    log "Install git and curl manually, then re-run."
    exit 1
    ;;
  esac
}

# -----------------------------
# Clone or update the repo
# -----------------------------
# If repo already exists:
#   - Pull latest changes
# If not:
#   - Clone it fresh

clone_or_update_repo() {
  if [[ -d "$REPO_DIR/.git" ]]; then
    log "Repo already exists. Updating..."
    git -C "$REPO_DIR" fetch --all --prune
    git -C "$REPO_DIR" checkout main
    git -C "$REPO_DIR" pull --ff-only
  else
    log "Cloning repo..."
    git clone "$REPO_URL" "$REPO_DIR"
  fi
}

# -----------------------------
# Execute main installer
# -----------------------------
# Delegates the heavy lifting to install.sh
# Keeps bootstrap small and focused

run_install() {
  local install_path="$REPO_DIR/$INSTALL_SCRIPT_REL"

  if [[ ! -f "$install_path" ]]; then
    log "ERROR: install script not found: $install_path"
    exit 1
  fi

  chmod +x "$install_path" || true
  log "Running installer..."
  bash "$install_path"
}

# -----------------------------
# Main bootstrap flow
# -----------------------------

main() {
  log "----------------------------------"
  log "Dotfiles Bootstrap Starting"
  log "Repo: $REPO_URL"
  log "Target: $REPO_DIR"
  log "----------------------------------"

  local mgr
  mgr="$(detect_pkg_mgr)"

  # If git or curl are missing, install them first
  if ! need_cmd git || ! need_cmd curl; then
    if [[ -z "$mgr" ]]; then
      log "ERROR: git/curl missing and no supported package manager found."
      exit 1
    fi
    log "Installing minimal dependencies..."
    install_min_deps "$mgr"
  fi

  clone_or_update_repo
  run_install

  log "----------------------------------"
  log "Bootstrap Complete"
  log "Restart terminal or run: source ~/.zshrc"
  log "----------------------------------"
}

main "$@"
