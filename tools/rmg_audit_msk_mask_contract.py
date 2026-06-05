#!/usr/bin/env python3
"""Audit H3MapEd object MSK bitfields against parsed object masks.

This is a recovery aid for the native RMG decorative filler path. H3MapEd's
0x41e951 helper reads a parsed object-row bitset at object+0x04, while 0x49e700
uses object +0x34/+0x38 as local scan bounds. This script does not tune density
or validate final maps; it checks which embedded object MSK field and bit
orientation actually lines up with the parsed objects.txt pass/action masks.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any, Callable


DEFAULT_EMBEDDED = Path("src/gdextension/src/h3maped_small_rmg_embedded_data.cpp")
OBJECT_CATALOG_PATTERN = re.compile(
    r'static constexpr char OBJECT_CATALOG_BY_TYPE_JSON\[\] = R"RMG1\((.*?)\)RMG1";',
    re.DOTALL,
)
MASK_COLUMNS = 8
MASK_ROWS = 6


def load_catalog(path: Path) -> dict[str, Any]:
    match = OBJECT_CATALOG_PATTERN.search(path.read_text(encoding="utf-8"))
    if not match:
        raise ValueError(f"{path}: OBJECT_CATALOG_BY_TYPE_JSON block not found")
    return json.loads(match.group(1))


def text_mask_points(mask: str, want_set_bits: bool) -> set[tuple[int, int]]:
    points: set[tuple[int, int]] = set()
    if len(mask) < MASK_COLUMNS * MASK_ROWS:
        return points
    for y in range(MASK_ROWS):
        for x in range(MASK_COLUMNS):
            if (mask[y * MASK_COLUMNS + x] == "1") == want_set_bits:
                points.add((x, y))
    return points


def msk_points(mask: int, width: int, height: int, orientation: str) -> set[tuple[int, int]]:
    points: set[tuple[int, int]] = set()
    for y in range(max(0, min(height, MASK_ROWS))):
        for x in range(max(0, min(width, MASK_COLUMNS))):
            if orientation == "source_41e951":
                bit_index = (MASK_COLUMNS * MASK_ROWS - 1) - (y * MASK_COLUMNS) - x
            elif orientation == "lsb_row_major":
                bit_index = y * MASK_COLUMNS + x
            elif orientation == "lsb_rect_major":
                bit_index = y * width + x
            elif orientation == "source_rect_major":
                bit_index = (width * height - 1) - (y * width) - x
            elif orientation == "source_bottom_origin":
                bit_index = (MASK_COLUMNS * MASK_ROWS - 1) - ((MASK_ROWS - 1 - y) * MASK_COLUMNS) - x
            else:
                raise ValueError(f"unknown orientation: {orientation}")
            if 0 <= bit_index < 64 and ((mask >> bit_index) & 1):
                points.add((x, y))
    return points


def summarize(
    rows: list[dict[str, Any]],
    field: str,
    orientation: str,
    target_name: str,
    target_points: Callable[[dict[str, Any]], set[tuple[int, int]]],
) -> dict[str, Any]:
    exact = 0
    nonempty_exact = 0
    subset = 0
    mask_bits = 0
    target_bits = 0
    intersection = 0
    union = 0
    for row in rows:
        observed = msk_points(
            int(row.get(field, 0) or 0),
            int(row.get("h3maped_msk_width_0x34", 0) or 0),
            int(row.get("h3maped_msk_height_0x38", 0) or 0),
            orientation,
        )
        target = target_points(row)
        if observed == target:
            exact += 1
            if observed:
                nonempty_exact += 1
        if observed and observed.issubset(target):
            subset += 1
        mask_bits += len(observed)
        target_bits += len(target)
        intersection += len(observed & target)
        union += len(observed | target)
    return {
        "field": field,
        "orientation": orientation,
        "target": target_name,
        "row_count": len(rows),
        "exact_match_count": exact,
        "nonempty_exact_match_count": nonempty_exact,
        "nonempty_subset_count": subset,
        "mask_bit_count": mask_bits,
        "target_bit_count": target_bits,
        "intersection_bit_count": intersection,
        "union_bit_count": union,
        "iou": (intersection / union) if union else 1.0,
    }


def flatten_rows(catalog: dict[str, Any]) -> list[dict[str, Any]]:
    return [template for type_row in catalog.get("types", []) for template in type_row.get("templates", [])]


def object_type(row: dict[str, Any]) -> int:
    for key in ("type", "type_id"):
        value = row.get(key)
        try:
            return int(value)
        except (TypeError, ValueError):
            pass
    return -1


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--embedded", type=Path, default=DEFAULT_EMBEDDED)
    parser.add_argument("--report-json", type=Path)
    args = parser.parse_args()

    catalog = load_catalog(args.embedded)
    all_rows = flatten_rows(catalog)
    decorative_rows = [row for row in all_rows if 0x72 <= object_type(row) <= 0xD3]
    fields = [
        ("mask_a_0x3c_0x40", "h3maped_msk_mask_a_0x3c_0x40"),
        ("mask_b_0x44_0x48", "h3maped_msk_mask_b_0x44_0x48"),
    ]
    orientations = [
        "source_41e951",
        "lsb_row_major",
        "lsb_rect_major",
        "source_rect_major",
        "source_bottom_origin",
    ]
    targets: list[tuple[str, Callable[[dict[str, Any]], set[tuple[int, int]]]]] = [
        ("passable_bits", lambda row: text_mask_points(str(row.get("pass_mask", "")), True)),
        ("body_bits", lambda row: text_mask_points(str(row.get("pass_mask", "")), False)),
        ("action_bits", lambda row: text_mask_points(str(row.get("action_mask", "")), True)),
    ]

    report: dict[str, Any] = {
        "schema_id": "rmg_msk_mask_contract_audit_v1",
        "embedded": str(args.embedded),
        "purpose": "Recover likely parsed object+0x04 bitset field/orientation before changing 0x41e951-native behavior.",
        "source_addresses": {
            "bit_test_helper": "0x41e951",
            "local_scan_caller": "0x49e700",
            "msk_row_copy": "0x4903e8",
        },
        "row_counts": {
            "all": len(all_rows),
            "decorative_0x72_to_0xd3": len(decorative_rows),
        },
        "all_rows": [],
        "decorative_rows": [],
    }
    for rows_name, rows in (("all_rows", all_rows), ("decorative_rows", decorative_rows)):
        for field_name, field in fields:
            for orientation in orientations:
                for target_name, target in targets:
                    item = summarize(rows, field, orientation, target_name, target)
                    item["field_name"] = field_name
                    report[rows_name].append(item)
        report[f"{rows_name}_best_by_iou"] = sorted(
            report[rows_name],
            key=lambda item: (item["iou"], item["nonempty_exact_match_count"], item["nonempty_subset_count"]),
            reverse=True,
        )[:10]

    if args.report_json:
        args.report_json.parent.mkdir(parents=True, exist_ok=True)
        args.report_json.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
