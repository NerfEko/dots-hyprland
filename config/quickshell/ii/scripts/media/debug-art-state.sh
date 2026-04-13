#!/usr/bin/env bash

set -euo pipefail

interval=0

if [[ "${1-}" == "--watch" ]]; then
    interval="${2:-1}"
fi

score_player() {
    local status="$1"
    local title="$2"
    local artist="$3"
    local album="$4"
    local art_url="$5"
    local score=0

    [[ "$status" == "Playing" ]] && ((score += 100))
    [[ -n "$title" ]] && ((score += 20))
    [[ -n "$artist" ]] && ((score += 15))
    [[ -n "$album" ]] && ((score += 10))
    [[ -n "$art_url" ]] && ((score += 15))

    printf '%s' "$score"
}

print_player() {
    local player="$1"
    local raw status title artist album art_url length score art_path art_exists art_hash art_size

    raw="$(playerctl -p "$player" metadata --format '{{status}}|{{xesam:title}}|{{xesam:artist}}|{{xesam:album}}|{{mpris:artUrl}}|{{mpris:length}}' 2>/dev/null || true)"
    IFS='|' read -r status title artist album art_url length <<< "$raw"

    art_path=""
    art_exists="no"
    art_hash=""
    art_size=""

    if [[ "$art_url" == file://* ]]; then
        art_path="${art_url#file://}"
        if [[ -f "$art_path" ]]; then
            art_exists="yes"
            art_hash="$(md5sum "$art_path" | awk '{print $1}')"
            art_size="$(stat -c '%s' "$art_path")"
        fi
    fi

    score="$(score_player "$status" "$title" "$artist" "$album" "$art_url")"

    printf 'player=%s\n' "$player"
    printf '  score=%s status=%s\n' "$score" "${status:-unknown}"
    printf '  title=%s\n' "${title:-}"
    printf '  artist=%s\n' "${artist:-}"
    printf '  album=%s\n' "${album:-}"
    printf '  art_url=%s\n' "${art_url:-}"
    if [[ -n "$art_path" ]]; then
        printf '  art_path=%s\n' "$art_path"
        printf '  art_exists=%s\n' "$art_exists"
        [[ -n "$art_size" ]] && printf '  art_size=%s\n' "$art_size"
        [[ -n "$art_hash" ]] && printf '  art_md5=%s\n' "$art_hash"
    fi
    printf '\n'

    printf '%s|%s\n' "$player" "$score" >> "${TMPDIR:-/tmp}/qs-media-debug-scores.$$"
}

run_once() {
    local players best_line best_player best_score

    rm -f "${TMPDIR:-/tmp}/qs-media-debug-scores.$$"
    mapfile -t players < <(playerctl -l 2>/dev/null || true)

    printf 'timestamp=%s\n\n' "$(date --iso-8601=seconds)"

    if [[ "${#players[@]}" -eq 0 ]]; then
        printf 'no players found\n'
        return
    fi

    for player in "${players[@]}"; do
        print_player "$player"
    done

    best_line="$(sort -t'|' -k2,2nr "${TMPDIR:-/tmp}/qs-media-debug-scores.$$" | head -n1)"
    IFS='|' read -r best_player best_score <<< "$best_line"
    printf 'selected_player=%s\nselected_score=%s\n' "$best_player" "$best_score"
}

trap 'rm -f "${TMPDIR:-/tmp}/qs-media-debug-scores.$$"' EXIT

if [[ "$interval" == 0 ]]; then
    run_once
else
    while true; do
        clear
        run_once
        sleep "$interval"
    done
fi
