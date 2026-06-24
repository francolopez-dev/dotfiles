alias ..='cd ..'
alias gs='git status'
alias gp='git pull'
alias dps='docker ps'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias ff='fastfetch 2>/dev/null || true'

# system apps
alias v='nvim'
alias y='yazi'

# Pretty directory listings. eza is the preferred path; ls fallbacks keep
# server shells usable before optional packages are installed.
if command -v eza >/dev/null 2>&1; then
  alias l='eza --long --header --icons --git --group-directories-first --time-style=relative --classify=auto'
  alias ll='eza --long --header --icons --git --group-directories-first --time-style=relative --classify=auto'
  alias la='eza --long --all --header --icons --git --group-directories-first --time-style=relative --classify=auto'
  alias lt='eza --tree --level=2 --icons --git --group-directories-first --classify=auto'
else
  if ls --color=auto -d . >/dev/null 2>&1; then
    alias l='ls -lh --color=auto --group-directories-first'
    alias ll='ls -lah --color=auto --group-directories-first'
    alias la='ls -lah --color=auto --group-directories-first'
  else
    alias l='ls -lh'
    alias ll='ls -lah'
    alias la='ls -lah'
  fi
  alias lt='ls -lah'
fi

_dotfiles_listing_separator() {
  local width="${COLUMNS:-100}"
  [ "$width" -gt 0 ] 2>/dev/null || width=100
  printf '%*s\n' "$width" '' | tr ' ' '-'
}

L() {
  if command -v eza >/dev/null 2>&1; then
    command eza --long --header --icons --git --group-directories-first --time-style=relative --classify=auto --color=always "$@" |
      while IFS= read -r line; do
        printf '%s\n' "$line"
        _dotfiles_listing_separator
      done
  elif ls --color=auto -d . >/dev/null 2>&1; then
    command ls -lh --color=always --group-directories-first "$@" |
      while IFS= read -r line; do
        printf '%s\n' "$line"
        _dotfiles_listing_separator
      done
  else
    command ls -lh "$@" |
      while IFS= read -r line; do
        printf '%s\n' "$line"
        _dotfiles_listing_separator
      done
  fi
}

#real clear
alias cls='clear && printf "\e[3J"'
