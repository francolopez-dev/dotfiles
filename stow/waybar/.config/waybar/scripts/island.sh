#!/usr/bin/env bash

json() {
  jq -cn --arg text "$1" --arg tooltip "$2" --arg class "$3" \
    '{text: $text, tooltip: $tooltip, class: $class}'
}

if pgrep -f '^gpu-screen-recorder' >/dev/null; then
  json '󰻂 recording' 'Screen recording is active' 'recording'
  exit 0
fi

if command -v playerctl >/dev/null 2>&1; then
  status=$(playerctl status 2>/dev/null || true)

  if [[ $status == "Playing" || $status == "Paused" ]]; then
    artist=$(playerctl metadata artist 2>/dev/null || true)
    title=$(playerctl metadata title 2>/dev/null || true)

    if [[ -n $artist && -n $title ]]; then
      label="$artist - $title"
    elif [[ -n $title ]]; then
      label="$title"
    else
      label="media"
    fi

    if ((${#label} > 56)); then
      label="${label:0:53}..."
    fi

    if [[ $status == "Playing" ]]; then
      json "󰎈 $label" "$label" 'playing'
    else
      json "󰏤 $label" "$label" 'paused'
    fi
    exit 0
  fi
fi

json '' '' 'idle'
