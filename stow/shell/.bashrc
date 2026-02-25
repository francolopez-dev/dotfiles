# Dotfiles shell config
[ -f "$HOME/.config/shell/env.sh" ] && . "$HOME/.config/shell/env.sh"
[ -f "$HOME/.config/shell/aliases.sh" ] && . "$HOME/.config/shell/aliases.sh"
# Auto-start zsh for interactive shells
if [[ $- == *i* ]] && command -v zsh >/dev/null 2>&1; then
  exec zsh -l
fi
