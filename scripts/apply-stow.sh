#!/usr/bin/env bash
set -euo pipefail
# Symlink a profile's STOW_PACKAGES into $HOME using GNU Stow.
#
# Usage:
#   apply-stow.sh --profile NAME --os OS [--adopt] [--backup-conflicts]
#
# Honors DRY_RUN=1 -> uses `stow --no -v` (simulate, no changes).
# Default conflict behavior is non-destructive: prompt on a tty, otherwise skip.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=scripts/lib.sh
. "$SCRIPT_DIR/lib.sh"

PROFILES_DIR="${PROFILES_DIR:-$REPO_DIR/profiles}"
STOW_DIR="${STOW_DIR:-$REPO_DIR/stow}"
STOW_OS_MAP="${STOW_OS_MAP:-$PROFILES_DIR/stow-os.map}"

PROFILE="" OS="" ADOPT=0 BACKUP_CONFLICTS=0
while [ $# -gt 0 ]; do
  case "$1" in
    --profile) PROFILE="${2:-}"; shift 2 ;;
    --profile=*) PROFILE="${1#*=}"; shift ;;
    --os) OS="${2:-}"; shift 2 ;;
    --os=*) OS="${1#*=}"; shift ;;
    --adopt) ADOPT=1; shift ;;
    --backup-conflicts) BACKUP_CONFLICTS=1; shift ;;
    *) die "apply-stow: unknown arg: $1" ;;
  esac
done
[ -n "$PROFILE" ] || die "apply-stow: --profile required"
[ -n "$OS" ] || die "apply-stow: --os required"

STOW_PACKAGES=()
# shellcheck source=/dev/null
. "$PROFILES_DIR/$PROFILE.conf"

need_cmd stow || die "stow is not installed (run the package step first)."
[ -d "$STOW_DIR" ] || die "stow dir not found: $STOW_DIR"

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
  [ "$oses" = "all" ] && return 0
  IFS=',' read -r -a _os_parts <<< "$oses"
  for os in "${_os_parts[@]}"; do
    [ "$os" = "$wanted" ] && return 0
  done
  return 1
}

stow_preview() {
  local pkg="$1"
  (cd "$REPO_DIR" && stow --no -v --no-folding -t "$HOME" "$pkg" 2>&1) || true
}

conflicts_for_pkg() {
  local pkg="$1" line path
  while IFS= read -r line; do
    case "$line" in
      *"existing target is neither a link nor a directory:"*)
        path="${line##*: }"
        printf "%s\n" "$path"
        ;;
      *"existing target is not owned by stow:"*)
        path="${line##*: }"
        printf "%s\n" "$path"
        ;;
      *"existing target is stowed to a different package:"*)
        path="${line##*: }"
        printf "%s\n" "$path"
        ;;
      *" over existing target "*)
        path="${line#* over existing target }"
        path="${path%% since *}"
        case "$path" in
          /*) printf "%s\n" "$path" ;;
          *) printf "%s\n" "$HOME/$path" ;;
        esac
        ;;
    esac
  done < <(stow_preview "$pkg") | sort -u
}

backup_paths() {
  local backup_root path rel dest
  backup_root="$HOME/.dotfiles-backup/$(date +%F-%H%M%S)"
  for path in "$@"; do
    [ -n "$path" ] || continue
    case "$path" in
      "$HOME"/*) rel="${path#"$HOME"/}" ;;
      ~/*) rel="${path#~/}" ;;
      *) rel="${path#/}" ;;
    esac
    dest="$backup_root/$rel"
    info "Backing up $path -> $dest"
    run mkdir -p "$(dirname "$dest")"
    run mv "$path" "$dest"
  done
}

stow_pkg() {
  local pkg="$1" mode="${2:-normal}"
  local flags=(-t "$HOME" --no-folding)
  [ "$DRY_RUN" = "1" ] && flags+=(--no -v)
  [ "$mode" = "adopt" ] && flags+=(--adopt)
  (cd "$REPO_DIR" && stow "${flags[@]}" "$pkg")
}

prompt_conflict_action() {
  local pkg="$1" reply
  while true; do
    printf "Stow package '%s' has conflicts. [s]kip / [b]ackup+stow / [a]dopt: " "$pkg" > /dev/tty
    read -r reply < /dev/tty
    case "$reply" in
      s|S|"") printf "skip\n"; return 0 ;;
      b|B) printf "backup\n"; return 0 ;;
      a|A) printf "adopt\n"; return 0 ;;
      *) warn "Invalid choice: $reply" ;;
    esac
  done
}

handle_conflicting_pkg() {
  local pkg="$1"; shift
  local conflicts=("$@") action

  warn "Conflicts for stow package '$pkg':"
  printf "  %s\n" "${conflicts[@]}" >&2

  if [ "$ADOPT" = "1" ]; then
    action="adopt"
  elif [ "$BACKUP_CONFLICTS" = "1" ]; then
    action="backup"
  elif is_interactive; then
    action="$(prompt_conflict_action "$pkg")"
  else
    action="skip"
  fi

  case "$action" in
    skip)
      warn "Skipping '$pkg' due to conflicts."
      ;;
    backup)
      backup_paths "${conflicts[@]}"
      info "Stowing after backup: $pkg"
      stow_pkg "$pkg" normal || warn "stow reported issues for: $pkg"
      ;;
    adopt)
      warn "Adopting existing files for '$pkg'. Review 'git diff' after this run."
      stow_pkg "$pkg" adopt || warn "stow --adopt reported issues for: $pkg"
      ;;
  esac
}

main() {
  info "Stow packages for profile '$PROFILE' (os=$OS): ${STOW_PACKAGES[*]:-<none>}"

  local pkg oses conflict_output conflict
  for pkg in "${STOW_PACKAGES[@]}"; do
    if [ ! -d "$STOW_DIR/$pkg" ]; then
      warn "missing stow package: $pkg (skipping)"
      continue
    fi

    oses="$(map_os_for_pkg "$pkg")"
    if ! os_list_contains "$oses" "$OS"; then
      info "skip: $pkg (${oses}-only, host is $OS)"
      continue
    fi

    if [ "$DRY_RUN" = "1" ]; then
      info "Stow preview: $pkg"
      stow_pkg "$pkg" normal || warn "stow preview reported issues for: $pkg"
      continue
    fi

    conflict_output=()
    while IFS= read -r conflict; do
      conflict_output+=("$conflict")
    done < <(conflicts_for_pkg "$pkg")
    if [ "${#conflict_output[@]}" -gt 0 ]; then
      handle_conflicting_pkg "$pkg" "${conflict_output[@]}"
      continue
    fi

    info "Stowing: $pkg"
    stow_pkg "$pkg" normal || warn "stow reported issues for: $pkg"
  done

  ok "Stow step complete."
}

main
