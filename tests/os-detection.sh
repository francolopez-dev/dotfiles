#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf 'fail: %s\n' "$*" >&2
  exit 1
}

detect_with_env() {
  (
    # shellcheck disable=SC1091
    . "$repo_dir/scripts/lib/common.sh"
    "$@"
  )
}

[[ "$(DOTFILES_OS=macos detect_with_env detect_os)" == "macos" ]] || fail 'DOTFILES_OS=macos was not accepted'
[[ "$(DOTFILES_OS=omarchy detect_with_env detect_os)" == "omarchy" ]] || fail 'DOTFILES_OS=omarchy changed behavior'
[[ "$(DOTFILES_BOOTSTRAP_OS=macos detect_with_env detect_os)" == "macos" ]] || fail 'DOTFILES_BOOTSTRAP_OS=macos was not accepted'
[[ "$(DOTFILES_PROFILE=profile-lamac-macos detect_with_env detect_os)" == "macos" ]] || fail 'profile-*-macos inference failed'

if [[ "$(uname -s)" == "Darwin" ]]; then
  [[ "$(unset DOTFILES_OS DOTFILES_BOOTSTRAP_OS DOTFILES_PROFILE; detect_with_env detect_os)" == "macos" ]] || fail 'Darwin was not detected as macos'
fi

printf 'ok os detection tests\n'
