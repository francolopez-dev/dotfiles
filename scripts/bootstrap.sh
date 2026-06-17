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
UPDATE_MODE="${DOTFILES_UPDATE_MODE:-safe}"
CONFIRM_RESET="${DOTFILES_CONFIRM_RESET:-0}"
FORWARD_ARGS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --auto-stash) UPDATE_MODE="stash"; shift ;;
    *) FORWARD_ARGS+=("$1"); shift ;;
  esac
done

if [ -z "${DOTFILES_UPDATE_MODE:-}" ] && [ "${DOTFILES_BOOTSTRAP_AUTO_STASH:-0}" = "1" ]; then
  UPDATE_MODE="stash"
fi

[ -n "${DOTFILES_PROFILE:-}" ] && FORWARD_ARGS+=(--profile "$DOTFILES_PROFILE")
[ "${DOTFILES_FIRST_TIME:-0}" = "1" ] && FORWARD_ARGS+=(--first-time)
[ "${DOTFILES_BACKUP_CONFLICTS:-0}" = "1" ] && FORWARD_ARGS+=(--backup-conflicts)
[ "${DOTFILES_DRY_RUN:-0}" = "1" ] && FORWARD_ARGS+=(--dry-run)

log() { printf "%s\n" "$*"; }
need_cmd() { command -v "$1" >/dev/null 2>&1; }

validate_update_mode() {
  case "$UPDATE_MODE" in
    safe|stash|stash-rebase|reset) return 0 ;;
    *)
      log "ERROR: Unsupported DOTFILES_UPDATE_MODE: $UPDATE_MODE"
      log "Supported modes: safe, stash, stash-rebase, reset"
      exit 1
      ;;
  esac
}

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
    update_existing_repo
  else
    log "Cloning repo..."
    git clone "$REPO_URL" "$REPO_DIR"
  fi
}

current_branch() {
  git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || printf "unknown\n"
}

dirty_status() {
  if [ -n "$(git -C "$REPO_DIR" status --porcelain)" ]; then
    printf "yes\n"
  else
    printf "no\n"
  fi
}

ahead_behind() {
  git -C "$REPO_DIR" rev-list --left-right --count origin/main...HEAD
}

print_update_state() {
  local branch="$1" dirty="$2" behind="$3" ahead="$4"
  log "Update state:"
  log "  branch: $branch"
  log "  dirty working tree: $dirty"
  log "  behind origin/main: $behind"
  log "  ahead of origin/main: $ahead"
}

block_update() {
  local reason="$1" branch="$2" dirty="$3" behind="$4" ahead="$5" suggestion="$6"
  log "ERROR: $reason"
  print_update_state "$branch" "$dirty" "$behind" "$ahead"
  log "Refusing to update so local work is not hidden or overwritten."
  log "Suggested command:"
  log "  $suggestion"
  exit 1
}

stash_dirty() {
  local label="$1"
  if [ "$(dirty_status)" = "yes" ]; then
    log "Local changes detected. Stashing because update mode is '$UPDATE_MODE'..."
    git -C "$REPO_DIR" stash push -u -m "bootstrap $label $(date +%F-%H%M%S)"
    AUTO_STASHED=1
  else
    AUTO_STASHED=0
  fi
}

pop_stash_if_needed() {
  if [ "${AUTO_STASHED:-0}" = "1" ]; then
    log "Re-applying stashed changes..."
    if ! git -C "$REPO_DIR" stash pop; then
      log "ERROR: stash pop had conflicts. Resolve them in $REPO_DIR, then rerun bootstrap."
      exit 1
    fi
  fi
}

update_existing_repo() {
  local branch dirty behind ahead
  log "Repo exists. Updating with mode: $UPDATE_MODE"
  git -C "$REPO_DIR" fetch --prune origin main

  branch="$(current_branch)"
  dirty="$(dirty_status)"
  read -r behind ahead < <(ahead_behind)

  if [ "$branch" != "main" ]; then
    block_update \
      "Current branch is not main." \
      "$branch" "$dirty" "$behind" "$ahead" \
      "cd $REPO_DIR && git checkout main"
  fi

  case "$UPDATE_MODE" in
    safe)
      [ "$dirty" = "no" ] || block_update \
        "Working tree has local changes." \
        "$branch" "$dirty" "$behind" "$ahead" \
        "cd $REPO_DIR && git status --short"
      if [ "$ahead" != "0" ] && [ "$behind" != "0" ]; then
        block_update \
          "Branch has diverged from origin/main." \
          "$branch" "$dirty" "$behind" "$ahead" \
          "DOTFILES_UPDATE_MODE=stash-rebase curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | bash"
      fi
      [ "$ahead" = "0" ] || block_update \
        "Branch has unpushed local commits." \
        "$branch" "$dirty" "$behind" "$ahead" \
        "DOTFILES_UPDATE_MODE=stash-rebase curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | bash"
      if [ "$behind" != "0" ]; then
        log "Fast-forwarding main from origin/main..."
        git -C "$REPO_DIR" merge --ff-only origin/main
      else
        log "Repo is already up to date."
      fi
      ;;
    stash)
      if [ "$ahead" != "0" ] && [ "$behind" != "0" ]; then
        block_update \
          "Branch has diverged from origin/main; stash mode does not rebase commits." \
          "$branch" "$dirty" "$behind" "$ahead" \
          "DOTFILES_UPDATE_MODE=stash-rebase curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | bash"
      fi
      [ "$ahead" = "0" ] || block_update \
        "Branch has unpushed local commits; stash mode does not rebase commits." \
        "$branch" "$dirty" "$behind" "$ahead" \
        "DOTFILES_UPDATE_MODE=stash-rebase curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | bash"
      stash_dirty "auto-stash"
      if [ "$behind" != "0" ]; then
        log "Fast-forwarding main from origin/main..."
        git -C "$REPO_DIR" merge --ff-only origin/main
      else
        log "Repo is already up to date."
      fi
      pop_stash_if_needed
      ;;
    stash-rebase)
      stash_dirty "stash-rebase"
      if [ "$ahead" != "0" ] || [ "$behind" != "0" ]; then
        log "Rebasing local commits onto origin/main..."
        if ! git -C "$REPO_DIR" rebase origin/main; then
          log "ERROR: rebase had conflicts. Resolve them in $REPO_DIR, then run git rebase --continue or git rebase --abort."
          exit 1
        fi
      else
        log "Repo is already up to date."
      fi
      pop_stash_if_needed
      ;;
    reset)
      if [ "$CONFIRM_RESET" != "1" ]; then
        block_update \
          "Reset mode requires DOTFILES_CONFIRM_RESET=1." \
          "$branch" "$dirty" "$behind" "$ahead" \
          "DOTFILES_UPDATE_MODE=reset DOTFILES_CONFIRM_RESET=1 curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | bash"
      fi
      log "WARNING: Reset mode discards local commits and working-tree changes."
      log "Resetting main to origin/main..."
      git -C "$REPO_DIR" reset --hard origin/main
      git -C "$REPO_DIR" clean -fd
      ;;
  esac
}

main() {
  log "----------------------------------"
  log "Dotfiles Bootstrap (remote entrypoint)"
  log "Repo:   $REPO_URL"
  log "Target: $REPO_DIR"
  log "Update: $UPDATE_MODE"
  log "----------------------------------"
  validate_update_mode

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
