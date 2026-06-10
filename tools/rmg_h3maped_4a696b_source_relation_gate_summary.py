#!/usr/bin/env python3
"""Summarize the current ``0x4a696b`` source/relation gate frontier.

This is a report-only recovery checkpoint.  It cross-checks the static gate
sequence in H3MapEd's ``0x4a696b`` body against the current controlled runtime
summaries.  It does not claim global unreachability and it does not change
native RMG behavior.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_STATIC_DUMP = Path(
    ".artifacts/rmg_recovery/ghidra_coord12_candidate_vector_helper_dump/"
    "caller_004a696b_FUN_004a696b.txt"
)
DEFAULT_CONTROLLED_SWEEP = Path(
    ".artifacts/rmg_recovery/medium_controlled_4a696b_sweep_summary_20260609.json"
)
DEFAULT_ARG_SURFACE = Path(
    ".artifacts/rmg_recovery/medium_seed10_4a696b_arg_surface_summary_20260609.json"
)
DEFAULT_GRID_SCAN = Path(
    ".artifacts/rmg_recovery/medium_seed10_4a696b_grid_scan2_summary_20260609.json"
)
DEFAULT_CANDIDATE_PREDICATE = Path(
    ".artifacts/rmg_recovery/4a696b_candidate_predicate_trace_summary_20260609.json"
)
DEFAULT_OUT = Path(".artifacts/rmg_recovery/4a696b_source_relation_gate_summary_20260609.json")


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def static_contract(static_text: str) -> dict[str, Any]:
    required_sites = {
        "same_level_coordinate_gate": "004a69b3: CMP EAX,dword ptr [EBP + -0x34]",
        "same_level_pass_target": "004a69c2: MOV AL,byte ptr [EBP + 0xb]",
        "source_scan_bounds_copy": "004a6a0b: LEA ESI,[EAX + 0x20]",
        "outer_scan_loop_bound": "004a6a27: CMP EAX,dword ptr [EBP + -0x5c]",
        "inner_scan_loop_bound": "004a6a33: CMP EDX,dword ptr [EBP + -0x60]",
        "generated_cell_word20_read": "004a6a58: MOV ECX,dword ptr [EAX + 0x20]",
        "generated_cell_byte2_compare": "004a6a63: CMP ESI,dword ptr [EBP + -0x18]",
        "byte2_mismatch_skip": "004a6a66: JNZ 0x004a6aff",
        "generated_cell_byte3_compare": "004a6a6f: CMP ECX,dword ptr [EBP + -0x1c]",
        "byte3_mismatch_skip": "004a6a72: JNZ 0x004a6aff",
        "cell_state_bit0_test": "004a6a7e: TEST CL,0x1",
        "source_relation_match_checkpoint": "004a6a81: JNZ 0x004a6cd1",
        "terrain_class_compare": "004a6a8d: CMP AL,0x8",
        "terrain_reject": "004a6a8f: JZ 0x004a6aff",
        "helper_49aa93_gate": "004a6ac3: CALL 0x0049aa93",
        "helper_49aa93_result_test": "004a6ac8: TEST AL,AL",
        "helper_4a6795_gate": "004a6ad9: CALL 0x004a6795",
        "helper_4a6795_result_test": "004a6ade: TEST AL,AL",
        "candidate_vector_append": "004a6ae9: CALL 0x004ae1fd",
        "scan_done": "004a6b10: XOR EDI,EDI",
        "no_candidate_exit_gate": "004a6b15: JZ 0x004a6b27",
        "selected_candidate_path": "004a6b2e: PUSH 0x1c",
        "selected_candidate_vtable_commit": "004a6b9b: CALL dword ptr [EDX + 0x4]",
        "direct_mutation_bit_test": "004a6c13: TEST byte ptr [ECX + 0x2c],0x1",
        "direct_mutation_clear_bit26": "004a6c1c: AND EAX,0xfbffffff",
        "direct_mutation_set_bit27": "004a6c21: OR EAX,0x8000000",
        "direct_mutation_write_word28": "004a6c26: MOV dword ptr [ECX + 0x28],EAX",
        "direct_mutation_append": "004a6c3b: CALL 0x0040bb15",
        "post_mutation_helper_4a68e0": "004a6c51: CALL 0x004a68e0",
        "border_guard_byte_gate": "004a6c78: CMP byte ptr [ESI + 0x9],0x0",
        "post_mutation_helper_4a5e73": "004a6c97: CALL 0x004a5e73",
        "fallback_materializer_4a5e03": "004a6ccc: CALL 0x004a5e03",
    }
    present = {name: needle in static_text for name, needle in required_sites.items()}
    return {
        "required_static_sites_present": present,
        "gate_order": [
            "same-level coordinate gate",
            "source scan rectangle from source record +0x20..+0x2c",
            "GeneratedCell+0x20 byte2 compare",
            "GeneratedCell+0x20 byte3 compare",
            "cell state bit0 and terrain gates",
            "0x49aa93 and 0x4a6795 helper gates",
            "12-byte local candidate append through 0x4ae1fd",
            "selected candidate vtable commit through slot +0x04",
            "direct mutation block writes GeneratedCell+0x28 by clearing bit26 and setting bit27",
        ],
    }


def controlled_metrics(controlled: dict[str, Any]) -> dict[str, Any]:
    metrics = controlled.get("metrics", {})
    counts = controlled.get("aggregate_address_counts", {})
    return {
        "sampled_4a696b_calls": metrics.get("sampled_4a696b_calls"),
        "source_relation_match_hits": metrics.get("source_relation_match_hits"),
        "candidate_append_hits": metrics.get("candidate_append_hits"),
        "candidate_path_hits": metrics.get("candidate_path_hits"),
        "direct_mutation_hits": metrics.get("direct_mutation_hits"),
        "fallback_4a7605_hits": metrics.get("fallback_4a7605_hits"),
        "direct_endpoint_4a7312_hits": metrics.get("direct_endpoint_4a7312_hits"),
        "scan_done_hits": counts.get("0x004a6b10", 0),
        "no_candidate_exit_hits": counts.get("0x004a6b27", 0),
        "classifications": controlled.get("aggregate_call_classifications", {}),
    }


def arg_metrics(arg_surface: dict[str, Any]) -> dict[str, Any]:
    metrics = arg_surface.get("metrics", {})
    return {
        "sampled_4a696b_calls": metrics.get("sampled_4a696b_calls"),
        "calls_with_arg_dumps": metrics.get("calls_with_arg_dumps"),
        "nonempty_scan_calls": metrics.get("nonempty_scan_calls"),
        "source_relation_match_hits": metrics.get("source_relation_match_hits"),
        "candidate_append_hits": metrics.get("candidate_append_hits"),
        "direct_mutation_hits": metrics.get("direct_mutation_hits"),
        "classifications": arg_surface.get("call_classifications", {}),
    }


def grid_metrics(grid_scan: dict[str, Any]) -> dict[str, Any]:
    calls = []
    for call in grid_scan.get("calls", []):
        grid = call.get("grid_scan", {})
        samples = grid.get("samples", {})
        calls.append(
            {
                "entry_event_index": call.get("entry_event_index"),
                "classification": call.get("classification"),
                "expected_generated_cell_0x20_bytes": grid.get("expected_generated_cell_0x20_bytes"),
                "counts": grid.get("counts", {}),
                "both_match_sample_count": len(samples.get("both_matches", [])),
            }
        )
    return {
        "metrics": grid_scan.get("metrics", {}),
        "calls": calls,
    }


def candidate_predicate_metrics(candidate_predicate: dict[str, Any]) -> dict[str, Any]:
    return {
        "status": candidate_predicate.get("status"),
        "event_count": candidate_predicate.get("event_count"),
        "address_counts": candidate_predicate.get("address_counts", {}),
        "predicate_counts": candidate_predicate.get("predicate_counts", {}),
        "call_classifications": candidate_predicate.get("call_classifications", {}),
    }


def summarize(
    static_dump: Path,
    controlled_sweep: Path,
    arg_surface: Path,
    grid_scan: Path,
    candidate_predicate: Path,
) -> dict[str, Any]:
    static = static_contract(static_dump.read_text(encoding="utf-8"))
    controlled = load_json(controlled_sweep)
    args = load_json(arg_surface)
    grid = load_json(grid_scan)
    predicate = load_json(candidate_predicate)

    controlled_invariants = controlled.get("invariants", {})
    arg_invariants = args.get("invariants", {})
    grid_invariants = grid.get("invariants", {})
    predicate_invariants = predicate.get("invariants", {})
    static_sites = static["required_static_sites_present"]

    invariants = {
        "no_native_behavior_change": True,
        "all_static_gate_and_mutation_sites_present": all(static_sites.values()),
        "controlled_sweep_has_sampled_calls": controlled.get("metrics", {}).get("sampled_4a696b_calls", 0) > 0,
        "controlled_sweep_zero_source_relation_hits": controlled_invariants.get("no_source_relation_match_hits") is True,
        "controlled_sweep_zero_candidate_append_hits": controlled_invariants.get("no_candidate_append_hits") is True,
        "controlled_sweep_zero_candidate_path_hits": controlled_invariants.get("no_candidate_path_hits") is True,
        "controlled_sweep_zero_direct_mutation_hits": controlled_invariants.get("no_direct_mutation_hits") is True,
        "controlled_sweep_observes_fallback_endpoint_surface": (
            controlled_invariants.get("fallback_endpoint_surface_observed") is True
        ),
        "arg_surface_calls_have_nonempty_scan_bounds": (
            arg_invariants.get("all_arg_dumped_calls_have_nonempty_scan_bounds") is True
        ),
        "arg_surface_calls_pass_same_level_gate": (
            arg_invariants.get("all_sampled_calls_pass_same_level_gate") is True
        ),
        "arg_surface_zero_source_relation_hits": (
            arg_invariants.get("no_sampled_call_reaches_source_relation_match_checkpoint") is True
        ),
        "grid_scan_has_complete_scans": grid_invariants.get("at_least_one_complete_grid_scan_captured") is True,
        "grid_scan_zero_owner_relation_pair_matches": (
            grid_invariants.get("all_complete_grid_scans_have_zero_owner_relation_pair_matches") is True
        ),
        "candidate_predicate_trace_stops_before_helpers_and_append": (
            predicate.get("status")
            == "partial_live_recovery_4a696b_prefilter_rejects_sampled_candidate_scans"
            and predicate_invariants.get("hit_sampled_4a696b_entries") is True
            and predicate_invariants.get("all_sampled_4a696b_entries_reached_scan_done") is True
            and predicate_invariants.get("all_sampled_4a696b_entries_took_no_candidate_exit") is True
            and predicate_invariants.get("no_source_relation_match_checkpoint_hits") is True
            and predicate_invariants.get("no_helper_predicate_hits") is True
            and predicate_invariants.get("no_candidate_appends") is True
            and predicate_invariants.get("no_direct_mutation_hits") is True
        ),
    }
    status = (
        "partial_recovery_4a696b_source_relation_gate_frontier"
        if all(invariants.values())
        else "partial_recovery_4a696b_source_relation_gate_frontier_incomplete"
    )
    return {
        "schema_id": "h3maped_4a696b_source_relation_gate_summary_v1",
        "status": status,
        "native_behavior_changed": False,
        "inputs": {
            "static_dump": str(static_dump),
            "controlled_sweep": str(controlled_sweep),
            "arg_surface": str(arg_surface),
            "grid_scan": str(grid_scan),
            "candidate_predicate": str(candidate_predicate),
        },
        "static_contract": static,
        "runtime_evidence": {
            "controlled_sweep": controlled_metrics(controlled),
            "arg_surface": arg_metrics(args),
            "grid_scan": grid_metrics(grid),
            "candidate_predicate": candidate_predicate_metrics(predicate),
        },
        "invariants": invariants,
        "source_backed_conclusion": (
            "For the current controlled target-mode corpus, every sampled 0x4a696b call exits before "
            "the source/relation-match checkpoint at 0x4a6a81. Static recovery places that checkpoint "
            "after the two GeneratedCell+0x20 byte-pair compares at 0x4a6a63 and 0x4a6a6f. The seed-10 "
            "argument/grid evidence proves the sampled scan rectangles are non-empty and complete grid "
            "scans contain zero cells matching both expected byte2/byte3 relation values. Therefore the "
            "sampled frontier is the source/relation byte-pair gate. The candidate-predicate trace "
            "separately proves the empty candidate vector is not caused by terrain checks, "
            "0x49aa93/0x4a6795 helper rejection, candidate append failure, vtable commit, or the "
            "direct GeneratedCell+0x28 mutation block."
        ),
        "remaining_gap": (
            "This is stronger sampled frontier evidence, not global unreachability proof. End-to-end "
            "recovery still needs either a natural 0x4a696b call that reaches 0x4a6a81 and then the "
            "candidate/direct-mutation path, or broader static/data proof that direct mutation is "
            "unreachable for the target one-level land mode. Live cleanup/uncommit behavior and the "
            "true owning projection-object slot +0x08 dispatch/lifetime also remain unrecovered."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--static-dump", type=Path, default=DEFAULT_STATIC_DUMP)
    parser.add_argument("--controlled-sweep", type=Path, default=DEFAULT_CONTROLLED_SWEEP)
    parser.add_argument("--arg-surface", type=Path, default=DEFAULT_ARG_SURFACE)
    parser.add_argument("--grid-scan", type=Path, default=DEFAULT_GRID_SCAN)
    parser.add_argument("--candidate-predicate", type=Path, default=DEFAULT_CANDIDATE_PREDICATE)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(
        args.static_dump,
        args.controlled_sweep,
        args.arg_surface,
        args.grid_scan,
        args.candidate_predicate,
    )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_4A696B_SOURCE_RELATION_GATE_SUMMARY status={summary['status']} out={args.out}")
    return 0 if summary["status"] == "partial_recovery_4a696b_source_relation_gate_frontier" else 1


if __name__ == "__main__":
    raise SystemExit(main())
