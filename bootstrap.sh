#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_DIR="${DOTFILES_DIR:-$repo_dir}"
exec "$repo_dir/scripts/bootstrap.sh" "$@"
