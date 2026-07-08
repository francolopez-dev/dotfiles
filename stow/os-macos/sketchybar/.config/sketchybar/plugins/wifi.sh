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

# Icon-only: the SSID is private info that doesn't belong on an
# always-visible bar. Icon shape + color carry the connection state;
# clicking the item opens the Wi-Fi settings pane for details.
if [ -n "$ssid" ]; then
  icon="󰤨"
  color=$CYAN
elif [ -n "$active_addr" ]; then
  icon="󰈀"
  color=$TEAL
else
  icon="󰤮"
  color=$MUTED
fi

if command -v sketchybar >/dev/null 2>&1; then
  sketchybar --set "$NAME" \
    icon="$icon" \
    icon.color="$color" \
    label.drawing=off
else
  printf '%s\n' "$icon"
fi
