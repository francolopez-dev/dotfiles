#!/usr/bin/env bash
set -euo pipefail
# ============================================================
# tests/cli/run-tests.sh — focused dispatch tests for the unified
# `dotfiles` CLI (stow/scripts/bin/dotfiles).
#
# The dispatcher is always invoked with DOTFILES_DIR="$REPO_DIR" so the
# tests never depend on ~/dotfiles. Each case asserts exit code and/or an
# output substring.
# ============================================================

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_DIR="$(cd "$TEST_DIR/../.." && pwd)"
DOTFILES="$REPO_DIR/stow/scripts/bin/dotfiles"
WORK_DIR="$TEST_DIR/.tmp"

fail() {
  printf "FAIL %s\n" "$*" >&2
  exit 1
}

pass() {
  printf "PASS %s\n" "$*"
}

cleanup() {
  rm -rf "${WORK_DIR:?}"
}
trap cleanup EXIT

# Run the dispatcher against the real repo, capturing exit code + output.
# Usage: run_cli <out_var> <rc_var> <args...>
run_cli() {
  local out_var="$1" rc_var="$2"; shift 2
  local _out _rc=0
  _out="$(DOTFILES_DIR="$REPO_DIR" bash "$DOTFILES" "$@" 2>&1)" || _rc=$?
  printf -v "$out_var" "%s" "$_out"
  printf -v "$rc_var" "%s" "$_rc"
}

git_config() {
  git -C "$1" config user.name "CLI Test"
  git -C "$1" config user.email "cli-test@example.invalid"
}

test_help() {
  local out rc
  run_cli out rc help
  [ "$rc" = "0" ] || fail "help: expected exit 0, got $rc"
  printf "%s" "$out" | grep -q "Usage: dotfiles" || fail "help: missing usage banner"
  pass "help"
}

test_help_update() {
  local out rc
  run_cli out rc help update
  [ "$rc" = "0" ] || fail "help update: expected exit 0, got $rc"
  printf "%s" "$out" | grep -q "dotfiles update —" || fail "help update: missing topic header"
  pass "help-update"
}

test_version() {
  local out rc
  run_cli out rc version
  [ "$rc" = "0" ] || fail "version: expected exit 0, got $rc"
  printf "%s" "$out" | grep -Eq "^dotfiles [^ ]+ @ [^ ]+" || fail "version: bad format: $out"
  pass "version"
}

test_unknown_command() {
  local out rc
  run_cli out rc frobnicate
  [ "$rc" = "2" ] || fail "unknown command: expected exit 2, got $rc"
  printf "%s" "$out" | grep -q "Usage: dotfiles" || fail "unknown command: missing help banner"
  pass "unknown-command"
}

test_reset_guard() {
  local out rc
  run_cli out rc update --reset
  [ "$rc" != "0" ] || fail "update --reset: expected non-zero exit (guard)"
  run_cli out rc update --reset --confirm --dry-run
  [ "$rc" = "0" ] || fail "update --reset --confirm --dry-run: expected exit 0, got $rc"
  pass "reset-guard"
}

test_bootstrap_routing() {
  local out rc
  run_cli out rc bootstrap --dry-run --profile minimal
  [ "$rc" = "0" ] || fail "bootstrap routing: expected exit 0, got $rc"
  printf "%s" "$out" | grep -q "Personal Platform bootstrap" || fail "bootstrap routing: not routed to orchestrator"
  printf "%s" "$out" | grep -q "DRY-RUN" || fail "bootstrap routing: missing DRY-RUN"
  pass "bootstrap-routing"
}

# Build a tiny temp repo (git init + one commit + bootstrap.sh stub + a copy of
# the real scripts/lib.sh so _validate_repo passes), then run a dry-run update
# against it and prove the repo state is untouched.
test_no_mutation() {
  local tmp="$WORK_DIR/no-mutation/repo"
  rm -rf "$WORK_DIR/no-mutation"
  mkdir -p "$tmp/scripts"
  git init -b main "$tmp" >/dev/null
  git_config "$tmp"
  printf '#!/usr/bin/env bash\necho stub\n' > "$tmp/bootstrap.sh"
  chmod +x "$tmp/bootstrap.sh"
  cp "$REPO_DIR/scripts/lib.sh" "$tmp/scripts/lib.sh"
  git -C "$tmp" add -A
  git -C "$tmp" commit -m "seed" >/dev/null

  local before_head before_status rc=0 out
  before_head="$(git -C "$tmp" rev-parse HEAD)"
  before_status="$(git -C "$tmp" status --porcelain)"

  out="$(DOTFILES_DIR="$tmp" bash "$DOTFILES" update --no-apply --dry-run 2>&1)" || rc=$?
  [ "$rc" = "0" ] || fail "no-mutation: expected exit 0, got $rc ($out)"

  [ "$(git -C "$tmp" rev-parse HEAD)" = "$before_head" ] || fail "no-mutation: HEAD changed"
  [ "$(git -C "$tmp" status --porcelain)" = "$before_status" ] || fail "no-mutation: working tree changed"
  pass "no-mutation"
}

# Invoke the dispatcher through a symlink with DOTFILES_DIR unset; it must still
# resolve back to the real REPO_DIR.
test_symlink_resolution() {
  local link_dir="$WORK_DIR/symlink"
  rm -rf "$link_dir"
  mkdir -p "$link_dir"
  ln -s "$DOTFILES" "$link_dir/dotfiles"

  local out rc=0
  out="$(env -u DOTFILES_DIR bash "$link_dir/dotfiles" version 2>&1)" || rc=$?
  [ "$rc" = "0" ] || fail "symlink resolution: expected exit 0, got $rc ($out)"
  printf "%s" "$out" | grep -qF "$REPO_DIR" || fail "symlink resolution: did not report real repo ($out)"
  pass "symlink-resolution"
}

main() {
  mkdir -p "$WORK_DIR"
  test_help
  test_help_update
  test_version
  test_unknown_command
  test_reset_guard
  test_bootstrap_routing
  test_no_mutation
  test_symlink_resolution
}

main
