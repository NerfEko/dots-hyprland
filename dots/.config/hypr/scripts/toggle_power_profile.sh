#!/bin/bash

# Get current profile
CURRENT_PROFILE=$(powerprofilesctl get)

# Cycle through profiles: power-saver -> balanced -> performance -> power-saver
case "$CURRENT_PROFILE" in
    "power-saver")
        NEXT_PROFILE="balanced"
        ICON="battery-balanced-symbolic" # You might want to adjust icons based on your theme
        ;;
    "balanced")
        NEXT_PROFILE="performance"
        ICON="battery-level-100-charged-symbolic"
        ;;
    "performance")
        NEXT_PROFILE="power-saver"
        ICON="battery-level-10-symbolic"
        ;;
    *)
        NEXT_PROFILE="balanced"
        ICON="battery-balanced-symbolic"
        ;;
esac

# Set the new profile
powerprofilesctl set "$NEXT_PROFILE"

# Notify
notify-send -i "$ICON" "Power Profile" "Switched to $NEXT_PROFILE"
