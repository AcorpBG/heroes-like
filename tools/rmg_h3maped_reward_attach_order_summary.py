#!/usr/bin/env python3
"""Summarize a same-run H3MapEd reward/guard attach-order trace."""

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
from rmg_h3maped_4aa9b7_ordered_commit_summary import local_vector


AA354_ENTRY = "0x004aa354"
BEFORE_AA1DB = "0x004aa38a"
AFTER_AA1DB = "0x004aa38f"
BEFORE_A5C07 = "0x004aa3a8"
BEFORE_49CF34 = "0x004aa3b6"
ENTRY_49CF34 = "0x0049cf34"
SUCCESS_49CF34 = "0x0049d2be"
AFTER_49CF34 = "0x004aa3bb"
AA354_TRUE_RETURN = "0x004aa3e0"
AA9B7_ENTRY = "0x004aa9b7"
AA9B7_COUNT_CHECK = "0x004aab12"
AA9B7_RETURN = "0x004aab6f"
AA3E9_ENTRY = "0x004aa3e9"

ORDERED_ADDRESSES = [
    AA354_ENTRY,
    BEFORE_AA1DB,
    AFTER_AA1DB,
    BEFORE_A5C07,
    BEFORE_49CF34,
    ENTRY_49CF34,
    SUCCESS_49CF34,
    AFTER_49CF34,
    AA354_TRUE_RETURN,
    AA9B7_ENTRY,
    AA9B7_COUNT_CHECK,
    AA9B7_RETURN,
]


def first_event(events: list[dict[str, Any]], address: str) -> tuple[int, dict[str, Any]] | tuple[None, None]:
    for event_index, event in enumerate(events, start=1):
        if normalize_address(event.get("address", "0")) == address:
            return event_index, event
    return None, None


def event_record(event: dict[str, Any] | None, event_index: int | None, label: str) -> dict[str, Any] | None:
    if event is None:
        return None
    return {
        "event_index": event_index,
        "label": label,
        "address": normalize_address(event.get("address", "0")),
        "registers": {key: hex32(value) for key, value in event.get("registers", {}).items()},
        "stack_words": [hex32(value) for value in stack_words(event, 8)],
    }


def raw_words(event: dict[str, Any] | None, pointer: int | None, count: int) -> list[str]:
    if event is None or not isinstance(pointer, int):
        return []
    memory = event_memory(event)
    return [hex32(word(memory, pointer + index * 4)) for index in range(count)]


def object_record(event: dict[str, Any] | None, pointer: int | None) -> dict[str, Any]:
    memory = event_memory(event) if event else {}
    return {
        "pointer": hex32(pointer),
        "vtable": hex32(word(memory, pointer) if isinstance(pointer, int) else None),
        "descriptor": hex32(word(memory, pointer + 0x04) if isinstance(pointer, int) else None),
        "coordinate": {
            "x": signed32(word(memory, pointer + 0x08) if isinstance(pointer, int) else None),
            "y": signed32(word(memory, pointer + 0x0C) if isinstance(pointer, int) else None),
            "level": signed32(word(memory, pointer + 0x10) if isinstance(pointer, int) else None),
        },
        "record_words": raw_words(event, pointer, 16),
    }


def wrapper_snapshot(event: dict[str, Any] | None, pointer: int | None) -> dict[str, Any]:
    memory = event_memory(event) if event else {}
    selected_begin = word(memory, pointer + 0x2C) if isinstance(pointer, int) else None
    selected_end = word(memory, pointer + 0x30) if isinstance(pointer, int) else None
    selected_count = None
    if isinstance(selected_begin, int) and isinstance(selected_end, int) and selected_end >= selected_begin:
        selected_count = (selected_end - selected_begin) // 4
    candidate_begin = word(memory, pointer + 0x3C) if isinstance(pointer, int) else None
    candidate_end = word(memory, pointer + 0x40) if isinstance(pointer, int) else None
    candidate_count = None
    if isinstance(candidate_begin, int) and isinstance(candidate_end, int) and candidate_end >= candidate_begin:
        candidate_count = (candidate_end - candidate_begin) // 8
    return {
        "pointer": hex32(pointer),
        "grid": {
            "cells": hex32(word(memory, pointer + 0x08) if isinstance(pointer, int) else None),
            "width": signed32(word(memory, pointer + 0x0C) if isinstance(pointer, int) else None),
            "height": signed32(word(memory, pointer + 0x10) if isinstance(pointer, int) else None),
        },
        "bounds_or_scan_fields": {
            "field_0x18": signed32(word(memory, pointer + 0x18) if isinstance(pointer, int) else None),
            "field_0x1c": signed32(word(memory, pointer + 0x1C) if isinstance(pointer, int) else None),
            "field_0x20": signed32(word(memory, pointer + 0x20) if isinstance(pointer, int) else None),
            "field_0x24": signed32(word(memory, pointer + 0x24) if isinstance(pointer, int) else None),
        },
        "selected_member_vector": {
            "begin": hex32(selected_begin),
            "end": hex32(selected_end),
            "capacity": hex32(word(memory, pointer + 0x34) if isinstance(pointer, int) else None),
            "count": selected_count,
        },
        "candidate_coordinate_vector": {
            "begin": hex32(candidate_begin),
            "end": hex32(candidate_end),
            "capacity": hex32(word(memory, pointer + 0x44) if isinstance(pointer, int) else None),
            "count": candidate_count,
        },
        "attached_flag": signed32(word(memory, pointer + 0x48) if isinstance(pointer, int) else None),
        "attached_relative_coordinate": {
            "x": signed32(word(memory, pointer + 0x4C) if isinstance(pointer, int) else None),
            "y": signed32(word(memory, pointer + 0x50) if isinstance(pointer, int) else None),
        },
        "field_0x54": signed32(word(memory, pointer + 0x54) if isinstance(pointer, int) else None),
        "generator_pointer_field_0x58": hex32(word(memory, pointer + 0x58) if isinstance(pointer, int) else None),
        "field_0x5c": signed32(word(memory, pointer + 0x5C) if isinstance(pointer, int) else None),
        "raw_words": raw_words(event, pointer, 24),
    }


