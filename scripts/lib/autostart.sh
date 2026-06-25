#!/usr/bin/env bash
# Autostart audit and management helpers. Source after lib/common.sh.
# Color vars are set by common.sh; these defaults satisfy shellcheck when checked standalone.
: "${_c_reset:=}" "${_c_green:=}" "${_c_yellow:=}" "${_c_red:=}" "${_c_blue:=}" "${_c_dim:=}"

autostart_usage() {
  cat <<'EOF'
Usage:
  dotfiles autostart status [--all]
  dotfiles autostart add <command...>
  dotfiles autostart remove [--yes] <command-or-item>
  dotfiles autostart adopt <hypr|xdg> <item>
  dotfiles autostart ignore <item>
  dotfiles autostart unignore <item>
  dotfiles autostart apply

Examples:
  dotfiles autostart add uwsm-app -- slack
  dotfiles autostart remove 'uwsm-app -- slack'
  dotfiles autostart remove synergy.service
  dotfiles autostart adopt xdg dropbox.desktop
  dotfiles autostart ignore systemd:synergy.service

Items and copy-paste actions are shown by `dotfiles autostart status`. Managed
writes go to the current machine profile under stow/ and are applied with GNU
stow.
EOF
}

cmd_autostart() {
  local sub="${1:-status}"
  [[ $# -gt 0 ]] && shift || true

  case "$sub" in
    status) autostart_status "$@" ;;
    add) autostart_add "$@" ;;
    remove|rm) autostart_remove "$@" ;;
    adopt) autostart_adopt "$@" ;;
    ignore) autostart_ignore "$@" ;;
    unignore) autostart_unignore "$@" ;;
    apply) autostart_apply "$@" ;;
    help|-h|--help) autostart_usage ;;
    *) err "unknown autostart command: $sub"; autostart_usage; return 1 ;;
  esac
}

autostart_profile_layer() {
  printf 'profile-%s-%s\n' "$(detect_hostname)" "$(detect_os)"
}

autostart_profile_dir() {
  printf '%s/stow/%s\n' "$DOTFILES_DIR" "$(autostart_profile_layer)"
}

autostart_managed_file() {
  printf '%s/hyprland/.config/hypr/conf.d/30-autostart.conf\n' "$(autostart_profile_dir)"
}

autostart_ignore_file() {
  printf '%s/dotfiles/.config/dotfiles/autostart.ignore\n' "$(autostart_profile_dir)"
}

autostart_require_omarchy() {
  if [[ "$(detect_os)" != "omarchy" ]]; then
    err "autostart management is currently implemented for Omarchy/Hyprland only"
    return 1
  fi
}

autostart_ensure_managed_file() {
  autostart_require_omarchy
  local file dir
  file="$(autostart_managed_file)"
  dir="$(dirname "$file")"
  mkdir -p "$dir"
  if [[ ! -f "$file" ]]; then
    cat >"$file" <<EOF
# Autostart for $(detect_hostname).
# Omarchy's own autostart lives in ~/.local/share/omarchy/default/hypr/autostart.conf
# (do not edit that file - it is overwritten on omarchy update).
#
# Add this machine's apps here. Format:
#   exec-once = uwsm-app -- <command>
EOF
  fi
}

autostart_ensure_ignore_file() {
  local file dir
  file="$(autostart_ignore_file)"
  dir="$(dirname "$file")"
  mkdir -p "$dir"
  if [[ ! -f "$file" ]]; then
    cat >"$file" <<'EOF'
# Autostart audit ignore list.
# Use item IDs from `dotfiles autostart status`, one per line.
EOF
  fi
}

autostart_strip() {
  local s="$*"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s\n' "$s"
}

