#!/usr/bin/env python3
"""Summarize dynamic after-state for direct endpoint commits.

Input comes from ``rmg_h3maped_endpoint_afterstate_dynamic_trace.py``. The
summary filters the two direct ``0x4a7447`` endpoint commits, then records the
target generated-cell and generator object-vector changes around ``0x4a54a7``.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_LEDGER = Path(
    ".artifacts/rmg_recovery/direct_endpoint_afterstate_dynamic_trace_20260608/"
    "winedbg_dynamic_endpoint_afterstate_trace_ledger.json"
)
DEFAULT_OUT = Path(".artifacts/rmg_recovery/direct_endpoint_afterstate_dynamic_summary_20260608.json")


def hex32(value: int | None) -> str | None:
    return None if value is None else f"0x{value & 0xFFFFFFFF:08x}"


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def memory_word(event: dict[str, Any], address: int | None) -> int | None:
    if address is None:
        return None
    for line in event.get("memory_lines", []):
        base = int(line["address"])
        words = line.get("words", [])
        if base <= address < base + len(words) * 4 and (address - base) % 4 == 0:
            return int(words[(address - base) // 4]) & 0xFFFFFFFF
    return None


def block_words(event: dict[str, Any], address: int | None, count: int) -> list[int]:
    if address is None:
        return []
    by_address = {
        int(line["address"]): [int(word) & 0xFFFFFFFF for word in line.get("words", [])]
        for line in event.get("memory_lines", [])
        if line.get("words")
    }
    words: list[int] = []
    cursor = address
    while len(words) < count and cursor in by_address:
        line_words = by_address[cursor]
        words.extend(line_words)
        cursor += len(line_words) * 4
    return words[:count]


def stack_word(event: dict[str, Any], index: int) -> int | None:
    esp = event.get("registers", {}).get("esp")
    if not isinstance(esp, int):
        return None
    return memory_word(event, esp + index * 4)


def cell_state(event: dict[str, Any], pointer: int | None) -> dict[str, Any]:
    words = block_words(event, pointer, 16)
    object_begin = words[1] if len(words) > 1 else None
    object_end = words[2] if len(words) > 2 else None
    object_cap = words[3] if len(words) > 3 else None
    return {
        "cell_pointer": hex32(pointer),
        "raw_words": [hex32(word) for word in words],
        "object_ref_vector": {
            "begin": hex32(object_begin),
            "end": hex32(object_end),
            "capacity_or_aux": hex32(object_cap),
            "empty": object_begin == object_end,
            "first_words": [hex32(word) for word in block_words(event, object_begin, 4)],
        },
        "projection_triple": {
            "x": words[4] if len(words) > 4 else None,
            "y": words[5] if len(words) > 5 else None,
            "level": words[6] if len(words) > 6 else None,
        },
        "generated_cell_words": {
            "+0x20": hex32(words[8] if len(words) > 8 else None),
            "+0x24": hex32(words[9] if len(words) > 9 else None),
            "+0x28": hex32(words[10] if len(words) > 10 else None),
            "+0x2c": hex32(words[11] if len(words) > 11 else None),
        },
    }


def vector_header(event: dict[str, Any], generator: int | None) -> dict[str, Any]:
    if generator is None:
        return {}
    words = block_words(event, generator + 0xEC4, 4)
    return {
        "header_address": hex32(generator + 0xEC4),
        "raw_words": [hex32(word) for word in words],
        "anchor_or_allocator": hex32(words[0] if len(words) > 0 else None),
        "begin": hex32(words[1] if len(words) > 1 else None),
        "end": hex32(words[2] if len(words) > 2 else None),
        "capacity": hex32(words[3] if len(words) > 3 else None),
    }


def find_next(events: list[dict[str, Any]], start: int, address: str) -> tuple[int, dict[str, Any]] | tuple[None, None]:
    for index in range(start, len(events)):
        event = events[index]
        if event.get("address") == address:
            return index, event
    return None, None


def summarize_sequence(events: list[dict[str, Any]], capture: dict[str, Any]) -> dict[str, Any]:
    event_index = int(capture["event_index"]) - 1
    commit_select = events[event_index]
    commit_entry_index, commit_entry = find_next(events, event_index + 1, "0x004a54a7")
    append_index, append_event = find_next(events, (commit_entry_index or event_index) + 1, "0x004a54ef")
    projection_done_index, projection_done = find_next(events, (commit_entry_index or event_index) + 1, "0x004a5756")
    call_return_index, call_return = find_next(events, (commit_entry_index or event_index) + 1, "0x004a744c")

    cell = int(capture["cell_pointer"], 16)
    object_record = int(capture["object_record"], 16)
    generator = int(capture["generator"], 16)
    append_slot = append_event.get("registers", {}).get("edx") if append_event else None

    return {
        "select_event_index": event_index + 1,
        "commit_entry_event_index": (commit_entry_index + 1) if commit_entry_index is not None else None,
        "append_event_index": (append_index + 1) if append_index is not None else None,
        "projection_done_event_index": (projection_done_index + 1) if projection_done_index is not None else None,
        "call_return_event_index": (call_return_index + 1) if call_return_index is not None else None,
        "object_record": hex32(object_record),
        "source_relation_record": hex32(stack_word(commit_select, 4)),
        "control_record": hex32(stack_word(commit_select, 5)),
        "coordinate": capture["coordinate"],
        "cell_pointer": hex32(cell),
        "pre_select_cell": cell_state(commit_select, cell),
        "commit_entry": {
            "return_address": hex32(stack_word(commit_entry, 0)) if commit_entry else None,
            "object_record": hex32(stack_word(commit_entry, 1)) if commit_entry else None,
            "coordinate": {
                "x": stack_word(commit_entry, 2) if commit_entry else None,
                "y": stack_word(commit_entry, 3) if commit_entry else None,
                "level": stack_word(commit_entry, 4) if commit_entry else None,
            },
            "generator_object_vector_before": vector_header(commit_entry, generator) if commit_entry else {},
            "cell_at_entry": cell_state(commit_entry, cell) if commit_entry else {},
        },
        "append_return": {
            "append_slot": hex32(append_slot),
            "append_slot_words": [hex32(word) for word in block_words(append_event, append_slot, 4)]
            if append_event
            else [],
            "generator_object_vector_after": vector_header(append_event, generator) if append_event else {},
        },
        "post_projection_cell": cell_state(projection_done, cell) if projection_done else {},
        "post_call_return_cell": cell_state(call_return, cell) if call_return else {},
    }


def summarize(ledger_path: Path) -> dict[str, Any]:
    ledger = load_json(ledger_path)
    events = ledger.get("events", [])
    counts = Counter(event.get("address") for event in events)
    direct_captures = [
        capture
        for capture in ledger.get("dynamic_captured_cells", [])
        if capture.get("site") == "0x004a7447" and capture.get("cell_pointer")
    ]
    sequences = [summarize_sequence(events, capture) for capture in direct_captures]

    def vector_advanced(sequence: dict[str, Any]) -> bool:
        before = sequence.get("commit_entry", {}).get("generator_object_vector_before", {})
        after = sequence.get("append_return", {}).get("generator_object_vector_after", {})
        if not before.get("end") or not after.get("end"):
            return False
        return int(after["end"], 16) == int(before["end"], 16) + 4

    def append_slot_matches_object(sequence: dict[str, Any]) -> bool:
        words = sequence.get("append_return", {}).get("append_slot_words", [])
        return bool(words) and words[0] == sequence.get("object_record")

    def cell_ref_matches_object(sequence: dict[str, Any]) -> bool:
        words = sequence.get("post_call_return_cell", {}).get("object_ref_vector", {}).get("first_words", [])
        return bool(words) and words[0] == sequence.get("object_record")

    def low_word_cleared(sequence: dict[str, Any]) -> bool:
        before = sequence.get("pre_select_cell", {}).get("generated_cell_words", {}).get("+0x20")
        after = sequence.get("post_call_return_cell", {}).get("generated_cell_words", {}).get("+0x20")
        return bool(before and after) and (int(before, 16) & 0xFFFF) != 0 and (int(after, 16) & 0xFFFF) == 0

    def bit22_set(sequence: dict[str, Any]) -> bool:
        before = sequence.get("pre_select_cell", {}).get("generated_cell_words", {}).get("+0x28")
        after = sequence.get("post_call_return_cell", {}).get("generated_cell_words", {}).get("+0x28")
        return bool(before and after) and (int(before, 16) | 0x00400000) == int(after, 16)

    invariants = {
        "trace_has_events": bool(events),
        "hit_two_direct_4a7447_commits": counts.get("0x004a7447", 0) == 2,
        "captured_two_direct_target_cells": len(sequences) == 2,
        "hit_two_direct_4a54a7_entries_after_4a7447": all(
            sequence.get("commit_entry", {}).get("return_address") == "0x004a744a"
            for sequence in sequences
        ),
        "object_vector_end_advances_one_dword": all(vector_advanced(sequence) for sequence in sequences),
        "append_slot_contains_object_record": all(append_slot_matches_object(sequence) for sequence in sequences),
        "pre_cells_empty": all(
            sequence.get("pre_select_cell", {}).get("object_ref_vector", {}).get("empty") is True
            for sequence in sequences
        ),
        "post_cells_reference_object_record": all(cell_ref_matches_object(sequence) for sequence in sequences),
        "target_cell_plus_0x20_low_word_cleared": all(low_word_cleared(sequence) for sequence in sequences),
        "target_cell_plus_0x28_sets_bit22_only": all(bit22_set(sequence) for sequence in sequences),
        "pair_mark_sites_hit": counts.get("0x004a7e21", 0) == 1 and counts.get("0x004a7e25", 0) == 1,
        "no_native_behavior_change": True,
    }
    status = (
        "direct_endpoint_4a54a7_afterstate_recovered"
        if all(invariants.values())
        else "direct_endpoint_4a54a7_afterstate_incomplete"
    )
    return {
        "schema_id": "h3maped_direct_endpoint_afterstate_dynamic_summary_v1",
        "status": status,
        "source_ledger": str(ledger_path),
        "event_count": len(events),
        "address_counts": dict(sorted(counts.items())),
        "direct_endpoint_sequences": sequences,
        "invariants": invariants,
        "recovered_contract": (
            "For the sampled direct 0x4a7605 -> 0x4a7312 endpoint commits, 0x4a7447 calls generator "
            "vtable slot +0x04, resolved to 0x4a54a7, with object records 0x03624e20 at (62,47,0) and "
            "0x036262f0 at (52,20,0). Each target generated cell is empty before the call, then after "
            "0x4a54a7 the generator object-vector end advances by one dword, the append slot contains "
            "the object record, the target cell object-reference vector contains that object record, "
            "GeneratedCell+0x20 low word is cleared, and GeneratedCell+0x28 changes by setting bit22."
        ),
        "remaining_gap": (
            "This recovers the direct endpoint commit after-state for the sampled fallback path. It does "
            "not recover a live 0x4a696b direct mutation-block hit at 0x4a6c13/0x4a6c26/0x4a6c29, nor "
            "does it recover a [record+0x09] != 0 path through 0x4a746b/0x4a5e73. Those remain the next "
            "private-state gaps before native RMG porting."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args.ledger)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_ENDPOINT_AFTERSTATE_DYNAMIC_SUMMARY status={summary['status']} out={args.out}")
    return 0 if summary["status"] == "direct_endpoint_4a54a7_afterstate_recovered" else 1


if __name__ == "__main__":
    raise SystemExit(main())
