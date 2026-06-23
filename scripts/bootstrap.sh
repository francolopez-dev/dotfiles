#!/usr/bin/env bash
# bootstrap.sh — curl-friendly first-run setup.
#   curl -fsSL <raw-url>/scripts/bootstrap.sh | bash
#
# Clones (or updates) the repo, checks out the working branch, applies the
# stow layers for this machine, and symlinks `dotfiles` onto PATH.
set -euo pipefail

REPO_URL="${DOTFILES_REPO_URL:-https://github.com/jfrancolopez/dotfiles.git}"
export DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"
BRANCH="${DOTFILES_BRANCH:-clean-layers}"
BIN_DIR="$HOME/.local/bin"

say() { printf '\033[34m==>\033[0m %s\n' "$*"; }

# 1. clone or update
if [[ -d "$DOTFILES_DIR/.git" ]]; then
  say "Updating existing repo at $DOTFILES_DIR"
  git -C "$DOTFILES_DIR" fetch --all --prune
else
  say "Cloning $REPO_URL -> $DOTFILES_DIR"
  git clone "$REPO_URL" "$DOTFILES_DIR"
fi
git -C "$DOTFILES_DIR" checkout "$BRANCH"
git -C "$DOTFILES_DIR" pull --ff-only origin "$BRANCH" || true

# 2. apply layers (plain stow, no wizard in phase 1)
say "Applying stow layers"
"$DOTFILES_DIR/scripts/dotfiles" apply

# 3. symlink the CLI onto PATH
mkdir -p "$BIN_DIR"
ln -sf "$DOTFILES_DIR/scripts/dotfiles" "$BIN_DIR/dotfiles"
say "Linked dotfiles -> $BIN_DIR/dotfiles"

# 4. ensure ~/.local/bin is on PATH via .zshrc
ZSHRC="$HOME/.zshrc"
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
if [[ -f "$ZSHRC" ]] && ! grep -qF "$PATH_LINE" "$ZSHRC"; then
  printf '\n# Added by dotfiles bootstrap\n%s\n' "$PATH_LINE" >> "$ZSHRC"
  say "Added ~/.local/bin to PATH in .zshrc (restart shell)"
fi

say "Done. Run: dotfiles status"
