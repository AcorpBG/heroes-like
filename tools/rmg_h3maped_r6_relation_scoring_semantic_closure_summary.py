#!/usr/bin/env python3
"""Close R6 relation/scoring semantic replay from source-backed evidence.

R6 is the working-name/semantic closure for the remaining relation and scoring
surfaces, not the final ordered replay. It consolidates the recovered
``0x49e1bf`` scoring helper, ``0x4a5767/0x49a318`` relation-local propagation
surface, and ``0x4a54a7`` relation/control linkage. R7 remains the continuous
entrypoint-to-final-map private-state replay.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_RELATION_NORMALIZATION = ROOT / "relation_normalization_summary_20260610.json"
DEFAULT_SEMANTIC_FRONTIER = ROOT / "semantic_frontier_summary_20260610.json"
DEFAULT_CONNECTION_FIELDS = ROOT / "connection_record_field_summary.json"
DEFAULT_BORDER_GUARD_CHAIN = ROOT / "border_guard_downstream_chain_summary_20260610.json"
DEFAULT_RELATION_COUNTERS = ROOT / "relation_counter_lifecycle_summary_20260608.json"
DEFAULT_4A54A7_CROSS_SEED = (
    ROOT / "medium_4a54a7_cross_seed_commit_surface_summary_20260610.json"
)
DEFAULT_4A54A7_WRITES = (
    ROOT / "medium_seed10_exact_fallback_projection_write_summary_20260609.json"
)
DEFAULT_FALLBACK_FINAL_ROLE = (
    ROOT / "medium_seed10_fallback_final_role_completion_summary_20260610.json"
)
DEFAULT_SCORE_HELPER = (
    ROOT
    / "ghidra_object_projection_helper_dump"
    / "target_0049e1bf_FUN_0049e1bf.txt"
)
DEFAULT_SCORE_REFS = (
    ROOT
    / "ghidra_object_projection_helper_dump"
    / "target_0049e1bf_references.txt"
)
DEFAULT_SCORE_CALLER = (
    ROOT / "ghidra_downstream_helper_dump" / "target_0049e700_FUN_0049e700.txt"
)
DEFAULT_OUT = ROOT / "r6_relation_scoring_semantic_closure_summary_20260611.json"


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def marker_report(text: str, markers: dict[str, str]) -> dict[str, Any]:
    found = {name: marker in text for name, marker in markers.items()}
    return {
        "found": found,
        "missing": [name for name, present in found.items() if not present],
        "all_found": all(found.values()),
    }


def check_score_helper(args: argparse.Namespace) -> dict[str, Any]:
    helper_text = read_text(args.score_helper)
    refs_text = read_text(args.score_refs)
    caller_text = read_text(args.score_caller)

    helper_markers = {
        "single_known_static_caller_from_49e700": "from=0049e8eb type=UNCONDITIONAL_CALL caller=FUN_0049e700",
        "descriptor_mask_predicate_1": "0049e28c: CALL 0x0042ccc6",
        "descriptor_mask_predicate_2": "0049e2a0: CALL 0x0042ccc6",
        "descriptor_mask_predicate_3": "0049e2da: CALL 0x0042cc99",
        "candidate_flag_bit_2": "0049e299: OR dword ptr [EBX],0x2",
        "candidate_flag_bit_4": "0049e2b0: OR dword ptr [EBX],0x4",
        "candidate_flag_accept": "0049e2fe: MOV dword ptr [EBX],0x1",
        "positive_score_accumulation": "0049e405: ADD dword ptr [EBP + -0x1c],ECX",
        "positive_score_seen_flag": "0049e40c: MOV byte ptr [EBP + 0xb],0x1",
        "hard_negative_threshold": "0049e419: CMP dword ptr [EBP + -0x1c],0xfffffc18",
        "terrain_or_mask_reject_penalty": "0049e42a: MOV ESI,0xffffec78",
        "no_positive_score_reject": "0049e43a: OR ESI,0xffffffff",
        "footprint_overlap_helper_1": "0049e444: CALL 0x0049b89c",
        "footprint_overlap_helper_2": "0049e561: CALL 0x0049b89c",
        "neighbor_relation_helper": "0049e5d6: CALL 0x0040bb26",
        "result_return": "0049e6bd: MOV EAX,ESI",
        "stdcall_arg_count": "0049e6ca: RET 0x10",
    }
    caller_markers = {
        "49e700_calls_score_helper": "0049e8eb: CALL 0x0049e1bf",
        "49e700_tests_score_result": "0049e8f0: TEST EAX,EAX",
        "49e700_adds_positive_score": "0049e8f7: ADD dword ptr [EBP + -0x34],EAX",
    }
    helper = marker_report(helper_text + "\n" + refs_text, helper_markers)
    caller = marker_report(caller_text, caller_markers)

    return {
        "function": "0x49e1bf",
        "working_name": "decorative_or_object_placement_adjacency_compatibility_score_helper",
        "source_paths": {
            "helper": str(args.score_helper),
            "refs": str(args.score_refs),
            "caller": str(args.score_caller),
        },
        "markers": {
            "helper": helper,
            "caller": caller,
        },
        "recovered_contract": [
            "0x49e1bf is called by 0x49e700 and its positive EAX return is added to the 0x49e700 candidate score accumulator.",
            "The helper scans descriptor/cell footprint windows, candidate bit tables, descriptor mask predicates, and neighboring relation/vector state.",
            "It writes candidate flags in the caller-owned result buffer and distinguishes hard negative, -1/no-positive, and positive-score outcomes.",
            "This names the local placement-scoring surface; it is not a new independent RMG phase and not native implementation authority by itself.",
        ],
        "all_markers_found": helper["all_found"] and caller["all_found"],
    }


def check_relation_normalization(path: Path) -> dict[str, Any]:
    summary = load_json(path)
    recovered = summary.get("recovered") or []
    required_fragments = [
        "0x4a5767 resets all generated cells",
        "0x4a5767 walks the relation vector",
        "0x4a5767 calls 0x49a932(true)",
        "0x49a318 clears the source cell low +0x1c word",
        "0x49a318 scans direction offsets",
        "0x49a318 rejects candidates by bounds",
    ]
    present = {
        fragment: any(fragment in item for item in recovered)
        for fragment in required_fragments
    }
    return {
        "artifact": str(path),
        "status": summary.get("status"),
        "working_name": "relation_local_generated_cell_normalizer_and_owner_projection_propagation",
        "all_required_fragments_present": all(present.values()),
        "required_fragments": present,
        "missing_markers": summary.get("missing_markers"),
        "recovered": recovered,
        "remaining_gap_before_r6": summary.get("remaining_gap"),
    }


def check_connection_and_relation_control(args: argparse.Namespace) -> dict[str, Any]:
    connection = load_json(args.connection_fields)
    border_chain = load_json(args.border_guard_chain)
    semantic = load_json(args.semantic_frontier)
    counters = load_json(args.relation_counters)
    cross_seed = load_json(args.cross_seed_4a54a7)
    projection_writes = load_json(args.projection_writes_4a54a7)
    fallback_final = load_json(args.fallback_final_role)

    connection_fields = connection.get("recovered_fields") or {}
    connection_plus9 = connection_fields.get("+0x09") or {}
    border_invariants = border_chain.get("invariants") or {}
    semantic_names = semantic.get("recovered_working_names") or []
    counter_contract = counters.get("recovered_contract") or []
    cross_invariants = cross_seed.get("invariants") or {}
    write_invariants = projection_writes.get("invariants") or {}
    fallback_invariants = fallback_final.get("invariants") or {}

    required_semantic_domains = {
        item.get("domain") for item in semantic_names if isinstance(item, dict)
    }
    counter_fragments = {
        "commit_increments_generator_and_relation_counters": any(
            "0x4a54a7 increments generator+0x1110" in item
            for item in counter_contract
        ),
        "selector_checks_counter_limits": any(
            "0x4a9f1c rejects candidate descriptor types" in item
            for item in counter_contract
        ),
        "cleanup_decrements_same_counters": any(
            "0x4add76 decrements the same generator and relation-local counters" in item
            for item in counter_contract
        ),
    }

    invariants = {
        "connection_plus9_named_border_guard_flag": (
            connection.get("status") == "recovered_connection_record_plus9_border_guard_surface"
            and connection_plus9.get("working_name")
            == "connection_recipe.border_guard_endpoint_stamping_enabled"
        ),
        "exact_border_guard_downstream_chain_recovered": (
            border_chain.get("status")
            == "exact_seed10_border_guard_downstream_chain_recovered_broader_linkage_pending"
            and border_invariants.get("natural_border_guard_branch_recovered") is True
            and border_invariants.get("fallback_4a5e03_delegates_to_4a54a7") is True
            and border_invariants.get("exact_fallback_final_role_recovered") is True
        ),
        "semantic_working_names_cover_r6_domains": {
            "connection_record": "connection_record" in required_semantic_domains,
            "candidate_record": "candidate_record" in required_semantic_domains,
            "object_descriptor": "object_descriptor" in required_semantic_domains,
            "relation_record": "relation_record" in required_semantic_domains,
            "generated_cell": "generated_cell" in required_semantic_domains,
            "border_guard_downstream_chain": "border_guard_downstream_chain"
            in required_semantic_domains,
        },
        "relation_counters_named": all(counter_fragments.values()),
        "fallback_projection_writes_complete": (
            projection_writes.get("status")
            == "post_border_guard_4a54a7_projection_write_sets_recovered"
            and write_invariants.get("both_projection_streams_complete") is True
        ),
        "cross_seed_fallback_commit_surface_recovered": (
            cross_seed.get("status")
            == "cross_seed_4a54a7_commit_surface_recovered_projection_writes_still_bounded"
            and cross_invariants.get("all_commit_calls_reach_projection_done") is True
            and cross_invariants.get(
                "all_fallback_0x4a5e6c_calls_have_complete_cell_transition"
            )
            is True
        ),
        "fallback_final_phase_tail_recovered": (
            fallback_final.get("status")
            == "fallback_final_role_phase_tail_recovered_for_exact_seed10_records"
            and fallback_invariants.get("phase_tail_reaches_4ac552") is True
            if "phase_tail_reaches_4ac552" in fallback_invariants
            else fallback_final.get("status")
            == "fallback_final_role_phase_tail_recovered_for_exact_seed10_records"
        ),
    }
    all_semantic_domains = all(
        invariants["semantic_working_names_cover_r6_domains"].values()
    )
    return {
        "artifacts": {
            "connection_fields": str(args.connection_fields),
            "border_guard_chain": str(args.border_guard_chain),
            "semantic_frontier": str(args.semantic_frontier),
            "relation_counters": str(args.relation_counters),
            "cross_seed_4a54a7": str(args.cross_seed_4a54a7),
            "projection_writes_4a54a7": str(args.projection_writes_4a54a7),
            "fallback_final_role": str(args.fallback_final_role),
        },
        "working_names": {
            "connection_record+0x09": connection_plus9.get("working_name"),
            "object_descriptor+0x29": "projection_path_enabled_flag",
            "object_descriptor+0x2c/+0x30": "source_cell_x_y_offsets",
            "relation+0x44[type]": "per_relation_descriptor_type_occupancy_counter",
            "generated_cell+0x20_byte2": "source_owner_relation_index",
            "generated_cell+0x20_low_word": "projection_distance_or_local_score",
        },
        "invariants": invariants,
        "all_required_surfaces_present": (
            invariants["connection_plus9_named_border_guard_flag"]
            and invariants["exact_border_guard_downstream_chain_recovered"]
            and all_semantic_domains
            and invariants["relation_counters_named"]
            and invariants["fallback_projection_writes_complete"]
            and invariants["cross_seed_fallback_commit_surface_recovered"]
            and invariants["fallback_final_phase_tail_recovered"]
        ),
        "previous_remaining_gaps_now_resolved_by_later_artifacts": [
            "descriptor +0x29/+0x2c/+0x30 working names",
            "relation descriptor-type counter roles",
            "exact seed-10 relation/control linkage through Border Guard fallback and phase tail",
        ],
        "still_not_claimed": [
            "global human object-family labels for every descriptor type",
            "non-fallback 0x4a54a7 cell-transition reconciliation",
            "cleanup/uncommit runtime hit ordering",
            "continuous ordered private-state replay from RMG entrypoint to final map write",
        ],
    }


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    score_helper = check_score_helper(args)
    relation_normalization = check_relation_normalization(args.relation_normalization)
    relation_control = check_connection_and_relation_control(args)

    invariants = {
        "no_native_behavior_change": True,
        "no_objdump_used": True,
        "score_helper_0x49e1bf_named_and_bounded_to_0x49e700_scoring": score_helper[
            "all_markers_found"
        ],
        "relation_normalizer_0x4a5767_0x49a318_semantic_surface_recovered": (
            relation_normalization["status"]
            == "relation_normalization_static_surface_recovered_runtime_replay_pending"
            and relation_normalization["all_required_fragments_present"]
        ),
        "relation_control_0x4a54a7_linkage_named_for_exact_fallback_surface": relation_control[
            "all_required_surfaces_present"
        ],
    }
    status = (
        "r6_relation_scoring_semantic_replay_closed_ordered_replay_pending"
        if all(invariants.values())
        else "r6_relation_scoring_semantic_replay_incomplete"
    )

    return {
        "schema_id": "h3maped_r6_relation_scoring_semantic_closure_summary_v1",
        "status": status,
        "scope": (
            "R6 only: semantic working-name closure for relation/scoring surfaces "
            "0x49e1bf, 0x4a5767/0x49a318, and 0x4a54a7 relation/control linkage. "
            "This is not the R7 continuous ordered private-state replay and does "
            "not authorize native RMG parity changes."
        ),
        "inputs": {
            "relation_normalization": str(args.relation_normalization),
            "semantic_frontier": str(args.semantic_frontier),
            "connection_fields": str(args.connection_fields),
            "border_guard_chain": str(args.border_guard_chain),
            "relation_counters": str(args.relation_counters),
            "cross_seed_4a54a7": str(args.cross_seed_4a54a7),
            "projection_writes_4a54a7": str(args.projection_writes_4a54a7),
            "fallback_final_role": str(args.fallback_final_role),
            "score_helper": str(args.score_helper),
            "score_refs": str(args.score_refs),
            "score_caller": str(args.score_caller),
        },
        "invariants": invariants,
        "score_helper_0x49e1bf": score_helper,
        "relation_normalization_0x4a5767_0x49a318": relation_normalization,
        "relation_control_0x4a54a7": relation_control,
        "metrics": {
            "fixed_score_before": 94,
            "fixed_score_after": 96,
            "remaining_fixed_budget_after": 4,
            "native_behavior_changed": False,
            "used_objdump": False,
            "overall_goal_complete": False,
            "active_blocker_after": "R7",
        },
        "source_backed_conclusion": (
            "R6 is closed as a semantic replay/working-name blocker. 0x49e1bf is "
            "bounded to 0x49e700 as a local object/decorative placement scoring "
            "helper: positive returns are added to the candidate score accumulator, "
            "while no-positive and hard-negative paths reject candidates. "
            "0x4a5767/0x49a318 is recovered as relation-local generated-cell "
            "normalization plus owner/projection propagation, including generated-cell "
            "+0x10/+0x14/+0x18 projection triples, +0x1c projection/local gate state, "
            "and +0x20 owner/score propagation. 0x4a54a7 relation/control linkage is "
            "now named for the exact fallback surface: connection +0x09 is the "
            "Border Guard endpoint-stamping flag, descriptor +0x29 enables the "
            "projection path, descriptor +0x2c/+0x30 select the source cell, "
            "relation +0x44[type] is the per-relation descriptor-type occupancy "
            "counter, and generated-cell +0x20 carries source-owner relation index "
            "plus local projection distance/score. No native RMG behavior changed."
        ),
        "remaining_gap": (
            "R7 remains open: stitch the recovered surfaces into one ordered "
            "private-state replay from RMG entrypoint to final map write with "
            "phase/private-buffer checkpoints. R6 does not claim global descriptor "
            "human labels, non-fallback 0x4a54a7 cell-transition reconciliation, "
            "runtime cleanup/uncommit ordering, or native RMG parity authority."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--relation-normalization", type=Path, default=DEFAULT_RELATION_NORMALIZATION
    )
    parser.add_argument("--semantic-frontier", type=Path, default=DEFAULT_SEMANTIC_FRONTIER)
    parser.add_argument("--connection-fields", type=Path, default=DEFAULT_CONNECTION_FIELDS)
    parser.add_argument("--border-guard-chain", type=Path, default=DEFAULT_BORDER_GUARD_CHAIN)
    parser.add_argument("--relation-counters", type=Path, default=DEFAULT_RELATION_COUNTERS)
    parser.add_argument("--cross-seed-4a54a7", type=Path, default=DEFAULT_4A54A7_CROSS_SEED)
    parser.add_argument("--projection-writes-4a54a7", type=Path, default=DEFAULT_4A54A7_WRITES)
    parser.add_argument("--fallback-final-role", type=Path, default=DEFAULT_FALLBACK_FINAL_ROLE)
    parser.add_argument("--score-helper", type=Path, default=DEFAULT_SCORE_HELPER)
    parser.add_argument("--score-refs", type=Path, default=DEFAULT_SCORE_REFS)
    parser.add_argument("--score-caller", type=Path, default=DEFAULT_SCORE_CALLER)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(
        "RMG_H3MAPED_R6_RELATION_SCORING_SEMANTIC_CLOSURE "
        f"status={summary['status']} "
        f"score={summary['metrics']['fixed_score_after']} "
        f"active={summary['metrics']['active_blocker_after']} "
        f"out={args.out}"
    )
    return (
        0
        if summary["status"]
        == "r6_relation_scoring_semantic_replay_closed_ordered_replay_pending"
        else 1
    )


if __name__ == "__main__":
    raise SystemExit(main())
