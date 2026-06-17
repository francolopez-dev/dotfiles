#!/usr/bin/env bash
# Shared helpers for the dotfiles platform scripts.
# Source this; do not execute it directly.
#
#   . "$(dirname "$0")/lib.sh"
#
# Honors:
#   DRY_RUN=1   -> run() prints commands instead of executing them
#   NO_COLOR=1  -> disable ANSI colors

# Guard against double-sourcing.
[ -n "${__DOTFILES_LIB_SOURCED:-}" ] && return 0
__DOTFILES_LIB_SOURCED=1

# Repo root = parent of the dir containing this file.
DOTFILES_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_DIR="${REPO_DIR:-$(cd "$DOTFILES_LIB_DIR/.." && pwd)}"
export REPO_DIR

DRY_RUN="${DRY_RUN:-0}"

# -----------------------------
# Colors
# -----------------------------
if [ -z "${NO_COLOR:-}" ] && [ -t 1 ]; then
  C_RESET="\033[0m"; C_DIM="\033[2m"; C_RED="\033[31m"
  C_GREEN="\033[32m"; C_YELLOW="\033[33m"; C_BLUE="\033[34m"
else
  C_RESET=""; C_DIM=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""
fi

# -----------------------------
# Logging
# -----------------------------
log()  { printf "%b\n" "$*"; }
info() { printf "%b\n" "${C_BLUE}::${C_RESET} $*"; }
ok()   { printf "%b\n" "${C_GREEN}ok${C_RESET} $*"; }
warn() { printf "%b\n" "${C_YELLOW}WARN${C_RESET} $*" >&2; }
err()  { printf "%b\n" "${C_RED}ERROR${C_RESET} $*" >&2; }
die()  { err "$*"; exit 1; }
dim()  { printf "%b\n" "${C_DIM}$*${C_RESET}"; }

# -----------------------------
# Command helpers
# -----------------------------
need_cmd() { command -v "$1" >/dev/null 2>&1; }

# run CMD...  — respects DRY_RUN (prints instead of executing).
run() {
  if [ "$DRY_RUN" = "1" ]; then
    printf "%b\n" "${C_DIM}[dry-run]${C_RESET} $*"
    return 0
  fi
  "$@"
}

# confirm "question"  — returns 0 on yes. Auto-no in non-interactive shells.
confirm() {
  local prompt="${1:-Are you sure?} [y/N] " reply
  if ! is_interactive; then
    warn "non-interactive; assuming 'no' for: $prompt"
    return 1
  fi
  printf "%b" "$prompt" > /dev/tty
  read -r reply < /dev/tty
  case "$reply" in
    [yY] | [yY][eE][sS]) return 0 ;;
    *) return 1 ;;
  esac
}

is_interactive() {
  [ -e /dev/tty ] && { : < /dev/tty; } 2>/dev/null && { : > /dev/tty; } 2>/dev/null
}

# Read a package/profile list file: strip comments and blank lines.
# Usage: read_list FILE  -> prints one entry per line.
read_list() {
  local f="$1"
  [ -f "$f" ] || return 0
  sed -e 's/#.*$//' -e 's/[[:space:]]*$//' -e 's/^[[:space:]]*//' "$f" | grep -v '^$' || true
}

# Read a simple whitespace-delimited map file after stripping comments.
# Usage: read_map FILE -> prints "key value" lines.
read_map() {
  local f="$1"
  [ -f "$f" ] || return 0
  read_list "$f" | awk 'NF >= 2 { print $1, $2 }'
}
