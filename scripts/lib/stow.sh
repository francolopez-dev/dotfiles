#!/usr/bin/env bash
# Stow helpers. Source after lib/common.sh.

# stow_layer <layer-dir-name> [extra stow args...]
# Applies a single layer directory into $HOME using GNU stow.
stow_layer() {
  local layer="$1"; shift || true
  local dir="$DOTFILES_DIR/stow/$layer"
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
  stow --dir="$dir" --target="$HOME" "$@" "${pkgs[@]}"
}

# apply_all_layers [extra stow args...]
# Applies every layer for this machine, in order.
apply_all_layers() {
  local layer
  while read -r layer; do
    [[ -z "$layer" ]] && continue
    info "stow layer: $layer"
    stow_layer "$layer" "$@"
  done < <(resolve_layers)
}
