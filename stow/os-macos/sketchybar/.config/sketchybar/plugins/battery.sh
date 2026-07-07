#!/usr/bin/env sh

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
CONFIG_DIR=${CONFIG_DIR:-$(dirname -- "$SCRIPT_DIR")}
# shellcheck source=/dev/null
. "$CONFIG_DIR/colors.sh"

NAME=${NAME:-battery}

battery_info=$(/usr/bin/pmset -g batt 2>/dev/null || true)
capacity=$(printf '%s\n' "$battery_info" | /usr/bin/awk '/InternalBattery/ { if (match($0, /[0-9]+%/)) { value = substr($0, RSTART, RLENGTH - 1); print value; exit } }')
state=$(printf '%s\n' "$battery_info" | /usr/bin/awk -F';' '/InternalBattery/ { gsub(/^ +| +$/, "", $2); print $2; exit }')

case ${capacity:-0} in
  ''|*[!0-9]*) capacity=0 ;;
esac

case $state in
  charging) icon="󰂄"; color=$IDLE ;;
  charged) icon="󰂅"; color=$GREEN ;;
  *)
    if [ "$capacity" -ge 95 ]; then
      icon="󰁹"
      color=$GREEN
    elif [ "$capacity" -ge 90 ]; then
      icon="󰂂"
      color=$BATTERY_SOFT
    elif [ "$capacity" -ge 80 ]; then
      icon="󰂁"
      color=$BATTERY_SOFT
    elif [ "$capacity" -ge 70 ]; then
      icon="󰂀"
      color=$BATTERY_SOFT
    elif [ "$capacity" -ge 60 ]; then
      icon="󰁿"
      color=$BATTERY_WARM
    elif [ "$capacity" -ge 50 ]; then
      icon="󰁾"
      color=$BATTERY_WARM
    elif [ "$capacity" -ge 40 ]; then
      icon="󰁽"
      color=$BATTERY_WARM
    elif [ "$capacity" -ge 30 ]; then
      icon="󰁼"
      color=$BATTERY_LOW
    elif [ "$capacity" -ge 15 ]; then
      icon="󰁻"
      color=$BATTERY_LOW
    else
      icon="󰁺"
      color=$RED
    fi
    ;;
esac

if command -v sketchybar >/dev/null 2>&1; then
  sketchybar --set "$NAME" \
    icon="$icon" \
    label="$capacity%" \
    icon.color="$color" \
    label.color="$color"
else
  printf '%s %s%%\n' "$icon" "$capacity"
fi
