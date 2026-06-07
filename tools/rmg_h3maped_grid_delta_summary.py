#!/usr/bin/env python3
"""Summarize same-run H3MapEd GeneratedCell grid deltas between trace events."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from rmg_h3maped_4a4c8e_grid_summary import GENERATED_CELL_DWORDS, choose_grid_words, summarize_cells


DEFAULT_LEDGER = Path(".artifacts/rmg_recovery/seed58_interactive_4a8c15_to_4a4c8e_full_grid/winedbg_interactive_trace_ledger.json")
DEFAULT_OUT = Path(".artifacts/rmg_recovery/direct_generation_4a8c15_to_4a4c8e_grid_delta_summary.json")
STATE_WORDS = (8, 9, 10, 11)
STATE_WORD_NAMES = {8: "w20", 9: "w24", 10: "w28", 11: "w2c"}
TRACKED_BITS = (22, 25, 26, 27)


def bit(value: int, index: int) -> int:
    return (value >> index) & 1


def state_tuple(cell_words: list[int]) -> tuple[int, int, int, int]:
    return tuple(cell_words[index] for index in STATE_WORDS)


def summarize_delta(
    before_words: list[int],
    after_words: list[int],
    *,
    width: int,
    height: int,
    levels: int,
) -> dict[str, Any]:
    cell_count = width * height * levels
    if len(before_words) != len(after_words):
        raise ValueError(f"dump dword count mismatch: before={len(before_words)} after={len(after_words)}")
    if len(before_words) != cell_count * GENERATED_CELL_DWORDS:
        raise ValueError(f"dump dword count does not match dimensions: {len(before_words)}")

    changed_state_cells = 0
    changed_word_counts = {name: 0 for name in STATE_WORD_NAMES.values()}
    bit_set_counts = {f"bit{index}": 0 for index in TRACKED_BITS}
    bit_clear_counts = {f"bit{index}": 0 for index in TRACKED_BITS}
    bit_delta_counts = {f"bit{index}": 0 for index in TRACKED_BITS}
    first_changed_cells: list[dict[str, Any]] = []

    for cell_index in range(cell_count):
        offset = cell_index * GENERATED_CELL_DWORDS
        before_cell = before_words[offset : offset + GENERATED_CELL_DWORDS]
        after_cell = after_words[offset : offset + GENERATED_CELL_DWORDS]
        before_state = state_tuple(before_cell)
        after_state = state_tuple(after_cell)
        if before_state == after_state:
            continue
        changed_state_cells += 1
        for word_index, word_name in STATE_WORD_NAMES.items():
            if before_cell[word_index] != after_cell[word_index]:
                changed_word_counts[word_name] += 1
        for bit_index in TRACKED_BITS:
            before_bit = bit(before_cell[10], bit_index)
            after_bit = bit(after_cell[10], bit_index)
            delta = after_bit - before_bit
            bit_delta_counts[f"bit{bit_index}"] += delta
            if delta > 0:
                bit_set_counts[f"bit{bit_index}"] += 1
            elif delta < 0:
                bit_clear_counts[f"bit{bit_index}"] += 1
        if len(first_changed_cells) < 24:
            first_changed_cells.append(
                {
                    "index": cell_index,
                    "before": dict(zip(STATE_WORD_NAMES.values(), before_state)),
                    "after": dict(zip(STATE_WORD_NAMES.values(), after_state)),
                }
            )

    return {
        "changed_state_cell_count": changed_state_cells,
        "changed_word_counts": changed_word_counts,
        "bit_set_counts_from_w28": bit_set_counts,
        "bit_clear_counts_from_w28": bit_clear_counts,
        "bit_delta_counts_from_w28": bit_delta_counts,
        "first_changed_cells": first_changed_cells,
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--from-event-index", type=int, default=0)
    parser.add_argument("--to-event-index", type=int, default=1)
    parser.add_argument("--width", type=int, default=36)
    parser.add_argument("--height", type=int, default=36)
    parser.add_argument("--levels", type=int, default=1)
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
    for event_index in (args.from_event_index, args.to_event_index):
        if event_index < 0 or event_index >= len(events):
            raise SystemExit(f"event index {event_index} is outside ledger event count {len(events)}")

    before_event = events[args.from_event_index]
    after_event = events[args.to_event_index]
    before_base, before_words = choose_grid_words(before_event)
    after_base, after_words = choose_grid_words(after_event)
    before_summary = summarize_cells(before_base, before_words, width=args.width, height=args.height, levels=args.levels)
    after_summary = summarize_cells(after_base, after_words, width=args.width, height=args.height, levels=args.levels)
    delta = summarize_delta(before_words, after_words, width=args.width, height=args.height, levels=args.levels)

    result = {
        "schema_id": "h3maped_generated_cell_grid_delta_summary_v1",
        "ledger": str(args.ledger),
        "seed_pinned": bool(args.seed_pinned),
        "seed_note": (
            "seed-pinned trace"
            if args.seed_pinned
            else "direct H3MapEd generation trace; random seed was not controlled by this tool"
        ),
        "from_event": {
            "index": args.from_event_index,
            "address": before_event.get("address", ""),
            "summary": before_summary,
        },
        "to_event": {
            "index": args.to_event_index,
            "address": after_event.get("address", ""),
            "summary": after_summary,
        },
        "delta": delta,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_GRID_DELTA_SUMMARY "
        f"status=pass from={before_event.get('address', '')} to={after_event.get('address', '')} "
        f"changed={delta['changed_state_cell_count']} "
        f"bit26_delta={delta['bit_delta_counts_from_w28']['bit26']} "
        f"bit27_delta={delta['bit_delta_counts_from_w28']['bit27']} out={args.out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