def aa9b7_return_success(event: dict[str, Any] | None) -> int | None:
    if event is None:
        return None
    ebx = event.get("registers", {}).get("ebx")
    if not isinstance(ebx, int):
        return None
    return ebx & 0xFF


def summarize(ledger: dict[str, Any]) -> dict[str, Any]:
    events = ledger.get("events", [])
    normalized_addresses = [normalize_address(event.get("address", "0")) for event in events]
    indexed = {address: first_event(events, address) for address in ORDERED_ADDRESSES}

    aa354_event_index, aa354 = indexed[AA354_ENTRY]
    before_aa1db_event_index, before_aa1db = indexed[BEFORE_AA1DB]
    after_aa1db_event_index, after_aa1db = indexed[AFTER_AA1DB]
    before_a5c07_event_index, before_a5c07 = indexed[BEFORE_A5C07]
    before_49cf34_event_index, before_49cf34 = indexed[BEFORE_49CF34]
    entry_49cf34_event_index, entry_49cf34 = indexed[ENTRY_49CF34]
    success_49cf34_event_index, success_49cf34 = indexed[SUCCESS_49CF34]
    after_49cf34_event_index, after_49cf34 = indexed[AFTER_49CF34]
    aa354_return_event_index, aa354_return = indexed[AA354_TRUE_RETURN]
    aa9b7_entry_event_index, aa9b7_entry = indexed[AA9B7_ENTRY]
    aa9b7_count_event_index, aa9b7_count = indexed[AA9B7_COUNT_CHECK]
    aa9b7_return_event_index, aa9b7_return = indexed[AA9B7_RETURN]

    aa354_stack = stack_words(aa354, 8) if aa354 else []
    before_aa1db_stack = stack_words(before_aa1db, 6) if before_aa1db else []
    before_49cf34_stack = stack_words(before_49cf34, 6) if before_49cf34 else []
    entry_49cf34_stack = stack_words(entry_49cf34, 6) if entry_49cf34 else []
    aa9b7_stack = stack_words(aa9b7_entry, 6) if aa9b7_entry else []

    wrapper_from_entry = aa354_stack[2] if len(aa354_stack) > 2 else None
    wrapper_from_before_aa1db = before_aa1db_stack[1] if len(before_aa1db_stack) > 1 else None
    wrapper_from_after_aa1db = after_aa1db.get("registers", {}).get("ebx") if after_aa1db else None
    wrapper_from_before_49cf34 = before_49cf34.get("registers", {}).get("ebx") if before_49cf34 else None
    wrapper_from_entry_49cf34 = entry_49cf34.get("registers", {}).get("ecx") if entry_49cf34 else None
    wrapper_from_success_49cf34 = success_49cf34.get("registers", {}).get("ebx") if success_49cf34 else None
    wrapper_from_after_49cf34 = after_49cf34.get("registers", {}).get("ebx") if after_49cf34 else None
    wrapper_from_return = aa354_return.get("registers", {}).get("ebx") if aa354_return else None
    wrapper_from_aa9b7 = aa9b7_stack[1] if len(aa9b7_stack) > 1 else None

    member_from_before_49cf34 = before_49cf34.get("registers", {}).get("esi") if before_49cf34 else None
    member_from_before_stack = before_49cf34_stack[0] if before_49cf34_stack else None
    member_from_entry_49cf34 = entry_49cf34_stack[1] if len(entry_49cf34_stack) > 1 else None
    member_from_after_49cf34 = after_49cf34.get("registers", {}).get("esi") if after_49cf34 else None

    aa9b7_count_vector = local_vector(aa9b7_count) if aa9b7_count else {}
    aa9b7_return_vector = local_vector(aa9b7_return) if aa9b7_return else {}

    wrapper_values = [
        wrapper_from_entry,
        wrapper_from_before_aa1db,
        wrapper_from_after_aa1db,
        wrapper_from_before_49cf34,
        wrapper_from_entry_49cf34,
        wrapper_from_success_49cf34,
        wrapper_from_after_49cf34,
        wrapper_from_return,
        wrapper_from_aa9b7,
    ]
    present_wrapper_values = [value for value in wrapper_values if isinstance(value, int)]
    member_values = [
        member_from_before_49cf34,
        member_from_before_stack,
        member_from_entry_49cf34,
        member_from_after_49cf34,
    ]
    present_member_values = [value for value in member_values if isinstance(value, int)]

    before_record = object_record(before_49cf34, member_from_before_49cf34)
    after_record = object_record(after_49cf34, member_from_after_49cf34)
    success_wrapper = wrapper_snapshot(success_49cf34, wrapper_from_success_49cf34)
    after_wrapper = wrapper_snapshot(after_49cf34, wrapper_from_after_49cf34)

    expected_indexes = [
        normalized_addresses.index(address) if address in normalized_addresses else -1
        for address in ORDERED_ADDRESSES
    ]
    expected_order_present = all(index >= 0 for index in expected_indexes)
    expected_order_strict = expected_order_present and expected_indexes == sorted(expected_indexes)
    aa3e9_events = [address for address in normalized_addresses if address == AA3E9_ENTRY]

    invariants = {
        "expected_order_reached": expected_order_strict,
        "single_wrapper_joined_across_attach_and_post_scheduler": (
            bool(present_wrapper_values) and len(set(present_wrapper_values)) == 1
        ),
        "single_member_joined_into_49cf34": (
            bool(present_member_values) and len(set(present_member_values)) == 1
        ),
        "49cf34_returns_to_4aa3bb": (
            bool(entry_49cf34_stack) and hex32(entry_49cf34_stack[0]) == AFTER_49CF34
        ),
        "object_record_starts_unplaced": before_record["coordinate"] == {"x": -1, "y": -1, "level": -1},
        "object_record_coordinate_stamped_after_49cf34": after_record["coordinate"] == {
            "x": 9,
            "y": 10,
            "level": 0,
        },
        "wrapper_attached_flag_set_by_49cf34": success_wrapper["attached_flag"] == 1
        and after_wrapper["attached_flag"] == 1,
        "wrapper_relative_coordinate_populated_by_49cf34": (
            success_wrapper["attached_relative_coordinate"] == {"x": 8, "y": 10}
            and after_wrapper["attached_relative_coordinate"] == {"x": 8, "y": 10}
        ),
        "post_attach_4aa9b7_candidate_vector_empty": aa9b7_count_vector.get("count") == 0,
        "post_attach_4aa9b7_returns_false": aa9b7_return_success(aa9b7_return) == 0,
        "post_attach_4aa9b7_does_not_call_4aa3e9": not aa3e9_events,
    }
    guardrails = {
        "native_behavior_changed": False,
        "used_objdump": False,
        "ordered_private_state_mutation_replay_complete": False,
        "overall_goal_complete": False,
    }

    return {
        "schema_id": "h3maped_reward_attach_order_summary_v1",
        "ledger": ledger.get("log_path", ""),
        "event_count": int(ledger.get("event_count", 0)),
        "breakpoints": ledger.get("breakpoints", []),
        "event_sequence": normalized_addresses,
        "trace_anchors": {
            "4aa354_entry": event_record(aa354, aa354_event_index, "4aa354_entry"),
            "before_4aa1db": event_record(before_aa1db, before_aa1db_event_index, "before_4aa1db"),
            "after_4aa1db": event_record(after_aa1db, after_aa1db_event_index, "after_4aa1db"),
            "before_4a5c07": event_record(before_a5c07, before_a5c07_event_index, "before_4a5c07"),
            "before_49cf34": event_record(before_49cf34, before_49cf34_event_index, "before_49cf34"),
            "entry_49cf34": event_record(entry_49cf34, entry_49cf34_event_index, "entry_49cf34"),
            "success_49cf34": event_record(success_49cf34, success_49cf34_event_index, "success_49cf34"),
            "after_49cf34": event_record(after_49cf34, after_49cf34_event_index, "after_49cf34"),
            "4aa354_true_return": event_record(aa354_return, aa354_return_event_index, "4aa354_true_return"),
            "post_attach_4aa9b7_entry": event_record(aa9b7_entry, aa9b7_entry_event_index, "post_attach_4aa9b7_entry"),
            "post_attach_4aa9b7_count_check": event_record(
                aa9b7_count, aa9b7_count_event_index, "post_attach_4aa9b7_count_check"
            ),
            "post_attach_4aa9b7_return": event_record(
                aa9b7_return, aa9b7_return_event_index, "post_attach_4aa9b7_return"
            ),
        },
        "wrapper_join": {
            "4aa354_stack_word_2": hex32(wrapper_from_entry),
            "before_4aa1db_stack_word_1": hex32(wrapper_from_before_aa1db),
            "after_4aa1db_ebx": hex32(wrapper_from_after_aa1db),
            "before_49cf34_ebx": hex32(wrapper_from_before_49cf34),
            "49cf34_entry_ecx": hex32(wrapper_from_entry_49cf34),
            "49cf34_success_ebx": hex32(wrapper_from_success_49cf34),
            "after_49cf34_ebx": hex32(wrapper_from_after_49cf34),
            "4aa354_return_ebx": hex32(wrapper_from_return),
            "post_attach_4aa9b7_stack_word_1": hex32(wrapper_from_aa9b7),
            "unique_present_wrappers": sorted(hex32(value) for value in set(present_wrapper_values)),
        },
        "member_join": {
            "before_49cf34_esi": hex32(member_from_before_49cf34),
            "before_49cf34_stack_word_0": hex32(member_from_before_stack),
            "49cf34_entry_stack_word_1": hex32(member_from_entry_49cf34),
            "after_49cf34_esi": hex32(member_from_after_49cf34),
            "unique_present_members": sorted(hex32(value) for value in set(present_member_values)),
        },
        "4aa1db": {
            "return_eax": hex32(after_aa1db.get("registers", {}).get("eax") if after_aa1db else None),
            "wrapper_after_return": wrapper_snapshot(after_aa1db, wrapper_from_after_aa1db),
            "note": "The sampled helper returns 0x2710 while preserving the same reward/guard wrapper pointer.",
        },
        "49cf34_attach": {
            "object_record_before": before_record,
            "object_record_after": after_record,
            "wrapper_at_success_site": success_wrapper,
            "wrapper_after_return_to_4aa354": after_wrapper,
        },
        "post_attach_4aa9b7": {
            "entry": {
                "wrapper": hex32(wrapper_from_aa9b7),
                "relation": hex32(aa9b7_stack[2] if len(aa9b7_stack) > 2 else None),
                "minimum_low_word": signed32(aa9b7_stack[3] if len(aa9b7_stack) > 3 else None),
                "policy_word": hex32(aa9b7_stack[4] if len(aa9b7_stack) > 4 else None),
                "extra_arg": signed32(aa9b7_stack[5] if len(aa9b7_stack) > 5 else None),
            },
            "candidate_count_check_local_vector": aa9b7_count_vector,
            "return_success_flag_bl": aa9b7_return_success(aa9b7_return),
            "return_local_vector": aa9b7_return_vector,
            "aa3e9_event_count": len(aa3e9_events),
            "interpretation": (
                "For this clean Medium seed-10 wrapper, the immediate post-attach 0x4aa9b7 call "
                "has an empty local candidate vector, returns false, and does not continue into 0x4aa3e9."
            ),
        },
        "invariants": invariants,
        "guardrails": guardrails,
        "remaining_gap": (
            "This recovers one same-run 0x4aa354 -> 0x4aa1db -> 0x4a5c07 -> 0x49cf34 "
            "attach-order path and a negative immediate 0x4aa9b7 boundary. It does not recover "
            "0x4adb72/0x4ad7f7 projection-method dispatch, relation-priority propagation, or a "
            "same-run successful post-attach 0x4aa9b7 -> 0x4aa3e9 continuation."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--ledger",
        type=Path,
        default=Path(
            ".artifacts/rmg_recovery/medium_seed10_reward_attach_order_replay_20260610/"
            "winedbg_interactive_trace_ledger.json"
        ),
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=Path(".artifacts/rmg_recovery/reward_attach_order_summary_20260610.json"),
    )
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
        and summary["guardrails"]["ordered_private_state_mutation_replay_complete"] is False
        and summary["guardrails"]["overall_goal_complete"] is False
    )
    status = "pass" if all(summary["invariants"].values()) and guardrails_ok else "partial"
    print(
        "RMG_H3MAPED_REWARD_ATTACH_ORDER_SUMMARY "
        f"status={status} events={summary['event_count']} "
        f"wrapper={summary['wrapper_join']['unique_present_wrappers']} "
        f"member={summary['member_join']['unique_present_members']} "
        f"out={args.out}"
    )
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
