#!/usr/bin/env python3
"""Resolve the current endpoint/candidate blockers for supported one-level land.

This is a recovery checkpoint, not native RMG implementation. It consolidates
existing Wine/Ghidra/Python evidence for three previously open blockers:

* 0x540ca0 / 0x49cd97 selected-create candidate scorer
* 0x4a696b direct source/relation mutation path
* 0x4a5e73 -> 0x4a606b endpoint-stamping path

The result is intentionally scoped to the supported one-level land target mode.
It does not claim global reachability/exclusion for every H3MapEd map mode.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_F5C = ROOT / "f5c_candidate_live_gate_summary_20260610.json"
DEFAULT_CURSOR = ROOT / "cursor_source_frontier_summary_20260610.json"
DEFAULT_4A696B = ROOT / "4a696b_target_mode_reachability_summary_20260610.json"
DEFAULT_ENDPOINT = ROOT / "supported_land_endpoint_reachability_summary_20260610.json"
DEFAULT_PROJECTION = ROOT / "projection_slot_target_mode_reachability_summary_20260610.json"
DEFAULT_DIRECT = ROOT / "direct_mode_recovery_frontier_summary_20260610.json"
DEFAULT_OUT = ROOT / "endpoint_blocker_resolution_summary_20260610.json"


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def invariant(summary: dict[str, Any], key: str) -> bool:
    return summary.get("invariants", {}).get(key) is True


def metric_int(summary: dict[str, Any], key: str) -> int:
    value = summary.get("metrics", {}).get(key, 0)
    return int(value or 0)


def no_native_change(summary: dict[str, Any]) -> bool:
    return (
        summary.get("native_behavior_changed") is False
        or summary.get("metrics", {}).get("native_behavior_changed") is False
        or summary.get("invariants", {}).get("no_native_behavior_change") is True
    )


def no_objdump(summary: dict[str, Any]) -> bool:
    return (
        summary.get("used_objdump") is False
        or summary.get("metrics", {}).get("used_objdump") is False
        or summary.get("invariants", {}).get("no_objdump_used") is True
    )


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    f5c = load_json(args.f5c)
    cursor = load_json(args.cursor)
    four_a696b = load_json(args.four_a696b)
    endpoint = load_json(args.endpoint)
    projection = load_json(args.projection)
    direct = load_json(args.direct)

    inputs = {
        "f5c_candidate_live_gate": f5c,
        "cursor_source_frontier": cursor,
        "4a696b_target_mode": four_a696b,
        "supported_land_endpoint_reachability": endpoint,
        "projection_slot_target_mode": projection,
        "direct_mode_frontier": direct,
    }

    f5c_resolved = (
        f5c.get("status")
        == "f5c_candidate_live_scorer_rejects_selector_context_cursor_sampled_scope"
        and invariant(f5c, "static_scorer_contract_present")
        and invariant(f5c, "selector_passes_entry_ecx_as_second_score_arg")
        and invariant(f5c, "branch_scan_has_zero_match_or_constructor")
        and invariant(f5c, "deep_trace_has_zero_match_or_constructor")
        and metric_int(f5c, "combined_reject_branch_count") >= 493
        and metric_int(f5c, "combined_match_branch_count") == 0
        and metric_int(f5c, "combined_constructor_count") == 0
        and invariant(cursor, "setup_initializes_f58_not_f5c")
        and invariant(cursor, "direct_f5c_writer_surface_exhausted")
        and invariant(cursor, "non_self_f5c_writers_bound_to_unhit_projection_chain")
        and invariant(projection, "sampled_projection_to_ordinary_reuse_recovered")
        and invariant(projection, "projection_methods_and_cleanup_have_zero_events")
    )

    four_a696b_resolved = (
        four_a696b.get("status")
        == "target_mode_4a696b_direct_mutation_unreached_pair_gate_explained"
        and invariant(four_a696b, "static_gate_order_recovered")
        and invariant(four_a696b, "static_direct_call_refs_only_from_4a79a3_sites")
        and invariant(four_a696b, "corpus_has_4a696b_entries")
        and invariant(four_a696b, "corpus_has_no_source_relation_match_or_deeper_hit")
        and invariant(four_a696b, "multi_seed_full_grid_scans_exist")
        and invariant(four_a696b, "multi_seed_scans_have_zero_owner_relation_pair_matches")
        and metric_int(four_a696b, "combined_source_relation_match_hits") == 0
        and metric_int(four_a696b, "combined_direct_mutation_hits") == 0
    )

    endpoint_resolved = (
        endpoint.get("status")
        == "sampled_one_level_land_endpoint_reachability_no_success_path_broader_source_gap_named"
        and invariant(endpoint, "cursor_contract_recovered_no_success_path")
        and invariant(endpoint, "all_5e73_callers_grouped_by_gate")
        and invariant(endpoint, "4a606b_static_contract_no_live_hit")
        and invariant(endpoint, "4a696b_pair_gate_explained_for_sampled_medium_land")
        and invariant(endpoint, "cursor_source_writer_surface_bounded")
        and invariant(endpoint, "projection_slot_recycle_boundary_explained_for_current_corpus")
        and metric_int(endpoint, "runtime_5e73_success_path_event_count") == 0
        and metric_int(endpoint, "runtime_4a606b_event_count") == 0
        and invariant(cursor, "widened_ghidra_endpoint_access_confirms_f5c_writer_surface")
        and invariant(cursor, "current_4a606b_no_live_hit_depends_on_4a5e73_failure")
    )

    direct_frontier_resolved = (
        direct.get("status") == "direct_mode_recovery_frontier_verified_target_mode_exclusions"
        and invariant(direct, "4a696b_current_target_mode_unreached")
        and invariant(direct, "projection_slot_current_target_mode_unreached")
        and invariant(direct, "cleanup_dependency_downstream_of_unhit_projection_slot")
    )

    invariants = {
        "no_native_behavior_change": all(no_native_change(summary) for summary in inputs.values()),
        "no_objdump_used": all(no_objdump(summary) for summary in inputs.values()),
        "f5c_candidate_540ca0_49cd97_resolved_for_supported_one_level_land": f5c_resolved,
        "4a696b_direct_mutation_resolved_for_supported_one_level_land": four_a696b_resolved,
        "4a5e73_to_4a606b_endpoint_stamping_resolved_for_supported_one_level_land": endpoint_resolved,
        "direct_frontier_agrees_target_mode_exclusions": direct_frontier_resolved,
    }
    status = (
        "supported_one_level_land_endpoint_blockers_resolved_as_target_mode_exclusions"
        if all(invariants.values())
        else "supported_one_level_land_endpoint_blocker_resolution_incomplete"
    )

    return {
        "schema_id": "h3maped_supported_land_endpoint_blocker_resolution_summary_v1",
        "status": status,
        "scope": (
            "Supported one-level land target-mode resolution for the current native RMG "
            "recovery blockers. This is source-backed exclusion for the selected target mode, "
            "not a global all-map-mode H3MapEd exclusion and not native implementation authority."
        ),
        "inputs": {
            "f5c_candidate_live_gate": str(args.f5c),
            "cursor_source_frontier": str(args.cursor),
            "4a696b_target_mode": str(args.four_a696b),
            "supported_land_endpoint_reachability": str(args.endpoint),
            "projection_slot_target_mode": str(args.projection),
            "direct_mode_frontier": str(args.direct),
        },
        "invariants": invariants,
        "resolved_blockers": [
            {
                "id": "0x540ca0_0x49cd97",
                "resolution": "target_mode_excluded",
                "reason": (
                    "The live scorer rejects every sampled one-level land call: static Ghidra "
                    "shows 0x49cd97 compares selector-context +0xf5c against candidate +0x08, "
                    "0x4a9f1c passes entry ECX as that score context, and the Wine corpus has "
                    "zero match-branch or constructor hits. The cursor-source frontier proves "
                    "setup writes +0xf58, not +0xf5c; direct +0xf5c writers are bounded; and "
                    "the non-self writers are behind the unhit projection/cleanup chain."
                ),
            },
            {
                "id": "0x4a696b",
                "resolution": "target_mode_excluded",
                "reason": (
                    "Static Ghidra recovers the direct-mutation gate order and callsites. "
                    "Wine corpus and multi-seed full-grid scans show zero owner/relation "
                    "byte-pair matches, zero candidate appends, and zero direct GeneratedCell "
                    "mutation hits for the supported one-level land target mode."
                ),
            },
            {
                "id": "0x4a5e73_to_0x4a606b",
                "resolution": "target_mode_excluded",
                "reason": (
                    "All static 0x4a5e73 caller gates are grouped. Current live callers fail "
                    "before success because generator+0xf5c is stale/unseeded; 0x4a696b is "
                    "blocked before its endpoint callsite; 0x4a6cf2 callsites are static-only "
                    "in the current corpus; non-self +0xf5c writers are behind projection/"
                    "cleanup slots whose sampled projection objects are destroyed/freed/reused "
                    "before final dispatch; and 0x4a606b has zero live hits."
                ),
            },
        ],
        "metrics": {
            "f5c_combined_reject_branch_count": metric_int(f5c, "combined_reject_branch_count"),
            "f5c_combined_match_branch_count": metric_int(f5c, "combined_match_branch_count"),
            "f5c_combined_constructor_count": metric_int(f5c, "combined_constructor_count"),
            "4a696b_combined_entries": metric_int(four_a696b, "combined_4a696b_entries"),
            "4a696b_complete_grid_scan_count": metric_int(four_a696b, "complete_grid_scan_count"),
            "4a696b_scanned_cell_total": metric_int(four_a696b, "scanned_cell_total"),
            "4a696b_source_relation_match_hits": metric_int(
                four_a696b, "combined_source_relation_match_hits"
            ),
            "runtime_5e73_entry_count": metric_int(endpoint, "runtime_5e73_entry_count"),
            "runtime_5e73_success_path_event_count": metric_int(
                endpoint, "runtime_5e73_success_path_event_count"
            ),
            "runtime_4a606b_event_count": metric_int(endpoint, "runtime_4a606b_event_count"),
            "projection_or_cleanup_event_hits_total": metric_int(
                projection, "cleanup_or_projection_target_event_hits_total"
            ),
            "native_behavior_changed": False,
            "used_objdump": False,
            "overall_goal_complete": False,
        },
        "source_backed_conclusion": (
            "For the supported one-level land target mode, the three named endpoint/candidate "
            "blockers are no longer active recovery blockers. They resolve as target-mode "
            "exclusions: 0x540ca0/0x49cd97 is a live but rejecting +0xf5c-gated scorer, "
            "0x4a696b is blocked by the GeneratedCell+0x20 owner/relation byte-pair gate, "
            "and the 0x4a5e73 -> 0x4a606b endpoint-stamping path has no seeded +0xf5c success "
            "route in the recovered one-level land evidence."
        ),
        "remaining_gap": (
            "This does not make native RMG 100% recovered. Remaining end-to-end work moves to "
            "the human/source-catalog labels, descriptor policy/container names, auxiliary "
            "0x490a11 stream record label/consumer, final source catalog/object-template mapping, "
            "and any future non-one-level-land or unsupported source state that reaches these "
            "excluded paths. Do not implement density scalars, brute-force retries, or native "
            "behavior guesses from this exclusion summary."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--f5c", type=Path, default=DEFAULT_F5C)
    parser.add_argument("--cursor", type=Path, default=DEFAULT_CURSOR)
    parser.add_argument("--four-a696b", type=Path, default=DEFAULT_4A696B)
    parser.add_argument("--endpoint", type=Path, default=DEFAULT_ENDPOINT)
    parser.add_argument("--projection", type=Path, default=DEFAULT_PROJECTION)
    parser.add_argument("--direct", type=Path, default=DEFAULT_DIRECT)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_ENDPOINT_BLOCKER_RESOLUTION "
        f"status={summary['status']} out={args.out}"
    )
    return (
        0
        if summary["status"]
        == "supported_one_level_land_endpoint_blockers_resolved_as_target_mode_exclusions"
        else 1
    )


if __name__ == "__main__":
    raise SystemExit(main())
