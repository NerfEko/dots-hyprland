#!/bin/bash

# Script to toggle between ultrawide (3440x1440) and 16:9 mode
# for Dell AW3423DWF monitor
#
# 16:9 mode keeps the 3440x1440 resolution but switches the Hyprland workspace
# to 2560x1440 via keyword. Black bars are handled by the monitor's OSD
# aspect ratio setting - toggle that on the monitor itself when switching.

STATE_FILE="/tmp/hypr-display-mode"
ACTIVE_MONITOR=$(hyprctl monitors -j | jq -r '.[0].name')

if [[ -f "$STATE_FILE" ]]; then
    CURRENT_MODE=$(cat "$STATE_FILE")
else
    CURRENT_MODE="ultrawide"
    echo "ultrawide" > "$STATE_FILE"
fi

if [[ "$CURRENT_MODE" == "ultrawide" ]]; then
    hyprctl keyword monitor "${ACTIVE_MONITOR},2560x1440@165.00,0x0,1"
    echo "16:9" > "$STATE_FILE"
    notify-send "Display: 16:9 mode" "Resolution: 2560x1440\nAlso set your monitor OSD to 1:1 or Aspect Ratio to get black bars" -t 5000
else
    hyprctl keyword monitor "${ACTIVE_MONITOR},3440x1440@164.90,0x0,1"
    echo "ultrawide" > "$STATE_FILE"
    notify-send "Display: Ultrawide mode" "Resolution: 3440x1440" -t 3000
fi