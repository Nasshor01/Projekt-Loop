#!/usr/bin/env python3
"""Validate translations.csv (UI / labels) and data/dialogue/dialogue.csv (spoken lines).

Runtime loading:
  scripts/autoload/TranslationBootstrap.gd reads translations.csv on startup
  scripts/autoload/DialogueCatalog.gd reads data/dialogue/dialogue.csv on startup
  and both register translations via TranslationServer.add_translation().

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
DIALOGUE_PATH = ROOT / "data" / "dialogue" / "dialogue.csv"


def _validate_keys(path: Path, key_column: int = 0) -> tuple[list[str], int, list[str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        reader = csv.reader(handle)
        header = next(reader)
        keys: set[str] = set()
        duplicates: list[str] = []
        row_count = 0
        for row in reader:
            if not row or not row[key_column].strip() or row[key_column].strip().startswith("#"):
                continue
            key = row[key_column].strip()
            row_count += 1
            if key in keys:
                duplicates.append(key)
            keys.add(key)
        locales = [column.strip() for column in header[1:] if column.strip()]
        return locales, row_count, duplicates


def main() -> int:
    locales, row_count, duplicates = _validate_keys(CSV_PATH)
    print(f"UI locales: {', '.join(locales)}")
    print(f"UI keys: {row_count}")
    failed = False
    if duplicates:
        print("Duplicate UI keys:")
        for key in duplicates:
            print(f"  - {key}")
        failed = True

    _header, dialogue_count, dialogue_dupes = _validate_keys(DIALOGUE_PATH)
    print(f"Dialogue lines: {dialogue_count}")
    if dialogue_dupes:
        print("Duplicate dialogue ids:")
        for key in dialogue_dupes:
            print(f"  - {key}")
        failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
