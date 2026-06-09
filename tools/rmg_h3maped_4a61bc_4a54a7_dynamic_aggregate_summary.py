#!/usr/bin/env python3
"""Aggregate recovered 0x4a61bc-origin 0x4a54a7 dynamic write streams."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_SUMMARIES = [
    Path(".artifacts/rmg_recovery/4a61bc_4a54a7_dynamic_summary_20260609.json"),
    Path(".artifacts/rmg_recovery/4a61bc_4a54a7_dynamic_summary_skip1_20260609.json"),
    Path(".artifacts/rmg_recovery/4a61bc_4a54a7_dynamic_summary_skip2_20260609.json"),
]
DEFAULT_OUT = Path(".artifacts/rmg_recovery/4a61bc_4a54a7_dynamic_aggregate_summary_20260609.json")


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def stream_summary(path: Path) -> dict[str, Any]:
    data = read_json(path)
    meta = data.get("dynamic_trace_meta", {})
    before = data.get("target_cell_states", {}).get("0x004a5e03", {})
    after = data.get("target_cell_states", {}).get("0x004a657d", {})
    vector_before = data.get("object_vector_states", {}).get("0x004a54a7", {})
    vector_after = data.get("object_vector_states", {}).get("0x004a5e6c", {})
    invariants = data.get("invariants", {})
    positive_invariants_true = all(
        bool(value)
        for name, value in invariants.items()
        if name != "native_behavior_changed"
    )
    native_unchanged = invariants.get("native_behavior_changed") is False
    return {
        "summary": str(path),
        "ledger": data.get("ledger"),
        "caller_boundary_index": meta.get("armed_caller_boundary_index", 0),
        "object_record": meta.get("object_record"),
        "target_cell": meta.get("target_cell"),
        "target_coordinate": meta.get("target_coordinate"),
        "projection_write_count": data.get("projection_write_count"),
        "unique_projection_write_cell_count": data.get("unique_projection_write_cell_count"),
        "object_vector_count_before_commit": vector_before.get("count"),
        "object_vector_count_after_commit": vector_after.get("count"),
        "target_cell_plus_0x20_before": (before.get("generated_cell_words") or {}).get("+0x20"),
        "target_cell_plus_0x20_after": (after.get("generated_cell_words") or {}).get("+0x20"),
        "target_cell_plus_0x28_before": (before.get("generated_cell_words") or {}).get("+0x28"),
        "target_cell_plus_0x28_after": (after.get("generated_cell_words") or {}).get("+0x28"),
        "target_cell_ref_count_before": (before.get("object_ref_vector") or {}).get("count"),
        "target_cell_ref_count_after": (after.get("object_ref_vector") or {}).get("count"),
        "target_cell_ref_entries_after": (after.get("object_ref_vector") or {}).get("entries"),
        "all_invariants_true": positive_invariants_true and native_unchanged,
        "invariants": invariants,
    }


def summarize(paths: list[Path]) -> dict[str, Any]:
    streams = [stream_summary(path) for path in paths]
    object_records = [stream.get("object_record") for stream in streams]
    target_cells = [stream.get("target_cell") for stream in streams]
    write_counts = [
        int(stream["projection_write_count"])
        for stream in streams
        if isinstance(stream.get("projection_write_count"), int)
    ]
    all_invariant_names = sorted({name for stream in streams for name in stream.get("invariants", {})})
    invariant_matrix = {
        name: [stream.get("invariants", {}).get(name) for stream in streams]
        for name in all_invariant_names
    }
    return {
        "schema": "h3maped_rmg_4a61bc_4a54a7_dynamic_aggregate_summary_v1",
        "stream_count": len(streams),
        "streams": streams,
        "distinct_object_record_count": len({item for item in object_records if item}),
        "distinct_target_cell_count": len({item for item in target_cells if item}),
        "projection_write_count_range": {
            "min": min(write_counts) if write_counts else None,
            "max": max(write_counts) if write_counts else None,
            "values": write_counts,
        },
        "all_streams_all_invariants_true": all(stream["all_invariants_true"] for stream in streams),
        "invariant_matrix": invariant_matrix,
        "recovered_contract": (
            "Across the sampled caller-frame indices 0, 1, and 2, each "
            "0x4a61bc-origin 0x4a54a7 commit appends exactly one object record "
            "to the generator object vector, adds that same object to the target "
            "generated-cell object-ref vector, clears the target cell +0x20 low "
            "word while preserving the high word, updates the target +0x28 "
            "occupied surface, and runs a unique-cell projection write stream "
            "whose 0x4a56b6 writes preserve +0x20 high words while lowering low "
            "words."
        ),
        "remaining_gap": (
            "The sampled first three 0x4a61bc-origin streams share the recovered "
            "0x4a54a7 write contract. End-to-end recovery still needs correlation "
            "from these appended records into the later 0x4a79a3 payload loop, "
            "downstream 0x4a696b/0x4a7605 consumers, natural endpoint success, "
            "and cleanup/uncommit paths."
        ),
        "native_behavior_changed": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--summary", type=Path, action="append", default=None)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    paths = args.summary if args.summary else DEFAULT_SUMMARIES
    summary = summarize(paths)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_4A61BC_4A54A7_DYNAMIC_AGGREGATE_SUMMARY "
        f"streams={summary['stream_count']} "
        f"objects={summary['distinct_object_record_count']} "
        f"targets={summary['distinct_target_cell_count']} "
        f"all_invariants={summary['all_streams_all_invariants_true']} "
        f"out={args.out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
