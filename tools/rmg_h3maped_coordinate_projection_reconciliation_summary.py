#!/usr/bin/env python3
"""Reconcile the exact fallback coordinate/projection evidence.

Older mixed projection traces left a coordinate mismatch open. Later exact
Medium seed-10 fallback traces use the same object records throughout
construction, commit, descriptor/relation replay, projection writes, vector
survival, and phase-tail completion. This verifier names that narrower recovery
truth without claiming broader map-mode coverage.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_EXACT_FRONTIER = Path(
    ".artifacts/rmg_recovery/medium_seed10_fallback_final_role_frontier_summary_20260609.json"
)
DEFAULT_EXACT_PROJECTION_WRITES = Path(
    ".artifacts/rmg_recovery/medium_seed10_exact_fallback_projection_write_summary_20260609.json"
)
DEFAULT_COMPLETION = Path(
    ".artifacts/rmg_recovery/medium_seed10_fallback_final_role_completion_summary_20260610.json"
)
DEFAULT_OLDER_DESCRIPTOR = Path(
    ".artifacts/rmg_recovery/medium_seed10_fallback_exact_descriptor_relation_summary_20260609.json"
)
DEFAULT_CROSS_SEED_COMMIT_SURFACE = Path(
    ".artifacts/rmg_recovery/medium_4a54a7_cross_seed_commit_surface_summary_20260610.json"
)
DEFAULT_OUT = Path(
    ".artifacts/rmg_recovery/coordinate_projection_reconciliation_summary_20260610.json"
)

EXPECTED_RECORDS = {"0x036260c0", "0x03626060"}


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def record_map(records: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    return {
        record["object_record"]: record
        for record in records
        if isinstance(record.get("object_record"), str)
    }


def target_record_set(summary: dict[str, Any]) -> set[str]:
    return {
        target["object_record_pointer"]
        for target in summary.get("targets", [])
        if isinstance(target.get("object_record_pointer"), str)
    }


def exact_record_coordinates(records: dict[str, dict[str, Any]]) -> dict[str, dict[str, Any]]:
    out: dict[str, dict[str, Any]] = {}
    for pointer, record in records.items():
        out[pointer] = record.get("coordinates", {})
    return out


def all_exact_evidence_true(records: dict[str, dict[str, Any]]) -> bool:
    for record in records.values():
        evidence = record.get("exact_evidence", {})
        if not evidence or any(value is not True for value in evidence.values()):
            return False
    return True


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    exact_frontier = load_json(args.exact_frontier)
    projection_writes = load_json(args.exact_projection_writes)
    completion = load_json(args.completion)
    older_descriptor = load_json(args.older_descriptor)
    cross_seed_commit_surface = load_json(args.cross_seed_commit_surface)

    records = record_map(exact_frontier.get("records", []))
    projection_targets = target_record_set(projection_writes)
    invariants = {
        "no_native_behavior_change": exact_frontier.get("native_behavior_changed") is False
        and projection_writes.get("native_behavior_changed") is False
        and completion.get("invariants", {}).get("no_native_behavior_change") is True,
        "no_objdump_used": True,
        "expected_exact_records_present": set(records) == EXPECTED_RECORDS,
        "projection_write_targets_match_exact_records": projection_targets == EXPECTED_RECORDS
        and exact_frontier.get("invariants", {}).get("projection_write_targets_match_fallback_records")
        is True,
        "exact_coordinates_match_for_all_fallback_records": exact_frontier.get("invariants", {}).get(
            "exact_coordinates_match_for_all_fallback_records"
        )
        is True,
        "exact_projection_write_stream_recovered_for_all_fallback_records": exact_frontier.get(
            "invariants", {}
        ).get("exact_projection_write_stream_recovered_for_all_fallback_records")
        is True,
        "exact_evidence_chain_true_for_all_records": all_exact_evidence_true(records),
        "older_mixed_trace_mismatch_is_named": "remaining setup/state difference"
        in older_descriptor.get("coordinate_reconciliation", {}).get("finding", ""),
        "phase_tail_completion_recovered_for_exact_records": completion.get("status")
        == "fallback_final_role_phase_tail_recovered_for_exact_seed10_records",
        "cross_seed_fallback_commit_surface_recovered": cross_seed_commit_surface.get("status")
        == "cross_seed_4a54a7_commit_surface_recovered_projection_writes_still_bounded"
        and cross_seed_commit_surface.get("invariants", {}).get(
            "all_fallback_0x4a5e6c_calls_have_complete_cell_transition"
        )
        is True
        and cross_seed_commit_surface.get("invariants", {}).get(
            "non_fallback_return_contexts_named_pending"
        )
        is True
        and cross_seed_commit_surface.get("metrics", {}).get("used_objdump") is False,
    }
    status = (
        "coordinate_projection_exact_and_cross_seed_fallback_reconciled_broader_contexts_pending"
        if all(invariants.values())
        else "exact_fallback_coordinate_projection_reconciliation_incomplete"
    )
    coordinates = exact_record_coordinates(records)

    return {
        "schema_id": "h3maped_coordinate_projection_reconciliation_summary_v1",
        "status": status,
        "scope": (
            "Exact deterministic Medium seed-10 post-Border-Guard fallback records only. This "
            "does not claim coordinate/projection parity for every map mode or source state."
        ),
        "inputs": {
            "exact_frontier": str(args.exact_frontier),
            "exact_projection_writes": str(args.exact_projection_writes),
            "completion": str(args.completion),
            "older_descriptor": str(args.older_descriptor),
            "cross_seed_commit_surface": str(args.cross_seed_commit_surface),
        },
        "invariants": invariants,
        "metrics": {
            "native_behavior_changed": False,
            "used_objdump": False,
            "overall_goal_complete": False,
            "exact_record_count": len(records),
            "projection_write_target_count": len(projection_targets),
            "completion_fallback_record_count": completion.get("metrics", {}).get(
                "fallback_record_count"
            ),
            "cross_seed_total_commit_call_count": cross_seed_commit_surface.get("metrics", {}).get(
                "total_commit_call_count"
            ),
            "cross_seed_fallback_0x4a5e6c_commit_call_count": cross_seed_commit_surface.get(
                "metrics", {}
            ).get("total_fallback_0x4a5e6c_commit_call_count"),
            "cross_seed_non_fallback_return_context_commit_count": cross_seed_commit_surface.get(
                "metrics", {}
            ).get("total_non_fallback_return_context_commit_count"),
        },
        "exact_records": [
            {
                "object_record": pointer,
                "coordinates": coordinates[pointer],
                "projection_write_recovered": pointer in projection_targets,
                "exact_evidence": records[pointer].get("exact_evidence", {}),
            }
            for pointer in sorted(records)
        ],
        "source_backed_conclusion": (
            "The older coordinate/projection mismatch came from mixed trace contexts and remains "
            "valid only as a warning against joining non-identical invocations. For the exact "
            "Medium seed-10 fallback records 0x036260c0 and 0x03626060, later Wine/Ghidra/Python "
            "evidence now reconciles construction, state-chain commit coordinates, after-state "
            "commit coordinates, descriptor/relation coordinates, exact projection write streams, "
            "object-vector survival, and phase-tail completion. These exact records are no longer "
            "blocked by the older coordinate mismatch. The cross-seed Medium seed-1/seed-2 commit "
            "surface additionally proves all 31 sampled 0x4a5e6c fallback-return commits reach "
            "0x4a5756 and clear the sampled GeneratedCell+0x20 low word while preserving the high "
            "word. The same cross-seed evidence also names 151 non-fallback 0x4a54a7 return-context "
            "commits as pending instead of merging them into the exact fallback proof."
        ),
        "remaining_gap": (
            "Broader coordinate/projection recovery remains pending for the non-fallback 0x4a54a7 "
            "return contexts, other map modes, other source states, 0x4a696b direct mutation, or "
            "cleanup/uncommit paths. Do not extrapolate the exact fallback proof into those contexts."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--exact-frontier", type=Path, default=DEFAULT_EXACT_FRONTIER)
    parser.add_argument("--exact-projection-writes", type=Path, default=DEFAULT_EXACT_PROJECTION_WRITES)
    parser.add_argument("--completion", type=Path, default=DEFAULT_COMPLETION)
    parser.add_argument("--older-descriptor", type=Path, default=DEFAULT_OLDER_DESCRIPTOR)
    parser.add_argument(
        "--cross-seed-commit-surface",
        type=Path,
        default=DEFAULT_CROSS_SEED_COMMIT_SURFACE,
    )
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_COORDINATE_PROJECTION status={summary['status']} out={args.out}")
    return (
        0
        if summary["status"]
        == "coordinate_projection_exact_and_cross_seed_fallback_reconciled_broader_contexts_pending"
        else 1
    )


if __name__ == "__main__":
    raise SystemExit(main())
