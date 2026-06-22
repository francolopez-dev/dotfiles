#!/usr/bin/env bash
set -euo pipefail
# Validate Omarchy terminal launch paths for Ghostty.
#
# Usage:
#   validate-terminal-integration.sh --profile NAME --os OS --pkgmgr MGR [--gui]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=scripts/lib.sh
. "$SCRIPT_DIR/lib.sh"

PROFILES_DIR="${PROFILES_DIR:-$REPO_DIR/profiles}"
PACKAGES_DIR="${PACKAGES_DIR:-$REPO_DIR/packages}"

PROFILE="" OS="" PKGMGR="" GUI_CHECK=0
while [ $# -gt 0 ]; do
  case "$1" in
    --profile) PROFILE="${2:-}"; shift 2 ;;
    --profile=*) PROFILE="${1#*=}"; shift ;;
    --os) OS="${2:-}"; shift 2 ;;
    --os=*) OS="${1#*=}"; shift ;;
    --pkgmgr) PKGMGR="${2:-}"; shift 2 ;;
    --pkgmgr=*) PKGMGR="${1#*=}"; shift ;;
    --gui) GUI_CHECK=1; shift ;;
    *) die "validate-terminal-integration: unknown arg: $1" ;;
  esac
done

[ -n "$PROFILE" ] || die "validate-terminal-integration: --profile required"
[ -n "$OS" ] || die "validate-terminal-integration: --os required"
[ -n "$PKGMGR" ] || die "validate-terminal-integration: --pkgmgr required"

PACKAGE_GROUPS=()
# shellcheck source=/dev/null
. "$PROFILES_DIR/$PROFILE.conf"

failures=0

fail_check() {
  err "$*"
  failures=1
}

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

first_xdg_terminal() {
  sed -e 's/#.*$//' -e 's/[[:space:]]*$//' -e 's/^[[:space:]]*//' \
    "$HOME/.config/xdg-terminals.list" 2>/dev/null | grep -v '^$' | head -n 1 || true
}

validate_xdg_terminal_exec() {
  local preferred resolved_id resolved_path resolved_cmd
  preferred="$(first_xdg_terminal)"

  [ -n "$preferred" ] || fail_check "~/.config/xdg-terminals.list is missing or empty."
  case "$preferred" in
    *ghostty*.desktop|*Ghostty*.desktop) ok "xdg terminal preference prioritizes Ghostty: $preferred" ;;
    *) fail_check "xdg-terminal preference does not prioritize Ghostty: ${preferred:-<none>}" ;;
  esac

  if ! need_cmd xdg-terminal-exec; then
    fail_check "xdg-terminal-exec is not installed or not on PATH."
    return 0
  fi

  resolved_id="$(xdg-terminal-exec --print-id 2>/dev/null || true)"
  resolved_path="$(xdg-terminal-exec --print-path 2>/dev/null || true)"
  resolved_cmd="$(xdg-terminal-exec --print-cmd 2>/dev/null || true)"

  case "$resolved_id" in
    *ghostty*.desktop|*Ghostty*.desktop) ok "xdg-terminal-exec resolves to Ghostty: $resolved_id" ;;
    *) fail_check "xdg-terminal-exec resolves to '$resolved_id', expected Ghostty." ;;
  esac
  if [ -n "$resolved_path" ] && [ -f "$resolved_path" ]; then
    ok "xdg-terminal-exec desktop entry exists: $resolved_path"
  else
    fail_check "xdg-terminal-exec resolved path is missing: ${resolved_path:-<none>}"
  fi
  case "$resolved_cmd" in
    *ghostty*) ok "xdg-terminal-exec command launches Ghostty" ;;
    *) fail_check "xdg-terminal-exec command does not launch Ghostty: ${resolved_cmd:-<none>}" ;;
  esac
}

validate_hypr_bindings() {
  local binds
  need_cmd hyprctl || { warn "hyprctl not found; skipping Hyprland binding validation."; return 0; }
  binds="$(hyprctl binds 2>/dev/null || true)"
  [ -n "$binds" ] || { warn "hyprctl binds returned no data; skipping Hyprland binding validation."; return 0; }

  if printf "%s\n" "$binds" | grep -q 'description: Terminal'; then
    ok "Hyprland has a Terminal binding"
  else
    fail_check "Hyprland has no active binding described as Terminal."
  fi
  if printf "%s\n" "$binds" | grep -q 'xdg-terminal-exec'; then
    ok "Hyprland terminal binding uses xdg-terminal-exec"
  else
    fail_check "Hyprland terminal bindings do not use xdg-terminal-exec."
  fi
  if printf "%s\n" "$binds" | grep -i 'arg: .*wezterm' >/dev/null 2>&1; then
    fail_check "Hyprland active bindings still reference WezTerm."
  else
    ok "Hyprland terminal bindings do not hardcode WezTerm"
  fi
}

main() {
  [ "$OS" = "omarchy" ] || return 0
  declares_package ghostty || return 0

  if [ "$DRY_RUN" = "1" ]; then
    info "Skipping terminal integration validation in dry-run mode."
    return 0
  fi

  info "Validating Omarchy terminal integration for Ghostty"
  if need_cmd ghostty; then
    ok "ghostty binary is on PATH"
    if ghostty --version >/dev/null 2>&1; then
      ok "ghostty --version works"
    else
      fail_check "ghostty --version failed."
    fi
  else
    fail_check "ghostty is not installed or not on PATH."
  fi

  validate_xdg_terminal_exec
  validate_hypr_bindings

  if [ "$GUI_CHECK" = "1" ]; then
    info "GUI check requested: open a terminal with Super+Return and confirm Ghostty launches."
    info "Diagnostics: ghostty --version; xdg-terminal-exec --print-id; hyprctl clients | grep -i ghostty"
  fi

  [ "$failures" = "0" ] || die "Terminal integration validation failed."
  ok "Terminal integration validation passed."
}

main
