# shellcheck shell=bash
# SSH sessions only: unknown $TERM (e.g. xterm-ghostty before its terminfo is
# installed) breaks full-screen apps; fall back before handing off to zsh,
# which inherits TERM. Inert in local desktop shells.
if [ -n "${SSH_CONNECTION:-}${SSH_TTY:-}" ] && [ -n "${TERM:-}" ] \
    && [ "$TERM" != dumb ] && [ "$TERM" != xterm-256color ]; then
  if ! command -v infocmp >/dev/null 2>&1 \
      || ! infocmp "$TERM" >/dev/null 2>&1; then
    export TERM=xterm-256color
  fi
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
# shellcheck disable=SC1091
[ -f "$HOME/.config/shell/env.sh" ] && . "$HOME/.config/shell/env.sh"
# shellcheck disable=SC1091
[ -f "$HOME/.config/shell/aliases.sh" ] && . "$HOME/.config/shell/aliases.sh"
# shellcheck disable=SC1091
[ -f "$HOME/.config/shell/tmux-layouts.sh" ] && . "$HOME/.config/shell/tmux-layouts.sh"

_dotfiles_source_first() {
  while [ "$#" -gt 0 ]; do
    if [ -r "$1" ]; then
      # shellcheck disable=SC1090
      . "$1"
      return 0
    fi
    shift
  done
  return 1
}

if command -v fzf >/dev/null 2>&1; then
  _dotfiles_source_first \
    "${HOMEBREW_PREFIX:-}/opt/fzf/shell/completion.bash" \
    /usr/share/fzf/completion.bash \
    /usr/share/fzf/shell/completion.bash \
    /usr/share/doc/fzf/examples/completion.bash >/dev/null 2>&1 || true
  _dotfiles_source_first \
    "${HOMEBREW_PREFIX:-}/opt/fzf/shell/key-bindings.bash" \
    /usr/share/fzf/key-bindings.bash \
    /usr/share/fzf/shell/key-bindings.bash \
    /usr/share/doc/fzf/examples/key-bindings.bash >/dev/null 2>&1 || true
fi

if command -v zoxide >/dev/null 2>&1; then
  if _dotfiles_zoxide_init="$(zoxide init bash --cmd cd 2>/dev/null)"; then
    eval "$_dotfiles_zoxide_init"
    alias z='cd'
  else
    eval "$(zoxide init bash)"
  fi
fi

command -v direnv >/dev/null 2>&1 && eval "$(direnv hook bash)"
unset _dotfiles_zoxide_init
unset -f _dotfiles_source_first 2>/dev/null || true
