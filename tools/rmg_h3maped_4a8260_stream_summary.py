#!/usr/bin/env python3
"""Summarize H3MapEd 0x4a8260 helper-call streams from WineDbg ledgers."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

from rmg_h3maped_4a4c8e_grid_summary import GENERATED_CELL_DWORDS, choose_grid_words


DEFAULT_LEDGER = Path(".artifacts/rmg_recovery/direct_generation_4a8260_stamp_clear_stream/winedbg_interactive_trace_ledger.json")
DEFAULT_GRID_DELTA = Path(".artifacts/rmg_recovery/direct_generation_4a8260_entry_to_return_grid_delta_summary.json")
DEFAULT_GRID_LEDGER = Path(".artifacts/rmg_recovery/direct_generation_4a8260_entry_to_return_full_grid_esi/winedbg_interactive_trace_ledger.json")
DEFAULT_OUT = Path(".artifacts/rmg_recovery/direct_generation_4a8260_stamp_clear_stream_summary.json")
ROUTE_STAMP = "0x0049a85d"
BOUNDARY_CLEAR = "0x0049a962"
BIT26_WRITE = "0x0049aa63"


def stack_words(event: dict[str, Any]) -> list[int]:
    memory_lines = event.get("memory_lines", [])
    if not memory_lines:
        return []
    return [int(word) & 0xFFFFFFFF for word in memory_lines[0].get("words", [])]


def coordinate_from_stack(event: dict[str, Any]) -> tuple[int, int, int] | None:
    words = stack_words(event)
    if len(words) < 4:
        return None
    return (words[1], words[2], words[3])


def clipped_3x3_coverage(coordinates: list[tuple[int, int, int]], *, width: int, height: int) -> set[tuple[int, int, int]]:
    coverage: set[tuple[int, int, int]] = set()
    for x, y, level in coordinates:
        if level < 0:
            continue
        for yy in range(max(0, y - 1), min(height, y + 2)):
            for xx in range(max(0, x - 1), min(width, x + 2)):
                coverage.add((xx, yy, level))
    return coverage


def cell_index(coordinate: tuple[int, int, int], *, width: int, height: int) -> int:
    x, y, level = coordinate
    return (level * height + y) * width + x


def cell_state(words: list[int], coordinate: tuple[int, int, int], *, width: int, height: int) -> dict[str, int]:
    index = cell_index(coordinate, width=width, height=height)
    offset = index * GENERATED_CELL_DWORDS
    cell_words = words[offset : offset + GENERATED_CELL_DWORDS]
    w20 = cell_words[8]
    w24 = cell_words[9]
    w28 = cell_words[10]
    w2c = cell_words[11]
    return {
        "flat": index,
        "x": coordinate[0],
        "y": coordinate[1],
        "level": coordinate[2],
        "w20": w20,
        "w24": w24,
        "w28": w28,
        "w2c": w2c,
        "bit22": (w28 >> 22) & 1,
        "bit25": (w28 >> 25) & 1,
        "bit26": (w28 >> 26) & 1,
        "bit27": (w28 >> 27) & 1,
        "terrain_class": (w24 >> 26) & 0x3F,
    }


def summarize_coordinate_helper(events: list[dict[str, Any]], address: str, *, width: int, height: int) -> dict[str, Any]:
    helper_events = [event for event in events if event.get("address") == address]
    coordinates = [coordinate for event in helper_events if (coordinate := coordinate_from_stack(event)) is not None]
    returns: Counter[str] = Counter()
    for event in helper_events:
        words = stack_words(event)
        if words:
            returns["0x%08x" % words[0]] += 1
    coverage = clipped_3x3_coverage(coordinates, width=width, height=height)
    return {
        "address": address,
        "call_count": len(helper_events),
        "return_address_counts": dict(sorted(returns.items())),
        "coordinate_count": len(coordinates),
        "unique_coordinate_count": len(set(coordinates)),
        "raw_clipped_3x3_coverage_count": len(coverage),
        "first_coordinates": [list(item) for item in coordinates[:16]],
        "last_coordinates": [list(item) for item in coordinates[-16:]],
    }


def summarize_bit26_writer(events: list[dict[str, Any]]) -> dict[str, Any]:
    writer_events = [event for event in events if event.get("address") == BIT26_WRITE]
    returns: Counter[str] = Counter()
    args: Counter[str] = Counter()
    for event in writer_events:
        words = stack_words(event)
        if words:
            returns["0x%08x" % words[0]] += 1
        if len(words) >= 2:
            args[str(words[1])] += 1
    return {
        "address": BIT26_WRITE,
        "call_count": len(writer_events),
        "return_address_counts": dict(sorted(returns.items())),
        "stack_arg_counts": dict(sorted(args.items())),
    }


def summarize_boundary_skip_predicates(
    *,
    grid_ledger_path: Path,
    raw_coverage: set[tuple[int, int, int]],
    width: int,
    height: int,
) -> dict[str, Any] | None:
    if not grid_ledger_path.exists():
        return None
    ledger = json.loads(grid_ledger_path.read_text(encoding="utf-8"))
    events = ledger.get("events", [])
    if len(events) < 2:
        return None
    _before_base, before_words = choose_grid_words(events[0])
    _after_base, after_words = choose_grid_words(events[1])
    cleared: set[tuple[int, int, int]] = set()
    cell_count = len(before_words) // GENERATED_CELL_DWORDS
    for index in range(cell_count):
        before_w28 = before_words[index * GENERATED_CELL_DWORDS + 10]
        after_w28 = after_words[index * GENERATED_CELL_DWORDS + 10]
        if ((before_w28 >> 27) & 1) and not ((after_w28 >> 27) & 1):
            x = index % width
            y = (index // width) % height
            level = index // (width * height)
            cleared.add((x, y, level))

    skipped = sorted(raw_coverage - cleared, key=lambda item: (item[2], item[1], item[0]))
    classes: Counter[str] = Counter()
    skipped_states: list[dict[str, int]] = []
    for coordinate in skipped:
        state = cell_state(before_words, coordinate, width=width, height=height)
        classes[
            "bit22={bit22} bit25={bit25} bit26={bit26} bit27={bit27} w2c={w2c} terrain={terrain_class}".format(
                **state
            )
        ] += 1
        skipped_states.append(state)
    return {
        "grid_ledger": str(grid_ledger_path),
        "bit27_cleared_cell_count": len(cleared),
        "raw_coverage_cell_count": len(raw_coverage),
        "skipped_cell_count": len(skipped),
        "skipped_class_counts": dict(sorted(classes.items())),
        "skipped_cells": skipped_states,
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--grid-delta", type=Path, default=DEFAULT_GRID_DELTA)
    parser.add_argument("--grid-ledger", type=Path, default=DEFAULT_GRID_LEDGER)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--width", type=int, default=36)
    parser.add_argument("--height", type=int, default=36)
    parser.add_argument(
        "--seed-pinned",
        action="store_true",
        help="Set only when the trace driver explicitly controlled the H3MapEd random seed.",
    )
    return parser


def main() -> int:
    args = build_parser().parse_args()
    ledger = json.loads(args.ledger.read_text(encoding="utf-8"))
    events = ledger.get("events", [])
    address_counts = Counter(str(event.get("address", "")) for event in events)
    route_stamp = summarize_coordinate_helper(events, ROUTE_STAMP, width=args.width, height=args.height)
    boundary_clear = summarize_coordinate_helper(events, BOUNDARY_CLEAR, width=args.width, height=args.height)
    bit26_writer = summarize_bit26_writer(events)
    boundary_coordinates = [
        coordinate
        for event in events
        if event.get("address") == BOUNDARY_CLEAR
        if (coordinate := coordinate_from_stack(event)) is not None
    ]
    boundary_raw_coverage = clipped_3x3_coverage(boundary_coordinates, width=args.width, height=args.height)
    skip_predicates = summarize_boundary_skip_predicates(
        grid_ledger_path=args.grid_ledger,
        raw_coverage=boundary_raw_coverage,
        width=args.width,
        height=args.height,
    )

    grid_delta: dict[str, Any] | None = None
    if args.grid_delta.exists():
        grid_delta = json.loads(args.grid_delta.read_text(encoding="utf-8"))
    delta = grid_delta.get("delta", {}) if isinstance(grid_delta, dict) else {}
    bit_delta = delta.get("bit_delta_counts_from_w28", {}) if isinstance(delta, dict) else {}
    bit_clear = delta.get("bit_clear_counts_from_w28", {}) if isinstance(delta, dict) else {}
    comparison = {
        "grid_delta_source": str(args.grid_delta) if grid_delta else "",
        "boundary_clear_unique_centers_minus_bit26_delta": (
            boundary_clear["unique_coordinate_count"] - int(bit_delta.get("bit26", 0))
            if bit_delta
            else None
        ),
        "boundary_clear_raw_coverage_minus_bit27_clears": (
            boundary_clear["raw_clipped_3x3_coverage_count"] - int(bit_clear.get("bit27", 0))
            if bit_clear
            else None
        ),
    }

    result = {
        "schema_id": "h3maped_4a8260_stream_summary_v1",
        "ledger": str(args.ledger),
        "seed_pinned": bool(args.seed_pinned),
        "seed_note": (
            "seed-pinned trace"
            if args.seed_pinned
            else "direct H3MapEd generation trace; random seed was not controlled by this tool"
        ),
        "event_count": len(events),
        "address_counts": dict(sorted(address_counts.items())),
        "route_stamp_0x49a85d": route_stamp,
        "boundary_clear_0x49a962": boundary_clear,
        "bit26_writer_0x49aa63": bit26_writer,
        "grid_delta_comparison": comparison,
        "boundary_clear_skip_predicates": skip_predicates,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_4A8260_STREAM_SUMMARY "
        f"status=pass events={len(events)} route_stamps={route_stamp['call_count']} "
        f"boundary_clears={boundary_clear['call_count']} raw_clear_coverage={boundary_clear['raw_clipped_3x3_coverage_count']} "
        f"out={args.out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
