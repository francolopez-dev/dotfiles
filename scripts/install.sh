#!/usr/bin/env bash
set -euo pipefail
# -e  : exit on error
# -u  : error on unset variables
# -o pipefail : fail if any command in a pipe fails

# ============================================================
# Dotfiles Installer
# - Installs CLI tools using the detected package manager
# - Optionally installs Oh My Zsh + plugins + Powerlevel10k
# - macOS: installs GUI apps via Homebrew casks (wezterm/aerospace/borders)
# - Raspberry Pi (apt): installs Cockpit and enables it
# - Applies configs via GNU Stow with safety backups
# ============================================================

# -----------------------------
# Configuration (overridable via env vars)
# -----------------------------
REPO_DIR="${REPO_DIR:-$HOME/dotfiles}"
STOW_DIR="${STOW_DIR:-$REPO_DIR/stow}"

# Optional: install oh-my-zsh + p10k
INSTALL_OHMYZSH="${INSTALL_OHMYZSH:-1}" # set to 0 to skip
INSTALL_P10K="${INSTALL_P10K:-1}"       # set to 0 to skip

# -----------------------------
# CLI tools to install everywhere
# (Keep this list mostly terminal/server-safe)
# -----------------------------
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

# -----------------------------
# Stow packages to apply everywhere
# (Desktop stow packages are appended below)
# -----------------------------
STOW_PACKAGES=(shell git ssh tmux)

# -----------------------------
# Desktop-only stow packages
# - macOS always gets these
# - Linux only gets wezterm when a desktop session is detected
# -----------------------------
if [[ "$(uname)" == "Darwin" ]]; then
  STOW_PACKAGES+=(wezterm aerospace borders)
else
  # Desktop session detection (X11 or Wayland)
  if [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" ]]; then
    STOW_PACKAGES+=(wezterm)
  fi
fi

# ============================================================
# Helpers
# ============================================================

log() { printf "%s\n" "$*"; }

need_cmd() { command -v "$1" >/dev/null 2>&1; }

# -----------------------------
# Detect package manager
# -----------------------------
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

# -----------------------------
# Map tool names across distros when needed
# (Currently minimal mapping; expand if you hit missing pkgs)
# -----------------------------
pkg_name() {
  local mgr="$1"
  local tool="$2"

  case "$mgr" in
  apt)
    case "$tool" in
    ca-certificates) echo "ca-certificates" ;;
    ripgrep) echo "ripgrep" ;;
    neovim) echo "neovim" ;;
    bat) echo "bat" ;; # On some distros it can be "batcat"; keep "bat" for modern Debian.
    *) echo "$tool" ;;
    esac
    ;;
  brew)
    # brew formulas mostly match their command names
    echo "$tool"
    ;;
  dnf | yum | pacman | apk)
    echo "$tool"
    ;;
  *)
    echo "$tool"
    ;;
  esac
}

# -----------------------------
# Update package index/cache
# -----------------------------
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

# -----------------------------
# Install one package (best-effort)
# -----------------------------
install_pkg() {
  local mgr="$1"
  local pkg="$2"
  [[ -z "$pkg" ]] && return 0

  case "$mgr" in
  brew)
    # CLI tools should be formulas, not casks
    if brew list --formula 2>/dev/null | grep -qx "$pkg"; then
      log "OK (already): $pkg"
      return 0
    fi
    log "Installing: $pkg"
    brew install "$pkg" || log "WARN: failed to install $pkg (skipping)"
    ;;
  apt)
    if dpkg -s "$pkg" >/dev/null 2>&1; then
      log "OK (already): $pkg"
      return 0
    fi
    log "Installing: $pkg"
    sudo apt-get install -y "$pkg" || log "WARN: failed to install $pkg (skipping)"
    ;;
  dnf)
    if rpm -q "$pkg" >/dev/null 2>&1; then
      log "OK (already): $pkg"
      return 0
    fi
    log "Installing: $pkg"
    sudo dnf -y install "$pkg" || log "WARN: failed to install $pkg (skipping)"
    ;;
  yum)
    if rpm -q "$pkg" >/dev/null 2>&1; then
      log "OK (already): $pkg"
      return 0
    fi
    log "Installing: $pkg"
    sudo yum -y install "$pkg" || log "WARN: failed to install $pkg (skipping)"
    ;;
  pacman)
    if pacman -Qi "$pkg" >/dev/null 2>&1; then
      log "OK (already): $pkg"
      return 0
    fi
    log "Installing: $pkg"
    sudo pacman -S --noconfirm --needed "$pkg" || log "WARN: failed to install $pkg (skipping)"
    ;;
  apk)
    if apk info -e "$pkg" >/dev/null 2>&1; then
      log "OK (already): $pkg"
      return 0
    fi
    log "Installing: $pkg"
    sudo apk add --no-cache "$pkg" || log "WARN: failed to install $pkg (skipping)"
    ;;
  *)
    log "WARN: no supported package manager, cannot install $pkg"
    ;;
  esac
}

# ============================================================
# macOS GUI apps (casks)
# ============================================================

