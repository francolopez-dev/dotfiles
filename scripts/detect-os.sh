#!/usr/bin/env bash
set -euo pipefail
# Detect the machine's OS id and package manager for the four supported targets:
#   omarchy | macos | debian | ubuntu
# Anything else is a hard error — generic-distro support was intentionally dropped.
#
# Output (stdout): two space-separated tokens "<os> <pkgmgr>".
#   omarchy pacman
#   macos   brew
#   debian  apt
#   ubuntu  apt
#
# Env overrides for testing:
#   OS_OVERRIDE=omarchy ./detect-os.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=scripts/lib.sh
. "$SCRIPT_DIR/lib.sh"

detect_os() {
  if [ -n "${OS_OVERRIDE:-}" ]; then
    case "$OS_OVERRIDE" in
      omarchy) echo "omarchy pacman"; return ;;
      macos)   echo "macos brew";     return ;;
      debian)  echo "debian apt";     return ;;
      ubuntu)  echo "ubuntu apt";     return ;;
      *) die "OS_OVERRIDE='$OS_OVERRIDE' is not one of: omarchy macos debian ubuntu" ;;
    esac
  fi

  if [ "$(uname)" = "Darwin" ]; then
    echo "macos brew"
    return
  fi

  if [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID:-}" in
      arch)   echo "omarchy pacman"; return ;;
      debian) echo "debian apt";     return ;;
      ubuntu) echo "ubuntu apt";     return ;;
    esac
    # Arch derivatives sometimes set ID_LIKE=arch.
    case "${ID_LIKE:-}" in
      *arch*) echo "omarchy pacman"; return ;;
    esac
    die "Unsupported OS (ID='${ID:-?}'). Supported: omarchy(arch) macos debian ubuntu."
  fi

  die "Cannot determine OS: no /etc/os-release and uname=$(uname)."
}

detect_os
