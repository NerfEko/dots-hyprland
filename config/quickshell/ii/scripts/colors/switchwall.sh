#!/usr/bin/env bash

QUICKSHELL_CONFIG_NAME="ii"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
CONFIG_DIR="$XDG_CONFIG_HOME/quickshell/$QUICKSHELL_CONFIG_NAME"
CACHE_DIR="$XDG_CACHE_HOME/quickshell"
STATE_DIR="$XDG_STATE_HOME/quickshell"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_CONFIG_FILE="$XDG_CONFIG_HOME/illogical-impulse/config.json"
MATUGEN_DIR="$XDG_CONFIG_HOME/matugen"
terminalscheme="$SCRIPT_DIR/terminal/scheme-base.json"
IMPORTED_THEME_CATALOG="$CONFIG_DIR/assets/themes/ghostty/catalog.json"
THEME_IMPORTER="$SCRIPT_DIR/import_ghostty_themes.py"
THEME_MATCHER="$SCRIPT_DIR/match_imported_theme.py"
APPLIED_THEME_SOURCE="legacy"
APPLIED_IMPORTED_THEME_ID=""

handle_kde_material_you_colors() {
    # Check if Qt app theming is enabled in config
    if [ -f "$SHELL_CONFIG_FILE" ]; then
        enable_qt_apps=$(jq -r '.appearance.wallpaperTheming.enableQtApps' "$SHELL_CONFIG_FILE")
        if [ "$enable_qt_apps" == "false" ]; then
            return
        fi
    fi

    # Map $type_flag to allowed scheme variants for kde-material-you-colors-wrapper.sh
    local kde_scheme_variant=""
    case "$type_flag" in
        scheme-content|scheme-expressive|scheme-fidelity|scheme-fruit-salad|scheme-monochrome|scheme-neutral|scheme-rainbow|scheme-tonal-spot)
            kde_scheme_variant="$type_flag"
            ;;
        *)
            kde_scheme_variant="scheme-tonal-spot" # default
            ;;
    esac
    "$XDG_CONFIG_HOME"/matugen/templates/kde/kde-material-you-colors-wrapper.sh --scheme-variant "$kde_scheme_variant"
}

pre_process() {
    local mode_flag="$1"
    # Set GNOME color-scheme if mode_flag is dark or light
    if [[ "$mode_flag" == "dark" ]]; then
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
        gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark'
    elif [[ "$mode_flag" == "light" ]]; then
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
        gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3'
    fi

    if [ ! -d "$CACHE_DIR"/user/generated ]; then
        mkdir -p "$CACHE_DIR"/user/generated
    fi
}

post_process() {
    local screen_width="$1"
    local screen_height="$2"
    local wallpaper_path="$3"

    if [[ "$APPLIED_THEME_SOURCE" != "imported" ]]; then
        handle_kde_material_you_colors &
    fi
    "$SCRIPT_DIR/code/material-code-set-color.sh" &
}

check_and_prompt_upscale() {
    local img="$1"
    min_width_desired="$(hyprctl monitors -j | jq '([.[].width] | max)' | xargs)" # max monitor width
    min_height_desired="$(hyprctl monitors -j | jq '([.[].height] | max)' | xargs)" # max monitor height

    if command -v identify &>/dev/null && [ -f "$img" ]; then
        local img_width img_height
        if is_video "$img"; then # Not check resolution for videos, just let em pass
            img_width=$min_width_desired
            img_height=$min_height_desired
        else
            img_width=$(identify -format "%w" "$img" 2>/dev/null)
            img_height=$(identify -format "%h" "$img" 2>/dev/null)
        fi
        if [[ "$img_width" -lt "$min_width_desired" || "$img_height" -lt "$min_height_desired" ]]; then
            action=$(notify-send "Upscale?" \
                "Image resolution (${img_width}x${img_height}) is lower than screen resolution (${min_width_desired}x${min_height_desired})" \
                -A "open_upscayl=Open Upscayl"\
                -a "Wallpaper switcher")
            if [[ "$action" == "open_upscayl" ]]; then
                if command -v upscayl &>/dev/null; then
                    nohup upscayl > /dev/null 2>&1 &
                else
                    action2=$(notify-send \
                        -a "Wallpaper switcher" \
                        -c "im.error" \
                        -A "install_upscayl=Install Upscayl (Arch)" \
                        "Install Upscayl?" \
                        "yay -S upscayl-bin")
                    if [[ "$action2" == "install_upscayl" ]]; then
                        kitty -1 yay -S upscayl-bin
                        if command -v upscayl &>/dev/null; then
                            nohup upscayl > /dev/null 2>&1 &
                        fi
                    fi
                fi
            fi
        fi
    fi
}

