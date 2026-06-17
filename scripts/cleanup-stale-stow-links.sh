#!/usr/bin/env bash
set -euo pipefail
# Remove stale repo-owned stow symlinks for packages incompatible with the host OS.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=scripts/lib.sh
. "$SCRIPT_DIR/lib.sh"

PROFILES_DIR="${PROFILES_DIR:-$REPO_DIR/profiles}"
STOW_DIR="${STOW_DIR:-$REPO_DIR/stow}"
STOW_OS_MAP="${STOW_OS_MAP:-$PROFILES_DIR/stow-os.map}"

OS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --os) OS="${2:-}"; shift 2 ;;
    --os=*) OS="${1#*=}"; shift ;;
    --help|-h)
      cat <<'USAGE'
Usage:
  scripts/cleanup-stale-stow-links.sh --os OS

Removes only symlinks under $HOME that point into this dotfiles repo from stow
packages that are incompatible with the current OS per profiles/stow-os.map.
Real files are never removed. Parent directories are removed only if empty.
Honors DRY_RUN=1.
USAGE
      exit 0
      ;;
    *) die "cleanup-stale-stow-links: unknown arg: $1" ;;
  esac
done
[ -n "$OS" ] || die "cleanup-stale-stow-links: --os required"
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

abs_path() {
  local path="$1" dir base
  dir="$(dirname "$path")"
  base="$(basename "$path")"
  (cd "$dir" 2>/dev/null && printf "%s/%s\n" "$(pwd -P)" "$base")
}

remove_empty_parents() {
  local dir="$1"
  while [ "$dir" != "$HOME" ] && [ "$dir" != "/" ]; do
    if [ -d "$dir" ] && rmdir "$dir" 2>/dev/null; then
      ok "removed empty directory: ${dir#"$HOME"/}"
      dir="$(dirname "$dir")"
    else
      break
    fi
  done
}

cleanup_pkg() {
  local pkg="$1"
  local pkg_root="$STOW_DIR/$pkg" src rel target link_target link_abs
  [ -d "$pkg_root" ] || return 0
  while IFS= read -r -d '' src; do
    rel="${src#"$pkg_root"/}"
    target="$HOME/$rel"
    [ -L "$target" ] || continue
    link_target="$(readlink "$target")"
    case "$link_target" in
      /*) link_abs="$(abs_path "$link_target")" ;;
      *) link_abs="$(abs_path "$(dirname "$target")/$link_target")" ;;
    esac
    case "$link_abs" in
      "$REPO_DIR"/stow/"$pkg"/*)
        if [ "$DRY_RUN" = "1" ]; then
          info "[dry-run] would remove stale stow link: ${target#"$HOME"/} -> $link_target"
        else
          rm "$target"
          ok "removed stale stow link: ${target#"$HOME"/} -> $link_target"
          remove_empty_parents "$(dirname "$target")"
        fi
        REMOVED_ANY=1
        ;;
    esac
  done < <(find "$pkg_root" -type f -print0)
}

main() {
  local pkg_path pkg oses
  REMOVED_ANY=0
  info "Cleaning stale incompatible stow links for OS '$OS'"
  for pkg_path in "$STOW_DIR"/*; do
    [ -d "$pkg_path" ] || continue
    pkg="$(basename "$pkg_path")"
    oses="$(map_os_for_pkg "$pkg")"
    if os_list_contains "$oses" "$OS"; then
      continue
    fi
    cleanup_pkg "$pkg"
  done
  if [ "$REMOVED_ANY" = "0" ]; then
    info "No stale incompatible stow links found."
  fi
  ok "Stale stow cleanup complete."
}

main
