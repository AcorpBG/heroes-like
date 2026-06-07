#!/usr/bin/env python3
"""Summarize H3MapEd 0x49ac8e GeneratedCell validity-bit clears.

The 0x49ac8e instruction is inside 0x49abd6 and clears byte
GeneratedCell+0x2b bit 0x02. That byte is the high byte of the +0x28 state
dword, so this is the source-level clear of w28 bit25 used by 0x49a1d8.
This report ties those runtime clear cells to the next 0x4a8260 private-state
grid checkpoint in the same trace.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

from rmg_h3maped_4a4c8e_grid_summary import GENERATED_CELL_DWORDS, choose_grid_words, summarize_cells


DEFAULT_LEDGER = Path(".artifacts/rmg_recovery/direct_generation_49ac8e_clears_to_4a8260/winedbg_interactive_trace_ledger.json")
DEFAULT_OUT = Path(".artifacts/rmg_recovery/direct_generation_49ac8e_bit25_clear_summary.json")
CLEAR_ADDRESS = "0x0049ac8e"
BOUNDARY_ADDRESS = "0x004a8260"


def memory_words_at(event: dict[str, Any], address: int) -> list[int]:
    for line in event.get("memory_lines", []):
        if int(line.get("address", -1)) == address:
            return [int(word) & 0xFFFFFFFF for word in line.get("words", [])]
    return []


def summarize_clear_event(event_index: int, event: dict[str, Any]) -> dict[str, Any]:
    registers = event.get("registers", {})
    ebx = int(registers["ebx"])
    esi = int(registers["esi"])
    wrapper_words0 = memory_words_at(event, ebx)
    wrapper_words1 = memory_words_at(event, ebx + 16)
    if len(wrapper_words0) < 4 or len(wrapper_words1) < 2:
        raise ValueError(f"event {event_index} does not contain enough grid-wrapper words at ebx")

    grid_base = wrapper_words0[2]
    width = wrapper_words0[3]
    height = wrapper_words1[0]
    levels = wrapper_words1[1]
    delta = esi - grid_base
    if delta < 0 or delta % 0x30 != 0:
        raise ValueError(f"event {event_index} esi 0x{esi:08x} is not a GeneratedCell pointer")
    flat = delta // 0x30
    x = flat % width
    y = (flat // width) % height
    level = flat // (width * height)
    state_words = memory_words_at(event, esi + 0x20)

    return {
        "event_index": event_index,
        "flat": flat,
        "x": x,
        "y": y,
        "level": level,
        "grid_base": f"0x{grid_base:08x}",
        "width": width,
        "height": height,
        "levels": levels,
        "pre_clear_state_words": {
            "w20": state_words[0] if len(state_words) > 0 else None,
            "w24": state_words[1] if len(state_words) > 1 else None,
            "w28": state_words[2] if len(state_words) > 2 else None,
            "w2c": state_words[3] if len(state_words) > 3 else None,
        },
        "stack_top": event.get("derived", {}).get("return_address", ""),
    }


def bit25_clear_flats(words: list[int]) -> list[int]:
    clears: list[int] = []
    for index in range(len(words) // GENERATED_CELL_DWORDS):
        w28 = words[index * GENERATED_CELL_DWORDS + 10]
        if ((w28 >> 25) & 1) == 0:
            clears.append(index)
    return clears


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--boundary-event-index", type=int, default=-1)
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

    clear_events = [
        summarize_clear_event(index, event)
        for index, event in enumerate(events)
        if event.get("address") == CLEAR_ADDRESS
    ]
    if not clear_events:
        raise SystemExit(f"no {CLEAR_ADDRESS} events in ledger: {args.ledger}")

    boundary_index = args.boundary_event_index if args.boundary_event_index >= 0 else len(events) - 1
    if boundary_index >= len(events):
        raise SystemExit(f"boundary event index {boundary_index} outside event count {len(events)}")
    boundary_event = events[boundary_index]
    if boundary_event.get("address") != BOUNDARY_ADDRESS:
        raise SystemExit(f"event {boundary_index} is {boundary_event.get('address')}, not {BOUNDARY_ADDRESS}")

    boundary_base, boundary_words = choose_grid_words(boundary_event)
    boundary_summary = summarize_cells(
        boundary_base,
        boundary_words,
        width=args.width,
        height=args.height,
        levels=args.levels,
    )
    clear_flats = sorted({int(item["flat"]) for item in clear_events})
    boundary_clear_flats = bit25_clear_flats(boundary_words)
    clear_set = set(clear_flats)
    boundary_set = set(boundary_clear_flats)
    stack_top_counts = Counter(str(item.get("stack_top", "")) for item in clear_events)

    result = {
        "schema_id": "h3maped_49ac8e_bit25_clear_trace_summary_v1",
        "ledger": str(args.ledger),
        "seed_pinned": False,
        "seed_note": "direct H3MapEd generation trace; random seed was not controlled by this tool",
        "clear_instruction": "0x0049ac8e AND byte ptr [ESI + 0x2b],0xfd",
        "clear_semantics": "clears GeneratedCell+0x2b bit 0x02, which is w28 bit25 and the validity bit tested by 0x49a1d8",
        "phase_boundary": BOUNDARY_ADDRESS,
        "phase_boundary_event_index": boundary_index,
        "phase_boundary_summary": boundary_summary,
        "clear_event_count": len(clear_events),
        "unique_clear_flat_count": len(clear_flats),
        "phase_boundary_bit25_clear_count": len(boundary_clear_flats),
        "phase_boundary_bit25_set_count": boundary_summary["bit_counts_from_w28"]["bit25"],
        "clear_flats_equal_phase_boundary_bit25_clear_flats": clear_set == boundary_set,
        "missing_phase_boundary_clear_flats_from_trace": sorted(boundary_set - clear_set),
        "extra_trace_clear_flats_not_clear_at_boundary": sorted(clear_set - boundary_set),
        "stack_top_counts": dict(sorted(stack_top_counts.items())),
        "first_clear_cells": clear_events[:24],
        "all_clear_flats": clear_flats,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_49AC8E_CLEAR_SUMMARY "
        f"status=pass clears={len(clear_events)} unique={len(clear_flats)} "
        f"boundary_bit25_clear={len(boundary_clear_flats)} "
        f"match={clear_set == boundary_set} out={args.out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
