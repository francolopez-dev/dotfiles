#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${REPO_DIR:-$HOME/dotfiles}"
STOW_DIR="${STOW_DIR:-$REPO_DIR/stow}"

# Change this list only. Add tools here once.
TOOLS_WANTED=(
  git
  stow
  tmux
  fzf
  ripgrep
  jq
  bat
  eza
  fastfetch
  btop
  htop
  neovim
  zsh
  curl
  wget
  ca-certificates
  nano
)

# Packages to stow (must exist as folders under $STOW_DIR)
STOW_PACKAGES=(shell git ssh tmux)

# Desktop-only packages
if [[ "$(uname)" == "Darwin" ]]; then
  STOW_PACKAGES+=(wezterm aerospace)
else
  # Linux desktop session detection (X11 or Wayland)
  if [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
    STOW_PACKAGES+=(wezterm)
  fi
fi

# Optional: install oh-my-zsh + p10k
INSTALL_OHMYZSH="${INSTALL_OHMYZSH:-1}" # set to 0 to skip
INSTALL_P10K="${INSTALL_P10K:-1}"       # set to 0 to skip

log() { printf "%s\n" "$*"; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

detect_pkg_mgr() {
  if need_cmd brew; then
    echo "brew"
    return
  fi
  if need_cmd apt-get; then
    echo "apt"
    return
  fi
  if need_cmd dnf; then
    echo "dnf"
    return
  fi
  if need_cmd yum; then
    echo "yum"
    return
  fi
  if need_cmd pacman; then
    echo "pacman"
    return
  fi
  if need_cmd apk; then
    echo "apk"
    return
  fi
  echo ""
}

pkg_name() {
  local mgr="$1"
  local tool="$2"

  case "$mgr" in
  apt)
    case "$tool" in
    ca-certificates) echo "ca-certificates" ;;
    ripgrep) echo "ripgrep" ;;
    neovim) echo "neovim" ;;
    *) echo "$tool" ;;
    esac
    ;;
  brew)
    case "$tool" in
    ca-certificates) echo "ca-certificates" ;;
    *) echo "$tool" ;;
    esac
    ;;
  dnf | yum | pacman | apk)
    echo "$tool"
    ;;
  *)
    echo "$tool"
    ;;
  esac
}

install_pkg() {
  local mgr="$1"
  local pkg="$2"
  [[ -z "$pkg" ]] && return 0

  case "$mgr" in
  brew)
    brew list --formula | grep -qx "$pkg" && {
      log "OK (already): $pkg"
      return 0
    }
    log "Installing: $pkg"
    brew install "$pkg" || log "WARN: failed to install $pkg (skipping)"
    ;;
  apt)
    dpkg -s "$pkg" >/dev/null 2>&1 && {
      log "OK (already): $pkg"
      return 0
    }
    log "Installing: $pkg"
    sudo apt-get install -y "$pkg" || log "WARN: failed to install $pkg (skipping)"
    ;;
  dnf)
    rpm -q "$pkg" >/dev/null 2>&1 && {
      log "OK (already): $pkg"
      return 0
    }
    log "Installing: $pkg"
    sudo dnf -y install "$pkg" || log "WARN: failed to install $pkg (skipping)"
    ;;
  yum)
    rpm -q "$pkg" >/dev/null 2>&1 && {
      log "OK (already): $pkg"
      return 0
    }
    log "Installing: $pkg"
    sudo yum -y install "$pkg" || log "WARN: failed to install $pkg (skipping)"
    ;;
  pacman)
    pacman -Qi "$pkg" >/dev/null 2>&1 && {
      log "OK (already): $pkg"
      return 0
    }
    log "Installing: $pkg"
    sudo pacman -S --noconfirm --needed "$pkg" || log "WARN: failed to install $pkg (skipping)"
    ;;
  apk)
    apk info -e "$pkg" >/dev/null 2>&1 && {
      log "OK (already): $pkg"
      return 0
    }
    log "Installing: $pkg"
    sudo apk add --no-cache "$pkg" || log "WARN: failed to install $pkg (skipping)"
    ;;
  *)
    log "WARN: no supported package manager, cannot install $pkg"
    ;;
  esac
}

