#!/usr/bin/env python3
"""Summarize sampled one-level land endpoint reachability evidence.

This is a recovery checkpoint, not a native RMG implementation step. It joins
the existing Wine/Ghidra/Python summaries that explain why the current sampled
one-level land corpus does not naturally reach successful endpoint stamping.
It deliberately does not claim a global all-template proof.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_4A5E73_CURSOR = ROOT / "4a5e73_cursor_frontier_summary_20260610.json"
DEFAULT_4A5E73_CALLERS = ROOT / "4a5e73_caller_gate_surface_summary_20260610.json"
DEFAULT_4A606B = ROOT / "4a606b_reachability_summary_20260610.json"
DEFAULT_4A696B = ROOT / "4a696b_target_mode_reachability_summary_20260610.json"
DEFAULT_4A696B_GRID = ROOT / "medium_4a696b_grid_scan_aggregate_summary_20260610.json"
DEFAULT_PROJECTION_SLOT = ROOT / "projection_slot_target_mode_reachability_summary_20260610.json"
DEFAULT_CURSOR_SOURCE = ROOT / "cursor_source_frontier_summary_20260610.json"
DEFAULT_DIRECT_FRONTIER = ROOT / "direct_mode_recovery_frontier_summary_20260610.json"
DEFAULT_OUT = ROOT / "supported_land_endpoint_reachability_summary_20260610.json"


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
    cursor = load_json(args.four_a5e73_cursor)
    callers = load_json(args.four_a5e73_callers)
    four_a606b = load_json(args.four_a606b)
    four_a696b = load_json(args.four_a696b)
    four_a696b_grid = load_json(args.four_a696b_grid)
    projection_slot = load_json(args.projection_slot)
    cursor_source = load_json(args.cursor_source)
    direct_frontier = load_json(args.direct_frontier)

    summaries = {
        "4a5e73_cursor": cursor,
        "4a5e73_callers": callers,
        "4a606b": four_a606b,
        "4a696b": four_a696b,
        "4a696b_grid": four_a696b_grid,
        "projection_slot": projection_slot,
        "cursor_source": cursor_source,
        "direct_frontier": direct_frontier,
    }

    cursor_metrics = cursor.get("metrics", {})
    caller_metrics = callers.get("metrics", {})
    writer_metrics = cursor_source.get("metrics", {})
    grid_metrics = four_a696b_grid.get("metrics", {})
    four_a696b_metrics = four_a696b.get("metrics", {})
    four_a606b_metrics = four_a606b.get("metrics", {})
    projection_metrics = projection_slot.get("metrics", {})

    invariants = {
        "no_native_behavior_change": all(no_native_change(summary) for summary in summaries.values()),
        "no_objdump_used": all(no_objdump(summary) for summary in summaries.values()),
        "cursor_contract_recovered_no_success_path": (
            cursor.get("status")
            == "target_mode_4a5e73_cursor_precondition_recovered_success_path_unhit"
            and cursor.get("invariants", {}).get("current_corpus_has_no_5e73_success_path_hit")
            is True
            and cursor_metrics.get("runtime_5e73_success_path_event_count") == 0
        ),
        "all_5e73_callers_grouped_by_gate": (
            callers.get("status")
            == "4a5e73_all_caller_gate_surface_recovered_current_scope_success_path_still_unrecovered"
            and callers.get("invariants", {}).get("six_static_callers_recovered") is True
        ),
        "4a606b_static_contract_no_live_hit": (
            four_a606b.get("status") == "target_mode_4a606b_static_contract_recovered_no_live_hit"
            and four_a606b.get("invariants", {}).get("current_corpus_has_no_live_4a606b_hit")
            is True
            and four_a606b_metrics.get("runtime_4a606b_event_count") == 0
        ),
        "4a696b_pair_gate_explained_for_sampled_medium_land": (
            four_a696b.get("status")
            == "target_mode_4a696b_direct_mutation_unreached_pair_gate_explained"
            and four_a696b_grid.get("status")
            == "multi_seed_4a696b_source_relation_pair_gate_recovered"
            and grid_metrics.get("seed_count", 0) >= 3
            and grid_metrics.get("complete_grid_scan_count", 0) >= 6
            and grid_metrics.get("zero_owner_relation_pair_match_scan_count")
            == grid_metrics.get("complete_grid_scan_count")
        ),
        "projection_slot_recycle_boundary_explained_for_current_corpus": (
            projection_slot.get("status")
            == "projection_slot_target_mode_unreached_recycle_boundary_explained"
            and projection_slot.get("invariants", {}).get(
                "projection_methods_and_cleanup_have_zero_events"
            )
            is True
        ),
        "cursor_source_writer_surface_bounded": (
            cursor_source.get("status")
            == "cursor_source_frontier_setup_and_writer_surface_recovered_success_path_still_unrecovered"
            and cursor_source.get("invariants", {}).get("direct_f5c_writer_surface_exhausted")
            is True
            and cursor_source.get("invariants", {}).get(
                "non_self_f5c_writers_bound_to_unhit_projection_chain"
            )
            is True
        ),
        "direct_frontier_keeps_end_to_end_incomplete": (
            direct_frontier.get("status")
            == "direct_mode_recovery_frontier_verified_target_mode_exclusions"
            and direct_frontier.get("metrics", {}).get("overall_goal_complete") is False
        ),
    }

    status = (
        "sampled_one_level_land_endpoint_reachability_no_success_path_broader_source_gap_named"
        if all(invariants.values())
        else "sampled_one_level_land_endpoint_reachability_incomplete"
    )

    gate_chain = [
        {
            "path": "0x4a61bc -> 0x4a5e73",
            "current_evidence": (
                "Natural Border Guard samples reach the endpoint helper but use stale "
                "generator+0xf5c, so all observed entries return before mutation."
            ),
            "runtime_callsite_events": caller_metrics.get("current_corpus_4a61bc_callsite_events"),
        },
        {
            "path": "0x4a746b -> 0x4a5e73",
            "current_evidence": (
                "Forced +0x09 route reaches this helper twice, but both delegated endpoint "
                "calls fail before generated-cell mutation."
            ),
            "runtime_callsite_events": caller_metrics.get("current_corpus_4a746b_callsite_events"),
        },
        {
            "path": "0x4a696b -> 0x4a5e73",
            "current_evidence": (
                "Current one-level land payload calls are blocked before this callsite by "
                "the GeneratedCell+0x20 owner/relation byte-pair gate."
            ),
            "sampled_entries": four_a696b_metrics.get("combined_4a696b_entries"),
            "complete_grid_scans": grid_metrics.get("complete_grid_scan_count"),
            "scanned_cells": grid_metrics.get("scanned_cell_total"),
        },
        {
            "path": "0x4a6cf2 -> 0x4a5e73",
            "current_evidence": (
                "Both endpoint callsites are statically recovered, but they are static-only "
                "in the current corpus."
            ),
            "runtime_callsite_events": caller_metrics.get(
                "current_corpus_inactive_family_callsite_events"
            ),
        },
        {
            "path": "0x4adb72/0x4add76 cursor writers",
            "current_evidence": (
                "The non-self generator+0xf5c writers are bound to the projection/cleanup "
                "slot chain; current sampled projection objects are recycled before ordinary "
                "slot dispatch and the corpus has zero live projection/cleanup hits."
            ),
            "projection_slot_runtime_hits": projection_metrics.get("projection_or_cleanup_hit_count"),
        },
    ]

    return {
        "schema_id": "h3maped_sampled_one_level_land_endpoint_reachability_summary_v1",
        "status": status,
        "scope": (
            "Sampled supported one-level land recovery checkpoint for endpoint/cursor reachability. "
            "The inputs are existing Wine ledgers and Ghidra-derived summaries; this report does "
            "not run objdump, does not alter native RMG behavior, and does not claim global "
            "all-template or all-map-mode exclusion."
        ),
        "inputs": {
            "4a5e73_cursor": str(args.four_a5e73_cursor),
            "4a5e73_callers": str(args.four_a5e73_callers),
            "4a606b": str(args.four_a606b),
            "4a696b": str(args.four_a696b),
            "4a696b_grid": str(args.four_a696b_grid),
            "projection_slot": str(args.projection_slot),
            "cursor_source": str(args.cursor_source),
            "direct_frontier": str(args.direct_frontier),
        },
        "gate_chain": gate_chain,
        "metrics": {
            "runtime_5e73_entry_count": cursor_metrics.get("runtime_5e73_entry_count"),
            "runtime_5e73_success_path_event_count": cursor_metrics.get(
                "runtime_5e73_success_path_event_count"
            ),
            "runtime_4a606b_event_count": four_a606b_metrics.get("runtime_4a606b_event_count"),
            "static_4a5e73_callsite_count": caller_metrics.get("static_4a5e73_callsite_count"),
            "current_corpus_4a61bc_callsite_events": caller_metrics.get(
                "current_corpus_4a61bc_callsite_events"
            ),
            "current_corpus_4a746b_callsite_events": caller_metrics.get(
                "current_corpus_4a746b_callsite_events"
            ),
            "current_corpus_inactive_family_callsite_events": caller_metrics.get(
                "current_corpus_inactive_family_callsite_events"
            ),
            "medium_land_seed_count": grid_metrics.get("seed_count"),
            "medium_land_complete_4a696b_grid_scan_count": grid_metrics.get(
                "complete_grid_scan_count"
            ),
            "medium_land_4a696b_scanned_cell_total": grid_metrics.get("scanned_cell_total"),
            "medium_land_4a696b_zero_pair_match_scan_count": grid_metrics.get(
                "zero_owner_relation_pair_match_scan_count"
            ),
            "native_behavior_changed": False,
            "overall_goal_complete": False,
            "used_objdump": False,
        },
        "invariants": invariants,
        "source_backed_conclusion": (
            "For the current sampled one-level land evidence, no successful endpoint-stamping "
            "path is live. The live 0x4a61bc/0x4a746b paths reach 0x4a5e73 but fail on stale "
            "generator+0xf5c; the 0x4a696b direct path is blocked before its endpoint callsite "
            "by the owner/relation byte-pair gate; the 0x4a6cf2 endpoint sites are static-only "
            "in the corpus; and the non-self cursor writers are bound to projection/cleanup "
            "slots that current sampled objects do not dispatch."
        ),
        "remaining_gap": (
            "This does not prove that all supported one-level land templates, sizes, seeds, or "
            "source states can never seed generator+0xf5c. The remaining blocker is either a "
            "natural successful 0x4a5e73 -> 0x4a606b path, or a broader Ghidra/static-data/Wine "
            "proof that no supported one-level land source can make any recovered caller gate "
            "reach a seeded generator+0xf5c success path. Broader relation/control linkage, "
            "global descriptor labels, and cleanup/uncommit semantics remain unrecovered if "
            "future evidence reaches those paths."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--four-a5e73-cursor", type=Path, default=DEFAULT_4A5E73_CURSOR)
    parser.add_argument("--four-a5e73-callers", type=Path, default=DEFAULT_4A5E73_CALLERS)
    parser.add_argument("--four-a606b", type=Path, default=DEFAULT_4A606B)
    parser.add_argument("--four-a696b", type=Path, default=DEFAULT_4A696B)
    parser.add_argument("--four-a696b-grid", type=Path, default=DEFAULT_4A696B_GRID)
    parser.add_argument("--projection-slot", type=Path, default=DEFAULT_PROJECTION_SLOT)
    parser.add_argument("--cursor-source", type=Path, default=DEFAULT_CURSOR_SOURCE)
    parser.add_argument("--direct-frontier", type=Path, default=DEFAULT_DIRECT_FRONTIER)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    missing = [
        str(path)
        for path in [
            args.four_a5e73_cursor,
            args.four_a5e73_callers,
            args.four_a606b,
            args.four_a696b,
            args.four_a696b_grid,
            args.projection_slot,
            args.cursor_source,
            args.direct_frontier,
        ]
        if not path.exists()
    ]
    if missing:
        raise SystemExit(f"missing input summaries: {missing}")
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_SUPPORTED_LAND_ENDPOINT_REACHABILITY status={summary['status']} out={args.out}")
    return (
        0
        if summary["status"]
        == "sampled_one_level_land_endpoint_reachability_no_success_path_broader_source_gap_named"
        else 1
    )


if __name__ == "__main__":
    raise SystemExit(main())
