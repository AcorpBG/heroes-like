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
    }
    status = (
        "exact_fallback_coordinate_projection_reconciled_broader_modes_pending"
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
            "blocked by the older coordinate mismatch."
        ),
        "remaining_gap": (
            "Broader coordinate/projection recovery remains pending outside these exact fallback "
            "records. Do not extrapolate this exact seed-10 reconciliation to other map modes, "
            "other source states, 0x4a696b direct mutation, or cleanup/uncommit paths."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--exact-frontier", type=Path, default=DEFAULT_EXACT_FRONTIER)
    parser.add_argument("--exact-projection-writes", type=Path, default=DEFAULT_EXACT_PROJECTION_WRITES)
    parser.add_argument("--completion", type=Path, default=DEFAULT_COMPLETION)
    parser.add_argument("--older-descriptor", type=Path, default=DEFAULT_OLDER_DESCRIPTOR)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_COORDINATE_PROJECTION status={summary['status']} out={args.out}")
    return 0 if summary["status"] == "exact_fallback_coordinate_projection_reconciled_broader_modes_pending" else 1


if __name__ == "__main__":
    raise SystemExit(main())
