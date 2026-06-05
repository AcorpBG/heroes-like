#!/usr/bin/env python3
"""Enrich the compiled H3MapEd object catalog with DEF/MSK object fields.

H3MapEd parses `objects.txt`/`objtmplt.txt` into 0x4c object rows, then
copies six DEF/MSK-derived fields into row offsets +0x34..+0x48. Native RMG
needs those fields for source-backed decorative post-stamp behavior; projecting
them from final masks is not equivalent.

This tool reads local extracted HoMM3 `.msk` files as evidence, but writes only
numeric metadata into the compiled catalog. It does not copy raw assets.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


DEFAULT_EMBEDDED = Path("src/gdextension/src/h3maped_small_rmg_embedded_data.cpp")
DEFAULT_MSK_DIRS = [
    Path("/root/.openclaw/workspace/tasks/10184/artifacts/homm3-lod-extract/output/h3sprite/raw"),
    Path("/root/.openclaw/workspace/tasks/10184/artifacts/homm3-lod-extract/output/h3ab_spr/raw"),
]

OBJECT_CATALOG_PATTERN = re.compile(
    r'(static constexpr char OBJECT_CATALOG_BY_TYPE_JSON\[\] = R"RMG1\()'
    r"(.*?)"
    r'(\)RMG1";)',
    re.DOTALL,
)


def read_msk_fields(def_name: str, msk_dirs: list[Path]) -> dict[str, Any]:
    stem = Path(def_name).stem.lower()
    candidates = [f"{stem}.msk", "default.msk"]
    for candidate in candidates:
        for msk_dir in msk_dirs:
            path = msk_dir / candidate
            if not path.exists():
                continue
            blob = path.read_bytes()
            if len(blob) != 14:
                raise ValueError(f"{path}: expected 14-byte .msk record, got {len(blob)}")
            return {
                "h3maped_msk_source_name": candidate,
                "h3maped_msk_source_status": "exact_def_msk" if candidate != "default.msk" else "default_msk_fallback",
                "h3maped_msk_width_0x34": blob[0],
                "h3maped_msk_height_0x38": blob[1],
                "h3maped_msk_mask_a_0x3c_0x40": int.from_bytes(blob[2:8], "little"),
                "h3maped_msk_mask_b_0x44_0x48": int.from_bytes(blob[8:14], "little"),
            }
    raise FileNotFoundError(f"no .msk or default.msk found for {def_name}")


def load_embedded_catalog(path: Path) -> tuple[str, dict[str, Any]]:
    text = path.read_text(encoding="utf-8")
    match = OBJECT_CATALOG_PATTERN.search(text)
    if not match:
        raise ValueError(f"{path}: OBJECT_CATALOG_BY_TYPE_JSON block not found")
    return text, json.loads(match.group(2))


def enrich_catalog(catalog: dict[str, Any], msk_dirs: list[Path]) -> dict[str, int]:
    stats = {
        "templates": 0,
        "exact_def_msk": 0,
        "default_msk_fallback": 0,
        "missing": 0,
    }
    for type_record in catalog.get("types", []):
        for template in type_record.get("templates", []):
            stats["templates"] += 1
            def_name = str(template.get("def_name", ""))
            try:
                fields = read_msk_fields(def_name, msk_dirs)
            except FileNotFoundError:
                stats["missing"] += 1
                template["h3maped_msk_source_status"] = "missing_msk"
                continue
            template.update(fields)
            stats[fields["h3maped_msk_source_status"]] += 1
    catalog.setdefault("inputs", {})["msk_fields"] = "compiled-redacted-source"
    catalog.setdefault("totals", {})["msk_field_templates"] = stats["templates"] - stats["missing"]
    catalog["msk_field_schema"] = {
        "source": "h3maped.exe 0x4903e8 copies .msk fields into parsed object row +0x34..+0x48",
        "record_size_bytes": 14,
        "fields": [
            "h3maped_msk_width_0x34",
            "h3maped_msk_height_0x38",
            "h3maped_msk_mask_a_0x3c_0x40",
            "h3maped_msk_mask_b_0x44_0x48",
        ],
    }
    return stats


def replace_embedded_catalog(original_text: str, catalog: dict[str, Any]) -> str:
    rendered = json.dumps(catalog, indent=2, sort_keys=True) + "\n"
    return OBJECT_CATALOG_PATTERN.sub(
        lambda match: f"{match.group(1)}{rendered}{match.group(3)}",
        original_text,
        count=1,
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--embedded", type=Path, default=DEFAULT_EMBEDDED)
    parser.add_argument("--msk-dir", type=Path, action="append", default=[])
    parser.add_argument("--write", action="store_true", help="Rewrite the compiled object catalog JSON block")
    parser.add_argument("--report-json", type=Path, help="Optional path for a JSON audit report")
    args = parser.parse_args()

    msk_dirs = [path.resolve() for path in (args.msk_dir or DEFAULT_MSK_DIRS)]
    missing_dirs = [str(path) for path in msk_dirs if not path.exists()]
    if missing_dirs:
        raise FileNotFoundError(f"missing .msk directories: {missing_dirs}")

    original_text, catalog = load_embedded_catalog(args.embedded)
    stats = enrich_catalog(catalog, msk_dirs)
    report = {
        "embedded": str(args.embedded),
        "msk_dirs": [str(path) for path in msk_dirs],
        "stats": stats,
        "write": bool(args.write),
    }
    if args.report_json:
        args.report_json.parent.mkdir(parents=True, exist_ok=True)
        args.report_json.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    if args.write:
        args.embedded.write_text(replace_embedded_catalog(original_text, catalog), encoding="utf-8")
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
