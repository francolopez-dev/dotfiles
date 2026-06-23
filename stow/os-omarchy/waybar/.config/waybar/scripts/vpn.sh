#!/usr/bin/env bash

json() {
  jq -cn --arg text "$1" --arg tooltip "$2" --arg class "$3" \
    '{text: $text, tooltip: $tooltip, class: $class}'
}

if command -v tailscale >/dev/null 2>&1 && tailscale status >/dev/null 2>&1; then
  json '󰖂' 'Tailscale VPN active' 'active'
  exit 0
fi

if command -v nmcli >/dev/null 2>&1; then
  vpn=$(nmcli -t -f TYPE,STATE,CONNECTION dev status 2>/dev/null | awk -F: '$1 == "vpn" && $2 == "connected" { print $3; exit }')
  if [[ -n $vpn ]]; then
    json '󰖂' "$vpn active" 'active'
    exit 0
  fi
fi

json '󰦝' 'VPN inactive' 'off'
