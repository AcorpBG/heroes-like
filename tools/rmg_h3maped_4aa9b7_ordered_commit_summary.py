#!/usr/bin/env python3
"""Summarize ordered H3MapEd 0x4aa9b7 reward-coordinate commit traces."""

from __future__ import annotations

import argparse
import json
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


ENTRY = "0x004aa9b7"
CANDIDATE_ACCEPTED = "0x004aaac6"
THRESHOLD_RESET = "0x004aaad4"
CANDIDATE_APPEND = "0x004aaae5"
CANDIDATE_COUNT_CHECK = "0x004aab12"
RANDOM_SELECTION = "0x004aab2e"
POST_RANDOM_MODULO = "0x004aab3a"
SELECTED_COPY = "0x004aab4b"
BEFORE_4AA3E9 = "0x004aab58"
AA3E9_ENTRY = "0x004aa3e9"
AFTER_4AA3E9 = "0x004aab5d"
CLEANUP = "0x004aab66"
RETURN = "0x004aab6f"


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


def entry_record(event: dict[str, Any], event_index: int) -> dict[str, Any]:
    stack = stack_words(event, 6)
    return {
        "event_index": event_index,
        "return_address": hex32(stack[0] if stack else None),
        "wrapper": hex32(stack[1] if len(stack) > 1 else None),
        "relation": hex32(stack[2] if len(stack) > 2 else None),
        "minimum_low_word": signed32(stack[3] if len(stack) > 3 else None),
        "policy_arg_word": hex32(stack[4] if len(stack) > 4 else None),
    }


def selected_record(event: dict[str, Any], event_index: int) -> dict[str, Any]:
    registers = event.get("registers", {})
    selected_ptr = registers.get("eax")
    memory = event_memory(event)
    return {
        "event_index": event_index,
        "selected_ptr": hex32(selected_ptr),
        "selected_coordinate": {
            "x": signed32(word(memory, selected_ptr) if isinstance(selected_ptr, int) else None),
            "y": signed32(word(memory, selected_ptr + 4) if isinstance(selected_ptr, int) else None),
            "level": signed32(word(memory, selected_ptr + 8) if isinstance(selected_ptr, int) else None),
        },
        "local_vector": local_vector(event),
    }


def before_commit_record(event: dict[str, Any], event_index: int) -> dict[str, Any]:
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


def new_call(event: dict[str, Any], event_index: int) -> dict[str, Any]:
    return {
        "entry": entry_record(event, event_index),
        "accepted_count": 0,
        "threshold_reset_count": 0,
        "append_count": 0,
        "candidate_count_check": None,
        "random_selection": None,
        "post_random_modulo": None,
        "selected_copy": None,
        "before_4aa3e9": None,
        "aa3e9_entry": None,
        "after_4aa3e9": None,
        "cleanup": None,
        "return": None,
        "orphan_events": [],
    }


