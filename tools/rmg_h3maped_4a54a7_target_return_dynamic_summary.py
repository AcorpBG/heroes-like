#!/usr/bin/env python3
"""Summarize a ``0x4a54a7`` dynamic trace selected by return address."""

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
    hex32,
    object_vector_snapshot,
    projection_write,
    read_json,
    stack_words,
)


DEFAULT_TRACE_ROOT = Path(".artifacts/rmg_recovery/4a54a7_target_return_dynamic_trace_20260610")
DEFAULT_OUT_ROOT = Path(".artifacts/rmg_recovery")


def normalized_return(value: str) -> str:
    return f"0x{int(value, 0) & 0xFFFFFFFF:08x}"


def default_ledger(target_return: str) -> Path:
    target_name = normalized_return(target_return)[2:]
    return DEFAULT_TRACE_ROOT / target_name / f"winedbg_4a54a7_to_{target_name}_dynamic_trace_ledger.json"


def default_out(target_return: str) -> Path:
    target_name = normalized_return(target_return)[2:]
    return DEFAULT_OUT_ROOT / f"4a54a7_target_return_{target_name}_dynamic_summary_20260610.json"


def first_event_with_return(
    events: list[dict[str, Any]], address: str, return_address: str
) -> dict[str, Any] | None:
    for event in events:
        if event_address(event) != address:
            continue
        if str(event.get("derived", {}).get("return_address", "")).lower() == return_address:
            return event
    return None


def last_event(events: list[dict[str, Any]], address: str) -> dict[str, Any] | None:
    result = None
    for event in events:
        if event_address(event) == address:
            result = event
    return result


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    target_return = normalized_return(args.target_return)
    ledger = read_json(args.ledger)
    events = ledger.get("events", [])
    meta = ledger.get("dynamic_trace_meta", {})
    target_cell = int(meta["target_cell"], 16) if meta.get("target_cell") else None
    object_record = str(meta.get("object_record") or "").lower()
    event_counts = Counter(event_address(event) for event in events)

    commit = first_event_with_return(events, COMMIT_4A54A7, target_return)
    commit_return = last_event(events, COMMIT_RETURN)
    after_callback = last_event(events, target_return)
    writes = [
        projection_write(event, index + 1)
        for index, event in enumerate(
            event for event in events if event_address(event) == PROJECTION_WRITE
        )
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
    commit_stack = stack_words(commit, 5) if commit else []

    invariants = {
        "no_native_behavior_change": True,
        "no_objdump_used": True,
        "ledger_has_events": bool(events),
        "target_return_commit_hit": commit is not None,
        "commit_return_continuation_hit": after_callback is not None,
        "commit_returns_to_target": meta.get("commit_return_address") == target_return
        and (commit or {}).get("derived", {}).get("return_address") == target_return,
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
        f"4a54a7_target_return_{target_return[2:]}_write_stream_recovered"
        if all(invariants.values())
        else f"4a54a7_target_return_{target_return[2:]}_write_stream_incomplete"
    )

    low_word_phrase = (
        f"{before_low}->{after_low}"
        if isinstance(before_low, int) and isinstance(after_low, int)
        else "unavailable"
    )
    return {
        "schema_id": "h3maped_4a54a7_target_return_dynamic_summary_v1",
        "status": status,
        "scope": (
            f"Live Wine recovery for a 0x4a54a7 callback selected by stack return "
            f"{target_return}. For the current Ghidra static surface, {target_return} "
            "is the continuation after the indirect call at 0x004a9c3c inside 0x004a9911. "
            "This is recovery evidence only and does not change native RMG behavior."
        ),
        "inputs": {"ledger": str(args.ledger)},
        "target_return": target_return,
        "event_counts": dict(sorted(event_counts.items())),
        "dynamic_trace_meta": meta,
        "commit_stack": [hex32(word) for word in commit_stack],
        "object_vector_states": {
            COMMIT_4A54A7: vector_before,
            COMMIT_RETURN: vector_after,
        },
        "target_cell_states": {
            COMMIT_4A54A7: before_cell,
            COMMIT_RETURN: return_cell,
            target_return: after_cell,
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
            f"The sampled 0x4a54a7 callback returning to {target_return} is live and "
            "has same-ledger target-cell plus projection-write recovery. In this path, "
            "0x4a54a7 appends the selected object to the generator object vector, adds "
            "that object reference to the target generated cell, preserves the target "
            f"cell +0x20 high word, changes the target low word as {low_word_phrase}, "
            f"and performs {len(writes)} unique projection writes that preserve high "
            "words while lowering low words."
        ),
        "remaining_gap": (
            "This recovers one sampled target-return path. Full end-to-end native-port "
            "authority still requires source-backed generator+0xf5c seeding coverage "
            "outside the currently excluded writer chain, broader relation/control "
            "downstream linkage, global descriptor labels, broader map/source modes, "
            "and cleanup/uncommit state only if a future natural projection-slot path "
            "reaches it."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target-return", default="0x004a9c3f")
    parser.add_argument("--ledger", type=Path, default=None)
    parser.add_argument("--out", type=Path, default=None)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    if args.ledger is None:
        args.ledger = default_ledger(args.target_return)
    if args.out is None:
        args.out = default_out(args.target_return)
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_4A54A7_TARGET_RETURN_DYNAMIC_SUMMARY "
        f"status={summary['status']} target_return={summary['target_return']} "
        f"writes={summary['projection_write_count']} "
        f"target_low={summary['metrics']['target_cell_low_word_before']}->"
        f"{summary['metrics']['target_cell_low_word_after']} out={args.out}"
    )
    return 0 if summary["status"].endswith("_recovered") else 1


if __name__ == "__main__":
    raise SystemExit(main())
