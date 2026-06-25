#!/usr/bin/env bash
# bootstrap.sh — curl-friendly first-run setup.
#   curl -fsSL <raw-url>/scripts/bootstrap.sh | bash
#
# Clones (or updates) the repo, checks out the working branch, applies the
# stow layers for this machine, and symlinks `dotfiles` onto PATH.
set -euo pipefail

REPO_URL="${DOTFILES_REPO_URL:-https://github.com/jfrancolopez/dotfiles.git}"
export DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
BRANCH="${DOTFILES_BRANCH:-main}"
BIN_DIR="$HOME/.local/bin"
DRY_RUN=0
ZSHRC_GUARD_MARKER="# dotfiles bootstrap zsh-newuser-install guard"

say() { printf '\033[34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[33mwarn\033[0m %s\n' "$*" >&2; }

repo_dirty() {
  [[ -n "$(git -C "$DOTFILES_DIR" status --porcelain 2>/dev/null || true)" ]]
}

show_repo_dirty_help() {
  warn "repo has local changes; skipping bootstrap pull to protect your work"
  git -C "$DOTFILES_DIR" status --short --branch || true
  printf '\nRun these diagnostics:\n'
  printf '  cd ~/dotfiles\n'
  printf '  git status --short --branch\n'
  printf '  git diff --name-only\n'
  printf '\nThen run:\n'
  printf '  ~/dotfiles/scripts/dotfiles update\n\n'
}

usage() {
  cat <<'EOF'
Usage: bootstrap.sh [--dry-run] [--profile profile-<host>-<os>]

Environment:
  DOTFILES_REPO_URL  Git repo URL (default: jfrancolopez/dotfiles)
  DOTFILES_DIR       Checkout path (default: ~/dotfiles)
  DOTFILES_BRANCH    Git branch (default: main)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --profile)
      [[ -n "${2:-}" ]] || { warn "--profile requires a value"; exit 2; }
      export DOTFILES_PROFILE="$2"
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *) warn "unknown option: $1"; usage; exit 2 ;;
  esac
done

detect_bootstrap_os() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    local id="${ID-}" id_like="${ID_LIKE-}"
    case "${id,,}:${id_like,,}" in
      arch:*|*:*arch*) echo "omarchy" ;;
      ubuntu:*) echo "ubuntu" ;;
      debian:*|*:*debian*) echo "debian" ;;
      *) echo "unknown" ;;
    esac
  else
    echo "unknown"
  fi
}

