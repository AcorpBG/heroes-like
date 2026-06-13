#!/usr/bin/env python3
"""Verify native 0x49cf34 attach mutation replay against recovered H3MapEd rows."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


def _load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def _parse_int(value: Any) -> int:
    if isinstance(value, str):
        return int(value, 16) if value.startswith("0x") else int(value)
    return int(value)


def _source_rows(summary: dict[str, Any]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    pairs = summary.get("write_pairs_prefix")
    if not isinstance(pairs, list):
        raise ValueError("source summary missing write_pairs_prefix")
    for pair in pairs:
        if not isinstance(pair, dict):
            raise ValueError("source write_pairs_prefix contains a non-object row")
        before = pair.get("before")
        after = pair.get("after")
        if not isinstance(before, dict) or not isinstance(after, dict):
            raise ValueError("source write pair missing before/after")
        before_locals = before.get("locals")
        if not isinstance(before_locals, dict):
            raise ValueError("source write pair missing before.locals")
        rows.append(
            {
                "kind": str(pair["kind"]),
                "recovered_cell_pointer": _parse_int(before["cell"]),
                "probe_x": int(before_locals["probe_x"]),
                "probe_y": int(before_locals["probe_y"]),
                "relative_x": int(before_locals["relative_x"]),
                "relative_y": int(before_locals["relative_y"]),
                "direction_index": int(before_locals["direction_index"]),
                "descriptor_class_or_type": int(before_locals["descriptor_class_or_type"]),
                "before_word_0x28": _parse_int(before["cell_w28"]),
                "expected_word_0x28": _parse_int(after["cell_w28"]),
                "changed_mask": _parse_int(pair["changed_mask"]),
                "clears_bit26": bool(pair["clears_bit26"]),
                "sets_bit27_from_clear": bool(pair["sets_bit27"]),
            }
        )
    return rows


def _native_rows(snapshot: dict[str, Any]) -> list[dict[str, Any]]:
    summary = snapshot.get("plain_cpp_object_vector_commit_mutation_summary")
    if not isinstance(summary, dict):
        raise ValueError("native snapshot missing plain_cpp_object_vector_commit_mutation_summary")
    rows = summary.get("attach_mutation_samples")
    if not isinstance(rows, list):
        raise ValueError("native summary missing attach_mutation_samples")
    keys = [
        "kind",
        "recovered_cell_pointer",
        "probe_x",
        "probe_y",
        "relative_x",
        "relative_y",
        "direction_index",
        "descriptor_class_or_type",
        "before_word_0x28",
        "expected_word_0x28",
        "changed_mask",
        "clears_bit26",
        "sets_bit27_from_clear",
    ]
    normalized: list[dict[str, Any]] = []
    for row in rows:
        if not isinstance(row, dict):
            raise ValueError("native attach_mutation_samples contains a non-object row")
        normalized_row: dict[str, Any] = {}
        for key in keys:
            if key in {"kind"}:
                normalized_row[key] = str(row[key])
            elif key in {"clears_bit26", "sets_bit27_from_clear"}:
                normalized_row[key] = bool(row[key])
            else:
                normalized_row[key] = int(row[key])
        normalized.append(normalized_row)
    return normalized


def verify(snapshot_path: Path, source_summary_path: Path) -> dict[str, Any]:
    snapshot = _load_json(snapshot_path)
    source_summary = _load_json(source_summary_path)
    native_rows = _native_rows(snapshot)
    source_rows = _source_rows(source_summary)
    mismatch_samples = []
    for index, (native_row, source_row) in enumerate(zip(native_rows, source_rows)):
        if native_row != source_row:
            mismatch_samples.append({"index": index, "native": native_row, "source": source_row})
            if len(mismatch_samples) >= 8:
                break
    native_unique = len({row["recovered_cell_pointer"] for row in native_rows})
    source_unique = len({row["recovered_cell_pointer"] for row in source_rows})
    count_matches = len(native_rows) == len(source_rows)
    rows_match = count_matches and not mismatch_samples
    native_summary = snapshot["plain_cpp_object_vector_commit_mutation_summary"]
    source_metrics = source_summary.get("metrics", {})
    report = {
        "schema_id": "rmg_h3maped_49cf34_attach_mutation_verify_v1",
        "status": "pass" if rows_match else "mismatch",
        "native_snapshot": str(snapshot_path),
        "h3maped_summary": str(source_summary_path),
        "native_write_pair_count": len(native_rows),
        "h3maped_write_pair_count": len(source_rows),
        "native_unique_cell_count": native_unique,
        "h3maped_unique_cell_count": source_unique,
        "count_matches": count_matches,
        "unique_cell_count_matches": native_unique == source_unique,
        "rows_match": rows_match,
        "native_attach_match_claim": bool(native_summary.get("attach_mutation_recovered_samples_match")),
        "native_live_grid_mutation_adopted": bool(native_summary.get("live_grid_mutation_adopted")),
        "source_primary_write_pair_count": int(source_metrics.get("primary_write_pair_count", -1)),
        "source_neighbor_write_pair_count": int(source_metrics.get("neighbor_write_pair_count", -1)),
        "source_changed_write_pair_count": int(source_metrics.get("changed_write_pair_count", -1)),
        "source_clears_bit26_count": int(source_metrics.get("clears_bit26_count", -1)),
        "source_sets_bit27_from_clear_count": int(source_metrics.get("sets_bit27_from_clear_count", -1)),
        "mismatch_samples": mismatch_samples,
    }
    return report


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--native-phase-snapshot", required=True, type=Path)
    parser.add_argument("--h3maped-summary", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    report = verify(args.native_phase_snapshot, args.h3maped_summary)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_49CF34_ATTACH_MUTATION_VERIFY "
        f"status={report['status']} native={report['native_write_pair_count']} "
        f"h3maped={report['h3maped_write_pair_count']} unique={report['native_unique_cell_count']}/"
        f"{report['h3maped_unique_cell_count']} out={args.out}"
    )
    return 0 if report["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
