#!/usr/bin/env bash
set -euo pipefail
# Pick a profile and persist the choice to a machine-local, gitignored state file.
#
# Resolution order:
#   1. --profile NAME flag
#   2. previously persisted choice (~/.config/dotfiles/profile)
#   3. interactive menu (if a TTY)
#   4. fallback to "minimal"
#
# Output (stdout): the chosen profile name (also persisted).
# All human-facing chatter goes to stderr so callers can capture stdout cleanly.

. "$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/lib.sh"

PROFILES_DIR="${PROFILES_DIR:-$REPO_DIR/profiles}"
STATE_DIR="${STATE_DIR:-$HOME/.config/dotfiles}"
STATE_FILE="$STATE_DIR/profile"

requested=""
while [ $# -gt 0 ]; do
  case "$1" in
    --profile) requested="${2:-}"; shift 2 ;;
    --profile=*) requested="${1#*=}"; shift ;;
    *) shift ;;
  esac
done

list_profiles() {
  [ -d "$PROFILES_DIR" ] || return 0
  for f in "$PROFILES_DIR"/*.conf; do
    [ -e "$f" ] || continue
    basename "$f" .conf
  done
}

profile_exists() {
  [ -f "$PROFILES_DIR/$1.conf" ]
}

persist() {
  mkdir -p "$STATE_DIR"
  printf "%s\n" "$1" > "$STATE_FILE"
}

choose() {
  # 1. explicit flag
  if [ -n "$requested" ]; then
    profile_exists "$requested" || die "Unknown profile: $requested (have: $(list_profiles | tr '\n' ' '))"
    echo "$requested"; return
  fi

  # 2. persisted
  if [ -f "$STATE_FILE" ]; then
    local saved; saved="$(tr -d '[:space:]' < "$STATE_FILE")"
    if [ -n "$saved" ] && profile_exists "$saved"; then
      info "Using saved profile: $saved" >&2
      echo "$saved"; return
    fi
  fi

  # 3. interactive
  if [ -t 0 ] && [ -t 1 ]; then
    local names; names=$(list_profiles)
    [ -n "$names" ] || die "No profiles found in $PROFILES_DIR"
    info "Select a profile:" >&2
    local PS3="profile> "
    local choice
    select choice in $names; do
      if [ -n "$choice" ]; then echo "$choice"; return; fi
      warn "Invalid selection." >&2
    done
  fi

  # 4. fallback
  warn "No profile specified and not interactive; falling back to 'minimal'." >&2
  echo "minimal"
}

selected="$(choose)"
persist "$selected"
echo "$selected"
