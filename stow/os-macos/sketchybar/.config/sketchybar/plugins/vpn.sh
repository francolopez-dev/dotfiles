#!/usr/bin/env sh

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
CONFIG_DIR=${CONFIG_DIR:-$(dirname -- "$SCRIPT_DIR")}
# shellcheck source=/dev/null
. "$CONFIG_DIR/colors.sh"

NAME=${NAME:-vpn}
TAILSCALE=${TAILSCALE:-}

if [ -z "$TAILSCALE" ]; then
  if command -v tailscale >/dev/null 2>&1; then
    TAILSCALE=$(command -v tailscale)
  elif [ -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ]; then
    TAILSCALE=/Applications/Tailscale.app/Contents/MacOS/Tailscale
  fi
fi

# Hide the item entirely until Tailscale exists; a permanent
# "not installed" label is just noise on the bar.
if [ -z "$TAILSCALE" ]; then
  if command -v sketchybar >/dev/null 2>&1; then
    sketchybar --set "$NAME" drawing=off
  fi
  exit 0
fi

if "$TAILSCALE" status >/dev/null 2>&1; then
  icon="󰖂"
  label="tailnet"
  color=$GREEN
else
  icon="󰦝"
  label="off"
  color=$MUTED
fi

if command -v sketchybar >/dev/null 2>&1; then
  sketchybar --set "$NAME" \
    drawing=on \
    icon="$icon" \
    label="$label" \
    icon.color="$color" \
    label.color="$color"
else
  printf '%s %s\n' "$icon" "$label"
fi
