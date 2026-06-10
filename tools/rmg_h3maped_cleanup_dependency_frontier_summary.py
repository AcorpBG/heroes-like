#!/usr/bin/env python3
"""Summarize cleanup/uncommit dependency against endpoint reachability.

This checkpoint answers a narrow recovery question: in the current sampled
one-level land evidence, is cleanup/uncommit an active upstream source for the
missing endpoint cursor, or is it downstream of an unhit projection-slot chain?

It uses only existing Wine/Ghidra/Python recovery artifacts and does not change
native RMG behavior.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_ENDPOINT = ROOT / "supported_land_endpoint_reachability_summary_20260610.json"
DEFAULT_CURSOR_OWNER = ROOT / "cursor_writer_owner_exclusion_summary_20260610.json"
DEFAULT_PROJECTION_SLOT = ROOT / "projection_slot_target_mode_reachability_summary_20260610.json"
DEFAULT_PROJECTION_METHOD = ROOT / "projection_method_dispatch_frontier_summary_20260610.json"
DEFAULT_CLEANUP_STATIC = ROOT / "cleanup_static_ownership_summary_20260610.json"
DEFAULT_CLEANUP_RUNTIME = ROOT / "cleanup_runtime_frontier_summary_20260610.json"
DEFAULT_OUT = ROOT / "cleanup_dependency_frontier_summary_20260610.json"


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def no_native_change(summary: dict[str, Any]) -> bool:
    invariants = summary.get("invariants", {})
    metrics = summary.get("metrics", {})
    return invariants.get("no_native_behavior_change") is True and metrics.get(
        "native_behavior_changed", False
    ) is False


def no_objdump(summary: dict[str, Any]) -> bool:
    invariants = summary.get("invariants", {})
    metrics = summary.get("metrics", {})
    return invariants.get("no_objdump_used") is True or metrics.get("used_objdump") is not True


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    endpoint = load_json(args.endpoint)
    cursor_owner = load_json(args.cursor_owner)
    projection_slot = load_json(args.projection_slot)
    projection_method = load_json(args.projection_method)
    cleanup_static = load_json(args.cleanup_static)
    cleanup_runtime = load_json(args.cleanup_runtime)

    summaries = {
        "endpoint": endpoint,
        "cursor_owner": cursor_owner,
        "projection_slot": projection_slot,
        "projection_method": projection_method,
        "cleanup_static": cleanup_static,
        "cleanup_runtime": cleanup_runtime,
    }

    endpoint_metrics = endpoint.get("metrics", {})
    projection_metrics = projection_slot.get("metrics", {})
    cleanup_runtime_events = cleanup_runtime.get("target_event_totals_from_ledgers", {})
    cleanup_runtime_stops = cleanup_runtime.get("target_stop_totals_from_logs", {})

    invariants = {
        "no_native_behavior_change": all(no_native_change(summary) for summary in summaries.values()),
        "no_objdump_used": all(no_objdump(summary) for summary in summaries.values()),
        "endpoint_checkpoint_has_no_success_path": (
            endpoint.get("status")
            == "sampled_one_level_land_endpoint_reachability_no_success_path_broader_source_gap_named"
            and endpoint.get("invariants", {}).get("cursor_contract_recovered_no_success_path")
            is True
            and endpoint.get("metrics", {}).get("runtime_5e73_success_path_event_count") == 0
        ),
        "non_self_cursor_writers_bound_to_projection_chain": (
            cursor_owner.get("status")
            == "cursor_writer_owner_frontier_nonself_writers_bound_to_unhit_projection_slots"
            and cursor_owner.get("invariants", {}).get("non_self_cursor_writers_are_projection_chain_entries")
            is True
        ),
        "projection_slot_chain_unhit_in_current_corpus": (
            projection_slot.get("status")
            == "projection_slot_target_mode_unreached_recycle_boundary_explained"
            and projection_slot.get("invariants", {}).get(
                "projection_methods_and_cleanup_have_zero_events"
            )
            is True
            and projection_method.get("status")
            == "projection_method_dispatch_frontier_no_live_slot08_hit"
            and projection_method.get("invariants", {}).get(
                "no_runtime_projection_slot_method_hit_in_current_corpus"
            )
            is True
        ),
        "cleanup_static_ownership_chain_recovered": (
            cleanup_static.get("status") == "cleanup_static_ownership_chain_recovered_runtime_unhit"
            and cleanup_static.get("invariants", {}).get("4add76_only_direct_caller_is_4adef7")
            is True
            and cleanup_static.get("invariants", {}).get(
                "4adef7_direct_callers_are_49c019_and_4ad947"
            )
            is True
            and cleanup_static.get("invariants", {}).get(
                "49c019_referenced_only_by_vtable_slot"
            )
            is True
            and cleanup_static.get("invariants", {}).get(
                "49c0a6_referenced_only_by_vtable_slot"
            )
            is True
        ),
        "cleanup_runtime_has_no_live_uncommit_hit": (
            cleanup_runtime.get("status") == "cleanup_runtime_frontier_static_only_no_live_uncommit_hit"
            and cleanup_runtime.get("invariants", {}).get(
                "no_runtime_4add76_hit_in_current_ledger_corpus"
            )
            is True
            and cleanup_runtime.get("invariants", {}).get(
                "no_runtime_4adef7_hit_in_current_ledger_corpus"
            )
            is True
        ),
    }

    status = (
        "cleanup_dependency_frontier_downstream_of_unhit_projection_slot"
        if all(invariants.values())
        else "cleanup_dependency_frontier_incomplete"
    )

    dependency_chain = [
        {
            "node": "generator+0xf5c non-self writers",
            "recovered_state": (
                "Direct non-self cursor writers are 0x4adb72 and 0x4add76, both bound by "
                "Ghidra references to the projection/cleanup slot chain."
            ),
        },
        {
            "node": "projection slot +0x08 dispatch",
            "recovered_state": (
                "0x540b00+0x08 dispatches 0x49c019 and 0x540b14+0x08 dispatches 0x49c0a6 "
                "statically, but current Wine corpus has zero live slot-method hits."
            ),
        },
        {
            "node": "cleanup/reselection helpers",
            "recovered_state": (
                "0x49c019 owns 0x4adb72 and falls into 0x4adef7; 0x49c0a6 owns 0x4ad947, "
                "which can fall into 0x4adef7; 0x4adef7 is the only direct caller of "
                "0x4add76."
            ),
        },
        {
            "node": "runtime cleanup state",
            "recovered_state": (
                "Current corpus has zero live 0x4add76/0x4adef7 hits, so object-vector, "
                "cell-reference, descriptor-counter, relation-counter, and cursor before/after "
                "state for cleanup remains unavailable."
            ),
        },
    ]

    return {
        "schema_id": "h3maped_cleanup_dependency_frontier_summary_v1",
        "status": status,
        "scope": (
            "Dependency classification for cleanup/uncommit relative to the sampled one-level land "
            "endpoint blocker. This is recovery evidence only; it does not authorize native RMG "
            "behavior changes."
        ),
        "inputs": {
            "endpoint": str(args.endpoint),
            "cursor_owner": str(args.cursor_owner),
            "projection_slot": str(args.projection_slot),
            "projection_method": str(args.projection_method),
            "cleanup_static": str(args.cleanup_static),
            "cleanup_runtime": str(args.cleanup_runtime),
        },
        "dependency_chain": dependency_chain,
        "metrics": {
            "runtime_5e73_entry_count": endpoint_metrics.get("runtime_5e73_entry_count"),
            "runtime_5e73_success_path_event_count": endpoint_metrics.get(
                "runtime_5e73_success_path_event_count"
            ),
            "runtime_4a606b_event_count": endpoint_metrics.get("runtime_4a606b_event_count"),
            "projection_slot_49c019_event_hits": projection_metrics.get(
                "projection_slot_49c019_event_hits"
            ),
            "projection_slot_49c0a6_event_hits": projection_metrics.get(
                "projection_slot_49c0a6_event_hits"
            ),
            "runtime_4add76_event_count": cleanup_runtime_events.get("0x004add76"),
            "runtime_4adef7_event_count": cleanup_runtime_events.get("0x004adef7"),
            "runtime_4add76_log_stop_count": cleanup_runtime_stops.get("0x004add76"),
            "runtime_4adef7_log_stop_count": cleanup_runtime_stops.get("0x004adef7"),
            "native_behavior_changed": False,
            "overall_goal_complete": False,
            "used_objdump": False,
        },
        "invariants": invariants,
        "source_backed_conclusion": (
            "For current sampled one-level land evidence, cleanup/uncommit is not an active "
            "upstream explanation for the missing successful endpoint cursor. The only non-self "
            "direct generator+0xf5c writers are bound to projection slot +0x08 methods; those "
            "projection methods have zero live hits in the current corpus; and cleanup/uncommit "
            "helpers downstream of them also have zero live hits. Cleanup remains real code, but "
            "its before/after state is deferred until a natural projection-slot dispatch is found "
            "or source-excluded for the selected target mode."
        ),
        "remaining_gap": (
            "This does not recover cleanup/uncommit runtime mutation semantics. If future Wine or "
            "Ghidra/static-data evidence makes 0x49c019/0x49c0a6 live for a supported one-level "
            "land source state, recover 0x4adb72/0x4ad947/0x4adef7/0x4add76 before/after state "
            "for generator object-vector membership, GeneratedCell object-reference removal, "
            "descriptor counters, relation counters, and generator+0xf5c/+0x1104 cursor state. "
            "Until then, cleanup/uncommit must not be ported or guessed in native RMG."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--endpoint", type=Path, default=DEFAULT_ENDPOINT)
    parser.add_argument("--cursor-owner", type=Path, default=DEFAULT_CURSOR_OWNER)
    parser.add_argument("--projection-slot", type=Path, default=DEFAULT_PROJECTION_SLOT)
    parser.add_argument("--projection-method", type=Path, default=DEFAULT_PROJECTION_METHOD)
    parser.add_argument("--cleanup-static", type=Path, default=DEFAULT_CLEANUP_STATIC)
    parser.add_argument("--cleanup-runtime", type=Path, default=DEFAULT_CLEANUP_RUNTIME)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    missing = [
        str(path)
        for path in [
            args.endpoint,
            args.cursor_owner,
            args.projection_slot,
            args.projection_method,
            args.cleanup_static,
            args.cleanup_runtime,
        ]
        if not path.exists()
    ]
    if missing:
        raise SystemExit(f"missing input summaries: {missing}")
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_CLEANUP_DEPENDENCY_FRONTIER status={summary['status']} out={args.out}")
    return (
        0
        if summary["status"] == "cleanup_dependency_frontier_downstream_of_unhit_projection_slot"
        else 1
    )


if __name__ == "__main__":
    raise SystemExit(main())
