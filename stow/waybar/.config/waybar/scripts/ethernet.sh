#!/usr/bin/env bash

json() {
  jq -cn --arg text "$1" --arg tooltip "$2" --arg class "$3" \
    '{text: $text, tooltip: $tooltip, class: $class}'
}

if ! command -v nmcli >/dev/null 2>&1; then
  json '󰈂' 'nmcli not found' 'off'
  exit 0
fi

line=$(nmcli -t -f TYPE,STATE,DEVICE,CONNECTION dev status 2>/dev/null | awk -F: '$1 == "ethernet" && $2 == "connected" { print; exit }')

if [[ -z $line ]]; then
  json '󰈂' 'Ethernet disconnected' 'off'
  exit 0
fi

IFS=: read -r _ _ device connection <<<"$line"
json '󰈀' "${connection:-Ethernet}  ${device:-wired}" 'active'
