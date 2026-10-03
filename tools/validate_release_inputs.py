#!/usr/bin/env python3
"""Validate a release checkout without needing archived art-authoring masters.

The complete development/source-art audit remains tests/validate_repo.py.
This focused check verifies referenced runtime art, required editor sources, and
matching Linux/Windows export filters. It does not replace the complete audit or
claim that a release build passed. Godot parsing, native selftests, and complete
development validation remain required by the existing release builder.
"""
from __future__ import annotations

import fnmatch
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
from source_material_inventory import EDITOR_SOURCE_PREFIXES, SOURCE_METADATA_KEYS, export_filters, references
from check_source_material_tracking import archived_media


def check_referenced_art(root: Path) -> tuple[list[str], int]:
    content, _, errors = references(root)
    failures = [str(error) for error in errors]
    checked = 0
    filters = export_filters(root)
    if filters["Linux Release"] != filters["Windows Release"]:
        failures.append("Linux and Windows release exclusions differ")
    for path, refs in content.items():
        if all(ref["key"] == "asset_root" for ref in refs):
            continue  # A resource namespace/directory, not a concrete art file.
        provenance = all(ref["key"] in SOURCE_METADATA_KEYS for ref in refs)
        excluded = all(any(fnmatch.fnmatchcase(path, p) or fnmatch.fnmatchcase(path.rstrip("/") + "/", p) for p in patterns) for patterns in filters.values())
        if provenance and not path.startswith(EDITOR_SOURCE_PREFIXES) and excluded:
            continue
        if provenance and archived_media(path):
            if not excluded:
                failures.append(f"Archived source is not excluded from both platforms: {path}")
            continue
        checked += 1
        if not (root / path).is_file():
            failures.append(f"Missing content art: {path}")
    # Only actual static resource loads are mandatory; arbitrary string literals
    # can include deliberate missing-path fixtures used to test UI fallbacks.
    loads = set()
    for folder in ("scripts", "scenes"):
        for script in (root / folder).rglob("*.gd"):
            loads.update(re.findall(r'''\b(?:preload|load)\(\s*["']res://(art/[^"']+)["']''', script.read_text(encoding="utf8")))
    for path in loads:
        if "%" in path or "{" in path or Path(path).suffix.lower() not in {".png", ".svg", ".jpg", ".webp", ".ogg", ".wav"}:
            continue
        checked += 1
        if not (root / path).is_file():
            failures.append(f"Missing live art literal: {path}")
    for prefix in EDITOR_SOURCE_PREFIXES:
        if not any((root / prefix).glob("*.png")):
            failures.append(f"Required editor source directory is empty: {prefix}")
    return failures, checked


def main() -> int:
    errors, checked = check_referenced_art(ROOT)
    print(json.dumps({"scope": "art references and platform exclusions only; not full release validation", "art_references_checked": checked, "errors": errors}, indent=2))
    return int(bool(errors))


if __name__ == "__main__":
    raise SystemExit(main())
