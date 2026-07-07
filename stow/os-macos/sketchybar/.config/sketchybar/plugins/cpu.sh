#!/usr/bin/env sh

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
CONFIG_DIR=${CONFIG_DIR:-$(dirname -- "$SCRIPT_DIR")}
# shellcheck source=/dev/null
. "$CONFIG_DIR/colors.sh"

NAME=${NAME:-cpu}

cpu_percent=$(
  /bin/ps -A -o %cpu= | /usr/bin/awk -v cores="$(/usr/sbin/sysctl -n hw.logicalcpu 2>/dev/null || printf '1')" '
    { total += $1 }
    END {
      if (cores < 1) cores = 1
      printf "%.0f", total / cores
    }
  '
)

case ${cpu_percent:-0} in
  ''|*[!0-9]*) cpu_percent=0 ;;
esac

color=$IDLE
if [ "$cpu_percent" -ge 85 ]; then
  color=$RED
elif [ "$cpu_percent" -ge 60 ]; then
  color=$YELLOW
fi

if command -v sketchybar >/dev/null 2>&1; then
  sketchybar --set "$NAME" \
    icon="󰍛" \
    label="$cpu_percent%" \
    icon.color="$color" \
    label.color="$color"
else
  printf '󰍛 %s%%\n' "$cpu_percent"
fi
