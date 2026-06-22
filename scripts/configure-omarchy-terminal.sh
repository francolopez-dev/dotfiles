#!/usr/bin/env bash
set -euo pipefail
# Configure Omarchy's xdg-terminal-exec integration for Ghostty.
#
# Usage:
#   configure-omarchy-terminal.sh --profile NAME --os OS --pkgmgr MGR
#
# Writes a local desktop entry override for Ghostty with the X-Terminal*
# fields required by xdg-terminal-exec, and sets it as the preferred terminal
# in ~/.config/xdg-terminals.list. This intentionally writes live user state
# rather than stowing it: Omarchy creates that file on first boot, so stow
# would often conflict and leave the old preference in place.

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
    *) die "configure-omarchy-terminal: unknown arg: $1" ;;
  esac
done

[ -n "$PROFILE" ] || die "configure-omarchy-terminal: --profile required"
[ -n "$OS" ] || die "configure-omarchy-terminal: --os required"
[ -n "$PKGMGR" ] || die "configure-omarchy-terminal: --pkgmgr required"

PACKAGE_GROUPS=()
# shellcheck source=/dev/null
. "$PROFILES_DIR/$PROFILE.conf"

declares_package() {
  local wanted="$1" group pkg
  for group in "${PACKAGE_GROUPS[@]}"; do
    while IFS= read -r pkg; do
      [ "$pkg" = "$wanted" ] && return 0
    done < <(read_list "$PACKAGES_DIR/$group/$PKGMGR.txt")
    if [ "$PKGMGR" = "pacman" ]; then
      while IFS= read -r pkg; do
        [ "$pkg" = "$wanted" ] && return 0
      done < <(read_list "$PACKAGES_DIR/$group/aur.txt")
    fi
  done
  return 1
}

write_ghostty_desktop_entry() {
  local desktop_dir="$HOME/.local/share/applications"
  local desktop_file="$desktop_dir/com.mitchellh.ghostty.desktop"

  if [ "$DRY_RUN" = "1" ]; then
    info "[dry-run] would write $desktop_file"
    return 0
  fi

  run mkdir -p "$desktop_dir"
  cat >"$desktop_file" <<'EOF'
[Desktop Entry]
Type=Application
Name=Ghostty
GenericName=Terminal
Comment=Fast, native, feature-rich terminal emulator
TryExec=ghostty
Exec=ghostty
Icon=com.mitchellh.ghostty
Terminal=false
Categories=System;TerminalEmulator;
StartupNotify=true
StartupWMClass=com.mitchellh.ghostty
X-TerminalArgExec=-e
X-TerminalArgDir=--working-directory=
EOF

  if need_cmd update-desktop-database; then
    run update-desktop-database "$desktop_dir" >/dev/null 2>&1 || true
  fi
}

write_xdg_terminal_preference() {
  local config_dir="$HOME/.config"
  local config_file="$config_dir/xdg-terminals.list"

  if [ "$DRY_RUN" = "1" ]; then
    info "[dry-run] would prefer com.mitchellh.ghostty.desktop in $config_file"
    return 0
  fi

  run mkdir -p "$config_dir"
  cat >"$config_file" <<'EOF'
# Terminal emulator preference order for xdg-terminal-exec
# The first found and valid terminal will be used
com.mitchellh.ghostty.desktop
Alacritty.desktop
EOF
}

main() {
  [ "$OS" = "omarchy" ] || return 0
  declares_package ghostty || return 0

  info "Configuring Omarchy terminal integration for Ghostty"
  write_ghostty_desktop_entry
  write_xdg_terminal_preference
  ok "Omarchy terminal integration configured."
}

main
