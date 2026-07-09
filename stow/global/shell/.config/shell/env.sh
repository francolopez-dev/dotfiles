# Shared shell environment
# Sourced by both ~/.zshrc and ~/.bashrc.
# Keep this machine-agnostic — anything machine-specific belongs in env.local.

# Homebrew is normally initialized from ~/.zprofile on macOS login shells, but
# interactive non-login shells (for example `exec zsh`) skip that file.
if [ "$(uname -s 2>/dev/null)" = "Darwin" ]; then
  _dotfiles_brew=
  if [ -x /opt/homebrew/bin/brew ]; then
    _dotfiles_brew=/opt/homebrew/bin/brew
  elif [ -x /usr/local/bin/brew ]; then
    _dotfiles_brew=/usr/local/bin/brew
  fi

  if [ -n "$_dotfiles_brew" ]; then
    _dotfiles_brew_env="$(cd "$HOME" && "$_dotfiles_brew" shellenv 2>/dev/null)" && eval "$_dotfiles_brew_env"
  fi
  unset _dotfiles_brew _dotfiles_brew_env
fi

# Add user script directories to PATH if present.
if [ -d "$HOME/.local/bin" ]; then
  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
  esac
fi

if [ -d "$HOME/bin" ]; then
  case ":$PATH:" in
    *":$HOME/bin:"*) ;;
    *) export PATH="$HOME/bin:$PATH" ;;
  esac
fi

# Sensible defaults
export EDITOR="${EDITOR:-nvim}"
export VISUAL="${VISUAL:-nvim}"

# Machine-specific overrides (gitignored, never committed).
# This is the env-equivalent of ~/.ssh/config.local.
[ -f "$HOME/.config/shell/env.local" ] && . "$HOME/.config/shell/env.local"
