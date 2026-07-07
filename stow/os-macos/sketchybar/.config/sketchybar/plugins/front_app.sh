#!/bin/bash

app_name=${INFO:-}

if [ -z "${app_name}" ]; then
  app_name="$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null || true)"
fi

sketchybar --set "${NAME}" label="${app_name}"
