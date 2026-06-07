#!/usr/bin/env python3
"""Summarize live H3MapEd 0x4aa3e9 source/destination cell projection traces."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ENTRY = "0x004aa3e9"
CELL_PRE_MIRROR = "0x004aa54f"
AFTER_SOURCE_CONDITIONAL = "0x004aa5a9"
AFTER_DESTINATION_MIRROR = "0x004aa5bd"
PRE_RETURN = "0x004aa5fc"


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
    w20 = word(memory, pointer + 0x20) if isinstance(pointer, int) else None
    w24 = word(memory, pointer + 0x24) if isinstance(pointer, int) else None
    w28 = word(memory, pointer + 0x28) if isinstance(pointer, int) else None
    return {
        "cell": hex32(pointer),
        "w20": hex32(w20),
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
        "source_bit26_local": signed32(word(memory, ebp - 0x08)),
        "source_bit27_local": signed32(word(memory, ebp - 0x0C)),
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


def loop_snapshot(event: dict[str, Any], event_index: int) -> dict[str, Any]:
    return {
        "event_index": event_index,
        "source": cell_state(event, "esi"),
        "destination": cell_state(event, "edi"),
        "locals": local_state(event),
    }


def summarize(ledger: dict[str, Any]) -> dict[str, Any]:
    calls: list[dict[str, Any]] = []
    current_call: dict[str, Any] | None = None
    current_loop: dict[str, Any] | None = None
    orphan_events: list[dict[str, Any]] = []
    replaced_incomplete_loops = 0

    for event_index, event in enumerate(ledger.get("events", []), start=1):
        address = normalize_address(event.get("address", "0"))
        if address == ENTRY:
            if current_call is not None:
                if current_loop is not None:
                    current_call.setdefault("incomplete_loops", []).append(current_loop)
                    current_loop = None
                current_call["complete"] = False
                calls.append(current_call)
            current_call = {
                "entry": entry_state(event, event_index),
                "loops": [],
                "incomplete_loops": [],
                "pre_return": None,
                "complete": False,
            }
            continue
        if current_call is None:
            orphan_events.append({"event_index": event_index, "address": address})
            continue
        if address == CELL_PRE_MIRROR:
            if current_loop is not None:
                current_call["incomplete_loops"].append(current_loop)
                replaced_incomplete_loops += 1
            current_loop = {"pre_mirror": loop_snapshot(event, event_index), "after_source_conditional": None, "after_destination_mirror": None}
        elif address == AFTER_SOURCE_CONDITIONAL:
            if current_loop is None:
                current_call["incomplete_loops"].append({"after_source_conditional": loop_snapshot(event, event_index)})
            else:
                current_loop["after_source_conditional"] = loop_snapshot(event, event_index)
        elif address == AFTER_DESTINATION_MIRROR:
            if current_loop is None:
                current_call["incomplete_loops"].append({"after_destination_mirror": loop_snapshot(event, event_index)})
            else:
                current_loop["after_destination_mirror"] = loop_snapshot(event, event_index)
                current_call["loops"].append(current_loop)
                current_loop = None
        elif address == PRE_RETURN:
            if current_loop is not None:
                current_call["incomplete_loops"].append(current_loop)
                current_loop = None
            current_call["pre_return"] = loop_snapshot(event, event_index)
            current_call["complete"] = True
            calls.append(current_call)
            current_call = None

    if current_call is not None:
        if current_loop is not None:
            current_call["incomplete_loops"].append(current_loop)
        calls.append(current_call)

    completed_loops = [loop for call in calls for loop in call.get("loops", [])]
    pointer_mismatches: list[dict[str, Any]] = []
    mirror_mismatches: list[dict[str, Any]] = []
    for index, loop in enumerate(completed_loops, start=1):
        pre = loop["pre_mirror"]
        mid = loop["after_source_conditional"]
        after = loop["after_destination_mirror"]
        source_cell = pre["source"]["cell"]
        dest_cell = pre["destination"]["cell"]
        if (
            mid is None
            or after is None
            or mid["source"]["cell"] != source_cell
            or after["source"]["cell"] != source_cell
            or mid["destination"]["cell"] != dest_cell
            or after["destination"]["cell"] != dest_cell
        ):
            pointer_mismatches.append({"loop_index": index, "pre": pre, "mid": mid, "after": after})
            continue
        if (
            after["destination"]["bit26"] != pre["source"]["bit26"]
            or after["destination"]["bit27"] != pre["source"]["bit27"]
        ):
            mirror_mismatches.append(
                {
                    "loop_index": index,
                    "source_before": pre["source"],
                    "destination_before": pre["destination"],
                    "destination_after": after["destination"],
                }
            )

    return {
        "schema_id": "h3maped_4aa3e9_cell_projection_summary_v1",
        "ledger": ledger.get("log_path", ""),
        "event_count": int(ledger.get("event_count", 0)),
        "breakpoints": ledger.get("breakpoints", []),
        "addresses": {
            "entry": ENTRY,
            "cell_pre_mirror": CELL_PRE_MIRROR,
            "after_source_conditional": AFTER_SOURCE_CONDITIONAL,
            "after_destination_mirror": AFTER_DESTINATION_MIRROR,
            "pre_return": PRE_RETURN,
        },
        "call_count": len(calls),
        "completed_call_count": sum(1 for call in calls if call.get("complete")),
        "incomplete_call_count": sum(1 for call in calls if not call.get("complete")),
        "completed_loop_count": len(completed_loops),
        "incomplete_loop_count": sum(len(call.get("incomplete_loops", [])) for call in calls),
        "replaced_incomplete_loop_count": replaced_incomplete_loops,
        "orphan_event_count": len(orphan_events),
        "pointer_mismatches": pointer_mismatches,
        "mirror_mismatches": mirror_mismatches,
        "first_completed_loop": completed_loops[0] if completed_loops else None,
        "calls_prefix": calls[:2],
        "invariants": {
            "has_entry": bool(calls),
            "has_completed_loop_samples": bool(completed_loops),
            "loop_source_destination_pointers_stable": not pointer_mismatches,
            "destination_bit26_bit27_mirror_source_before": not mirror_mismatches,
            "no_orphan_events": not orphan_events,
        },
        "notes": [
            "0x4aa54f captures source ESI and destination EDI after both cells are mapped and before destination mirror calls.",
            "0x4aa5a9 captures the same source/destination pair after the conditional source branch and before destination bit26/bit27 mirror calls.",
            "0x4aa5bd captures the same pair after 0x49aa63(destination, source_bit26) and 0x49a932(destination, source_bit27).",
            "This partial trace was intentionally cut after enough loop samples; it proves sampled destination mirror parity, not the complete source-conditional before/after chain.",
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
        "RMG_H3MAPED_4AA3E9_CELL_PROJECTION_SUMMARY "
        f"status={status} loops={summary['completed_loop_count']} "
        f"incomplete_loops={summary['incomplete_loop_count']} out={args.out}"
    )
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
