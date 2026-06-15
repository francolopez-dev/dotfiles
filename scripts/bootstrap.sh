#!/usr/bin/env bash
set -euo pipefail
# ============================================================
# Remote curl entrypoint:
#   curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | bash
#
# Installs minimal deps (git, curl, ca-certificates), clones/updates the repo,
# then hands off to the repo-root ./bootstrap.sh orchestrator.
#
# Supports exactly the four target OSes: omarchy(arch) / macos / debian / ubuntu.
# Any extra args are forwarded to the root bootstrap (e.g. --dry-run, --profile NAME).
# ============================================================

REPO_URL="${REPO_URL:-https://github.com/jfrancolopez/dotfiles.git}"
REPO_DIR="${REPO_DIR:-$HOME/dotfiles}"

log() { printf "%s\n" "$*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

# -----------------------------
# Minimal-dependency install (4 supported OSes only)
# -----------------------------
install_min_deps() {
  if [ "$(uname)" = "Darwin" ]; then
    need_cmd brew || {
      log "ERROR: Homebrew is required on macOS. Install from https://brew.sh then re-run."
      exit 1
    }
    brew install git curl ca-certificates || true
    return
  fi

  if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID:-}${ID_LIKE:-}" in
      *arch*)
        sudo pacman -Sy --noconfirm
        sudo pacman -S --noconfirm --needed git curl ca-certificates
        return ;;
      *debian*|*ubuntu*)
        sudo apt-get update -y
        sudo apt-get install -y git curl ca-certificates
        return ;;
    esac
  fi

  log "ERROR: Unsupported OS. Supported: omarchy(arch), macos, debian, ubuntu."
  log "Install git + curl manually, then re-run."
  exit 1
}

# -----------------------------
# Clone or update the repo
# -----------------------------
clone_or_update_repo() {
  if [ -d "$REPO_DIR/.git" ]; then
    log "Repo exists. Updating..."
    if [ -n "$(git -C "$REPO_DIR" status --porcelain)" ]; then
      log "Local changes detected. Stashing..."
      git -C "$REPO_DIR" stash push -u -m "bootstrap auto-stash $(date +%F-%H%M%S)"
      AUTO_STASHED=1
    else
      AUTO_STASHED=0
    fi
    git -C "$REPO_DIR" fetch --all --prune
    git -C "$REPO_DIR" checkout main
    git -C "$REPO_DIR" pull --ff-only
    if [ "${AUTO_STASHED:-0}" = "1" ]; then
      log "Re-applying stashed changes..."
      git -C "$REPO_DIR" stash pop || log "WARN: stash pop had conflicts. Resolve them in $REPO_DIR."
    fi
  else
    log "Cloning repo..."
    git clone "$REPO_URL" "$REPO_DIR"
  fi
}

main() {
  log "----------------------------------"
  log "Dotfiles Bootstrap (remote entrypoint)"
  log "Repo:   $REPO_URL"
  log "Target: $REPO_DIR"
  log "----------------------------------"

  if ! need_cmd git || ! need_cmd curl; then
    log "Installing minimal dependencies..."
    install_min_deps
  fi

  clone_or_update_repo

  local root_bootstrap="$REPO_DIR/bootstrap.sh"
  [ -f "$root_bootstrap" ] || { log "ERROR: $root_bootstrap not found"; exit 1; }
  chmod +x "$root_bootstrap" || true

  log "Handing off to root orchestrator..."
  exec bash "$root_bootstrap" "$@"
}

main "$@"
