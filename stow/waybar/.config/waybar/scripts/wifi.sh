#!/usr/bin/env bash

json() {
  jq -cn --arg text "$1" --arg tooltip "$2" --arg class "$3" \
    '{text: $text, tooltip: $tooltip, class: $class}'
}

ssid=''
signal=''

if command -v nmcli >/dev/null 2>&1 && nmcli general status >/dev/null 2>&1; then
  line=$(nmcli -t -f ACTIVE,SSID,SIGNAL dev wifi 2>/dev/null | awk -F: '$1 == "yes" { print; exit }')
  if [[ -n $line ]]; then
    IFS=: read -r _ ssid signal <<<"$line"
  fi
fi

if [[ -z $ssid ]] && command -v iw >/dev/null 2>&1; then
  iface=$(ip route show default 2>/dev/null | awk '$5 ~ /^(wl|wlan)/ { print $5; exit }')
  if [[ -n $iface ]]; then
    link=$(iw dev "$iface" link 2>/dev/null || true)
    ssid=$(awk -F': ' '/SSID:/ { print $2; exit }' <<<"$link")
    dbm=$(awk '/signal:/ { print int($2); exit }' <<<"$link")
    if [[ -n $dbm ]]; then
      signal=$((2 * (dbm + 100)))
      ((signal > 100)) && signal=100
      ((signal < 0)) && signal=0
    fi
  fi
fi

if [[ -z $ssid ]] && command -v iwctl >/dev/null 2>&1; then
  iface=$(iwctl station list 2>/dev/null | awk '$2 == "connected" { print $1; exit }')
  if [[ -n $iface ]]; then
    details=$(iwctl station "$iface" show 2>/dev/null || true)
    ssid=$(awk '/Connected network/ { sub(/.*Connected network[[:space:]]+/, ""); print; exit }' <<<"$details")
    dbm=$(awk '/AverageRSSI|RSSI/ { print int($(NF-1)); exit }' <<<"$details")
    if [[ -n $dbm ]]; then
      signal=$((2 * (dbm + 100)))
      ((signal > 100)) && signal=100
      ((signal < 0)) && signal=0
    fi
  fi
fi

if [[ -z $ssid ]]; then
  json '󰤮' 'Wi-Fi disconnected' 'off'
  exit 0
fi

signal=${signal:-0}

icon='󰤨'
class='active'
if ((signal < 25)); then
  icon='󰤟'
  class='weak'
elif ((signal < 55)); then
  icon='󰤢'
  class='mid'
elif ((signal < 80)); then
  icon='󰤥'
fi

json "$icon" "${ssid:-Wi-Fi}  ${signal}%" "$class"
