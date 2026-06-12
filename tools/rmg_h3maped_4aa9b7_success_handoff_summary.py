#!/usr/bin/env python3
"""Summarize a seed-controlled H3MapEd 0x4aa9b7 -> 0x4aa3e9 success handoff."""

from __future__ import annotations

import argparse
import json
from collections import Counter
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
from rmg_h3maped_4aa9b7_ordered_commit_summary import local_vector


DEFAULT_LEDGER = Path(
    ".artifacts/rmg_recovery/small2p_seed58_4aa9b7_success_handoff_20260610/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_OUT = Path(".artifacts/rmg_recovery/small2p_seed58_4aa9b7_success_handoff_summary_20260610.json")

ENTRY = "0x004aa9b7"
COUNT_CHECK = "0x004aab12"
RANDOM_SELECTION = "0x004aab2e"
POST_RANDOM_MODULO = "0x004aab3a"
SELECTED_COPY = "0x004aab4b"
BEFORE_4AA3E9 = "0x004aab58"
AA3E9_ENTRY = "0x004aa3e9"
SLOT8_CALLBACK = "0x004aa5f6"
AA3E9_PRE_RETURN = "0x004aa5fc"
AFTER_4AA3E9 = "0x004aab5d"
CLEANUP = "0x004aab66"
RETURN = "0x004aab6f"

PROJECTION_METHOD_TARGETS = {
    "0x0049c019",
    "0x0049c0a6",
    "0x004adb72",
    "0x004ad947",
    "0x004ad7f7",
}
PROJECTION_OBJECT_VTABLES = {"0x00540b00", "0x00540b14"}


def event_address(event: dict[str, Any]) -> str:
    return normalize_address(event.get("address", "0"))


def local_word(event: dict[str, Any], offset: int) -> int | None:
    ebp = event.get("registers", {}).get("ebp")
    if not isinstance(ebp, int):
        return None
    return word(event_memory(event), ebp + offset)


def local_coord(event: dict[str, Any], offset: int = -0x30) -> dict[str, Any]:
    return {
        "x": signed32(local_word(event, offset)),
        "y": signed32(local_word(event, offset + 4)),
        "level": signed32(local_word(event, offset + 8)),
    }


def local_vector_coordinates(event: dict[str, Any], max_records: int = 16) -> list[dict[str, Any]]:
    begin = local_word(event, -0x4C)
    end = local_word(event, -0x48)
    if not isinstance(begin, int) or not isinstance(end, int) or end < begin:
        return []
    memory = event_memory(event)
    count = min((end - begin) // 12, max_records)
    records: list[dict[str, Any]] = []
    for index in range(count):
        pointer = begin + index * 12
        x = signed32(word(memory, pointer))
        y = signed32(word(memory, pointer + 4))
        level = signed32(word(memory, pointer + 8))
        if x is None or y is None or level is None:
            return []
        records.append({"index": index, "x": x, "y": y, "level": level})
    return records


def slot8_record(event: dict[str, Any], event_index: int) -> dict[str, Any]:
    registers = event.get("registers", {})
    member = registers.get("ecx")
    vtable = registers.get("eax")
    memory = event_memory(event)
    return {
        "event_index": event_index,
        "member": hex32(member),
        "vtable": hex32(vtable),
        "slot_target": hex32(word(memory, vtable + 0x08) if isinstance(vtable, int) else None),
        "member_record": {
            "vtable": hex32(word(memory, member) if isinstance(member, int) else None),
            "descriptor": hex32(word(memory, member + 0x04) if isinstance(member, int) else None),
            "coordinate": {
                "x": signed32(word(memory, member + 0x08) if isinstance(member, int) else None),
                "y": signed32(word(memory, member + 0x0C) if isinstance(member, int) else None),
                "level": signed32(word(memory, member + 0x10) if isinstance(member, int) else None),
            },
        },
    }


def entry_record(event: dict[str, Any], event_index: int) -> dict[str, Any]:
    stack = stack_words(event, 6)
    return {
        "event_index": event_index,
        "return_address": hex32(stack[0] if len(stack) > 0 else None),
        "wrapper": hex32(stack[1] if len(stack) > 1 else None),
        "relation": hex32(stack[2] if len(stack) > 2 else None),
        "minimum_low_word": signed32(stack[3] if len(stack) > 3 else None),
        "policy_word": hex32(stack[4] if len(stack) > 4 else None),
        "extra_arg": signed32(stack[5] if len(stack) > 5 else None),
    }


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
        "local_vector": local_vector(event),
        "local_selected_coordinate": local_coord(event),
    }


def aa3e9_entry_record(event: dict[str, Any], event_index: int) -> dict[str, Any]:
    stack = stack_words(event, 5)
    return {
        "event_index": event_index,
        "return_address": hex32(stack[0] if len(stack) > 0 else None),
        "wrapper": hex32(stack[1] if len(stack) > 1 else None),
        "selected_coordinate": {
            "x": signed32(stack[2] if len(stack) > 2 else None),
            "y": signed32(stack[3] if len(stack) > 3 else None),
            "level": signed32(stack[4] if len(stack) > 4 else None),
        },
    }


def selected_pointer_record(event: dict[str, Any], event_index: int) -> dict[str, Any]:
    registers = event.get("registers", {})
    selected_ptr = registers.get("eax")
    vector = local_vector(event)
    selected_index = registers.get("edx")
    expected_ptr = None
    if vector.get("begin") and isinstance(selected_index, int):
        expected_ptr = int(vector["begin"], 16) + selected_index * 12
    return {
        "event_index": event_index,
        "selected_ptr": hex32(selected_ptr),
        "selected_index": selected_index,
        "expected_selected_ptr_from_vector": hex32(expected_ptr),
        "local_vector": vector,
    }


def compact_call_record(call: dict[str, Any], ordinal: int) -> dict[str, Any]:
    entry = call.get("entry") or {}
    count_check = call.get("count_check") or {}
    random_selection = call.get("random_selection") or {}
    post_random_modulo = call.get("post_random_modulo") or {}
    selected_copy = call.get("selected_copy") or {}
    before_4aa3e9 = call.get("before_4aa3e9") or {}
    aa3e9_entry = call.get("aa3e9_entry") or {}
    return_record = call.get("return") or {}
    count_vector = count_check.get("local_vector") or {}
    candidate_coordinates = count_check.get("candidate_coordinates", [])
    candidate_count = count_vector.get("count")
    before_coordinate = before_4aa3e9.get("selected_coordinate")
    entry_coordinate = aa3e9_entry.get("selected_coordinate")
    return {
        "call_ordinal": ordinal,
        "entry_event_index": entry.get("event_index"),
        "entry_wrapper": entry.get("wrapper"),
        "entry_relation": entry.get("relation"),
        "entry_minimum_low_word": entry.get("minimum_low_word"),
        "entry_policy_word": entry.get("policy_word"),
        "entry_extra_arg": entry.get("extra_arg"),
        "candidate_count_at_count_check": candidate_count,
        "candidate_coordinates_at_count_check": candidate_coordinates,
        "candidate_coordinates_memory_available": candidate_count == 0
        or len(candidate_coordinates) == candidate_count,
        "candidate_count_at_random_selection": random_selection.get("candidate_count"),
        "selected_index": post_random_modulo.get("selected_index", selected_copy.get("selected_index")),
        "selected_coordinate_before_4aa3e9": before_coordinate,
        "selected_coordinate_4aa3e9_entry": entry_coordinate,
        "reached_4aa3e9": call.get("after_4aa3e9") is not None,
        "return_success_flag_bl": return_record.get("success_flag_bl"),
        "cleanup_seen": call.get("cleanup") is not None,
        "slot8_targets": [
            record.get("slot_target")
            for record in call.get("slot8_callbacks", [])
            if isinstance(record, dict)
        ],
    }


def new_call(event: dict[str, Any], event_index: int) -> dict[str, Any]:
    return {
        "entry": entry_record(event, event_index),
        "count_check": None,
        "random_selection": None,
        "post_random_modulo": None,
        "selected_copy": None,
        "before_4aa3e9": None,
        "aa3e9_entry": None,
        "slot8_callbacks": [],
        "aa3e9_pre_return": None,
        "after_4aa3e9": None,
        "cleanup": None,
        "return": None,
        "orphan_events": [],
    }


def summarize(ledger: dict[str, Any]) -> dict[str, Any]:
    calls: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    orphan_before_entry: list[dict[str, Any]] = []
    address_counts: Counter[str] = Counter()

    for event_index, event in enumerate(ledger.get("events", []), start=1):
        address = event_address(event)
        address_counts[address] += 1
        if address == ENTRY:
            current = new_call(event, event_index)
            calls.append(current)
            continue
        if current is None:
            orphan_before_entry.append({"event_index": event_index, "address": address})
            continue
        if address == COUNT_CHECK:
            current["count_check"] = {
                "event_index": event_index,
                "local_vector": local_vector(event),
                "candidate_coordinates": local_vector_coordinates(event),
            }
        elif address == RANDOM_SELECTION:
            current["random_selection"] = {
                "event_index": event_index,
                "candidate_count": event.get("registers", {}).get("esi"),
                "local_vector": local_vector(event),
                "candidate_coordinates": local_vector_coordinates(event),
            }
        elif address == POST_RANDOM_MODULO:
            current["post_random_modulo"] = {
                "event_index": event_index,
                "selected_index": event.get("registers", {}).get("edx"),
                "candidate_count": event.get("registers", {}).get("esi"),
                "local_vector": local_vector(event),
                "candidate_coordinates": local_vector_coordinates(event),
            }
        elif address == SELECTED_COPY:
            current["selected_copy"] = selected_pointer_record(event, event_index)
        elif address == BEFORE_4AA3E9:
            current["before_4aa3e9"] = before_4aa3e9_record(event, event_index)
        elif address == AA3E9_ENTRY:
            current["aa3e9_entry"] = aa3e9_entry_record(event, event_index)
        elif address == SLOT8_CALLBACK:
            current["slot8_callbacks"].append(slot8_record(event, event_index))
        elif address == AA3E9_PRE_RETURN:
            current["aa3e9_pre_return"] = {
                "event_index": event_index,
                "wrapper": hex32(event.get("registers", {}).get("ebx")),
            }
        elif address == AFTER_4AA3E9:
            current["after_4aa3e9"] = {
                "event_index": event_index,
                "local_vector": local_vector(event),
                "local_selected_coordinate": local_coord(event),
            }
        elif address == CLEANUP:
            current["cleanup"] = {"event_index": event_index, "local_vector": local_vector(event)}
        elif address == RETURN:
            current["return"] = {
                "event_index": event_index,
                "success_flag_bl": int(event.get("registers", {}).get("ebx", 0)) & 0xFF,
                "local_vector": local_vector(event),
            }
        else:
            current["orphan_events"].append({"event_index": event_index, "address": address})

    successful_handoffs = [call for call in calls if call["after_4aa3e9"] is not None]
    false_completed_calls = [
        call
        for call in calls
        if call["return"] is not None and call["return"]["success_flag_bl"] == 0 and call["after_4aa3e9"] is None
    ]
    first_success = successful_handoffs[0] if successful_handoffs else None
    projection_method_counts = {
        address: address_counts.get(address, 0)
        for address in sorted(PROJECTION_METHOD_TARGETS)
        if address_counts.get(address, 0)
    }
    slot8_projection_records = []
    slot8_non_ordinary_records = []
    if first_success:
        for record in first_success["slot8_callbacks"]:
            if record["vtable"] in PROJECTION_OBJECT_VTABLES:
                slot8_projection_records.append(record)
            if record["slot_target"] != "0x0049baf5":
                slot8_non_ordinary_records.append(record)

    selected_pointer_matches = False
    selected_coord_matches = False
    wrapper_matches = False
    if first_success:
        selected_copy = first_success["selected_copy"]
        before = first_success["before_4aa3e9"]
        entry = first_success["aa3e9_entry"]
        if selected_copy:
            selected_pointer_matches = selected_copy["selected_ptr"] == selected_copy["expected_selected_ptr_from_vector"]
        if before and entry:
            selected_coord_matches = before["selected_coordinate"] == entry["selected_coordinate"]
            wrapper_matches = before["wrapper"] == entry["wrapper"] == first_success["entry"]["wrapper"]

    invariants = {
        "seed_control_pe_patch_used": ledger.get("seed_control", {}).get("patch", {}).get("status") == "patched",
        "has_false_calls_before_success": len(false_completed_calls) >= 1,
        "has_successful_4aa9b7_to_4aa3e9_handoff": bool(successful_handoffs),
        "success_handoff_reaches_4aa3e9_pre_return": bool(first_success and first_success["aa3e9_pre_return"]),
        "success_handoff_reaches_after_4aa3e9_site": bool(first_success and first_success["after_4aa3e9"]),
        "success_candidate_vector_non_empty": bool(
            first_success and first_success["count_check"] and first_success["count_check"]["local_vector"].get("count", 0) > 0
        ),
        "selected_pointer_matches_vector_index": selected_pointer_matches,
        "selected_coordinate_matches_4aa3e9_entry": selected_coord_matches,
        "wrapper_matches_across_success_handoff": wrapper_matches,
        "slot8_callback_seen_inside_4aa3e9": bool(first_success and first_success["slot8_callbacks"]),
        "slot8_callback_is_ordinary_49baf5_in_sample": bool(first_success and first_success["slot8_callbacks"])
        and not slot8_non_ordinary_records,
        "no_projection_vtable_in_success_slot8": not slot8_projection_records,
        "projection_methods_not_hit_in_trace": not projection_method_counts,
    }
    guardrails = {
        "native_behavior_changed": False,
        "used_objdump": False,
        "overall_goal_complete": False,
        "r1_complete": False,
    }

    return {
        "schema_id": "h3maped_4aa9b7_success_handoff_summary_v1",
        "ledger": ledger.get("log_path", ""),
        "event_count": int(ledger.get("event_count", 0)),
        "seed_control": ledger.get("seed_control", {}),
        "address_counts": dict(sorted(address_counts.items())),
        "call_count": len(calls),
        "call_sequence": [
            compact_call_record(call, ordinal)
            for ordinal, call in enumerate(calls, start=1)
        ],
        "false_completed_call_count_before_success": len(false_completed_calls),
        "successful_handoff_count": len(successful_handoffs),
        "first_successful_handoff": first_success,
        "projection_method_counts": projection_method_counts,
        "slot8_projection_records": slot8_projection_records,
        "slot8_non_ordinary_records": slot8_non_ordinary_records,
        "orphan_events_before_entry": orphan_before_entry,
        "invariants": invariants,
        "guardrails": guardrails,
        "r1_progress": {
            "closed_subblocker": "seed_controlled_successful_4aa9b7_to_4aa3e9_handoff",
            "remaining_r1_subblockers": [
                "0x4adb72/0x4ad7f7 projection-method dispatch live path or source-backed exclusion",
                "relation-priority/object-vector +0xc8/+0x1104/+0xf5c state replay around projection methods",
            ],
            "recommended_progress_delta_points": 2,
        },
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    ledger = json.loads(args.ledger.read_text(encoding="utf-8"))
    summary = summarize(ledger)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    guardrails_ok = (
        summary["guardrails"]["native_behavior_changed"] is False
        and summary["guardrails"]["used_objdump"] is False
        and summary["guardrails"]["overall_goal_complete"] is False
    )
    status = "pass" if all(summary["invariants"].values()) and guardrails_ok else "partial"
    print(
        "RMG_H3MAPED_4AA9B7_SUCCESS_HANDOFF_SUMMARY "
        f"status={status} events={summary['event_count']} "
        f"false_before_success={summary['false_completed_call_count_before_success']} "
        f"successes={summary['successful_handoff_count']} out={args.out}"
    )
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
