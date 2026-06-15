#!/usr/bin/env bash
set -euo pipefail
# Install the packages declared by a profile's PACKAGE_GROUPS for the detected OS.
#
# Reads plain-text per-manager lists at packages/<group>/<mgr>.txt
# (and packages/desktop/brew-cask.txt for macOS GUI apps,
#  packages/<group>/aur.txt for Omarchy AUR via yay).
#
# Usage:
#   install-packages.sh --profile NAME --os OS --pkgmgr MGR [--enforce]
#
# Honors DRY_RUN=1 (via lib.sh run()).
#
# Optional desktop extras (oh-my-zsh / powerlevel10k), gated by env, run only
# when the 'desktop' group is selected:
#   INSTALL_OHMYZSH=1 INSTALL_P10K=1   (both default 1)

. "$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)/lib.sh"

PACKAGES_DIR="${PACKAGES_DIR:-$REPO_DIR/packages}"
PROFILES_DIR="${PROFILES_DIR:-$REPO_DIR/profiles}"
INSTALL_OHMYZSH="${INSTALL_OHMYZSH:-1}"
INSTALL_P10K="${INSTALL_P10K:-1}"

PROFILE="" OS="" PKGMGR="" ENFORCE=0
while [ $# -gt 0 ]; do
  case "$1" in
    --profile) PROFILE="${2:-}"; shift 2 ;;
    --os)      OS="${2:-}";      shift 2 ;;
    --pkgmgr)  PKGMGR="${2:-}";  shift 2 ;;
    --enforce) ENFORCE=1;        shift ;;
    *) die "install-packages: unknown arg: $1" ;;
  esac
done

[ -n "$PROFILE" ] || die "install-packages: --profile required"
[ -n "$PKGMGR" ]  || die "install-packages: --pkgmgr required"

PACKAGE_GROUPS=()
# shellcheck source=/dev/null
. "$PROFILES_DIR/$PROFILE.conf"

# -----------------------------
# Index refresh (once)
# -----------------------------
update_index() {
  case "$PKGMGR" in
    brew)   run brew update || true ;;
    apt)    run sudo apt-get update -y ;;
    pacman) run sudo pacman -Sy --noconfirm ;;
  esac
}

# -----------------------------
# Idempotent single-package install
# -----------------------------
pkg_installed() {
  case "$PKGMGR" in
    brew)   brew list --formula 2>/dev/null | grep -qx "$1" ;;
    apt)    dpkg -s "$1" >/dev/null 2>&1 ;;
    pacman) pacman -Qi "$1" >/dev/null 2>&1 ;;
  esac
}

install_one() {
  local pkg="$1"
  [ -z "$pkg" ] && return 0
  if pkg_installed "$pkg"; then
    dim "ok (already): $pkg"
    return 0
  fi
  info "Installing: $pkg"
  case "$PKGMGR" in
    brew)   run brew install "$pkg" || warn "failed: $pkg (skipping)" ;;
    apt)    run sudo apt-get install -y "$pkg" || warn "failed: $pkg (skipping)" ;;
    pacman) run sudo pacman -S --noconfirm --needed "$pkg" || warn "failed: $pkg (skipping)" ;;
  esac
}

# AUR via yay (Omarchy only)
install_aur() {
  local pkg="$1"
  [ -z "$pkg" ] && return 0
  if ! need_cmd yay; then
    warn "yay not found; cannot install AUR package: $pkg"
    return 0
  fi
  if pacman -Qi "$pkg" >/dev/null 2>&1; then
    dim "ok (already, aur): $pkg"; return 0
  fi
  info "Installing (aur): $pkg"
  run yay -S --noconfirm --needed "$pkg" || warn "failed (aur): $pkg (skipping)"
}

# macOS cask
install_cask() {
  local c="$1"
  [ -z "$c" ] && return 0
  if brew list --cask 2>/dev/null | grep -qx "$c"; then
    dim "ok (already, cask): $c"; return 0
  fi
  info "Installing (cask): $c"
  run brew install --cask "$c" || warn "failed (cask): $c (skipping)"
}

