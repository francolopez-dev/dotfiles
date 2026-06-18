#!/usr/bin/env bash

json() {
  jq -cn --arg text "$1" --arg tooltip "$2" --arg class "$3" \
    '{text: $text, tooltip: $tooltip, class: $class}'
}

if ! command -v nvidia-smi >/dev/null 2>&1; then
  json '' 'nvidia-smi not found' 'unavailable'
  exit 0
fi

stats=$(nvidia-smi --query-gpu=utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv,noheader,nounits 2>/dev/null)
stats=${stats%%$'\n'*}

if [[ -z $stats ]]; then
  json '' 'GPU unavailable' 'unavailable'
  exit 0
fi

IFS=',' read -r util mem_used mem_total temp <<<"$stats"
util=${util// /}
mem_used=${mem_used// /}
mem_total=${mem_total// /}
temp=${temp// /}

mem_pct=$(awk -v used="$mem_used" -v total="$mem_total" 'BEGIN { if (total > 0) printf "%d", (used / total) * 100; else print 0 }')
mem_gb=$(awk -v used="$mem_used" 'BEGIN { printf "%.1f", used / 1024 }')
total_gb=$(awk -v total="$mem_total" 'BEGIN { printf "%.1f", total / 1024 }')

class='cool'
if ((temp >= 78 || util >= 85 || mem_pct >= 88)); then
  class='hot'
elif ((temp >= 65 || util >= 60 || mem_pct >= 70)); then
  class='warm'
fi

text="󰢮 ${util}% ${mem_pct}%"
tooltip="GPU ${util}%  VRAM ${mem_gb}/${total_gb}G  ${temp}C"

json "$text" "$tooltip" "$class"
