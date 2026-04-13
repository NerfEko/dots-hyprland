#!/usr/bin/env python3
from __future__ import annotations

import argparse
from datetime import datetime, timezone
from pathlib import Path

from theme_catalog import build_catalog_from_directory, write_catalog


def main() -> int:
    parser = argparse.ArgumentParser(description="Import Ghostty themes into a Quickshell-native catalog")
    parser.add_argument(
        "--source-dir",
        default="/usr/share/ghostty/themes",
        help="Directory containing Ghostty theme files",
    )
    parser.add_argument(
        "--output",
        default=str(Path(__file__).resolve().parents[2] / "assets/themes/ghostty/catalog.json"),
        help="Output catalog JSON path",
    )
    args = parser.parse_args()

    source_dir = Path(args.source_dir).expanduser().resolve()
    output_path = Path(args.output).expanduser().resolve()

    if not source_dir.is_dir():
        parser.error(f"Ghostty theme directory not found: {source_dir}")

    catalog = build_catalog_from_directory(source_dir)
    catalog["generatedAt"] = datetime.now(timezone.utc).isoformat()
    write_catalog(catalog, output_path)
    print(f"Imported {catalog['themeCount']} themes into {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
