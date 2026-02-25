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
plugins=(git zsh-autosuggestions zsh-syntax-highlighting docker-compose python nmap)
# Optional plugins if available
[[ -d "$ZSH/plugins/gcloud" ]] && plugins+=(gcloud)
[[ -d "$ZSH/plugins/vscode" ]] && plugins+=(vscode)

#makes my files usable even before you install oh-my-zsh
if [[ -r "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
else
  echo "oh-my-zsh not found at $ZSH (skipping)"
fi
#symlinks
[[ -f "$HOME/.config/shell/env.sh" ]] && source "$HOME/.config/shell/env.sh"
[[ -f "$HOME/.config/shell/aliases.sh" ]] && source "$HOME/.config/shell/aliases.sh"
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
