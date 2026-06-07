#!/usr/bin/env python3
"""Summarize H3MapEd GeneratedCell grid dumps captured at 0x4a4c8e.

This consumes a WineDbg ledger produced by
``rmg_h3maped_recovery_interactive_trace.py``. It intentionally summarizes the
private phase buffer; it does not compare final maps or mutate native RMG.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


DEFAULT_LEDGER = Path(".artifacts/rmg_recovery/seed58_interactive_4a4c8e_full_grid/winedbg_interactive_trace_ledger.json")
DEFAULT_OUT = Path(".artifacts/rmg_recovery/seed58_4a4c8e_grid_summary.json")
GENERATED_CELL_DWORDS = 12


def signed_byte(value: int) -> int:
    value &= 0xFF
    return value - 0x100 if value & 0x80 else value


def contiguous_memory_groups(memory_lines: list[dict[str, Any]]) -> list[dict[str, Any]]:
    groups: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    expected_address: int | None = None
    for line in sorted(memory_lines, key=lambda item: int(item.get("address", 0))):
        address = int(line.get("address", 0))
        words = [int(word) & 0xFFFFFFFF for word in line.get("words", [])]
        if not words:
            continue
        if current is None or expected_address != address:
            current = {"base": address, "words": []}
            groups.append(current)
        current["words"].extend(words)
        expected_address = address + len(words) * 4
    return groups


def choose_grid_words(event: dict[str, Any]) -> tuple[int, list[int]]:
    groups = contiguous_memory_groups(event.get("memory_lines", []))
    candidates = [
        group
        for group in groups
        if len(group["words"]) >= GENERATED_CELL_DWORDS and len(group["words"]) % GENERATED_CELL_DWORDS == 0
    ]
    if not candidates:
        raise ValueError("ledger does not contain a full GeneratedCell dword dump")
    group = max(candidates, key=lambda item: len(item["words"]))
    return int(group["base"]), list(group["words"])


def summarize_cells(base: int, words: list[int], *, width: int, height: int, levels: int) -> dict[str, Any]:
    cell_count = len(words) // GENERATED_CELL_DWORDS
    expected_cells = width * height * levels if width and height and levels else cell_count
    if expected_cells != cell_count:
        raise ValueError(f"dimension cell count {expected_cells} does not match dumped cells {cell_count}")

    bit_counts = {f"bit{bit}": 0 for bit in (22, 25, 26, 27)}
    owner_byte2_counts: dict[str, int] = {}
    terrain_class_counts: dict[str, int] = {}
    nonzero_2c = 0
    checksum = hashlib.sha256()

    cells: list[dict[str, int]] = []
    for index in range(cell_count):
        offset = index * GENERATED_CELL_DWORDS
        cell_words = words[offset : offset + GENERATED_CELL_DWORDS]
        w20 = cell_words[8]
        w24 = cell_words[9]
        w28 = cell_words[10]
        w2c = cell_words[11]
        for bit in (22, 25, 26, 27):
            bit_counts[f"bit{bit}"] += (w28 >> bit) & 1
        owner = signed_byte(w20 >> 16)
        owner_byte2_counts[str(owner)] = owner_byte2_counts.get(str(owner), 0) + 1
        terrain_class = (w24 >> 26) & 0x3F
        terrain_class_counts[str(terrain_class)] = terrain_class_counts.get(str(terrain_class), 0) + 1
        nonzero_2c += 1 if w2c else 0
        checksum.update(w20.to_bytes(4, "little"))
        checksum.update(w24.to_bytes(4, "little"))
        checksum.update(w28.to_bytes(4, "little"))
        checksum.update(w2c.to_bytes(4, "little"))
        cells.append({"index": index, "w20": w20, "w24": w24, "w28": w28, "w2c": w2c})

    return {
        "schema_id": "h3maped_4a4c8e_grid_summary_v1",
        "grid_base": "0x%08x" % base,
        "width": width,
        "height": height,
        "levels": levels,
        "cell_count": cell_count,
        "bit_counts_from_w28": bit_counts,
        "owner_byte2_counts_from_w20": dict(sorted(owner_byte2_counts.items(), key=lambda item: int(item[0]))),
        "terrain_class_counts_from_w24": dict(sorted(terrain_class_counts.items(), key=lambda item: int(item[0]))),
        "nonzero_w2c_count": nonzero_2c,
        "w20_w24_w28_w2c_sha256": checksum.hexdigest(),
        "first_cells": cells[:16],
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--event-index", type=int, default=0)
    parser.add_argument("--width", type=int, default=36)
    parser.add_argument("--height", type=int, default=36)
    parser.add_argument("--levels", type=int, default=1)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    ledger = json.loads(args.ledger.read_text(encoding="utf-8"))
    events = ledger.get("events", [])
    if not events:
        raise SystemExit(f"no events in ledger: {args.ledger}")
    if args.event_index < 0 or args.event_index >= len(events):
        raise SystemExit(f"event index {args.event_index} is outside ledger event count {len(events)}")
    event = events[args.event_index]
    base, words = choose_grid_words(event)
    summary = summarize_cells(base, words, width=args.width, height=args.height, levels=args.levels)
    summary["ledger"] = str(args.ledger)
    summary["event_index"] = args.event_index
    summary["event_address"] = event.get("address", "")
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_4A4C8E_GRID_SUMMARY "
        f"status=pass cells={summary['cell_count']} bit26={summary['bit_counts_from_w28']['bit26']} "
        f"bit27={summary['bit_counts_from_w28']['bit27']} sha256={summary['w20_w24_w28_w2c_sha256']} out={args.out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
