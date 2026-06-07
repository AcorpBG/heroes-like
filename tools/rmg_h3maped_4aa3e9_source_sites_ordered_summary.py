#!/usr/bin/env python3
"""Summarize ordered H3MapEd 0x4aa3e9 source-site trace coverage."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from rmg_h3maped_4aa3e9_ordered_summary import (
    ENTRY,
    PRE_RETURN,
    SLOT4_CALLBACK,
    SLOT8_CALLBACK,
    SOURCE_BIT26_SET_BEFORE,
    SOURCE_BIT27_CLEAR_AFTER,
    cell_state,
    entry_record,
    hex32,
    local_state,
    normalize_address,
    slot_callback_record,
    snapshot,
    stack_words,
    wrapper_state,
)


SOURCE_BIT27_CLEAR_SITE = "0x004aa58d"


def source_clear_record(event: dict[str, Any], event_index: int, kind: str) -> dict[str, Any]:
    record = snapshot(event, event_index, kind)
    record["source_argument"] = stack_words(event, 4)[3] if len(stack_words(event, 4)) > 3 else None
    return record


def source_set_record(event: dict[str, Any], event_index: int) -> dict[str, Any]:
    return {
        "event_index": event_index,
        "kind": "source_bit26_set_before",
        "source": cell_state(event, "esi"),
        "destination": cell_state(event, "edi"),
        "locals": local_state(event),
        "source_argument": stack_words(event, 4)[3] if len(stack_words(event, 4)) > 3 else None,
    }


def new_call(event: dict[str, Any], event_index: int) -> dict[str, Any]:
    return {
        "entry": entry_record(event, event_index),
        "slot4_callbacks": [],
        "slot8_callbacks": [],
        "source_clear_pairs": [],
        "source_set_before": [],
        "pre_return": None,
        "orphan_events": [],
    }


def summarize(ledger: dict[str, Any]) -> dict[str, Any]:
    calls: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    pending_source_clear: dict[str, Any] | None = None
    orphan_events: list[dict[str, Any]] = []

    for event_index, event in enumerate(ledger.get("events", []), start=1):
        address = normalize_address(event.get("address", "0"))
        if address == ENTRY:
            if current is not None and current["pre_return"] is None:
                current["orphan_events"].append({"event_index": event_index, "address": "entry_before_previous_return"})
            current = new_call(event, event_index)
            calls.append(current)
            pending_source_clear = None
            continue

        if current is None:
            orphan_events.append({"event_index": event_index, "address": address})
            continue

        if address == SLOT4_CALLBACK:
            current["slot4_callbacks"].append(slot_callback_record(event, event_index, "slot4"))
        elif address == SOURCE_BIT27_CLEAR_SITE:
            pending_source_clear = source_clear_record(event, event_index, "source_bit27_clear_before")
        elif address == SOURCE_BIT27_CLEAR_AFTER:
            after = source_clear_record(event, event_index, "source_bit27_clear_after")
            if pending_source_clear is None:
                current["orphan_events"].append({"event_index": event_index, "address": address, "reason": "clear_after_without_before"})
            else:
                current["source_clear_pairs"].append({"before": pending_source_clear, "after": after})
                pending_source_clear = None
        elif address == SOURCE_BIT26_SET_BEFORE:
            current["source_set_before"].append(source_set_record(event, event_index))
        elif address == SLOT8_CALLBACK:
            current["slot8_callbacks"].append(slot_callback_record(event, event_index, "slot8"))
        elif address == PRE_RETURN:
            wrapper = event.get("registers", {}).get("ebx")
            current["pre_return"] = {
                "event_index": event_index,
                "wrapper": hex32(wrapper),
                "wrapper_state": wrapper_state(event, wrapper),
            }
            pending_source_clear = None
        else:
            current["orphan_events"].append({"event_index": event_index, "address": address})

    completed_calls = [call for call in calls if call["pre_return"] is not None]
    source_clear_calls = [call for call in completed_calls if call["source_clear_pairs"]]
    source_set_calls = [call for call in completed_calls if call["source_set_before"]]

    def clear_pair_is_valid(pair: dict[str, Any]) -> bool:
        before = pair["before"]["source"]
        after = pair["after"]["source"]
        return (
            before["cell"] == after["cell"]
            and before["bit26"] == after["bit26"]
            and not after["bit27"]
        )

    clear_mismatches = [
        pair
        for call in completed_calls
        for pair in call["source_clear_pairs"]
        if not clear_pair_is_valid(pair)
    ]
    wrapper_mismatches = [
        call
        for call in completed_calls
        if call["entry"]["wrapper"] != call["pre_return"]["wrapper"]
    ]
    selected_mismatches = [
        call
        for call in completed_calls
        if call["entry"]["selected_coordinate_arg"] != call["pre_return"]["wrapper_state"]["selected_coordinate"]
    ]
    orphan_call_events = [event for call in calls for event in call["orphan_events"]]

    representative_source_clear_call = source_clear_calls[0] if source_clear_calls else None
    representative_source_set_call = source_set_calls[0] if source_set_calls else None

    return {
        "schema_id": "h3maped_4aa3e9_source_sites_ordered_summary_v1",
        "ledger": ledger.get("log_path", ""),
        "event_count": int(ledger.get("event_count", 0)),
        "breakpoints": ledger.get("breakpoints", []),
        "call_count": len(calls),
        "completed_call_count": len(completed_calls),
        "source_clear_call_count": len(source_clear_calls),
        "source_clear_pair_count": sum(len(call["source_clear_pairs"]) for call in completed_calls),
        "source_set_before_call_count": len(source_set_calls),
        "source_set_before_count": sum(len(call["source_set_before"]) for call in completed_calls),
        "slot4_callback_count": sum(len(call["slot4_callbacks"]) for call in completed_calls),
        "slot8_callback_count": sum(len(call["slot8_callbacks"]) for call in completed_calls),
        "first_source_clear_completed_call": representative_source_clear_call,
        "first_source_set_before_completed_call": representative_source_set_call,
        "mismatch_counts": {
            "source_clear": len(clear_mismatches),
            "wrapper": len(wrapper_mismatches),
            "selected_coordinate": len(selected_mismatches),
            "orphan_call_events": len(orphan_call_events),
            "orphan_events_before_entry": len(orphan_events),
        },
        "invariants": {
            "has_completed_calls": bool(completed_calls),
            "has_completed_source_clear_call": bool(source_clear_calls),
            "source_clear_after_bit27_false_and_bit26_stable": not clear_mismatches,
            "has_completed_source_set_before_call": bool(source_set_calls),
            "wrapper_matches_for_completed_calls": not wrapper_mismatches,
            "selected_coordinate_matches_for_completed_calls": not selected_mismatches,
            "no_orphan_events": not orphan_events and not orphan_call_events,
        },
        "notes": [
            "This trace intentionally omits 0x4aa5a9 to avoid flooding on every branch-after iteration.",
            "It proves completed 0x4aa3e9 calls with source bit27 clear before/after state and completed calls that reach source bit26 set-before sites.",
            "Source bit26 after-set state is proven by the separate 0x4aa5a9 source-set-after trace, not by this no-0x4aa5a9 ordered trace.",
            "Caller-side reward/object-vector commit ordering before and after 0x4aa3e9 remains separate recovery work.",
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
        "RMG_H3MAPED_4AA3E9_SOURCE_SITES_ORDERED_SUMMARY "
        f"status={status} events={summary['event_count']} "
        f"calls={summary['completed_call_count']} "
        f"source_clear_pairs={summary['source_clear_pair_count']} "
        f"source_set_before={summary['source_set_before_count']} out={args.out}"
    )
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
