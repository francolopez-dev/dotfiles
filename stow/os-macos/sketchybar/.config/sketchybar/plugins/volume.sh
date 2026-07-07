#!/usr/bin/env sh

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
CONFIG_DIR=${CONFIG_DIR:-$(dirname -- "$SCRIPT_DIR")}
# shellcheck source=/dev/null
. "$CONFIG_DIR/colors.sh"
MUTED=${MUTED:-0xff6b7280}

NAME=${NAME:-volume}

settings=$(/usr/bin/osascript -e 'get volume settings' 2>/dev/null || true)
muted=$(printf '%s\n' "$settings" | /usr/bin/awk -F'output muted:' '{ print $2 }' | /usr/bin/awk -F',' '{ gsub(/^ +| +$/, "", $1); print $1 }')
volume=${INFO:-$(printf '%s\n' "$settings" | /usr/bin/awk -F'output volume:' '{ print $2 }' | /usr/bin/awk -F',' '{ gsub(/^ +| +$/, "", $1); print $1 }')}

case ${volume:-0} in
  ''|*[!0-9]*) volume=0 ;;
esac

if [ "$muted" = "true" ] || [ "$volume" -eq 0 ]; then
  icon=""
  label="muted"
  color=$MUTED
elif [ "$volume" -ge 67 ]; then
  icon=""
  label="$volume%"
  color=$BLUE
elif [ "$volume" -ge 34 ]; then
  icon=""
  label="$volume%"
  color=$BLUE
else
  icon=""
  label="$volume%"
  color=$BLUE
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
