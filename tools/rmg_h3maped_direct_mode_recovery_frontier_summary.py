#!/usr/bin/env python3
"""Summarize the current direct one-level land H3MapEd RMG recovery frontier.

This verifier does not recover a new H3MapEd phase by itself. It is a guard
against stale tracker language: it consumes the focused Wine/Ghidra summaries
that already proved several suspected blockers are target-mode exclusions, then
emits the remaining direct-mode blockers that still need real recovery before
native RMG behavior can be ported.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_SOURCE_HANDLER = Path(
    ".artifacts/rmg_recovery/source_handler_owner_chain_summary_20260610.json"
)
DEFAULT_4A696B = Path(
    ".artifacts/rmg_recovery/4a696b_target_mode_reachability_summary_20260610.json"
)
DEFAULT_PROJECTION_SLOT = Path(
    ".artifacts/rmg_recovery/projection_slot_target_mode_reachability_summary_20260610.json"
)
DEFAULT_FALLBACK_FINAL_ROLE = Path(
    ".artifacts/rmg_recovery/medium_seed10_fallback_final_role_completion_summary_20260610.json"
)
DEFAULT_COORDINATE_RECONCILIATION = Path(
    ".artifacts/rmg_recovery/coordinate_projection_reconciliation_summary_20260610.json"
)
DEFAULT_SEMANTIC_FRONTIER = Path(".artifacts/rmg_recovery/semantic_frontier_summary_20260610.json")
DEFAULT_OUT = Path(
    ".artifacts/rmg_recovery/direct_mode_recovery_frontier_summary_20260610.json"
)

EXPECTED_STATUSES = {
    "source_handler_owner": "source_handler_chain_classified_static_orphan_for_direct_rmg_owner",
    "4a696b_target_mode": "target_mode_4a696b_direct_mutation_unreached_pair_gate_explained",
    "projection_slot_target_mode": "projection_slot_target_mode_unreached_recycle_boundary_explained",
    "fallback_final_role": "fallback_final_role_phase_tail_recovered_for_exact_seed10_records",
    "coordinate_projection_reconciliation": (
        "exact_fallback_coordinate_projection_reconciled_broader_modes_pending"
    ),
    "semantic_frontier": (
        "semantic_frontier_working_names_seed10_chain_4a5e73_and_4a606b_frontiers_recovered_broader_scope_pending"
    ),
}


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
    return invariants.get("no_objdump_used") is True and metrics.get("used_objdump", False) is False


def status_matches(summary: dict[str, Any], expected: str) -> bool:
    return summary.get("status") == expected


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    inputs = {
        "source_handler_owner": args.source_handler_owner,
        "4a696b_target_mode": args.four_a696b_target_mode,
        "projection_slot_target_mode": args.projection_slot_target_mode,
        "fallback_final_role": args.fallback_final_role,
        "coordinate_projection_reconciliation": args.coordinate_projection_reconciliation,
        "semantic_frontier": args.semantic_frontier,
    }
    summaries = {name: load_json(path) for name, path in inputs.items()}

    input_invariants = {
        name: {
            "status_matches_expected": status_matches(summary, EXPECTED_STATUSES[name]),
            "no_native_behavior_change": no_native_change(summary),
            "no_objdump_used": no_objdump(summary),
        }
        for name, summary in summaries.items()
    }
    recovered_target_mode_exclusions = [
        {
            "id": "source_handler_0x53eafc_chain",
            "classification": "static_orphan_for_current_direct_generation_owner",
            "evidence": str(args.source_handler_owner),
            "scope": (
                "Ghidra refs close the chain under 0x484d9f, Ghidra reports no incoming refs "
                "to 0x484d9f, and the existing Wine direct-generation probe armed 0x484d9f "
                "without a breakpoint stop."
            ),
        },
        {
            "id": "0x4a696b_direct_generated_cell_0x28_mutation",
            "classification": "unreached_in_current_one_level_land_target_mode",
            "evidence": str(args.four_a696b_target_mode),
            "scope": (
                "Current one-level land evidence has 150 sampled 0x4a696b entries and six "
                "complete Medium full-grid scans with zero source/relation byte-pair matches, "
                "zero candidate appends, and zero direct mutation hits."
            ),
        },
        {
            "id": "projection_slot_0x08_cleanup_chain",
            "classification": "unreached_in_current_one_level_land_target_mode",
            "evidence": str(args.projection_slot_target_mode),
            "scope": (
                "Projection slot methods 0x49c019/0x49c0a6 and cleanup methods remain static "
                "real code, but current Wine ledgers/logs have zero live hits and sampled "
                "projection objects are destroyed/freed before ordinary final slot dispatch."
            ),
        },
    ]
    recovered_active_phase_checkpoints = [
        {
            "id": "medium_seed10_fallback_final_role_phase_tail",
            "evidence": str(args.fallback_final_role),
            "scope": (
                "Exact seed-10 fallback records are identified, adopted, absent from the sampled "
                "prior payload, and survive to the 0x4ac552 phase tail."
            ),
        },
        {
            "id": "exact_seed10_fallback_coordinate_projection_reconciliation",
            "evidence": str(args.coordinate_projection_reconciliation),
            "scope": (
                "The old mixed-trace coordinate mismatch is superseded for exact fallback "
                "records 0x036260c0 and 0x03626060: construction, state-chain commit, "
                "after-state commit, descriptor/relation coordinates, exact projection writes, "
                "object-vector survival, and phase-tail completion now line up for those records."
            ),
        },
        {
            "id": "working_semantic_name_frontier",
            "evidence": str(args.semantic_frontier),
            "scope": (
                "Connection record bytes, candidate record fields, exact descriptor projection "
                "fields, relation occupancy counters, and selected GeneratedCell +0x20 roles "
                "now have source-backed working names. Connection byte +0x09 is recovered as "
                "the template connection Border Guard flag, and the exact seed-10 Border Guard "
                "downstream chain is recovered through phase tail. 0x4a5e73 is recovered as "
                "the cursor-keyed endpoint helper with zero current success-path hits, and "
                "0x4a606b is statically recovered with no live hit in the current corpus. "
                "Broader linkage and global human labels remain pending."
            ),
        }
    ]
    remaining_blockers = [
        {
            "id": "broader_coordinate_projection_reconciliation_outside_exact_records",
            "reason": (
                "Exact Medium seed-10 fallback records are reconciled, but other records, "
                "map modes, and source states still need coordinate/projection proof before "
                "native behavior changes."
            ),
        },
        {
            "id": "remaining_downstream_semantics_and_global_labels",
            "reason": (
                "Working names and the exact seed-10 Border Guard downstream chain are recovered, "
                "0x4a5e73 is recovered as the cursor-keyed endpoint helper with no current "
                "success-path hits, and 0x4a606b is statically recovered with no live hit in the "
                "current corpus. Broader relation/control linkage, the source path that seeds "
                "generator+0xf5c before successful endpoint stamping or excludes that path in "
                "broader map/source states, global descriptor type labels, and cleanup/uncommit "
                "semantics remain pending."
            ),
        },
        {
            "id": "broader_map_mode_or_source_state_reachability",
            "reason": (
                "The 0x4a696b and projection-slot exclusions are proven for the current one-level "
                "land target evidence only. Other H3MapEd modes/source states still require either "
                "natural Wine hits or Ghidra/static-data proof before being implemented or excluded."
            ),
        },
        {
            "id": "runtime_cleanup_uncommit_state_if_reached",
            "reason": (
                "Cleanup/uncommit state behind 0x49c019/0x49c0a6 remains unavailable if a future "
                "natural projection-slot path is found; it should not be implemented from guesses."
            ),
        },
    ]

    invariants = {
        "no_native_behavior_change": all(
            entry["no_native_behavior_change"] for entry in input_invariants.values()
        ),
        "no_objdump_used": all(entry["no_objdump_used"] for entry in input_invariants.values()),
        "all_input_statuses_match_expected": all(
            entry["status_matches_expected"] for entry in input_invariants.values()
        ),
        "source_handler_not_active_direct_mode_blocker": status_matches(
            summaries["source_handler_owner"], EXPECTED_STATUSES["source_handler_owner"]
        ),
        "4a696b_current_target_mode_unreached": status_matches(
            summaries["4a696b_target_mode"], EXPECTED_STATUSES["4a696b_target_mode"]
        ),
        "projection_slot_current_target_mode_unreached": status_matches(
            summaries["projection_slot_target_mode"],
            EXPECTED_STATUSES["projection_slot_target_mode"],
        ),
        "fallback_final_role_exact_seed10_checkpoint_recovered": status_matches(
            summaries["fallback_final_role"], EXPECTED_STATUSES["fallback_final_role"]
        ),
        "exact_fallback_coordinate_projection_reconciled": status_matches(
            summaries["coordinate_projection_reconciliation"],
            EXPECTED_STATUSES["coordinate_projection_reconciliation"],
        ),
        "working_semantic_name_frontier_recovered": status_matches(
            summaries["semantic_frontier"], EXPECTED_STATUSES["semantic_frontier"]
        ),
    }
    status = (
        "direct_mode_recovery_frontier_verified_target_mode_exclusions"
        if all(invariants.values())
        else "direct_mode_recovery_frontier_inputs_incomplete"
    )

    return {
        "schema_id": "h3maped_direct_mode_recovery_frontier_summary_v1",
        "status": status,
        "scope": (
            "Current direct one-level land H3MapEd RMG recovery frontier. This is not a full "
            "end-to-end recovery completion claim and not authority to edit native RMG behavior."
        ),
        "inputs": {name: str(path) for name, path in inputs.items()},
        "expected_statuses": EXPECTED_STATUSES,
        "input_invariants": input_invariants,
        "invariants": invariants,
        "recovered_target_mode_exclusions": recovered_target_mode_exclusions,
        "recovered_active_phase_checkpoints": recovered_active_phase_checkpoints,
        "remaining_blockers_before_native_port": remaining_blockers,
        "metrics": {
            "native_behavior_changed": False,
            "used_objdump": False,
            "overall_goal_complete": False,
            "recovered_target_mode_exclusion_count": len(recovered_target_mode_exclusions),
            "remaining_blocker_count": len(remaining_blockers),
        },
        "source_backed_conclusion": (
            "The current one-level land target-mode frontier has enough Wine/Ghidra evidence to "
            "remove three stale active blockers: the 0x53eafc source-handler chain is a static "
            "orphan for the current direct-generation owner, 0x4a696b's direct mutation block is "
            "unreached because the source/relation byte-pair gate never matches, and projection "
            "slot +0x08 cleanup is unreached because sampled projection objects are destroyed/"
            "freed before ordinary final dispatch. These are target-mode exclusions, not global "
            "proofs for every H3MapEd map mode. Exact seed-10 fallback coordinate/projection "
            "state is also reconciled for records 0x036260c0 and 0x03626060. Several "
            "formerly hex-only fields now have source-backed working names, including +0x09 as "
            "the template connection Border Guard flag; the exact seed-10 Border Guard chain now "
            "has recovered fallback materialization and phase-tail evidence. 0x4a5e73 now has "
            "a recovered cursor-precondition frontier with current-corpus zero success-path hits, "
            "and 0x4a606b has a recovered static contract and current-corpus no-live-hit evidence."
        ),
        "remaining_gap": (
            "End-to-end recovery remains incomplete. Do not port or compensate native RMG behavior "
            "until broader coordinate/projection coverage, remaining semantic producers/global labels, and any "
            "future non-current-mode reachability gaps are recovered from Wine/Ghidra evidence."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-handler-owner", type=Path, default=DEFAULT_SOURCE_HANDLER)
    parser.add_argument("--four-a696b-target-mode", type=Path, default=DEFAULT_4A696B)
    parser.add_argument("--projection-slot-target-mode", type=Path, default=DEFAULT_PROJECTION_SLOT)
    parser.add_argument("--fallback-final-role", type=Path, default=DEFAULT_FALLBACK_FINAL_ROLE)
    parser.add_argument(
        "--coordinate-projection-reconciliation",
        type=Path,
        default=DEFAULT_COORDINATE_RECONCILIATION,
    )
    parser.add_argument("--semantic-frontier", type=Path, default=DEFAULT_SEMANTIC_FRONTIER)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_DIRECT_MODE_FRONTIER status={summary['status']} out={args.out}")
    return 0 if summary["status"] == "direct_mode_recovery_frontier_verified_target_mode_exclusions" else 1


if __name__ == "__main__":
    raise SystemExit(main())