# -----------------------------
# Install GUI apps on macOS via Homebrew casks
# - These are NOT part of TOOLS_WANTED because they aren't formulas
# - Stow only provides config, so we install apps here too
# -----------------------------
install_macos_casks() {
  [[ "$(uname)" != "Darwin" ]] && return 0
  need_cmd brew || {
    log "WARN: brew not found, skipping macOS casks"
    return 0
  }

  local casks=(wezterm aerospace borders)

  for c in "${casks[@]}"; do
    if brew list --cask 2>/dev/null | grep -qx "$c"; then
      log "OK (already): $c (cask)"
    else
      log "Installing (cask): $c"
      brew install --cask "$c" || log "WARN: failed to install cask $c (skipping)"
    fi
  done

  # If borders is installed, start/restart its launchd service so borders actually show up.
  if brew services list 2>/dev/null | grep -q '^borders '; then
    brew services restart borders || true
  else
    brew services start borders || true
  fi
}

# ============================================================
# Raspberry Pi: Cockpit dashboard
# ============================================================

# -----------------------------
# Detect Raspberry Pi (best-effort)
# -----------------------------
is_raspberry_pi() {
  grep -qi "raspberry pi" /proc/device-tree/model 2>/dev/null && return 0
  grep -qi "Raspberry Pi" /proc/cpuinfo 2>/dev/null && return 0
  return 1
}

# -----------------------------
# Install Cockpit only on Raspberry Pi (apt-based systems)
# - Enables cockpit.socket for web access on :9090
# -----------------------------
install_cockpit_if_rpi() {
  local mgr="$1"
  [[ "$mgr" != "apt" ]] && return 0
  is_raspberry_pi || return 0

  log "Raspberry Pi detected: installing Cockpit..."
  sudo apt-get update -y

  # Install cockpit + optional extras (best-effort)
  sudo apt-get install -y cockpit || log "WARN: cockpit install failed (skipping)"
  sudo apt-get install -y cockpit-storaged cockpit-pcp 2>/dev/null || true

  if command -v systemctl >/dev/null 2>&1; then
    sudo systemctl enable --now cockpit.socket || true
  fi

  log "Cockpit: https://<pi-ip>:9090"
}

# ============================================================
# Oh My Zsh + plugins + Powerlevel10k
# ============================================================

# -----------------------------
# Install oh-my-zsh into ~/.oh-my-zsh if missing
# -----------------------------
install_oh_my_zsh() {
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

# -----------------------------
# Install common zsh plugins into Oh My Zsh custom dir
# -----------------------------
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

# -----------------------------
# Install Powerlevel10k theme into Oh My Zsh themes dir
# -----------------------------
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

# ============================================================
# Default shell + Stow safety
# ============================================================

# -----------------------------
# Attempt to set zsh as the login shell
# - This may fail on some systems due to PAM restrictions (common on Debian/RPi)
# - Your .bashrc can still auto-launch zsh for interactive sessions as a fallback
# -----------------------------
set_default_shell_to_zsh() {
  if command -v chsh >/dev/null 2>&1 && command -v zsh >/dev/null 2>&1; then
    if [[ -t 0 && -t 1 ]]; then
      log "Setting zsh as default shell..."
      chsh -s "$(command -v zsh)" "$USER" ||
        log "WARN: Could not change default shell (PAM may block it). Using .bashrc auto-zsh instead."
    else
      log "Skipping chsh (non-interactive session)."
    fi
  fi
}

# -----------------------------
# Backup existing dotfiles that would conflict with stow
# - Stow cannot overwrite real files with symlinks unless you use --adopt
# - We prefer backing up into ~/.dotfiles-backup
# -----------------------------
backup_conflicting_dotfiles() {
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

# ============================================================
# Apply Stow packages
# ============================================================

# -----------------------------
# Symlink stow packages into $HOME
# -----------------------------
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

# ============================================================
# Main
# ============================================================

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

  # 1) Update package indexes
  log "Updating package index..."
  update_index "$mgr" || true

  # 2) Install CLI tools
  log "Installing tools..."
  for tool in "${TOOLS_WANTED[@]}"; do
    install_pkg "$mgr" "$(pkg_name "$mgr" "$tool")"
  done

  # 3) macOS: install GUI apps (casks) that match your stowed configs
  install_macos_casks

  # 4) Optional zsh extras
  if [[ "$INSTALL_OHMYZSH" == "1" ]]; then
    install_oh_my_zsh
    install_zsh_plugins
    if [[ "$INSTALL_P10K" == "1" ]]; then
      install_p10k
    fi
  fi

  # 5) Try to set zsh as default login shell (may fail on some systems)
  set_default_shell_to_zsh

  # 6) Raspberry Pi: cockpit dashboard
  install_cockpit_if_rpi "$mgr"

  # 7) Stow: backup conflicts, then apply symlinks
  log "Preparing for stow..."
  backup_conflicting_dotfiles

  log "Applying stow packages..."
  apply_stow

  log "Done."
  log "Tip: open a new terminal session, or run: exec zsh"
}

main "$@"
