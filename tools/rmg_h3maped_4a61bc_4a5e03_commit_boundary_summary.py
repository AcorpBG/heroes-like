#!/usr/bin/env python3
"""Summarize 0x4a61bc -> 0x4a5e03 -> 0x4a54a7 commit boundaries.

This is recovery evidence only. It narrows the sampled object-vector append
delegated from 0x4a61bc to the 0x4a54a7 commit callback reached by 0x4a5e03.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_LEDGER = Path(
    ".artifacts/rmg_recovery/4a61bc_4a5e03_commit_boundary_trace_20260609/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_OUT = Path(
    ".artifacts/rmg_recovery/4a61bc_4a5e03_commit_boundary_summary_20260609.json"
)

ADDR_BEFORE_5E03 = "0x004a6578"
ADDR_5E03_ENTRY = "0x004a5e03"
ADDR_CELL_COMPUTED = "0x004a5e2b"
ADDR_PRE_COMMIT_CELL = "0x004a5e4a"
ADDR_OBJECT_CONSTRUCTED = "0x004a5e55"
ADDR_OBJECT_BRANCH = "0x004a5e59"
ADDR_COMMIT_CALLSITE = "0x004a5e69"
ADDR_COMMIT_ENTRY = "0x004a54a7"
ADDR_PROJECTION_SEED = "0x004a558a"
ADDR_COMMIT_RETURN = "0x004a5756"
ADDR_AFTER_COMMIT_CALLBACK = "0x004a5e6c"
ADDR_AFTER_5E03 = "0x004a657d"


def hex32(value: int | None) -> str | None:
    if value is None:
        return None
    return f"0x{value & 0xFFFFFFFF:08x}"


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def event_address(event: dict[str, Any]) -> str:
    return str(event.get("address", "")).lower()


def memory_line_at(event: dict[str, Any], address: int) -> list[int] | None:
    for line in event.get("memory_lines", []):
        if line.get("address") == address:
            return list(line.get("words", []))
    return None


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


def first_words(event: dict[str, Any]) -> list[int]:
    if not event.get("memory_lines"):
        return []
    return [int(word) & 0xFFFFFFFF for word in event["memory_lines"][0].get("words", [])]


def event_generator(event: dict[str, Any]) -> int | None:
    registers = event.get("registers", {})
    address = event_address(event)
    if address in {
        ADDR_BEFORE_5E03,
        ADDR_5E03_ENTRY,
        ADDR_COMMIT_CALLSITE,
        ADDR_COMMIT_ENTRY,
        ADDR_AFTER_COMMIT_CALLBACK,
        ADDR_AFTER_5E03,
    }:
        return registers.get("ecx") if address in {ADDR_5E03_ENTRY, ADDR_COMMIT_CALLSITE, ADDR_COMMIT_ENTRY} else registers.get("ebx")
    return None


def object_vector_snapshot(event: dict[str, Any]) -> dict[str, Any] | None:
    generator = event_generator(event)
    if generator is None:
        return None
    words = memory_line_at(event, generator + 0xEC4)
    if not words or len(words) < 4:
        return None
    anchor, begin, end, capacity = words[:4]
    byte_span = end - begin
    cap_span = capacity - begin
    count = byte_span // 4 if byte_span >= 0 and byte_span % 4 == 0 else None
    capacity_count = cap_span // 4 if cap_span >= 0 and cap_span % 4 == 0 else None
    return {
        "generator": hex32(generator),
        "anchor": hex32(anchor),
        "begin": hex32(begin),
        "end": hex32(end),
        "capacity": hex32(capacity),
        "count": count,
        "capacity_count": capacity_count,
    }


def stack_args_5e03(event: dict[str, Any]) -> dict[str, Any]:
    words = first_words(event)
    level_words = (
        event.get("memory_lines", [{}])[1].get("words", [])
        if len(event.get("memory_lines", [])) > 1
        else []
    )
    return {
        "return_address": hex32(words[0] if len(words) > 0 else None),
        "arg0": hex32(words[1] if len(words) > 1 else None),
        "x": words[2] if len(words) > 2 else None,
        "y": words[3] if len(words) > 3 else None,
        "level": int(level_words[0]) & 0xFFFFFFFF if level_words else None,
    }


def stack_args_commit(event: dict[str, Any]) -> dict[str, Any]:
    words = first_words(event)
    return {
        "return_address": hex32(words[0] if event_address(event) == ADDR_COMMIT_ENTRY and len(words) > 0 else None),
        "object_record_pointer": hex32(words[1] if event_address(event) == ADDR_COMMIT_ENTRY and len(words) > 1 else words[0] if len(words) > 0 else None),
        "x": words[2] if event_address(event) == ADDR_COMMIT_ENTRY and len(words) > 2 else words[1] if len(words) > 1 else None,
        "y": words[3] if event_address(event) == ADDR_COMMIT_ENTRY and len(words) > 3 else words[2] if len(words) > 2 else None,
        "level": (
            event.get("memory_lines", [{}])[1].get("words", [None])[0]
            if event_address(event) == ADDR_COMMIT_ENTRY and len(event.get("memory_lines", [])) > 1
            else words[3] if len(words) > 3 else None
        ),
    }


def cell_summary(event: dict[str, Any]) -> dict[str, Any]:
    pointer = int(event.get("registers", {}).get("eax", 0))
    words = block_words_at(event, pointer, 16)
    cell20 = words[8] if len(words) > 8 else None
    owner = ((cell20 or 0) >> 16) & 0xFF if cell20 is not None else None
    if owner is not None and owner >= 0x80:
        owner -= 0x100
    return {
        "cell_pointer": hex32(pointer),
        "raw_words": [hex32(word) for word in words],
        "object_ref_vector": {
            "begin": hex32(words[1] if len(words) > 1 else None),
            "end": hex32(words[2] if len(words) > 2 else None),
            "empty": len(words) > 2 and words[1] == words[2],
        },
        "generated_cell_words": {
            "+0x20": hex32(words[8] if len(words) > 8 else None),
            "+0x24": hex32(words[9] if len(words) > 9 else None),
            "+0x28": hex32(words[10] if len(words) > 10 else None),
            "+0x2c": hex32(words[11] if len(words) > 11 else None),
        },
        "owner_relation_index_from_plus_0x20_byte2": owner,
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
        "descriptor_type_word_plus_0x1c": hex32(words[7] if len(words) > 7 else None),
    }


def event_summary(index: int, event: dict[str, Any]) -> dict[str, Any]:
    registers = event.get("registers", {})
    return {
        "event_index": index,
        "address": event_address(event),
        "eax": hex32(registers.get("eax")),
        "ebx": hex32(registers.get("ebx")),
        "ecx": hex32(registers.get("ecx")),
        "edx": hex32(registers.get("edx")),
        "esi": hex32(registers.get("esi")),
        "edi": hex32(registers.get("edi")),
        "object_vector": object_vector_snapshot(event),
        "stack_5e03_args": stack_args_5e03(event) if event_address(event) == ADDR_5E03_ENTRY else None,
        "commit_stack_args": stack_args_commit(event) if event_address(event) in {ADDR_COMMIT_CALLSITE, ADDR_COMMIT_ENTRY} else None,
        "cell": cell_summary(event) if event_address(event) in {ADDR_CELL_COMPUTED, ADDR_PRE_COMMIT_CELL, ADDR_PROJECTION_SEED} else None,
        "object_record": object_record_summary(event) if event_address(event) in {ADDR_OBJECT_CONSTRUCTED, ADDR_OBJECT_BRANCH} else None,
    }


def group_sequences(events: list[dict[str, Any]]) -> list[list[dict[str, Any]]]:
    groups: list[list[dict[str, Any]]] = []
    current: list[dict[str, Any]] = []
    for index, event in enumerate(events):
        item = event_summary(index, event)
        address = item["address"]
        if address == ADDR_BEFORE_5E03:
            if current:
                groups.append(current)
            current = [item]
        elif current:
            current.append(item)
            if address == ADDR_AFTER_5E03:
                groups.append(current)
                current = []
    if current:
        groups.append(current)
    return groups


def first_item(group: list[dict[str, Any]], address: str) -> dict[str, Any] | None:
    for item in group:
        if item["address"] == address:
            return item
    return None


def count_at(group: list[dict[str, Any]], address: str) -> int | None:
    item = first_item(group, address)
    vector = (item or {}).get("object_vector") or {}
    count = vector.get("count")
    return count if isinstance(count, int) else None


def summarize_sequence(index: int, group: list[dict[str, Any]]) -> dict[str, Any]:
    constructed = first_item(group, ADDR_OBJECT_CONSTRUCTED)
    commit_callsite = first_item(group, ADDR_COMMIT_CALLSITE)
    commit_entry = first_item(group, ADDR_COMMIT_ENTRY)
    entry_args = (first_item(group, ADDR_5E03_ENTRY) or {}).get("stack_5e03_args") or {}
    commit_args = (commit_entry or {}).get("commit_stack_args") or {}
    object_pointer = (constructed or {}).get("object_record", {}).get("object_record_pointer")
    vector_counts = {
        "before_0x4a5e03": count_at(group, ADDR_BEFORE_5E03),
        "at_0x4a5e03_entry": count_at(group, ADDR_5E03_ENTRY),
        "at_0x4a5e69_commit_callsite": count_at(group, ADDR_COMMIT_CALLSITE),
        "at_0x4a54a7_entry": count_at(group, ADDR_COMMIT_ENTRY),
        "after_0x4a54a7_return": count_at(group, ADDR_AFTER_COMMIT_CALLBACK),
        "after_0x4a5e03_return": count_at(group, ADDR_AFTER_5E03),
    }
    return {
        "sequence_index": index,
        "event_indexes": [item["event_index"] for item in group],
        "addresses": [item["address"] for item in group],
        "complete": all(
            first_item(group, address) is not None
            for address in [
                ADDR_BEFORE_5E03,
                ADDR_5E03_ENTRY,
                ADDR_PRE_COMMIT_CELL,
                ADDR_OBJECT_CONSTRUCTED,
                ADDR_COMMIT_CALLSITE,
                ADDR_COMMIT_ENTRY,
                ADDR_COMMIT_RETURN,
                ADDR_AFTER_COMMIT_CALLBACK,
                ADDR_AFTER_5E03,
            ]
        ),
        "entry_args": entry_args,
        "constructed_object_record": (constructed or {}).get("object_record"),
        "pre_commit_cell": (first_item(group, ADDR_PRE_COMMIT_CELL) or {}).get("cell"),
        "commit_callsite_args": (commit_callsite or {}).get("commit_stack_args"),
        "commit_entry_args": commit_args,
        "projection_seed_cell": (first_item(group, ADDR_PROJECTION_SEED) or {}).get("cell"),
        "vector_counts": vector_counts,
        "object_pointer_matches_commit_entry": object_pointer == commit_args.get("object_record_pointer"),
        "entry_coordinate_matches_commit_entry": (
            entry_args.get("x") == commit_args.get("x")
            and entry_args.get("y") == commit_args.get("y")
            and entry_args.get("level") == commit_args.get("level")
        ),
        "growth_by_0x4a54a7_return": (
            isinstance(vector_counts["at_0x4a54a7_entry"], int)
            and isinstance(vector_counts["after_0x4a54a7_return"], int)
            and vector_counts["after_0x4a54a7_return"] > vector_counts["at_0x4a54a7_entry"]
        ),
        "growth_between_0x4a5e03_entry_and_0x4a54a7_entry": (
            isinstance(vector_counts["at_0x4a5e03_entry"], int)
            and isinstance(vector_counts["at_0x4a54a7_entry"], int)
            and vector_counts["at_0x4a54a7_entry"] > vector_counts["at_0x4a5e03_entry"]
        ),
    }


def summarize(ledger_path: Path) -> dict[str, Any]:
    ledger = read_json(ledger_path)
    events = ledger.get("events", [])
    groups = group_sequences(events)
    sequences = [summarize_sequence(index, group) for index, group in enumerate(groups)]
    complete = [sequence for sequence in sequences if sequence["complete"]]
    return {
        "schema": "h3maped_rmg_4a61bc_4a5e03_commit_boundary_summary_v1",
        "ledger": str(ledger_path),
        "event_count": len(events),
        "address_counts": dict(sorted(Counter(event_address(event) for event in events).items())),
        "child_returncode": ledger.get("child_returncode"),
        "caller_framed_sequence_count": len(sequences),
        "complete_sequence_count": len(complete),
        "complete_sequences_growing_by_0x4a54a7_return": sum(
            1 for sequence in complete if sequence["growth_by_0x4a54a7_return"]
        ),
        "complete_sequences_with_pre_commit_growth": sum(
            1 for sequence in complete if sequence["growth_between_0x4a5e03_entry_and_0x4a54a7_entry"]
        ),
        "complete_sequences_object_pointer_matches_commit": sum(
            1 for sequence in complete if sequence["object_pointer_matches_commit_entry"]
        ),
        "complete_sequences_coordinate_matches_commit": sum(
            1 for sequence in complete if sequence["entry_coordinate_matches_commit_entry"]
        ),
        "sequences": sequences,
        "recovered_contract": (
            "In the sampled caller-framed 0x4a61bc sequences, 0x4a5e03 receives "
            "the same coordinate later passed to generator vtable slot +0x04 / "
            "0x4a54a7. The constructed object record pointer is passed unchanged "
            "to 0x4a54a7. The generator object vector is stable at 0x4a5e03 entry, "
            "0x4a5e69, and 0x4a54a7 entry, then has grown by the 0x4a5e6c return "
            "from the 0x4a54a7 callback. This narrows the sampled append to the "
            "0x4a54a7 commit callback rather than 0x4a5e03 setup code."
        ),
        "remaining_gap": (
            "Recover the generated-cell write set and after-state inside 0x4a54a7 "
            "for these 0x4a61bc-origin records, then link the appended records to "
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
        "RMG_H3MAPED_4A61BC_4A5E03_COMMIT_BOUNDARY_SUMMARY "
        f"sequences={summary['caller_framed_sequence_count']} "
        f"complete={summary['complete_sequence_count']} "
        f"growth_by_0x4a54a7_return={summary['complete_sequences_growing_by_0x4a54a7_return']} "
        f"pre_commit_growth={summary['complete_sequences_with_pre_commit_growth']} "
        f"out={args.out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
