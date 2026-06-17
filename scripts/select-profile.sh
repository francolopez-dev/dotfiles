#!/usr/bin/env bash
set -euo pipefail
# Pick a profile and persist the choice to a machine-local, gitignored state file.
#
# Resolution order:
#   1. --profile NAME flag
#   2. --first-time/--reconfigure wizard
#   3. previously persisted choice (~/.config/dotfiles/profile)
#   4. wizard
#   5. fallback to "minimal"
#
# Output (stdout): the chosen profile name. Human-facing chatter goes to stderr.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=scripts/lib.sh
. "$SCRIPT_DIR/lib.sh"

PROFILES_DIR="${PROFILES_DIR:-$REPO_DIR/profiles}"
STATE_DIR="${STATE_DIR:-$HOME/.config/dotfiles}"
STATE_FILE="$STATE_DIR/profile"

requested="" OS="" FIRST_TIME=0
while [ $# -gt 0 ]; do
  case "$1" in
    --profile) requested="${2:-}"; shift 2 ;;
    --profile=*) requested="${1#*=}"; shift ;;
    --os) OS="${2:-}"; shift 2 ;;
    --os=*) OS="${1#*=}"; shift ;;
    --first-time|--reconfigure) FIRST_TIME=1; shift ;;
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

choices_for_os() {
  case "$OS" in
    omarchy)
      printf "%s\n" desktop-omarchy work-omarchy minimal
      ;;
    macos)
      printf "%s\n" personal-macos work-macos minimal
      ;;
    debian)
      printf "%s\n" server-debian minimal
      ;;
    ubuntu)
      printf "%s\n" server-ubuntu minimal
      ;;
    *)
      printf "%s\n" minimal
      ;;
  esac
}

profile_description() {
  case "$1" in
    desktop-omarchy) printf "Omarchy desktop workstation" ;;
    work-omarchy) printf "Omarchy work laptop" ;;
    personal-macos) printf "macOS personal laptop" ;;
    work-macos) printf "macOS work laptop" ;;
    server-debian) printf "Debian personal server" ;;
    server-ubuntu) printf "Ubuntu work server" ;;
    minimal) printf "minimal shell and common CLI" ;;
    *) printf "%s" "$1" ;;
  esac
}

run_wizard() {
  if ! is_interactive; then
    warn "No tty available for first-run profile wizard; falling back to 'minimal'." >&2
    printf "minimal\n"
    return 0
  fi

  local choices=() choice index reply selected confirm_reply
  while IFS= read -r choice; do
    [ -n "$choice" ] || continue
    profile_exists "$choice" && choices+=("$choice")
  done < <(choices_for_os)
  [ "${#choices[@]}" -gt 0 ] || die "No valid profiles found for OS '$OS'"

  printf "\nDotfiles first-run profile setup\n" > /dev/tty
  printf "Detected OS: %s\n" "${OS:-unknown}" > /dev/tty
  printf "Choose this machine's role:\n" > /dev/tty
  index=1
  for choice in "${choices[@]}"; do
    printf "  %d) %s - %s\n" "$index" "$choice" "$(profile_description "$choice")" > /dev/tty
    index=$((index + 1))
  done

  while true; do
    printf "profile [1]: " > /dev/tty
    read -r reply < /dev/tty
    [ -n "$reply" ] || reply=1
    case "$reply" in
      *[!0-9]*|"") warn "Invalid selection: $reply" >&2 ;;
      *)
        if [ "$reply" -ge 1 ] && [ "$reply" -le "${#choices[@]}" ]; then
          selected="${choices[$((reply - 1))]}"
          break
        fi
        warn "Invalid selection: $reply" >&2
        ;;
    esac
  done

  while true; do
    printf "Use and save profile '%s'? [Y/n] " "$selected" > /dev/tty
    read -r confirm_reply < /dev/tty
    case "$confirm_reply" in
      ""|[yY]|[yY][eE][sS]) printf "%s\n" "$selected"; return 0 ;;
      [nN]|[nN][oO]) warn "Profile setup canceled; falling back to 'minimal'." >&2; printf "minimal\n"; return 0 ;;
      *) warn "Please answer yes or no." >&2 ;;
    esac
  done
}

choose() {
  if [ -n "$requested" ]; then
    profile_exists "$requested" || die "Unknown profile: $requested (have: $(list_profiles | tr '\n' ' '))"
    printf "%s\n" "$requested"
    return 0
  fi

  if [ "$FIRST_TIME" = "1" ]; then
    run_wizard
    return 0
  fi

  if [ -f "$STATE_FILE" ]; then
    local saved
    saved="$(tr -d '[:space:]' < "$STATE_FILE")"
    if [ -n "$saved" ] && profile_exists "$saved"; then
      info "Using saved profile: $saved" >&2
      printf "%s\n" "$saved"
      return 0
    fi
    warn "Saved profile '$saved' no longer exists; running first-run setup." >&2
  fi

  run_wizard
}

selected="$(choose)"
persist "$selected"
printf "%s\n" "$selected"
