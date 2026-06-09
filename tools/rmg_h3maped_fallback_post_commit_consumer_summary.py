#!/usr/bin/env python3
"""Summarize bounded post-fallback consumer evidence.

This report reads a clean seed-pinned trace that arms likely consumer
breakpoints only after the second post-Border-Guard fallback return at
``0x4a789a``. It answers a narrow question: in the bounded sampled window, do
the exact fallback object records reappear at payload, direct-mutation,
cleanup/uncommit, or later commit surfaces?
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_LEDGER = Path(
    ".artifacts/rmg_recovery/medium_seed10_fallback_post_commit_consumer_trace_20260609/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_OUT = Path(
    ".artifacts/rmg_recovery/medium_seed10_fallback_post_commit_consumer_summary_20260609.json"
)

BOUNDARY_ADDRESS = "0x004a789a"
FALLBACK_RECORDS = ("0x036260c0", "0x03626060")
LIKELY_CONSUMERS = {
    "0x004a79a3": "payload_driver_entry",
    "0x004a7d36": "payload_record_iteration",
    "0x004a7d99": "payload_count_site",
    "0x004a696b": "linked_payload_direct_mutation_candidate",
    "0x004a7605": "endpoint_fallback_coordinator",
    "0x004add76": "cleanup_uncommit",
    "0x004adb72": "reward_guard_attachment_attempt",
    "0x004a8c15": "phase_boundary_materialization",
    "0x004a4c8e": "generated_cell_entry_boundary",
}
LATER_COMMIT_SURFACES = {
    "0x004a54a7": "object_commit_projection",
    "0x004a5756": "object_commit_projection_return",
}


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def address(event: dict[str, Any]) -> str:
    return str(event.get("address", "")).lower()


def event_contains_pointer(event: dict[str, Any], pointer: str) -> bool:
    needle = pointer.lower().replace("0x", "")
    return needle in json.dumps(event, sort_keys=True).lower()


def compact_event(event: dict[str, Any], event_index: int) -> dict[str, Any]:
    return {
        "event_index": event_index,
        "address": address(event),
        "return_address": event.get("derived", {}).get("return_address"),
        "registers": {
            key: f"0x{int(value) & 0xFFFFFFFF:08x}"
            for key, value in event.get("registers", {}).items()
            if key in {"eax", "ebx", "ecx", "edx", "esi", "edi", "esp", "ebp"}
        },
    }


def summarize(ledger_path: Path) -> dict[str, Any]:
    ledger = read_json(ledger_path)
    events = ledger.get("events", [])
    counts = Counter(address(event) for event in events)
    boundary_indices = [
        index
        for index, event in enumerate(events, start=1)
        if address(event) == BOUNDARY_ADDRESS
    ]
    boundary_index = boundary_indices[0] if boundary_indices else None
    post_events = events[boundary_index:] if boundary_index is not None else []
    post_counts = Counter(address(event) for event in post_events)

    pointer_hits: dict[str, list[dict[str, Any]]] = {}
    for pointer in FALLBACK_RECORDS:
        pointer_hits[pointer] = [
            compact_event(event, index)
            for index, event in enumerate(events, start=1)
            if event_contains_pointer(event, pointer)
        ]
    post_pointer_hits = {
        pointer: [
            hit
            for hit in hits
            if boundary_index is not None and hit["event_index"] > boundary_index
        ]
        for pointer, hits in pointer_hits.items()
    }

    observed_likely_consumers = {
        addr: {
            "name": name,
            "count_after_boundary": post_counts.get(addr, 0),
        }
        for addr, name in LIKELY_CONSUMERS.items()
        if post_counts.get(addr, 0)
    }
    observed_later_commit_surfaces = {
        addr: {
            "name": name,
            "count_after_boundary": post_counts.get(addr, 0),
        }
        for addr, name in LATER_COMMIT_SURFACES.items()
        if post_counts.get(addr, 0)
    }
    invariants = {
        "native_behavior_changed": False,
        "clean_seed_control_present": ledger.get("seed_control", {}).get("status") == "prepared"
        and ledger.get("seed_control", {}).get("patch", {}).get("status") == "patched",
        "boundary_0x4a789a_observed_once": len(boundary_indices) == 1,
        "post_boundary_events_observed": bool(post_events),
        "likely_consumers_not_observed_after_boundary": not observed_likely_consumers,
        "later_commit_surfaces_continue_after_boundary": bool(observed_later_commit_surfaces),
        "fallback_record_pointers_absent_after_boundary": all(
            not hits for hits in post_pointer_hits.values()
        ),
    }
    status = (
        "fallback_post_commit_likely_consumers_not_observed_in_bounded_trace"
        if all(
            value
            for key, value in invariants.items()
            if key != "native_behavior_changed"
        )
        else "fallback_post_commit_consumer_frontier_partial"
    )
    return {
        "schema_id": "h3maped_fallback_post_commit_consumer_summary_v1",
        "status": status,
        "native_behavior_changed": False,
        "ledger": str(ledger_path),
        "seed_control": ledger.get("seed_control"),
        "event_count": len(events),
        "event_counts": dict(sorted(counts.items())),
        "boundary_event_index": boundary_index,
        "post_boundary_event_count": len(post_events),
        "post_boundary_event_counts": dict(sorted(post_counts.items())),
        "observed_likely_consumers_after_boundary": observed_likely_consumers,
        "observed_later_commit_surfaces_after_boundary": observed_later_commit_surfaces,
        "fallback_pointer_hits": pointer_hits,
        "fallback_pointer_hits_after_boundary": post_pointer_hits,
        "invariants": invariants,
        "source_backed_conclusion": (
            "In this clean seed-pinned Medium seed-10 bounded trace, likely payload/direct-mutation/"
            "cleanup/endpoint consumer sites were armed only after the second fallback return at 0x4a789a. "
            "The trace then reached later 0x4a54a7/0x4a5756 commit traffic, but none of the armed likely "
            "consumer sites fired and neither exact fallback pointer reappeared in the parsed event stream."
        ),
        "remaining_gap": (
            "This is bounded negative runtime evidence, not terminal proof. Full final-role recovery still needs "
            "a longer later-consumer trace, a trace that follows map-generation phase completion with object-vector "
            "membership checks, or static phase-order proof that committed object-vector/cell adoption is terminal "
            "for the two fallback records in this mode."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args.ledger)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_FALLBACK_POST_COMMIT_CONSUMER_SUMMARY status={summary['status']} out={args.out}")
    return 0 if summary["status"] == "fallback_post_commit_likely_consumers_not_observed_in_bounded_trace" else 1


if __name__ == "__main__":
    raise SystemExit(main())
