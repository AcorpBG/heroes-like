#!/usr/bin/env python3
"""Consolidate the recovered post-fallback 0x49eb8d/0x49e700/0x4ac552 phase tail.

This checkpoint verifies an exact Medium seed-10 chain that is already present
in existing Wine/Ghidra/Python summaries:

* 0x49eb8d count/budget/first-normal-dispatch/return boundary
* first 0x49e700 selection/commit/return boundary
* first 0x49e700 bit26 generated-cell write set
* immediate 0x4ac552 phase-tail success return

It is recovery evidence only. It does not change native RMG behavior and does
not use objdump.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_49EB8D = ROOT / "medium_seed10_fallback_49eb8d_replay_summary_20260609.json"
DEFAULT_49E700_FIRST = ROOT / "medium_seed10_49e700_first_dispatch_summary_20260609.json"
DEFAULT_49E700_MUTATION = ROOT / "medium_seed10_49e700_mutation_summary_20260609.json"
DEFAULT_4AC552 = ROOT / "medium_seed10_4ac552_phase_completion_summary_20260609.json"
DEFAULT_FINAL_ROLE = ROOT / "medium_seed10_fallback_final_role_completion_summary_20260610.json"
DEFAULT_OUT = ROOT / "post_fallback_phase_tail_summary_20260610.json"


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    replay_49eb8d = load_json(args.replay_49eb8d)
    first_49e700 = load_json(args.first_49e700)
    mutation_49e700 = load_json(args.mutation_49e700)
    phase_4ac552 = load_json(args.phase_4ac552)
    final_role = load_json(args.final_role)

    replay_inv = replay_49eb8d.get("invariants", {})
    first_inv = first_49e700.get("invariants", {})
    mutation_inv = mutation_49e700.get("invariants", {})
    phase_inv = phase_4ac552.get("invariants", {})
    final_inv = final_role.get("invariants", {})

    mutation_metrics = mutation_49e700.get("metrics", {})
    phase_metrics = phase_4ac552.get("metrics", {})
    final_metrics = final_role.get("metrics", {})

    invariants = {
        "no_native_behavior_change": replay_49eb8d.get("native_behavior_changed") is False
        and first_49e700.get("native_behavior_changed") is False
        and mutation_49e700.get("native_behavior_changed") is False
        and phase_4ac552.get("native_behavior_changed") is False
        and final_role.get("invariants", {}).get("no_native_behavior_change") is True,
        "no_objdump_used": final_role.get("invariants", {}).get("no_objdump_used") is True,
        "same_run_49eb8d_boundary_recovered": replay_49eb8d.get("status")
        == "fallback_49eb8d_same_run_count_dispatch_return_recovered"
        and replay_inv.get("same_run_49eb8d_boundary_recovered", True) is True
        and replay_inv.get("entry_returns_to_0x4ac844") is True
        and replay_inv.get("first_dispatch_returns_to_0x49ec6b") is True
        and replay_inv.get("fallback_records_present_at_entry") is True
        and replay_inv.get("fallback_records_present_at_exit") is True,
        "49eb8d_budget_formula_recovered": replay_inv.get("budget_matches_formula") is True
        and replay_49eb8d.get("bit26_count") == 2284
        and replay_49eb8d.get("computed_budget") == 120,
        "first_49e700_selection_boundary_recovered": first_49e700.get("status")
        == "49e700_first_dispatch_selection_commit_return_boundary_recovered"
        and first_inv.get("candidate_trace_reaches_scorer") is True
        and first_inv.get("candidate_trace_reaches_accepted_candidate_appends") is True
        and first_inv.get("selection_trace_reaches_rng_allocation_commit") is True
        and first_inv.get("selection_trace_reaches_post_commit_coordinate_appends") is True
        and first_inv.get("return_trace_reaches_cleanup_return_boundary") is True,
        "first_49e700_mutation_write_set_recovered": mutation_49e700.get("status")
        == "49e700_mutation_bit26_write_set_recovered"
        and mutation_inv.get("write_triplets_complete") is True
        and mutation_inv.get("all_coordinates_match_generated_cell_formula") is True
        and mutation_inv.get("all_writes_clear_bit26_only") is True
        and mutation_inv.get("post_commit_appends_match_writes") is True
        and mutation_metrics.get("bit26_write_count") == 67
        and mutation_metrics.get("commit_callback_count") == 42,
        "4ac552_phase_tail_success_recovered": phase_4ac552.get("status")
        == "4ac552_post_49eb8d_phase_completion_recovered"
        and phase_inv.get("expected_event_sequence") is True
        and phase_inv.get("same_generator_through_tail_calls") is True
        and phase_inv.get("al_set_to_success_before_return") is True
        and phase_inv.get("caller_continuation_observed_with_success_al") is True
        and phase_inv.get("entry_returns_to_caller_0x4ae082") is True,
        "final_role_completion_agrees": final_role.get("status")
        == "fallback_final_role_phase_tail_recovered_for_exact_seed10_records"
        and final_inv.get("same_run_49eb8d_boundary_recovered") is True
        and final_inv.get("first_49e700_mutation_write_set_recovered") is True
        and final_inv.get("post_49eb8d_4ac552_phase_tail_recovered") is True,
    }

    status = (
        "post_fallback_49eb8d_49e700_4ac552_phase_tail_recovered"
        if all(invariants.values())
        else "post_fallback_phase_tail_incomplete"
    )

    return {
        "schema_id": "h3maped_post_fallback_phase_tail_summary_v1",
        "status": status,
        "scope": (
            "Exact deterministic Medium seed-10 post-Border-Guard fallback path only. "
            "This consolidates already recovered same-run Wine/Ghidra/Python evidence from "
            "0x49eb8d through the first normal 0x49e700 dispatch and the immediate 0x4ac552 "
            "success return."
        ),
        "inputs": {
            "49eb8d_replay": str(args.replay_49eb8d),
            "49e700_first_dispatch": str(args.first_49e700),
            "49e700_mutation": str(args.mutation_49e700),
            "4ac552_phase_completion": str(args.phase_4ac552),
            "fallback_final_role_completion": str(args.final_role),
        },
        "invariants": invariants,
        "metrics": {
            "bit26_count_at_49eb8d": replay_49eb8d.get("bit26_count"),
            "computed_budget_at_49eb8d": replay_49eb8d.get("computed_budget"),
            "first_49e700_commit_callback_count": mutation_metrics.get("commit_callback_count"),
            "first_49e700_bit26_write_count": mutation_metrics.get("bit26_write_count"),
            "first_49e700_unique_write_cells": mutation_metrics.get("unique_write_cells"),
            "phase_tail_event_count": phase_metrics.get("event_count"),
            "phase_tail_generator": phase_metrics.get("generator"),
            "final_role_fallback_record_count": final_metrics.get("fallback_record_count"),
            "native_behavior_changed": False,
            "overall_goal_complete": False,
            "used_objdump": False,
        },
        "recovered_chain": [
            {
                "stage": "0x49eb8d",
                "state": (
                    "Counts 2284 bit26 generated cells, computes budget 120, calls the first "
                    "normal 0x49e700 dispatch, and returns to 0x4ac844 while exact fallback "
                    "records remain in the generator object vector."
                ),
            },
            {
                "stage": "first 0x49e700",
                "state": (
                    "Scorer, accepted candidate appends, RNG selection, allocation/commit "
                    "callback, post-commit coordinate appends, and cleanup return boundary are "
                    "recovered for the first normal dispatch."
                ),
            },
            {
                "stage": "first 0x49e700 generated-cell writes",
                "state": (
                    "42 commit callbacks produce 67 unique post-commit decorative cell writes; "
                    "each write clears only GeneratedCell+0x28 bit26, matches the generated-cell "
                    "address formula, and is mirrored in the post-commit coordinate vector."
                ),
            },
            {
                "stage": "0x4ac552 tail",
                "state": (
                    "After 0x49eb8d returns to 0x4ac844, 0x4ac552 calls 0x4ab52a and 0x4ac4ae "
                    "on the same generator, sets AL=1, and returns to caller 0x4ae082 with AL=1."
                ),
            },
        ],
        "source_backed_conclusion": (
            "The exact seed-10 post-fallback phase tail is recovered from 0x49eb8d through "
            "the first normal 0x49e700 dispatch and the immediate 0x4ac552 success return. "
            "This closes the sampled downstream phase-tail gap for the exact fallback records "
            "but remains scoped to that deterministic path."
        ),
        "remaining_gap": (
            "This does not recover global final-role semantic names, broader map-mode/source-state "
            "phase tails, positive 0x4a696b source/relation-match behavior, live "
            "0x4add76/0x4adef7 cleanup/uncommit state, or full native RMG parity. Do not port "
            "native behavior from this checkpoint alone."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--replay-49eb8d", type=Path, default=DEFAULT_49EB8D)
    parser.add_argument("--first-49e700", type=Path, default=DEFAULT_49E700_FIRST)
    parser.add_argument("--mutation-49e700", type=Path, default=DEFAULT_49E700_MUTATION)
    parser.add_argument("--phase-4ac552", type=Path, default=DEFAULT_4AC552)
    parser.add_argument("--final-role", type=Path, default=DEFAULT_FINAL_ROLE)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_POST_FALLBACK_PHASE_TAIL "
        f"status={summary['status']} "
        f"first_49e700_writes={summary['metrics']['first_49e700_bit26_write_count']} "
        f"phase_tail_events={summary['metrics']['phase_tail_event_count']} "
        f"out={args.out}"
    )
    return (
        0
        if summary["status"] == "post_fallback_49eb8d_49e700_4ac552_phase_tail_recovered"
        else 1
    )


if __name__ == "__main__":
    raise SystemExit(main())