# -----------------------------
# Optional desktop shell extras
# -----------------------------
install_desktop_shell_extras() {
  [ "$INSTALL_OHMYZSH" = "1" ] || return 0
  if [ -d "$HOME/.oh-my-zsh" ]; then
    dim "ok (already): oh-my-zsh"
  elif need_cmd curl; then
    info "Installing oh-my-zsh..."
    run env RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || true
  else
    warn "curl missing; cannot install oh-my-zsh"
  fi

  local custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  run mkdir -p "$custom/plugins" "$custom/themes"
  [ -d "$custom/plugins/zsh-autosuggestions" ] || \
    run git clone https://github.com/zsh-users/zsh-autosuggestions "$custom/plugins/zsh-autosuggestions" || true
  [ -d "$custom/plugins/zsh-syntax-highlighting" ] || \
    run git clone https://github.com/zsh-users/zsh-syntax-highlighting "$custom/plugins/zsh-syntax-highlighting" || true

  if [ "$INSTALL_P10K" = "1" ] && [ ! -d "$custom/themes/powerlevel10k" ]; then
    info "Installing powerlevel10k..."
    run git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$custom/themes/powerlevel10k" || true
  fi
}

# -----------------------------
# Collect declared packages for the active manager (for --enforce)
# -----------------------------
declared_packages() {
  local g
  for g in "${PACKAGE_GROUPS[@]}"; do
    read_list "$PACKAGES_DIR/$g/$PKGMGR.txt"
  done
}

enforce_removals() {
  warn "--enforce: this is the only destructive package operation."
  case "$PKGMGR" in
    pacman)
      local declared installed extra
      declared="$(declared_packages | sort -u)"
      installed="$(pacman -Qqe | sort -u)"
      extra="$(comm -23 <(printf "%s\n" "$installed") <(printf "%s\n" "$declared"))"
      ;;
    apt)
      local declared installed extra
      declared="$(declared_packages | sort -u)"
      installed="$(apt-mark showmanual 2>/dev/null | sort -u)"
      extra="$(comm -23 <(printf "%s\n" "$installed") <(printf "%s\n" "$declared"))"
      ;;
    brew)
      local declared installed extra
      declared="$(declared_packages | sort -u)"
      installed="$(brew leaves 2>/dev/null | sort -u)"
      extra="$(comm -23 <(printf "%s\n" "$installed") <(printf "%s\n" "$declared"))"
      ;;
    *) warn "enforce not supported for $PKGMGR"; return 0 ;;
  esac

  if [ -z "${extra:-}" ]; then
    ok "Nothing to remove; system matches the profile manifest."
    return 0
  fi

  warn "These manually-installed packages are NOT declared by profile '$PROFILE':"
  # shellcheck disable=SC2086  # intentional word-splitting of the package list
  printf "  %s\n" $extra
  if ! confirm "Remove the above packages?"; then
    info "Skipping removals."
    return 0
  fi
  # shellcheck disable=SC2086  # intentional word-splitting of the package list
  case "$PKGMGR" in
    pacman) run sudo pacman -Rns --noconfirm $extra || warn "some removals failed" ;;
    apt)    run sudo apt-get remove -y $extra || warn "some removals failed" ;;
    brew)   run brew uninstall $extra || warn "some removals failed" ;;
  esac
}

# -----------------------------
# Main
# -----------------------------
main() {
  info "Packages for profile '$PROFILE' (os=$OS, mgr=$PKGMGR)"
  info "Groups: ${PACKAGE_GROUPS[*]:-<none>}"
  update_index

  local has_desktop=0 g pkg
  for g in "${PACKAGE_GROUPS[@]}"; do
    [ "$g" = "desktop" ] && has_desktop=1
    # standard packages for this manager
    while IFS= read -r pkg; do
      install_one "$pkg"
    done < <(read_list "$PACKAGES_DIR/$g/$PKGMGR.txt")

    # AUR (Omarchy)
    if [ "$PKGMGR" = "pacman" ]; then
      while IFS= read -r pkg; do
        install_aur "$pkg"
      done < <(read_list "$PACKAGES_DIR/$g/aur.txt")
    fi

    # macOS casks
    if [ "$PKGMGR" = "brew" ]; then
      while IFS= read -r pkg; do
        install_cask "$pkg"
      done < <(read_list "$PACKAGES_DIR/$g/brew-cask.txt")
    fi
  done

  if [ "$has_desktop" = "1" ]; then
    install_desktop_shell_extras
  fi

  if [ "$ENFORCE" = "1" ]; then
    enforce_removals
  fi

  ok "Package step complete."
}

main
