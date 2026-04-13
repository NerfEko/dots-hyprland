#!/usr/bin/env python3
from __future__ import annotations

import argparse
import colorsys
import json
from pathlib import Path

import numpy as np
from PIL import Image

from theme_catalog import hex_to_rgb, relative_luminance


def image_features(image_path: Path) -> dict[str, float]:
    with Image.open(image_path) as img:
        img = img.convert("RGB")
        img.thumbnail((128, 128))
        rgb = np.asarray(img, dtype=np.float32) / 255.0
        hsv = np.asarray(img.convert("HSV"), dtype=np.float32)

    hue = hsv[:, :, 0] / 255.0
    sat = hsv[:, :, 1] / 255.0
    val = hsv[:, :, 2] / 255.0

    weights = sat * np.clip(val, 0.2, 1.0)
    colored_mask = sat > 0.20
    if np.any(colored_mask):
        bins = np.linspace(0.0, 1.0, 37)
        hist, edges = np.histogram(hue[colored_mask], bins=bins, weights=weights[colored_mask])
        index = int(np.argmax(hist))
        dominant_hue = float((edges[index] + edges[index + 1]) / 2.0)
    else:
        dominant_hue = 0.0

    avg_rgb = rgb.reshape(-1, 3).mean(axis=0)
    _, avg_sat, _ = colorsys.rgb_to_hsv(*avg_rgb.tolist())
    avg_hex = "#%02x%02x%02x" % tuple(int(round(channel * 255)) for channel in avg_rgb)

    return {
        "isDark": relative_luminance(avg_hex) < 0.32,
        "backgroundLuma": relative_luminance(avg_hex),
        "dominantHue": dominant_hue,
        "saturation": float(avg_sat),
        "avgRgb": avg_rgb.tolist(),
    }


def hue_distance(a: float, b: float) -> float:
    diff = abs(a - b)
    return min(diff, 1.0 - diff)


def theme_features(theme: dict) -> dict[str, float]:
    accent = theme.get("accentColor") or (theme.get("previewColors") or [theme["background"]])[0]
    r, g, b = [channel / 255.0 for channel in hex_to_rgb(accent)]
    hue, sat, _ = colorsys.rgb_to_hsv(r, g, b)
    preview = theme.get("previewColors") or [theme["background"], theme["foreground"]]
    preview_rgbs = [np.array(hex_to_rgb(color), dtype=np.float32) / 255.0 for color in preview]
    return {
        "isDark": bool(theme.get("isDark", True)),
        "backgroundLuma": relative_luminance(theme["background"]),
        "accentHue": hue,
        "accentSaturation": sat,
        "previewRgbs": preview_rgbs,
    }


def score_theme(img: dict, tf: dict) -> float:
    dark_penalty = 0.0 if img["isDark"] == tf["isDark"] else 0.35
    bg_penalty = abs(img["backgroundLuma"] - tf["backgroundLuma"])
    hue_penalty = hue_distance(img["dominantHue"], tf["accentHue"])
    sat_penalty = abs(img["saturation"] - tf["accentSaturation"])
    avg_rgb = np.array(img["avgRgb"], dtype=np.float32)
    preview_penalty = min(float(np.linalg.norm(avg_rgb - preview_rgb)) for preview_rgb in tf["previewRgbs"])
    return dark_penalty * 1.9 + bg_penalty * 1.2 + hue_penalty * 1.0 + sat_penalty * 0.7 + preview_penalty * 0.8


def main() -> int:
    parser = argparse.ArgumentParser(description="Match a wallpaper to the closest imported theme")
    parser.add_argument("image", help="Wallpaper image path")
    parser.add_argument(
        "--catalog",
        default=str(Path(__file__).resolve().parents[2] / "assets/themes/ghostty/catalog.json"),
        help="Imported theme catalog path",
    )
    args = parser.parse_args()

    catalog_path = Path(args.catalog).expanduser().resolve()
    image_path = Path(args.image).expanduser().resolve()
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    themes = catalog.get("themes", [])
    if not themes:
        raise SystemExit("No imported themes found in catalog")

    img = image_features(image_path)
    scored = []
    for theme in themes:
        tf = theme_features(theme)
        scored.append((score_theme(img, tf), theme))
    scored.sort(key=lambda item: item[0])
    print(scored[0][1]["id"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
