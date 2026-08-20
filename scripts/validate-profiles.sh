#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failed=0
warned=0

package_items() {
  sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$@" | awk 'NF'
}

known_aur_package() {
  case "$1" in
    paru-bin|brave-bin|zen-browser-bin) return 0 ;;
    *) return 1 ;;
  esac
}

allowed_source_aur_package() {
  case "$1" in
    # Source-built AUR packages must be explicitly justified here.
    *) return 1 ;;
  esac
}

known_pacman_package() {
  case "$1" in
    git|stow|tmux|fzf|fd|ripgrep|jq|bat|eza|fastfetch|btop|htop|ncdu|git-delta|direnv|tldr|neovim|zsh|curl|bash|wget|nano|ca-certificates|shellcheck|atuin|networkmanager|tailscale|pamixer|power-profiles-daemon|iw|ghostty|alacritty|vivaldi|firefox|zoxide|yazi|socat|restic|age|obsidian|kdeconnect|wl-clipboard|libnotify|ollama|ollama-cuda|pacman|base-devel) return 0 ;;
    *) return 1 ;;
  esac
}

paru_health_status() {
  local path output lib first_line
  path="$(command -v paru 2>/dev/null || true)"
  if [[ -z "$path" ]]; then
    printf 'missing\n'
    return 1
  fi
  if output="$(paru --version 2>&1)"; then
    printf 'ready\n'
    return 0
  fi
  lib="$(printf '%s\n' "$output" | sed -n 's/.*\(libalpm\.so\.[^: ]*\).*/\1/p' | sed -n '1p')"
  if [[ -n "$lib" ]]; then
    printf 'broken: missing %s\n' "$lib"
  else
    first_line="$(printf '%s\n' "$output" | sed -n '1p')"
    printf 'broken: %s\n' "${first_line:-paru --version failed}"
  fi
  return 2
}

aur_packages_declared() {
  local f
  for f in "$repo_dir"/packages/*/aur.txt; do
    [[ -f "$f" ]] || continue
    if [[ -n "$(package_items "$f")" ]]; then
      return 0
    fi
  done
  return 1
}

is_arch_validation_host() {
  [[ -f /etc/os-release ]] || return 1
  # shellcheck disable=SC1091
  . /etc/os-release
  case "${ID-}:${ID_LIKE-}" in
    arch:*|*:*arch*) return 0 ;;
    *) return 1 ;;
  esac
}

check_profile() {
  local profile="$1"
  if [[ -d "$repo_dir/stow/$profile" ]]; then
    printf 'ok profile dir: %s\n' "$profile"
  else
    printf 'missing profile dir: %s\n' "$profile" >&2
    failed=1
  fi
  if [[ -f "$repo_dir/packages/$profile/pacman.txt" && -f "$repo_dir/packages/$profile/aur.txt" ]]; then
    printf 'ok package declarations: %s/{pacman,aur}.txt\n' "$profile"
  else
    printf 'missing package declarations: %s/{pacman,aur}.txt\n' "$profile" >&2
    failed=1
  fi
}

check_forbidden_aur_packages() {
  local pkg f
  for f in "$repo_dir"/packages/*/aur.txt; do
    [[ -f "$f" ]] || continue
    while read -r pkg; do
      if [[ "$pkg" == *-git ]] && ! allowed_source_aur_package "$pkg"; then
        printf 'fail: forbidden source AUR package declaration\nfile: %s\npackage: %s\nfix: prefer official repos, then maintained *-bin packages; source builds require explicit override\n' "${f#"$repo_dir/"}" "$pkg" >&2
        failed=1
      elif [[ "$pkg" != *-bin ]] && ! allowed_source_aur_package "$pkg"; then
        printf 'fail: non-binary AUR package declaration\nfile: %s\npackage: %s\nfix: prefer official repos or a maintained *-bin package unless explicitly overridden\n' "${f#"$repo_dir/"}" "$pkg" >&2
        failed=1
      fi
      if known_aur_package "$pkg"; then
        continue
      elif known_pacman_package "$pkg"; then
        printf 'fail: forbidden AUR package declaration\nfile: %s\npackage: %s\nfix: move to the matching pacman.txt\n' "${f#"$repo_dir/"}" "$pkg" >&2
        failed=1
      fi
      if command -v pacman >/dev/null 2>&1 && pacman -Si "$pkg" >/dev/null 2>&1; then
        printf 'fail: forbidden AUR package declaration\nfile: %s\npackage: %s\nfix: move to the matching pacman.txt; package exists in official repos\n' "${f#"$repo_dir/"}" "$pkg" >&2
        failed=1
      fi
    done < <(package_items "$f")
  done
}