CUSTOM_DIR="$XDG_CONFIG_HOME/hypr/custom"
RESTORE_SCRIPT_DIR="$CUSTOM_DIR/scripts"
RESTORE_SCRIPT="$RESTORE_SCRIPT_DIR/__restore_video_wallpaper.sh"
THUMBNAIL_DIR="$RESTORE_SCRIPT_DIR/mpvpaper_thumbnails"
VIDEO_OPTS="no-audio loop hwdec=auto scale=bilinear interpolation=no video-sync=display-resample panscan=1.0 video-scale-x=1.0 video-scale-y=1.0 video-align-x=0.5 video-align-y=0.5 load-scripts=no"

is_video() {
    local extension="${1##*.}"
    [[ "$extension" == "mp4" || "$extension" == "webm" || "$extension" == "mkv" || "$extension" == "avi" || "$extension" == "mov" ]] && return 0 || return 1
}

kill_existing_mpvpaper() {
    pkill -f -9 mpvpaper || true
}

create_restore_script() {
    local video_path=$1
    cat > "$RESTORE_SCRIPT.tmp" << EOF
#!/bin/bash
# Generated by switchwall.sh - Don't modify it by yourself.
# Time: $(date)

pkill -f -9 mpvpaper

for monitor in \$(hyprctl monitors -j | jq -r '.[] | .name'); do
    mpvpaper -o "$VIDEO_OPTS" "\$monitor" "$video_path" &
    sleep 0.1
done
EOF
    mv "$RESTORE_SCRIPT.tmp" "$RESTORE_SCRIPT"
    chmod +x "$RESTORE_SCRIPT"
}

remove_restore() {
    cat > "$RESTORE_SCRIPT.tmp" << EOF
#!/bin/bash
# The content of this script will be generated by switchwall.sh - Don't modify it by yourself.
EOF
    mv "$RESTORE_SCRIPT.tmp" "$RESTORE_SCRIPT"
}

set_wallpaper_path() {
    local path="$1"
    if [ -f "$SHELL_CONFIG_FILE" ]; then
        jq --arg path "$path" '.background.wallpaperPath = $path' "$SHELL_CONFIG_FILE" > "$SHELL_CONFIG_FILE.tmp" && mv "$SHELL_CONFIG_FILE.tmp" "$SHELL_CONFIG_FILE"
    fi
}

set_thumbnail_path() {
    local path="$1"
    if [ -f "$SHELL_CONFIG_FILE" ]; then
        jq --arg path "$path" '.background.thumbnailPath = $path' "$SHELL_CONFIG_FILE" > "$SHELL_CONFIG_FILE.tmp" && mv "$SHELL_CONFIG_FILE.tmp" "$SHELL_CONFIG_FILE"
    fi
}

get_type_from_config() {
    jq -r '.appearance.palette.type // "auto"' "$SHELL_CONFIG_FILE" 2>/dev/null || echo "auto"
}

get_accent_color_from_config() {
    jq -r '.appearance.palette.accentColor // ""' "$SHELL_CONFIG_FILE" 2>/dev/null || echo ""
}

set_accent_color() {
    local color="$1"
    jq --arg color "$color" '.appearance.palette.accentColor = $color' "$SHELL_CONFIG_FILE" > "$SHELL_CONFIG_FILE.tmp" && mv "$SHELL_CONFIG_FILE.tmp" "$SHELL_CONFIG_FILE"
}

get_theme_mode_from_config() {
    jq -r '.appearance.theme.mode // "legacy-palette"' "$SHELL_CONFIG_FILE" 2>/dev/null || echo "legacy-palette"
}

get_imported_theme_id_from_config() {
    jq -r '.appearance.theme.selectedId // "dracula"' "$SHELL_CONFIG_FILE" 2>/dev/null || echo "dracula"
}

get_resolved_theme_id_from_config() {
    jq -r '.appearance.theme.resolvedId // ""' "$SHELL_CONFIG_FILE" 2>/dev/null || echo ""
}

