#!/usr/bin/env python3
"""Verify native R4 descriptor/source identity diagnostics against recovered H3MapEd evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


CORE_INVARIANTS = (
    "no_native_behavior_change",
    "no_objdump_used",
    "same_run_selected_descriptor_pointer_join_recovered",
    "all_target_mixed_selected_descriptors_joined",
    "descriptor_input_type_subtype_class_fields_recovered",
    "descriptor_only_identity_not_claimed_for_ambiguous_mines",
    "descriptor_plus_0x00_registry_key_not_row_recovered",
    "object_table_loader_source_row_shape_recovered",
    "provider_mapping_covers_target_source_lanes_53_54_79",
    "source_catalog_template_producer_recovered",
    "source_record_cache_key_preserves_def_name_fields",
    "type45_base_loader_special_case_recovered",
)


CONTEXT_COMPARE_KEYS = (
    "return_address",
    "descriptor_type",
    "label",
    "selected_sample_count",
    "joined_sample_count",
    "all_selected_samples_joined",
    "unique_descriptor_identity_tuple_count",
    "unique_catalog_type_subtype_resolution_count",
    "ambiguous_catalog_type_subtype_resolution_count",
    "missing_catalog_type_subtype_resolution_count",
    "identity_authority",
)


ROW_MODE_KEYS = (
    "sample_count",
    "row_match_count",
    "row_mismatch_count",
    "row_missing_count",
)


def _load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def _as_bool(value: Any) -> bool:
    return bool(value)


def _context_key(context: dict[str, Any]) -> tuple[str, int]:
    return (str(context.get("return_address")), int(context.get("descriptor_type")))


def _extract_native(snapshot: dict[str, Any]) -> dict[str, Any]:
    summary = snapshot.get("plain_cpp_descriptor_source_identity_closure_summary")
    if not isinstance(summary, dict):
        raise ValueError("native snapshot missing plain_cpp_descriptor_source_identity_closure_summary")
    return summary


def _normalize_context(context: dict[str, Any]) -> dict[str, Any]:
    normalized = {key: context.get(key) for key in CONTEXT_COMPARE_KEYS}
    row_mode = context.get("row_mode")
    if not isinstance(row_mode, dict):
        row_mode = {}
    normalized["row_mode"] = {key: row_mode.get(key) for key in ROW_MODE_KEYS}
    return normalized


def _compare_contexts(native: dict[str, Any], h3maped: dict[str, Any]) -> list[dict[str, Any]]:
    native_contexts = native.get("target_contexts")
    source_contexts = h3maped.get("target_contexts")
    if not isinstance(native_contexts, list):
        raise ValueError("native descriptor summary missing target_contexts")
    if not isinstance(source_contexts, list):
        raise ValueError("H3MapEd descriptor summary missing target_contexts")

    native_by_key = {_context_key(item): _normalize_context(item) for item in native_contexts}
    source_by_key = {_context_key(item): _normalize_context(item) for item in source_contexts}
    mismatches: list[dict[str, Any]] = []
    for key in sorted(set(native_by_key) | set(source_by_key)):
        native_item = native_by_key.get(key)
        source_item = source_by_key.get(key)
        if native_item != source_item:
            mismatches.append(
                {
                    "key": {"return_address": key[0], "descriptor_type": key[1]},
                    "native": native_item,
                    "h3maped": source_item,
                }
            )
    return mismatches


def verify(snapshot_path: Path, h3maped_summary_path: Path) -> dict[str, Any]:
    snapshot = _load_json(snapshot_path)
    h3maped = _load_json(h3maped_summary_path)
    native = _extract_native(snapshot)
    prerequisite = snapshot.get("plain_cpp_object_vector_prerequisite_contract_summary")
    if not isinstance(prerequisite, dict):
        raise ValueError("native snapshot missing plain_cpp_object_vector_prerequisite_contract_summary")

    h3_metrics = h3maped.get("metrics") or {}
    native_invariants = native.get("invariants") or {}
    h3_invariants = h3maped.get("invariants") or {}
    context_mismatches = _compare_contexts(native, h3maped)

    invariant_mismatches = []
    for key in CORE_INVARIANTS:
        native_value = _as_bool(native_invariants.get(key))
        source_value = _as_bool(h3_invariants.get(key))
        if native_value != source_value or source_value is not True:
            invariant_mismatches.append(
                {"key": key, "native": native_invariants.get(key), "h3maped": h3_invariants.get(key)}
            )

    expected_counts = {
        "target_mixed_selected_descriptor_count": 87,
        "target_mixed_joined_descriptor_count": 87,
        "target_mixed_missing_join_count": 0,
        "provider_slot_pair_count": 27,
        "source_record_copy_size_bytes": 76,
    }
    count_mismatches = []
    for key, expected in expected_counts.items():
        native_value = native.get(key)
        source_value = h3_metrics.get(key, expected)
        if native_value != source_value or source_value != expected:
            count_mismatches.append(
                {"key": key, "native": native_value, "h3maped": source_value, "expected": expected}
            )

    hard_checks = {
        "h3maped_status_recovered": h3maped.get("status")
        == "r4_descriptor_source_identity_crosswalk_recovered",
        "native_status_diagnostic": native.get("status")
        == "diagnostic_r4_descriptor_source_identity_crosswalk_ported",
        "native_diagnostic_only": native.get("diagnostic_only") is True,
        "native_behavior_unchanged": native.get("native_behavior_changed") is False,
        "native_no_objdump": native.get("used_objdump") is False,
        "native_same_run_descriptor_state_still_incomplete": native.get("same_run_descriptor_state_complete")
        is False,
        "native_r4_crosswalk_ported": native.get("descriptor_source_identity_closure_ported_plain_cpp")
        is True
        and native.get("r4_descriptor_source_identity_crosswalk_recovered") is True,
        "native_requires_copied_source_record_identity": native.get(
            "copied_source_record_identity_authority_required"
        )
        is True,
        "prerequisite_r4_flags_exposed": prerequisite.get("descriptor_source_identity_closure_ported_plain_cpp")
        is True
        and prerequisite.get("descriptor_source_identity_r4_crosswalk_recovered") is True
        and prerequisite.get("descriptor_source_identity_native_behavior_changed") is False
        and prerequisite.get("descriptor_plus_0x00_registry_key_not_row_recovered") is True
        and prerequisite.get("descriptor_copied_source_record_identity_authority_recovered") is True,
        "prerequisite_same_run_descriptor_state_still_incomplete": prerequisite.get(
            "same_run_descriptor_state_complete"
        )
        is False,
    }
    failed_checks = [key for key, passed in hard_checks.items() if not passed]
    status = (
        "pass"
        if not failed_checks and not invariant_mismatches and not count_mismatches and not context_mismatches
        else "mismatch"
    )
    report = {
        "schema_id": "rmg_h3maped_r4_descriptor_source_identity_verify_v1",
        "status": status,
        "native_snapshot": str(snapshot_path),
        "h3maped_summary": str(h3maped_summary_path),
        "hard_checks": hard_checks,
        "failed_checks": failed_checks,
        "invariant_mismatches": invariant_mismatches,
        "count_mismatches": count_mismatches,
        "context_mismatch_count": len(context_mismatches),
        "context_mismatches": context_mismatches[:8],
        "native_same_run_descriptor_state_complete": native.get("same_run_descriptor_state_complete"),
        "native_behavior_changed": native.get("native_behavior_changed"),
        "native_target_mixed_selected_descriptor_count": native.get(
            "target_mixed_selected_descriptor_count"
        ),
        "native_target_mixed_joined_descriptor_count": native.get(
            "target_mixed_joined_descriptor_count"
        ),
        "native_target_mixed_missing_join_count": native.get(
            "target_mixed_missing_join_count"
        ),
    }
    return report


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
        "RMG_H3MAPED_R4_DESCRIPTOR_SOURCE_IDENTITY_VERIFY "
        f"status={report['status']} "
        f"selected={report['native_target_mixed_selected_descriptor_count']} "
        f"joined={report['native_target_mixed_joined_descriptor_count']} "
        f"missing={report['native_target_mixed_missing_join_count']} "
        f"context_mismatches={report['context_mismatch_count']} out={args.out}"
    )
    return 0 if report["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
