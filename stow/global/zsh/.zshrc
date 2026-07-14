# A client terminal whose terminfo this host lacks (e.g. Ghostty's
# xterm-ghostty) breaks zle redraw and full-screen apps (nano ignores
# Ctrl-X). Fall back to a universally shipped entry when the terminfo is
# missing. Covers SSH, Tailscale SSH, and any other remote session. Local
# desktop shells are inert because their terminfo is installed locally; the
# != xterm-256color guard avoids a redundant export. See
# docs/server-minimal.md.
if [[ -n "$TERM" && "$TERM" != dumb && "$TERM" != xterm-256color ]]; then
  if ! command -v infocmp >/dev/null 2>&1 \
      || ! infocmp "$TERM" >/dev/null 2>&1; then
    export TERM=xterm-256color
  fi
fi

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi
typeset -g POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
#ZSH_THEME="powerlevel9k/powerlevel9k"
ZSH_THEME="powerlevel10k/powerlevel10k"
if [[ ! -d "$ZSH/custom/themes/powerlevel10k" && ! -d "$HOME/powerlevel10k" ]]; then
  ZSH_THEME="robbyrussell"
fi

# Which plugins would you like to load?
plugins=(git docker-compose python nmap)
# Optional plugins if available.
[[ -d "$ZSH/custom/plugins/zsh-autosuggestions" ]] && plugins+=(zsh-autosuggestions)
[[ -d "$ZSH/custom/plugins/zsh-syntax-highlighting" ]] && plugins+=(zsh-syntax-highlighting)
[[ -d "$ZSH/plugins/gcloud" ]] && plugins+=(gcloud)
[[ -d "$ZSH/plugins/vscode" ]] && plugins+=(vscode)

# Skip compaudit's insecure-directory check: on Macs where two accounts share
# one Homebrew, brew's completion dirs are owned by the other account and the
# ownership check can never pass for both users (it also breaks p10k instant
# prompt with startup spam). All admins on managed machines are trusted.
ZSH_DISABLE_COMPFIX=true

#makes my files usable even before you install oh-my-zsh
if [[ -r "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
else
  echo "oh-my-zsh not found at $ZSH (skipping)"
fi
#symlinks
[[ -f "$HOME/.config/shell/env.sh" ]] && source "$HOME/.config/shell/env.sh"
[[ -f "$HOME/.config/shell/aliases.sh" ]] && source "$HOME/.config/shell/aliases.sh"
[[ -f "$HOME/.config/shell/tmux-layouts.sh" ]] && source "$HOME/.config/shell/tmux-layouts.sh"

_dotfiles_source_first() {
  while [ "$#" -gt 0 ]; do
    if [ -r "$1" ]; then
      source "$1"
      return 0
    fi
    shift
  done
  return 1
}

if command -v fzf >/dev/null 2>&1; then
  _dotfiles_source_first \
    "${HOMEBREW_PREFIX:-}/opt/fzf/shell/completion.zsh" \
    /usr/share/fzf/completion.zsh \
    /usr/share/fzf/shell/completion.zsh \
    /usr/share/doc/fzf/examples/completion.zsh >/dev/null 2>&1 || true
  _dotfiles_source_first \
    "${HOMEBREW_PREFIX:-}/opt/fzf/shell/key-bindings.zsh" \
    /usr/share/fzf/key-bindings.zsh \
    /usr/share/fzf/shell/key-bindings.zsh \
    /usr/share/doc/fzf/examples/key-bindings.zsh >/dev/null 2>&1 || true
fi

if command -v zoxide >/dev/null 2>&1; then
  if _dotfiles_zoxide_init="$(zoxide init zsh --cmd cd 2>/dev/null)"; then
    eval "$_dotfiles_zoxide_init"
    alias z='cd'
  else
    eval "$(zoxide init zsh)"
  fi
fi

command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"
unset _dotfiles_zoxide_init
unfunction _dotfiles_source_first 2>/dev/null || true
# User configuration
# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# The following lines have been added by Docker Desktop to enable Docker CLI completions.
if [[ -d "$HOME/.docker/completions" ]]; then
  fpath=("$HOME/.docker/completions" $fpath)
  autoload -Uz compinit
  (( ${+_comps} )) || compinit
fi
# End of Docker CLI completions
#
### Pomodoro timer
if command -v timer >/dev/null 2>&1; then
  work() {
    timer "${1:-25m}" && {
      if command -v terminal-notifier >/dev/null 2>&1; then
        terminal-notifier -message 'Pomodoro' -title 'Work Timer is up! Take a Break 😊' -sound Crystal
      else
        echo "Work timer done"
      fi
    }
  }

  rest() {
    timer "${1:-5m}" && {
      if command -v terminal-notifier >/dev/null 2>&1; then
        terminal-notifier -message 'Pomodoro' -title 'Break is over! Get back to work 😬' -sound Crystal
      else
        echo "Break timer done"
      fi
    }
  }
else
  work() { echo "timer not installed"; }
  rest() { echo "timer not installed"; }
fi

# Machine-specific paths and credentials live in ~/.config/shell/env.local
# (sourced via env.sh near the top). Nothing machine-specific belongs here.
