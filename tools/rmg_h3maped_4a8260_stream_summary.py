#!/usr/bin/env python3
"""Summarize H3MapEd 0x4a8260 helper-call streams from WineDbg ledgers."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_LEDGER = Path(".artifacts/rmg_recovery/direct_generation_4a8260_stamp_clear_stream/winedbg_interactive_trace_ledger.json")
DEFAULT_GRID_DELTA = Path(".artifacts/rmg_recovery/direct_generation_4a8260_entry_to_return_grid_delta_summary.json")
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


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--grid-delta", type=Path, default=DEFAULT_GRID_DELTA)
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
