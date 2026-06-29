# shellcheck shell=sh
# Shared tmux layouts for editor + AI-agent terminal workflows.
# Sourced by both zsh and bash; keep this file POSIX-shell friendly.

_dotfiles_ai_agent_command() {
  case "${1:-}" in
    c|oc|opencode) printf '%s\n' "opencode" ;;
    cx|claude) printf '%s\n' "claude" ;;
    codex) printf '%s\n' "codex" ;;
    *) printf '%s\n' "${1:-}" ;;
  esac
}

_dotfiles_ai_agent_resolve() {
  if [ -z "${1:-}" ]; then
    printf '%s\n' "tdl: missing agent" >&2
    return 1
  fi

  agent_command=$(_dotfiles_ai_agent_command "$1")
  if ! command -v "$agent_command" >/dev/null 2>&1; then
    printf '%s\n' "tdl: agent '$1' maps to missing command '$agent_command'" >&2
    return 1
  fi

  printf '%s\n' "$agent_command"
}

_dotfiles_tmux_require() {
  if ! command -v tmux >/dev/null 2>&1; then
    printf '%s\n' "tmux layout: tmux is not installed" >&2
    return 1
  fi
}

_dotfiles_tmux_session_name() {
  layout_prefix=$1
  layout_dir=$2
  layout_base=$(basename "$layout_dir" | tr -c '[:alnum:]_.-' '_')
  layout_hash=$(printf '%s' "$layout_dir" | cksum | while read -r sum _rest; do printf '%s' "$sum"; done)

  [ -n "$layout_base" ] || layout_base="home"
  printf '%s\n' "${layout_prefix}-${layout_base}-${layout_hash}"
}

_dotfiles_tmux_open() {
  target_session=$1

  if [ -n "${TMUX:-}" ]; then
    tmux switch-client -t "$target_session"
  else
    tmux attach-session -t "$target_session"
  fi
}

_dotfiles_tdl_create_window() {
  target_session=$1
  target_window=$2
  target_dir=$3
  first_agent=$4
  second_agent=${5:-}
  editor_command="${EDITOR:-nvim} ."
  shell_command="${SHELL:-/bin/sh}"

  if tmux has-session -t "$target_session" 2>/dev/null; then
    editor_pane=$(tmux new-window -d -P -F '#{pane_id}' -t "$target_session:" -n "$target_window" -c "$target_dir" "$editor_command") || return 1
  else
    editor_pane=$(tmux new-session -d -P -F '#{pane_id}' -s "$target_session" -n "$target_window" -c "$target_dir" "$editor_command") || return 1
  fi

  tmux split-window -v -p 25 -t "$editor_pane" -c "$target_dir" "$shell_command" >/dev/null || return 1
  agent_pane=$(tmux split-window -h -p 40 -P -F '#{pane_id}' -t "$editor_pane" -c "$target_dir" "$first_agent") || return 1

  if [ -n "$second_agent" ]; then
    tmux split-window -v -p 50 -t "$agent_pane" -c "$target_dir" "$second_agent" >/dev/null || return 1
  fi

  tmux select-pane -t "$editor_pane" >/dev/null
}

tdl() {
  _dotfiles_tmux_require || return 1

  tdl_dir=$(pwd -P)
  tdl_session=$(_dotfiles_tmux_session_name "tdl" "$tdl_dir")
  tdl_agent_1=${1:-c}
  tdl_agent_2=${2:-}

  if [ -n "${3:-}" ]; then
    printf '%s\n' "tdl: expected at most two agents" >&2
    return 1
  fi

  tdl_command_1=$(_dotfiles_ai_agent_resolve "$tdl_agent_1") || return 1
  if [ -n "$tdl_agent_2" ]; then
    tdl_command_2=$(_dotfiles_ai_agent_resolve "$tdl_agent_2") || return 1
  else
    tdl_command_2=""
  fi

  if ! tmux has-session -t "$tdl_session" 2>/dev/null; then
    _dotfiles_tdl_create_window "$tdl_session" "main" "$tdl_dir" "$tdl_command_1" "$tdl_command_2" || return 1
  fi

  _dotfiles_tmux_open "$tdl_session"
}

tdlm() {
  _dotfiles_tmux_require || return 1

  tdlm_dir=$(pwd -P)
  tdlm_session=$(_dotfiles_tmux_session_name "tdlm" "$tdlm_dir")
  tdlm_agent=${1:-c}
  tdlm_command=$(_dotfiles_ai_agent_resolve "$tdlm_agent") || return 1

  if [ -n "${2:-}" ]; then
    printf '%s\n' "tdlm: expected one optional agent" >&2
    return 1
  fi

  if tmux has-session -t "$tdlm_session" 2>/dev/null; then
    _dotfiles_tmux_open "$tdlm_session"
    return
  fi

  tdlm_count=$(find "$tdlm_dir" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
  if [ "$tdlm_count" -eq 0 ]; then
    printf '%s\n' "tdlm: no immediate subdirectories found" >&2
    return 1
  fi

  if [ "$tdlm_count" -gt 8 ]; then
    printf 'tdlm: create layouts for %s directories? [y/N] ' "$tdlm_count" >/dev/tty 2>/dev/null || true
    IFS= read -r tdlm_answer </dev/tty || return 1
    case "$tdlm_answer" in
      y|Y|yes|YES) ;;
      *) printf '%s\n' "tdlm: cancelled" >&2; return 1 ;;
    esac
  fi

  find "$tdlm_dir" -mindepth 1 -maxdepth 1 -type d | sort | while IFS= read -r child_dir; do
    child_name=$(basename "$child_dir" | tr -c '[:alnum:]_.-' '_')
    _dotfiles_tdl_create_window "$tdlm_session" "$child_name" "$child_dir" "$tdlm_command" || exit 1
  done || return 1

  _dotfiles_tmux_open "$tdlm_session"
}

tsl() {
  _dotfiles_tmux_require || return 1

  tsl_panes=${1:-}
  if ! printf '%s' "$tsl_panes" | grep -Eq '^[0-9]+$'; then
    printf '%s\n' "tsl: usage: tsl <2-8 panes> <agent-or-command> [args...]" >&2
    return 1
  fi

  if [ "$tsl_panes" -lt 2 ] || [ "$tsl_panes" -gt 8 ]; then
    printf '%s\n' "tsl: pane count must be between 2 and 8" >&2
    return 1
  fi

  shift
  if [ -z "${1:-}" ]; then
    printf '%s\n' "tsl: missing agent or command" >&2
    return 1
  fi

  tsl_command=$(_dotfiles_ai_agent_resolve "$1") || return 1
  shift
  if [ "$#" -gt 0 ]; then
    tsl_command="$tsl_command $*"
  fi

  tsl_dir=$(pwd -P)
  tsl_session=$(_dotfiles_tmux_session_name "tsl" "$tsl_dir")

  if ! tmux has-session -t "$tsl_session" 2>/dev/null; then
    tmux new-session -d -s "$tsl_session" -n "swarm" -c "$tsl_dir" "$tsl_command" || return 1
    tsl_index=2
    while [ "$tsl_index" -le "$tsl_panes" ]; do
      tmux split-window -t "$tsl_session:swarm" -c "$tsl_dir" "$tsl_command" >/dev/null || return 1
      tmux select-layout -t "$tsl_session:swarm" tiled >/dev/null || return 1
      tsl_index=$((tsl_index + 1))
    done
  fi

  _dotfiles_tmux_open "$tsl_session"
}

alias ic='tdl c'
alias icx='tdl c cx'
alias icl='tdl cx'
