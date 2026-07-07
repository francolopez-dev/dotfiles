#!/usr/bin/env sh

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
CONFIG_DIR=${CONFIG_DIR:-$(dirname -- "$SCRIPT_DIR")}
# shellcheck source=/dev/null
. "$CONFIG_DIR/colors.sh"

NAME=${NAME:-memory}

memory_percent=$(
  /usr/bin/vm_stat | /usr/bin/awk -v page_size="$(/usr/bin/pagesize 2>/dev/null || printf '4096')" -v mem_bytes="$(/usr/sbin/sysctl -n hw.memsize 2>/dev/null || printf '0')" '
    /Pages active/ { gsub(/[^0-9]/, "", $3); active = $3 }
    /Pages wired down/ { gsub(/[^0-9]/, "", $4); wired = $4 }
    END {
      if (mem_bytes <= 0 || page_size <= 0) {
        print 0
        exit
      }
      total_pages = mem_bytes / page_size
      printf "%.0f", ((active + wired) / total_pages) * 100
    }
  '
)

case ${memory_percent:-0} in
  ''|*[!0-9]*) memory_percent=0 ;;
esac

color=$IDLE
if [ "$memory_percent" -ge 88 ]; then
  color=$RED
elif [ "$memory_percent" -ge 70 ]; then
  color=$YELLOW
fi

if command -v sketchybar >/dev/null 2>&1; then
  sketchybar --set "$NAME" \
    icon="󰘚" \
    label="$memory_percent%" \
    icon.color="$color" \
    label.color="$color"
else
  printf '󰘚 %s%%\n' "$memory_percent"
fi
