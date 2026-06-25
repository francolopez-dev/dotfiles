#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

scripts=(
  "$repo_dir/bootstrap.sh"
  "$repo_dir/scripts/bootstrap.sh"
  "$repo_dir/scripts/dotfiles"
  "$repo_dir/scripts/validate-bootstrap.sh"
  "$repo_dir/scripts/validate-profiles.sh"
  "$repo_dir/scripts/lib/autostart.sh"
  "$repo_dir/scripts/lib/common.sh"
  "$repo_dir/scripts/lib/packages.sh"
  "$repo_dir/scripts/lib/stow.sh"
  "$repo_dir/tests/bootstrap-first-run.sh"
  "$repo_dir/.githooks/pre-commit"
)

printf '==> bash syntax\n'
for script in "${scripts[@]}"; do
  bash -n "$script"
done

printf '==> shellcheck\n'
shellcheck -x "${scripts[@]}"

printf '==> bootstrap clean dry-run\n'
HOME="$tmp_dir/home" \
DOTFILES_DIR="$tmp_dir/home/dotfiles" \
DOTFILES_REPO_URL="file://$repo_dir" \
DOTFILES_BOOTSTRAP_OS=omarchy \
DOTFILES_BRANCH="$(git -C "$repo_dir" branch --show-current)" \
  bash "$repo_dir/scripts/bootstrap.sh" --dry-run

printf '==> bootstrap first-run fixture\n'
"$repo_dir/tests/bootstrap-first-run.sh"

printf 'ok bootstrap validation passed\n'
