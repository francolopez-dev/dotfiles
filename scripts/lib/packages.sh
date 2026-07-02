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
  command -v paru >/dev/null 2>&1 && echo "paru -S --needed" || echo ""
}

known_aur_package() {
  case "$1" in
    zen-browser-bin) return 0 ;;
    *) return 1 ;;
  esac
}

known_pacman_package() {
  case "$1" in
    git|stow|tmux|fzf|ripgrep|jq|bat|eza|fastfetch|btop|htop|neovim|zsh|curl|bash|wget|nano|ca-certificates|shellcheck|atuin|networkmanager|tailscale|playerctl|pamixer|power-profiles-daemon|iw|ghostty|alacritty|vivaldi|firefox|gsimplecal|zoxide|yazi|satty|socat|restic|age|pacman|base-devel) return 0 ;;
    *) return 1 ;;
  esac
}

aur_packages_declared() {
  local pkg
  while read -r pkg; do
    [[ -n "$pkg" ]] && return 0
  done < <(desired_aur_packages)
  return 1
}

validate_package_source_overlap() {
  local failed=0 pkg
  while read -r pkg; do
    [[ -z "$pkg" ]] && continue
    warn "package declared in both pacman and AUR: $pkg"
    warn "declare the package in pacman.txt or aur.txt, not both"
    failed=1
  done < <(comm -12 <(desired_pacman_packages | sort -u) <(desired_aur_packages | sort -u))
  return "$failed"
}

validate_pacman_package_names() {
  local failed=0 pkg
  while read -r pkg; do
    [[ -z "$pkg" ]] && continue
    if known_aur_package "$pkg"; then
      warn "$pkg is declared as pacman but was not found."
      warn "Move it to aur.txt or choose a valid pacman package."
      failed=1
    elif command -v pacman >/dev/null 2>&1 && ! pacman -Si "$pkg" >/dev/null 2>&1; then
      warn "$pkg is declared as pacman but was not found."
      warn "Move it to aur.txt or choose a valid pacman package."
      failed=1
    fi
  done < <(desired_pacman_packages)
  return "$failed"
}

validate_aur_package_names() {
  local failed=0 pkg
  while read -r pkg; do
    [[ -z "$pkg" ]] && continue
    if known_aur_package "$pkg"; then
      continue
    elif known_pacman_package "$pkg"; then
      warn "forbidden AUR package declaration: $pkg belongs in pacman.txt"
      failed=1
    elif command -v pacman >/dev/null 2>&1 && pacman -Si "$pkg" >/dev/null 2>&1; then
      warn "forbidden AUR package declaration: $pkg exists in official repos; move it to pacman.txt"
      failed=1
    fi
  done < <(desired_aur_packages)
  return "$failed"
}

validate_package_declarations() {
  local failed=0
  validate_package_source_overlap || failed=1
  validate_pacman_package_names || failed=1
  validate_aur_package_names || failed=1
  return "$failed"
}

install_paru_from_aur() {
  local build_root pkg_file
  local pkg_files=()

  if ! command -v pacman >/dev/null 2>&1; then
    warn "pacman is required to install AUR build prerequisites for paru"
    return 1
  fi
  if ! command -v git >/dev/null 2>&1; then
    warn "git is required to clone paru from AUR"
    return 1
  fi
  if ! have_tty; then
    warn "paru bootstrap from AUR requires a TTY for makepkg/provider prompts"
    return 1
  fi

  info "Installing AUR build prerequisites with pacman: base-devel"
  # shellcheck disable=SC2024
  if ! sudo pacman -S --needed base-devel </dev/tty; then
    warn "failed to install AUR build prerequisites: base-devel"
    return 1
  fi
  if ! command -v makepkg >/dev/null 2>&1; then
    warn "makepkg is required to build paru but is still missing"
    return 1
  fi

  build_root="$(mktemp -d)"
  if ! git clone https://aur.archlinux.org/paru.git "$build_root/paru"; then
    rm -rf "$build_root"
    warn "failed to clone paru AUR package"
    return 1
  fi

  if ! (
    cd "$build_root/paru" || exit 1
    makepkg -s </dev/tty
  ); then
    rm -rf "$build_root"
    warn "paru AUR build failed"
    return 1
  fi

  for pkg_file in "$build_root"/paru/paru-*.pkg.tar.*; do
    [[ -e "$pkg_file" ]] || continue
    case "$(basename "$pkg_file")" in
      paru-debug-*|*.sig) continue ;;
    esac
    pkg_files+=("$pkg_file")
  done
  if [[ ${#pkg_files[@]} -eq 0 ]]; then
    rm -rf "$build_root"
    warn "paru build completed but no installable paru package was found"
    return 1
  fi

  info "Installing built paru package with pacman"
  # shellcheck disable=SC2024
  if ! sudo pacman -U --needed "${pkg_files[@]}" </dev/tty; then
    rm -rf "$build_root"
    warn "failed to install built paru package"
    return 1
  fi
  rm -rf "$build_root"
}

ensure_paru_available() {
  local dry="$1"
  shift || true
  local declared_aur=("$@")

  if command -v paru >/dev/null 2>&1; then
    return 0
  fi
  if [[ "$dry" -eq 1 ]]; then
    dim "  would ensure paru AUR helper is installed before required AUR packages: ${declared_aur[*]}"
    return 0
  fi
  if ! have_tty; then
    warn "This profile requires AUR packages: ${declared_aur[*]}."
    warn "paru is required but is not installed; rerun from a TTY so paru can be installed."
    return 1
  fi

  info "This profile requires AUR packages: ${declared_aur[*]}."
  info "paru is required before AUR packages can be installed."
  if command -v pacman >/dev/null 2>&1 && pacman -Si paru >/dev/null 2>&1; then
    info "Installing paru with pacman"
    # shellcheck disable=SC2024
    if ! sudo pacman -S --needed paru </dev/tty; then
      warn "failed to install paru with pacman"
      return 1
    fi
  else
    info "paru is required and must be built once from AUR."
    info "This can take several minutes."
    info "Bootstrapping paru from AUR with git and makepkg"
    install_paru_from_aur || return 1
  fi

  if ! command -v paru >/dev/null 2>&1; then
    warn "paru install completed but paru is still not on PATH"
    return 1
  fi
}
