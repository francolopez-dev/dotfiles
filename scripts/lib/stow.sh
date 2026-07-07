#!/usr/bin/env bash
# Stow helpers. Source after lib/common.sh.

require_stow() {
  if command -v stow >/dev/null 2>&1; then
    return 0
  fi
  err "GNU Stow is not installed; run 'dotfiles update' or install package 'stow'"
  return 1
}

stow_package_conflicts() {
  local layer="$1" pkg="$2"
  local pkg_dir="$DOTFILES_DIR/stow/$layer/$pkg"
  local src rel target link_target src_resolved target_resolved
  [[ -d "$pkg_dir" ]] || return 0
  while IFS= read -r -d '' src; do
    rel="${src#"$pkg_dir"/}"
    target="$HOME/$rel"
    if [[ ! -e "$target" && ! -L "$target" ]]; then
      continue
    fi
    if [[ -L "$target" ]]; then
      link_target="$(readlink "$target")"
      if [[ "$link_target" == "$src" || "$link_target" == "${src#"$HOME"/}" ]]; then
        continue
      fi
      src_resolved="$(readlink -f "$src" 2>/dev/null || true)"
      target_resolved="$(readlink -f "$target" 2>/dev/null || true)"
      if [[ -n "$src_resolved" && "$src_resolved" == "$target_resolved" ]]; then
        continue
      fi
    fi
    printf '%s\n' "$target"
  done < <(find "$pkg_dir" \( -type f -o -type l \) -print0)
}

stow_backup_conflicts() {
  local backup_root="$1" target rel dest
  shift
  for target in "$@"; do
    rel="${target#"$HOME"/}"
    dest="$backup_root/$rel"
    mkdir -p "$(dirname "$dest")"
    mv "$target" "$dest"
  done
}

stow_conflict_choice() {
  local layer="$1" pkg="$2" conflicts_file="$3" choice="${DOTFILES_STOW_CONFLICTS:-}"
  case "$choice" in
    backup|skip|adopt) printf '%s\n' "$choice"; return 0 ;;
    "") ;;
    *) warn "unknown DOTFILES_STOW_CONFLICTS=$choice; using safe conflict handling" ;;
  esac

  if ! have_tty; then
    warn "stow conflicts for $layer/$pkg and no TTY available; skipping package"
    warn "set DOTFILES_STOW_CONFLICTS=backup to allow non-interactive backup+stow"
    printf 'skip\n'
    return 0
  fi

  {
    printf '\nStow conflicts detected for %s/%s:\n' "$layer" "$pkg"
    sed 's|^|  |' "$conflicts_file"
    printf '\nChoose:\n'
    printf '  1) backup existing files and stow repo version [recommended]\n'
    printf '  2) skip this package\n'
    printf '  3) adopt existing files into repo [advanced]\n'
    printf 'Selection [1]: '
  } >/dev/tty
  IFS= read -r choice </dev/tty || true
  case "${choice:-1}" in
    1|backup|b|B) printf 'backup\n' ;;
    2|skip|s|S) printf 'skip\n' ;;
    3|adopt|a|A) printf 'adopt\n' ;;
    *) warn "unknown choice '$choice'; skipping $layer/$pkg"; printf 'skip\n' ;;
  esac
}

stow_one_package() {
  local layer="$1" pkg="$2"
  shift 2 || true
  local dir="$DOTFILES_DIR/stow/$layer" conflicts_file conflict_count action backup_root
  local conflicts=()
  conflicts_file="$(mktemp)"
  stow_package_conflicts "$layer" "$pkg" >"$conflicts_file"
  conflict_count="$(wc -l <"$conflicts_file")"

  if [[ "$conflict_count" -gt 0 && " $* " == *" --no "* ]]; then
    warn "stow conflicts detected for $layer/$pkg"
    sed 's|^|  |' "$conflicts_file" >&2
    rm -f "$conflicts_file"
    # Dry-run must report conflicts in its exit code so status/doctor/update
    # cannot claim "clean" while conflicts exist.
    return 1
  fi

  if [[ "$conflict_count" -gt 0 ]]; then
    action="$(stow_conflict_choice "$layer" "$pkg" "$conflicts_file")"
    case "$action" in
      backup)
        backup_root="${DOTFILES_BACKUP_DIR:-$HOME/.dotfiles-backup/$(date +%Y-%m-%d-%H%M%S)}"
        info "backing up $conflict_count conflict(s) for $layer/$pkg to $backup_root"
        mapfile -t conflicts <"$conflicts_file"
        stow_backup_conflicts "$backup_root" "${conflicts[@]}"
        ;;
      adopt)
        warn "adopting existing files into repo for $layer/$pkg"
        stow --no-folding --dir="$dir" --target="$HOME" --adopt "$@" "$pkg"
        rm -f "$conflicts_file"
        return 0
        ;;
      skip)
        rm -f "$conflicts_file"
        return 1
        ;;
    esac
  fi

  rm -f "$conflicts_file"
  stow --no-folding --dir="$dir" --target="$HOME" "$@" "$pkg"
}

# stow_layer <layer-dir-name> [extra stow args...]
# Applies a single layer directory into $HOME using GNU stow.
stow_layer() {
  local layer="$1"; shift || true
  local dir="$DOTFILES_DIR/stow/$layer"
  local failed=0
  if [[ ! -d "$dir" ]]; then
    warn "layer '$layer' not found, skipping"
    return 0
  fi
  # Each immediate subdirectory of a layer is a stow package.
  local pkgs=()
  local p
  for p in "$dir"/*/; do
    [[ -d "$p" ]] && pkgs+=("$(basename "$p")")
  done
  if [[ ${#pkgs[@]} -eq 0 ]]; then
    dim "  ($layer: no packages)"
    return 0
  fi
  for p in "${pkgs[@]}"; do
    if ! stow_one_package "$layer" "$p" "$@"; then
      failed=1
      warn "skipped or failed stow package: $layer/$p"
    fi
  done
  return "$failed"
}

# apply_all_layers [extra stow args...]
# Applies every layer for this machine, in order.
apply_all_layers() {
  local layer failed=0
  require_stow || return 1
  while read -r layer; do
    [[ -z "$layer" ]] && continue
    info "stow layer: $layer"
    if ! stow_layer "$layer" "$@"; then
      failed=1
    fi
  done < <(resolve_layers)
  return "$failed"
}
