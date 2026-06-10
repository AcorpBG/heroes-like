#!/usr/bin/env python3
"""Summarize the exact fallback-record phase-tail completion boundary.

This joins existing Wine/Ghidra-derived summaries for the deterministic Medium
seed-10 post-Border-Guard fallback records. It intentionally does not claim a
global final-role proof for every object family or map mode. It only verifies
that the exact sampled fallback records have recovered construction/adoption,
survive through the later ``0x49eb8d`` handoff, and the immediately following
``0x49e700`` / ``0x4ac552`` phase tail is source-backed.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_FINAL_ROLE_FRONTIER = Path(
    ".artifacts/rmg_recovery/medium_seed10_fallback_final_role_frontier_summary_20260609.json"
)
DEFAULT_49E700_MUTATION = Path(
    ".artifacts/rmg_recovery/medium_seed10_49e700_mutation_summary_20260609.json"
)
DEFAULT_4AC552_COMPLETION = Path(
    ".artifacts/rmg_recovery/medium_seed10_4ac552_phase_completion_summary_20260609.json"
)
DEFAULT_OUT = Path(
    ".artifacts/rmg_recovery/medium_seed10_fallback_final_role_completion_summary_20260610.json"
)


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def invariant(summary: dict[str, Any], key: str) -> bool:
    return summary.get("invariants", {}).get(key) is True


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    frontier = read_json(args.final_role_frontier)
    mutation_49e700 = read_json(args.mutation_49e700)
    completion_4ac552 = read_json(args.completion_4ac552)

    frontier_invariants = frontier.get("invariants", {})
    mutation_invariants = mutation_49e700.get("invariants", {})
    completion_invariants = completion_4ac552.get("invariants", {})

    invariants = {
        "no_native_behavior_change": (
            frontier_invariants.get("native_behavior_changed") is False
            and mutation_invariants.get("native_behavior_changed") is False
            and completion_invariants.get("native_behavior_changed") is False
        ),
        "no_objdump_used": True,
        "exact_fallback_records_identified": invariant(frontier, "two_fallback_records_identified"),
        "exact_fallback_construction_adoption_recovered": (
            invariant(frontier, "exact_state_chain_recovered_for_all_fallback_records")
            and invariant(frontier, "exact_afterstate_recovered_for_all_fallback_records")
            and invariant(frontier, "cell_object_ref_vector_contains_all_fallback_records")
            and invariant(frontier, "exact_descriptor_relation_recovered_for_all_fallback_records")
            and invariant(frontier, "exact_projection_write_stream_recovered_for_all_fallback_records")
        ),
        "fallback_records_not_in_sampled_prior_payload": (
            invariant(frontier, "fallback_records_constructed_after_payload")
            and invariant(frontier, "fallback_records_absent_from_sampled_payload")
        ),
        "fallback_records_survive_to_phase_tail": (
            invariant(frontier, "fallback_records_survive_to_4a8d27_object_vector")
            and invariant(frontier, "fallback_records_survive_to_49eb8d_object_vector")
            and invariant(frontier, "fallback_records_survive_49eb8d_return_to_4ac844")
        ),
        "same_run_49eb8d_boundary_recovered": invariant(
            frontier, "same_run_49eb8d_count_dispatch_return_recovered"
        ),
        "first_49e700_mutation_write_set_recovered": (
            mutation_49e700.get("status") == "49e700_mutation_bit26_write_set_recovered"
            and invariant(mutation_49e700, "write_triplets_complete")
            and invariant(mutation_49e700, "all_writes_clear_bit26_only")
            and invariant(mutation_49e700, "post_commit_appends_match_writes")
            and invariant(mutation_49e700, "return_boundary_reached")
        ),
        "post_49eb8d_4ac552_phase_tail_recovered": (
            completion_4ac552.get("status") == "4ac552_post_49eb8d_phase_completion_recovered"
            and invariant(completion_4ac552, "expected_event_sequence")
            and invariant(completion_4ac552, "same_generator_through_tail_calls")
            and invariant(completion_4ac552, "al_set_to_success_before_return")
            and invariant(completion_4ac552, "caller_continuation_observed_with_success_al")
        ),
    }
    status = (
        "fallback_final_role_phase_tail_recovered_for_exact_seed10_records"
        if all(invariants.values())
        else "fallback_final_role_phase_tail_incomplete"
    )

    return {
        "schema_id": "h3maped_fallback_final_role_completion_summary_v1",
        "status": status,
        "inputs": {
            "final_role_frontier": str(args.final_role_frontier),
            "mutation_49e700": str(args.mutation_49e700),
            "completion_4ac552": str(args.completion_4ac552),
        },
        "metrics": {
            "fallback_record_count": len(frontier.get("records", [])),
            "first_49e700_commit_callbacks": mutation_49e700.get("metrics", {}).get("commit_callback_count"),
            "first_49e700_bit26_write_count": mutation_49e700.get("metrics", {}).get("bit26_write_count"),
            "phase_tail_event_count": completion_4ac552.get("metrics", {}).get("event_count"),
            "phase_tail_generator": completion_4ac552.get("metrics", {}).get("generator"),
        },
        "invariants": invariants,
        "source_backed_conclusion": (
            "For the exact deterministic Medium seed-10 post-Border-Guard fallback records, "
            "the currently recovered Wine/Ghidra/Python evidence now covers construction, "
            "target-cell adoption, descriptor/relation counters, exact projection writes, "
            "object-vector survival through 0x49eb8d return to 0x4ac844, the first normal "
            "0x49e700 bit26 mutation write set, and the 0x4ac552 tail returning success "
            "through 0x4ae082 on the same generator."
        ),
        "remaining_gap": (
            "This closes the previously stale downstream phase-completion gap for these exact "
            "fallback records only. It does not recover global final-role semantic names, a "
            "positive 0x4a696b source/relation-match or broader reachability proof, live "
            "0x4add76/0x4adef7 cleanup/uncommit runtime state, or broader map-mode/source-state "
            "proof. Do not port native RMG behavior from this checkpoint alone."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--final-role-frontier", type=Path, default=DEFAULT_FINAL_ROLE_FRONTIER)
    parser.add_argument("--mutation-49e700", type=Path, default=DEFAULT_49E700_MUTATION)
    parser.add_argument("--completion-4ac552", type=Path, default=DEFAULT_4AC552_COMPLETION)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_FALLBACK_FINAL_ROLE_COMPLETION status={summary['status']} out={args.out}")
    return 0 if summary["status"] == "fallback_final_role_phase_tail_recovered_for_exact_seed10_records" else 1


if __name__ == "__main__":
    raise SystemExit(main())
