#!/usr/bin/env sh

# Spotify-only media island for macOS. There is no stable public CLI for
# system-wide Now Playing on macOS 26, so this mirrors the Waybar island for
# Spotify and intentionally drops Linux-only screen-recording state.

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
CONFIG_DIR=${CONFIG_DIR:-$(dirname -- "$SCRIPT_DIR")}
# shellcheck source=/dev/null
. "$CONFIG_DIR/colors.sh"

NAME=${NAME:-media}

spotify_state=$(/usr/bin/osascript <<'APPLESCRIPT' 2>/dev/null || true
if application "Spotify" is running then
  tell application "Spotify"
    set player_state to player state as text
    if player_state is "playing" or player_state is "paused" then
      set track_artist to artist of current track
      set track_name to name of current track
      return player_state & linefeed & track_artist & " - " & track_name
    end if
  end tell
end if
APPLESCRIPT
)

state=$(printf '%s\n' "$spotify_state" | /usr/bin/sed -n '1p')
label=$(printf '%s\n' "$spotify_state" | /usr/bin/sed -n '2p')

if [ ${#label} -gt 56 ]; then
  label=$(printf '%s' "$label" | /usr/bin/cut -c 1-53)
  label="$label..."
fi

case $state in
  playing)
    icon="󰎈"
    color=$GREEN
    drawing=on
    ;;
  paused)
    icon="󰏤"
    color=$YELLOW
    drawing=on
    ;;
  *)
    icon=""
    label=""
    color=$MUTED
    drawing=off
    ;;
esac

if command -v sketchybar >/dev/null 2>&1; then
  sketchybar --set "$NAME" \
    icon="$icon" \
    label="$label" \
    icon.color="$color" \
    label.color="$color" \
    drawing="$drawing"
else
  [ -n "$icon$label" ] && printf '%s %s\n' "$icon" "$label"
fi
