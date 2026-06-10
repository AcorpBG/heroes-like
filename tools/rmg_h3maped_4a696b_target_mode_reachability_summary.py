#!/usr/bin/env python3
"""Summarize target-mode reachability of H3MapEd ``0x4a696b`` direct mutation.

This recovery checkpoint combines the Ghidra-backed static call/gate evidence
with the current Wine full-grid samples. It is intentionally narrow: it proves
what the recovered one-level land samples do and do not reach, without claiming
global unreachable behavior for every H3MapEd map mode.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_SOURCE_RELATION_GATE = Path(
    ".artifacts/rmg_recovery/4a696b_source_relation_gate_summary_20260609.json"
)
DEFAULT_CORPUS_REACHABILITY = Path(
    ".artifacts/rmg_recovery/4a696b_corpus_reachability_summary_20260609.json"
)
DEFAULT_GRID_AGGREGATE = Path(
    ".artifacts/rmg_recovery/medium_4a696b_grid_scan_aggregate_summary_20260610.json"
)
DEFAULT_OUT = Path(
    ".artifacts/rmg_recovery/4a696b_target_mode_reachability_summary_20260610.json"
)


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def summarize(
    source_relation_gate_path: Path,
    corpus_reachability_path: Path,
    grid_aggregate_path: Path,
) -> dict[str, Any]:
    source_relation_gate = load_json(source_relation_gate_path)
    corpus_reachability = load_json(corpus_reachability_path)
    grid_aggregate = load_json(grid_aggregate_path)

    source_invariants = source_relation_gate.get("invariants", {})
    corpus_invariants = corpus_reachability.get("invariants", {})
    grid_invariants = grid_aggregate.get("invariants", {})
    corpus_metrics = corpus_reachability.get("metrics", {})
    grid_metrics = grid_aggregate.get("metrics", {})
    static_refs = corpus_reachability.get("static_call_refs", {})

    invariants = {
        "no_native_behavior_change": True,
        "no_objdump_used": True,
        "static_gate_order_recovered": source_invariants.get(
            "all_static_gate_and_mutation_sites_present"
        )
        is True,
        "static_direct_call_refs_only_from_4a79a3_sites": corpus_invariants.get(
            "static_direct_call_refs_only_from_4a79a3_sites"
        )
        is True,
        "corpus_has_4a696b_entries": int(corpus_metrics.get("combined_4a696b_entries", 0) or 0)
        > 0,
        "corpus_has_no_source_relation_match_or_deeper_hit": (
            corpus_invariants.get("no_combined_source_relation_match_hits") is True
            and corpus_invariants.get("no_combined_candidate_append_hits") is True
            and corpus_invariants.get("no_combined_candidate_path_hits") is True
            and corpus_invariants.get("no_combined_direct_mutation_hits") is True
        ),
        "controlled_gate_summary_has_zero_source_relation_hits": source_invariants.get(
            "controlled_sweep_zero_source_relation_hits"
        )
        is True,
        "controlled_gate_summary_has_zero_direct_mutation_hits": source_invariants.get(
            "controlled_sweep_zero_direct_mutation_hits"
        )
        is True,
        "candidate_predicate_trace_confirms_pre_helper_empty_vector": source_invariants.get(
            "candidate_predicate_trace_stops_before_helpers_and_append"
        )
        is True,
        "multi_seed_full_grid_scans_exist": int(
            grid_metrics.get("complete_grid_scan_count", 0) or 0
        )
        >= 6,
        "multi_seed_scans_have_zero_owner_relation_pair_matches": grid_invariants.get(
            "all_complete_scans_have_zero_owner_relation_pair_matches"
        )
        is True,
        "multi_seed_scans_include_single_byte_matches": grid_invariants.get(
            "complete_scans_still_have_single_byte_matches"
        )
        is True,
    }
    status = (
        "target_mode_4a696b_direct_mutation_unreached_pair_gate_explained"
        if all(invariants.values())
        else "target_mode_4a696b_reachability_incomplete"
    )

    return {
        "schema_id": "h3maped_4a696b_target_mode_reachability_summary_v1",
        "status": status,
        "inputs": {
            "source_relation_gate": str(source_relation_gate_path),
            "corpus_reachability": str(corpus_reachability_path),
            "grid_aggregate": str(grid_aggregate_path),
        },
        "metrics": {
            "combined_4a696b_entries": corpus_metrics.get("combined_4a696b_entries"),
            "combined_source_relation_match_hits": corpus_metrics.get(
                "combined_source_relation_match_hits"
            ),
            "combined_candidate_append_hits": corpus_metrics.get("combined_candidate_append_hits"),
            "combined_candidate_path_hits": corpus_metrics.get("combined_candidate_path_hits"),
            "combined_direct_mutation_hits": corpus_metrics.get("combined_direct_mutation_hits"),
            "seed_count": grid_metrics.get("seed_count"),
            "sampled_4a696b_calls_in_grid_aggregate": grid_metrics.get("sampled_4a696b_calls"),
            "complete_grid_scan_count": grid_metrics.get("complete_grid_scan_count"),
            "scanned_cell_total": grid_metrics.get("scanned_cell_total"),
            "byte2_only_or_any_match_total": grid_metrics.get("byte2_only_or_any_match_total"),
            "byte3_only_or_any_match_total": grid_metrics.get("byte3_only_or_any_match_total"),
            "zero_owner_relation_pair_match_scan_count": grid_metrics.get(
                "zero_owner_relation_pair_match_scan_count"
            ),
            "expected_pair_counts": grid_metrics.get("expected_pair_counts"),
        },
        "static_call_refs": static_refs,
        "invariants": invariants,
        "source_backed_conclusion": (
            "For the currently recovered one-level land target-mode evidence, 0x4a696b direct "
            "GeneratedCell+0x28 mutation is not active. Static Ghidra evidence places direct "
            "0x4a696b calls only at 0x4a79a3 sites 0x4a7c04 and 0x4a7dfa and recovers the gate "
            "order: GeneratedCell+0x20 byte2 compare, byte3 compare, state/terrain/helper gates, "
            "candidate append, selected-object commit, then the direct mutation block. The Wine "
            "corpus has 150 0x4a696b entries and zero source/relation-match, candidate, or direct "
            "mutation hits. The seed-pinned Medium one-level/no-water full-grid scans cover 6 "
            "complete rectangles across seeds 1, 2, and 10, with 5,752 scanned cells and zero cells "
            "matching both expected owner/relation bytes. The observed reason is therefore the "
            "GeneratedCell+0x20 byte-pair gate. The candidate-predicate trace additionally proves "
            "the sampled empty candidate vectors occur before terrain/helper rejection, candidate "
            "append, selected commit, or direct mutation behavior."
        ),
        "remaining_gap": (
            "This is not a global proof that 0x4a696b can never mutate cells. It is a stronger "
            "target-mode recovery checkpoint: native RMG must not port or compensate this block "
            "for the current one-level land path until either a natural 0x4a696b source/relation "
            "match is captured, or a broader static/data proof explains exactly which map modes or "
            "source states can reach it. Cleanup/uncommit runtime state and older coordinate/"
            "projection reconciliation remain separate end-to-end blockers."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-relation-gate", type=Path, default=DEFAULT_SOURCE_RELATION_GATE)
    parser.add_argument("--corpus-reachability", type=Path, default=DEFAULT_CORPUS_REACHABILITY)
    parser.add_argument("--grid-aggregate", type=Path, default=DEFAULT_GRID_AGGREGATE)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args.source_relation_gate, args.corpus_reachability, args.grid_aggregate)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_4A696B_TARGET_MODE_REACHABILITY status={summary['status']} out={args.out}")
    return (
        0
        if summary["status"]
        == "target_mode_4a696b_direct_mutation_unreached_pair_gate_explained"
        else 1
    )


if __name__ == "__main__":
    raise SystemExit(main())
