#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
failed=0

package_items() {
  sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$@" | awk 'NF'
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
      case "$pkg" in
        git|stow|zsh|curl|bash|ca-certificates|pacman|base-devel)
          printf 'bad AUR declaration: %s in %s belongs in pacman.txt\n' "$pkg" "${f#"$repo_dir/"}" >&2
          failed=1
          ;;
      esac
      if command -v pacman >/dev/null 2>&1 && pacman -Si "$pkg" >/dev/null 2>&1; then
        printf 'bad AUR declaration: %s in %s exists in official repos\n' "$pkg" "${f#"$repo_dir/"}" >&2
        failed=1
      fi
    done < <(package_items "$f")
  done
}

check_package_duplicates() {
  local kind pkg f tmp
  for kind in pacman aur apt; do
    tmp="$(mktemp)"
    for f in "$repo_dir"/packages/*/"$kind".txt; do
      [[ -f "$f" ]] || continue
      while read -r pkg; do
        printf '%s\t%s\n' "$pkg" "${f#"$repo_dir/"}" >>"$tmp"
      done < <(package_items "$f")
    done
    awk -F '\t' -v kind="$kind" '
      seen[$1] { printf "duplicate %s package: %s in %s and %s\n", kind, $1, seen[$1], $2 > "/dev/stderr"; bad=1; next }
      { seen[$1]=$2 }
      END { exit bad ? 1 : 0 }
    ' "$tmp" || failed=1
    rm -f "$tmp"
  done
}

check_pacman_aur_overlap() {
  local pkg f pacman_tmp aur_tmp
  pacman_tmp="$(mktemp)"
  aur_tmp="$(mktemp)"
  for f in "$repo_dir"/packages/*/pacman.txt; do
    [[ -f "$f" ]] || continue
    package_items "$f" >>"$pacman_tmp"
  done
  for f in "$repo_dir"/packages/*/aur.txt; do
    [[ -f "$f" ]] || continue
    package_items "$f" >>"$aur_tmp"
  done
  while read -r pkg; do
    printf 'bad package declaration: %s appears in both pacman.txt and aur.txt\n' "$pkg" >&2
    failed=1
  done < <(sort -u "$pacman_tmp" | comm -12 - <(sort -u "$aur_tmp"))
  rm -f "$pacman_tmp" "$aur_tmp"
}

check_pacman_declarations() {
  local pkg f
  command -v pacman >/dev/null 2>&1 || return 0
  for f in "$repo_dir"/packages/*/pacman.txt; do
    [[ -f "$f" ]] || continue
    while read -r pkg; do
      if ! pacman -Si "$pkg" >/dev/null 2>&1; then
        printf 'bad pacman declaration: %s in %s not found in official repos\n' "$pkg" "${f#"$repo_dir/"}" >&2
        failed=1
      fi
    done < <(package_items "$f")
  done
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

nox_monitor="$repo_dir/stow/profile-nox-omarchy/hyprland/.config/hypr/conf.d/20-monitors.conf"
if grep -Eq '^[[:space:]]*monitor = eDP-1, preferred, auto, 1(\.10?)?[[:space:]]*$' "$nox_monitor"; then
  printf 'ok nox monitor scale: eDP-1 scale 1 or 1.1\n'
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

check_forbidden_aur_packages
check_package_duplicates
check_pacman_aur_overlap
check_pacman_declarations
check_bootstrap_prereqs_declared

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
