# Auto-start zsh for interactive shells (but avoid nested shells)
if [[ $- == *i* ]] && command -v zsh >/dev/null 2>&1 && [[ -z "${ZSH_VERSION:-}" ]]; then
  exec zsh -l
fi
# Dotfiles shell config
[ -f "$HOME/.config/shell/env.sh" ] && . "$HOME/.config/shell/env.sh"
[ -f "$HOME/.config/shell/aliases.sh" ] && . "$HOME/.config/shell/aliases.sh"
