#!/usr/bin/env python3
"""Summarize live H3MapEd 0x49d69d selected-member stamp traces."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ENTRY = "0x0049d69d"
VECTOR_APPEND = "0x0049d6af"
STAMP_CALL = "0x0049d6d4"
AFTER_STAMP = "0x0049d6d9"


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


def signed32(value: int | None) -> int | None:
    if value is None:
        return None
    value &= 0xFFFFFFFF
    return value - 0x100000000 if value & 0x80000000 else value


def hex32(value: int | None) -> str:
    return "0x%08x" % value if value is not None else ""


def dword_vector_snapshot(memory: dict[int, int], wrapper: int) -> dict[str, Any]:
    begin = word(memory, wrapper + 0x2C)
    end = word(memory, wrapper + 0x30)
    capacity = word(memory, wrapper + 0x34)
    count = None
    if begin is not None and end is not None and end >= begin and (end - begin) % 4 == 0:
        count = (end - begin) // 4
    return {
        "begin": hex32(begin),
        "end": hex32(end),
        "capacity": hex32(capacity),
        "count": count,
    }


def coordinate_vector_snapshot(memory: dict[int, int], wrapper: int) -> dict[str, Any]:
    begin = word(memory, wrapper + 0x3C)
    end = word(memory, wrapper + 0x40)
    capacity = word(memory, wrapper + 0x44)
    count = None
    if begin is not None and end is not None and end >= begin and (end - begin) % 8 == 0:
        count = (end - begin) // 8
    return {
        "begin": hex32(begin),
        "end": hex32(end),
        "capacity": hex32(capacity),
        "count": count,
    }


def entry_snapshot(index: int, event: dict[str, Any]) -> dict[str, Any]:
    registers = event.get("registers", {})
    esp = int(registers.get("esp", 0))
    wrapper = int(registers.get("ecx", 0))
    memory = event_memory(event)
    return {
        "event_index": index,
        "wrapper": hex32(wrapper),
        "return_address": hex32(word(memory, esp)),
        "member_pointer": hex32(word(memory, esp + 0x04)),
        "selected_coordinate": {
            "x": signed32(word(memory, esp + 0x08)),
            "y": signed32(word(memory, esp + 0x0C)),
        },
        "selected_member_vector_before": dword_vector_snapshot(memory, wrapper),
        "candidate_coordinate_vector_before": coordinate_vector_snapshot(memory, wrapper),
        "wrapper_bounds": {
            "min_x": signed32(word(memory, wrapper + 0x18)),
            "min_y": signed32(word(memory, wrapper + 0x1C)),
            "max_x": signed32(word(memory, wrapper + 0x20)),
            "max_y": signed32(word(memory, wrapper + 0x24)),
        },
    }


def vector_append_snapshot(index: int, event: dict[str, Any]) -> dict[str, Any]:
    registers = event.get("registers", {})
    wrapper = int(registers.get("ebx", 0))
    ebp = int(registers.get("ebp", 0))
    memory = event_memory(event)
    return {
        "event_index": index,
        "wrapper": hex32(wrapper),
        "source_pointer_eax": hex32(int(registers.get("eax", 0))),
        "member_pointer_arg": hex32(word(memory, ebp + 0x08)),
        "selected_coordinate_args": {
            "x": signed32(word(memory, ebp + 0x0C)),
            "y": signed32(word(memory, ebp + 0x10)),
        },
        "selected_member_vector_before_append": dword_vector_snapshot(memory, wrapper),
        "candidate_coordinate_vector_before_append": coordinate_vector_snapshot(memory, wrapper),
    }


def stamp_call_snapshot(index: int, event: dict[str, Any]) -> dict[str, Any]:
    registers = event.get("registers", {})
    esp = int(registers.get("esp", 0))
    ebp = int(registers.get("ebp", 0))
    wrapper = int(registers.get("ecx", registers.get("ebx", 0)))
    memory = event_memory(event)
    return {
        "event_index": index,
        "wrapper": hex32(wrapper),
        "member_pointer_stack": hex32(word(memory, esp)),
        "stamp_coordinate_stack": {
            "x": signed32(word(memory, esp + 0x04)),
            "y": signed32(word(memory, esp + 0x08)),
            "z": signed32(word(memory, esp + 0x0C)),
        },
        "local_coordinate": {
            "x": signed32(word(memory, ebp - 0x0C)),
            "y": signed32(word(memory, ebp - 0x08)),
            "z": signed32(word(memory, ebp - 0x04)),
        },
    }


def after_stamp_snapshot(index: int, event: dict[str, Any]) -> dict[str, Any]:
    registers = event.get("registers", {})
    wrapper = int(registers.get("ebx", 0))
    ebp = int(registers.get("ebp", 0))
    memory = event_memory(event)
    return {
        "event_index": index,
        "wrapper": hex32(wrapper),
        "return_eax": hex32(int(registers.get("eax", 0))),
        "selected_member_vector_after_stamp": dword_vector_snapshot(memory, wrapper),
        "candidate_coordinate_vector_after_stamp": coordinate_vector_snapshot(memory, wrapper),
        "local_coordinate_after_stamp": {
            "x": signed32(word(memory, ebp - 0x0C)),
            "y": signed32(word(memory, ebp - 0x08)),
            "z": signed32(word(memory, ebp - 0x04)),
        },
    }


def summarize(ledger: dict[str, Any]) -> dict[str, Any]:
    calls: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    orphan_events: list[dict[str, Any]] = []

    for index, event in enumerate(ledger.get("events", []), start=1):
        address = normalize_address(event.get("address", "0"))
        if address == ENTRY:
            if current is not None:
                calls.append(current)
            current = {
                "entry": entry_snapshot(index, event),
                "vector_append": None,
                "stamp_call": None,
                "after_stamp": None,
                "complete": False,
            }
        elif address == VECTOR_APPEND:
            snapshot = vector_append_snapshot(index, event)
            if current is None:
                orphan_events.append({"address": address, "snapshot": snapshot})
            else:
                current["vector_append"] = snapshot
        elif address == STAMP_CALL:
            snapshot = stamp_call_snapshot(index, event)
            if current is None:
                orphan_events.append({"address": address, "snapshot": snapshot})
            else:
                current["stamp_call"] = snapshot
        elif address == AFTER_STAMP:
            snapshot = after_stamp_snapshot(index, event)
            if current is None:
                orphan_events.append({"address": address, "snapshot": snapshot})
            else:
                current["after_stamp"] = snapshot
                current["complete"] = bool(current.get("vector_append") and current.get("stamp_call"))
                calls.append(current)
                current = None

    if current is not None:
        calls.append(current)

    completed = [call for call in calls if call.get("complete")]
    coordinate_mismatches: list[dict[str, Any]] = []
    vector_growth_mismatches: list[dict[str, Any]] = []
    for call_index, call in enumerate(completed, start=1):
        selected = call["entry"]["selected_coordinate"]
        stamp = call["stamp_call"]["stamp_coordinate_stack"]
        if selected.get("x") != stamp.get("x") or selected.get("y") != stamp.get("y") or stamp.get("z") != 0:
            coordinate_mismatches.append({"call_index": call_index, "selected": selected, "stamp": stamp})
        before = call["vector_append"]["selected_member_vector_before_append"].get("count")
        after = call["after_stamp"]["selected_member_vector_after_stamp"].get("count")
        if isinstance(before, int) and isinstance(after, int) and after != before + 1:
            vector_growth_mismatches.append({"call_index": call_index, "before": before, "after": after})

    return {
        "schema_id": "h3maped_49d69d_runtime_summary_v1",
        "ledger": ledger.get("log_path", ""),
        "event_count": int(ledger.get("event_count", 0)),
        "breakpoints": ledger.get("breakpoints", []),
        "addresses": {
            "entry": ENTRY,
            "selected_member_vector_append_call_site": VECTOR_APPEND,
            "stamp_call_site": STAMP_CALL,
            "after_stamp_call_site": AFTER_STAMP,
        },
        "call_count": len(calls),
        "completed_call_count": len(completed),
        "incomplete_call_count": len(calls) - len(completed),
        "orphan_event_count": len(orphan_events),
        "coordinate_mismatches": coordinate_mismatches,
        "vector_growth_mismatches": vector_growth_mismatches,
        "first_completed_call": completed[0] if completed else None,
        "calls": calls,
        "invariants": {
            "hits_49d69d_entry": len(calls) > 0,
            "hits_selected_member_vector_append": any(call.get("vector_append") for call in calls),
            "hits_49abd6_stamp_call_site": any(call.get("stamp_call") for call in calls),
            "has_completed_call": len(completed) > 0,
            "selected_xy_matches_stamp_xy0": not coordinate_mismatches,
            "selected_member_vector_grows_by_one": not vector_growth_mismatches,
            "no_orphan_events": not orphan_events,
        },
        "notes": [
            "Entry stack layout is return address, member pointer, selected x, selected y.",
            "At 0x49d6af, EAX points to the member-pointer argument copied into wrapper+0x28 through 0x40bb26.",
            "At 0x49d6d4, the 0x49abd6 stack payload is member pointer followed by the copied (x,y,0) coordinate triple.",
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
        "RMG_H3MAPED_49D69D_RUNTIME_SUMMARY "
        f"status={status} calls={summary['call_count']} completed={summary['completed_call_count']} "
        f"out={args.out}"
    )
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
