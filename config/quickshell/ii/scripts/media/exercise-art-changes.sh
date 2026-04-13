#!/usr/bin/env bash

set -euo pipefail

player="${1:-sidra}"
steps="${2:-3}"
delay="${3:-2}"
restore="yes"

snapshot() {
    local raw status title artist album art_url art_path art_hash
    raw="$(playerctl -p "$player" metadata --format '{{status}}|{{xesam:title}}|{{xesam:artist}}|{{xesam:album}}|{{mpris:artUrl}}' 2>/dev/null || true)"
    IFS='|' read -r status title artist album art_url <<< "$raw"
    art_path=""
    art_hash=""
    if [[ "$art_url" == file://* ]]; then
        art_path="${art_url#file://}"
        [[ -f "$art_path" ]] && art_hash="$(md5sum "$art_path" | awk '{print $1}')"
    fi

    printf 'status=%s\n' "${status:-unknown}"
    printf 'title=%s\n' "${title:-}"
    printf 'artist=%s\n' "${artist:-}"
    printf 'album=%s\n' "${album:-}"
    printf 'art_url=%s\n' "${art_url:-}"
    [[ -n "$art_path" ]] && printf 'art_path=%s\n' "$art_path"
    [[ -n "$art_hash" ]] && printf 'art_md5=%s\n' "$art_hash"
}

if [[ "$player" == "--help" ]]; then
    printf 'usage: %s [player] [steps] [delay-seconds]\n' "$0"
    exit 0
fi

printf 'player=%s steps=%s delay=%s\n\n' "$player" "$steps" "$delay"
printf 'before\n'
snapshot
printf '\n'

for ((i = 1; i <= steps; i++)); do
    printf 'next_step=%s\n' "$i"
    playerctl -p "$player" next
    sleep "$delay"
    snapshot
    printf '\n'
done

if [[ "$restore" == "yes" ]]; then
    for ((i = 1; i <= steps; i++)); do
        playerctl -p "$player" previous
        sleep "$delay"
    done

    printf 'restored\n'
    snapshot
    printf '\n'
fi
