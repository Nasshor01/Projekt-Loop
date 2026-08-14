#!/usr/bin/env python3
"""Validate translations.csv (source of truth for in-game text).

Runtime loading:
  scripts/autoload/TranslationBootstrap.gd reads translations.csv on startup
  and registers translations via TranslationServer.add_translation().

Optional Godot editor step:
  Select translations.csv -> Import dock -> Reimport
  to refresh translations.en.translation / translations.cs.translation binaries.
"""

from __future__ import annotations

import csv
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / "translations.csv"


def main() -> int:
    with CSV_PATH.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.reader(handle)
        header = next(reader)
        locales = [column.strip() for column in header[1:] if column.strip()]
        keys: set[str] = set()
        duplicates: list[str] = []
        row_count = 0

        for row in reader:
            if not row or not row[0].strip():
                continue
            key = row[0].strip()
            row_count += 1
            if key in keys:
                duplicates.append(key)
            keys.add(key)

    print(f"Locales: {', '.join(locales)}")
    print(f"Keys: {len(keys)} ({row_count} rows)")
    if duplicates:
        print("Duplicate keys:")
        for key in duplicates:
            print(f"  - {key}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