set_resolved_theme_id() {
    local theme_id="$1"
    if [ -f "$SHELL_CONFIG_FILE" ]; then
        jq --arg theme_id "$theme_id" '.appearance.theme.resolvedId = $theme_id' "$SHELL_CONFIG_FILE" > "$SHELL_CONFIG_FILE.tmp" && mv "$SHELL_CONFIG_FILE.tmp" "$SHELL_CONFIG_FILE"
    fi
}

ensure_imported_theme_catalog() {
    if [[ -f "$IMPORTED_THEME_CATALOG" ]]; then
        return 0
    fi

    mkdir -p "$(dirname "$IMPORTED_THEME_CATALOG")"
    python3 "$THEME_IMPORTER" --output "$IMPORTED_THEME_CATALOG"
}

detect_scheme_type_from_image() {
    local img="$1"
    source "$(eval echo $ILLOGICAL_IMPULSE_VIRTUAL_ENV)/bin/activate"
    "$SCRIPT_DIR"/scheme_for_image.py "$img" 2>/dev/null | tr -d '\n'
    deactivate
}

match_reactive_imported_theme() {
    local img="$1"
    [[ -n "$img" && -f "$img" ]] || return 1
    python3 "$THEME_MATCHER" "$img" --catalog "$IMPORTED_THEME_CATALOG" 2>/dev/null | tr -d '\n'
}

apply_imported_theme() {
    local theme_id="$1"
    local applied_id

    applied_id=$(python3 - "$IMPORTED_THEME_CATALOG" "$theme_id" "$STATE_DIR/user/generated/colors.json" "$STATE_DIR/user/generated/material_colors.scss" "$STATE_DIR/user/generated/color.txt" "$SCRIPT_DIR" <<'PY'
import json
import pathlib
import sys

catalog_path, requested_id, colors_path, scss_path, accent_path, script_dir = sys.argv[1:7]
sys.path.insert(0, script_dir)

from theme_catalog import catalog_to_scss

with open(catalog_path, "r", encoding="utf-8") as f:
    catalog = json.load(f)

themes = [theme for theme in catalog.get("themes", []) if "colors" in theme]
theme = next((theme for theme in themes if theme.get("id") == requested_id), None)
if theme is None and themes:
    theme = next((theme for theme in themes if theme.get("id") == "dracula"), None) or themes[0]
if theme is None:
    raise SystemExit(1)

colors = theme["colors"]
pathlib.Path(colors_path).parent.mkdir(parents=True, exist_ok=True)
with open(colors_path, "w", encoding="utf-8") as f:
    json.dump(colors, f, indent=2)
    f.write("\n")
with open(scss_path, "w", encoding="utf-8") as f:
    f.write(catalog_to_scss(colors))
with open(accent_path, "w", encoding="utf-8") as f:
    f.write((theme.get("accentColor") or colors.get("primary") or "") + "\n")
print(theme["id"])
PY
) || return 1

    APPLIED_THEME_SOURCE="imported"
    APPLIED_IMPORTED_THEME_ID="$applied_id"
    return 0
}

