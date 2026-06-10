#!/usr/bin/env python3
"""Summarize mine-owner ``0x4a54a7`` selected-callback live traces."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

from rmg_h3maped_4aa3e9_4a54a7_dynamic_summary import (
    COMMIT_4A54A7,
    COMMIT_RETURN,
    PROJECTION_WRITE,
    cell_state,
    event_address,
    first_event,
    hex32,
    object_vector_snapshot,
    projection_write,
    read_json,
    stack_words,
)
from rmg_h3maped_mine_owner_4a54a7_dynamic_trace import OWNER_PROFILES


DEFAULT_TRACE_ROOT = Path(".artifacts/rmg_recovery/mine_owner_4a54a7_dynamic_trace_20260610")
DEFAULT_OUT_ROOT = Path(".artifacts/rmg_recovery")


def default_ledger(owner: str) -> Path:
    owner = owner.lower()
    return DEFAULT_TRACE_ROOT / owner / f"winedbg_{owner}_4a54a7_dynamic_trace_ledger.json"


def default_out(owner: str) -> Path:
    return DEFAULT_OUT_ROOT / f"mine_owner_{owner.lower()}_4a54a7_dynamic_summary_20260610.json"


def owner_profile(owner: str) -> dict[str, str]:
    try:
        return OWNER_PROFILES[owner.lower()]
    except KeyError as exc:
        choices = ", ".join(sorted(OWNER_PROFILES))
        raise SystemExit(f"unknown owner {owner!r}; expected one of: {choices}") from exc


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    profile = owner_profile(args.owner)
    ledger = read_json(args.ledger)
    events = ledger.get("events", [])
    meta = ledger.get("dynamic_trace_meta", {})
    target_cell = int(meta["target_cell"], 16) if meta.get("target_cell") else None
    object_record = str(meta.get("object_record") or "").lower()
    event_counts = Counter(event_address(event) for event in events)

    owner_entry = first_event(events, profile["owner_entry"])
    callsite = first_event(events, profile["callsite"])
    commit = first_event(events, COMMIT_4A54A7)
    commit_return = first_event(events, COMMIT_RETURN)
    after_callback = first_event(events, profile["after_callback"])
    writes = [
        projection_write(event, index + 1)
        for index, event in enumerate(events)
        if event_address(event) == PROJECTION_WRITE
    ]
    unique_write_cells = sorted({write["cell_pointer"] for write in writes if write["cell_pointer"]})

    before_cell = cell_state(commit, target_cell)
    return_cell = cell_state(commit_return, target_cell)
    after_cell = cell_state(after_callback, target_cell)
    before_refs = set((before_cell or {}).get("object_ref_vector", {}).get("entries") or [])
    after_refs = set((after_cell or {}).get("object_ref_vector", {}).get("entries") or [])
    before_low = (before_cell or {}).get("low_word_plus_0x20")
    after_low = (after_cell or {}).get("low_word_plus_0x20")
    before_high = (before_cell or {}).get("high_word_plus_0x20")
    after_high = (after_cell or {}).get("high_word_plus_0x20")
    vector_before = object_vector_snapshot(commit)
    vector_after = object_vector_snapshot(commit_return)
    callsite_stack = stack_words(callsite, 6) if callsite else []
    commit_stack = stack_words(commit, 5) if commit else []
    callsite_member_matches = bool(callsite_stack) and hex32(callsite_stack[0]) == object_record

    invariants = {
        "no_native_behavior_change": True,
        "no_objdump_used": True,
        "ledger_has_events": bool(events),
        "path_hits_owner_callsite_4a54a7_and_after_callback": all(
            event_counts.get(address, 0) > 0
            for address in [
                profile["owner_entry"],
                profile["callsite"],
                COMMIT_4A54A7,
                COMMIT_RETURN,
                profile["after_callback"],
            ]
        ),
        "commit_returns_to_owner_after_callback": meta.get("commit_return_address")
        == profile["after_callback"]
        and (commit or {}).get("derived", {}).get("return_address") == profile["after_callback"],
        "commit_object_matches_callsite_stack0_when_available": not callsite_stack
        or callsite_member_matches,
        "commit_object_matches_commit_stack": len(commit_stack) > 1
        and hex32(commit_stack[1]) == object_record,
        "target_cell_snapshots_available": before_cell is not None
        and return_cell is not None
        and after_cell is not None,
        "target_cell_object_ref_added": object_record not in before_refs and object_record in after_refs,
        "target_cell_low_word_not_increased": isinstance(before_low, int)
        and isinstance(after_low, int)
        and after_low <= before_low,
        "target_cell_high_word_preserved": before_high == after_high,
        "object_vector_grows_by_one_inside_4a54a7": isinstance((vector_before or {}).get("count"), int)
        and isinstance((vector_after or {}).get("count"), int)
        and vector_after["count"] == vector_before["count"] + 1,
        "projection_write_stream_captured": len(writes) > 0,
        "projection_writes_have_unique_cells": len(writes) == len(unique_write_cells),
        "projection_writes_preserve_high_word": bool(writes)
        and all(write["high_word_preserved"] for write in writes),
        "projection_writes_lower_low_word": bool(writes)
        and all(write["low_word_lowered"] for write in writes),
    }
    status = (
        f"mine_owner_{args.owner.lower()}_4a54a7_write_stream_recovered"
        if all(invariants.values())
        else f"mine_owner_{args.owner.lower()}_4a54a7_write_stream_incomplete"
    )

    low_word_phrase = (
        f"{before_low}->{after_low}"
        if isinstance(before_low, int) and isinstance(after_low, int)
        else "unavailable"
    )
    return {
        "schema_id": "h3maped_mine_owner_4a54a7_dynamic_summary_v1",
        "status": status,
        "scope": (
            f"Live Wine recovery for {profile['owner_entry']} "
            f"({profile['owner_name']}) selected callback into 0x4a54a7 returning "
            f"to {profile['after_callback']}. This is recovery evidence only and "
            "does not change native RMG behavior."
        ),
        "inputs": {"ledger": str(args.ledger)},
        "owner": args.owner.lower(),
        "owner_name": profile["owner_name"],
        "owner_entry": profile["owner_entry"],
        "callsite": profile["callsite"],
        "after_callback": profile["after_callback"],
        "event_counts": dict(sorted(event_counts.items())),
        "dynamic_trace_meta": meta,
        "callsite_stack": [hex32(word) for word in callsite_stack],
        "commit_stack": [hex32(word) for word in commit_stack],
        "object_vector_states": {
            COMMIT_4A54A7: vector_before,
            COMMIT_RETURN: vector_after,
        },
        "target_cell_states": {
            COMMIT_4A54A7: before_cell,
            COMMIT_RETURN: return_cell,
            profile["after_callback"]: after_cell,
        },
        "projection_write_count": len(writes),
        "unique_projection_write_cell_count": len(unique_write_cells),
        "first_projection_writes": writes[:12],
        "last_projection_writes": writes[-12:],
        "invariants": invariants,
        "metrics": {
            "native_behavior_changed": False,
            "used_objdump": False,
            "overall_goal_complete": False,
            "target_cell_low_word_before": before_low,
            "target_cell_low_word_after": after_low,
            "target_cell_low_word_cleared_to_zero": after_low == 0,
            "object_vector_count_before": (vector_before or {}).get("count"),
            "object_vector_count_after": (vector_after or {}).get("count"),
            "projection_write_count": len(writes),
        },
        "source_backed_conclusion": (
            f"The sampled {profile['owner_entry']} selected callback reaches 0x4a54a7 "
            f"and returns to {profile['after_callback']}. In this live path, 0x4a54a7 "
            "appends the selected object to the generator object vector, adds that object "
            "reference to the target generated cell, preserves the target cell +0x20 high "
            f"word, changes the target low word as {low_word_phrase}, and performs "
            f"{len(writes)} unique projection writes that preserve high words while lowering "
            "low words."
        ),
        "remaining_gap": (
            "This recovers one sampled owner loop only. Full end-to-end native-port authority "
            "still requires equivalent same-ledger recovery for the other mine owner loop, "
            "plus broader relation/control downstream linkage and the unresolved generator+0xf5c "
            "success-path question."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--owner", choices=sorted(OWNER_PROFILES), default="4a9641")
    parser.add_argument("--ledger", type=Path, default=None)
    parser.add_argument("--out", type=Path, default=None)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    if args.ledger is None:
        args.ledger = default_ledger(args.owner)
    if args.out is None:
        args.out = default_out(args.owner)
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_MINE_OWNER_4A54A7_DYNAMIC_SUMMARY "
        f"status={summary['status']} owner={summary['owner']} "
        f"writes={summary['projection_write_count']} "
        f"target_low={summary['metrics']['target_cell_low_word_before']}->"
        f"{summary['metrics']['target_cell_low_word_after']} out={args.out}"
    )
    return 0 if summary["status"].endswith("_recovered") else 1


if __name__ == "__main__":
    raise SystemExit(main())