install_bootstrap_prereqs() {
  local prereqs=(git stow zsh curl bash ca-certificates) missing=() pkg

  case "$(detect_bootstrap_os)" in
    omarchy)
      command -v pacman >/dev/null 2>&1 || { warn "pacman is required to install bootstrap prerequisites"; return 1; }
      for pkg in "${prereqs[@]}"; do
        pacman -Qq "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
      done
      [[ ${#missing[@]} -eq 0 ]] && return 0
      say "Installing bootstrap prerequisites with pacman: ${missing[*]}"
      if [[ $DRY_RUN -eq 1 ]]; then
        warn "dry-run: would install pacman prerequisites: ${missing[*]}"
        return 0
      fi
      sudo pacman -S --needed "${missing[@]}"
      ;;
    debian|ubuntu)
      for pkg in git stow zsh curl bash ca-certificates; do
        dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
      done
      [[ ${#missing[@]} -eq 0 ]] && return 0
      say "Installing bootstrap prerequisites with apt: ${missing[*]}"
      if [[ $DRY_RUN -eq 1 ]]; then
        warn "dry-run: would install apt prerequisites: ${missing[*]}"
        return 0
      fi
      sudo apt-get update
      sudo apt-get install -y "${missing[@]}"
      ;;
    *)
      warn "cannot install prerequisites automatically on this OS: ${prereqs[*]}"
      [[ $DRY_RUN -eq 1 ]] && return 0
      return 1
      ;;
  esac
}

install_bootstrap_prereqs

install_zshrc_guard() {
  local zshrc="$HOME/.zshrc"
  if [[ -e "$zshrc" || -L "$zshrc" ]]; then
    return 0
  fi

  say "Installing temporary zsh first-run guard"
  if [[ $DRY_RUN -eq 1 ]]; then
    warn "dry-run: would create temporary $zshrc until managed zsh config is stowed"
    return 0
  fi

  printf '%s\n# Replaced by stowed dotfiles zsh config during bootstrap.\n' "$ZSHRC_GUARD_MARKER" >"$zshrc"
}

remove_zshrc_guard() {
  local zshrc="$HOME/.zshrc"
  if [[ ! -f "$zshrc" || -L "$zshrc" ]]; then
    return 0
  fi
  if sed -n '1p' "$zshrc" | grep -Fxq "$ZSHRC_GUARD_MARKER"; then
    say "Removing temporary zsh first-run guard"
    if [[ $DRY_RUN -eq 1 ]]; then
      warn "dry-run: would remove temporary $zshrc before stow"
    else
      rm -f "$zshrc"
    fi
  fi
}

install_zshrc_guard

install_oh_my_zsh() {
  local omz_dir="$HOME/.oh-my-zsh"
  if [[ -r "$omz_dir/oh-my-zsh.sh" ]]; then
    return 0
  fi

  say "Installing Oh My Zsh"
  if [[ $DRY_RUN -eq 1 ]]; then
    warn "dry-run: would clone Oh My Zsh to $omz_dir"
    return 0
  fi

  git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$omz_dir"
}

install_oh_my_zsh

install_oh_my_zsh_plugin() {
  local name="$1" url="$2" plugin_dir
  plugin_dir="$HOME/.oh-my-zsh/custom/plugins/$name"
  if [[ -d "$plugin_dir" ]]; then
    return 0
  fi

  say "Installing Oh My Zsh plugin: $name"
  if [[ $DRY_RUN -eq 1 ]]; then
    warn "dry-run: would clone $url to $plugin_dir"
    return 0
  fi

  git clone --depth=1 "$url" "$plugin_dir"
}

install_oh_my_zsh_plugin zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions.git
install_oh_my_zsh_plugin zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting.git

install_powerlevel10k() {
  local theme_dir="$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
  if [[ -d "$theme_dir" ]]; then
    return 0
  fi

  say "Installing Powerlevel10k"
  if [[ $DRY_RUN -eq 1 ]]; then
    warn "dry-run: would clone Powerlevel10k to $theme_dir"
    return 0
  fi

  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$theme_dir"
}

install_powerlevel10k

# 1. clone or update
if [[ -d "$DOTFILES_DIR/.git" ]]; then
  say "Updating existing repo at $DOTFILES_DIR"
  if [[ $DRY_RUN -eq 1 ]]; then
    git -C "$DOTFILES_DIR" fetch --dry-run || true
  else
    git -C "$DOTFILES_DIR" fetch --all --prune
  fi
else
  say "Cloning $REPO_URL -> $DOTFILES_DIR"
  if [[ $DRY_RUN -eq 1 ]]; then
    warn "dry-run: would clone $REPO_URL to $DOTFILES_DIR"
  else
    git clone "$REPO_URL" "$DOTFILES_DIR"
  fi
fi
if [[ -d "$DOTFILES_DIR/.git" ]]; then
  if [[ $DRY_RUN -eq 0 ]]; then
    if repo_dirty; then
      show_repo_dirty_help
    else
      if git -C "$DOTFILES_DIR" rev-parse --verify "$BRANCH" >/dev/null 2>&1; then
        git -C "$DOTFILES_DIR" checkout "$BRANCH"
      else
        git -C "$DOTFILES_DIR" checkout -b "$BRANCH" "origin/$BRANCH"
      fi
      git -C "$DOTFILES_DIR" pull --ff-only origin "$BRANCH"
    fi
  else
    say "Dry-run branch: $BRANCH"
  fi
fi

# 2. symlink the CLI onto PATH before stow so fallback exists if conflicts occur.
mkdir -p "$BIN_DIR"
if [[ $DRY_RUN -eq 1 ]]; then
  say "Would link dotfiles -> $BIN_DIR/dotfiles"
else
  ln -sf "$DOTFILES_DIR/scripts/dotfiles" "$BIN_DIR/dotfiles"
fi
say "Linked dotfiles -> $BIN_DIR/dotfiles"

# 3. Make dotfiles available to the current bootstrap shell immediately.
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) export PATH="$BIN_DIR:$PATH" ;;
esac

# 4. Stow managed shell config before the longer package/update phase so a new
# terminal cannot fall into zsh-newuser-install on fresh installs.
remove_zshrc_guard
say "Applying managed shell config"
if [[ $DRY_RUN -eq 1 ]]; then
  if [[ -x "$DOTFILES_DIR/scripts/dotfiles" ]]; then
    "$DOTFILES_DIR/scripts/dotfiles" apply --dry-run || warn "dry-run: managed shell config pre-apply reported conflicts; continuing"
  else
    warn "dry-run: repo checkout is not present, so stow cannot be simulated"
  fi
else
  "$DOTFILES_DIR/scripts/dotfiles" apply || warn "managed shell config pre-apply had conflicts; continuing to update"
fi

# 5. Install declared packages, then re-apply layers with conflict wizard.
say "Running dotfiles update"
if [[ $DRY_RUN -eq 1 ]]; then
  if [[ -x "$DOTFILES_DIR/scripts/dotfiles" ]]; then
    "$DOTFILES_DIR/scripts/dotfiles" update --dry-run
  else
    warn "dry-run: repo checkout is not present, so dotfiles update cannot be simulated"
    warn "dry-run: would run $DOTFILES_DIR/scripts/dotfiles update --dry-run after clone"
  fi
else
  "$DOTFILES_DIR/scripts/dotfiles" update
fi

bootstrap_summary() {
  local host host_upper
  host="$(hostname -s 2>/dev/null || uname -n | cut -d. -f1)"
  host_upper="$(printf '%s' "$host" | tr '[:lower:]' '[:upper:]')"
  printf '\nBootstrap complete for %s.\n\n' "$host_upper"
  printf 'Ready:\n'
  printf '  dotfiles command installed: %s\n' "$(command -v dotfiles 2>/dev/null || printf '%s' "$BIN_DIR/dotfiles")"
  printf '  managed shell config applied\n'
  printf '  packages checked and stow applied\n'
  printf '\nNeeds manual action:\n'
  printf '  Tailscale: run sudo tailscale up\n'
  printf '  GitHub SSH: run dotfiles git setup-ssh\n'
  printf '  Recovery pack: build the encrypted recovery pack when ready\n'
  printf '  Atuin: run atuin login && atuin sync\n'
  printf '\nRecommended:\n'
  printf '  open a new terminal or run exec zsh\n'
  printf '  run dotfiles status && dotfiles doctor\n'
}

bootstrap_summary
