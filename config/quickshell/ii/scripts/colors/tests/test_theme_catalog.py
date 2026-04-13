#!/usr/bin/env python3
from __future__ import annotations

import unittest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from theme_catalog import build_theme_record, catalog_to_scss, parse_ghostty_theme_text  # noqa: E402


DRACULA_SAMPLE = """\
palette = 0=#21222c
palette = 1=#ff5555
palette = 2=#50fa7b
palette = 3=#f1fa8c
palette = 4=#bd93f9
palette = 5=#ff79c6
palette = 6=#8be9fd
palette = 7=#f8f8f2
palette = 8=#6272a4
palette = 9=#ff6e6e
palette = 10=#69ff94
palette = 11=#ffffa5
palette = 12=#d6acff
palette = 13=#ff92df
palette = 14=#a4ffff
palette = 15=#ffffff
background = #282a36
foreground = #f8f8f2
cursor-color = #f8f8f2
cursor-text = #282a36
selection-background = #44475a
selection-foreground = #ffffff
"""

LIGHT_SAMPLE = """\
palette = 0=#241f31
palette = 1=#c01c28
palette = 2=#2ec27e
palette = 3=#e8b504
palette = 4=#1e78e4
palette = 5=#9841bb
palette = 6=#0ab9dc
palette = 7=#c0bfbc
palette = 8=#5e5c64
palette = 9=#ed333b
palette = 10=#4ad67c
palette = 11=#d2be36
palette = 12=#51a1ff
palette = 13=#c061cb
palette = 14=#4fd2fd
palette = 15=#f6f5f4
background = #ffffff
foreground = #000000
selection-background = #c0bfbc
selection-foreground = #000000
"""


class ThemeCatalogTests(unittest.TestCase):
    def test_builds_dark_theme_record(self) -> None:
        parsed = parse_ghostty_theme_text(DRACULA_SAMPLE, "Dracula", "/tmp/Dracula")
        record = build_theme_record(parsed)

        self.assertEqual(record["id"], "dracula")
        self.assertTrue(record["isDark"])
        self.assertEqual(record["colors"]["background"], "#282a36")
        self.assertEqual(record["colors"]["on_background"], "#f8f8f2")
        self.assertEqual(record["colors"]["term4"], "#bd93f9")
        self.assertEqual(len(record["previewColors"]), 5)

    def test_builds_light_theme_record(self) -> None:
        parsed = parse_ghostty_theme_text(LIGHT_SAMPLE, "Adwaita", "/tmp/Adwaita")
        record = build_theme_record(parsed)

        self.assertFalse(record["isDark"])
        self.assertEqual(record["colors"]["background"], "#ffffff")
        self.assertEqual(record["colors"]["on_background"], "#000000")
        self.assertIn("primary_container", record["colors"])
        self.assertIn("term15", record["colors"])

    def test_exports_scss_with_terminal_palette(self) -> None:
        parsed = parse_ghostty_theme_text(DRACULA_SAMPLE, "Dracula", "/tmp/Dracula")
        record = build_theme_record(parsed)
        scss = catalog_to_scss(record["colors"])

        self.assertIn("$background: #282a36;", scss)
        self.assertIn("$primaryContainer:", scss)
        self.assertIn("$term0: #21222c;", scss)
        self.assertIn("$term15: #ffffff;", scss)


if __name__ == "__main__":
    unittest.main()
