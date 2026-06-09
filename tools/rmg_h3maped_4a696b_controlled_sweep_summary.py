#!/usr/bin/env python3
"""Aggregate controlled ``0x4a696b`` payload-branch sweep evidence.

The input ledgers are clean PE seed-pinned Medium one-level no-water runs from
``rmg_h3maped_4a61bc_payload_link_dynamic_trace.py``.  This report does not
claim global unreachability.  It records how much controlled evidence currently
supports the live one-level land path exiting before the direct mutation block.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_LEDGERS = [
    Path(
        ".artifacts/rmg_recovery/medium_seed1_4a696b_payload_sweep_20260609/"
        "winedbg_4a61bc_payload_link_dynamic_trace_ledger.json"
    ),
    Path(
        ".artifacts/rmg_recovery/medium_seed2_4a696b_payload_sweep_20260609/"
        "winedbg_4a61bc_payload_link_dynamic_trace_ledger.json"
    ),
    Path(
        ".artifacts/rmg_recovery/4a61bc_payload_seed10_medium_trace_20260609/"
        "winedbg_4a61bc_payload_link_dynamic_trace_ledger.json"
    ),
]
DEFAULT_OUT = Path(".artifacts/rmg_recovery/medium_controlled_4a696b_sweep_summary_20260609.json")

ENTRY = "0x004a696b"
SOURCE_RELATION_MATCH_CHECKPOINT = "0x004a6a81"
TERRAIN_REJECT_CHECKPOINT = "0x004a6a8f"
HELPER_49AA93_RETURN_TEST = "0x004a6ac8"
HELPER_4A6795_RETURN_TEST = "0x004a6ade"
CANDIDATE_APPEND = "0x004a6ae2"
SCAN_DONE = "0x004a6b10"
NO_CANDIDATE_EXIT = "0x004a6b27"
CANDIDATE_PATH = "0x004a6b2e"
VTABLE_COMMIT = "0x004a6b9b"
DIRECT_MUTATION_TEST = "0x004a6c13"
DIRECT_MUTATION_AFTER = "0x004a6c2c"
FALSE_RETURN_PREP = "0x004a6cd3"
RETURN_SITE = "0x004a6ce1"
FALLBACK_COORDINATOR = "0x004a7605"
ENDPOINT_COMMIT = "0x004a7312"
ENDPOINT_VTABLE_COMMIT = "0x004a7447"
PAIR_MARK_BEFORE = "0x004a7e21"
PAIR_MARK_AFTER = "0x004a7e25"

TRACKED = [
    ENTRY,
    SOURCE_RELATION_MATCH_CHECKPOINT,
    TERRAIN_REJECT_CHECKPOINT,
    HELPER_49AA93_RETURN_TEST,
    HELPER_4A6795_RETURN_TEST,
    CANDIDATE_APPEND,
    SCAN_DONE,
    NO_CANDIDATE_EXIT,
    CANDIDATE_PATH,
    VTABLE_COMMIT,
    DIRECT_MUTATION_TEST,
    DIRECT_MUTATION_AFTER,
    FALSE_RETURN_PREP,
    RETURN_SITE,
    FALLBACK_COORDINATOR,
    ENDPOINT_COMMIT,
    ENDPOINT_VTABLE_COMMIT,
    PAIR_MARK_BEFORE,
    PAIR_MARK_AFTER,
]


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def event_address(event: dict[str, Any]) -> str:
    return str(event.get("address", "")).lower()


def seed_control_clean(ledger: dict[str, Any]) -> bool:
    seed_control = ledger.get("seed_control", {})
    return (
        seed_control.get("status") == "prepared"
        and seed_control.get("patch", {}).get("status") == "patched"
        and seed_control.get("requested_seed") not in {None, ""}
        and not seed_control.get("missing")
    )


def grouped_calls(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    calls: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    for index, event in enumerate(events):
        address = event_address(event)
        if address == ENTRY:
            if current is not None:
                calls.append(current)
            current = {
                "entry_event_index": index,
                "sites": [],
            }
        if current is not None and address in TRACKED:
            current["sites"].append(address)
            if address == RETURN_SITE:
                calls.append(current)
                current = None
    if current is not None:
        calls.append(current)
    for call in calls:
        sites = set(call["sites"])
        if DIRECT_MUTATION_TEST in sites:
            call["classification"] = "reached_direct_mutation_block"
        elif CANDIDATE_PATH in sites:
            call["classification"] = "reached_candidate_path_without_direct_mutation"
        elif NO_CANDIDATE_EXIT in sites and SOURCE_RELATION_MATCH_CHECKPOINT not in sites:
            call["classification"] = "scan_completed_no_candidate_before_source_relation_match"
        elif NO_CANDIDATE_EXIT in sites:
            call["classification"] = "scan_completed_no_candidate_after_source_relation_progress"
        else:
            call["classification"] = "incomplete"
    return calls


def summarize_ledgers(ledger_paths: list[Path]) -> dict[str, Any]:
    per_ledger: list[dict[str, Any]] = []
    aggregate_counts: Counter[str] = Counter()
    aggregate_classifications: Counter[str] = Counter()
    total_calls = 0

    for path in ledger_paths:
        ledger = load_json(path)
        events = ledger.get("events", [])
        counts = Counter(event_address(event) for event in events)
        calls = grouped_calls(events)
        classifications = Counter(call["classification"] for call in calls)
        aggregate_counts.update({key: counts.get(key, 0) for key in TRACKED})
        aggregate_classifications.update(classifications)
        total_calls += len(calls)
        meta = ledger.get("dynamic_trace_meta", {})
        per_ledger.append(
            {
                "ledger": str(path),
                "requested_seed": ledger.get("seed_control", {}).get("requested_seed"),
                "seed_control_clean": seed_control_clean(ledger),
                "event_count": ledger.get("event_count", len(events)),
                "payload_record_events": meta.get("payload_record_events"),
                "dispatch_events": meta.get("dispatch_events"),
                "selected_object_record": meta.get("object_record"),
                "address_counts": {key: counts.get(key, 0) for key in TRACKED if counts.get(key, 0)},
                "call_classifications": dict(sorted(classifications.items())),
            }
        )

    invariants = {
        "native_behavior_changed": False,
        "all_seed_control_clean": all(item["seed_control_clean"] for item in per_ledger),
        "all_ledgers_have_payload_records": all((item.get("payload_record_events") or 0) > 0 for item in per_ledger),
        "all_ledgers_have_dispatch_events": all((item.get("dispatch_events") or 0) > 0 for item in per_ledger),
        "sampled_4a696b_calls": total_calls > 0,
        "all_sampled_calls_reached_scan_done": aggregate_counts.get(SCAN_DONE, 0) == total_calls,
        "all_sampled_calls_took_no_candidate_exit": aggregate_counts.get(NO_CANDIDATE_EXIT, 0) == total_calls,
        "no_source_relation_match_hits": aggregate_counts.get(SOURCE_RELATION_MATCH_CHECKPOINT, 0) == 0,
        "no_candidate_append_hits": aggregate_counts.get(CANDIDATE_APPEND, 0) == 0,
        "no_candidate_path_hits": aggregate_counts.get(CANDIDATE_PATH, 0) == 0,
        "no_direct_mutation_hits": aggregate_counts.get(DIRECT_MUTATION_TEST, 0) == 0,
        "fallback_endpoint_surface_observed": aggregate_counts.get(FALLBACK_COORDINATOR, 0) > 0
        and aggregate_counts.get(ENDPOINT_COMMIT, 0) > 0,
    }
    status = (
        "controlled_medium_4a696b_sweep_no_direct_mutation_hits"
        if all(value for key, value in invariants.items() if key != "native_behavior_changed")
        else "controlled_medium_4a696b_sweep_partial"
    )
    return {
        "schema_id": "h3maped_4a696b_controlled_sweep_summary_v1",
        "status": status,
        "native_behavior_changed": False,
        "inputs": {"ledgers": [str(path) for path in ledger_paths]},
        "metrics": {
            "ledger_count": len(per_ledger),
            "sampled_4a696b_calls": total_calls,
            "source_relation_match_hits": aggregate_counts.get(SOURCE_RELATION_MATCH_CHECKPOINT, 0),
            "candidate_append_hits": aggregate_counts.get(CANDIDATE_APPEND, 0),
            "candidate_path_hits": aggregate_counts.get(CANDIDATE_PATH, 0),
            "direct_mutation_hits": aggregate_counts.get(DIRECT_MUTATION_TEST, 0),
            "fallback_4a7605_hits": aggregate_counts.get(FALLBACK_COORDINATOR, 0),
            "direct_endpoint_4a7312_hits": aggregate_counts.get(ENDPOINT_COMMIT, 0),
        },
        "aggregate_address_counts": {key: aggregate_counts.get(key, 0) for key in TRACKED if aggregate_counts.get(key, 0)},
        "aggregate_call_classifications": dict(sorted(aggregate_classifications.items())),
        "per_ledger": per_ledger,
        "invariants": invariants,
        "source_backed_conclusion": (
            "Across the controlled Medium one-level no-water seed-pinned ledgers, all sampled "
            "0x4a696b calls reach scan completion and take the no-candidate exit before the "
            "source/relation-match checkpoint. The sweep records zero hits at 0x4a6a81, "
            "0x4a6ae2, 0x4a6b2e, and 0x4a6c13, while still observing the fallback 0x4a7605 "
            "endpoint surface."
        ),
        "remaining_gap": (
            "This is broader controlled negative evidence, not a proof of global unreachability. "
            "End-to-end recovery still needs either a natural sample that reaches 0x4a6a81 and "
            "then the candidate/direct-mutation path, or stronger static/data proof that the "
            "direct mutation block is unreachable for the target one-level land mode. Live "
            "0x4add76/0x4adef7 cleanup/uncommit behavior and older coordinate/projection "
            "reconciliation remain unrecovered."
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, action="append", default=[])
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    ledgers = args.ledger or DEFAULT_LEDGERS
    summary = summarize_ledgers(ledgers)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_4A696B_CONTROLLED_SWEEP_SUMMARY status={summary['status']} out={args.out}")
    return 0 if summary["status"].endswith("_no_direct_mutation_hits") else 1


if __name__ == "__main__":
    raise SystemExit(main())
