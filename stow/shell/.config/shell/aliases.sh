alias ..='cd ..'
alias gs='git status'
alias gp='git pull'
alias dps='docker ps'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias ff='fastfetch 2>/dev/null || true'

# system apps
alias v='nvim'

#in case i use EZA
if command -v eza >/dev/null 2>&1; then
  alias ll='eza -lah'
else
  alias ll='ls -lah'
fi
