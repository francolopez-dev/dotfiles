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

check_hypridle_timeouts() {
  local profile="$1" expected="$2" hypridle_conf timeouts
  hypridle_conf="$repo_dir/stow/$profile/hypridle/.config/hypr/hypridle.conf"
  if [[ ! -f "$hypridle_conf" ]]; then
    printf 'missing profile hypridle: %s\n' "$profile" >&2
    failed=1
    return
  fi

  timeouts="$(grep -E '^[[:space:]]*timeout = ' "$hypridle_conf" | tr -s ' ' | cut -d' ' -f4 | paste -sd, -)"
  if [[ "$timeouts" == "$expected" ]]; then
    printf 'ok profile hypridle timeouts: %s (%s)\n' "$profile" "$timeouts"
  else
    printf 'bad profile hypridle timeouts: %s got %s expected %s\n' "$profile" "$timeouts" "$expected" >&2
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

check_hypridle_timeouts profile-nox-omarchy 240,600,660,1800
check_hypridle_timeouts profile-fornax-omarchy 180,600,900,3600

for profile in profile-nox-omarchy profile-fornax-omarchy; do
  plymouth_script="$repo_dir/stow/$profile/plymouth/.config/dotfiles/plymouth/omarchy.script"
  if [[ -f "$plymouth_script" ]]; then
    printf 'ok profile plymouth unlock: %s\n' "$profile"
  else
    printf 'missing profile plymouth unlock: %s\n' "$profile" >&2
    failed=1
  fi
done

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
