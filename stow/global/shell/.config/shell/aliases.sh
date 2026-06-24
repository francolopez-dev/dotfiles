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
unalias l ll la L lt 2>/dev/null || true

if command -v eza >/dev/null 2>&1; then
  alias ll='l'
  alias la='l'
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

    function plain_text(value, plain) {
      plain = value
      gsub(/\033\[[0-9;?]*[[:alpha:]]/, "", plain)
      return plain
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

    function file_type(permissions, name, plain_permissions, plain_name, base) {
      plain_permissions = plain_text(permissions)
      plain_name = plain_text(name)
      sub(/^[[:space:]]+/, "", plain_name)
      sub(/[[:space:]]+$/, "", plain_name)
      sub(/^[^[:space:]]+[[:space:]]+/, "", plain_name)

      if (substr(plain_permissions, 1, 1) == "d") return "dir"
      if (substr(plain_permissions, 1, 1) == "l") return "link"
      if (plain_name ~ /\/$/) return "dir"
      if (plain_name ~ /\*$/) return "exe"

      base = plain_name
      sub(/[\/@*|=]$/, "", base)
      if (base ~ /\.[^.\/]+$/) {
        sub(/^.*\./, "", base)
        return base
      }

      return "file"
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

        set_cell(rows, 1, "#")
        set_cell(rows, 2, "Name")
        set_cell(rows, 3, "Type")
        set_cell(rows, 4, "Size")
        set_cell(rows, 5, date_heading)
        set_cell(rows, 6, "Git")
        set_cell(rows, 7, "User")
        set_cell(rows, 8, "Permissions")
        next
      }

      name = rest(7)
      set_cell(rows, 1, rows - 1)
      set_cell(rows, 2, name)
      set_cell(rows, 3, file_type($1, name))
      set_cell(rows, 4, $2)
      set_cell(rows, 5, $4 " " $5)
      set_cell(rows, 6, $6)
      set_cell(rows, 7, $3)
      set_cell(rows, 8, $1)
    }

    END {
      if (rows == 0) exit
      columns = 8

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
      command eza --long --all --header --icons --git --group-directories-first --time-style=relative --classify=auto --color=always "$@"
    elif ls --color=auto -d . >/dev/null 2>&1; then
      command ls -lh --color=always --group-directories-first "$@"
    else
      command ls -lh "$@"
    fi
    return
  fi

  if command -v eza >/dev/null 2>&1; then
    command eza --long --all --header --icons --git --group-directories-first --time-style=relative --classify=auto --color=always "$@" | _dotfiles_box_table
  elif ls --color=auto -d . >/dev/null 2>&1; then
    command ls -lh --color=always --group-directories-first "$@"
  else
    command ls -lh "$@"
  fi
}

#real clear
alias cls='clear && printf "\e[3J"'
