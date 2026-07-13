# shellcheck shell=sh
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

# Prefer fd/fdfind for fzf file discovery when available. Debian/Ubuntu ship
# fd as fdfind; macOS and Arch ship it as fd.
_dotfiles_fd=
if command -v fd >/dev/null 2>&1; then
  _dotfiles_fd=fd
elif command -v fdfind >/dev/null 2>&1; then
  _dotfiles_fd=fdfind
fi

if [ -n "$_dotfiles_fd" ]; then
  export FZF_DEFAULT_COMMAND="${FZF_DEFAULT_COMMAND:-$_dotfiles_fd --hidden --follow --exclude .git}"
  export FZF_CTRL_T_COMMAND="${FZF_CTRL_T_COMMAND:-$FZF_DEFAULT_COMMAND}"
  export FZF_ALT_C_COMMAND="${FZF_ALT_C_COMMAND:-$_dotfiles_fd --type d --hidden --follow --exclude .git}"
fi
export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:---height 40% --layout=reverse --border --info=inline}"
unset _dotfiles_fd

# Delta is a friendlier pager for git diffs. Set it only when installed so git
# remains usable during first bootstrap or on older package repositories.
command -v delta >/dev/null 2>&1 && export GIT_PAGER="${GIT_PAGER:-delta}"

# Colorized man pages through bat/batcat. Plain man remains the fallback.
if command -v bat >/dev/null 2>&1; then
  export MANPAGER="${MANPAGER:-sh -c 'col -bx | bat -l man -p'}"
elif command -v batcat >/dev/null 2>&1; then
  export MANPAGER="${MANPAGER:-sh -c 'col -bx | batcat -l man -p'}"
fi

# Machine-specific overrides (gitignored, never committed).
# This is the env-equivalent of ~/.ssh/config.local.
# shellcheck disable=SC1091
[ -f "$HOME/.config/shell/env.local" ] && . "$HOME/.config/shell/env.local"
