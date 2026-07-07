#!/bin/bash

CONFIG_DIR="${HOME}/.config/sketchybar"

# shellcheck source=stow/os-macos/sketchybar/.config/sketchybar/colors.sh
. "${CONFIG_DIR}/colors.sh"

workspace=${NAME#workspace.}
focused_workspace=${FOCUSED_WORKSPACE:-}

if [ -z "${focused_workspace}" ] && command -v aerospace >/dev/null 2>&1; then
  focused_workspace=$(aerospace list-workspaces --focused 2>/dev/null || true)
fi

if [ "${workspace}" = "${focused_workspace}" ]; then
  sketchybar --set "${NAME}" icon="" icon.color="${CYAN}"
else
  sketchybar --set "${NAME}" icon="" icon.color="${DEFAULT_COLOR:-${IDLE}}"
fi