update_index() {
  local mgr="$1"
  case "$mgr" in
  brew) brew update ;;
  apt) sudo apt-get update -y ;;
  dnf) sudo dnf -y makecache ;;
  yum) sudo yum -y makecache || sudo yum -y check-update || true ;;
  pacman) sudo pacman -Sy --noconfirm ;;
  apk) sudo apk update ;;
  *) true ;;
  esac
}

install_oh_my_zsh() {
  # Installs into ~/.oh-my-zsh if missing
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    log "OK (already): oh-my-zsh"
    return 0
  fi

  if ! need_cmd curl; then
    log "WARN: curl missing, cannot install oh-my-zsh"
    return 0
  fi

  log "Installing oh-my-zsh..."
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || true
}

install_zsh_plugins() {
  local custom_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  mkdir -p "$custom_dir/plugins"

  if [[ ! -d "$custom_dir/plugins/zsh-autosuggestions" ]]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions \
      "$custom_dir/plugins/zsh-autosuggestions" || true
  fi

  if [[ ! -d "$custom_dir/plugins/zsh-syntax-highlighting" ]]; then
    git clone https://github.com/zsh-users/zsh-syntax-highlighting \
      "$custom_dir/plugins/zsh-syntax-highlighting" || true
  fi
}

install_p10k() {
  local custom_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  mkdir -p "$custom_dir/themes"

  if [[ -d "$custom_dir/themes/powerlevel10k" ]]; then
    log "OK (already): powerlevel10k"
    return 0
  fi

  log "Installing powerlevel10k..."
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
    "$custom_dir/themes/powerlevel10k" || true
}

backup_conflicting_dotfiles() {
  # Stow fails if it needs to create ~/.bashrc or ~/.zshrc but those files already exist
  # as real files (not symlinks). On Debian/RPi, the OS creates these by default.
  local backup_dir="$HOME/.dotfiles-backup"
  mkdir -p "$backup_dir"

  local ts
  ts="$(date +%F-%H%M%S)"

  for f in .bashrc .zshrc; do
    if [[ -e "$HOME/$f" && ! -L "$HOME/$f" ]]; then
      log "Backing up existing ~/$f -> $backup_dir/${f}.${ts}"
      mv "$HOME/$f" "$backup_dir/${f}.${ts}"
    fi
  done
}

apply_stow() {
  if [[ ! -d "$STOW_DIR" ]]; then
    log "ERROR: stow directory not found: $STOW_DIR"
    exit 1
  fi

  cd "$REPO_DIR"

  for pkg in "${STOW_PACKAGES[@]}"; do
    if [[ ! -d "$STOW_DIR/$pkg" ]]; then
      log "WARN: missing stow package: $pkg (skipping)"
      continue
    fi
    log "Stowing: $pkg"
    stow -t "$HOME" "$pkg"
  done
}

main() {
  log "Repo: $REPO_DIR"
  log "Stow dir: $STOW_DIR"

  local mgr
  mgr="$(detect_pkg_mgr)"
  if [[ -z "$mgr" ]]; then
    log "ERROR: No supported package manager found (brew/apt/dnf/yum/pacman/apk)."
    exit 1
  fi

  log "Package manager: $mgr"
  log "Updating package index..."
  update_index "$mgr" || true

  log "Installing tools..."
  for tool in "${TOOLS_WANTED[@]}"; do
    install_pkg "$mgr" "$(pkg_name "$mgr" "$tool")"
  done

  if [[ "$INSTALL_OHMYZSH" == "1" ]]; then
    install_oh_my_zsh
    install_zsh_plugins
    if [[ "$INSTALL_P10K" == "1" ]]; then
      install_p10k
    fi
  fi

  log "Preparing for stow..."
  backup_conflicting_dotfiles

  log "Applying stow packages..."
  apply_stow

  log "Done."
  log "Tip: restart your terminal or run: source ~/.zshrc"
}

main "$@"
