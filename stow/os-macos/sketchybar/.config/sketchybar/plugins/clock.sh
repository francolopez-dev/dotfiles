#!/bin/bash

# Shared by the "date" and "clock" items; sketchybar has no per-item env
# vars, so the format is derived from the item name.
case "${NAME}" in
  date) format='+%b%d' ;;
  *) format='+%I:%M %p' ;;
esac

sketchybar --set "${NAME}" label="$(date "${format}")"
