#!/usr/bin/env python3
from __future__ import annotations

import colorsys
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

TERM_KEYS = [f"term{i}" for i in range(16)]
COLOR_KEYS = [
    "background",
    "on_background",
    "surface",
    "surface_dim",
    "surface_bright",
    "surface_container_lowest",
    "surface_container_low",
    "surface_container",
    "surface_container_high",
    "surface_container_highest",
    "on_surface",
    "surface_variant",
    "on_surface_variant",
    "inverse_surface",
    "inverse_on_surface",
    "outline",
    "outline_variant",
    "shadow",
    "scrim",
    "surface_tint",
    "primary",
    "on_primary",
    "primary_container",
    "on_primary_container",
    "inverse_primary",
    "secondary",
    "on_secondary",
    "secondary_container",
    "on_secondary_container",
    "tertiary",
    "on_tertiary",
    "tertiary_container",
    "on_tertiary_container",
    "error",
    "on_error",
    "error_container",
    "on_error_container",
    "primary_fixed",
    "primary_fixed_dim",
    "on_primary_fixed",
    "on_primary_fixed_variant",
    "secondary_fixed",
    "secondary_fixed_dim",
    "on_secondary_fixed",
    "on_secondary_fixed_variant",
    "tertiary_fixed",
    "tertiary_fixed_dim",
    "on_tertiary_fixed",
    "on_tertiary_fixed_variant",
    "success",
    "on_success",
    "success_container",
    "on_success_container",
    *TERM_KEYS,
]

HEX_RE = re.compile(r"^#?[0-9a-fA-F]{6}$")
PALETTE_RE = re.compile(r"^(\d+)=(#[0-9a-fA-F]{6})$")
KV_RE = re.compile(r"^([a-zA-Z0-9\-]+)\s*=\s*(.+?)\s*$")
SLUG_RE = re.compile(r"[^a-z0-9]+")


@dataclass
class ParsedGhosttyTheme:
    source_name: str
    source_path: str
    background: str
    foreground: str
    cursor_color: str
    cursor_text: str
    selection_background: str
    selection_foreground: str
    palette: list[str]


def normalize_hex(value: str, fallback: str | None = None) -> str:
    value = (value or "").strip()
    if HEX_RE.match(value):
        return value.lower() if value.startswith("#") else f"#{value.lower()}"
    if fallback is None:
        raise ValueError(f"Invalid color: {value!r}")
    return fallback


def hex_to_rgb(value: str) -> tuple[int, int, int]:
    value = normalize_hex(value)
    return tuple(int(value[i:i + 2], 16) for i in (1, 3, 5))


def rgb_to_hex(rgb: Iterable[float]) -> str:
    r, g, b = [max(0, min(255, int(round(channel)))) for channel in rgb]
    return f"#{r:02x}{g:02x}{b:02x}"


def blend(color_a: str, color_b: str, amount_to_b: float) -> str:
    amount_to_b = max(0.0, min(1.0, amount_to_b))
    ra, ga, ba = hex_to_rgb(color_a)
    rb, gb, bb = hex_to_rgb(color_b)
    return rgb_to_hex((
        ra + (rb - ra) * amount_to_b,
        ga + (gb - ga) * amount_to_b,
        ba + (bb - ba) * amount_to_b,
    ))


def relative_luminance(value: str) -> float:
    def channel(c: float) -> float:
        c = c / 255.0
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4

    r, g, b = hex_to_rgb(value)
    return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)


def contrast_ratio(color_a: str, color_b: str) -> float:
    l1 = relative_luminance(color_a)
    l2 = relative_luminance(color_b)
    lighter = max(l1, l2)
    darker = min(l1, l2)
    return (lighter + 0.05) / (darker + 0.05)


def best_contrast(on_dark: str, on_light: str, background: str) -> str:
    return on_dark if contrast_ratio(on_dark, background) >= contrast_ratio(on_light, background) else on_light


def slugify(name: str) -> str:
    lowered = name.strip().lower()
    lowered = SLUG_RE.sub("-", lowered)
    return lowered.strip("-") or "theme"


def theme_is_dark(background: str, foreground: str | None = None) -> bool:
    bg_l = relative_luminance(background)
    if foreground:
        fg_l = relative_luminance(foreground)
        return bg_l < fg_l
    return bg_l < 0.3


def ensure_palette(parsed: dict[str, str], background: str, foreground: str) -> list[str]:
    palette = [None] * 16
    for key, value in parsed.items():
        if key.startswith("palette["):
            idx = int(key[8:-1])
            if 0 <= idx < 16:
                palette[idx] = normalize_hex(value)

    defaults = [
        background,
        "#ff5555",
        "#50fa7b",
        "#f1fa8c",
        "#8be9fd",
        "#bd93f9",
        "#ff79c6",
        foreground,
        blend(background, foreground, 0.25),
        "#ff6e6e",
        "#69ff94",
        "#ffffa5",
        "#a4ffff",
        "#d6acff",
        "#ff92df",
        blend(foreground, background, 0.15),
    ]
    return [palette[i] or defaults[i] for i in range(16)]


