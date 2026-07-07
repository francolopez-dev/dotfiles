#!/usr/bin/env bash
# macos-inventory.sh — read-only macOS machine inventory for audits/rebuilds.
#
# Prints system, brew, symlink, and config state WITHOUT secrets. Hard rules:
#   - never reads file contents under ~/.ssh except Host/Include lines of
#     ~/.ssh/config (names/permissions only otherwise)
#   - never prints environment variables
#   - never reads .npmrc, .netrc, keychains, or browser profiles
#   - takes no write actions of any kind
# Runs under macOS /bin/bash 3.2 on purpose (no bash-4 features).
set -euo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
  echo "macos-inventory: this script only runs on macOS" >&2
  exit 0
fi

section() { printf '\n== %s ==\n' "$1"; }

section "system"
sw_vers
printf 'arch: %s\n' "$(uname -m)"
printf 'cpu: %s\n' "$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo unknown)"
printf 'hostname: %s (LocalHostName: %s)\n' \
  "$(hostname -s)" "$(scutil --get LocalHostName 2>/dev/null || echo unset)"

section "shell"
printf 'SHELL: %s\n' "${SHELL:-unknown}"
printf '/bin/bash: %s\n' "$(/bin/bash --version | head -1)"
printf 'zsh: %s\n' "$(zsh --version 2>/dev/null || echo missing)"

section "homebrew"
if command -v brew >/dev/null 2>&1; then
  brew --version | head -1
  printf 'prefix: %s\n' "$(brew --prefix)"
  printf '\n-- taps --\n'
  brew tap
  printf '\n-- formulae (installed on request) --\n'
  brew leaves --installed-on-request | tr '\n' ' '; echo
  printf '\n-- casks --\n'
  brew list --cask 2>/dev/null | tr '\n' ' '; echo
  printf '\n-- services --\n'
  brew services list 2>/dev/null || true
else
  echo "brew: missing"
fi

section "dangling symlinks (home, .config, .ssh)"
found=0
while IFS= read -r f; do
  if [ ! -e "$f" ]; then
    printf 'DANGLING %s -> %s\n' "$f" "$(readlink "$f")"
    found=1
  fi
done < <({ find "$HOME" -maxdepth 1 -type l 2>/dev/null
           find "$HOME/.config" "$HOME/.ssh" -maxdepth 3 -type l 2>/dev/null; })
[ "$found" -eq 0 ] && echo "(none)"

section "managed symlinks into ~/dotfiles"
while IFS= read -r f; do
  case "$(readlink "$f")" in
    *dotfiles/stow/*) printf '%s -> %s\n' "$f" "$(readlink "$f")" ;;
  esac
done < <({ find "$HOME" -maxdepth 1 -type l 2>/dev/null
           find "$HOME/.config" -maxdepth 3 -type l 2>/dev/null; })

section "ssh (names only)"
if [ -d "$HOME/.ssh" ]; then
  # shellcheck disable=SC2012  # names/permissions only, deliberate
  ls -l "$HOME/.ssh" | awk 'NR>1 {print $1, $NF}'
  printf -- '-- config Host/Include lines --\n'
  grep -E '^[[:space:]]*(Host|Include)[[:space:]]' "$HOME/.ssh/config" 2>/dev/null \
    || echo "(no config or no Host lines)"
fi

section "LaunchAgents"
ls "$HOME/Library/LaunchAgents" 2>/dev/null || echo "(none)"

section "applications"
ls /Applications

section "notable defaults"
d() {
  printf '%-55s %s\n' "$1 $2" \
    "$(defaults read "$1" "$2" 2>/dev/null || echo unset)"
}
d com.apple.dock autohide
d com.apple.dock orientation
d com.apple.dock tilesize
d com.apple.finder AppleShowAllFiles
d -g AppleShowAllExtensions
d -g KeyRepeat
d -g InitialKeyRepeat
d -g ApplePressAndHoldEnabled
d com.apple.AppleMultitouchTrackpad Clicking
