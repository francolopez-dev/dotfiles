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
  alias ll='l'
  alias la='l --all'
  alias lt='eza --tree --level=2 --icons --git --group-directories-first --classify=auto'
else
  if ls --color=auto -d . >/dev/null 2>&1; then
    alias ll='l --all'
    alias la='l --all'
  else
    alias ll='l --all'
    alias la='l --all'
  fi
  alias lt='ls -lah'
fi

_dotfiles_box_table() {
  awk '
    function visible_length(value, plain) {
      plain = value
      gsub(/\033\[[0-9;?]*[[:alpha:]]/, "", plain)
      return length(plain)
    }

    function rest(start, value, i) {
      value = $start
      for (i = start + 1; i <= NF; i++) value = value " " $i
      return value
    }

    function set_cell(row, column, value) {
      cells[row, column] = value
      widths[column] = visible_length(value) > widths[column] ? visible_length(value) : widths[column]
    }

    function border(left, middle, right, line, i, j) {
      line = left
      for (i = 1; i <= columns; i++) {
        for (j = 0; j < widths[i] + 2; j++) line = line "─"
        line = line (i == columns ? right : middle)
      }
      print line
    }

    {
      rows++

      if (NR == 1) {
        date_heading = "Modified"
        if ($0 ~ /Date Created/) date_heading = "Created"
        if ($0 ~ /Date Accessed/) date_heading = "Accessed"
        if ($0 ~ /Date Changed/) date_heading = "Changed"

        set_cell(rows, 1, "Permissions")
        set_cell(rows, 2, "Size")
        set_cell(rows, 3, "User")
        set_cell(rows, 4, date_heading)
        set_cell(rows, 5, "Git")
        set_cell(rows, 6, "Name")
        next
      }

      set_cell(rows, 1, $1)
      set_cell(rows, 2, $2)
      set_cell(rows, 3, $3)
      set_cell(rows, 4, $4 " " $5)
      set_cell(rows, 5, $6)
      set_cell(rows, 6, rest(7))
    }

    END {
      if (rows == 0) exit
      columns = 6

      border("┌", "┬", "┐")
      for (i = 1; i <= rows; i++) {
        line = "│"
        for (j = 1; j <= columns; j++) {
          line = line " " cells[i, j] sprintf("%*s", widths[j] - visible_length(cells[i, j]), "") " │"
        }
        print line

        if (i == 1) border("├", "┼", "┤")
      }
      border("└", "┴", "┘")
    }
  '
}

l() {
  if [ "${1:-}" = "--raw" ]; then
    shift
    if command -v eza >/dev/null 2>&1; then
      command eza --long --header --icons --git --group-directories-first --time-style=relative --classify=auto --color=always "$@"
    elif ls --color=auto -d . >/dev/null 2>&1; then
      command ls -lh --color=always --group-directories-first "$@"
    else
      command ls -lh "$@"
    fi
    return
  fi

  if command -v eza >/dev/null 2>&1; then
    command eza --long --header --icons --git --group-directories-first --time-style=relative --classify=auto --color=always "$@" | _dotfiles_box_table
  elif ls --color=auto -d . >/dev/null 2>&1; then
    command ls -lh --color=always --group-directories-first "$@"
  else
    command ls -lh "$@"
  fi
}

#real clear
alias cls='clear && printf "\e[3J"'