check_package_duplicates() {
  local kind pkg f tmp status
  for kind in pacman aur apt; do
    tmp="$(mktemp)"
    for f in "$repo_dir"/packages/*/"$kind".txt; do
      [[ -f "$f" ]] || continue
      while read -r pkg; do
        printf '%s\t%s\n' "$pkg" "${f#"$repo_dir/"}" >>"$tmp"
      done < <(package_items "$f")
    done
    status=0
    awk -F '\t' -v kind="$kind" '
      seen[$1] { printf "warn: duplicate %s package: %s in %s and %s; install helpers dedupe it\n", kind, $1, seen[$1], $2 > "/dev/stderr"; warned=1; next }
      { seen[$1]=$2 }
      END { exit warned ? 2 : 0 }
    ' "$tmp" || status=$?
    if [[ $status -eq 2 ]]; then
      warned=1
    elif [[ $status -ne 0 ]]; then
      failed=1
    fi
    rm -f "$tmp"
  done
}

check_pacman_aur_overlap_for_profile() {
  local profile="$1" pkg f pacman_tmp aur_tmp layer
  pacman_tmp="$(mktemp)"
  aur_tmp="$(mktemp)"
  for layer in global os-omarchy "$profile"; do
    f="$repo_dir/packages/$layer/pacman.txt"
    [[ -f "$f" ]] && package_items "$f" >>"$pacman_tmp"
  done
  for layer in global os-omarchy "$profile"; do
    f="$repo_dir/packages/$layer/aur.txt"
    [[ -f "$f" ]] && package_items "$f" >>"$aur_tmp"
  done
  while read -r pkg; do
    printf 'fail: package declaration overlap\nprofile: %s\npackage: %s\nfix: declare the package in pacman.txt or aur.txt, not both\n' "$profile" "$pkg" >&2
    failed=1
  done < <(sort -u "$pacman_tmp" | comm -12 - <(sort -u "$aur_tmp"))
  rm -f "$pacman_tmp" "$aur_tmp"
}

check_pacman_aur_overlap() {
  check_pacman_aur_overlap_for_profile profile-nox-omarchy
  check_pacman_aur_overlap_for_profile profile-fornax-omarchy
}

check_pacman_declarations() {
  local pkg f
  for f in "$repo_dir"/packages/*/pacman.txt; do
    [[ -f "$f" ]] || continue
    while read -r pkg; do
      if known_aur_package "$pkg"; then
        printf 'fail: known AUR package declared as pacman\nfile: %s\npackage: %s\nfix: move it to the matching aur.txt\n' "${f#"$repo_dir/"}" "$pkg" >&2
        failed=1
      elif command -v pacman >/dev/null 2>&1 && ! pacman -Si "$pkg" >/dev/null 2>&1; then
        printf 'bad pacman declaration: %s in %s not found in official repos\n' "$pkg" "${f#"$repo_dir/"}" >&2
        failed=1
      fi
    done < <(package_items "$f")
  done
}

check_aur_helper() {
  if ! aur_packages_declared; then
    printf 'ok no AUR packages declared\n'
    return 0
  fi
  if is_arch_validation_host; then
    local health
    health="$(paru_health_status 2>/dev/null || true)"
    case "$health" in
      ready) printf 'ok paru AUR helper ready\n' ;;
      missing) printf 'fail: AUR packages are declared but paru is missing\n' >&2; failed=1 ;;
      broken:*) printf 'fail: paru installed but broken: %s\n' "${health#broken: }" >&2; failed=1 ;;
    esac
  else
    printf 'ok AUR helper runtime check skipped on non-Arch validation host\n'
  fi
}

check_bootstrap_prereqs_declared() {
  local prereq found
  for prereq in git stow zsh curl bash ca-certificates; do
    found=0
    if package_items "$repo_dir/packages/global/pacman.txt" "$repo_dir/packages/os-omarchy/pacman.txt" | grep -qx "$prereq"; then
      found=1
    fi
    if [[ $found -eq 1 ]]; then
      printf 'ok bootstrap pacman prerequisite declared: %s\n' "$prereq"
    else
      printf 'missing bootstrap pacman prerequisite declaration: %s\n' "$prereq" >&2
      failed=1
    fi
  done
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

nox_monitor="$repo_dir/stow/profile-nox-omarchy/hyprland/.config/hypr/monitors.lua"
if grep -Eq 'hl\.monitor\(\{ output = "eDP-1", mode = "preferred", position = "auto", scale = 1(\.10?)? \}\)' "$nox_monitor"; then
  printf 'ok nox monitor scale: eDP-1 scale 1 or 1.1\n'
else
  printf 'bad nox monitor scale in %s\n' "$nox_monitor" >&2
  failed=1
fi

fornax_monitor="$repo_dir/stow/profile-fornax-omarchy/hyprland/.config/hypr/monitors.lua"
if grep -q '^local omarchy_monitor_scale = ' "$fornax_monitor" &&
  grep -q '^hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })$' "$fornax_monitor"; then
  printf 'ok fornax monitor scale is Display-panel persistent\n'
else
  printf 'bad fornax monitor persistence in %s\n' "$fornax_monitor" >&2
  failed=1
fi

omarchy_bindings="$repo_dir/stow/os-omarchy/hyprland/.config/hypr/bindings.lua"
if grep -q 'bind_exec(.*code:' "$omarchy_bindings"; then
  printf 'bad Omarchy 4 Lua binding uses nonfunctional code:N key in %s\n' "$omarchy_bindings" >&2
  failed=1
else
  printf 'ok Omarchy 4 Lua bindings use symbolic keys\n'
fi

if grep -RqsE '^wezterm(-git)?($|[[:space:]])' "$repo_dir/packages"; then
  printf 'bad package declaration: wezterm found\n' >&2
  failed=1
else
  printf 'ok no wezterm package declarations\n'
fi

check_forbidden_aur_packages
check_package_duplicates
check_pacman_aur_overlap
check_pacman_declarations
check_aur_helper
check_bootstrap_prereqs_declared

check_hypridle_timeouts profile-nox-omarchy 240,600,660,1800
check_hypridle_timeouts profile-fornax-omarchy 180,600,900,3600,600,2100,3600,7200,18000

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

if [[ $failed -eq 0 && $warned -eq 1 ]]; then
  printf 'ok profile validation passed with warnings\n'
fi

exit "$failed"