def summarize(ledger: dict[str, Any]) -> dict[str, Any]:
    calls: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    orphan_events: list[dict[str, Any]] = []

    for event_index, event in enumerate(ledger.get("events", []), start=1):
        address = normalize_address(event.get("address", "0"))
        if address == ENTRY:
            if current is not None and current["return"] is None:
                current["orphan_events"].append({"event_index": event_index, "address": "entry_before_previous_return"})
            current = new_call(event, event_index)
            calls.append(current)
            continue

        if current is None:
            orphan_events.append({"event_index": event_index, "address": address})
            continue

        if address == CANDIDATE_ACCEPTED:
            current["accepted_count"] += 1
        elif address == THRESHOLD_RESET:
            current["threshold_reset_count"] += 1
        elif address == CANDIDATE_APPEND:
            current["append_count"] += 1
        elif address == CANDIDATE_COUNT_CHECK:
            current["candidate_count_check"] = {
                "event_index": event_index,
                "local_vector": local_vector(event),
            }
        elif address == RANDOM_SELECTION:
            current["random_selection"] = {
                "event_index": event_index,
                "candidate_count": event.get("registers", {}).get("esi"),
                "local_vector": local_vector(event),
            }
        elif address == POST_RANDOM_MODULO:
            current["post_random_modulo"] = {
                "event_index": event_index,
                "selected_index": event.get("registers", {}).get("edx"),
                "candidate_count": event.get("registers", {}).get("esi"),
                "local_vector": local_vector(event),
            }
        elif address == SELECTED_COPY:
            current["selected_copy"] = selected_record(event, event_index)
        elif address == BEFORE_4AA3E9:
            current["before_4aa3e9"] = before_commit_record(event, event_index)
        elif address == AA3E9_ENTRY:
            current["aa3e9_entry"] = aa3e9_entry_record(event, event_index)
        elif address == AFTER_4AA3E9:
            current["after_4aa3e9"] = {
                "event_index": event_index,
                "local_vector": local_vector(event),
                "local_selected_coordinate": local_coord(event),
            }
        elif address == CLEANUP:
            current["cleanup"] = {
                "event_index": event_index,
                "local_vector": local_vector(event),
            }
        elif address == RETURN:
            registers = event.get("registers", {})
            current["return"] = {
                "event_index": event_index,
                "success_flag_bl": int(registers.get("ebx", 0)) & 0xFF,
                "eax_before_return_write": registers.get("eax"),
                "local_vector": local_vector(event),
            }
        else:
            current["orphan_events"].append({"event_index": event_index, "address": address})

    completed_calls = [call for call in calls if call["return"] is not None]
    success_calls = [call for call in completed_calls if call["return"]["success_flag_bl"] == 1]
    false_calls = [call for call in completed_calls if call["return"]["success_flag_bl"] == 0]

    def coord_matches(a: dict[str, Any] | None, b: dict[str, Any] | None) -> bool:
        return bool(a and b and a == b)

    success_mismatches: list[dict[str, Any]] = []
    for call in success_calls:
        selected_copy = call["selected_copy"]
        before = call["before_4aa3e9"]
        aa3e9 = call["aa3e9_entry"]
        post_mod = call["post_random_modulo"]
        if not all([selected_copy, before, aa3e9, call["after_4aa3e9"], call["cleanup"]]):
            success_mismatches.append({"entry": call["entry"], "reason": "missing_success_stage"})
            continue
        if not coord_matches(selected_copy["selected_coordinate"], before["selected_coordinate"]):
            success_mismatches.append({"entry": call["entry"], "reason": "selected_copy_does_not_match_stack"})
        if not coord_matches(before["selected_coordinate"], aa3e9["selected_coordinate"]):
            success_mismatches.append({"entry": call["entry"], "reason": "before_call_does_not_match_4aa3e9_entry"})
        if before["wrapper"] != aa3e9["wrapper"] or before["wrapper"] != call["entry"]["wrapper"]:
            success_mismatches.append({"entry": call["entry"], "reason": "wrapper_mismatch"})
        if post_mod:
            selected_index = post_mod["selected_index"]
            candidate_count = post_mod["candidate_count"]
            if not isinstance(selected_index, int) or not isinstance(candidate_count, int) or not (0 <= selected_index < candidate_count):
                success_mismatches.append({"entry": call["entry"], "reason": "selected_index_out_of_range"})
            begin_text = post_mod["local_vector"]["begin"]
            selected_ptr_text = selected_copy["selected_ptr"]
            if begin_text and selected_ptr_text:
                expected = int(begin_text, 16) + selected_index * 12
                actual = int(selected_ptr_text, 16)
                if expected != actual:
                    success_mismatches.append({"entry": call["entry"], "reason": "selected_pointer_not_begin_plus_index"})

    false_call_with_commit = [
        call for call in false_calls if call["before_4aa3e9"] or call["aa3e9_entry"] or call["after_4aa3e9"]
    ]
    orphan_call_events = [event for call in calls for event in call["orphan_events"]]

    return {
        "schema_id": "h3maped_4aa9b7_ordered_commit_summary_v1",
        "ledger": ledger.get("log_path", ""),
        "event_count": int(ledger.get("event_count", 0)),
        "breakpoints": ledger.get("breakpoints", []),
        "call_count": len(calls),
        "completed_call_count": len(completed_calls),
        "success_call_count": len(success_calls),
        "false_call_count": len(false_calls),
        "accepted_candidate_stop_count": sum(call["accepted_count"] for call in completed_calls),
        "threshold_reset_count": sum(call["threshold_reset_count"] for call in completed_calls),
        "candidate_append_count": sum(call["append_count"] for call in completed_calls),
        "first_success_call": success_calls[0] if success_calls else None,
        "mismatch_counts": {
            "success_commit": len(success_mismatches),
            "false_call_with_commit": len(false_call_with_commit),
            "orphan_call_events": len(orphan_call_events),
            "orphan_events_before_entry": len(orphan_events),
        },
        "invariants": {
            "has_completed_calls": bool(completed_calls),
            "has_successful_commit_calls": bool(success_calls),
            "successful_commits_have_ordered_4aa3e9_handoff": not success_mismatches,
            "false_calls_do_not_enter_4aa3e9_commit": not false_call_with_commit,
            "no_orphan_events": not orphan_events and not orphan_call_events,
        },
        "notes": [
            "This summarizes the 0x4aa9b7 local candidate-vector and commit handoff into 0x4aa3e9.",
            "It proves sampled ordered handoff from selected coordinate vector element to 0x4aa3e9 stack arguments.",
            "It does not recover 0x4ad7f7 relation-priority vector ordering or 0x4adb72 object-vector projection.",
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
        "RMG_H3MAPED_4AA9B7_ORDERED_COMMIT_SUMMARY "
        f"status={status} events={summary['event_count']} "
        f"calls={summary['completed_call_count']} successes={summary['success_call_count']} "
        f"appends={summary['candidate_append_count']} out={args.out}"
    )
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
