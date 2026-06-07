#!/usr/bin/env python3
"""Summarize live H3MapEd 0x4aa3e9 source-conditional mutation traces."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ENTRY = "0x004aa3e9"
SOURCE_BIT27_CLEAR_CALL = "0x004aa58d"
AFTER_SOURCE_BIT27_CLEAR = "0x004aa596"
SOURCE_BIT26_SET_CALL = "0x004aa5a0"


def normalize_address(value: Any) -> str:
    return "0x%08x" % int(str(value), 0)


def event_memory(event: dict[str, Any]) -> dict[int, int]:
    memory: dict[int, int] = {}
    for line in event.get("memory_lines", []):
        base = int(line.get("address", 0))
        for offset, word in enumerate(line.get("words", [])):
            memory[base + offset * 4] = int(word) & 0xFFFFFFFF
    return memory


def word(memory: dict[int, int], address: int) -> int | None:
    value = memory.get(address)
    return int(value) if value is not None else None


def hex32(value: int | None) -> str:
    return "0x%08x" % value if value is not None else ""


def signed32(value: int | None) -> int | None:
    if value is None:
        return None
    value &= 0xFFFFFFFF
    return value - 0x100000000 if value & 0x80000000 else value


def stack_words(event: dict[str, Any]) -> list[int]:
    registers = event.get("registers", {})
    esp = registers.get("esp")
    if not isinstance(esp, int):
        return []
    memory = event_memory(event)
    return [word(memory, esp + offset * 4) or 0 for offset in range(8)]


def cell_state(event: dict[str, Any], register: str) -> dict[str, Any]:
    registers = event.get("registers", {})
    pointer = registers.get(register)
    memory = event_memory(event)
    w24 = word(memory, pointer + 0x24) if isinstance(pointer, int) else None
    w28 = word(memory, pointer + 0x28) if isinstance(pointer, int) else None
    return {
        "cell": hex32(pointer),
        "w20": hex32(word(memory, pointer + 0x20) if isinstance(pointer, int) else None),
        "w24": hex32(w24),
        "w28": hex32(w28),
        "terrain_low6": (w24 & 0x3F) if isinstance(w24, int) else None,
        "bit22": bool((w28 or 0) & 0x00400000),
        "bit25": bool((w28 or 0) & 0x02000000),
        "bit26": bool((w28 or 0) & 0x04000000),
        "bit27": bool((w28 or 0) & 0x08000000),
    }


def local_state(event: dict[str, Any]) -> dict[str, Any]:
    registers = event.get("registers", {})
    ebp = registers.get("ebp")
    memory = event_memory(event)
    if not isinstance(ebp, int):
        return {}
    return {
        "selected_x": signed32(word(memory, ebp + 0x0C)),
        "selected_y": signed32(word(memory, ebp + 0x10)),
        "selected_level": signed32(word(memory, ebp + 0x14)),
        "local_x": signed32(word(memory, ebp - 0x14)),
        "local_y": signed32(word(memory, ebp - 0x10)),
    }


def entry_state(event: dict[str, Any], event_index: int) -> dict[str, Any]:
    stack = stack_words(event)
    return {
        "event_index": event_index,
        "wrapper": hex32(stack[1] if len(stack) > 1 else None),
        "selected_coordinate_arg": {
            "x": signed32(stack[2] if len(stack) > 2 else None),
            "y": signed32(stack[3] if len(stack) > 3 else None),
            "level": signed32(stack[4] if len(stack) > 4 else None),
        },
    }


def snapshot(event: dict[str, Any], event_index: int) -> dict[str, Any]:
    return {
        "event_index": event_index,
        "source": cell_state(event, "esi"),
        "destination": cell_state(event, "edi"),
        "locals": local_state(event),
    }


def summarize(ledger: dict[str, Any]) -> dict[str, Any]:
    calls: list[dict[str, Any]] = []
    current_call: dict[str, Any] | None = None
    pending_clear: dict[str, Any] | None = None
    clear_pairs: list[dict[str, Any]] = []
    source_set_entries: list[dict[str, Any]] = []
    orphan_events: list[dict[str, Any]] = []
    incomplete_clear_count = 0

    for event_index, event in enumerate(ledger.get("events", []), start=1):
        address = normalize_address(event.get("address", "0"))
        if address == ENTRY:
            if current_call is not None:
                calls.append(current_call)
            current_call = {"entry": entry_state(event, event_index), "clear_pairs": [], "source_set_entries": []}
            pending_clear = None
            continue
        if current_call is None:
            orphan_events.append({"event_index": event_index, "address": address})
            continue
        if address == SOURCE_BIT27_CLEAR_CALL:
            if pending_clear is not None:
                incomplete_clear_count += 1
            pending_clear = snapshot(event, event_index)
        elif address == AFTER_SOURCE_BIT27_CLEAR:
            after_clear = snapshot(event, event_index)
            if pending_clear is None:
                incomplete_clear_count += 1
            else:
                pair = {"before_clear": pending_clear, "after_clear": after_clear}
                current_call["clear_pairs"].append(pair)
                clear_pairs.append(pair)
                pending_clear = None
        elif address == SOURCE_BIT26_SET_CALL:
            set_entry = snapshot(event, event_index)
            current_call["source_set_entries"].append(set_entry)
            source_set_entries.append(set_entry)

    if pending_clear is not None:
        incomplete_clear_count += 1
    if current_call is not None:
        calls.append(current_call)

    clear_mismatches: list[dict[str, Any]] = []
    for index, pair in enumerate(clear_pairs, start=1):
        before = pair["before_clear"]
        after = pair["after_clear"]
        if (
            before["source"]["cell"] != after["source"]["cell"]
            or before["destination"]["cell"] != after["destination"]["cell"]
            or after["source"]["bit27"]
            or before["source"]["bit26"] != after["source"]["bit26"]
        ):
            clear_mismatches.append({"pair_index": index, "before": before, "after": after})

    set_entry_mismatches: list[dict[str, Any]] = []
    cleared_source_cells = {pair["after_clear"]["source"]["cell"] for pair in clear_pairs}
    for index, entry in enumerate(source_set_entries, start=1):
        if entry["source"]["cell"] not in cleared_source_cells or entry["source"]["bit27"]:
            set_entry_mismatches.append({"entry_index": index, "entry": entry})

    return {
        "schema_id": "h3maped_4aa3e9_source_conditional_summary_v1",
        "ledger": ledger.get("log_path", ""),
        "event_count": int(ledger.get("event_count", 0)),
        "breakpoints": ledger.get("breakpoints", []),
        "addresses": {
            "entry": ENTRY,
            "source_bit27_clear_call": SOURCE_BIT27_CLEAR_CALL,
            "after_source_bit27_clear": AFTER_SOURCE_BIT27_CLEAR,
            "source_bit26_set_call": SOURCE_BIT26_SET_CALL,
        },
        "call_count": len(calls),
        "clear_pair_count": len(clear_pairs),
        "source_set_entry_count": len(source_set_entries),
        "incomplete_clear_count": incomplete_clear_count,
        "orphan_event_count": len(orphan_events),
        "clear_mismatches": clear_mismatches,
        "source_set_entry_mismatches": set_entry_mismatches,
        "first_clear_pair": clear_pairs[0] if clear_pairs else None,
        "first_source_set_entry": source_set_entries[0] if source_set_entries else None,
        "calls_prefix": calls[:4],
        "invariants": {
            "has_clear_pairs": bool(clear_pairs),
            "source_bit27_clear_pairs_match": not clear_mismatches,
            "has_source_set_branch_entries": bool(source_set_entries),
            "source_set_entries_follow_cleared_source_cells": not set_entry_mismatches,
            "no_orphan_events": not orphan_events,
        },
        "notes": [
            "0x4aa58d captures source ESI and destination EDI immediately before 0x49a932(source, false).",
            "0x4aa596 captures the same pair after the source bit27-clear call and before the optional source bit26-set branch.",
            "0x4aa5a0 captures entry to the optional 0x49aa63(source, true) branch. This trace does not include the after-set site, so source bit26 after-set parity remains pending.",
        ],
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    ledger = json.loads(args.ledger.read_text(encoding="utf-8"))
    summary = summarize(ledger)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    status = "pass" if all(summary["invariants"].values()) else "partial"
    print(
        "RMG_H3MAPED_4AA3E9_SOURCE_CONDITIONAL_SUMMARY "
        f"status={status} clear_pairs={summary['clear_pair_count']} "
        f"source_set_entries={summary['source_set_entry_count']} out={args.out}"
    )
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
