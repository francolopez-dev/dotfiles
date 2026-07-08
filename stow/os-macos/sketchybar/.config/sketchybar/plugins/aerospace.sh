#!/bin/bash

# Focus state only; per-workspace colors are set in sketchybarrc via
# icon.color / icon.highlight_color (sketchybar has no per-item env vars).

workspace=${NAME#workspace.}
focused_workspace=${FOCUSED_WORKSPACE:-}

if [ -z "${focused_workspace}" ] && command -v aerospace >/dev/null 2>&1; then
  focused_workspace=$(aerospace list-workspaces --focused 2>/dev/null || true)
fi

if [ "${workspace}" = "${focused_workspace}" ]; then
  sketchybar --set "${NAME}" icon="" icon.highlight=on
else
  sketchybar --set "${NAME}" icon="" icon.highlight=off
fi
