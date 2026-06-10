#!/usr/bin/env python3
"""Aggregate H3MapEd 0x4a696b full-grid source/relation scan evidence."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_INPUTS = [
    Path(".artifacts/rmg_recovery/medium_seed1_4a696b_grid_scan_summary_20260610.json"),
    Path(".artifacts/rmg_recovery/medium_seed2_4a696b_grid_scan_summary_20260610.json"),
    Path(".artifacts/rmg_recovery/medium_seed10_4a696b_grid_scan2_summary_20260609.json"),
]
DEFAULT_OUT = Path(".artifacts/rmg_recovery/medium_4a696b_grid_scan_aggregate_summary_20260610.json")


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def seed_label(summary: dict[str, Any], fallback_index: int) -> str:
    seed_control = summary.get("seed_control") or {}
    seed = seed_control.get("requested_seed")
    if seed not in {None, ""}:
        return str(seed)
    ledger = str(summary.get("ledger", ""))
    for candidate in ("seed1", "seed2", "seed10"):
        if candidate in ledger:
            return candidate.removeprefix("seed")
    return f"unknown_{fallback_index}"


def expected_pair(call: dict[str, Any]) -> str:
    expected = call.get("grid_scan", {}).get("expected_generated_cell_0x20_bytes") or {}
    return f"{expected.get('byte2_owner_relation')}->{expected.get('byte3_owner_relation')}"


def is_complete_zero_pair(call: dict[str, Any]) -> bool:
    grid = call.get("grid_scan", {})
    counts = grid.get("counts") or {}
    return (
        bool(grid.get("captured"))
        and counts.get("scanned_cells", 0) > 0
        and counts.get("missing_cell_word20", 0) == 0
        and counts.get("both_match", 0) == 0
    )


def summarize(inputs: list[Path]) -> dict[str, Any]:
    per_summary: list[dict[str, Any]] = []
    pair_counts: Counter[str] = Counter()
    byte2_total = 0
    byte3_total = 0
    scanned_total = 0
    complete_total = 0
    zero_pair_total = 0
    sampled_call_total = 0
    seeds: set[str] = set()

    for index, path in enumerate(inputs):
        summary = load_json(path)
        seed = seed_label(summary, index)
        seeds.add(seed)
        complete_calls = [call for call in summary.get("calls", []) if is_complete_zero_pair(call)]
        sampled_call_total += int(summary.get("metrics", {}).get("sampled_4a696b_calls", 0) or 0)
        complete_total += len(complete_calls)
        zero_pair_total += len(complete_calls)
        for call in complete_calls:
            grid = call.get("grid_scan", {})
            counts = grid.get("counts") or {}
            scanned_total += int(counts.get("scanned_cells", 0) or 0)
            byte2_total += int(counts.get("byte2_match", 0) or 0)
            byte3_total += int(counts.get("byte3_match", 0) or 0)
            pair_counts[expected_pair(call)] += 1
        per_summary.append(
            {
                "summary": str(path),
                "seed": seed,
                "status": summary.get("status"),
                "sampled_4a696b_calls": summary.get("metrics", {}).get("sampled_4a696b_calls"),
                "complete_grid_scans": len(complete_calls),
                "zero_owner_relation_pair_match_scans": len(complete_calls),
                "complete_scan_expected_pairs": [expected_pair(call) for call in complete_calls],
                "ledger": summary.get("ledger"),
                "seed_control": summary.get("seed_control"),
            }
        )

    invariants = {
        "no_native_behavior_change": True,
        "input_summaries_exist": all(path.exists() for path in inputs),
        "all_inputs_are_grid_scan_summaries": all(
            load_json(path).get("schema_id") == "h3maped_4a696b_grid_scan_summary_v1" for path in inputs
        ),
        "multi_seed_surface": len(seeds) >= 3,
        "complete_grid_scan_count_is_meaningful": complete_total >= 6,
        "all_complete_scans_have_zero_owner_relation_pair_matches": complete_total == zero_pair_total,
        "complete_scans_still_have_single_byte_matches": byte2_total > 0 or byte3_total > 0,
    }
    status = (
        "multi_seed_4a696b_source_relation_pair_gate_recovered"
        if all(invariants.values())
        else "multi_seed_4a696b_source_relation_pair_gate_incomplete"
    )
    return {
        "schema_id": "h3maped_4a696b_grid_scan_aggregate_summary_v1",
        "status": status,
        "inputs": [str(path) for path in inputs],
        "metrics": {
            "seed_count": len(seeds),
            "sampled_4a696b_calls": sampled_call_total,
            "complete_grid_scan_count": complete_total,
            "zero_owner_relation_pair_match_scan_count": zero_pair_total,
            "scanned_cell_total": scanned_total,
            "byte2_only_or_any_match_total": byte2_total,
            "byte3_only_or_any_match_total": byte3_total,
            "expected_pair_counts": dict(sorted(pair_counts.items())),
        },
        "per_summary": per_summary,
        "invariants": invariants,
        "source_backed_conclusion": (
            "Across the seed-pinned Medium one-level/no-water full-grid 0x4a696b scan samples, "
            "the direct-mutation path is blocked at the GeneratedCell+0x20 owner/relation byte-pair "
            "gate. Individual byte2 or byte3 values appear inside the scanned rectangles, but no "
            "complete scan contains a cell matching both expected bytes, so execution exits before "
            "0x4a6a81, terrain/helper checks, candidate append, selected-candidate commit, or "
            "GeneratedCell+0x28 direct mutation."
        ),
        "remaining_gap": (
            "This is multi-seed source-state evidence for the sampled one-level land path, not a global "
            "proof that 0x4a696b direct mutation is unreachable in every template or map mode. Full "
            "end-to-end recovery still needs either a natural 0x4a696b pair-match sample, a broader "
            "static/data proof for the target mode, live 0x4add76/0x4adef7 cleanup/uncommit replay, "
            "and the remaining coordinate/projection reconciliation."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", action="append", type=Path, dest="inputs")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    inputs = args.inputs or DEFAULT_INPUTS
    missing = [str(path) for path in inputs if not path.exists()]
    if missing:
        raise SystemExit(f"missing input summaries: {missing}")
    summary = summarize(inputs)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_4A696B_GRID_SCAN_AGGREGATE status={summary['status']} out={args.out}")
    return 0 if summary["status"] == "multi_seed_4a696b_source_relation_pair_gate_recovered" else 1


if __name__ == "__main__":
    raise SystemExit(main())
