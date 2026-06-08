#!/usr/bin/env python3
"""Summarize complete ``0x4a54a7`` projection-loop write streams.

The input traces begin at the post-Border-Guard ``0x4a7605`` materialization
call sites and install detailed breakpoints only after those call sites fire.
This report records the ordered ``0x4a56b6`` writes from the ``0x4a54a7``
low-word projection loop. It is recovery evidence only and does not change
native RMG behavior.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_FIRST_LEDGER = Path(
    ".artifacts/rmg_recovery/medium_seed10_4a54a7_projection_first_target_20260608/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_SECOND_LEDGER = Path(
    ".artifacts/rmg_recovery/medium_seed10_4a54a7_projection_second_target_20260608/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_OUT = Path(
    ".artifacts/rmg_recovery/medium_seed10_4a54a7_projection_write_summary_20260608.json"
)

TARGETS = [
    {
        "name": "first_0x4a7605_materialization",
        "ledger": DEFAULT_FIRST_LEDGER,
        "trigger": "0x004a77a8",
        "return_site": "0x004a77ad",
    },
    {
        "name": "second_0x4a7605_materialization",
        "ledger": DEFAULT_SECOND_LEDGER,
        "trigger": "0x004a7895",
        "return_site": "0x004a789a",
    },
]


def hex_word(value: int | None) -> str | None:
    if value is None:
        return None
    return "0x%08x" % (int(value) & 0xFFFFFFFF)


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def first_words(event: dict[str, Any]) -> list[int]:
    if not event.get("memory_lines"):
        return []
    return [int(word) & 0xFFFFFFFF for word in event["memory_lines"][0].get("words", [])]


def block_words_at(event: dict[str, Any], address: int, max_words: int) -> list[int]:
    by_address: dict[int, list[int]] = {}
    for memory_line in event.get("memory_lines", []):
        line_address = int(memory_line.get("address", -1))
        words = [int(word) & 0xFFFFFFFF for word in memory_line.get("words", [])]
        if words:
            by_address[line_address] = words
    words: list[int] = []
    cursor = address
    while len(words) < max_words and cursor in by_address:
        line_words = by_address[cursor]
        words.extend(line_words)
        cursor += len(line_words) * 4
    return words[:max_words]


def find_event(events: list[dict[str, Any]], address: str) -> dict[str, Any] | None:
    for event in events:
        if str(event.get("address", "")).lower() == address:
            return event
    return None


def return_address(event: dict[str, Any] | None) -> str | None:
    if event is None:
        return None
    derived = event.get("derived", {})
    if derived.get("return_address"):
        return str(derived["return_address"])
    words = first_words(event)
    return hex_word(words[0]) if words else None


def generator_layout(entry_event: dict[str, Any]) -> dict[str, Any]:
    generator = int(entry_event.get("registers", {}).get("ecx", 0))
    words = block_words_at(entry_event, generator, 12)
    base = words[5] if len(words) > 5 else None
    width = words[6] if len(words) > 6 else None
    height = words[7] if len(words) > 7 else None
    levels = words[8] if len(words) > 8 else None
    return {
        "generator_pointer": hex_word(generator),
        "raw_words": [hex_word(word) for word in words],
        "generated_cell_base": hex_word(base),
        "width": width,
        "height": height,
        "levels": levels,
        "stride": 0x30,
    }


def coordinate_for_cell(pointer: int, layout: dict[str, Any]) -> dict[str, Any]:
    base_text = layout.get("generated_cell_base")
    width = layout.get("width")
    height = layout.get("height")
    if not base_text or not width or not height:
        return {"flat": None, "x": None, "y": None, "level": None}
    base = int(base_text, 16)
    delta = pointer - base
    if delta < 0 or delta % int(layout["stride"]) != 0:
        return {"flat": None, "x": None, "y": None, "level": None}
    flat = delta // int(layout["stride"])
    level_area = int(width) * int(height)
    return {
        "flat": flat,
        "x": flat % int(width),
        "y": (flat // int(width)) % int(height),
        "level": flat // level_area,
    }


def event_args(event: dict[str, Any] | None) -> dict[str, Any]:
    if event is None:
        return {}
    words = first_words(event)
    level_line = event.get("memory_lines", [{}])[1].get("words", []) if len(event.get("memory_lines", [])) > 1 else []
    return {
        "return_address": return_address(event),
        "arg0": hex_word(words[1] if len(words) > 1 else None),
        "x": words[2] if len(words) > 2 else None,
        "y": words[3] if len(words) > 3 else None,
        "level": int(level_line[0]) & 0xFFFFFFFF if level_line else None,
    }


def write_event_summary(event: dict[str, Any], index: int, layout: dict[str, Any]) -> dict[str, Any]:
    cell_pointer = int(event.get("registers", {}).get("eax", 0))
    new_word = int(event.get("registers", {}).get("esi", 0)) & 0xFFFFFFFF
    proposed_next = int(event.get("registers", {}).get("edx", 0)) & 0xFFFFFFFF
    cell_words = block_words_at(event, cell_pointer, 16)
    old_word = cell_words[8] if len(cell_words) > 8 else None
    old_low = (old_word & 0xFFFF) if old_word is not None else None
    new_low = new_word & 0xFFFF
    old_high = (old_word & 0xFFFF0000) if old_word is not None else None
    new_high = new_word & 0xFFFF0000
    return {
        "ordinal": index,
        "cell_pointer": hex_word(cell_pointer),
        "coordinate": coordinate_for_cell(cell_pointer, layout),
        "old_plus_0x20": hex_word(old_word),
        "new_plus_0x20": hex_word(new_word),
        "proposed_next_edx": hex_word(proposed_next),
        "old_low_word": old_low,
        "new_low_word": new_low,
        "high_word_preserved": old_high == new_high,
        "low_word_lowered": old_low is not None and new_low < old_low,
        "raw_cell_words": [hex_word(word) for word in cell_words],
    }


def summarize_one(target: dict[str, Any]) -> dict[str, Any]:
    ledger_path = Path(target["ledger"])
    ledger = read_json(ledger_path)
    events = ledger.get("events", [])
    trigger = find_event(events, target["trigger"])
    entry = find_event(events, "0x004a5e03")
    callback = find_event(events, "0x004a5e69")
    commit = find_event(events, "0x004a54a7")
    projection_start = find_event(events, "0x004a558a")
    projection_done = find_event(events, "0x004a5756")
    delegated_return = find_event(events, "0x004a5e6c")
    target_return = find_event(events, target["return_site"])
    if entry is None:
        layout = {}
    else:
        layout = generator_layout(entry)
    writes = [
        write_event_summary(event, index + 1, layout)
        for index, event in enumerate(events)
        if str(event.get("address", "")).lower() == "0x004a56b6"
    ]
    unique_cells = sorted({write["cell_pointer"] for write in writes})
    xs = [write["coordinate"]["x"] for write in writes if write["coordinate"]["x"] is not None]
    ys = [write["coordinate"]["y"] for write in writes if write["coordinate"]["y"] is not None]
    lows = [write["new_low_word"] for write in writes if write["new_low_word"] is not None]
    object_pointer = first_words(callback)[0] if callback is not None and first_words(callback) else None
    invariants = {
        "trigger_reached": trigger is not None,
        "entry_return_matches_target": return_address(entry) == target["return_site"],
        "commit_returns_to_0x4a5e6c": return_address(commit) == "0x004a5e6c",
        "projection_done_reached": projection_done is not None,
        "delegated_return_reached": delegated_return is not None,
        "target_return_reached": target_return is not None,
        "has_projection_writes": bool(writes),
        "every_write_has_unique_cell_pointer": len(unique_cells) == len(writes),
        "every_write_preserves_high_word": bool(writes) and all(write["high_word_preserved"] for write in writes),
        "every_write_lowers_low_word": bool(writes) and all(write["low_word_lowered"] for write in writes),
    }
    return {
        "name": target["name"],
        "ledger": str(ledger_path),
        "status": "complete" if all(invariants.values()) else "incomplete",
        "event_count": len(events),
        "trigger_address": target["trigger"],
        "return_site": target["return_site"],
        "target_call_args": event_args(entry),
        "object_record_pointer": hex_word(object_pointer),
        "commit_call_args": event_args(commit),
        "generator_layout": layout,
        "projection_seed_cell": {
            "event_address": "0x004a558a",
            "cell_pointer": hex_word(int(projection_start.get("registers", {}).get("eax", 0))) if projection_start else None,
            "coordinate": coordinate_for_cell(int(projection_start.get("registers", {}).get("eax", 0)), layout) if projection_start else None,
            "raw_words": [hex_word(word) for word in block_words_at(projection_start, int(projection_start.get("registers", {}).get("eax", 0)), 16)] if projection_start else [],
        },
        "write_count": len(writes),
        "unique_cell_count": len(unique_cells),
        "coordinate_bounds": {
            "min_x": min(xs) if xs else None,
            "max_x": max(xs) if xs else None,
            "min_y": min(ys) if ys else None,
            "max_y": max(ys) if ys else None,
        },
        "new_low_word_range": {
            "min": min(lows) if lows else None,
            "max": max(lows) if lows else None,
        },
        "first_writes": writes[:12],
        "last_writes": writes[-12:],
        "invariants": invariants,
    }


def summarize(targets: list[dict[str, Any]]) -> dict[str, Any]:
    summaries = [summarize_one(target) for target in targets]
    invariants = {
        "native_behavior_changed": False,
        "both_projection_streams_complete": all(summary["status"] == "complete" for summary in summaries),
        "first_stream_write_count": summaries[0]["write_count"] if summaries else 0,
        "second_stream_write_count": summaries[1]["write_count"] if len(summaries) > 1 else 0,
    }
    status = (
        "post_border_guard_4a54a7_projection_write_sets_recovered"
        if invariants["both_projection_streams_complete"]
        else "post_border_guard_4a54a7_projection_write_sets_incomplete"
    )
    return {
        "schema_id": "h3maped_4a54a7_projection_write_summary_v1",
        "status": status,
        "native_behavior_changed": False,
        "targets": summaries,
        "invariants": invariants,
        "remaining_blocker": (
            "This recovers two complete ordered 0x4a54a7 projection-loop write streams for the focused "
            "post-Border-Guard materialization callsites under the recorded controlled Medium seed-10 "
            "debugger setup. Full end-to-end recovery still needs descriptor +0x29/+0x2c/+0x30 semantic "
            "names, relation-counter roles, linkage from these projection writes into later relation/control "
            "consumers, and reconciliation with the earlier target-cell after-state trace coordinates."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--first-ledger", type=Path, default=DEFAULT_FIRST_LEDGER)
    parser.add_argument("--second-ledger", type=Path, default=DEFAULT_SECOND_LEDGER)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    targets = [
        {**TARGETS[0], "ledger": args.first_ledger},
        {**TARGETS[1], "ledger": args.second_ledger},
    ]
    summary = summarize(targets)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_4A54A7_PROJECTION_WRITE_SUMMARY status={summary['status']} out={args.out}")
    return 0 if summary["status"].endswith("recovered") else 1


if __name__ == "__main__":
    raise SystemExit(main())
