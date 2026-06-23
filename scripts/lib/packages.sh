#!/usr/bin/env bash
# Package helpers. Source after lib/common.sh.

# desired_packages — prints the deduped, ordered set of declared packages
# for this machine (global + os + profile), ignoring blank/comment lines.
desired_packages() {
  local f
  while read -r f; do
    [[ -z "$f" ]] && continue
    sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$f"
  done < <(resolve_package_lists) | awk 'NF' | awk '!seen[$0]++'
}

# pkg_manager — echoes the native installer command base for this OS.
pkg_manager() {
  case "$(detect_os)" in
    omarchy) command -v yay >/dev/null && echo "yay -S --needed" || echo "sudo pacman -S --needed" ;;
    debian|ubuntu) echo "sudo apt-get install -y" ;;
    *) echo "" ;;
  esac
}
