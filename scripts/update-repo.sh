#!/usr/bin/env bash
set -euo pipefail
# ============================================================
# scripts/update-repo.sh — git fetch/ff/stash/rebase/reset for the dotfiles repo.
#
# Used by both `scripts/bootstrap.sh` (remote curl entrypoint) and
# `dotfiles update` (in-repo CLI). Sourceable (defines functions) or executable.
#
# Usage when executed:
#   scripts/update-repo.sh --mode safe|stash|stash-rebase|reset [--confirm-reset]
#
# Honors:
#   REPO_DIR          path to the local dotfiles repo (default $HOME/dotfiles)
# ============================================================

REPO_DIR="${REPO_DIR:-$HOME/dotfiles}"

# Provide a minimal log() if one isn't already defined by the caller.
if ! declare -F log >/dev/null 2>&1; then
  log() { printf "%s\n" "$*"; }
fi

validate_update_mode() {
  case "${UPDATE_MODE:-}" in
    safe|stash|stash-rebase|reset) return 0 ;;
    *)
      log "ERROR: Unsupported update mode: ${UPDATE_MODE:-}"
      log "Supported modes: safe, stash, stash-rebase, reset"
      exit 1
      ;;
  esac
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
          "curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | DOTFILES_UPDATE_MODE=stash-rebase bash"
      fi
      [ "$ahead" = "0" ] || block_update \
        "Branch has unpushed local commits." \
        "$branch" "$dirty" "$behind" "$ahead" \
        "curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | DOTFILES_UPDATE_MODE=stash-rebase bash"
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
          "curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | DOTFILES_UPDATE_MODE=stash-rebase bash"
      fi
      [ "$ahead" = "0" ] || block_update \
        "Branch has unpushed local commits; stash mode does not rebase commits." \
        "$branch" "$dirty" "$behind" "$ahead" \
        "curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | DOTFILES_UPDATE_MODE=stash-rebase bash"
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
      if [ "${CONFIRM_RESET:-0}" != "1" ]; then
        block_update \
          "Reset mode requires DOTFILES_CONFIRM_RESET=1." \
          "$branch" "$dirty" "$behind" "$ahead" \
          "curl -fsSL https://raw.githubusercontent.com/jfrancolopez/dotfiles/main/scripts/bootstrap.sh | DOTFILES_UPDATE_MODE=reset DOTFILES_CONFIRM_RESET=1 bash"
      fi
      log "WARNING: Reset mode discards local commits and working-tree changes."
      log "Resetting main to origin/main..."
      git -C "$REPO_DIR" reset --hard origin/main
      git -C "$REPO_DIR" clean -fd
      ;;
  esac
}

# Run only when executed directly, not when sourced.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  UPDATE_MODE="${UPDATE_MODE:-safe}"
  CONFIRM_RESET="${CONFIRM_RESET:-0}"
  while [ $# -gt 0 ]; do
    case "$1" in
      --mode) UPDATE_MODE="${2:-}"; shift 2 ;;
      --mode=*) UPDATE_MODE="${1#*=}"; shift ;;
      --confirm-reset) CONFIRM_RESET=1; shift ;;
      *) log "update-repo.sh: unknown argument: $1"; exit 2 ;;
    esac
  done
  [ -d "$REPO_DIR/.git" ] || { log "ERROR: $REPO_DIR is not a git repo"; exit 1; }
  validate_update_mode
  update_existing_repo
fi
