#!/usr/bin/env bash
# Common helpers shared by the dotfiles CLI and bootstrap.
# Source this; do not execute directly.

# Repo root (this file lives in scripts/lib/).
DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export DOTFILES_DIR

# --- logging -------------------------------------------------------------
_c_reset=$'\033[0m'; _c_blue=$'\033[34m'; _c_green=$'\033[32m'
_c_yellow=$'\033[33m'; _c_red=$'\033[31m'; _c_dim=$'\033[2m'

info()  { printf '%s==>%s %s\n' "$_c_blue"   "$_c_reset" "$*"; }
ok()    { printf '%s ok%s %s\n' "$_c_green"  "$_c_reset" "$*"; }
warn()  { printf '%swarn%s %s\n' "$_c_yellow" "$_c_reset" "$*" >&2; }
err()   { printf '%serr%s %s\n'  "$_c_red"    "$_c_reset" "$*" >&2; }
dim()   { printf '%s%s%s\n' "$_c_dim" "$*" "$_c_reset"; }

# confirm "Question?" -> returns 0 on yes. Defaults to no.
confirm() {
  local q="$1" ans
  if have_tty; then
    printf '%s [y/N] ' "$q" >/dev/tty
    IFS= read -r ans </dev/tty || true
  else
    printf '%s [y/N] ' "$q"
    read -r ans || true
  fi
  [[ "$ans" == [yY] || "$ans" == [yY][eE][sS] ]]
}

have_tty() { [[ -r /dev/tty && -w /dev/tty ]]; }

prompt_tty() {
  local prompt="$1" ans
  have_tty || return 1
  printf '%s' "$prompt" >/dev/tty
  IFS= read -r ans </dev/tty || true
  printf '%s\n' "$ans"
}

# --- machine identity ----------------------------------------------------
detect_hostname() { hostname -s 2>/dev/null || uname -n | cut -d. -f1; }

active_profile() {
  local os="${1:-$(detect_os)}" host="${2:-$(detect_hostname)}"
  printf '%s\n' "${DOTFILES_PROFILE:-profile-${host}-${os}}"
}

# Echoes one of: omarchy | debian | ubuntu | unknown
detect_os() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    local id="${ID-}" id_like="${ID_LIKE-}"
    case "${id,,}:${id_like,,}" in
      arch:*|*:*arch*) echo "omarchy" ;;
      ubuntu:*)        echo "ubuntu"  ;;
      debian:*|*:*debian*) echo "debian" ;;
      *) echo "unknown" ;;
    esac
  else
    echo "unknown"
  fi
}

# --- layers --------------------------------------------------------------
# Echoes the ordered list of stow layer directory names that apply to this
# machine: global -> os-<os> -> profile-<hostname>-<os> (only if present).
resolve_layers() {
  local os="${1:-$(detect_os)}" host="${2:-$(detect_hostname)}"
  echo "global"
  [[ -d "$DOTFILES_DIR/stow/os-$os" ]] && echo "os-$os"
  local profile
  profile="$(active_profile "$os" "$host")"
  [[ -d "$DOTFILES_DIR/stow/$profile" ]] && echo "$profile"
  return 0
}

# Echoes ordered package list files for this machine (those that exist).
resolve_package_lists() {
  local os="${1:-$(detect_os)}" host="${2:-$(detect_hostname)}"
  local profile
  profile="$(active_profile "$os" "$host")"
  for name in "global" "os-$os" "$profile"; do
    local f="$DOTFILES_DIR/packages/${name}.list"
    [[ -f "$f" ]] && echo "$f"
  done
  return 0
}
