#!/usr/bin/env bash
set -euo pipefail
# ============================================================
# Remote curl entrypoint:
#   curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | bash
#
# Installs minimal deps (git, curl, ca-certificates), clones/updates the repo,
# then hands off to the repo-root ./bootstrap.sh orchestrator.
#
# Supports exactly the four target OSes: omarchy / macos / debian / ubuntu.
# Any extra args are forwarded to the root bootstrap unless consumed here.
# ============================================================

REPO_URL="${REPO_URL:-https://github.com/jfrancolopez/dotfiles.git}"
REPO_DIR="${REPO_DIR:-$HOME/dotfiles}"
UPDATE_REPO_URL="${UPDATE_REPO_URL:-https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/update-repo.sh}"
UPDATE_MODE="${DOTFILES_UPDATE_MODE:-safe}"
CONFIRM_RESET="${DOTFILES_CONFIRM_RESET:-0}"
FORWARD_ARGS=()
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"

# Track whether a CLI flag set the mode, so legacy env fallback does not override it.
FLAG_SET_MODE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --update-mode) UPDATE_MODE="${2:-}"; FLAG_SET_MODE=1; shift 2 ;;
    --update-mode=*) UPDATE_MODE="${1#*=}"; FLAG_SET_MODE=1; shift ;;
    --confirm-reset) CONFIRM_RESET=1; shift ;;
    --auto-stash) UPDATE_MODE="stash"; FLAG_SET_MODE=1; shift ;;
    *) FORWARD_ARGS+=("$1"); shift ;;
  esac
done

# Legacy fallback: only fires when neither DOTFILES_UPDATE_MODE nor a CLI flag set a mode.
if [ -z "${DOTFILES_UPDATE_MODE:-}" ] && [ "$FLAG_SET_MODE" = "0" ] && [ "${DOTFILES_BOOTSTRAP_AUTO_STASH:-0}" = "1" ]; then
  UPDATE_MODE="stash"
fi

[ -n "${DOTFILES_PROFILE:-}" ] && FORWARD_ARGS+=(--profile "$DOTFILES_PROFILE")
[ "${DOTFILES_FIRST_TIME:-0}" = "1" ] && FORWARD_ARGS+=(--first-time)
[ "${DOTFILES_BACKUP_CONFLICTS:-0}" = "1" ] && FORWARD_ARGS+=(--backup-conflicts)
[ "${DOTFILES_DRY_RUN:-0}" = "1" ] && FORWARD_ARGS+=(--dry-run)

log() { printf "%s\n" "$*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

is_omarchy_host() {
  [ "${DOTFILES_ASSUME_OMARCHY:-0}" = "1" ] && return 0
  [ "${ID:-}" = "omarchy" ] && return 0
  [ -f /etc/omarchy-release ] && return 0
  [ -d /usr/share/omarchy ] && return 0
  [ -d "$HOME/.local/share/omarchy" ] && return 0
  return 1
}

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
        if ! is_omarchy_host; then
          log "ERROR: Arch-like OS detected, but Omarchy markers were not found."
          log "Supported Arch target is Omarchy. Set DOTFILES_ASSUME_OMARCHY=1 to force."
          exit 1
        fi
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
    load_update_repo
    validate_update_mode
    update_existing_repo
  else
    log "Cloning repo..."
    git clone "$REPO_URL" "$REPO_DIR"
  fi
}

load_update_repo() {
  local helper=""
  if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/update-repo.sh" ]; then
    helper="$SCRIPT_DIR/update-repo.sh"
  elif [ -f "$REPO_DIR/scripts/update-repo.sh" ]; then
    helper="$REPO_DIR/scripts/update-repo.sh"
  else
    helper="${TMPDIR:-/tmp}/dotfiles-update-repo.$$.$RANDOM.sh"
    log "Fetching update helper..."
    curl -fsSL "$UPDATE_REPO_URL" -o "$helper"
  fi
  # shellcheck source=scripts/update-repo.sh
  . "$helper"
}

main() {
  log "----------------------------------"
  log "Dotfiles Bootstrap (remote entrypoint)"
  log "Repo:   $REPO_URL"
  log "Target: $REPO_DIR"
  log "Update: $UPDATE_MODE"
  log "----------------------------------"

  if ! need_cmd git || ! need_cmd curl; then
    log "Installing minimal dependencies..."
    install_min_deps
  fi

  clone_or_update_repo

  if [ "${DOTFILES_BOOTSTRAP_SKIP_HANDOFF:-0}" = "1" ]; then
    log "Skipping root orchestrator handoff because DOTFILES_BOOTSTRAP_SKIP_HANDOFF=1."
    exit 0
  fi

  local root_bootstrap="$REPO_DIR/bootstrap.sh"
  [ -f "$root_bootstrap" ] || { log "ERROR: $root_bootstrap not found"; exit 1; }
  chmod +x "$root_bootstrap" || true

  log "Handing off to root orchestrator..."
  exec bash "$root_bootstrap" "${FORWARD_ARGS[@]}"
}

main
