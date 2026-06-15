# Shared shell environment
# Sourced by both ~/.zshrc and ~/.bashrc.
# Keep this machine-agnostic — anything machine-specific belongs in env.local.

# Add ~/bin (stowed scripts) to PATH if present
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
