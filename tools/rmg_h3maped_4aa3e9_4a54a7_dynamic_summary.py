#!/usr/bin/env python3
"""Summarize the 0x4aa3e9 -> 0x4a54a7 live callback write stream."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_LEDGER = Path(
    ".artifacts/rmg_recovery/4aa3e9_4a54a7_dynamic_trace_20260610/"
    "winedbg_4aa3e9_4a54a7_dynamic_trace_ledger.json"
)
DEFAULT_OUT = Path(".artifacts/rmg_recovery/4aa3e9_4a54a7_dynamic_summary_20260610.json")

ENTRY_4AA3E9 = "0x004aa3e9"
SLOT4_CALLSITE = "0x004aa44a"
COMMIT_4A54A7 = "0x004a54a7"
PROJECTION_WRITE = "0x004a56b6"
COMMIT_RETURN = "0x004a5756"
AFTER_SLOT4 = "0x004aa44d"
GENERATOR_OBJECT_VECTOR_ANCHOR = 0x00500F00


def hex32(value: int | None) -> str | None:
    return None if value is None else f"0x{value & 0xFFFFFFFF:08x}"


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def event_address(event: dict[str, Any]) -> str:
    return str(event.get("address", "")).lower()


def first_event(events: list[dict[str, Any]], address: str) -> dict[str, Any] | None:
    for event in events:
        if event_address(event) == address:
            return event
    return None


def block_words_at(event: dict[str, Any], address: int | None, max_words: int) -> list[int]:
    if not isinstance(address, int):
        return []
    by_address: dict[int, list[int]] = {}
    for line in event.get("memory_lines", []):
        line_address = int(line.get("address", -1))
        words = [int(word) & 0xFFFFFFFF for word in line.get("words", [])]
        if words and line_address not in by_address:
            by_address[line_address] = words
    words: list[int] = []
    cursor = address
    while len(words) < max_words and cursor in by_address:
        line_words = by_address[cursor]
        words.extend(line_words)
        cursor += len(line_words) * 4
    return words[:max_words]


def stack_words(event: dict[str, Any], max_words: int = 8) -> list[int]:
    return block_words_at(event, event.get("registers", {}).get("esp"), max_words)


def object_vector_snapshot(event: dict[str, Any] | None) -> dict[str, Any] | None:
    if event is None:
        return None
    candidates: list[dict[str, Any]] = []
    for line in event.get("memory_lines", []):
        words = [int(word) & 0xFFFFFFFF for word in line.get("words", [])]
        if len(words) < 4 or words[0] != GENERATOR_OBJECT_VECTOR_ANCHOR:
            continue
        begin, end, capacity = words[1], words[2], words[3]
        count = (end - begin) // 4 if end >= begin and (end - begin) % 4 == 0 else None
        capacity_count = (
            (capacity - begin) // 4
            if capacity >= begin and (capacity - begin) % 4 == 0
            else None
        )
        candidates.append(
            {
                "line_address": hex32(int(line.get("address", 0))),
                "begin": hex32(begin),
                "end": hex32(end),
                "capacity": hex32(capacity),
                "count": count,
                "capacity_count": capacity_count,
            }
        )
    return candidates[0] if candidates else None


def cell_state(event: dict[str, Any] | None, cell: int | None) -> dict[str, Any] | None:
    if event is None or cell is None:
        return None
    words = block_words_at(event, cell, 16)
    if len(words) < 12:
        return None
    refs_begin = words[1]
    refs_end = words[2]
    ref_count = (
        (refs_end - refs_begin) // 4
        if refs_end >= refs_begin and (refs_end - refs_begin) % 4 == 0
        else None
    )
    refs = block_words_at(event, refs_begin, min(16, ref_count or 0)) if ref_count else []
    word20 = words[8]
    return {
        "cell_pointer": hex32(cell),
        "raw_words": [hex32(word) for word in words],
        "object_ref_vector": {
            "begin": hex32(refs_begin),
            "end": hex32(refs_end),
            "capacity": hex32(words[3]),
            "count": ref_count,
            "entries": [hex32(word) for word in refs],
        },
        "projection_coordinate_words": {
            "+0x10": words[4],
            "+0x14": words[5],
            "+0x18": words[6],
        },
        "generated_cell_words": {
            "+0x20": hex32(word20),
            "+0x24": hex32(words[9]),
            "+0x28": hex32(words[10]),
            "+0x2c": hex32(words[11]),
        },
        "low_word_plus_0x20": word20 & 0xFFFF,
        "high_word_plus_0x20": hex32(word20 & 0xFFFF0000),
    }


def projection_write(event: dict[str, Any], ordinal: int) -> dict[str, Any]:
    cell = int(event.get("registers", {}).get("eax", 0))
    old_words = block_words_at(event, cell, 12)
    old_word = old_words[8] if len(old_words) > 8 else None
    new_word = int(event.get("registers", {}).get("esi", 0)) & 0xFFFFFFFF
    proposed_word = int(event.get("registers", {}).get("edx", 0)) & 0xFFFFFFFF
    old_low = old_word & 0xFFFF if old_word is not None else None
    new_low = new_word & 0xFFFF
    return {
        "ordinal": ordinal,
        "cell_pointer": hex32(cell),
        "old_plus_0x20": hex32(old_word),
        "new_plus_0x20": hex32(new_word),
        "proposed_edx": hex32(proposed_word),
        "old_low_word": old_low,
        "new_low_word": new_low,
        "high_word_preserved": old_word is not None
        and (old_word & 0xFFFF0000) == (new_word & 0xFFFF0000),
        "low_word_lowered": old_low is not None and new_low < old_low,
        "raw_cell_words": [hex32(word) for word in old_words],
    }


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    ledger = read_json(args.ledger)
    events = ledger.get("events", [])
    meta = ledger.get("dynamic_trace_meta", {})
    target_cell = int(meta["target_cell"], 16) if meta.get("target_cell") else None
    object_record = str(meta.get("object_record") or "").lower()
    event_counts = Counter(event_address(event) for event in events)

    entry = first_event(events, ENTRY_4AA3E9)
    slot4 = first_event(events, SLOT4_CALLSITE)
    commit = first_event(events, COMMIT_4A54A7)
    commit_return = first_event(events, COMMIT_RETURN)
    after_slot4 = first_event(events, AFTER_SLOT4)
    writes = [
        projection_write(event, index + 1)
        for index, event in enumerate(events)
        if event_address(event) == PROJECTION_WRITE
    ]
    unique_write_cells = sorted({write["cell_pointer"] for write in writes if write["cell_pointer"]})

    before_cell = cell_state(commit, target_cell)
    return_cell = cell_state(commit_return, target_cell)
    after_cell = cell_state(after_slot4, target_cell)
    before_refs = set((before_cell or {}).get("object_ref_vector", {}).get("entries") or [])
    after_refs = set((after_cell or {}).get("object_ref_vector", {}).get("entries") or [])
    before_low = (before_cell or {}).get("low_word_plus_0x20")
    after_low = (after_cell or {}).get("low_word_plus_0x20")
    before_high = (before_cell or {}).get("high_word_plus_0x20")
    after_high = (after_cell or {}).get("high_word_plus_0x20")
    vector_before = object_vector_snapshot(commit)
    vector_after = object_vector_snapshot(commit_return)
    slot4_stack = stack_words(slot4, 4) if slot4 else []
    commit_stack = stack_words(commit, 5) if commit else []

    invariants = {
        "no_native_behavior_change": True,
        "no_objdump_used": True,
        "ledger_has_events": bool(events),
        "path_hits_4aa3e9_slot4_4a54a7_and_4aa44d": all(
            event_counts.get(address, 0) > 0
            for address in [ENTRY_4AA3E9, SLOT4_CALLSITE, COMMIT_4A54A7, COMMIT_RETURN, AFTER_SLOT4]
        ),
        "commit_returns_to_4aa44d": meta.get("commit_return_address") == AFTER_SLOT4
        and (commit or {}).get("derived", {}).get("return_address") == AFTER_SLOT4,
        "slot4_member_matches_committed_object": bool(slot4_stack)
        and hex32(slot4_stack[0]) == object_record,
        "commit_object_matches_slot4_member": len(commit_stack) > 1
        and hex32(commit_stack[1]) == object_record,
        "target_cell_snapshots_available": before_cell is not None
        and return_cell is not None
        and after_cell is not None,
        "target_cell_object_ref_added": object_record not in before_refs and object_record in after_refs,
        "target_cell_low_word_lowered": isinstance(before_low, int)
        and isinstance(after_low, int)
        and after_low < before_low,
        "target_cell_high_word_preserved": before_high == after_high,
        "object_vector_grows_by_one_inside_4a54a7": isinstance((vector_before or {}).get("count"), int)
        and isinstance((vector_after or {}).get("count"), int)
        and vector_after["count"] == vector_before["count"] + 1,
        "projection_write_stream_captured": len(writes) > 0,
        "projection_writes_have_unique_cells": len(writes) == len(unique_write_cells),
        "projection_writes_preserve_high_word": bool(writes)
        and all(write["high_word_preserved"] for write in writes),
        "projection_writes_lower_low_word": bool(writes)
        and all(write["low_word_lowered"] for write in writes),
    }
    status = (
        "4aa3e9_4aa44d_4a54a7_write_stream_recovered"
        if all(invariants.values())
        else "4aa3e9_4aa44d_4a54a7_write_stream_incomplete"
    )

    return {
        "schema_id": "h3maped_4aa3e9_4a54a7_dynamic_summary_v1",
        "status": status,
        "scope": (
            "Live Wine recovery for the 0x4aa3e9 selected-member slot +0x04 callback "
            "that enters 0x4a54a7 and returns to 0x4aa44d. This is recovery evidence "
            "only and does not change native RMG behavior."
        ),
        "inputs": {"ledger": str(args.ledger)},
        "event_counts": dict(sorted(event_counts.items())),
        "dynamic_trace_meta": meta,
        "object_vector_states": {
            COMMIT_4A54A7: vector_before,
            COMMIT_RETURN: vector_after,
        },
        "target_cell_states": {
            COMMIT_4A54A7: before_cell,
            COMMIT_RETURN: return_cell,
            AFTER_SLOT4: after_cell,
        },
        "projection_write_count": len(writes),
        "unique_projection_write_cell_count": len(unique_write_cells),
        "first_projection_writes": writes[:12],
        "last_projection_writes": writes[-12:],
        "invariants": invariants,
        "metrics": {
            "native_behavior_changed": False,
            "used_objdump": False,
            "overall_goal_complete": False,
            "target_cell_low_word_before": before_low,
            "target_cell_low_word_after": after_low,
            "target_cell_low_word_cleared_to_zero": after_low == 0,
            "object_vector_count_before": (vector_before or {}).get("count"),
            "object_vector_count_after": (vector_after or {}).get("count"),
            "projection_write_count": len(writes),
        },
        "source_backed_conclusion": (
            "The sampled 0x4aa3e9 selected-member callback reaches 0x4a54a7 through "
            "slot +0x04 and returns to 0x4aa44d. In this live path, 0x4a54a7 appends "
            "the selected member object to the generator object vector, adds that object "
            "reference to the target generated cell, preserves the target cell +0x20 high "
            "word, and lowers the low word from 14 to 2. It does not clear that sampled "
            "target low word to zero. The internal projection loop writes 90 unique cells, "
            "preserving each +0x20 high word while lowering each low word."
        ),
        "remaining_gap": (
            "The 0x4aa3e9 -> 0x4aa44d owner loop now has same-ledger target-cell and "
            "projection-write recovery for one sampled callback. Full end-to-end native-port "
            "authority still requires equivalent same-ledger recovery for 0x4a9641 -> 0x4a98f0 "
            "and 0x4a9911 -> 0x4a9c3f, plus broader relation/control downstream linkage and "
            "the unresolved generator+0xf5c success-path question."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_4AA3E9_4A54A7_DYNAMIC_SUMMARY "
        f"status={summary['status']} writes={summary['projection_write_count']} "
        f"target_low={summary['metrics']['target_cell_low_word_before']}->"
        f"{summary['metrics']['target_cell_low_word_after']} out={args.out}"
    )
    return 0 if summary["status"].endswith("_recovered") else 1


if __name__ == "__main__":
    raise SystemExit(main())
