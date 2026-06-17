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

requested="" OS="" FIRST_TIME=0 NO_PERSIST=0 SELECTED="" PERSIST_SELECTED=0
while [ $# -gt 0 ]; do
  case "$1" in
    --profile) requested="${2:-}"; shift 2 ;;
    --profile=*) requested="${1#*=}"; shift ;;
    --os) OS="${2:-}"; shift 2 ;;
    --os=*) OS="${1#*=}"; shift ;;
    --first-time|--reconfigure) FIRST_TIME=1; shift ;;
    --no-persist|--dry-run) NO_PERSIST=1; shift ;;
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

detect_chassis() {
  if [ -n "${DOTFILES_CHASSIS:-}" ]; then
    printf "%s\n" "$DOTFILES_CHASSIS"
    return 0
  fi
  if [ -r /sys/class/dmi/id/chassis_type ]; then
    case "$(cat /sys/class/dmi/id/chassis_type 2>/dev/null)" in
      8|9|10|14) printf "laptop\n"; return 0 ;;
      3|4|5|6|7|13|15|16) printf "desktop\n"; return 0 ;;
    esac
  fi
  if need_cmd hostnamectl; then
    case "$(hostnamectl 2>/dev/null | awk -F: '/Chassis:/ { gsub(/^[[:space:]]+/, "", $2); print $2; exit }')" in
      laptop|convertible|tablet) printf "laptop\n"; return 0 ;;
      desktop|tower|workstation) printf "desktop\n"; return 0 ;;
    esac
  fi
  printf "unknown\n"
}

persist() {
  [ "$NO_PERSIST" = "0" ] || return 0
  mkdir -p "$STATE_DIR"
  printf "%s\n" "$1" > "$STATE_FILE"
}

migrate_profile_name() {
  local old="$1"
  case "$old:$OS" in
    work-laptop:omarchy|work-omarchy:omarchy) printf "laptop-work-omarchy\n" ;;
    personal-laptop:omarchy) printf "laptop-personal-omarchy\n" ;;
    domum-workstation:omarchy|desktop-omarchy:omarchy) printf "desktop-personal-omarchy\n" ;;
    personal-laptop:macos) printf "personal-macos\n" ;;
    work-laptop:macos) printf "work-macos\n" ;;
    linux-server-personal:debian) printf "server-debian\n" ;;
    linux-server-work:ubuntu) printf "server-ubuntu\n" ;;
    *) return 1 ;;
  esac
}

choices_for_os() {
  local chassis
  chassis="$(detect_chassis)"
  case "$OS" in
    omarchy)
      if [ "$chassis" = "laptop" ]; then
        printf "%s\n" laptop-work-omarchy laptop-personal-omarchy desktop-personal-omarchy desktop-work-omarchy minimal
      else
        printf "%s\n" desktop-personal-omarchy desktop-work-omarchy laptop-work-omarchy laptop-personal-omarchy minimal
      fi
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
    desktop-personal-omarchy) printf "Omarchy personal desktop" ;;
    desktop-work-omarchy) printf "Omarchy work desktop" ;;
    laptop-personal-omarchy) printf "Omarchy personal laptop" ;;
    laptop-work-omarchy) printf "Omarchy work laptop" ;;
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
    warn "No tty available for first-run profile wizard; using unsaved 'minimal' fallback." >&2
    SELECTED="minimal"
    PERSIST_SELECTED=0
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
  printf "Detected chassis: %s\n" "$(detect_chassis)" > /dev/tty
  printf "Choose this machine type:\n" > /dev/tty
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
    if [ "$NO_PERSIST" = "1" ]; then
      printf "Use profile '%s' for this dry run? [Y/n] " "$selected" > /dev/tty
    else
      printf "Use and save profile '%s'? [Y/n] " "$selected" > /dev/tty
    fi
    read -r confirm_reply < /dev/tty
    case "$confirm_reply" in
      ""|[yY]|[yY][eE][sS]) SELECTED="$selected"; PERSIST_SELECTED=1; return 0 ;;
      [nN]|[nN][oO]) warn "Profile setup canceled; no profile was saved." >&2; return 2 ;;
      *) warn "Please answer yes or no." >&2 ;;
    esac
  done
}

choose() {
  if [ -n "$requested" ]; then
    profile_exists "$requested" || die "Unknown profile: $requested (have: $(list_profiles | tr '\n' ' '))"
    SELECTED="$requested"
    PERSIST_SELECTED=1
    return 0
  fi

  if [ "$FIRST_TIME" = "1" ]; then
    run_wizard
    return $?
  fi

  if [ -f "$STATE_FILE" ]; then
    local saved migrated
    saved="$(tr -d '[:space:]' < "$STATE_FILE")"
    if [ -n "$saved" ] && profile_exists "$saved"; then
      info "Using saved profile: $saved" >&2
      SELECTED="$saved"
      PERSIST_SELECTED=0
      return 0
    fi
    if [ -n "$saved" ] && migrated="$(migrate_profile_name "$saved")" && profile_exists "$migrated"; then
      warn "Migrating saved profile '$saved' -> '$migrated'." >&2
      SELECTED="$migrated"
      PERSIST_SELECTED=1
      return 0
    fi
    warn "Saved profile '$saved' no longer exists; running first-run setup." >&2
  fi

  run_wizard
}

choose
[ "$PERSIST_SELECTED" = "1" ] && persist "$SELECTED"
printf "%s\n" "$SELECTED"
