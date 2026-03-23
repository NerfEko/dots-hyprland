#!/bin/bash
# Safe OLED DPMS script for Dell AW3423DWF

case "$1" in
    "off")
        # Turn off display using multiple methods for reliability
        xset dpms force off 2>/dev/null || \
        hyprctl dispatch dpms off 2>/dev/null || \
        echo "Could not turn off display"
        ;;
    "on")
        # Turn on display
        xset dpms force on 2>/dev/null || \
        hyprctl dispatch dpms on 2>/dev/null || \
        echo "Could not turn on display"
        ;;
    *)
        echo "Usage: $0 {on|off}"
        exit 1
        ;;
esac