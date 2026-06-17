#!/usr/bin/env bash
set -euo pipefail
# Validate profile declarations against package groups, stow packages, and known services.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=scripts/lib.sh
. "$SCRIPT_DIR/lib.sh"

PROFILES_DIR="${PROFILES_DIR:-$REPO_DIR/profiles}"
PACKAGES_DIR="${PACKAGES_DIR:-$REPO_DIR/packages}"
STOW_DIR="${STOW_DIR:-$REPO_DIR/stow}"

PROFILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --profile) PROFILE="${2:-}"; shift 2 ;;
    --profile=*) PROFILE="${1#*=}"; shift ;;
    *) die "validate-profiles: unknown arg: $1" ;;
  esac
done

known_service() {
  case "$1" in
    tailscale|syncthing|libvirtd|borders) return 0 ;;
    *) return 1 ;;
  esac
}

validate_one() {
  local profile_file="$1" profile fail=0 item
  profile="$(basename "$profile_file" .conf)"

  PACKAGE_GROUPS=()
  STOW_PACKAGES=()
  SERVICES=()
  # shellcheck source=/dev/null
  if ! . "$profile_file"; then
    err "$profile: could not source profile"
    return 1
  fi
  declare -p PACKAGE_GROUPS >/dev/null 2>&1 || PACKAGE_GROUPS=()
  declare -p STOW_PACKAGES >/dev/null 2>&1 || STOW_PACKAGES=()
  declare -p SERVICES >/dev/null 2>&1 || SERVICES=()

  set +u
  for item in "${PACKAGE_GROUPS[@]}"; do
    if [ ! -d "$PACKAGES_DIR/$item" ]; then
      err "$profile: missing package group: $item"
      fail=1
    fi
  done

  for item in "${STOW_PACKAGES[@]}"; do
    if [ ! -d "$STOW_DIR/$item" ]; then
      err "$profile: missing stow package: $item"
      fail=1
    fi
  done

  for item in "${SERVICES[@]}"; do
    if ! known_service "$item"; then
      err "$profile: unknown service: $item"
      fail=1
    fi
  done
  set -u

  if [ "$fail" = "0" ]; then
    ok "$profile: PASS"
  else
    err "$profile: FAIL"
  fi
  return "$fail"
}

main() {
  local files=() f failures=0
  if [ -n "$PROFILE" ]; then
    [ -f "$PROFILES_DIR/$PROFILE.conf" ] || die "Unknown profile: $PROFILE"
    files=("$PROFILES_DIR/$PROFILE.conf")
  else
    for f in "$PROFILES_DIR"/*.conf; do
      [ -e "$f" ] || continue
      files+=("$f")
    done
  fi

  [ "${#files[@]}" -gt 0 ] || die "No profiles found in $PROFILES_DIR"
  for f in "${files[@]}"; do
    validate_one "$f" || failures=1
  done
  return "$failures"
}

main
