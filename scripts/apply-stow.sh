#!/usr/bin/env bash
set -euo pipefail
# Symlink a profile's STOW_PACKAGES into $HOME using GNU Stow.
#
# Usage:
#   apply-stow.sh --profile NAME [--adopt]
#
# Honors DRY_RUN=1 -> uses `stow --no -v` (simulate, no changes).
# --adopt: opt-in; let stow adopt existing real files into the repo
#          (review the resulting git diff afterwards!).
#
# Conflicting real (non-symlink) ~/.bashrc and ~/.zshrc are backed up to
# ~/.dotfiles-backup before stowing, matching the previous installer behavior.

. "$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/lib.sh"

PROFILES_DIR="${PROFILES_DIR:-$REPO_DIR/profiles}"
STOW_DIR="${STOW_DIR:-$REPO_DIR/stow}"

PROFILE="" ADOPT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --profile) PROFILE="${2:-}"; shift 2 ;;
    --adopt)   ADOPT=1;          shift ;;
    *) die "apply-stow: unknown arg: $1" ;;
  esac
done
[ -n "$PROFILE" ] || die "apply-stow: --profile required"

STOW_PACKAGES=()
# shellcheck source=/dev/null
. "$PROFILES_DIR/$PROFILE.conf"

need_cmd stow || die "stow is not installed (run the package step first)."
[ -d "$STOW_DIR" ] || die "stow dir not found: $STOW_DIR"

backup_conflicts() {
  local backup_dir="$HOME/.dotfiles-backup" ts f
  ts="$(date +%F-%H%M%S)"
  for f in .bashrc .zshrc; do
    if [ -e "$HOME/$f" ] && [ ! -L "$HOME/$f" ]; then
      run mkdir -p "$backup_dir"
      info "Backing up existing ~/$f -> $backup_dir/${f}.${ts}"
      run mv "$HOME/$f" "$backup_dir/${f}.${ts}"
    fi
  done
}

main() {
  info "Stow packages for profile '$PROFILE': ${STOW_PACKAGES[*]:-<none>}"

  # --no-folding keeps managed directories as real dirs (file-level symlinks),
  # so machine-local files like ~/.config/shell/env.local can coexist.
  local flags=(-t "$HOME" --no-folding)
  [ "$DRY_RUN" = "1" ] && flags+=(--no -v)
  [ "$ADOPT" = "1" ] && flags+=(--adopt)

  # Only back up conflicts on a real apply (not dry-run / adopt).
  if [ "$DRY_RUN" != "1" ] && [ "$ADOPT" != "1" ]; then
    backup_conflicts
  fi

  cd "$REPO_DIR"
  local pkg
  for pkg in "${STOW_PACKAGES[@]}"; do
    if [ ! -d "$STOW_DIR/$pkg" ]; then
      warn "missing stow package: $pkg (skipping)"
      continue
    fi
    info "Stowing: $pkg"
    stow "${flags[@]}" "$pkg" || warn "stow reported issues for: $pkg"
  done

  ok "Stow step complete."
}

main
