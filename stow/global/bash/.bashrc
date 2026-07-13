# SSH sessions only: unknown $TERM (e.g. xterm-ghostty before its terminfo is
# installed) breaks full-screen apps; fall back before handing off to zsh,
# which inherits TERM. Inert in local desktop shells.
if [ -n "${SSH_CONNECTION:-}${SSH_TTY:-}" ] && [ -n "${TERM:-}" ] && [ "$TERM" != dumb ] \
    && command -v infocmp >/dev/null 2>&1 \
    && ! infocmp "$TERM" >/dev/null 2>&1; then
  export TERM=xterm-256color
fi
# Auto-start zsh for interactive shells (but avoid nested shells)
if [[ $- == *i* ]] && command -v zsh >/dev/null 2>&1 && [[ -z "${ZSH_VERSION:-}" ]]; then
  exec zsh -l
fi
# Bash-only fallback (zsh not installed). ignoreboth = ignoredups plus
# ignorespace, so a leading space keeps a command out of history; histappend
# plus `history -a` merges parallel SSH sessions instead of overwriting.
HISTSIZE=50000
HISTFILESIZE=100000
HISTCONTROL=ignoreboth
HISTTIMEFORMAT='%F %T '
shopt -s histappend 2>/dev/null
case "${PROMPT_COMMAND:-}" in
  *"history -a"*) ;;
  *) PROMPT_COMMAND="history -a${PROMPT_COMMAND:+; $PROMPT_COMMAND}" ;;
esac
# Dotfiles shell config
[ -f "$HOME/.config/shell/env.sh" ] && . "$HOME/.config/shell/env.sh"
[ -f "$HOME/.config/shell/aliases.sh" ] && . "$HOME/.config/shell/aliases.sh"
[ -f "$HOME/.config/shell/tmux-layouts.sh" ] && . "$HOME/.config/shell/tmux-layouts.sh"
