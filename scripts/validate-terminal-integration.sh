#!/usr/bin/env bash
set -euo pipefail
# Validate Omarchy terminal launch paths for WezTerm.
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
  local preferred resolved_id resolved_path resolved_cmd desktop_content
  preferred="$(first_xdg_terminal)"

  [ -n "$preferred" ] || fail_check "~/.config/xdg-terminals.list is missing or empty."
  case "$preferred" in
    *wezterm*.desktop|*WezTerm*.desktop) ok "xdg terminal preference prioritizes WezTerm: $preferred" ;;
    *) fail_check "xdg-terminal preference does not prioritize WezTerm: ${preferred:-<none>}" ;;
  esac

  if ! need_cmd xdg-terminal-exec; then
    fail_check "xdg-terminal-exec is not installed or not on PATH."
    return 0
  fi

  resolved_id="$(xdg-terminal-exec --print-id 2>/dev/null || true)"
  resolved_path="$(xdg-terminal-exec --print-path 2>/dev/null || true)"
  resolved_cmd="$(xdg-terminal-exec --print-cmd 2>/dev/null || true)"

  case "$resolved_id" in
    *wezterm*.desktop|*WezTerm*.desktop) ok "xdg-terminal-exec resolves to WezTerm: $resolved_id" ;;
    *) fail_check "xdg-terminal-exec resolves to '$resolved_id', expected WezTerm." ;;
  esac
  if [ -n "$resolved_path" ] && [ -f "$resolved_path" ]; then
    ok "xdg-terminal-exec desktop entry exists: $resolved_path"
  else
    fail_check "xdg-terminal-exec resolved path is missing: ${resolved_path:-<none>}"
  fi
  case "$resolved_cmd" in
    *wezterm*) ok "xdg-terminal-exec command launches WezTerm" ;;
    *) fail_check "xdg-terminal-exec command does not launch WezTerm: ${resolved_cmd:-<none>}" ;;
  esac

  if [ -n "$resolved_path" ] && [ -f "$resolved_path" ]; then
    case "$resolved_id" in
      *wezterm*.desktop|*WezTerm*.desktop) ;;
      *) return 0 ;;
    esac
    desktop_content="$(xdg-terminal-exec --print-content 2>/dev/null || true)"
    if printf "%s\n" "$desktop_content" | grep -q '^Exec=.*wezterm'; then
      ok "WezTerm desktop entry has Exec=wezterm"
    else
      fail_check "WezTerm desktop entry lacks an Exec=wezterm command: $resolved_path"
    fi
    printf "%s\n" "$desktop_content" | grep -q '^X-TerminalArgExec=' || warn "WezTerm desktop entry lacks X-TerminalArgExec; command launch compatibility may be limited."
    printf "%s\n" "$desktop_content" | grep -q '^X-TerminalArgDir=' || warn "WezTerm desktop entry lacks X-TerminalArgDir; cwd launch compatibility may be limited."
    if printf "%s\n" "$desktop_content" | grep -q '^X-TerminalArgTitle='; then
      fail_check "WezTerm desktop entry advertises unsupported --title terminal argument: $resolved_path"
    else
      ok "WezTerm desktop entry avoids unsupported title argument"
    fi
  fi
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
  if printf "%s\n" "$binds" | grep -i 'arg: .*alacritty' >/dev/null 2>&1; then
    fail_check "Hyprland active bindings still hardcode Alacritty."
  else
    ok "Hyprland terminal bindings do not hardcode Alacritty"
  fi
}

validate_wezterm_window() {
  local after launch_output launch_log launch_pid marker address
  if ! need_cmd hyprctl; then
    warn "hyprctl not found; skipping WezTerm window visibility validation."
    return 0
  fi
  if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && ! hyprctl monitors >/dev/null 2>&1; then
    warn "not in a live Hyprland session; skipping WezTerm window visibility validation."
    return 0
  fi
  need_cmd jq || { warn "jq not found; skipping WezTerm window visibility validation."; return 0; }

  marker="dotfiles-wezterm-validation-$$"
  launch_log="${TMPDIR:-/tmp}/dotfiles-wezterm-validation.$$.log"
  : >"$launch_log"
  wezterm start --always-new-process --class "$marker" -- bash -lc 'sleep 20' >"$launch_log" 2>&1 &
  launch_pid=$!

  address=""
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    after="$(hyprctl clients -j 2>/dev/null || printf '[]')"
    address="$(printf "%s\n" "$after" | jq -r --arg marker "$marker" '
      .[]
      | select((.class // "" | test("wezterm|WezTerm|" + $marker))
          or (.initialClass // "" | test("wezterm|WezTerm|" + $marker))
          or (.title // "" | test($marker))
          or (.initialTitle // "" | test($marker)))
      | .address
    ' | head -n 1)"
    [ -n "$address" ] && [ "$address" != "null" ] && break
    if ! kill -0 "$launch_pid" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done

  if [ -z "$address" ] || [ "$address" = "null" ]; then
    launch_output="$(sed -n '1,120p' "$launch_log" 2>/dev/null || true)"
    [ -n "$launch_output" ] && dim "$launch_output"
    fail_check "wezterm start --always-new-process did not create a Hyprland-visible WezTerm client."
    info "Diagnostics to run: wezterm --version; xdg-terminal-exec --print-id; xdg-terminal-exec --print-path; hyprctl clients"
    kill "$launch_pid" >/dev/null 2>&1 || true
    wait "$launch_pid" >/dev/null 2>&1 || true
    rm -f "$launch_log"
    return 0
  fi

  hyprctl dispatch closewindow "address:$address" >/dev/null 2>&1 || true
  wait "$launch_pid" >/dev/null 2>&1 || true
  rm -f "$launch_log"
}

main() {
  local has_wezterm=0
  [ "$OS" = "omarchy" ] || return 0
  declares_package wezterm || return 0

  if [ "$DRY_RUN" = "1" ]; then
    info "Skipping terminal integration validation in dry-run mode."
    return 0
  fi

  info "Validating Omarchy terminal integration for WezTerm"
  if need_cmd wezterm; then
    has_wezterm=1
    ok "wezterm binary is on PATH"
  else
    fail_check "wezterm is not installed or not on PATH."
  fi
  if need_cmd wezterm; then
    if wezterm --version >/dev/null 2>&1; then
      ok "wezterm --version works"
    else
      fail_check "wezterm --version failed."
    fi
  fi

  validate_xdg_terminal_exec
  validate_hypr_bindings
  if [ "$GUI_CHECK" = "1" ] && [ "$has_wezterm" = "1" ]; then
    validate_wezterm_window
  else
    info "Skipping live GUI WezTerm window check (use --gui to run it manually)."
  fi

  [ "$failures" = "0" ] || die "Terminal integration validation failed."
  ok "Terminal integration validation passed."
}

main
