# shellcheck shell=bash

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
  alias la='l'
  alias lt='eza --tree --level=2 --icons --git --group-directories-first --classify=auto'
else
  alias la='ll'
  alias lt='ls -lah'
fi

_dotfiles_box_table() {
  awk -v table_mode="${1:-full}" '
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

    function is_relative_time_unit(value) {
      value = plain_text(value)
      return value ~ /^(second|seconds|minute|minutes|hour|hours|day|days|week|weeks|month|months|year|years)$/
    }

    function compact_relative_time(number, unit, plain_unit, label, colored_unit, value) {
      plain_unit = tolower(plain_text(unit))

      if (plain_unit ~ /^second/) label = "sec"
      else if (plain_unit ~ /^minute/) label = "min"
      else if (plain_unit ~ /^hour/) label = "hr"
      else if (plain_unit ~ /^day/) label = "d"
      else if (plain_unit ~ /^week/) label = "wk"
      else if (plain_unit ~ /^month/) label = "mo"
      else if (plain_unit ~ /^year/) label = "yr"
      else label = plain_unit

      colored_unit = unit
      gsub(plain_unit, label, colored_unit)
      value = number " " colored_unit

      if (value ~ /\033\[/ && value !~ /\033\[0m/) value = value "\033[0m"
      return value
    }

    function is_git_status(value) {
      value = plain_text(value)
      return value ~ /^[-!?ACDIMNRTU]+$/
    }

    function compact_file_type(value) {
      value = tolower(value)

      if (value ~ /^(dir|directory)$/) return "dir"
      if (value ~ /^(link|symlink)$/) return "link"
      if (value ~ /^(exe|exec|app)$/) return "exec"
      if (value ~ /^(sh|bash|zsh|fish|ksh|csh|bashrc|zshrc|profile|zprofile|bash_profile|bash_logout)$/) return "sh"
      if (value ~ /^(md|markdown|mdown|mkd)$/) return "md"
      if (value ~ /^(conf|config|cfg|cnf|ini|toml|yaml|yml|json|env|gitconfig|gitignore|editorconfig|npmrc|curlrc|wgetrc)$/) return "conf"
      if (value ~ /^(jpg|jpeg|png|gif|webp|svg|heic|bmp|tif|tiff|ico|avif)$/) return "img"
      if (value ~ /^(zip|tar|gz|tgz|xz|bz2|7z|rar|zst|lz|lzma|dmg|iso)$/) return "arch"
      if (value ~ /^(xcompose)$/) return "xcmp"

      if (length(value) > 4) return substr(value, 1, 4)
      return value == "" ? "file" : value
    }

    function file_type(permissions, name, plain_permissions, plain_name, base, value) {
      plain_permissions = plain_text(permissions)
      plain_name = plain_text(name)
      sub(/^[[:space:]]+/, "", plain_name)
      sub(/[[:space:]]+$/, "", plain_name)
      sub(/^[^[:space:]]+[[:space:]]+/, "", plain_name)

      if (substr(plain_permissions, 1, 1) == "d") value = "dir"
      else if (substr(plain_permissions, 1, 1) == "l") value = "link"
      else if (plain_name ~ /\/$/) value = "dir"
      else if (plain_name ~ /\*$/) value = "exe"
      else value = "file"

      base = plain_name
      sub(/[\/@*|=]$/, "", base)
      if (value == "file" && base ~ /\.[^.\/]+$/) {
        sub(/^.*\./, "", base)
        value = base
      }

      return compact_file_type(value)
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
        date_heading = "Mod"
        has_git = plain_text($0) ~ /(^|[[:space:]])Git([[:space:]]|$)/

        set_cell(rows, 1, "#")
        set_cell(rows, 2, "Name")
        set_cell(rows, 3, "Type")
        set_cell(rows, 4, "Size")
        set_cell(rows, 5, date_heading)
        if (table_mode != "compact") {
          set_cell(rows, 6, "Git")
          set_cell(rows, 7, "User")
          set_cell(rows, 8, "Permissions")
        }
        next
      }

      if (has_git) {
        if (is_git_status($6)) {
          modified = compact_relative_time($4, $5)
          git = $6
          name = rest(7)
        } else {
          modified = $4
          git = $5
          name = rest(6)
        }
      } else {
        git = ""
        if (is_relative_time_unit($5)) {
          modified = compact_relative_time($4, $5)
          name = rest(6)
        } else {
          modified = $4
          name = rest(5)
        }
      }

      set_cell(rows, 1, rows - 1)
      set_cell(rows, 2, name)
      set_cell(rows, 3, file_type($1, name))
      set_cell(rows, 4, $2)
      set_cell(rows, 5, modified)
      if (table_mode != "compact") {
        set_cell(rows, 6, git)
        set_cell(rows, 7, $3)
        set_cell(rows, 8, $1)
      }
    }

    END {
      if (rows == 0) exit
      columns = table_mode == "compact" ? 5 : 8

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

_dotfiles_list_raw() {
  if command -v eza >/dev/null 2>&1; then
    command eza --long --all --header --icons --git --group-directories-first --time-style=relative --classify=auto --color=always "$@"
  elif ls --color=auto -d . >/dev/null 2>&1; then
    command ls -lh --color=always --group-directories-first "$@"
  else
    command ls -lh "$@"
  fi
}

_dotfiles_list_raw_all() {
  if command -v eza >/dev/null 2>&1; then
    command eza --long --all --header --icons --git --group-directories-first --time-style=relative --classify=auto --color=always "$@"
  elif ls --color=auto -d . >/dev/null 2>&1; then
    command ls -lha --color=always --group-directories-first "$@"
  else
    command ls -lha "$@"
  fi
}

l() {
  if [ "${1:-}" = "--raw" ]; then
    shift
    _dotfiles_list_raw "$@"
    return
  fi

  if command -v eza >/dev/null 2>&1; then
    command eza --long --all --header --icons --git --group-directories-first --time-style=relative --classify=auto --color=always "$@" | _dotfiles_box_table compact
  elif ls --color=auto -d . >/dev/null 2>&1; then
    command ls -lh --color=always --group-directories-first "$@"
  else
    command ls -lh "$@"
  fi
}

ll() {
  if [ "${1:-}" = "--raw" ]; then
    shift
    _dotfiles_list_raw_all "$@"
    return
  fi

  if command -v eza >/dev/null 2>&1; then
    command eza --long --all --header --icons --git --group-directories-first --time-style=relative --classify=auto --color=always "$@" | _dotfiles_box_table full
  elif ls --color=auto -d . >/dev/null 2>&1; then
    command ls -lha --color=always --group-directories-first "$@"
  else
    command ls -lha "$@"
  fi
}

#real clear
alias cls='clear && printf "\e[3J"'
