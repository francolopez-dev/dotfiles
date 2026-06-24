#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failed=0

check_profile() {
  local profile="$1"
  if [[ -d "$repo_dir/stow/$profile" ]]; then
    printf 'ok profile dir: %s\n' "$profile"
  else
    printf 'missing profile dir: %s\n' "$profile" >&2
    failed=1
  fi
  if [[ -f "$repo_dir/packages/$profile.list" ]]; then
    printf 'ok package list: %s.list\n' "$profile"
  else
    printf 'missing package list: %s.list\n' "$profile" >&2
    failed=1
  fi
}

check_profile profile-nox-omarchy
check_profile profile-fornax-omarchy

nox_monitor="$repo_dir/stow/profile-nox-omarchy/hyprland/.config/hypr/conf.d/20-monitors.conf"
if grep -Eq '^monitor = eDP-1, preferred, auto, 1(\.00)?$' "$nox_monitor"; then
  printf 'ok nox monitor scale: eDP-1 scale 1\n'
else
  printf 'bad nox monitor scale in %s\n' "$nox_monitor" >&2
  failed=1
fi

if grep -RqsE '^wezterm(-git)?($|[[:space:]])' "$repo_dir/packages"; then
  printf 'bad package declaration: wezterm found\n' >&2
  failed=1
else
  printf 'ok no wezterm package declarations\n'
fi

stale_profile="laptop-personal"
if grep -Rqs \
  --exclude-dir=.git \
  --exclude-dir=tests \
  --exclude='*.tmp' \
  "${stale_profile}-omarchy" "$repo_dir"; then
  printf 'bad stale profile reference: %s-omarchy\n' "$stale_profile" >&2
  failed=1
else
  printf 'ok no stale laptop-personal profile references\n'
fi

exit "$failed"