autostart_hypr_execs_from_file() {
  local file="$1" line cmd
  [[ -f "$file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(autostart_strip "${line%%#*}")"
    [[ "$line" == exec-once\ =* ]] || continue
    cmd="$(autostart_strip "${line#exec-once =}")"
    [[ -n "$cmd" ]] && printf '%s\n' "$cmd"
  done <"$file"
}

autostart_hypr_managed_execs() {
  local layer file
  while read -r layer; do
    [[ -n "$layer" ]] || continue
    for file in \
      "$DOTFILES_DIR/stow/$layer"/*/.config/hypr/*.conf \
      "$DOTFILES_DIR/stow/$layer"/*/.config/hypr/conf.d/*.conf; do
      [[ -f "$file" ]] || continue
      autostart_hypr_execs_from_file "$file"
    done
  done < <(resolve_layers)
}

autostart_hypr_live_execs() {
  local file
  for file in "$HOME/.config/hypr/autostart.conf" "$HOME/.config/hypr/conf.d"/*.conf; do
    [[ -f "$file" ]] || continue
    while read -r cmd; do
      [[ -n "$cmd" ]] && printf '%s\t%s\n' "$file" "$cmd"
    done < <(autostart_hypr_execs_from_file "$file")
  done
}

autostart_ignored() {
  local item="$1" file line
  for file in "$(autostart_ignore_file)" "$HOME/.config/dotfiles/autostart.ignore"; do
    [[ -f "$file" ]] || continue
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="$(autostart_strip "${line%%#*}")"
      [[ -z "$line" ]] && continue
      [[ "$line" == "$item" ]] && return 0
    done <"$file"
  done
  return 1
}

autostart_contains_line() {
  local needle="$1" line
  while IFS= read -r line; do
    [[ "$line" == "$needle" ]] && return 0
  done
  return 1
}

autostart_status() {
  local show_all=0 managed_file managed_execs live_file live_cmd item needs_decision
  if [[ "${1:-}" == "--all" ]]; then
    show_all=1
  elif [[ -n "${1:-}" ]]; then
    err "unknown status option: $1"
    autostart_usage
    return 1
  fi

  managed_file="$(autostart_managed_file)"

  info "Autostart audit"
  printf '  machine: %s (%s)\n' "$(detect_hostname)" "$(detect_os)"
  printf '  managed: %s\n' "$managed_file"

  info "Tracked in dotfiles"
  managed_execs="$(autostart_hypr_managed_execs || true)"
  if [[ -n "$managed_execs" ]]; then
    while read -r item; do
      [[ -n "$item" ]] && printf '  %s✓%s %s  %s[hypr]%s\n' "$_c_green" "$_c_reset" "$item" "$_c_dim" "$_c_reset"
    done <<<"$managed_execs"
  else
    dim "  (none)"
  fi

  info "Needs decision"
  needs_decision=0
  while IFS=$'\t' read -r live_file live_cmd; do
    [[ -n "$live_cmd" ]] || continue
    item="hypr:$live_cmd"
    if autostart_contains_line "$live_cmd" <<<"$managed_execs" || autostart_ignored "$item"; then
      continue
    fi
    printf '\n  %s!%s %s  %s[hypr:local]%s\n' "$_c_yellow" "$_c_reset" "$live_cmd" "$_c_dim" "$_c_reset"
    printf '    %sfile:%s    %s\n'   "$_c_dim" "$_c_reset" "${live_file/#"$HOME"/\~}"
    printf '    %sadopt:%s   dotfiles autostart adopt hypr %q\n'  "$_c_dim" "$_c_reset" "$live_cmd"
    printf '    %signore:%s  dotfiles autostart ignore %q\n' "$_c_dim" "$_c_reset" "$item"
    printf '    %sremove:%s  dotfiles autostart remove %q\n'  "$_c_dim" "$_c_reset" "$live_cmd"
    needs_decision=1
  done < <(autostart_hypr_live_execs)

  autostart_status_xdg_user needs_decision
  needs_decision="$AUTOSTART_NEEDS_DECISION"
  autostart_status_systemd needs_decision
  needs_decision="$AUTOSTART_NEEDS_DECISION"
  [[ $needs_decision -eq 0 ]] && ok "nothing local needs a decision"

  autostart_status_ignored
  autostart_status_defaults "$show_all"
  return 0
}

autostart_desktop_value() {
  local key="$1" file="$2" line
  [[ -f "$file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == "$key="* ]] || continue
    printf '%s\n' "${line#*=}"
    return 0
  done <"$file"
}

autostart_status_xdg_user() {
  local needs_decision_ref="$1" file base name exec hidden item
  AUTOSTART_NEEDS_DECISION="${!needs_decision_ref}"

  for file in "$HOME/.config/autostart"/*.desktop; do
    [[ -f "$file" ]] || continue
    base="$(basename "$file")"
    item="xdg:$base"
    autostart_ignored "$item" && continue
    name="$(autostart_desktop_value Name "$file")"
    exec="$(autostart_desktop_value Exec "$file")"
    hidden="$(autostart_desktop_value Hidden "$file")"
    if [[ "${hidden,,}" == "true" ]]; then
      printf '\n  %s!%s %s  %s[xdg:disabled]%s\n' "$_c_yellow" "$_c_reset" "$base" "$_c_dim" "$_c_reset"
      printf '    %sstate:%s   Hidden=true local override\n' "$_c_dim" "$_c_reset"
      printf '    %sfile:%s    %s\n'   "$_c_dim" "$_c_reset" "${file/#"$HOME"/\~}"
      printf '    %signore:%s  dotfiles autostart ignore %q\n' "$_c_dim" "$_c_reset" "$item"
      printf '    %sremove:%s  dotfiles autostart remove %q\n'  "$_c_dim" "$_c_reset" "$item"
    else
      printf '\n  %s!%s %s  %s[xdg:local]%s  %s\n' "$_c_yellow" "$_c_reset" "$base" "$_c_dim" "$_c_reset" "${name:-$base}"
      printf '    %sexec:%s    %s\n'  "$_c_dim" "$_c_reset" "${exec:-(none)}"
      printf '    %sadopt:%s   dotfiles autostart adopt xdg %q\n' "$_c_dim" "$_c_reset" "$base"
      printf '    %signore:%s  dotfiles autostart ignore %q\n' "$_c_dim" "$_c_reset" "$item"
      printf '    %sremove:%s  dotfiles autostart remove %q\n'  "$_c_dim" "$_c_reset" "$item"
    fi
    AUTOSTART_NEEDS_DECISION=1
  done
  return 0
}

autostart_status_defaults() {
  local show_all="$1" file base name exec item found_system=0 system_count=0 unit state fragment item_systemd systemd_count=0

  info "System defaults (read-only)"

  for file in /etc/xdg/autostart/*.desktop; do
    [[ -f "$file" ]] || continue
    base="$(basename "$file")"
    item="xdg-system:$base"
    autostart_ignored "$item" && continue
    system_count=$((system_count+1))
    found_system=1
    [[ $show_all -ne 1 ]] && continue
    name="$(autostart_desktop_value Name "$file")"
    printf '  %s%-50s%s  %s\n' "$_c_dim" "$base" "$_c_reset" "${name:-$base}"
  done

  if command -v systemctl >/dev/null 2>&1; then
    while read -r unit state _; do
      [[ -n "${unit:-}" ]] || continue
      [[ "$unit" == *.* ]] || continue
      item_systemd="systemd:$unit"
      autostart_ignored "$item_systemd" && continue
      fragment="$(systemctl --user show "$unit" -p FragmentPath --value --no-pager 2>/dev/null || true)"
      [[ "$fragment" == /usr/lib/systemd/user/* ]] || continue
      systemd_count=$((systemd_count+1))
      if [[ $show_all -eq 1 ]]; then
        printf '  %s%-50s%s  %s\n' "$_c_dim" "$unit" "$_c_reset" "$state"
      fi
    done < <(systemctl --user list-unit-files --state=enabled,linked,masked --no-pager --no-legend 2>/dev/null || true)
  fi

  local total=$((system_count + systemd_count))
  if [[ $show_all -eq 1 ]]; then
    if [[ $total -eq 0 ]]; then
      dim "  (none)"
    else
      printf '\n'
      dim "  To suppress any entry: dotfiles autostart ignore xdg-system:<name>"
      dim "                                                    systemd:<unit>"
    fi
  else
    if [[ $total -eq 0 ]]; then
      [[ $found_system -eq 0 ]] && dim "  (none visible)"
    else
      printf '  %s%s entries hidden%s  —  dotfiles autostart status --all\n' "$_c_dim" "$total" "$_c_reset"
    fi
  fi
  return 0
}

autostart_status_systemd() {
  local needs_decision_ref="$1" unit state item fragment
  AUTOSTART_NEEDS_DECISION="${!needs_decision_ref}"
  if ! command -v systemctl >/dev/null 2>&1; then
    return 0
  fi

  while read -r unit state _; do
    [[ -n "${unit:-}" ]] || continue
    [[ "$unit" == "UNIT" ]] && continue
    [[ "$unit" == *.* ]] || continue
    item="systemd:$unit"
    autostart_ignored "$item" && continue
    # Masked units are already intentionally suppressed; surface them in Ignored, not here.
    [[ "$state" == "masked" ]] && continue
    fragment="$(systemctl --user show "$unit" -p FragmentPath --value --no-pager 2>/dev/null || true)"
    [[ "$fragment" == /usr/lib/systemd/user/* ]] && continue
    printf '\n  %s!%s %s  %s[systemd:user]%s  %s\n' "$_c_yellow" "$_c_reset" "$unit" "$_c_dim" "$_c_reset" "$state"
    [[ -n "$fragment" ]] && printf '    %sfile:%s    %s\n' "$_c_dim" "$_c_reset" "${fragment/#"$HOME"/\~}"
    printf '    %signore:%s  dotfiles autostart ignore %q\n' "$_c_dim" "$_c_reset" "$item"
    printf '    %sremove:%s  dotfiles autostart remove %q\n'  "$_c_dim" "$_c_reset" "$item"
    AUTOSTART_NEEDS_DECISION=1
  done < <(systemctl --user list-unit-files --state=enabled,linked,masked --no-pager --no-legend 2>/dev/null || true)
  return 0
}

autostart_status_ignored() {
  local file line found=0 seen=$'\n'
  info "Ignored"
  for file in "$(autostart_ignore_file)" "$HOME/.config/dotfiles/autostart.ignore"; do
    [[ -f "$file" ]] || continue
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="$(autostart_strip "${line%%#*}")"
      [[ -z "$line" ]] && continue
      [[ "$seen" == *$'\n'"$line"$'\n'* ]] && continue
      printf '  %s%s%s\n' "$_c_dim" "$line" "$_c_reset"
      seen+="$line"$'\n'
      found=1
    done <"$file"
  done
  # Show masked user systemd units (intentionally suppressed, not in ignore file).
  if command -v systemctl >/dev/null 2>&1; then
    while read -r unit state _; do
      [[ -n "${unit:-}" && "$state" == "masked" ]] || continue
      [[ "$unit" == *.* ]] || continue
      local mfrag
      mfrag="$(systemctl --user show "$unit" -p FragmentPath --value --no-pager 2>/dev/null || true)"
      [[ "$mfrag" == /usr/lib/systemd/user/* ]] && continue
      local mitem="systemd:$unit"
      autostart_ignored "$mitem" && continue
      printf '  %s%s%s  %s(masked)%s\n' "$_c_dim" "$mitem" "$_c_reset" "$_c_dim" "$_c_reset"
      seen+="$mitem"$'\n'
      found=1
    done < <(systemctl --user list-unit-files --state=masked --no-pager --no-legend 2>/dev/null || true)
  fi
  [[ $found -eq 0 ]] && dim "  (none)"
  return 0
}

autostart_add() {
  [[ $# -gt 0 ]] || { err "missing command"; autostart_usage; return 1; }
  autostart_ensure_managed_file
  local cmd file line
  cmd="$*"
  file="$(autostart_managed_file)"
  line="exec-once = $cmd"
  if autostart_hypr_execs_from_file "$file" | autostart_contains_line "$cmd"; then
    ok "already managed: $cmd"
    return 0
  fi
  printf '\n%s\n' "$line" >>"$file"
  ok "added: $line"
  dim "run: dotfiles autostart apply"
}

autostart_remove() {
  local yes=0 target file tmp line raw removed=0 item_file
  if [[ "${1:-}" == "--yes" || "${1:-}" == "-y" ]]; then
    yes=1; shift
  fi
  [[ $# -gt 0 ]] || { err "missing command-or-item"; autostart_usage; return 1; }
  target="$*"

  if [[ "$target" != *:* ]]; then
    if [[ "$target" == *.desktop && -f "$HOME/.config/autostart/$target" ]]; then
      target="xdg:$target"
    elif [[ "$target" == *.service || "$target" == *.timer || "$target" == *.socket ]]; then
      target="systemd:$target"
    fi
  fi

  case "$target" in
    xdg:*)
      item_file="$HOME/.config/autostart/${target#xdg:}"
      [[ -f "$item_file" ]] || { err "not found: $item_file"; return 1; }
      if [[ $yes -eq 1 ]] || confirm "Remove $item_file?"; then
        rm -f -- "$item_file"
        ok "removed: $item_file"
      fi
      return 0
      ;;
    systemd:*)
      local unit="${target#systemd:}"
      if ! command -v systemctl >/dev/null 2>&1; then
        err "systemctl not installed"
        return 1
      fi
      local fragment
      fragment="$(systemctl --user show "$unit" -p FragmentPath --value --no-pager 2>/dev/null || true)"
      # Units outside ~/.config/systemd/user/ are globally enabled; disable alone won't survive
      # a reboot because the system-scope enable wins. Mask instead.
      local needs_mask=0
      [[ -n "$fragment" && "$fragment" != "$HOME/.config/systemd/user/"* ]] && needs_mask=1
      local action="Disable and stop"
      [[ $needs_mask -eq 1 ]] && action="Mask and stop"
      if [[ $yes -eq 1 ]] || confirm "$action user unit $unit?"; then
        if [[ $needs_mask -eq 1 ]]; then
          systemctl --user disable --now "$unit" 2>/dev/null || true
          systemctl --user mask "$unit"
          ok "masked user unit: $unit"
        else
          systemctl --user disable --now "$unit"
          ok "disabled user unit: $unit"
        fi
      fi
      return 0
      ;;
  esac

  file="$(autostart_managed_file)"
  [[ -f "$file" ]] || { err "managed autostart file does not exist: $file"; return 1; }
  tmp="$(mktemp)"
  while IFS= read -r raw || [[ -n "$raw" ]]; do
    line="$(autostart_strip "${raw%%#*}")"
    if [[ "$line" == "exec-once = $target" || "$line" == "exec-once = ${target#hypr:}" ]]; then
      removed=1
      continue
    fi
    printf '%s\n' "$raw" >>"$tmp"
  done <"$file"

  if [[ $removed -eq 0 ]]; then
    rm -f -- "$tmp"
    err "not found in managed autostart: $target"
    return 1
  fi
  if [[ $yes -eq 1 ]] || confirm "Remove managed autostart '$target'?"; then
    mv -- "$tmp" "$file"
    ok "removed: $target"
    dim "run: dotfiles autostart apply"
  else
    rm -f -- "$tmp"
  fi
}

autostart_adopt() {
  local source item file exec
  source="${1:-}"; item="${2:-}"
  [[ -n "$source" && -n "$item" ]] || { err "usage: dotfiles autostart adopt <hypr|xdg> <item>"; return 1; }
  case "$source" in
    hypr)
      autostart_add "$item"
      ;;
    xdg)
      file="$HOME/.config/autostart/$item"
      [[ -f "$file" ]] || { err "not found: $file"; return 1; }
      exec="$(autostart_desktop_value Exec "$file")"
      [[ -n "$exec" ]] || { err "no Exec= found in $file"; return 1; }
      autostart_add "uwsm-app -- $exec"
      ;;
    *)
      err "unknown adopt source: $source"
      return 1
      ;;
  esac
}

autostart_ignore() {
  [[ $# -gt 0 ]] || { err "missing item"; autostart_usage; return 1; }
  autostart_ensure_ignore_file
  local item="$*" file
  file="$(autostart_ignore_file)"
  if autostart_ignored "$item"; then
    ok "already ignored: $item"
    return 0
  fi
  printf '%s\n' "$item" >>"$file"
  ok "ignored: $item"
  dim "run: dotfiles autostart apply"
}

autostart_unignore() {
  [[ $# -gt 0 ]] || { err "missing item"; autostart_usage; return 1; }
  local item="$*" file tmp raw line removed=0
  file="$(autostart_ignore_file)"
  [[ -f "$file" ]] || { ok "not ignored: $item"; return 0; }
  tmp="$(mktemp)"
  while IFS= read -r raw || [[ -n "$raw" ]]; do
    line="$(autostart_strip "${raw%%#*}")"
    if [[ "$line" == "$item" ]]; then
      removed=1
      continue
    fi
    printf '%s\n' "$raw" >>"$tmp"
  done <"$file"
  mv -- "$tmp" "$file"
  if [[ $removed -eq 1 ]]; then
    ok "unignored: $item"
  else
    ok "not ignored: $item"
  fi
}

autostart_apply() {
  info "stow layer: $(autostart_profile_layer)"
  stow_layer "$(autostart_profile_layer)" --restow
  ok "autostart profile applied"
}
