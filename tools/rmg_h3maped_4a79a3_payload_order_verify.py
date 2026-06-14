#!/usr/bin/env python3
"""Verify native 0x4a79a3 payload-order diagnostics against recovered H3MapEd rows."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


RECORD_KEYS = (
    "event_index",
    "record_pointer",
    "record_vtable",
    "descriptor_pointer",
    "descriptor_source_pointer",
    "coordinate_or_payload_words_08_10",
    "field_1c",
    "field_20",
    "field_24",
    "field_28",
    "field_2c",
    "record_words",
)


def _load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def _parse_int(value: Any) -> int:
    if isinstance(value, str):
        return int(value, 16) if value.startswith("0x") else int(value)
    return int(value)


def _native_summary(snapshot: dict[str, Any]) -> dict[str, Any]:
    summary = snapshot.get("plain_cpp_object_vector_payload_order_summary")
    if not isinstance(summary, dict):
        raise ValueError("native snapshot missing plain_cpp_object_vector_payload_order_summary")
    return summary


def _native_prerequisite(snapshot: dict[str, Any]) -> dict[str, Any]:
    summary = snapshot.get("plain_cpp_object_vector_prerequisite_contract_summary")
    if not isinstance(summary, dict):
        raise ValueError("native snapshot missing plain_cpp_object_vector_prerequisite_contract_summary")
    return summary


def _normalize_native_record(record: dict[str, Any]) -> dict[str, Any]:
    normalized = {key: record.get(key) for key in RECORD_KEYS}
    normalized["coordinate_or_payload_words_08_10"] = [
        int(value) for value in normalized["coordinate_or_payload_words_08_10"]
    ]
    normalized["field_1c"] = int(normalized["field_1c"])
    normalized["field_20"] = int(normalized["field_20"])
    normalized["field_24"] = int(normalized["field_24"])
    normalized["field_28"] = int(normalized["field_28"])
    normalized["field_2c"] = int(normalized["field_2c"])
    normalized["record_words"] = [int(value) for value in normalized["record_words"]]
    normalized["event_index"] = int(normalized["event_index"])
    return normalized


def _normalize_source_record(record: dict[str, Any]) -> dict[str, Any]:
    normalized = {key: record.get(key) for key in RECORD_KEYS}
    normalized["coordinate_or_payload_words_08_10"] = [
        int(value) for value in normalized["coordinate_or_payload_words_08_10"]
    ]
    normalized["field_1c"] = int(normalized["field_1c"])
    normalized["field_20"] = int(normalized["field_20"])
    normalized["field_24"] = int(normalized["field_24"])
    normalized["field_28"] = int(normalized["field_28"])
    normalized["field_2c"] = int(normalized["field_2c"])
    normalized["record_words"] = [_parse_int(value) for value in normalized["record_words"]]
    normalized["event_index"] = int(normalized["event_index"])
    return normalized


def _compare_records(native: list[dict[str, Any]], source: list[dict[str, Any]]) -> list[dict[str, Any]]:
    mismatches: list[dict[str, Any]] = []
    max_len = max(len(native), len(source))
    for index in range(max_len):
        native_row = native[index] if index < len(native) else None
        source_row = source[index] if index < len(source) else None
        if native_row != source_row:
            mismatches.append({"index": index, "native": native_row, "h3maped": source_row})
            if len(mismatches) >= 8:
                break
    return mismatches


def verify(snapshot_path: Path, h3maped_summary_path: Path) -> dict[str, Any]:
    snapshot = _load_json(snapshot_path)
    source = _load_json(h3maped_summary_path)
    native = _native_summary(snapshot)
    prerequisite = _native_prerequisite(snapshot)

    native_records_raw = native.get("records")
    source_records_raw = source.get("records")
    if not isinstance(native_records_raw, list):
        raise ValueError("native payload summary missing records")
    if not isinstance(source_records_raw, list):
        raise ValueError("H3MapEd payload summary missing records")
    native_records = [_normalize_native_record(record) for record in native_records_raw]
    source_records = [_normalize_source_record(record) for record in source_records_raw]
    record_mismatches = _compare_records(native_records, source_records)

    native_vector_entries = native.get("vector_entries")
    source_vector_entries = source.get("vector_entries")
    if not isinstance(native_vector_entries, list):
        raise ValueError("native payload summary missing vector_entries")
    if not isinstance(source_vector_entries, list):
        raise ValueError("H3MapEd payload summary missing vector_entries")

    native_vtables = native.get("record_vtable_counts") or {}
    source_vtables = source.get("record_vtable_counts") or {}
    hard_checks = {
        "source_status_partial_recovered": source.get("status")
        == "partial_live_recovery_4a79a3_object_record_payload",
        "native_status_diagnostic": native.get("status") == "diagnostic_4a79a3_payload_order_ported",
        "native_diagnostic_only": native.get("diagnostic_only") is True,
        "native_behavior_unchanged": native.get("native_behavior_changed") is False,
        "native_payload_order_ported": native.get("object_vector_4a79a3_payload_order_ported_plain_cpp")
        is True,
        "native_keeps_adoption_denied": native.get("native_object_vector_order_materialized") is False
        and native.get("generated_cell_mutation_replay_complete") is False
        and native.get("projection_write_coordinates_materialized") is False,
        "prerequisite_payload_order_flags_exposed": prerequisite.get(
            "object_vector_4a79a3_payload_order_ported_plain_cpp"
        )
        is True
        and prerequisite.get("object_vector_4a79a3_payload_order_records_match_recovered") is True
        and prerequisite.get("native_object_vector_order_materialized") is False
        and prerequisite.get("generated_cell_mutation_replay_complete") is False
        and prerequisite.get("projection_write_coordinates_materialized") is False,
        "native_record_count_matches": native.get("record_count") == source.get("record_count") == 19,
        "native_shifted_count_matches": native.get("shifted_count_at_0x4a7d99")
        == source.get("shifted_count_at_0x4a7d99")
        == 19,
        "native_vector_entries_match": native_vector_entries == source_vector_entries,
        "native_vtable_counts_match": native_vtables == source_vtables,
        "native_rows_match": not record_mismatches and len(native_records) == len(source_records),
    }
    failed_checks = [key for key, passed in hard_checks.items() if not passed]
    status = "pass" if not failed_checks else "mismatch"
    return {
        "schema_id": "rmg_h3maped_4a79a3_payload_order_verify_v1",
        "status": status,
        "native_snapshot": str(snapshot_path),
        "h3maped_summary": str(h3maped_summary_path),
        "hard_checks": hard_checks,
        "failed_checks": failed_checks,
        "native_record_count": len(native_records),
        "h3maped_record_count": len(source_records),
        "native_vector_entry_count": len(native_vector_entries),
        "h3maped_vector_entry_count": len(source_vector_entries),
        "native_record_vtable_counts": native_vtables,
        "h3maped_record_vtable_counts": source_vtables,
        "record_mismatch_count": len(record_mismatches),
        "record_mismatches": record_mismatches,
        "native_object_vector_order_materialized": native.get("native_object_vector_order_materialized"),
        "generated_cell_mutation_replay_complete": native.get("generated_cell_mutation_replay_complete"),
        "projection_write_coordinates_materialized": native.get("projection_write_coordinates_materialized"),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native-phase-snapshot", required=True, type=Path)
    parser.add_argument("--h3maped-summary", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    report = verify(args.native_phase_snapshot, args.h3maped_summary)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_4A79A3_PAYLOAD_ORDER_VERIFY "
        f"status={report['status']} native={report['native_record_count']} "
        f"h3maped={report['h3maped_record_count']} "
        f"record_mismatches={report['record_mismatch_count']} out={args.out}"
    )
    return 0 if report["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
