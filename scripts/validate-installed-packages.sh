#!/usr/bin/env bash
set -euo pipefail
# Validate that declared packages are installed and basic commands are usable.
#
# Usage:
#   validate-installed-packages.sh --profile NAME --os OS --pkgmgr MGR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=scripts/lib.sh
. "$SCRIPT_DIR/lib.sh"

PROFILES_DIR="${PROFILES_DIR:-$REPO_DIR/profiles}"
PACKAGES_DIR="${PACKAGES_DIR:-$REPO_DIR/packages}"

PROFILE="" OS="" PKGMGR=""
while [ $# -gt 0 ]; do
  case "$1" in
    --profile) PROFILE="${2:-}"; shift 2 ;;
    --profile=*) PROFILE="${1#*=}"; shift ;;
    --os) OS="${2:-}"; shift 2 ;;
    --os=*) OS="${1#*=}"; shift ;;
    --pkgmgr) PKGMGR="${2:-}"; shift 2 ;;
    --pkgmgr=*) PKGMGR="${1#*=}"; shift ;;
    *) die "validate-installed-packages: unknown arg: $1" ;;
  esac
done

[ -n "$PROFILE" ] || die "validate-installed-packages: --profile required"
[ -n "$PKGMGR" ] || die "validate-installed-packages: --pkgmgr required"

PACKAGE_GROUPS=()
# shellcheck source=/dev/null
. "$PROFILES_DIR/$PROFILE.conf"

pkg_installed() {
  case "$PKGMGR" in
    brew) brew list --formula "$1" >/dev/null 2>&1 || brew list --cask "$1" >/dev/null 2>&1 ;;
    apt) dpkg -s "$1" >/dev/null 2>&1 ;;
    pacman) pacman -Qi "$1" >/dev/null 2>&1 ;;
    *) return 0 ;;
  esac
}

command_for_package() {
  case "$1" in
    age) printf "age\n" ;;
    atuin) printf "atuin\n" ;;
    bat)
      case "$PKGMGR" in
        apt) printf "batcat\n" ;;
        *) printf "bat\n" ;;
      esac
      ;;
    btop) printf "btop\n" ;;
    curl) printf "curl\n" ;;
    eza) printf "eza\n" ;;
    fastfetch) printf "fastfetch\n" ;;
    fzf) printf "fzf\n" ;;
    git) printf "git\n" ;;
    htop) printf "htop\n" ;;
    jq) printf "jq\n" ;;
    nano) printf "nano\n" ;;
    networkmanager) printf "nmcli\n" ;;
    neovim) printf "nvim\n" ;;
    restic) printf "restic\n" ;;
    ripgrep) printf "rg\n" ;;
    stow) printf "stow\n" ;;
    tailscale) printf "tailscale\n" ;;
    tmux) printf "tmux\n" ;;
    wget) printf "wget\n" ;;
    ghostty) printf "ghostty\n" ;;
    walker) printf "walker\n" ;;
    firefox) printf "firefox\n" ;;
    zoxide) printf "zoxide\n" ;;
    yazi) printf "yazi\n" ;;
    socat) printf "socat\n" ;;
    zsh) printf "zsh\n" ;;
    *) return 1 ;;
  esac
}

declared_packages() {
  local group
  for group in "${PACKAGE_GROUPS[@]}"; do
    read_list "$PACKAGES_DIR/$group/$PKGMGR.txt"
    if [ "$PKGMGR" = "pacman" ]; then
      read_list "$PACKAGES_DIR/$group/aur.txt"
    elif [ "$PKGMGR" = "brew" ]; then
      read_list "$PACKAGES_DIR/$group/brew-cask.txt"
    fi
  done | sort -u
}

main() {
  if [ "$DRY_RUN" = "1" ]; then
    info "Skipping package usability validation in dry-run mode."
    return 0
  fi

  info "Validating installed packages for profile '$PROFILE'"
  local pkg cmd failures=0
  while IFS= read -r pkg; do
    [ -n "$pkg" ] || continue
    if ! pkg_installed "$pkg"; then
      err "package is declared but not installed: $pkg"
      failures=1
      continue
    fi
    if cmd="$(command_for_package "$pkg")"; then
      if ! need_cmd "$cmd"; then
        err "package '$pkg' is installed but command is not on PATH: $cmd"
        failures=1
      else
        dim "ok usable: $pkg -> $cmd"
      fi
    fi
  done < <(declared_packages)

  [ "$failures" = "0" ] || die "Package usability validation failed."
  ok "Package usability validation passed."
}

main
