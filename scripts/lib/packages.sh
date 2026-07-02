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
  paru_health_status >/dev/null 2>&1 && echo "paru -S --needed" || echo ""
}

paru_health_status() {
  local path output lib first_line
  path="$(command -v paru 2>/dev/null || true)"
  if [[ -z "$path" ]]; then
    printf 'missing\n'
    return 1
  fi
  if output="$(paru --version 2>&1)"; then
    printf 'ready\n'
    return 0
  fi
  lib="$(printf '%s\n' "$output" | sed -n 's/.*\(libalpm\.so\.[^: ]*\).*/\1/p' | sed -n '1p')"
  if [[ -n "$lib" ]]; then
    printf 'broken: missing %s\n' "$lib"
  else
    first_line="$(printf '%s\n' "$output" | sed -n '1p')"
    printf 'broken: %s\n' "${first_line:-paru --version failed}"
  fi
  return 2
}

paru_is_ready() { [[ "$(paru_health_status 2>/dev/null || true)" == "ready" ]]; }

print_paru_diagnostics() {
  local path lib_file found_libalpm=0
  path="$(command -v paru 2>/dev/null || true)"
  [[ -n "$path" ]] || return 0
  warn "paru diagnostic: $path"
  if command -v ldd >/dev/null 2>&1; then
    ldd "$path" 2>&1 | sed 's/^/  /' >&2 || true
  fi
  for lib_file in /usr/lib/libalpm.so*; do
    [[ -e "$lib_file" ]] || continue
    found_libalpm=1
    printf '  %s\n' "$lib_file" >&2
  done
  [[ $found_libalpm -eq 1 ]] || printf '  no /usr/lib/libalpm.so* files found\n' >&2
  pacman -Q pacman 2>&1 | sed 's/^/  /' >&2 || true
}

remove_broken_paru_bin() {
  command -v pacman >/dev/null 2>&1 || return 1
  pacman -Qq paru-bin >/dev/null 2>&1 || return 0
  info "Removing broken paru-bin before source fallback"
  # shellcheck disable=SC2024
  sudo pacman -Rns --noconfirm paru-bin </dev/tty
}

known_aur_package() {
  case "$1" in
    paru-bin|zen-browser-bin) return 0 ;;
    *) return 1 ;;
  esac
}

allowed_source_aur_package() {
  case "$1" in
    # Source-built AUR packages must be explicitly justified here.
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
    if [[ "$pkg" == *-git ]] && ! allowed_source_aur_package "$pkg"; then
      warn "forbidden source AUR package declaration: $pkg"
      warn "prefer official repos, then binary packages, then *-bin; source builds require an explicit override"
      failed=1
    elif [[ "$pkg" != *-bin ]] && ! allowed_source_aur_package "$pkg"; then
      warn "non-binary AUR package declaration requires review: $pkg"
      warn "prefer an official repo package or maintained *-bin package when available"
      failed=1
    fi
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

install_paru_bin_from_aur() {
  local build_root pkg_file
  local pkg_files=()

  if ! command -v pacman >/dev/null 2>&1; then
    warn "pacman is required to install paru-bin"
    return 1
  fi
  if ! command -v git >/dev/null 2>&1; then
    warn "git is required to clone paru-bin from AUR"
    return 1
  fi
  if ! have_tty; then
    warn "paru-bin bootstrap from AUR requires a TTY for makepkg/provider prompts"
    return 1
  fi
  if ! command -v makepkg >/dev/null 2>&1; then
    info "Installing AUR packaging prerequisites with pacman: base-devel"
    # shellcheck disable=SC2024
    if ! sudo pacman -S --needed base-devel </dev/tty; then
      warn "failed to install AUR packaging prerequisites: base-devel"
      return 1
    fi
  fi
  if ! command -v makepkg >/dev/null 2>&1; then
    warn "makepkg is required to package paru-bin but is still missing"
    return 1
  fi

  build_root="$(mktemp -d)"
  if ! git clone https://aur.archlinux.org/paru-bin.git "$build_root/paru-bin"; then
    rm -rf "$build_root"
    warn "failed to clone paru-bin AUR package"
    return 1
  fi

  if ! (
    cd "$build_root/paru-bin" || exit 1
    makepkg -s </dev/tty
  ); then
    rm -rf "$build_root"
    warn "paru-bin package build failed"
    return 1
  fi

  for pkg_file in "$build_root"/paru-bin/paru-bin-*.pkg.tar.*; do
    [[ -e "$pkg_file" ]] || continue
    case "$(basename "$pkg_file")" in
      paru-bin-debug-*|*.sig) continue ;;
    esac
    pkg_files+=("$pkg_file")
  done
  if [[ ${#pkg_files[@]} -eq 0 ]]; then
    rm -rf "$build_root"
    warn "paru-bin build completed but no installable package was found"
    return 1
  fi

  info "Installing paru-bin package with pacman"
  # shellcheck disable=SC2024
  if ! sudo pacman -U --needed "${pkg_files[@]}" </dev/tty; then
    rm -rf "$build_root"
    warn "failed to install paru-bin package"
    return 1
  fi
  rm -rf "$build_root"
}

ensure_paru_available() {
  local dry="$1"
  shift || true
  local declared_aur=("$@") health

  health="$(paru_health_status 2>/dev/null || true)"
  if [[ "$health" == "ready" ]]; then
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
  if [[ "$health" == broken:* ]]; then
    warn "paru installed but broken: ${health#broken: }"
    print_paru_diagnostics
    if pacman -Qq paru-bin >/dev/null 2>&1; then
      if [[ "$health" == *libalpm.so.* ]]; then
        warn "paru-bin is installed but incompatible with the current pacman/libalpm. Falling back to source-built paru."
      fi
      warn "Prebuilt paru-bin is incompatible with this system. Building paru from source is required this time."
      remove_broken_paru_bin || return 1
      install_paru_from_aur || return 1
    else
      return 1
    fi
  elif command -v pacman >/dev/null 2>&1 && pacman -Si paru >/dev/null 2>&1; then
    info "Installing paru with pacman"
    # shellcheck disable=SC2024
    if ! sudo pacman -S --needed paru </dev/tty; then
      warn "failed to install paru with pacman"
      return 1
    fi
    health="$(paru_health_status 2>/dev/null || true)"
    if [[ "$health" != "ready" ]]; then
      warn "pacman paru installed but failed validation: ${health#broken: }"
      print_paru_diagnostics
      return 1
    fi
  else
    info "pacman does not provide paru; bootstrapping paru-bin from AUR"
    if install_paru_bin_from_aur; then
      health="$(paru_health_status 2>/dev/null || true)"
      if [[ "$health" != "ready" ]]; then
        warn "paru-bin installed but failed validation: ${health#broken: }"
        print_paru_diagnostics
        if [[ "$health" == *libalpm.so.* ]]; then
          warn "paru-bin is installed but incompatible with the current pacman/libalpm. Falling back to source-built paru."
        fi
        warn "Prebuilt paru-bin is incompatible with this system. Building paru from source is required this time."
        remove_broken_paru_bin || return 1
        install_paru_from_aur || return 1
      fi
    else
      warn "paru-bin bootstrap failed; falling back to source-built paru as a last resort"
      info "This can take several minutes."
      info "Bootstrapping paru from AUR with git and makepkg"
      install_paru_from_aur || return 1
    fi
  fi

  health="$(paru_health_status 2>/dev/null || true)"
  if [[ "$health" != "ready" ]]; then
    warn "paru install completed but paru failed validation: ${health#broken: }"
    print_paru_diagnostics
    return 1
  fi
}
