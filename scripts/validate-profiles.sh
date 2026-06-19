#!/usr/bin/env bash
set -euo pipefail
# Validate profile declarations against package groups, stow packages, and known services.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=scripts/lib.sh
. "$SCRIPT_DIR/lib.sh"

PROFILES_DIR="${PROFILES_DIR:-$REPO_DIR/profiles}"
PACKAGES_DIR="${PACKAGES_DIR:-$REPO_DIR/packages}"
STOW_DIR="${STOW_DIR:-$REPO_DIR/stow}"
STOW_OS_MAP="${STOW_OS_MAP:-$PROFILES_DIR/stow-os.map}"
STOW_BASE="${STOW_BASE:-$PROFILES_DIR/stow-base}"
STOW_OS_BASE="${STOW_OS_BASE:-$PROFILES_DIR/stow-os-base}"

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

known_sync_agent() {
  case "$1" in
    tailscale|syncthing|atuin) return 0 ;;
    *) return 1 ;;
  esac
}

optional_array() {
  local profile="$1" name="$2" decl
  if ! decl="$(declare -p "$name" 2>/dev/null)"; then
    return 0
  fi
  case "$decl" in
    declare\ -a*) return 0 ;;
    *)
      err "$profile: $name must be an array"
      return 1
      ;;
  esac
}

optional_number() {
  local profile="$1" name="$2" value
  value="${!name:-}"
  [ -z "$value" ] && return 0
  case "$value" in
    *[!0-9]*) err "$profile: $name must be a positive integer"; return 1 ;;
    *) return 0 ;;
  esac
}

profile_os() {
  case "$1" in
    desktop-personal-omarchy|desktop-work-omarchy|laptop-personal-omarchy|laptop-work-omarchy) printf "omarchy\n" ;;
    personal-macos|work-macos) printf "macos\n" ;;
    server-debian) printf "debian\n" ;;
    server-ubuntu) printf "ubuntu\n" ;;
    minimal) printf "any\n" ;;
    *) printf "unknown\n" ;;
  esac
}

require_array() {
  local profile="$1" name="$2" decl
  if ! decl="$(declare -p "$name" 2>/dev/null)"; then
    err "$profile: missing required array: $name"
    return 1
  fi
  case "$decl" in
    declare\ -a*) return 0 ;;
    *)
      err "$profile: $name must be an array"
      return 1
      ;;
  esac
}

map_os_for_pkg() {
  local pkg="$1" key oses
  while read -r key oses; do
    [ "$key" = "$pkg" ] || continue
    printf "%s\n" "$oses"
    return 0
  done < <(read_map "$STOW_OS_MAP")
  printf "all\n"
}

os_list_contains() {
  local oses="$1" wanted="$2" os
  [ "$wanted" = "any" ] && return 0
  [ "$oses" = "all" ] && return 0
  IFS=',' read -r -a _os_parts <<< "$oses"
  for os in "${_os_parts[@]}"; do
    [ "$os" = "$wanted" ] && return 0
  done
  return 1
}

validate_one() {
  local profile_file="$1" profile os fail=0 item oses
  profile="$(basename "$profile_file" .conf)"
  os="$(profile_os "$profile")"

  unset PACKAGE_GROUPS STOW_PACKAGES SERVICES SYNC DISPLAY_MODES HARDWARE_PACKAGE_GROUPS
  STOW_PACKAGES=()
  SYNC=()
  # shellcheck source=/dev/null
  if ! . "$profile_file"; then
    err "$profile: could not source profile"
    return 1
  fi

  require_array "$profile" PACKAGE_GROUPS || fail=1
  require_array "$profile" SERVICES || fail=1
  # STOW_PACKAGES and SYNC are optional now (shared dotfiles live in stow-base /
  # stow-os-base). Default them above so unset is fine; if declared, must be arrays.
  if declare -p STOW_PACKAGES >/dev/null 2>&1; then
    require_array "$profile" STOW_PACKAGES || fail=1
  fi
  if declare -p SYNC >/dev/null 2>&1; then
    require_array "$profile" SYNC || fail=1
  fi
  optional_array "$profile" DISPLAY_MODES || fail=1
  optional_array "$profile" HARDWARE_PACKAGE_GROUPS || fail=1
  optional_number "$profile" QUICK_SURFACE_NOTES_WIDTH_PERCENT || fail=1
  optional_number "$profile" QUICK_SURFACE_QUAKE_HEIGHT_PERCENT || fail=1
  optional_number "$profile" QUICK_SURFACE_TOP_OFFSET || fail=1
  optional_number "$profile" QUICK_SURFACE_BOTTOM_OFFSET || fail=1
  [ "$fail" = "0" ] || { err "$profile: FAIL"; return 1; }

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
      continue
    fi
    oses="$(map_os_for_pkg "$item")"
    if ! os_list_contains "$oses" "$os"; then
      err "$profile: stow package '$item' is ${oses}-only but profile OS is $os"
      fail=1
    fi
  done

  for item in "${SERVICES[@]}"; do
    if ! known_service "$item"; then
      err "$profile: unknown service: $item"
      fail=1
    fi
  done

  for item in "${SYNC[@]}"; do
    if ! known_sync_agent "$item"; then
      err "$profile: unknown sync agent: $item (allowed: tailscale syncthing atuin)"
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

validate_base_manifests() {
  local fail=0 pkg
  for pkg in $(read_list "$STOW_BASE"); do
    if [ ! -d "$STOW_DIR/$pkg" ]; then
      err "stow-base: missing stow package: $pkg"
      fail=1
    fi
  done
  # stow-os-base lines: `<os>: pkg pkg ...`
  while read -r os_label rest; do
    [ -n "$os_label" ] || continue
    for pkg in $rest; do
      if [ ! -d "$STOW_DIR/$pkg" ]; then
        err "stow-os-base ($os_label): missing stow package: $pkg"
        fail=1
      fi
    done
  done < <(read_list "$STOW_OS_BASE")
  if [ "$fail" = "0" ]; then
    ok "base manifests: PASS"
  else
    err "base manifests: FAIL"
  fi
  return "$fail"
}

main() {
  local files=() f failures=0
  validate_base_manifests || failures=1
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
