# ~/.zprofile - managed by dotfiles (stow/os-macos/zsh).
# Machine-specific PATH/init lines belong in ~/.config/shell/env.local
# (sourced by env.sh) - never edit this file locally.
if [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi
