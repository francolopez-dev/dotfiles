#!/usr/bin/env bash
set -euo pipefail

window_id=${AEROSPACE_WINDOW_ID:-}
if [[ -z "$window_id" ]]; then
  exit 0
fi

# Let AeroSpace finish inserting the new window into the workspace tree.
sleep 0.2

workspace=$(aerospace echo --window-id "$window_id" -- '%{workspace}')
layout=$(aerospace echo --window-id "$window_id" -- '%{window-parent-container-layout}')

if [[ -z "$workspace" || "$layout" == "floating" ]]; then
  exit 0
fi

tiled_count=0
while IFS= read -r window_layout; do
  if [[ "$window_layout" != "floating" ]]; then
    tiled_count=$((tiled_count + 1))
  fi
done < <(aerospace list-windows --workspace "$workspace" --format '%{window-parent-container-layout}')

case "$tiled_count" in
  3)
    aerospace join-with --window-id "$window_id" left || true
    ;;
  4)
    aerospace move --window-id "$window_id" left || true
    aerospace join-with --window-id "$window_id" left || true
    ;;
esac
