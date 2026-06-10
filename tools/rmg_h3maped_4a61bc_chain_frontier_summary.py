#!/usr/bin/env python3
"""Consolidate the sampled 0x4a61bc append-to-downstream recovery chain.

This is a recovery checkpoint only. It consumes existing Wine/Ghidra/Python
summary artifacts and verifies the sampled chain:

0x4a79a3 -> 0x49b3fb -> 0x4a61bc -> 0x4a5e03 -> 0x4a54a7
    -> 0x4a79a3 payload -> 0x4a696b / 0x4a7605

No native RMG behavior is changed or authorized by this report.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_OUT = Path(".artifacts/rmg_recovery/4a61bc_chain_frontier_summary_20260610.json")

ARTIFACTS = {
    "internal_growth": Path(".artifacts/rmg_recovery/4a79a3_internal_growth_summary_20260609.json"),
    "internal_append": Path(".artifacts/rmg_recovery/4a61bc_internal_append_summary_20260609.json"),
    "commit_boundary": Path(".artifacts/rmg_recovery/4a61bc_4a5e03_commit_boundary_summary_20260609.json"),
    "dynamic_commit": Path(".artifacts/rmg_recovery/4a61bc_4a54a7_dynamic_aggregate_summary_20260609.json"),
    "payload_link": Path(".artifacts/rmg_recovery/4a61bc_payload_link_summary_20260609.json"),
    "payload_dispatch": Path(".artifacts/rmg_recovery/4a61bc_payload_seed10_medium_dispatch_summary_20260609.json"),
    "controlled_4a696b": Path(".artifacts/rmg_recovery/medium_controlled_4a696b_sweep_summary_20260609.json"),
}

STATUS_RECOVERED = "4a61bc_append_commit_payload_downstream_frontier_recovered"
STATUS_INCOMPLETE = "4a61bc_append_commit_payload_downstream_frontier_incomplete"


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def invariants_pass(mapping: dict[str, Any] | None) -> bool:
    if not mapping:
        return False
    for key, value in mapping.items():
        if key == "native_behavior_changed":
            if value is not False:
                return False
            continue
        if value is not True:
            return False
    return True


def artifact_status(summary: dict[str, Any]) -> str | None:
    return summary.get("status") or summary.get("schema")


def summarize(artifact_paths: dict[str, Path]) -> dict[str, Any]:
    artifacts = {name: read_json(path) for name, path in artifact_paths.items()}

    growth = artifacts["internal_growth"]
    append = artifacts["internal_append"]
    boundary = artifacts["commit_boundary"]
    dynamic = artifacts["dynamic_commit"]
    link = artifacts["payload_link"]
    dispatch = artifacts["payload_dispatch"]
    sweep = artifacts["controlled_4a696b"]

    growth_invariants = growth.get("invariants", {})
    link_invariants = link.get("invariants", {})
    dispatch_invariants = dispatch.get("invariants", {})
    sweep_invariants = sweep.get("invariants", {})

    complete_boundary_count = boundary.get("complete_sequence_count", 0)
    dynamic_write_values = (dynamic.get("projection_write_count_range") or {}).get("values") or []
    sweep_metrics = sweep.get("metrics", {})
    dispatch_counts = dispatch.get("address_counts", {})

    invariants = {
        "all_expected_artifacts_present": all(path.exists() for path in artifact_paths.values()),
        "no_native_behavior_changed": all(
            artifact.get("native_behavior_changed") is False
            for artifact in artifacts.values()
            if "native_behavior_changed" in artifact
        ),
        "internal_growth_boundary_recovered": (
            growth.get("status") == "4a79a3_internal_growth_4a61bc_append_boundary_recovered"
            and invariants_pass(growth_invariants)
            and growth.get("positive_append_count") == 6
            and growth.get("positive_append_delta") == 6
            and growth.get("reallocation_count") == 1
        ),
        "internal_append_delegates_to_4a5e03": (
            append.get("schema") == "h3maped_rmg_4a61bc_internal_append_summary_v1"
            and "0x4a6578 -> 0x4a5e03 -> 0x4a657d" in append.get("recovered_contract", "")
            and "stays stable" in append.get("recovered_contract", "")
        ),
        "commit_boundary_reaches_4a54a7": (
            complete_boundary_count >= 5
            and boundary.get("complete_sequences_coordinate_matches_commit") == complete_boundary_count
            and boundary.get("complete_sequences_object_pointer_matches_commit") == complete_boundary_count
            and boundary.get("complete_sequences_growing_by_0x4a54a7_return") == complete_boundary_count
            and boundary.get("complete_sequences_with_pre_commit_growth") == 0
        ),
        "dynamic_4a54a7_write_contract_recovered": (
            dynamic.get("stream_count") == 3
            and dynamic.get("all_streams_all_invariants_true") is True
            and dynamic.get("distinct_object_record_count") == 3
            and dynamic.get("distinct_target_cell_count") == 3
            and len(dynamic_write_values) == 3
            and min(dynamic_write_values) > 0
        ),
        "selected_append_reaches_payload_loop": (
            link.get("status") == "same_run_4a61bc_append_reaches_4a79a3_payload"
            and invariants_pass(link_invariants)
            and (link.get("selected_4a61bc_object_record") or {}).get("record_pointer")
            == (link.get("linked_payload_record") or {}).get("record_pointer")
            and link.get("payload_record_count", 0) > 0
        ),
        "linked_payload_reaches_4a696b_and_7605": (
            dispatch.get("status") == "linked_payload_7605_endpoint_gates_replayed"
            and invariants_pass(dispatch_invariants)
            and dispatch_counts.get("0x004a696b", 0) > 0
            and dispatch_counts.get("0x004a7605", 0) > 0
            and dispatch_counts.get("0x004a7312", 0) > 0
        ),
        "controlled_4a696b_negative_frontier_recovered": (
            sweep.get("status") == "controlled_medium_4a696b_sweep_no_direct_mutation_hits"
            and invariants_pass(sweep_invariants)
            and sweep_metrics.get("sampled_4a696b_calls") == 30
            and sweep_metrics.get("source_relation_match_hits") == 0
            and sweep_metrics.get("direct_mutation_hits") == 0
            and sweep_metrics.get("fallback_4a7605_hits", 0) > 0
        ),
    }

    status = STATUS_RECOVERED if all(invariants.values()) else STATUS_INCOMPLETE
    return {
        "schema_id": "h3maped_4a61bc_chain_frontier_summary_v1",
        "status": status,
        "native_behavior_changed": False,
        "used_objdump": False,
        "overall_goal_complete": False,
        "artifacts": {
            name: {
                "path": str(path),
                "status": artifact_status(artifacts[name]),
            }
            for name, path in artifact_paths.items()
        },
        "metrics": {
            "internal_growth_positive_appends": growth.get("positive_append_count"),
            "internal_growth_append_delta": growth.get("positive_append_delta"),
            "commit_boundary_complete_sequences": complete_boundary_count,
            "dynamic_commit_stream_count": dynamic.get("stream_count"),
            "dynamic_commit_projection_write_counts": dynamic_write_values,
            "payload_link_selected_record": (link.get("selected_4a61bc_object_record") or {}).get(
                "record_pointer"
            ),
            "payload_link_payload_record_count": link.get("payload_record_count"),
            "payload_dispatch_4a696b_calls": dispatch_counts.get("0x004a696b", 0),
            "payload_dispatch_7605_calls": dispatch_counts.get("0x004a7605", 0),
            "payload_dispatch_direct_7312_commits": dispatch_counts.get("0x004a7312", 0),
            "controlled_4a696b_sampled_calls": sweep_metrics.get("sampled_4a696b_calls"),
            "controlled_4a696b_source_relation_match_hits": sweep_metrics.get(
                "source_relation_match_hits"
            ),
            "controlled_4a696b_direct_mutation_hits": sweep_metrics.get("direct_mutation_hits"),
        },
        "invariants": invariants,
        "source_backed_conclusion": (
            "The sampled 0x4a61bc append path is now consolidated as an ordered Wine/Ghidra/Python "
            "frontier: 0x4a79a3 reaches 0x4a61bc through 0x49b3fb, 0x4a61bc delegates object "
            "growth through 0x4a5e03, the append occurs inside the 0x4a54a7 commit callback, "
            "sampled 0x4a54a7 commits mutate generated-cell object references, +0x20, +0x28, "
            "and projection low words, a selected 0x4a61bc-origin object reappears in the same "
            "run's 0x4a79a3 payload loop, and the linked payload reaches 0x4a696b and 0x4a7605. "
            "The sampled 0x4a696b frontier remains negative: controlled Medium one-level land "
            "samples reach scan completion/no-candidate exit with zero source/relation-match "
            "and zero direct mutation hits."
        ),
        "remaining_gap": (
            "End-to-end recovery is still incomplete. The current named blockers are a natural "
            "linked-payload sample that reaches 0x4a696b source/relation match and direct mutation, "
            "or stronger proof that this direct mutation block is unreachable for supported one-level "
            "land; natural endpoint-stamping success through 0x4a7605 -> 0x4a746b -> 0x4a5e73 or "
            "source-backed exclusion of that path; and live cleanup/uncommit mutation state if a "
            "future projection/cleanup path becomes reachable."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(ARTIFACTS)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_4A61BC_CHAIN_FRONTIER "
        f"status={summary['status']} "
        f"out={args.out}"
    )
    return 0 if summary["status"] == STATUS_RECOVERED else 1


if __name__ == "__main__":
    raise SystemExit(main())
