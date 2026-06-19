#!/usr/bin/env bash
set -euo pipefail
# Enable a profile's SERVICES.
#   - Linux: systemctl (system services) with a --user fallback
#   - macOS: brew services
#
# Usage:
#   enable-services.sh --profile NAME --os OS
#
# Honors DRY_RUN=1. Unknown/unsupported services warn and are skipped.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=scripts/lib.sh
. "$SCRIPT_DIR/lib.sh"

PROFILES_DIR="${PROFILES_DIR:-$REPO_DIR/profiles}"

PROFILE="" OS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --profile) PROFILE="${2:-}"; shift 2 ;;
    --os)      OS="${2:-}";      shift 2 ;;
    *) die "enable-services: unknown arg: $1" ;;
  esac
done
[ -n "$PROFILE" ] || die "enable-services: --profile required"

SERVICES=()
# shellcheck source=/dev/null
. "$PROFILES_DIR/$PROFILE.conf"

system_unit_for() {
  local svc="$1"
  case "$OS:$svc" in
    omarchy:tailscale|debian:tailscale|ubuntu:tailscale) printf "tailscaled.service\n" ;;
    omarchy:ssh) printf "sshd.service\n" ;;
    debian:ssh|ubuntu:ssh) printf "ssh.service\n" ;;
    *:libvirtd) printf "libvirtd.service\n" ;;
    *) printf "%s.service\n" "$svc" ;;
  esac
}

user_unit_for() {
  local svc="$1"
  case "$svc" in
    syncthing) printf "syncthing.service\n" ;;
    *) printf "%s.service\n" "$svc" ;;
  esac
}

system_unit_exists() {
  local unit="$1"
  if systemctl list-unit-files "$unit" 2>/dev/null | grep -q "^${unit}[[:space:]]"; then
    return 0
  fi
  systemctl cat "$unit" >/dev/null 2>&1 && return 0
  [ -f "/etc/systemd/system/$unit" ] && return 0
  [ -f "/usr/lib/systemd/system/$unit" ] && return 0
  [ -f "/lib/systemd/system/$unit" ] && return 0
  return 1
}

user_unit_exists() {
  local unit="$1"
  if systemctl --user list-unit-files "$unit" 2>/dev/null | grep -q "^${unit}[[:space:]]"; then
    return 0
  fi
  systemctl --user cat "$unit" >/dev/null 2>&1 && return 0
  [ -f "$HOME/.config/systemd/user/$unit" ] && return 0
  [ -f "/usr/lib/systemd/user/$unit" ] && return 0
  [ -f "/lib/systemd/user/$unit" ] && return 0
  return 1
}

warn_missing_unit() {
  local svc="$1" system_unit="$2" user_unit="$3"
  warn "service unit not found for: $svc"
  warn "checked system unit: $system_unit"
  warn "checked user unit:   $user_unit"
  warn "diagnostics: systemctl list-unit-files '$system_unit'; systemctl cat '$system_unit'"
}

enable_linux() {
  local svc="$1" system_unit user_unit
  system_unit="$(system_unit_for "$svc")"
  user_unit="$(user_unit_for "$svc")"

  if [ "$DRY_RUN" = "1" ]; then
    info "Enabling (system): $svc -> $system_unit"
    run sudo systemctl enable --now "$system_unit"
    return 0
  fi

  need_cmd systemctl || { warn "systemctl not found; cannot enable $svc -> $system_unit"; return 0; }
  if system_unit_exists "$system_unit"; then
    info "Enabling (system): $svc -> $system_unit"
    run sudo systemctl daemon-reload || true
    run sudo systemctl enable --now "$system_unit" || warn "could not enable system service: $svc -> $system_unit"
  elif user_unit_exists "$user_unit"; then
    info "Enabling (user): $svc -> $user_unit"
    run systemctl --user enable --now "$user_unit" || warn "could not enable user service: $svc -> $user_unit"
  else
    warn_missing_unit "$svc" "$system_unit" "$user_unit"
  fi
}

enable_macos() {
  local svc="$1"
  need_cmd brew || { warn "brew not found; cannot manage service $svc"; return 0; }
  if brew services list 2>/dev/null | grep -q "^${svc} "; then
    info "Restarting (brew): $svc"
    run brew services restart "$svc" || warn "could not restart: $svc"
  else
    info "Starting (brew): $svc"
    run brew services start "$svc" || warn "could not start: $svc"
  fi
}

main() {
  if [ "${#SERVICES[@]}" -eq 0 ]; then
    info "No services declared for profile '$PROFILE'."
    return 0
  fi
  info "Services for profile '$PROFILE': ${SERVICES[*]}"
  local svc
  for svc in "${SERVICES[@]}"; do
    case "$OS" in
      macos) enable_macos "$svc" ;;
      omarchy|debian|ubuntu) enable_linux "$svc" ;;
      *) warn "unknown OS '$OS'; skipping service $svc" ;;
    esac
  done
  ok "Service step complete."
}

main
