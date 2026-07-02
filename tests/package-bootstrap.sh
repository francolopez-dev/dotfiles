#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  printf 'fail: %s\n' "$*" >&2
  exit 1
}

assert_contains() {
  local needle="$1" file="$2"
  grep -Fq -- "$needle" "$file" || fail "missing '$needle' in $file"
}

assert_not_contains() {
  local needle="$1" file="$2"
  if grep -Fq -- "$needle" "$file"; then
    fail "unexpected '$needle' in $file"
  fi
}

assert_line() {
  local needle="$1"
  grep -Fxq -- "$needle" || fail "missing package line: $needle"
}

assert_no_line() {
  local needle="$1"
  if grep -Fxq -- "$needle"; then
    fail "unexpected package line: $needle"
  fi
}

assert_not_contains '--batchinstall' "$repo_dir/scripts/lib/packages.sh"
assert_not_contains 'Install paru with pacman?' "$repo_dir/scripts/lib/packages.sh"
assert_not_contains 'Bootstrap paru from AUR with git and makepkg?' "$repo_dir/scripts/lib/packages.sh"
assert_not_contains 'missing AUR package(s)?' "$repo_dir/scripts/dotfiles"
assert_not_contains 'makepkg -si' "$repo_dir/scripts/lib/packages.sh"
assert_contains 'This can take several minutes.' "$repo_dir/scripts/lib/packages.sh"
assert_contains 'sudo pacman -U --needed' "$repo_dir/scripts/lib/packages.sh"
assert_contains 'paru --version' "$repo_dir/scripts/lib/packages.sh"
assert_contains 'sudo pacman -Rns --noconfirm paru-bin' "$repo_dir/scripts/lib/packages.sh"
assert_contains 'paru-bin is installed but incompatible with the current pacman/libalpm' "$repo_dir/scripts/lib/packages.sh"
assert_contains 'Prebuilt paru-bin is incompatible with this system. Building paru from source is required this time.' "$repo_dir/scripts/lib/packages.sh"
assert_contains 'paru-debug-*|*.sig) continue' "$repo_dir/scripts/lib/packages.sh"
assert_contains 'https://aur.archlinux.org/paru-bin.git' "$repo_dir/scripts/lib/packages.sh"
assert_not_contains "OPTIONS='!debug'" "$repo_dir/scripts/lib/packages.sh"
assert_not_contains '--noconfirm' "$repo_dir/scripts/bootstrap.sh"
assert_contains 'pacman_install_args=(-S --needed)' "$repo_dir/scripts/bootstrap.sh"
assert_contains 'pacman_install_args=(-Syu --needed)' "$repo_dir/scripts/bootstrap.sh"
assert_contains 'sudo pacman "${pacman_install_args[@]}"' "$repo_dir/scripts/bootstrap.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

mkdir -p "$tmp/bin"
cat >"$tmp/bin/hostname" <<'EOF'
#!/usr/bin/env bash
printf 'NOX\n'
EOF
chmod +x "$tmp/bin/hostname"
PATH="$tmp/bin:$PATH"

mkdir -p \
  "$tmp/packages/global" \
  "$tmp/packages/os-omarchy" \
  "$tmp/packages/profile-test-omarchy"

printf '%s\n' stow git >"$tmp/packages/global/pacman.txt"
printf '%s\n' ca-certificates >"$tmp/packages/os-omarchy/pacman.txt"
printf '%s\n' profile-pacman-package >"$tmp/packages/profile-test-omarchy/pacman.txt"
printf '%s\n' zen-browser-bin >"$tmp/packages/os-omarchy/aur.txt"
printf '%s\n' profile-aur-package >"$tmp/packages/profile-test-omarchy/aur.txt"

export DOTFILES_DIR="$tmp"
export DOTFILES_PROFILE=profile-test-omarchy

# shellcheck disable=SC1091
. "$repo_dir/scripts/lib/common.sh"
# shellcheck disable=SC1091
. "$repo_dir/scripts/lib/packages.sh"

# shellcheck disable=SC2218
[[ "$(detect_hostname)" == "nox" ]] || fail 'detect_hostname did not normalize uppercase hostnames'

detect_os() { printf 'omarchy\n'; }
detect_hostname() { printf 'test\n'; }

desired_pacman_packages | assert_line stow
desired_pacman_packages | assert_line profile-pacman-package
desired_pacman_packages | assert_no_line zen-browser-bin
desired_aur_packages | assert_line zen-browser-bin
desired_aur_packages | assert_line profile-aur-package
desired_aur_packages | assert_no_line stow

printf '%s\n' stow >"$tmp/packages/profile-test-omarchy/aur.txt"
if validate_aur_package_names >/dev/null 2>&1; then
  fail 'forbidden AUR package stow was accepted'
fi

printf '%s\n' zen-browser-bin >"$tmp/packages/profile-test-omarchy/pacman.txt"
if validate_pacman_package_names >/dev/null 2>&1; then
  fail 'known AUR package zen-browser-bin was accepted in pacman.txt'
fi

printf '%s\n' profile-aur-package >"$tmp/packages/profile-test-omarchy/aur.txt"
if validate_aur_package_names >/dev/null 2>&1; then
  fail 'non-binary AUR package was accepted without override'
fi

printf '%s\n' profile-package-git >"$tmp/packages/profile-test-omarchy/aur.txt"
if validate_aur_package_names >/dev/null 2>&1; then
  fail 'source AUR package was accepted without override'
fi

printf 'ok package bootstrap tests\n'
