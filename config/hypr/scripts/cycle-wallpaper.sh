#!/bin/bash
WALLPAPER_DIR="$HOME/Pictures/wallpapers"
CYCLE_INTERVAL=300
MONITOR="DP-1"
CONFIG_FILE="$HOME/.config/illogical-impulse/config.json"
INDEX_FILE="$HOME/.cache/wallpaper_index"

get_wallpapers() {
    wallpapers=("$WALLPAPER_DIR"/*)
    total=${#wallpapers[@]}
}

load_index() {
    if [ -f "$INDEX_FILE" ]; then
        index=$(cat "$INDEX_FILE")
    else
        index=0
    fi
}

save_index() {
    echo "$index" > "$INDEX_FILE"
}

set_wallpaper() {
    local path="$1"
    pkill swaybg 2>/dev/null
    sleep 0.1
    swaybg -o "$MONITOR" -i "$path" -m fill &
    if [ -f "$CONFIG_FILE" ]; then
        jq --arg path "$path" '.background.wallpaperPath = $path' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
    fi
    echo "$(date) - Setting wallpaper: $path"
}

get_wallpapers
if [ $total -eq 0 ]; then
    echo "No wallpapers found in $WALLPAPER_DIR"
    exit 1
fi

load_index

while true; do
    get_wallpapers
    if [ $total -eq 0 ]; then
        sleep 60
        continue
    fi
    
    if [ "$index" -ge "$total" ]; then
        index=0
    fi
    
    set_wallpaper "${wallpapers[$index]}"
    save_index
    
    sleep $CYCLE_INTERVAL
done
