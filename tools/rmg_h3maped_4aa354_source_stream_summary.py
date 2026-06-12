#!/usr/bin/env python3
"""Summarize repeated H3MapEd 0x4aa354 reward source-stream cycles."""

from __future__ import annotations

import argparse
import json
from collections import OrderedDict
from pathlib import Path
from typing import Any

from rmg_h3maped_4aa3e9_ordered_summary import (
    event_memory,
    hex32,
    normalize_address,
    signed32,
    stack_words,
    word,
)


AA354_ENTRY = "0x004aa354"
AA38F_AFTER_VALUE = "0x004aa38f"
GUARD_CONSTRUCT = "0x004aa3a8"
GUARD_ATTACH_ENTRY = "0x0049cf34"
AA9B7_ENTRY = "0x004aa9b7"
CANDIDATE_COUNT_CHECK = "0x004aab12"
POST_RANDOM_MODULO = "0x004aab3a"
SELECTED_COPY = "0x004aab4b"
BEFORE_4AA3E9 = "0x004aab58"
AA3E9_ENTRY = "0x004aa3e9"
AA9B7_RETURN = "0x004aab6f"


def local_word(event: dict[str, Any], offset: int) -> int | None:
    ebp = event.get("registers", {}).get("ebp")
    if not isinstance(ebp, int):
        return None
    return word(event_memory(event), ebp + offset)


def local_vector(event: dict[str, Any]) -> dict[str, Any]:
    begin = local_word(event, -0x4C)
    end = local_word(event, -0x48)
    capacity = local_word(event, -0x44)
    count = None
    if isinstance(begin, int) and isinstance(end, int) and end >= begin:
        count = (end - begin) // 12
    return {
        "begin": hex32(begin),
        "end": hex32(end),
        "capacity": hex32(capacity),
        "count": count,
    }


def vector_coordinates(event: dict[str, Any]) -> tuple[list[dict[str, int]], bool]:
    memory = event_memory(event)
    begin = local_word(event, -0x4C)
    end = local_word(event, -0x48)
    if not isinstance(begin, int) or not isinstance(end, int) or end < begin:
        return [], False
    count = (end - begin) // 12
    coordinates: list[dict[str, int]] = []
    complete = True
    for index in range(count):
        base = begin + index * 12
        x = word(memory, base)
        y = word(memory, base + 4)
        level = word(memory, base + 8)
        if x is None or y is None or level is None:
            complete = False
            continue
        coordinates.append(
            {
                "x": signed32(x) or 0,
                "y": signed32(y) or 0,
                "level": signed32(level) or 0,
            }
        )
    return coordinates, complete and len(coordinates) == count


def aa354_entry(event: dict[str, Any], event_index: int) -> dict[str, Any]:
    stack = stack_words(event, 8)
    return {
        "event_index": event_index,
        "return_address": hex32(stack[0] if len(stack) > 0 else None),
        "relation": hex32(stack[1] if len(stack) > 1 else None),
        "wrapper": hex32(stack[2] if len(stack) > 2 else None),
        "mode_arg": signed32(stack[3] if len(stack) > 3 else None),
        "low_value": signed32(stack[4] if len(stack) > 4 else None),
        "high_value": signed32(stack[5] if len(stack) > 5 else None),
        "policy_word": hex32(stack[6] if len(stack) > 6 else None),
        "extra_arg": signed32(stack[7] if len(stack) > 7 else None),
    }


def aa9b7_entry(event: dict[str, Any], event_index: int) -> dict[str, Any]:
    stack = stack_words(event, 8)
    return {
        "event_index": event_index,
        "return_address": hex32(stack[0] if len(stack) > 0 else None),
        "wrapper": hex32(stack[1] if len(stack) > 1 else None),
        "relation": hex32(stack[2] if len(stack) > 2 else None),
        "minimum_low_word": signed32(stack[3] if len(stack) > 3 else None),
        "policy_word": hex32(stack[4] if len(stack) > 4 else None),
        "extra_arg": signed32(stack[5] if len(stack) > 5 else None),
    }


def selected_coordinate_from_eax(event: dict[str, Any]) -> dict[str, int] | None:
    selected_ptr = event.get("registers", {}).get("eax")
    if not isinstance(selected_ptr, int):
        return None
    memory = event_memory(event)
    x = word(memory, selected_ptr)
    y = word(memory, selected_ptr + 4)
    level = word(memory, selected_ptr + 8)
    if x is None or y is None or level is None:
        return None
    return {"x": signed32(x) or 0, "y": signed32(y) or 0, "level": signed32(level) or 0}


