#!/bin/bash

format=${DATE_FORMAT:-+%I:%M %p}

sketchybar --set "${NAME}" label="$(date "${format}")"
