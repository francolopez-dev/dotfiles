#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT_UNDER_TEST="$REPO_DIR/scripts/bootstrap.sh"
WORK_DIR="$SCRIPT_DIR/.tmp"

fail() {
  printf "FAIL %s\n" "$*" >&2
  exit 1
}

pass() {
  printf "PASS %s\n" "$*"
}

git_config() {
  git -C "$1" config user.name "Bootstrap Test"
  git -C "$1" config user.email "bootstrap-test@example.invalid"
}

commit_file() {
  local repo="$1" path="$2" content="$3" message="$4"
  mkdir -p "$(dirname "$repo/$path")"
  printf "%s\n" "$content" > "$repo/$path"
  git -C "$repo" add "$path"
  git -C "$repo" commit -m "$message" >/dev/null
}

setup_remote() {
  local name="$1" seed bare
  rm -rf "${WORK_DIR:?}/$name"
  mkdir -p "$WORK_DIR/$name"
  seed="$WORK_DIR/$name/seed"
  bare="$WORK_DIR/$name/origin.git"
  git init -b main "$seed" >/dev/null
  git_config "$seed"
  commit_file "$seed" "state.txt" "base" "base"
  git clone --bare "$seed" "$bare" >/dev/null 2>&1
  printf "%s\n" "$bare"
}

clone_local() {
  local bare="$1" target="$2"
  git clone "$bare" "$target" >/dev/null 2>&1
  git_config "$target"
}

remote_commit() {
  local bare="$1" work="$2" content="$3"
  rm -rf "$work"
  git clone "$bare" "$work" >/dev/null 2>&1
  git_config "$work"
  commit_file "$work" "state.txt" "$content" "remote $content"
  git -C "$work" push origin main >/dev/null 2>&1
}

run_bootstrap() {
  local local_repo="$1" remote="$2" mode="${3:-safe}" out="$4"
  REPO_DIR="$local_repo" \
  REPO_URL="$remote" \
  DOTFILES_UPDATE_MODE="$mode" \
  DOTFILES_BOOTSTRAP_SKIP_HANDOFF=1 \
  "$SCRIPT_UNDER_TEST" > "$out" 2>&1
}

run_bootstrap_reset_confirmed() {
  local local_repo="$1" remote="$2" out="$3"
  REPO_DIR="$local_repo" \
  REPO_URL="$remote" \
  DOTFILES_UPDATE_MODE=reset \
  DOTFILES_CONFIRM_RESET=1 \
  DOTFILES_BOOTSTRAP_SKIP_HANDOFF=1 \
  "$SCRIPT_UNDER_TEST" > "$out" 2>&1
}

test_clean_fast_forward() {
  local bare local_repo out
  bare="$(setup_remote clean-ff)"
  local_repo="$WORK_DIR/clean-ff/local"
  out="$WORK_DIR/clean-ff/out.txt"
  clone_local "$bare" "$local_repo"
  remote_commit "$bare" "$WORK_DIR/clean-ff/remote-work" "remote"

  run_bootstrap "$local_repo" "$bare" safe "$out"
  grep -q "Fast-forwarding main" "$out" || fail "safe mode did not fast-forward"
  grep -q "remote" "$local_repo/state.txt" || fail "local repo did not fast-forward"
  pass "safe-clean-fast-forward"
}

test_dirty_refusal() {
  local bare local_repo out
  bare="$(setup_remote dirty)"
  local_repo="$WORK_DIR/dirty/local"
  out="$WORK_DIR/dirty/out.txt"
  clone_local "$bare" "$local_repo"
  printf "dirty\n" > "$local_repo/dirty.txt"

  if run_bootstrap "$local_repo" "$bare" safe "$out"; then
    fail "safe mode allowed dirty working tree"
  fi
  grep -q "Working tree has local changes" "$out" || fail "dirty refusal missing reason"
  grep -q "dirty working tree: yes" "$out" || fail "dirty refusal missing state"
  pass "safe-dirty-refusal"
}

test_ahead_refusal() {
  local bare local_repo out
  bare="$(setup_remote ahead)"
  local_repo="$WORK_DIR/ahead/local"
  out="$WORK_DIR/ahead/out.txt"
  clone_local "$bare" "$local_repo"
  commit_file "$local_repo" "local.txt" "local" "local"

  if run_bootstrap "$local_repo" "$bare" safe "$out"; then
    fail "safe mode allowed ahead branch"
  fi
  grep -q "unpushed local commits" "$out" || fail "ahead refusal missing reason"
  grep -q "ahead of origin/main: 1" "$out" || fail "ahead refusal missing ahead count"
  pass "safe-ahead-refusal"
}

test_diverged_refusal() {
  local bare local_repo out
  bare="$(setup_remote diverged)"
  local_repo="$WORK_DIR/diverged/local"
  out="$WORK_DIR/diverged/out.txt"
  clone_local "$bare" "$local_repo"
  commit_file "$local_repo" "local.txt" "local" "local"
  remote_commit "$bare" "$WORK_DIR/diverged/remote-work" "remote"

  if run_bootstrap "$local_repo" "$bare" safe "$out"; then
    fail "safe mode allowed diverged branch"
  fi
  grep -q "diverged from origin/main" "$out" || fail "diverged refusal missing reason"
  grep -q "behind origin/main: 1" "$out" || fail "diverged refusal missing behind count"
  grep -q "ahead of origin/main: 1" "$out" || fail "diverged refusal missing ahead count"
  pass "safe-diverged-refusal"
}

test_stash_mode() {
  local bare local_repo out
  bare="$(setup_remote stash)"
  local_repo="$WORK_DIR/stash/local"
  out="$WORK_DIR/stash/out.txt"
  clone_local "$bare" "$local_repo"
  remote_commit "$bare" "$WORK_DIR/stash/remote-work" "remote"
  printf "dirty\n" > "$local_repo/dirty.txt"

  run_bootstrap "$local_repo" "$bare" stash "$out"
  grep -q "Stashing because update mode is 'stash'" "$out" || fail "stash mode did not stash"
  grep -q "remote" "$local_repo/state.txt" || fail "stash mode did not fast-forward"
  grep -q "dirty" "$local_repo/dirty.txt" || fail "stash mode did not restore dirty file"
  pass "stash-mode"
}

test_reset_requires_confirmation() {
  local bare local_repo out
  bare="$(setup_remote reset)"
  local_repo="$WORK_DIR/reset/local"
  out="$WORK_DIR/reset/out.txt"
  clone_local "$bare" "$local_repo"
  commit_file "$local_repo" "local.txt" "local" "local"
  printf "dirty\n" > "$local_repo/dirty.txt"

  if run_bootstrap "$local_repo" "$bare" reset "$out"; then
    fail "reset mode ran without confirmation"
  fi
  grep -q "requires DOTFILES_CONFIRM_RESET=1" "$out" || fail "reset refusal missing confirmation message"

  run_bootstrap_reset_confirmed "$local_repo" "$bare" "$WORK_DIR/reset/out-confirmed.txt"
  [ ! -e "$local_repo/local.txt" ] || fail "confirmed reset did not discard local commit"
  [ ! -e "$local_repo/dirty.txt" ] || fail "confirmed reset did not discard dirty file"
  pass "reset-requires-confirmation"
}

main() {
  test_clean_fast_forward
  test_dirty_refusal
  test_ahead_refusal
  test_diverged_refusal
  test_stash_mode
  test_reset_requires_confirmation
}

main