switch() {
    imgpath="$1"
    mode_flag="$2"
    type_flag="$3"
    preset_type="$type_flag"
    color_flag="$4"
    color="$5"
    thumbnail=""
    APPLIED_THEME_SOURCE="legacy"
    APPLIED_IMPORTED_THEME_ID=""

    # Start Gemini auto-categorization if enabled
    aiStylingEnabled=$(jq -r '.background.clock.cookie.aiStyling' "$SHELL_CONFIG_FILE")
    if [[ "$aiStylingEnabled" == "true" ]]; then
        "$SCRIPT_DIR/../ai/gemini-categorize-wallpaper.sh" "$imgpath" > "$STATE_DIR/user/generated/wallpaper/category.txt" &
    fi

    read scale screenx screeny screensizey < <(hyprctl monitors -j | jq '.[] | select(.focused) | .scale, .x, .y, .height' | xargs)
    cursorposx=$(hyprctl cursorpos -j | jq '.x' 2>/dev/null) || cursorposx=960
    cursorposx=$(bc <<< "scale=0; ($cursorposx - $screenx) * $scale / 1")
    cursorposy=$(hyprctl cursorpos -j | jq '.y' 2>/dev/null) || cursorposy=540
    cursorposy=$(bc <<< "scale=0; ($cursorposy - $screeny) * $scale / 1")
    cursorposy_inverted=$((screensizey - cursorposy))

    if [[ "$color_flag" == "1" ]]; then
        matugen_args=(color hex "$color")
        generate_colors_material_args=(--color "$color")
    else
        if [[ -z "$imgpath" ]]; then
            echo 'Aborted'
            exit 0
        fi

        check_and_prompt_upscale "$imgpath" &
        kill_existing_mpvpaper

        if is_video "$imgpath"; then
            mkdir -p "$THUMBNAIL_DIR"

            missing_deps=()
            if ! command -v mpvpaper &> /dev/null; then
                missing_deps+=("mpvpaper")
            fi
            if ! command -v ffmpeg &> /dev/null; then
                missing_deps+=("ffmpeg")
            fi
            if [ ${#missing_deps[@]} -gt 0 ]; then
                echo "Missing deps: ${missing_deps[*]}"
                echo "Arch: sudo pacman -S ${missing_deps[*]}"
                action=$(notify-send \
                    -a "Wallpaper switcher" \
                    -c "im.error" \
                    -A "install_arch=Install (Arch)" \
                    "Can't switch to video wallpaper" \
                    "Missing dependencies: ${missing_deps[*]}")
                if [[ "$action" == "install_arch" ]]; then
                    kitty -1 sudo pacman -S "${missing_deps[*]}"
                    if command -v mpvpaper &>/dev/null && command -v ffmpeg &>/dev/null; then
                        notify-send 'Wallpaper switcher' 'Alright, try again!' -a "Wallpaper switcher"
                    fi
                fi
                exit 0
            fi

            # Set wallpaper path
            set_wallpaper_path "$imgpath"

            # Set video wallpaper
            local video_path="$imgpath"
            monitors=$(hyprctl monitors -j | jq -r '.[] | .name')
            for monitor in $monitors; do
                mpvpaper -o "$VIDEO_OPTS" "$monitor" "$video_path" &
                sleep 0.1
            done

            # Extract first frame for color generation
            thumbnail="$THUMBNAIL_DIR/$(basename "$imgpath").jpg"
            ffmpeg -y -i "$imgpath" -vframes 1 "$thumbnail" 2>/dev/null

            # Set thumbnail path
            set_thumbnail_path "$thumbnail"

            if [ -f "$thumbnail" ]; then
                matugen_args=(image "$thumbnail")
                generate_colors_material_args=(--path "$thumbnail")
                create_restore_script "$video_path"
            else
                echo "Cannot create image to colorgen"
                remove_restore
                exit 1
            fi
        else
            matugen_args=(image "$imgpath")
            generate_colors_material_args=(--path "$imgpath")
            # Update wallpaper path in config
            set_wallpaper_path "$imgpath"
            remove_restore
        fi
    fi

    # Determine mode if not set
    if [[ -z "$mode_flag" ]]; then
        current_mode=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'")
        if [[ "$current_mode" == "prefer-dark" ]]; then
            mode_flag="dark"
        else
            mode_flag="light"
        fi
    fi

    local theme_mode
    theme_mode="$(get_theme_mode_from_config)"
    if [[ "$theme_mode" == "imported" || "$theme_mode" == "reactive-wallpaper" ]]; then
        local imported_theme_id=""
        local match_source="$imgpath"

        if [[ "$theme_mode" == "reactive-wallpaper" ]]; then
            if [[ -n "$thumbnail" && -f "$thumbnail" ]]; then
                match_source="$thumbnail"
            elif [[ -n "$match_source" && -f "$match_source" ]] && is_video "$match_source"; then
                match_source="$(jq -r '.background.thumbnailPath // empty' "$SHELL_CONFIG_FILE" 2>/dev/null || echo "")"
            fi

            if [[ -z "$match_source" || ! -f "$match_source" ]]; then
                match_source="$(jq -r '.background.thumbnailPath // empty' "$SHELL_CONFIG_FILE" 2>/dev/null || echo "")"
            fi
            if [[ -z "$match_source" || ! -f "$match_source" ]]; then
                match_source="$(jq -r '.background.wallpaperPath // empty' "$SHELL_CONFIG_FILE" 2>/dev/null || echo "")"
            fi
        fi

        if ensure_imported_theme_catalog; then
            if [[ "$theme_mode" == "reactive-wallpaper" ]]; then
                imported_theme_id="$(match_reactive_imported_theme "$match_source")"
                [[ -z "$imported_theme_id" ]] && imported_theme_id="$(get_resolved_theme_id_from_config)"
            else
                imported_theme_id="$(get_imported_theme_id_from_config)"
            fi
            [[ -z "$imported_theme_id" ]] && imported_theme_id="$(get_imported_theme_id_from_config)"

            if [ -f "$SHELL_CONFIG_FILE" ]; then
                enable_apps_shell=$(jq -r '.appearance.wallpaperTheming.enableAppsAndShell' "$SHELL_CONFIG_FILE")
                if [ "$enable_apps_shell" == "false" ]; then
                    echo "App and shell theming disabled, skipping imported theme application"
                    return
                fi
            fi

            pre_process "$mode_flag"
            if apply_imported_theme "$imported_theme_id"; then
                if [[ "$theme_mode" == "reactive-wallpaper" ]]; then
                    set_resolved_theme_id "$APPLIED_IMPORTED_THEME_ID"
                fi
                "$SCRIPT_DIR"/applycolor.sh
                max_width_desired="$(hyprctl monitors -j | jq '([.[].width] | min)' | xargs)"
                max_height_desired="$(hyprctl monitors -j | jq '([.[].height] | min)' | xargs)"
                post_process "$max_width_desired" "$max_height_desired" "$imgpath"
                return 0
            fi
        fi

        echo "[switchwall] Warning: Imported theme mode requested but no imported theme could be applied. Falling back to legacy palette flow." >&2
    fi

    # Fixed palette presets
    case "$type_flag" in
        dracula)
            type_flag="scheme-tonal-spot"
            matugen_args=(color hex "#BD93F9")
            generate_colors_material_args=(--color "#BD93F9")
            ;;
        dracula-plus)
            type_flag="scheme-fidelity"
            matugen_args=(color hex "#82AAFF")
            generate_colors_material_args=(--color "#82AAFF")
            ;;
    esac

    # enforce dark mode for terminal
    if [[ -n "$mode_flag" ]]; then
        matugen_args+=(--mode "$mode_flag")
        if [[ $(jq -r '.appearance.wallpaperTheming.terminalGenerationProps.forceDarkMode' "$SHELL_CONFIG_FILE") == "true" ]]; then
            generate_colors_material_args+=(--mode "dark")
        else
            generate_colors_material_args+=(--mode "$mode_flag")
        fi
    fi
    [[ -n "$type_flag" ]] && matugen_args+=(--type "$type_flag") && generate_colors_material_args+=(--scheme "$type_flag")
    generate_colors_material_args+=(--termscheme "$terminalscheme" --blend_bg_fg)
    generate_colors_material_args+=(--cache "$STATE_DIR/user/generated/color.txt")

    pre_process "$mode_flag"

    # Check if app and shell theming is enabled in config
    if [ -f "$SHELL_CONFIG_FILE" ]; then
        enable_apps_shell=$(jq -r '.appearance.wallpaperTheming.enableAppsAndShell' "$SHELL_CONFIG_FILE")
        if [ "$enable_apps_shell" == "false" ]; then
            echo "App and shell theming disabled, skipping matugen and color generation"
            return
        fi
    fi

    # Set harmony and related properties
    if [ -f "$SHELL_CONFIG_FILE" ]; then
        harmony=$(jq -r '.appearance.wallpaperTheming.terminalGenerationProps.harmony' "$SHELL_CONFIG_FILE")
        harmonize_threshold=$(jq -r '.appearance.wallpaperTheming.terminalGenerationProps.harmonizeThreshold' "$SHELL_CONFIG_FILE")
        term_fg_boost=$(jq -r '.appearance.wallpaperTheming.terminalGenerationProps.termFgBoost' "$SHELL_CONFIG_FILE")
        [[ "$harmony" != "null" && -n "$harmony" ]] && generate_colors_material_args+=(--harmony "$harmony")
        [[ "$harmonize_threshold" != "null" && -n "$harmonize_threshold" ]] && generate_colors_material_args+=(--harmonize_threshold "$harmonize_threshold")
        [[ "$term_fg_boost" != "null" && -n "$term_fg_boost" ]] && generate_colors_material_args+=(--term_fg_boost "$term_fg_boost")
    fi

    matugen "${matugen_args[@]}"
    source "$(eval echo $ILLOGICAL_IMPULSE_VIRTUAL_ENV)/bin/activate"
    python3 "$SCRIPT_DIR/generate_colors_material.py" "${generate_colors_material_args[@]}" \
        > "$STATE_DIR"/user/generated/material_colors.scss

    if [[ "$preset_type" == "dracula-plus" ]]; then
        python3 - "$STATE_DIR/user/generated/colors.json" "$STATE_DIR/user/generated/material_colors.scss" <<'PY'
import json
import re
import sys

json_path, scss_path = sys.argv[1:3]

json_updates = {
    "background": "#212121",
    "surface": "#212121",
    "surface_dim": "#212121",
    "surface_bright": "#2b2b2b",
    "surface_container_lowest": "#1b1b1b",
    "surface_container_low": "#252526",
    "surface_container": "#2d2d2d",
    "surface_container_high": "#333333",
    "surface_container_highest": "#3c3c3c",
    "on_background": "#f8f8f2",
    "on_surface": "#f8f8f2",
    "surface_variant": "#545454",
    "on_surface_variant": "#f8f8f2",
    "inverse_surface": "#f8f8f2",
    "inverse_on_surface": "#212121",
    "outline": "#545454",
    "outline_variant": "#444444",
    "primary": "#82aaff",
    "on_primary": "#212121",
    "primary_container": "#31405f",
    "on_primary_container": "#dce8ff",
    "secondary": "#c792ea",
    "on_secondary": "#212121",
    "secondary_container": "#4d3a63",
    "on_secondary_container": "#f2ddff",
    "tertiary": "#ffcb6b",
    "on_tertiary": "#212121",
    "tertiary_container": "#5c4720",
    "on_tertiary_container": "#ffe9b6",
    "error": "#ff5555",
    "on_error": "#212121",
    "error_container": "#5a2323",
    "on_error_container": "#ffd6d6",
    "surface_tint": "#82aaff"
}

scss_updates = {
    "background": "#212121",
    "surface": "#212121",
    "surfaceDim": "#212121",
    "surfaceBright": "#2b2b2b",
    "surfaceContainerLowest": "#1b1b1b",
    "surfaceContainerLow": "#252526",
    "surfaceContainer": "#2d2d2d",
    "surfaceContainerHigh": "#333333",
    "surfaceContainerHighest": "#3c3c3c",
    "onBackground": "#f8f8f2",
    "onSurface": "#f8f8f2",
    "surfaceVariant": "#545454",
    "onSurfaceVariant": "#f8f8f2",
    "inverseSurface": "#f8f8f2",
    "inverseOnSurface": "#212121",
    "outline": "#545454",
    "outlineVariant": "#444444",
    "primary": "#82AAFF",
    "onPrimary": "#212121",
    "primaryContainer": "#31405F",
    "onPrimaryContainer": "#DCE8FF",
    "secondary": "#C792EA",
    "onSecondary": "#212121",
    "secondaryContainer": "#4D3A63",
    "onSecondaryContainer": "#F2DDFF",
    "tertiary": "#FFCB6B",
    "onTertiary": "#212121",
    "tertiaryContainer": "#5C4720",
    "onTertiaryContainer": "#FFE9B6",
    "error": "#FF5555",
    "onError": "#212121",
    "errorContainer": "#5A2323",
    "onErrorContainer": "#FFD6D6",
    "surfaceTint": "#82AAFF",
    "term0": "#21222c",
    "term1": "#ff5555",
    "term2": "#50fa7b",
    "term3": "#ffcb6b",
    "term4": "#82aaff",
    "term5": "#c792ea",
    "term6": "#8be9fd",
    "term7": "#f8f8f2",
    "term8": "#545454",
    "term9": "#ff6e6e",
    "term10": "#69ff94",
    "term11": "#ffcb6b",
    "term12": "#d6acff",
    "term13": "#ff92df",
    "term14": "#a4ffff",
    "term15": "#f8f8f2"
}

with open(json_path, "r", encoding="utf-8") as f:
    data = json.load(f)
for key, value in json_updates.items():
    data[key] = value
with open(json_path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")

with open(scss_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

pattern = re.compile(r"^\$(\w+):\s*[^;]+;")
seen = set()
out = []
for line in lines:
    match = pattern.match(line)
    if match and match.group(1) in scss_updates:
        key = match.group(1)
        out.append(f"${key}: {scss_updates[key]};\n")
        seen.add(key)
    else:
        out.append(line)
for key, value in scss_updates.items():
    if key not in seen:
        out.append(f"${key}: {value};\n")
with open(scss_path, "w", encoding="utf-8") as f:
    f.writelines(out)
PY
    fi

    "$SCRIPT_DIR"/applycolor.sh
    deactivate

    # Pass screen width, height, and wallpaper path to post_process
    max_width_desired="$(hyprctl monitors -j | jq '([.[].width] | min)' | xargs)"
    max_height_desired="$(hyprctl monitors -j | jq '([.[].height] | min)' | xargs)"
    post_process "$max_width_desired" "$max_height_desired" "$imgpath"
}

main() {
    imgpath=""
    mode_flag=""
    type_flag=""
    color_flag=""
    color=""
    noswitch_flag=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --mode)
                mode_flag="$2"
                shift 2
                ;;
            --type)
                type_flag="$2"
                shift 2
                ;;
            --color)
                if [[ "$2" =~ ^#?[A-Fa-f0-9]{6}$ ]]; then
                    set_accent_color "$2"
                    shift 2
                elif [[ "$2" == "clear" ]]; then
                    set_accent_color ""
                    shift 2
                else
                    set_accent_color $(hyprpicker --no-fancy)
                    shift
                fi
                ;;
            --image)
                imgpath="$2"
                shift 2
                ;;
            --noswitch)
                noswitch_flag="1"
                imgpath=$(jq -r '.background.wallpaperPath' "$SHELL_CONFIG_FILE" 2>/dev/null || echo "")
                shift
                ;;
            *)
                if [[ -z "$imgpath" ]]; then
                    imgpath="$1"
                fi
                shift
                ;;
        esac
    done

    # If accentColor is set in config, use it
    config_color="$(get_accent_color_from_config)"
    if [[ "$config_color" =~ ^#?[A-Fa-f0-9]{6}$ ]]; then
        color_flag="1"
        color="$config_color"
    fi

    # If type_flag is not set, get it from config
    if [[ -z "$type_flag" ]]; then
        type_flag="$(get_type_from_config)"
    fi

    # Validate type_flag (allow 'auto' as well)
    allowed_types=(dracula dracula-plus scheme-content scheme-expressive scheme-fidelity scheme-fruit-salad scheme-monochrome scheme-neutral scheme-rainbow scheme-tonal-spot auto)
    valid_type=0
    for t in "${allowed_types[@]}"; do
        if [[ "$type_flag" == "$t" ]]; then
            valid_type=1
            break
        fi
    done
    if [[ $valid_type -eq 0 ]]; then
        echo "[switchwall.sh] Warning: Invalid type '$type_flag', defaulting to 'auto'" >&2
        type_flag="auto"
    fi

    # Only prompt for wallpaper if not using --color and not using --noswitch and no imgpath set
    if [[ -z "$imgpath" && -z "$color_flag" && -z "$noswitch_flag" ]]; then
        cd "$(xdg-user-dir PICTURES)/Wallpapers/showcase" 2>/dev/null || cd "$(xdg-user-dir PICTURES)/Wallpapers" 2>/dev/null || cd "$(xdg-user-dir PICTURES)" || return 1
        imgpath="$(kdialog --getopenfilename . --title 'Choose wallpaper')"
    fi

    # If type_flag is 'auto', detect scheme type from image (after imgpath is set)
    if [[ "$type_flag" == "auto" ]]; then
        if [[ -n "$imgpath" && -f "$imgpath" ]]; then
            detected_type="$(detect_scheme_type_from_image "$imgpath")"
            # Only use detected_type if it's valid
            valid_detected=0
            for t in "${allowed_types[@]}"; do
                if [[ "$detected_type" == "$t" && "$detected_type" != "auto" ]]; then
                    valid_detected=1
                    break
                fi
            done
            if [[ $valid_detected -eq 1 ]]; then
                type_flag="$detected_type"
            else
                echo "[switchwall] Warning: Could not auto-detect a valid scheme, defaulting to 'scheme-tonal-spot'" >&2
                type_flag="scheme-tonal-spot"
            fi
        else
            echo "[switchwall] Warning: No image to auto-detect scheme from, defaulting to 'scheme-tonal-spot'" >&2
            type_flag="scheme-tonal-spot"
        fi
    fi

    switch "$imgpath" "$mode_flag" "$type_flag" "$color_flag" "$color"
}

main "$@"
