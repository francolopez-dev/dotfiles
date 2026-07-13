#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

bash_syntax_scripts=(
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
  "$repo_dir/tests/legacy-ssh-migration.sh"
  "$repo_dir/tests/package-bootstrap.sh"
  "$repo_dir/.githooks/pre-commit"
)

shellcheck_scripts=(
  "$repo_dir/bootstrap.sh"
  "$repo_dir/scripts/bootstrap.sh"
  "$repo_dir/scripts/validate-bootstrap.sh"
  "$repo_dir/scripts/validate-profiles.sh"
)

run_step() {
  local label="$1"
  shift
  local output status
  output="$tmp_dir/${label//[^A-Za-z0-9]/_}.out"
  printf '==> %s\n' "$label"
  if "$@" >"$output" 2>&1; then
    printf 'ok\n'
    return 0
  fi
  status=$?
  sed 's/^/  /' "$output" >&2
  printf 'fail: %s failed\n' "$label" >&2
  return "$status"
}

staged_files() {
  git -C "$repo_dir" diff --cached --name-only --diff-filter=ACMRT
}

requires_bootstrap_fixture() {
  local path
  [[ "${DOTFILES_FULL_HOOK:-0}" == "1" ]] && return 0
  while IFS= read -r path; do
    case "$path" in
      bootstrap.sh|scripts/bootstrap.sh|scripts/dotfiles|scripts/lib/*|tests/bootstrap*|packages/*|profiles/*|stow/global/scripts/*)
        return 0
        ;;
    esac
  done < <(staged_files)
  return 1
}

bootstrap_clean_dry_run() {
  HOME="$tmp_dir/home" \
  DOTFILES_DIR="$tmp_dir/home/dotfiles" \
  DOTFILES_REPO_URL="file://$repo_dir" \
  DOTFILES_BOOTSTRAP_OS=omarchy \
  DOTFILES_BRANCH="$(git -C "$repo_dir" branch --show-current)" \
    bash "$repo_dir/scripts/bootstrap.sh" --dry-run
}

run_step "bash syntax" bash -n "${bash_syntax_scripts[@]}"
run_step "shellcheck" shellcheck -x "${shellcheck_scripts[@]}"
run_step "validate profiles" "$repo_dir/scripts/validate-profiles.sh"

printf '==> bootstrap fixture\n'
if requires_bootstrap_fixture; then
  run_step "bootstrap clean dry-run" bootstrap_clean_dry_run
  run_step "bootstrap first-run fixture" "$repo_dir/tests/bootstrap-first-run.sh"
  run_step "legacy ssh migration fixture" "$repo_dir/tests/legacy-ssh-migration.sh"
else
  printf 'skipped: no bootstrap/profile/package changes\n'
fi

printf 'ok bootstrap validation passed\n'
