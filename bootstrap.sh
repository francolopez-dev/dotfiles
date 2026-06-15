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
#   ./bootstrap.sh [--dry-run] [--profile NAME] [--enforce] [--adopt] [--log FILE]
#
#   --dry-run      print intended actions, mutate nothing
#   --profile NAME use/persist this profile (else interactive / saved / minimal)
#   --enforce      additionally remove packages not declared by the profile
#                  (destructive, prompts for confirmation)
#   --adopt        let stow adopt existing real files (review the git diff after)
#   --log FILE     tee output here (default ~/.cache/dotfiles/bootstrap-<ts>.log)
#
# Idempotent and safe to re-run.
# ============================================================

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
export REPO_DIR
SCRIPTS="$REPO_DIR/scripts"
. "$SCRIPTS/lib.sh"

DRY_RUN=0
PROFILE_ARG=""
ENFORCE=0
ADOPT=0
LOG_FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --profile) PROFILE_ARG="${2:-}"; shift 2 ;;
    --profile=*) PROFILE_ARG="${1#*=}"; shift ;;
    --enforce) ENFORCE=1; shift ;;
    --adopt) ADOPT=1; shift ;;
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
if [ -z "$LOG_FILE" ]; then
  LOG_FILE="$HOME/.cache/dotfiles/bootstrap-$(date +%F-%H%M%S).log"
fi
mkdir -p "$(dirname "$LOG_FILE")"
# Mirror all output to the log while keeping it on the terminal.
exec > >(tee -a "$LOG_FILE") 2>&1

log ""
info "Personal Platform bootstrap"
[ "$DRY_RUN" = "1" ] && warn "DRY-RUN mode: no changes will be made."
info "Repo: $REPO_DIR"
info "Log:  $LOG_FILE"

# 1) Detect OS
read -r OS PKGMGR < <(bash "$SCRIPTS/detect-os.sh")
ok "Detected OS: $OS (pkg manager: $PKGMGR)"

# 2) Select profile (persisted to ~/.config/dotfiles/profile)
profile_args=()
[ -n "$PROFILE_ARG" ] && profile_args=(--profile "$PROFILE_ARG")
PROFILE="$(bash "$SCRIPTS/select-profile.sh" "${profile_args[@]}")"
ok "Profile: $PROFILE"

# 3) Install packages
pkg_args=(--profile "$PROFILE" --os "$OS" --pkgmgr "$PKGMGR")
[ "$ENFORCE" = "1" ] && pkg_args+=(--enforce)
bash "$SCRIPTS/install-packages.sh" "${pkg_args[@]}"

# 4) Apply stow
stow_args=(--profile "$PROFILE")
[ "$ADOPT" = "1" ] && stow_args+=(--adopt)
bash "$SCRIPTS/apply-stow.sh" "${stow_args[@]}"

# 5) Enable services
bash "$SCRIPTS/enable-services.sh" --profile "$PROFILE" --os "$OS"

# 6) (Phase 3) setup-syncing — not yet implemented.

log ""
ok "Bootstrap complete for profile '$PROFILE' on $OS."
[ "$DRY_RUN" = "1" ] && info "That was a dry run. Re-run without --dry-run to apply."
info "Open a new terminal or run: exec zsh"
