#!/usr/bin/env python3
"""Summarize live H3MapEd 0x49d7c3 contour-vector runtime traces."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ENTRY = "0x0049d7c3"
APPEND = "0x0049d868"
EXIT = "0x0049d90f"


def normalize_address(value: Any) -> str:
    return "0x%08x" % int(str(value), 0)


def event_memory(event: dict[str, Any]) -> dict[int, int]:
    memory: dict[int, int] = {}
    for line in event.get("memory_lines", []):
        base = int(line.get("address", 0))
        for offset, word in enumerate(line.get("words", [])):
            memory[base + offset * 4] = int(word) & 0xFFFFFFFF
    return memory


def signed32(value: int | None) -> int | None:
    if value is None:
        return None
    value &= 0xFFFFFFFF
    if value & 0x80000000:
        return value - 0x100000000
    return value


def word(memory: dict[int, int], address: int) -> int | None:
    value = memory.get(address)
    return int(value) if value is not None else None


def vector_snapshot(memory: dict[int, int], base: int) -> dict[str, Any]:
    begin = word(memory, base + 0x3C)
    end = word(memory, base + 0x40)
    capacity = word(memory, base + 0x44)
    count = None
    if begin is not None and end is not None and end >= begin and (end - begin) % 8 == 0:
        count = (end - begin) // 8
    return {
        "begin": "0x%08x" % begin if begin is not None else "",
        "end": "0x%08x" % end if end is not None else "",
        "capacity": "0x%08x" % capacity if capacity is not None else "",
        "count": count,
    }


def entry_snapshot(event: dict[str, Any]) -> dict[str, Any]:
    registers = event.get("registers", {})
    wrapper = int(registers.get("ecx", 0))
    memory = event_memory(event)
    return {
        "wrapper": "0x%08x" % wrapper,
        "return_address": event.get("derived", {}).get("return_address", ""),
        "cell_buffer": "0x%08x" % word(memory, wrapper + 0x08) if word(memory, wrapper + 0x08) is not None else "",
        "width": word(memory, wrapper + 0x0C),
        "height": word(memory, wrapper + 0x10),
        "level_count_or_flag": word(memory, wrapper + 0x14),
        "bounds": {
            "min_x": signed32(word(memory, wrapper + 0x18)),
            "min_y": signed32(word(memory, wrapper + 0x1C)),
            "max_x": signed32(word(memory, wrapper + 0x20)),
            "max_y": signed32(word(memory, wrapper + 0x24)),
        },
        "vector_before": vector_snapshot(memory, wrapper),
    }


def append_snapshot(index: int, event: dict[str, Any]) -> dict[str, Any]:
    registers = event.get("registers", {})
    ebp = int(registers.get("ebp", 0))
    wrapper = int(registers.get("ebx", 0))
    memory = event_memory(event)
    return {
        "event_index": index,
        "wrapper": "0x%08x" % wrapper,
        "source_pointer_eax": "0x%08x" % int(registers.get("eax", 0)),
        "initial_coordinate": {
            "x": signed32(word(memory, ebp - 0x14)),
            "y": signed32(word(memory, ebp - 0x10)),
        },
        "append_coordinate": {
            "x": signed32(word(memory, ebp - 0x0C)),
            "y": signed32(word(memory, ebp - 0x08)),
        },
        "direction_probe_index_or_step": signed32(int(registers.get("esi", 0))),
        "vector_before_append": vector_snapshot(memory, wrapper),
    }


def exit_snapshot(event: dict[str, Any]) -> dict[str, Any]:
    registers = event.get("registers", {})
    wrapper = int(registers.get("ebx", 0))
    memory = event_memory(event)
    return {
        "wrapper": "0x%08x" % wrapper,
        "return_address": event.get("derived", {}).get("return_address", ""),
        "final_coordinate": {
            "x": signed32(word(memory, int(registers.get("ebp", 0)) - 0x0C)),
            "y": signed32(word(memory, int(registers.get("ebp", 0)) - 0x08)),
        },
        "vector_at_exit": vector_snapshot(memory, wrapper),
    }


def summarize(ledger: dict[str, Any]) -> dict[str, Any]:
    calls: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    orphan_appends: list[dict[str, Any]] = []
    orphan_exits: list[dict[str, Any]] = []

    for index, event in enumerate(ledger.get("events", []), start=1):
        address = normalize_address(event.get("address", "0"))
        if address == ENTRY:
            if current is not None:
                calls.append(current)
            current = {
                "entry_event_index": index,
                "entry": entry_snapshot(event),
                "append_count": 0,
                "append_coordinates": [],
                "append_events": [],
                "exit_event_index": None,
                "exit": None,
                "complete": False,
            }
        elif address == APPEND:
            append = append_snapshot(index, event)
            if current is None:
                orphan_appends.append(append)
            else:
                current["append_count"] += 1
                current["append_coordinates"].append(append["append_coordinate"])
                current["append_events"].append(append)
        elif address == EXIT:
            exit_data = exit_snapshot(event)
            if current is None:
                orphan_exits.append({"event_index": index, "exit": exit_data})
            else:
                current["exit_event_index"] = index
                current["exit"] = exit_data
                current["complete"] = True
                calls.append(current)
                current = None

    if current is not None:
        calls.append(current)

    completed = [call for call in calls if call.get("complete")]
    append_total = sum(int(call.get("append_count", 0)) for call in calls)
    first_completed = completed[0] if completed else None
    first_append_count = int(first_completed.get("append_count", 0)) if first_completed else 0

    return {
        "schema_id": "h3maped_49d7c3_runtime_summary_v1",
        "ledger": ledger.get("log_path", ""),
        "event_count": int(ledger.get("event_count", 0)),
        "breakpoints": ledger.get("breakpoints", []),
        "addresses": {
            "entry": ENTRY,
            "append_call_site": APPEND,
            "exit": EXIT,
        },
        "call_count": len(calls),
        "completed_call_count": len(completed),
        "incomplete_call_count": len(calls) - len(completed),
        "append_total": append_total,
        "orphan_append_count": len(orphan_appends),
        "orphan_exit_count": len(orphan_exits),
        "first_completed_call": first_completed,
        "calls": calls,
        "invariants": {
            "hits_49d7c3_entry": len(calls) > 0,
            "hits_49d868_append_call_site": append_total > 0,
            "has_completed_call": len(completed) > 0,
            "first_completed_call_appends_coordinates": first_append_count > 0,
            "no_orphan_append_events": not orphan_appends,
        },
        "notes": [
            "At 0x49d868, EAX points to the local coordinate pair at EBP-0x0c/EBP-0x08 passed to 0x40bb15.",
            "The vector snapshot uses wrapper+0x3c/+0x40/+0x44 for begin/end/capacity; counts are pre-append at 0x49d868.",
            "The trace was manually stopped after useful append evidence was captured, so an incomplete final call is expected when present.",
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
        "RMG_H3MAPED_49D7C3_RUNTIME_SUMMARY "
        f"status={status} calls={summary['call_count']} completed={summary['completed_call_count']} "
        f"appends={summary['append_total']} out={args.out}"
    )
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
