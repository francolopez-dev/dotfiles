#!/usr/bin/env bash
set -euo pipefail
# Set up a profile's sync agents (Phase 3A).
#
# Usage:
#   setup-syncing.sh --profile NAME --os OS
#
# Reads the profile's optional SYNC=() array. Empty/unset -> info + no-op.
# Honors DRY_RUN=1. Everything here is idempotent, non-destructive, and never
# performs an interactive login or stores credentials.
#
# Adding a new sync agent = add one `case` branch below AND list it in the
# profile's SYNC=() array. Nothing else to wire up.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=scripts/lib.sh
. "$SCRIPT_DIR/lib.sh"

PROFILES_DIR="${PROFILES_DIR:-$REPO_DIR/profiles}"

PROFILE="" OS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --profile) PROFILE="${2:-}"; shift 2 ;;
    --profile=*) PROFILE="${1#*=}"; shift ;;
    --os)      OS="${2:-}";      shift 2 ;;
    --os=*)    OS="${1#*=}";     shift ;;
    *) die "setup-syncing: unknown arg: $1" ;;
  esac
done
[ -n "$PROFILE" ] || die "setup-syncing: --profile required"

SYNC=()
# shellcheck source=/dev/null
. "$PROFILES_DIR/$PROFILE.conf"

setup_one() {
  local agent="$1"
  case "$agent" in
    tailscale)
      if need_cmd tailscale && tailscale status >/dev/null 2>&1; then
        info "tailscale: already up."
      else
        info "tailscale: not connected. To join your tailnet, run: sudo tailscale up"
      fi
      ;;
    syncthing)
      info "syncthing: ensuring ~/.config/syncthing exists (enable the service via SERVICES)."
      run mkdir -p "$HOME/.config/syncthing"
      ;;
    atuin)
      if ! need_cmd atuin; then
        info "atuin: not installed; add it to a package group first."
      elif atuin status >/dev/null 2>&1; then
        info "atuin: already logged in and syncing."
      else
        info "atuin: to enable shell-history sync, run: atuin login && atuin sync"
      fi
      ;;
    *)
      warn "setup-syncing: unknown sync agent '$agent' (skipping)."
      ;;
  esac
}

main() {
  if [ "${#SYNC[@]}" -eq 0 ]; then
    info "No sync agents declared for profile '$PROFILE'."
    return 0
  fi
  info "Sync agents for profile '$PROFILE' (os=$OS): ${SYNC[*]}"
  local agent
  for agent in "${SYNC[@]}"; do
    setup_one "$agent"
  done
  ok "Sync step complete."
}

main
