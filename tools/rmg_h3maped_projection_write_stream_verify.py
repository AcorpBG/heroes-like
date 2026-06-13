#!/usr/bin/env python3
"""Verify native 0x4a56b6 projection-write replay against a recovered Wine ledger."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


def _load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def _extract_ledger_rows(ledger: dict[str, Any]) -> list[dict[str, int]]:
    rows: list[dict[str, int]] = []
    events = ledger.get("events")
    if not isinstance(events, list):
        raise ValueError("ledger does not contain an events array")
    for event in events:
        if not isinstance(event, dict) or event.get("address") != "0x004a56b6":
            continue
        registers = event.get("registers")
        memory_lines = event.get("memory_lines")
        if not isinstance(registers, dict) or not isinstance(memory_lines, list):
            raise ValueError("0x4a56b6 event missing registers or memory_lines")
        cell_pointer = int(registers["eax"])
        memory_by_address = {
            int(line["address"]): line["words"]
            for line in memory_lines
            if isinstance(line, dict) and isinstance(line.get("words"), list)
        }
        words: list[int] = []
        for offset in (0, 16, 32):
            part = memory_by_address.get(cell_pointer + offset)
            if part is None:
                raise ValueError(f"0x4a56b6 event missing cell words at offset {offset}")
            words.extend(int(word) for word in part)
        if len(words) < 12:
            raise ValueError("0x4a56b6 event has incomplete generated-cell words")
        rows.append(
            {
                "ordinal": len(rows) + 4,
                "recovered_cell_pointer": cell_pointer,
                "x": words[4],
                "y": words[5],
                "level": words[6],
                "before_word_0x1c": words[7],
                "before_word_0x20": words[8],
                "before_word_0x24": words[9],
                "before_word_0x28": words[10],
                "before_word_0x2c": words[11],
                "expected_word_0x20": int(registers["esi"]),
            }
        )
    return rows


def _native_rows(snapshot: dict[str, Any]) -> list[dict[str, int]]:
    summary = snapshot.get("plain_cpp_object_vector_commit_mutation_summary")
    if not isinstance(summary, dict):
        raise ValueError("native snapshot missing plain_cpp_object_vector_commit_mutation_summary")
    rows = summary.get("projection_write_samples")
    if not isinstance(rows, list):
        raise ValueError("native summary missing projection_write_samples")
    keys = [
        "ordinal",
        "recovered_cell_pointer",
        "x",
        "y",
        "level",
        "before_word_0x1c",
        "before_word_0x20",
        "before_word_0x24",
        "before_word_0x28",
        "before_word_0x2c",
        "expected_word_0x20",
    ]
    normalized: list[dict[str, int]] = []
    for row in rows:
        if not isinstance(row, dict):
            raise ValueError("native projection_write_samples contains a non-object row")
        normalized.append({key: int(row[key]) for key in keys})
    return normalized


def verify(snapshot_path: Path, ledger_path: Path) -> dict[str, Any]:
    snapshot = _load_json(snapshot_path)
    ledger = _load_json(ledger_path)
    native_rows = _native_rows(snapshot)
    ledger_rows = _extract_ledger_rows(ledger)
    mismatch_samples = []
    for index, (native_row, ledger_row) in enumerate(zip(native_rows, ledger_rows)):
        if native_row != ledger_row:
            mismatch_samples.append({"index": index, "native": native_row, "ledger": ledger_row})
            if len(mismatch_samples) >= 8:
                break
    count_matches = len(native_rows) == len(ledger_rows)
    row_matches = count_matches and not mismatch_samples
    unique_native = len({row["recovered_cell_pointer"] for row in native_rows})
    unique_ledger = len({row["recovered_cell_pointer"] for row in ledger_rows})
    summary = snapshot["plain_cpp_object_vector_commit_mutation_summary"]
    report = {
        "schema_id": "rmg_h3maped_projection_write_stream_verify_v1",
        "status": "pass" if row_matches else "mismatch",
        "native_snapshot": str(snapshot_path),
        "h3maped_ledger": str(ledger_path),
        "native_write_count": len(native_rows),
        "h3maped_write_count": len(ledger_rows),
        "native_unique_cell_count": unique_native,
        "h3maped_unique_cell_count": unique_ledger,
        "count_matches": count_matches,
        "unique_cell_count_matches": unique_native == unique_ledger,
        "rows_match": row_matches,
        "native_full_stream_claim": bool(summary.get("projection_write_full_stream_materialized_plain_cpp")),
        "native_samples_match_claim": bool(summary.get("projection_write_recovered_samples_match")),
        "native_live_grid_mutation_adopted": bool(summary.get("live_grid_mutation_adopted")),
        "mismatch_samples": mismatch_samples,
    }
    return report


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--native-phase-snapshot", required=True, type=Path)
    parser.add_argument("--h3maped-ledger", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    report = verify(args.native_phase_snapshot, args.h3maped_ledger)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_PROJECTION_WRITE_STREAM_VERIFY "
        f"status={report['status']} native={report['native_write_count']} "
        f"h3maped={report['h3maped_write_count']} unique={report['native_unique_cell_count']}/"
        f"{report['h3maped_unique_cell_count']} out={args.out}"
    )
    return 0 if report["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
