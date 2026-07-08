#!/usr/bin/env sh

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
CONFIG_DIR=${CONFIG_DIR:-$(dirname -- "$SCRIPT_DIR")}
# shellcheck source=/dev/null
. "$CONFIG_DIR/colors.sh"

NAME=${NAME:-wifi}

ssid=$(/usr/sbin/ipconfig getsummary en0 2>/dev/null | /usr/bin/awk -F': ' '/ SSID/ { print $2; exit }')
active_service=$(/usr/sbin/networksetup -listnetworkserviceorder 2>/dev/null | /usr/bin/awk -F'Device: ' '/Device: / { sub(/\)/, "", $2); print $2; exit }')
active_addr=''

if [ -n "$active_service" ]; then
  active_addr=$(/usr/sbin/ipconfig getifaddr "$active_service" 2>/dev/null || true)
fi

if [ -n "$ssid" ]; then
  icon="󰤨"
  label=$ssid
  color=$CYAN
elif [ -n "$active_addr" ]; then
  icon="󰈀"
  label="ethernet"
  color=$TEAL
else
  icon="󰤮"
  label="offline"
  color=$MUTED
fi

if command -v sketchybar >/dev/null 2>&1; then
  sketchybar --set "$NAME" \
    icon="$icon" \
    label="$label" \
    icon.color="$color" \
    label.color="$color"
else
  printf '%s %s\n' "$icon" "$label"
fi