def before_4aa3e9_record(event: dict[str, Any], event_index: int) -> dict[str, Any]:
    stack = stack_words(event, 4)
    return {
        "event_index": event_index,
        "wrapper": hex32(stack[0] if len(stack) > 0 else None),
        "selected_coordinate": {
            "x": signed32(stack[1] if len(stack) > 1 else None),
            "y": signed32(stack[2] if len(stack) > 2 else None),
            "level": signed32(stack[3] if len(stack) > 3 else None),
        },
    }


def summarize(ledger: dict[str, Any]) -> dict[str, Any]:
    calls: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    orphan_events: list[dict[str, Any]] = []

    for event_index, event in enumerate(ledger.get("events", []), start=1):
        address = normalize_address(event.get("address", "0"))
        if address == AA354_ENTRY:
            if current is not None and current.get("return") is None:
                current["orphan_events"].append(
                    {"event_index": event_index, "address": "new_aa354_before_previous_return"}
                )
            current = {
                "entry": aa354_entry(event, event_index),
                "aa38f_after_value": None,
                "guard_constructor_seen": False,
                "guard_attach_seen": False,
                "aa9b7_entry": None,
                "candidate_count_check": None,
                "selected_index": -1,
                "selected_coordinate_before_4aa3e9": None,
                "selected_coordinate_4aa3e9_entry": None,
                "reached_4aa3e9": False,
                "return": None,
                "orphan_events": [],
            }
            calls.append(current)
            continue

        if current is None:
            if address in {AA9B7_ENTRY, AA9B7_RETURN}:
                orphan_events.append({"event_index": event_index, "address": address})
            continue

        if address == AA38F_AFTER_VALUE:
            current["aa38f_after_value"] = {"event_index": event_index}
        elif address == GUARD_CONSTRUCT:
            current["guard_constructor_seen"] = True
        elif address == GUARD_ATTACH_ENTRY:
            current["guard_attach_seen"] = True
        elif address == AA9B7_ENTRY:
            current["aa9b7_entry"] = aa9b7_entry(event, event_index)
        elif address == CANDIDATE_COUNT_CHECK:
            coords, complete = vector_coordinates(event)
            vector = local_vector(event)
            current["candidate_count_check"] = {
                "event_index": event_index,
                "local_vector": vector,
                "candidate_coordinates": coords,
                "candidate_coordinates_memory_available": complete,
            }
        elif address == POST_RANDOM_MODULO:
            current["selected_index"] = int(event.get("registers", {}).get("edx", -1))
        elif address == SELECTED_COPY:
            selected = selected_coordinate_from_eax(event)
            if selected is not None:
                current["selected_coordinate_before_4aa3e9"] = selected
        elif address == BEFORE_4AA3E9:
            before = before_4aa3e9_record(event, event_index)
            current["selected_coordinate_before_4aa3e9"] = before["selected_coordinate"]
        elif address == AA3E9_ENTRY:
            current["reached_4aa3e9"] = True
            stack = stack_words(event, 5)
            current["selected_coordinate_4aa3e9_entry"] = {
                "x": signed32(stack[2] if len(stack) > 2 else None),
                "y": signed32(stack[3] if len(stack) > 3 else None),
                "level": signed32(stack[4] if len(stack) > 4 else None),
            }
        elif address == AA9B7_RETURN:
            registers = event.get("registers", {})
            current["return"] = {
                "event_index": event_index,
                "success_flag_bl": int(registers.get("ebx", 0)) & 0xFF,
            }
            current = None
        elif address not in {
            "0x004aa3b6",
            "0x0049d2be",
            "0x004aa3bb",
            "0x004aa3e0",
            "0x004aab2e",
            "0x004aab4b",
            "0x004aab5d",
        }:
            current["orphan_events"].append({"event_index": event_index, "address": address})

    completed = [call for call in calls if call.get("return") is not None]
    success = [
        call
        for call in completed
        if call.get("return", {}).get("success_flag_bl") == 1 or bool(call.get("reached_4aa3e9"))
    ]
    false = [call for call in completed if call not in success]

    call_sequence: list[dict[str, Any]] = []
    relation_groups: OrderedDict[str, dict[str, Any]] = OrderedDict()
    for ordinal, call in enumerate(completed, start=1):
        entry = call["entry"]
        count_check = call.get("candidate_count_check") or {}
        vector = count_check.get("local_vector") or {}
        aa9b7 = call.get("aa9b7_entry") or {}
        relation = entry.get("relation", "")
        if relation not in relation_groups:
            relation_groups[relation] = {
                "relation": relation,
                "first_ordinal": ordinal,
                "call_count": 0,
                "band_counts": OrderedDict(),
                "policy_word": entry.get("policy_word", ""),
                "extra_arg": entry.get("extra_arg"),
                "success_count": 0,
                "guard_attach_count": 0,
            }
        group = relation_groups[relation]
        group["call_count"] += 1
        band_key = f"{entry.get('low_value')}..{entry.get('high_value')}"
        group["band_counts"][band_key] = int(group["band_counts"].get(band_key, 0)) + 1
        if call.get("reached_4aa3e9"):
            group["success_count"] += 1
        if call.get("guard_attach_seen"):
            group["guard_attach_count"] += 1
        call_sequence.append(
            {
                "ordinal": ordinal,
                "entry_event_index": entry.get("event_index"),
                "entry_relation": relation,
                "entry_wrapper": entry.get("wrapper"),
                "entry_low_value": entry.get("low_value"),
                "entry_high_value": entry.get("high_value"),
                "entry_policy_word": entry.get("policy_word"),
                "entry_extra_arg": entry.get("extra_arg"),
                "aa9b7_relation": aa9b7.get("relation"),
                "entry_minimum_low_word": aa9b7.get("minimum_low_word"),
                "candidate_count_at_count_check": vector.get("count", 0),
                "candidate_coordinates_at_count_check": count_check.get("candidate_coordinates", []),
                "candidate_coordinates_memory_available": count_check.get(
                    "candidate_coordinates_memory_available", False
                ),
                "selected_index": int(call.get("selected_index", -1)),
                "selected_coordinate_before_4aa3e9": call.get("selected_coordinate_before_4aa3e9"),
                "selected_coordinate_4aa3e9_entry": call.get("selected_coordinate_4aa3e9_entry"),
                "reached_4aa3e9": bool(call.get("reached_4aa3e9")),
                "guard_constructor_seen": bool(call.get("guard_constructor_seen")),
                "guard_attach_seen": bool(call.get("guard_attach_seen")),
            }
        )

    first_success = next((call for call in call_sequence if call["reached_4aa3e9"]), None)
    false_before_success = 0
    for call in call_sequence:
        if call["reached_4aa3e9"]:
            break
        false_before_success += 1

    return {
        "schema_id": "h3maped_4aa354_source_stream_summary_v1",
        "ledger": ledger.get("log_path", ""),
        "event_count": int(ledger.get("event_count", 0)),
        "child_returncode": ledger.get("child_returncode"),
        "max_events": ledger.get("max_events"),
        "call_count": len(calls),
        "completed_call_count": len(completed),
        "successful_handoff_count": len(success),
        "false_completed_call_count": len(false),
        "false_completed_call_count_before_success": false_before_success,
        "guard_constructor_call_count_0x4aa3a8": sum(1 for call in completed if call.get("guard_constructor_seen")),
        "guard_attach_call_count_0x49cf34": sum(1 for call in completed if call.get("guard_attach_seen")),
        "relation_group_count": len(relation_groups),
        "relation_groups": list(relation_groups.values()),
        "first_successful_handoff": first_success,
        "call_sequence": call_sequence,
        "orphan_events": orphan_events
        + [event for call in completed for event in call.get("orphan_events", [])],
        "invariants": {
            "has_completed_calls": bool(completed),
            "all_aa354_calls_completed": len(completed) == len(calls),
            "has_successful_handoff": bool(success),
            "no_orphan_events": not orphan_events
            and not [event for call in completed for event in call.get("orphan_events", [])],
        },
        "notes": [
            "This groups each 0x4aa354 entry through the following 0x4aa9b7 return.",
            "The relation groups are source pointer identities from one H3MapEd process, useful for order/shape only.",
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
    print(
        "RMG_H3MAPED_4AA354_SOURCE_STREAM_SUMMARY "
        f"calls={summary['completed_call_count']}/{summary['call_count']} "
        f"relations={summary['relation_group_count']} "
        f"success={summary['successful_handoff_count']} "
        f"false_before={summary['false_completed_call_count_before_success']} "
        f"guards={summary['guard_attach_call_count_0x49cf34']} "
        f"out={args.out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
