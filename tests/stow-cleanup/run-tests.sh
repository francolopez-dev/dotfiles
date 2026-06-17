#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT_UNDER_TEST="$REPO_DIR/scripts/cleanup-stale-stow-links.sh"
WORK_DIR="$SCRIPT_DIR/.tmp"
FAKE_HOME="$WORK_DIR/home"
FAKE_REPO="$WORK_DIR/repo"

fail() {
  printf "FAIL %s\n" "$*" >&2
  exit 1
}

pass() {
  printf "PASS %s\n" "$*"
}

reset_fixture() {
  rm -rf "$WORK_DIR"
  mkdir -p \
    "$FAKE_HOME/.config/aerospace" \
    "$FAKE_HOME/.config/borders" \
    "$FAKE_HOME/.config/keep" \
    "$FAKE_REPO/stow/aerospace/.config/aerospace" \
    "$FAKE_REPO/stow/borders/.config/borders" \
    "$FAKE_REPO/stow/shell/.config/shell" \
    "$FAKE_REPO/profiles"

  cat > "$FAKE_REPO/profiles/stow-os.map" <<'MAP'
aerospace macos
borders macos
MAP

  : > "$FAKE_REPO/stow/aerospace/.config/aerospace/aerospace.toml"
  : > "$FAKE_REPO/stow/borders/.config/borders/bordersrc"
  : > "$FAKE_REPO/stow/shell/.config/shell/env.sh"

  ln -s "../../../repo/stow/aerospace/.config/aerospace/aerospace.toml" "$FAKE_HOME/.config/aerospace/aerospace.toml"
  ln -s "../../../repo/stow/borders/.config/borders/bordersrc" "$FAKE_HOME/.config/borders/bordersrc"
  ln -s "/tmp/not-this-repo" "$FAKE_HOME/.config/keep/external"
  printf "real file\n" > "$FAKE_HOME/.config/keep/real-file"
}

run_cleanup() {
  HOME="$FAKE_HOME" \
  REPO_DIR="$FAKE_REPO" \
  STOW_DIR="$FAKE_REPO/stow" \
  PROFILES_DIR="$FAKE_REPO/profiles" \
  STOW_OS_MAP="$FAKE_REPO/profiles/stow-os.map" \
  "$SCRIPT_UNDER_TEST" --os omarchy
}

run_cleanup_dry() {
  HOME="$FAKE_HOME" \
  REPO_DIR="$FAKE_REPO" \
  STOW_DIR="$FAKE_REPO/stow" \
  PROFILES_DIR="$FAKE_REPO/profiles" \
  STOW_OS_MAP="$FAKE_REPO/profiles/stow-os.map" \
  DRY_RUN=1 \
  "$SCRIPT_UNDER_TEST" --os omarchy
}

test_removes_only_repo_owned_incompatible_links() {
  reset_fixture
  run_cleanup > "$WORK_DIR/cleanup.out"

  [ ! -e "$FAKE_HOME/.config/aerospace/aerospace.toml" ] || fail "aerospace stale link was not removed"
  [ ! -e "$FAKE_HOME/.config/borders/bordersrc" ] || fail "borders stale link was not removed"
  [ ! -d "$FAKE_HOME/.config/aerospace" ] || fail "empty aerospace directory was not removed"
  [ ! -d "$FAKE_HOME/.config/borders" ] || fail "empty borders directory was not removed"
  [ -L "$FAKE_HOME/.config/keep/external" ] || fail "external symlink was incorrectly removed"
  [ -f "$FAKE_HOME/.config/keep/real-file" ] || fail "real file was incorrectly removed"
  grep -q "removed stale stow link" "$WORK_DIR/cleanup.out" || fail "cleanup did not report removed links"
  pass "stale-macos-links-removed-on-omarchy"
}

test_dry_run_removes_nothing() {
  reset_fixture
  run_cleanup_dry > "$WORK_DIR/cleanup-dry.out"

  [ -L "$FAKE_HOME/.config/aerospace/aerospace.toml" ] || fail "dry-run removed aerospace link"
  [ -L "$FAKE_HOME/.config/borders/bordersrc" ] || fail "dry-run removed borders link"
  grep -q "\[dry-run\] would remove stale stow link" "$WORK_DIR/cleanup-dry.out" || fail "dry-run did not report planned removal"
  pass "stale-cleanup-dry-run"
}

main() {
  test_removes_only_repo_owned_incompatible_links
  test_dry_run_removes_nothing
}

main
