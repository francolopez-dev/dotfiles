#!/usr/bin/env bash
# Fixture for rescue_ssh_from_legacy_checkout: a pre-layer checkout where old
# stow folding left ~/.ssh as a symlink into the repo, with private keys and
# authorized_keys accumulated untracked inside it (the domum-core case).
# shellcheck disable=SC2088  # literal ~/ in assertion messages
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

fail() {
  printf 'fail: %s\n' "$*" >&2
  exit 1
}

file_mode() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    stat -f '%Lp' "$1"
  else
    stat -c '%a' "$1"
  fi
}

make_legacy_home() {
  local home="$1" repo
  repo="$home/dotfiles"
  mkdir -p "$repo/stow/ssh/.ssh"
  git -C "$repo" init -q
  printf 'Host github.com\n  User git\n' >"$repo/stow/ssh/.ssh/config"
  git -C "$repo" add stow/ssh/.ssh/config
  git -C "$repo" \
    -c core.hooksPath=/dev/null \
    -c user.name='Dotfiles Test' \
    -c user.email='dotfiles-test@example.invalid' \
    commit -qm 'legacy layout fixture'
  # Untracked key material, exactly what old machines accumulated.
  printf 'PRIVATE KEY\n' >"$repo/stow/ssh/.ssh/id_ed25519"
  chmod 600 "$repo/stow/ssh/.ssh/id_ed25519"
  printf 'ssh-ed25519 AAAA pub\n' >"$repo/stow/ssh/.ssh/id_ed25519.pub"
  printf 'ssh-ed25519 AAAA authorized\n' >"$repo/stow/ssh/.ssh/authorized_keys"
  printf 'host ssh-ed25519 AAAA\n' >"$repo/stow/ssh/.ssh/known_hosts"
  # Old stow folded the whole directory: relative symlink, like on real hosts.
  ln -s dotfiles/stow/ssh/.ssh "$home/.ssh"
}

run_rescue() {
  local home="$1" dry="${2:-0}"
  # Sourcing bootstrap.sh resets DRY_RUN; reassign it after the source.
  HOME="$home" DOTFILES_DIR="$home/dotfiles" WANT_DRY_RUN="$dry" bash -c '
    set -euo pipefail
    DOTFILES_BOOTSTRAP_SOURCE_ONLY=1 source "'"$repo_dir"'/scripts/bootstrap.sh"
    DRY_RUN="$WANT_DRY_RUN"
    rescue_ssh_from_legacy_checkout
  '
}

# --- dry-run changes nothing -----------------------------------------------
home1="$tmp_dir/home-dry"
mkdir -p "$home1"
make_legacy_home "$home1"
run_rescue "$home1" 1 >/dev/null 2>&1
[[ -L "$home1/.ssh" ]] || fail "dry-run must not replace the ~/.ssh symlink"
[[ -f "$home1/dotfiles/stow/ssh/.ssh/id_ed25519" ]] || fail "dry-run must not move keys"

# --- real run migrates keys out of the repo --------------------------------
home2="$tmp_dir/home-real"
mkdir -p "$home2"
make_legacy_home "$home2"
run_rescue "$home2" 0 >/dev/null 2>&1

[[ ! -L "$home2/.ssh" && -d "$home2/.ssh" ]] || fail "~/.ssh must become a real directory"
perms="$(file_mode "$home2/.ssh")"
[[ "$perms" == "700" ]] || fail "~/.ssh must be mode 700, got $perms"
for f in config id_ed25519 id_ed25519.pub authorized_keys known_hosts; do
  [[ -f "$home2/.ssh/$f" ]] || fail "missing ~/.ssh/$f after migration"
done
key_perms="$(file_mode "$home2/.ssh/id_ed25519")"
[[ "$key_perms" == "600" ]] || fail "private key must keep mode 600, got $key_perms"

# Untracked key material must be gone from the repo; the tracked config must
# remain so the checkout stays clean for a ff-only pull.
[[ ! -e "$home2/dotfiles/stow/ssh/.ssh/id_ed25519" ]] || fail "private key still inside the repo"
[[ ! -e "$home2/dotfiles/stow/ssh/.ssh/authorized_keys" ]] || fail "authorized_keys still inside the repo"
[[ -f "$home2/dotfiles/stow/ssh/.ssh/config" ]] || fail "tracked config must stay in the repo"
dirty="$(git -C "$home2/dotfiles" status --porcelain)"
[[ -z "$dirty" ]] || fail "repo must stay clean after migration, got: $dirty"

# Rerunning must be a no-op (idempotent).
run_rescue "$home2" 0 >/dev/null 2>&1
[[ -f "$home2/.ssh/id_ed25519" ]] || fail "second run must not disturb ~/.ssh"

# --- non-legacy homes are untouched -----------------------------------------
home3="$tmp_dir/home-plain"
mkdir -p "$home3/.ssh" "$home3/dotfiles/.git"
printf 'real\n' >"$home3/.ssh/id_ed25519"
run_rescue "$home3" 0 >/dev/null 2>&1
[[ -f "$home3/.ssh/id_ed25519" && ! -L "$home3/.ssh" ]] || fail "real ~/.ssh must be untouched"

home4="$tmp_dir/home-foreign"
mkdir -p "$home4/dotfiles/.git" "$home4/elsewhere/.ssh"
ln -s elsewhere/.ssh "$home4/.ssh"
run_rescue "$home4" 0 >/dev/null 2>&1
[[ -L "$home4/.ssh" ]] || fail "~/.ssh symlink outside the repo must be untouched"

printf 'ok legacy ssh migration fixture passed\n'
