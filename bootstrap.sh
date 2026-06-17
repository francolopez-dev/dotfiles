#!/usr/bin/env bash
set -euo pipefail
# ============================================================
# Personal Platform — root orchestrator ("the one command")
#
# Runs, in order:
#   detect-os -> select-profile -> install-packages -> apply-stow -> enable-services
# (setup-syncing arrives in Phase 3.)
#
# Usage:
#   ./bootstrap.sh [--dry-run] [--profile NAME] [--first-time] [--enforce] [--adopt] [--backup-conflicts] [--log FILE]
#
#   --dry-run      print intended actions, mutate nothing
#   --profile NAME use/persist this profile unless --dry-run is set
#   --first-time   run the first-run profile wizard even if a profile is saved
#   --enforce      additionally remove packages not declared by the profile
#                  (destructive, prompts for confirmation)
#   --adopt        let stow adopt existing real files (review the git diff after)
#   --backup-conflicts
#                  back up stow conflicts instead of prompting/skipping
#   --log FILE     tee output here (default ~/.cache/dotfiles/bootstrap-<ts>.log)
#
# Idempotent and safe to re-run.
# ============================================================

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
export REPO_DIR
SCRIPTS="$REPO_DIR/scripts"
# shellcheck source=scripts/lib.sh
. "$SCRIPTS/lib.sh"

DRY_RUN="${DOTFILES_DRY_RUN:-0}"
PROFILE_ARG="${DOTFILES_PROFILE:-}"
ENFORCE=0
ADOPT=0
BACKUP_CONFLICTS="${DOTFILES_BACKUP_CONFLICTS:-0}"
FIRST_TIME="${DOTFILES_FIRST_TIME:-0}"
LOG_FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --profile) PROFILE_ARG="${2:-}"; shift 2 ;;
    --profile=*) PROFILE_ARG="${1#*=}"; shift ;;
    --first-time|--reconfigure) FIRST_TIME=1; shift ;;
    --enforce) ENFORCE=1; shift ;;
    --adopt) ADOPT=1; shift ;;
    --backup-conflicts) BACKUP_CONFLICTS=1; shift ;;
    --log) LOG_FILE="${2:-}"; shift 2 ;;
    --log=*) LOG_FILE="${1#*=}"; shift ;;
    -h|--help)
      sed -n '2,30p' "$0"; exit 0 ;;
    *) die "unknown argument: $1 (try --help)" ;;
  esac
done
export DRY_RUN

# -----------------------------
# Logging to file (tee)
# -----------------------------
if [ -z "$LOG_FILE" ] && [ "$DRY_RUN" != "1" ]; then
  LOG_FILE="$HOME/.cache/dotfiles/bootstrap-$(date +%F-%H%M%S).log"
fi
if [ -n "$LOG_FILE" ]; then
  mkdir -p "$(dirname "$LOG_FILE")"
  # Mirror all output to the log while keeping it on the terminal.
  exec > >(tee -a "$LOG_FILE") 2>&1
fi

log ""
info "Personal Platform bootstrap"
[ "$DRY_RUN" = "1" ] && warn "DRY-RUN mode: no changes will be made."
info "Repo: $REPO_DIR"
if [ -n "$LOG_FILE" ]; then
  info "Log:  $LOG_FILE"
else
  info "Log:  <disabled for dry-run>"
fi

# 1) Detect OS
read -r OS PKGMGR < <(bash "$SCRIPTS/detect-os.sh")
ok "Detected OS: $OS (pkg manager: $PKGMGR)"

# 2) Select profile (persisted to ~/.config/dotfiles/profile)
profile_args=()
[ -n "$PROFILE_ARG" ] && profile_args=(--profile "$PROFILE_ARG")
[ "$FIRST_TIME" = "1" ] && profile_args+=(--first-time)
[ "$DRY_RUN" = "1" ] && profile_args+=(--no-persist)
PROFILE="$(bash "$SCRIPTS/select-profile.sh" --os "$OS" "${profile_args[@]}")"
ok "Profile: $PROFILE"

# Validate selected profile before mutating the machine.
bash "$SCRIPTS/validate-profiles.sh" --profile "$PROFILE" || die "Profile validation failed: $PROFILE"
ok "Profile validation passed: $PROFILE"

# 3) Install packages
pkg_args=(--profile "$PROFILE" --os "$OS" --pkgmgr "$PKGMGR")
[ "$ENFORCE" = "1" ] && pkg_args+=(--enforce)
bash "$SCRIPTS/install-packages.sh" "${pkg_args[@]}"

# 4) Clean stale incompatible stow links from older profile mistakes.
bash "$SCRIPTS/cleanup-stale-stow-links.sh" --os "$OS"

# 5) Apply stow
stow_args=(--profile "$PROFILE" --os "$OS")
[ "$ADOPT" = "1" ] && stow_args+=(--adopt)
[ "$BACKUP_CONFLICTS" = "1" ] && stow_args+=(--backup-conflicts)
bash "$SCRIPTS/apply-stow.sh" "${stow_args[@]}"

# 6) Enable services
bash "$SCRIPTS/enable-services.sh" --profile "$PROFILE" --os "$OS"

# 7) (Phase 3) setup-syncing — not yet implemented.

log ""
ok "Bootstrap complete for profile '$PROFILE' on $OS."
[ "$DRY_RUN" = "1" ] && info "That was a dry run. Re-run without --dry-run to apply."
info "Open a new terminal or run: exec zsh"
