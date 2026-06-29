#!/usr/bin/env bash
# Package helpers. Source after lib/common.sh.

package_file_items() {
  local f
  while read -r f; do
    [[ -z "$f" ]] && continue
    sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$f"
  done | awk 'NF'
}

dedupe_packages() { awk '!seen[$0]++'; }

# desired_packages — prints the deduped, ordered set of declared packages
# for this machine (global + os + profile), ignoring blank/comment lines.
desired_packages() {
  case "$(detect_os)" in
    omarchy) { desired_pacman_packages; desired_aur_packages; } | dedupe_packages ;;
    debian|ubuntu) desired_apt_packages ;;
  esac
}

desired_pacman_packages() { resolve_package_files pacman | package_file_items | dedupe_packages; }

desired_aur_packages() { resolve_package_files aur | package_file_items | dedupe_packages; }

desired_apt_packages() { resolve_package_files apt | package_file_items | dedupe_packages; }

# pkg_manager — echoes the native installer command base for this OS.
pkg_manager() {
  case "$(detect_os)" in
    omarchy) echo "sudo pacman -S --needed" ;;
    debian|ubuntu) echo "sudo apt-get install -y" ;;
    *) echo "" ;;
  esac
}

aur_pkg_manager() {
  command -v yay >/dev/null 2>&1 && echo "yay -S --needed --batchinstall" || echo ""
}

is_forbidden_aur_package() {
  case "$1" in
    git|stow|zsh|curl|bash|ca-certificates|pacman|base-devel|zen-browser-bin) return 0 ;;
    *) return 1 ;;
  esac
}

validate_aur_package_names() {
  local failed=0 pkg
  while read -r pkg; do
    [[ -z "$pkg" ]] && continue
    if is_forbidden_aur_package "$pkg"; then
      warn "forbidden AUR package declaration: $pkg belongs in pacman.txt"
      failed=1
    elif command -v pacman >/dev/null 2>&1 && pacman -Si "$pkg" >/dev/null 2>&1; then
      warn "forbidden AUR package declaration: $pkg exists in official repos; move it to pacman.txt"
      failed=1
    fi
  done < <(desired_aur_packages)
  return "$failed"
}
