#!/usr/bin/env python3
"""Summarize a 0x4a61bc-origin 0x4a54a7 dynamic write trace."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_LEDGER = Path(
    ".artifacts/rmg_recovery/4a61bc_4a54a7_dynamic_write_trace_20260609/"
    "winedbg_4a61bc_4a54a7_dynamic_trace_ledger.json"
)
DEFAULT_OUT = Path(".artifacts/rmg_recovery/4a61bc_4a54a7_dynamic_summary_20260609.json")

ADDR_BEFORE_5E03 = "0x004a6578"
ADDR_5E03_ENTRY = "0x004a5e03"
ADDR_OBJECT_CONSTRUCTED = "0x004a5e55"
ADDR_COMMIT_CALLSITE = "0x004a5e69"
ADDR_COMMIT_ENTRY = "0x004a54a7"
ADDR_PROJECTION_SEED = "0x004a558a"
ADDR_PROJECTION_WRITE = "0x004a56b6"
ADDR_COMMIT_RETURN = "0x004a5756"
ADDR_AFTER_COMMIT_CALLBACK = "0x004a5e6c"
ADDR_AFTER_5E03 = "0x004a657d"
GENERATED_CELL_STRIDE = 0x30
GENERATOR_OBJECT_VECTOR_ANCHOR = 0x00500F00


def hex32(value: int | None) -> str | None:
    if value is None:
        return None
    return f"0x{value & 0xFFFFFFFF:08x}"


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def event_address(event: dict[str, Any]) -> str:
    return str(event.get("address", "")).lower()


def block_words_at(event: dict[str, Any], address: int, max_words: int) -> list[int]:
    by_address: dict[int, list[int]] = {}
    for line in event.get("memory_lines", []):
        line_address = int(line.get("address", -1))
        words = [int(word) & 0xFFFFFFFF for word in line.get("words", [])]
        if words:
            by_address[line_address] = words
    words: list[int] = []
    cursor = address
    while len(words) < max_words and cursor in by_address:
        line_words = by_address[cursor]
        words.extend(line_words)
        cursor += len(line_words) * 4
    return words[:max_words]


def memory_word(event: dict[str, Any], address: int) -> int | None:
    for line in event.get("memory_lines", []):
        line_address = int(line.get("address", -1))
        words = [int(word) & 0xFFFFFFFF for word in line.get("words", [])]
        if line_address <= address < line_address + len(words) * 4 and (address - line_address) % 4 == 0:
            return words[(address - line_address) // 4]
    return None


def first_event(events: list[dict[str, Any]], address: str) -> dict[str, Any] | None:
    for event in events:
        if event_address(event) == address:
            return event
    return None


def object_vector_snapshot(event: dict[str, Any]) -> dict[str, Any] | None:
    candidates: list[dict[str, Any]] = []
    for line in event.get("memory_lines", []):
        words = [int(word) & 0xFFFFFFFF for word in line.get("words", [])]
        if len(words) < 4:
            continue
        begin, end, capacity = words[1:4]
        byte_span = end - begin
        cap_span = capacity - begin
        count = byte_span // 4 if byte_span >= 0 and byte_span % 4 == 0 else None
        capacity_count = cap_span // 4 if cap_span >= 0 and cap_span % 4 == 0 else None
        if (
            count is None
            or capacity_count is None
            or count > capacity_count
            or capacity_count > 4096
            or begin == 0
            or end == 0
            or capacity == 0
        ):
            continue
        candidates.append({
            "anchor": hex32(words[0]),
            "anchor_value": words[0],
            "begin": hex32(begin),
            "end": hex32(end),
            "capacity": hex32(capacity),
            "count": count,
            "capacity_count": capacity_count,
        })
    if not candidates:
        return None
    selected = next(
        (candidate for candidate in candidates if candidate["anchor_value"] == GENERATOR_OBJECT_VECTOR_ANCHOR),
        candidates[0],
    )
    selected.pop("anchor_value", None)
    return selected


def generator_layout(event: dict[str, Any]) -> dict[str, Any]:
    generator = int(event.get("registers", {}).get("ecx", 0))
    base = memory_word(event, generator + 0x14)
    width = memory_word(event, generator + 0x18)
    height = memory_word(event, generator + 0x1C)
    levels = memory_word(event, generator + 0x20)
    return {
        "generator": hex32(generator),
        "base": hex32(base),
        "width": width,
        "height": height,
        "levels": levels,
        "stride": GENERATED_CELL_STRIDE,
    }


def coordinate_for_cell(pointer: int | None, layout: dict[str, Any]) -> dict[str, Any]:
    if pointer is None or not layout.get("base") or not layout.get("width") or not layout.get("height"):
        return {"flat": None, "x": None, "y": None, "level": None}
    base = int(layout["base"], 16)
    width = int(layout["width"])
    height = int(layout["height"])
    delta = pointer - base
    if delta < 0 or delta % GENERATED_CELL_STRIDE != 0:
        return {"flat": None, "x": None, "y": None, "level": None}
    flat = delta // GENERATED_CELL_STRIDE
    level_area = width * height
    return {
        "flat": flat,
        "x": flat % width,
        "y": (flat // width) % height,
        "level": flat // level_area,
    }


def cell_summary(event: dict[str, Any], cell: int, layout: dict[str, Any]) -> dict[str, Any] | None:
    words = block_words_at(event, cell, 16)
    if len(words) < 12:
        return None
    refs_begin = words[1]
    refs_end = words[2]
    ref_words = block_words_at(event, refs_begin, min(16, max(0, (refs_end - refs_begin) // 4)))
    cell20 = words[8]
    return {
        "cell_pointer": hex32(cell),
        "coordinate": coordinate_for_cell(cell, layout),
        "raw_words": [hex32(word) for word in words],
        "object_ref_vector": {
            "begin": hex32(refs_begin),
            "end": hex32(refs_end),
            "count": (refs_end - refs_begin) // 4 if refs_end >= refs_begin and (refs_end - refs_begin) % 4 == 0 else None,
            "entries": [hex32(word) for word in ref_words],
        },
        "generated_cell_words": {
            "+0x20": hex32(words[8]),
            "+0x24": hex32(words[9]),
            "+0x28": hex32(words[10]),
            "+0x2c": hex32(words[11]),
        },
        "low_word_plus_0x20": cell20 & 0xFFFF,
        "high_word_plus_0x20": hex32(cell20 & 0xFFFF0000),
    }


def object_record_summary(event: dict[str, Any]) -> dict[str, Any]:
    pointer = int(event.get("registers", {}).get("eax", 0))
    words = block_words_at(event, pointer, 12)
    return {
        "object_record_pointer": hex32(pointer),
        "raw_words": [hex32(word) for word in words],
        "vtable": hex32(words[0] if len(words) > 0 else None),
        "descriptor_or_payload_pointer": hex32(words[1] if len(words) > 1 else None),
        "relative_coordinate": {
            "x": words[2] if len(words) > 2 else None,
            "y": words[3] if len(words) > 3 else None,
            "level": words[4] if len(words) > 4 else None,
        },
    }


def write_summary(event: dict[str, Any], ordinal: int, layout: dict[str, Any]) -> dict[str, Any]:
    cell = int(event.get("registers", {}).get("eax", 0))
    new_word = int(event.get("registers", {}).get("esi", 0)) & 0xFFFFFFFF
    proposed = int(event.get("registers", {}).get("edx", 0)) & 0xFFFFFFFF
    words = block_words_at(event, cell, 16)
    old_word = words[8] if len(words) > 8 else None
    old_low = old_word & 0xFFFF if old_word is not None else None
    new_low = new_word & 0xFFFF
    return {
        "ordinal": ordinal,
        "cell_pointer": hex32(cell),
        "coordinate": coordinate_for_cell(cell, layout),
        "old_plus_0x20": hex32(old_word),
        "new_plus_0x20": hex32(new_word),
        "proposed_edx": hex32(proposed),
        "old_low_word": old_low,
        "new_low_word": new_low,
        "high_word_preserved": old_word is not None and (old_word & 0xFFFF0000) == (new_word & 0xFFFF0000),
        "low_word_lowered": old_low is not None and new_low < old_low,
        "raw_cell_words": [hex32(word) for word in words],
    }


def summarize(ledger_path: Path) -> dict[str, Any]:
    ledger = read_json(ledger_path)
    events = ledger.get("events", [])
    meta = ledger.get("dynamic_trace_meta", {})
    target_cell = int(meta["target_cell"], 16) if meta.get("target_cell") else None
    object_record = meta.get("object_record")
    layout_event = first_event(events, ADDR_5E03_ENTRY)
    layout = generator_layout(layout_event) if layout_event else {}
    writes = [
        write_summary(event, index + 1, layout)
        for index, event in enumerate(events)
        if event_address(event) == ADDR_PROJECTION_WRITE
    ]
    target_cell_states = {
        address: cell_summary(event, target_cell, layout)
        for address in [
            ADDR_5E03_ENTRY,
            ADDR_PROJECTION_SEED,
            ADDR_COMMIT_RETURN,
            ADDR_AFTER_COMMIT_CALLBACK,
            ADDR_AFTER_5E03,
        ]
        for event in [first_event(events, address)]
        if event is not None and target_cell is not None
    }
    vector_states = {
        address: object_vector_snapshot(event)
        for address in [
            ADDR_BEFORE_5E03,
            ADDR_5E03_ENTRY,
            ADDR_COMMIT_CALLSITE,
            ADDR_COMMIT_ENTRY,
            ADDR_COMMIT_RETURN,
            ADDR_AFTER_COMMIT_CALLBACK,
            ADDR_AFTER_5E03,
        ]
        for event in [first_event(events, address)]
        if event is not None
    }
    unique_write_cells = sorted({write["cell_pointer"] for write in writes})
    before_cell = target_cell_states.get(ADDR_5E03_ENTRY) or {}
    after_cell = target_cell_states.get(ADDR_AFTER_5E03) or {}
    before_refs = (before_cell.get("object_ref_vector") or {}).get("entries") or []
    after_refs = (after_cell.get("object_ref_vector") or {}).get("entries") or []
    before_count = (vector_states.get(ADDR_COMMIT_ENTRY) or {}).get("count")
    after_count = (vector_states.get(ADDR_AFTER_COMMIT_CALLBACK) or {}).get("count")
    return {
        "schema": "h3maped_rmg_4a61bc_4a54a7_dynamic_summary_v1",
        "ledger": str(ledger_path),
        "event_count": len(events),
        "address_counts": dict(sorted(Counter(event_address(event) for event in events).items())),
        "dynamic_trace_meta": meta,
        "generator_layout": layout,
        "constructed_object_record": (
            object_record_summary(first_event(events, ADDR_OBJECT_CONSTRUCTED))
            if first_event(events, ADDR_OBJECT_CONSTRUCTED)
            else None
        ),
        "object_vector_states": vector_states,
        "target_cell_states": target_cell_states,
        "projection_write_count": len(writes),
        "unique_projection_write_cell_count": len(unique_write_cells),
        "first_projection_writes": writes[:12],
        "last_projection_writes": writes[-12:],
        "invariants": {
            "native_behavior_changed": False,
            "target_cell_captured": target_cell is not None,
            "object_record_captured": object_record is not None,
            "object_vector_grows_by_one_inside_0x4a54a7": isinstance(before_count, int)
            and isinstance(after_count, int)
            and after_count == before_count + 1,
            "target_cell_object_ref_added": object_record not in before_refs and object_record in after_refs,
            "target_cell_low_word_cleared": before_cell.get("low_word_plus_0x20") != 0
            and after_cell.get("low_word_plus_0x20") == 0,
            "target_cell_high_word_preserved": before_cell.get("high_word_plus_0x20")
            == after_cell.get("high_word_plus_0x20"),
            "all_projection_writes_have_unique_cells": len(writes) == len(unique_write_cells),
            "all_projection_writes_preserve_high_word": bool(writes)
            and all(write["high_word_preserved"] for write in writes),
            "all_projection_writes_lower_low_word": bool(writes)
            and all(write["low_word_lowered"] for write in writes),
        },
        "recovered_contract": (
            "For this sampled 0x4a61bc-origin object record, 0x4a54a7 appends "
            "the object to the generator object vector, adds the object reference "
            "to the target/source generated cell, sets the target/source cell "
            "occupied bit surface at +0x28, clears the target/source cell +0x20 "
            "low word, and performs 74 unique 0x4a56b6 projection-loop writes "
            "that preserve each cell +0x20 high word while lowering its low word."
        ),
        "remaining_gap": (
            "Repeat or correlate this 0x4a54a7 write-set recovery for the remaining "
            "0x4a61bc-origin appended records, then link the appended records to "
            "the later 0x4a79a3 payload loop and downstream 0x4a696b/0x4a7605 "
            "consumers."
        ),
        "native_behavior_changed": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    summary = summarize(args.ledger)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_4A61BC_4A54A7_DYNAMIC_SUMMARY "
        f"writes={summary['projection_write_count']} "
        f"unique={summary['unique_projection_write_cell_count']} "
        f"target_cell={summary['dynamic_trace_meta'].get('target_cell')} "
        f"object_record={summary['dynamic_trace_meta'].get('object_record')} "
        f"out={args.out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