def parse_ghostty_theme_text(text: str, source_name: str, source_path: str) -> ParsedGhosttyTheme:
    parsed: dict[str, str] = {}
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        match = KV_RE.match(line)
        if not match:
            continue
        key, value = match.groups()
        if key == "palette":
            palette_match = PALETTE_RE.match(value)
            if palette_match:
                index, color = palette_match.groups()
                parsed[f"palette[{index}]"] = color
            continue
        parsed[key] = value

    background = normalize_hex(parsed.get("background", "#1e1e2e"))
    foreground = normalize_hex(parsed.get("foreground", "#cdd6f4"))
    palette = ensure_palette(parsed, background, foreground)
    return ParsedGhosttyTheme(
        source_name=source_name,
        source_path=source_path,
        background=background,
        foreground=foreground,
        cursor_color=normalize_hex(parsed.get("cursor-color", foreground), foreground),
        cursor_text=normalize_hex(parsed.get("cursor-text", background), background),
        selection_background=normalize_hex(parsed.get("selection-background", palette[8]), palette[8]),
        selection_foreground=normalize_hex(parsed.get("selection-foreground", foreground), foreground),
        palette=palette,
    )


def parse_ghostty_theme_file(path: Path) -> ParsedGhosttyTheme:
    return parse_ghostty_theme_text(path.read_text(encoding="utf-8"), path.name, str(path))


def pick_accent(parsed: ParsedGhosttyTheme) -> str:
    candidates = [parsed.palette[i] for i in (4, 12, 5, 13, 6, 14, 3, 11, 2, 10, 1, 9)]
    def score(color: str) -> float:
        r, g, b = [c / 255.0 for c in hex_to_rgb(color)]
        h, s, v = colorsys.rgb_to_hsv(r, g, b)
        return s * 2.0 + v * 0.3 + abs(h - 0.58) * 0.01
    return max(candidates, key=score)


def container_color(accent: str, background: str, dark: bool, strength: float) -> str:
    if dark:
        return blend(background, accent, strength)
    return blend(accent, background, 0.78 - (strength * 0.25))


def fixed_color(accent: str, dark: bool, dim: bool = False) -> str:
    target = "#ffffff" if dark else "#000000"
    amount = 0.18 if dim else 0.08
    return blend(accent, target, amount)


