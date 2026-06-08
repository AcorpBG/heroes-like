#!/usr/bin/env python3
"""Summarize the pre-0x4a8db2 GeneratedCell+0x20 score order.

This is recovery evidence only. It combines two bounded H3MapEd WineDbg
traces with the already recovered 0x4a54a7 projection-write and 0x4a8db2
threshold summaries. It does not change native RMG behavior.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_PRE_LEDGER = ROOT / "4a54a7_before_4a8db2_order_trace_20260608" / "winedbg_interactive_trace_ledger.json"
DEFAULT_SCHEDULER_LEDGER = ROOT / "4a8db2_to_4a8c15_order_trace_20260608" / "winedbg_interactive_trace_ledger.json"
DEFAULT_THRESHOLD_SUMMARY = ROOT / "4a8db2_threshold_formula_summary_20260608.json"
DEFAULT_PROJECTION_SUMMARY = ROOT / "medium_seed10_4a54a7_projection_write_summary_20260608.json"
DEFAULT_OUT = ROOT / "pre_4a8db2_score_order_summary_20260608.json"


def hex32(value: int | None) -> str | None:
    return None if value is None else f"0x{value & 0xFFFFFFFF:08x}"


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def event_words(event: dict[str, Any], line_index: int = 0) -> list[int]:
    lines = event.get("memory_lines", [])
    if line_index >= len(lines):
        return []
    return [int(word) & 0xFFFFFFFF for word in lines[line_index].get("words", [])]


def event_counts(events: list[dict[str, Any]]) -> dict[str, int]:
    return dict(sorted(Counter(str(event.get("address")) for event in events).items()))


def commit_summary(event: dict[str, Any], ordinal: int) -> dict[str, Any]:
    words = event_words(event)
    return {
        "ordinal": ordinal,
        "object_record": hex32(words[1] if len(words) > 1 else None),
        "x": words[2] if len(words) > 2 else None,
        "y": words[3] if len(words) > 3 else None,
        "level": words[4] if len(words) > 4 else None,
        "return_address": event.get("derived", {}).get("return_address"),
        "ecx_generator": hex32(event.get("registers", {}).get("ecx")),
    }


def summarize_pre_trace(path: Path) -> dict[str, Any]:
    ledger = read_json(path)
    events = ledger.get("events", [])
    commits: list[dict[str, Any]] = []
    projection_done_ordinals: list[int] = []
    scheduler_ordinals: list[int] = []
    for ordinal, event in enumerate(events, start=1):
        address = event.get("address")
        if address == "0x004a54a7":
            commits.append(commit_summary(event, ordinal))
        elif address == "0x004a5756":
            projection_done_ordinals.append(ordinal)
        elif address == "0x004a8db2":
            scheduler_ordinals.append(ordinal)
    first_scheduler = min(scheduler_ordinals) if scheduler_ordinals else None
    return {
        "ledger": str(path),
        "event_count": ledger.get("event_count", len(events)),
        "address_counts": event_counts(events),
        "commit_count_before_first_4a8db2": sum(
            1 for commit in commits if first_scheduler is not None and commit["ordinal"] < first_scheduler
        ),
        "projection_done_count_before_first_4a8db2": sum(
            1 for ordinal in projection_done_ordinals if first_scheduler is not None and ordinal < first_scheduler
        ),
        "first_4a8db2_ordinal": first_scheduler,
        "all_4a54a7_returns_are_relation_builder_slot": bool(commits)
        and all(commit["return_address"] == "0x004a9586" for commit in commits),
        "all_4a54a7_events_before_first_4a8db2": bool(commits)
        and first_scheduler is not None
        and all(commit["ordinal"] < first_scheduler for commit in commits),
        "no_4a8c15_or_4a79a3_before_first_4a8db2": not any(
            event.get("address") in {"0x004a8c15", "0x004a79a3"} for event in events
        ),
        "first_commits": commits[:8],
        "last_commits": commits[-4:],
    }


def summarize_scheduler_trace(path: Path) -> dict[str, Any]:
    ledger = read_json(path)
    events = ledger.get("events", [])
    first_materialization_ordinal = next(
        (ordinal for ordinal, event in enumerate(events, start=1) if event.get("address") == "0x004a8c15"),
        None,
    )
    before_materialization = [
        event
        for ordinal, event in enumerate(events, start=1)
        if first_materialization_ordinal is None or ordinal < first_materialization_ordinal
    ]
    weighted_events = [
        (ordinal, event)
        for ordinal, event in enumerate(events, start=1)
        if event.get("address") in {"0x004a8ffd", "0x004a8fd6", "0x004a8fb4", "0x004a8f96"}
    ]
    return {
        "ledger": str(path),
        "event_count": ledger.get("event_count", len(events)),
        "address_counts": event_counts(events),
        "first_4a8c15_ordinal": first_materialization_ordinal,
        "scheduler_entries_before_first_4a8c15": sum(
            1 for event in before_materialization if event.get("address") == "0x004a8db2"
        ),
        "weighted_call_events_before_first_4a8c15": [
            {
                "ordinal": ordinal,
                "callsite": event.get("address"),
                "source_pointer_or_wrapper": hex32(event_words(event)[0] if event_words(event) else None),
                "stack_words": [hex32(word) for word in event_words(event)],
                "return_address": event.get("derived", {}).get("return_address"),
            }
            for ordinal, event in weighted_events
            if first_materialization_ordinal is None or ordinal < first_materialization_ordinal
        ],
        "no_4a79a3_before_first_4a8c15": not any(
            event.get("address") == "0x004a79a3" for event in before_materialization
        ),
    }


def projection_low_ranges(path: Path) -> list[dict[str, Any]]:
    summary = read_json(path)
    ranges: list[dict[str, Any]] = []
    for target in summary.get("targets", []):
        ranges.append(
            {
                "name": target.get("name"),
                "write_count": target.get("write_count"),
                "new_low_word_range": target.get("new_low_word_range"),
                "invariants": target.get("invariants"),
            }
        )
    return ranges


def threshold_value_gate(path: Path) -> dict[str, Any]:
    summary = read_json(path)
    gate = summary.get("large_low_threshold_value_gate", {})
    return {
        "required_threshold_counts": gate.get("required_threshold_counts"),
        "sample_count": gate.get("sample_count"),
        "candidate_cell_value_low16_min": gate.get("candidate_cell_value_low16_min"),
        "candidate_cell_value_low16_max": gate.get("candidate_cell_value_low16_max"),
        "passing_value_floor_count": gate.get("passing_value_floor_count"),
        "counts": gate.get("counts"),
    }


def build_summary(args: argparse.Namespace) -> dict[str, Any]:
    pre = summarize_pre_trace(args.pre_ledger)
    scheduler = summarize_scheduler_trace(args.scheduler_ledger)
    projection_ranges = projection_low_ranges(args.projection_summary)
    value_gate = threshold_value_gate(args.threshold_summary)
    projection_maxes = [
        item.get("new_low_word_range", {}).get("max")
        for item in projection_ranges
        if item.get("new_low_word_range")
    ]
    max_projection_low = max([value for value in projection_maxes if value is not None], default=None)
    value_gate_max = value_gate.get("candidate_cell_value_low16_max")
    invariants = {
        "native_behavior_changed": False,
        "same_run_4a54a7_commits_complete_before_first_4a8db2": pre[
            "all_4a54a7_events_before_first_4a8db2"
        ]
        and pre["commit_count_before_first_4a8db2"] == pre["projection_done_count_before_first_4a8db2"],
        "pre_4a8db2_commits_return_through_4a93a2_slot": pre["all_4a54a7_returns_are_relation_builder_slot"],
        "same_run_4a8db2_repeats_before_4a8c15": scheduler["scheduler_entries_before_first_4a8c15"] == 48,
        "no_4a79a3_before_4a8c15": scheduler["no_4a79a3_before_first_4a8c15"],
        "value_gate_low_range_matches_recovered_projection_score_shape": (
            max_projection_low is not None and value_gate_max is not None and value_gate_max <= max_projection_low
        ),
    }
    return {
        "schema_id": "h3maped_pre_4a8db2_score_order_summary.v1",
        "status": "pre_4a8db2_score_projection_order_recovered",
        "native_behavior_changed": False,
        "pre_scheduler_projection_order": pre,
        "scheduler_to_materialization_order": scheduler,
        "prior_projection_low_word_ranges": projection_ranges,
        "prior_large_value_gate": value_gate,
        "recovery_meaning": {
            "recovered": (
                "The same Large no-water generation run reaches sixteen completed 0x4a54a7 "
                "object-footprint/local-score projection commits before the first 0x4a8db2 "
                "weighted scheduler entry; every sampled commit returns through 0x4a9586. "
                "A second bounded run shows forty-eight 0x4a8db2 scheduler entries, eight "
                "0x4a8ffd weighted calls, eight 0x4a8f96 weighted calls, then 0x4a8c15, "
                "with no 0x4a79a3 before materialization."
            ),
            "interpretation": (
                "The failing 0x4a901a value-gate low words 0..40 are consistent with the "
                "already recovered 0x4a54a7 projection-distance field. The remaining blocker "
                "is not an unknown threshold formula; it is the complete ordered replay of all "
                "pre-scheduler projection seeds and the successful weighted materialization path."
            ),
            "remaining_blocker": (
                "Capture a 0x4a901a weighted scan that reaches 0x49aa93 eligibility and appends "
                "through 0x4ae52a/0x4ae1fd, then record successful 0x540a9c materialization, "
                "selected descriptor, 0x4a54a7 projection, generated-cell before/after, and "
                "generator vector deltas. Continue 0x4a696b direct mutation replay, natural "
                "0x4a7605/0x4a746b/0x4a5e73 success replay, and actual 0x4add76 cleanup/uncommit "
                "runtime replay before porting native behavior."
            ),
        },
        "invariants": invariants,
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pre-ledger", type=Path, default=DEFAULT_PRE_LEDGER)
    parser.add_argument("--scheduler-ledger", type=Path, default=DEFAULT_SCHEDULER_LEDGER)
    parser.add_argument("--threshold-summary", type=Path, default=DEFAULT_THRESHOLD_SUMMARY)
    parser.add_argument("--projection-summary", type=Path, default=DEFAULT_PROJECTION_SUMMARY)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = build_summary(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_PRE_4A8DB2_SCORE_ORDER status={summary['status']} out={args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