def derive_semantic_colors(parsed: ParsedGhosttyTheme) -> dict[str, str]:
    dark = theme_is_dark(parsed.background, parsed.foreground)
    white = "#ffffff"
    black = "#000000"
    primary = pick_accent(parsed)
    secondary = parsed.palette[5]
    tertiary = parsed.palette[6]
    error = parsed.palette[1]
    success = parsed.palette[2]

    surface_dim = blend(parsed.background, black if dark else parsed.foreground, 0.06)
    surface_bright = blend(parsed.background, parsed.foreground, 0.12)
    surface_container_lowest = blend(parsed.background, black if dark else parsed.foreground, 0.10 if dark else 0.03)
    surface_container_low = blend(parsed.background, parsed.foreground, 0.05 if dark else 0.08)
    surface_container = blend(parsed.background, parsed.foreground, 0.09 if dark else 0.12)
    surface_container_high = blend(parsed.background, parsed.foreground, 0.13 if dark else 0.16)
    surface_container_highest = blend(parsed.background, parsed.foreground, 0.18 if dark else 0.21)
    outline = blend(parsed.selection_background, parsed.foreground, 0.28)
    outline_variant = blend(parsed.selection_background, parsed.background, 0.35)

    primary_container = container_color(primary, parsed.background, dark, 0.24)
    secondary_container = container_color(secondary, parsed.background, dark, 0.22)
    tertiary_container = container_color(tertiary, parsed.background, dark, 0.20)
    error_container = container_color(error, parsed.background, dark, 0.20)
    success_container = container_color(success, parsed.background, dark, 0.20)

    colors = {
        "background": parsed.background,
        "on_background": parsed.foreground,
        "surface": parsed.background,
        "surface_dim": surface_dim,
        "surface_bright": surface_bright,
        "surface_container_lowest": surface_container_lowest,
        "surface_container_low": surface_container_low,
        "surface_container": surface_container,
        "surface_container_high": surface_container_high,
        "surface_container_highest": surface_container_highest,
        "on_surface": parsed.foreground,
        "surface_variant": parsed.selection_background,
        "on_surface_variant": best_contrast(white, black, parsed.selection_background),
        "inverse_surface": parsed.foreground,
        "inverse_on_surface": parsed.background,
        "outline": outline,
        "outline_variant": outline_variant,
        "shadow": black,
        "scrim": black,
        "surface_tint": primary,
        "primary": primary,
        "on_primary": best_contrast(white, black, primary),
        "primary_container": primary_container,
        "on_primary_container": best_contrast(white, black, primary_container),
        "inverse_primary": blend(primary, parsed.background, 0.25 if dark else 0.15),
        "secondary": secondary,
        "on_secondary": best_contrast(white, black, secondary),
        "secondary_container": secondary_container,
        "on_secondary_container": best_contrast(white, black, secondary_container),
        "tertiary": tertiary,
        "on_tertiary": best_contrast(white, black, tertiary),
        "tertiary_container": tertiary_container,
        "on_tertiary_container": best_contrast(white, black, tertiary_container),
        "error": error,
        "on_error": best_contrast(white, black, error),
        "error_container": error_container,
        "on_error_container": best_contrast(white, black, error_container),
        "primary_fixed": fixed_color(primary, dark, dim=False),
        "primary_fixed_dim": fixed_color(primary, dark, dim=True),
        "on_primary_fixed": best_contrast(white, black, fixed_color(primary, dark, dim=False)),
        "on_primary_fixed_variant": best_contrast(white, black, fixed_color(primary, dark, dim=True)),
        "secondary_fixed": fixed_color(secondary, dark, dim=False),
        "secondary_fixed_dim": fixed_color(secondary, dark, dim=True),
        "on_secondary_fixed": best_contrast(white, black, fixed_color(secondary, dark, dim=False)),
        "on_secondary_fixed_variant": best_contrast(white, black, fixed_color(secondary, dark, dim=True)),
        "tertiary_fixed": fixed_color(tertiary, dark, dim=False),
        "tertiary_fixed_dim": fixed_color(tertiary, dark, dim=True),
        "on_tertiary_fixed": best_contrast(white, black, fixed_color(tertiary, dark, dim=False)),
        "on_tertiary_fixed_variant": best_contrast(white, black, fixed_color(tertiary, dark, dim=True)),
        "success": success,
        "on_success": best_contrast(white, black, success),
        "success_container": success_container,
        "on_success_container": best_contrast(white, black, success_container),
    }
    colors.update({f"term{i}": parsed.palette[i] for i in range(16)})
    return colors


def preview_colors(parsed: ParsedGhosttyTheme, colors: dict[str, str]) -> list[str]:
    return [
        parsed.background,
        colors["primary"],
        colors["secondary"],
        colors["tertiary"],
        parsed.foreground,
    ]


def build_theme_record(parsed: ParsedGhosttyTheme) -> dict:
    colors = derive_semantic_colors(parsed)
    record = {
        "id": slugify(parsed.source_name),
        "displayName": parsed.source_name,
        "sourceName": parsed.source_name,
        "sourcePath": parsed.source_path,
        "isDark": theme_is_dark(parsed.background, parsed.foreground),
        "background": parsed.background,
        "foreground": parsed.foreground,
        "selectionBackground": parsed.selection_background,
        "selectionForeground": parsed.selection_foreground,
        "cursorColor": parsed.cursor_color,
        "cursorText": parsed.cursor_text,
        "accentColor": colors["primary"],
        "previewColors": preview_colors(parsed, colors),
        "colors": colors,
    }
    return record


def build_catalog_from_directory(source_dir: Path) -> dict:
    themes = []
    for path in sorted(source_dir.iterdir(), key=lambda p: p.name.lower()):
        if not path.is_file():
            continue
        try:
            parsed = parse_ghostty_theme_file(path)
            themes.append(build_theme_record(parsed))
        except Exception as exc:  # pragma: no cover - importer logs failures
            themes.append({
                "id": slugify(path.name),
                "displayName": path.name,
                "sourceName": path.name,
                "sourcePath": str(path),
                "error": str(exc),
            })
    successful = [theme for theme in themes if "colors" in theme]
    return {
        "version": 1,
        "source": "ghostty-import",
        "sourceDir": str(source_dir),
        "themeCount": len(successful),
        "themes": successful,
    }


def catalog_to_scss(colors: dict[str, str]) -> str:
    lines = []
    for key in COLOR_KEYS:
        if key in colors:
            camel_key = re.sub(r"_([a-z])", lambda match: match.group(1).upper(), key)
            lines.append(f"${camel_key}: {normalize_hex(colors[key])};")
    return "\n".join(lines) + "\n"


def write_catalog(catalog: dict, output_path: Path) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(catalog, indent=2) + "\n", encoding="utf-8")
