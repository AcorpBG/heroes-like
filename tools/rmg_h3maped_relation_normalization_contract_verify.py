#!/usr/bin/env python3
"""Verify native relation-normalization diagnostics against recovered H3MapEd evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


def _load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def _native_relation_summary(snapshot: dict[str, Any]) -> dict[str, Any]:
    summary = snapshot.get("plain_cpp_relation_normalization_contract_summary")
    if not isinstance(summary, dict):
        raise ValueError("native snapshot missing plain_cpp_relation_normalization_contract_summary")
    return summary


def _native_prerequisite(snapshot: dict[str, Any]) -> dict[str, Any]:
    summary = snapshot.get("plain_cpp_object_vector_prerequisite_contract_summary")
    if not isinstance(summary, dict):
        raise ValueError("native snapshot missing plain_cpp_object_vector_prerequisite_contract_summary")
    return summary


def _metrics(value: dict[str, Any]) -> dict[str, Any]:
    metrics = value.get("metrics")
    if not isinstance(metrics, dict):
        raise ValueError(f"{value.get('schema_id', '<unknown>')} missing metrics")
    return metrics


def _file_marker_counts(relation_summary: dict[str, Any], key: str) -> tuple[int, int]:
    files = relation_summary.get("files")
    if not isinstance(files, dict):
        raise ValueError("relation normalization summary missing files")
    record = files.get(key)
    if not isinstance(record, dict):
        raise ValueError(f"relation normalization summary missing files.{key}")
    return int(record.get("check_count", -1)), int(record.get("present_check_count", -1))


def verify(
    snapshot_path: Path,
    relation_normalization_path: Path,
    r6_summary_path: Path,
    private_state_compare_path: Path,
    selected_candidate_relation_path: Path | None = None,
) -> dict[str, Any]:
    snapshot = _load_json(snapshot_path)
    relation_source = _load_json(relation_normalization_path)
    r6_source = _load_json(r6_summary_path)
    private_compare = _load_json(private_state_compare_path)
    selected_candidate_relation = (
        _load_json(selected_candidate_relation_path) if selected_candidate_relation_path else None
    )

    native = _native_relation_summary(snapshot)
    prerequisite = _native_prerequisite(snapshot)
    relation_metrics = _metrics(relation_source)
    r6_metrics = _metrics(r6_source)
    generated_cells = private_compare.get("generated_cells")
    if not isinstance(generated_cells, dict):
        raise ValueError("private-state compare missing generated_cells")
    mismatch_counts = generated_cells.get("mismatch_counts")
    if not isinstance(mismatch_counts, dict):
        raise ValueError("private-state compare missing generated_cells.mismatch_counts")
    native_cell_count = int(native.get("cell_count", -1))
    reset_samples = native.get("reset_samples")
    if not isinstance(reset_samples, list):
        raise ValueError("native relation summary missing reset_samples")
    source_clear_samples = native.get("source_clear_samples")
    if not isinstance(source_clear_samples, list):
        raise ValueError("native relation summary missing source_clear_samples")
    direction_table_entries = native.get("direction_table_entries")
    if not isinstance(direction_table_entries, list):
        raise ValueError("native relation summary missing direction_table_entries")
    reset_sample_checks = []
    for sample in reset_samples:
        if not isinstance(sample, dict):
            reset_sample_checks.append(False)
            continue
        reset_sample_checks.append(
            sample.get("word_0x10") == 0xFFFFFFFF
            and sample.get("word_0x14") == 0xFFFFFFFF
            and sample.get("word_0x18") == 0xFFFFFFFF
            and sample.get("word_0x1c") == 0x7D007D00
            and (int(sample.get("word_0x20", 0)) & 0xFF000000) == 0xFF000000
            and (int(sample.get("word_0x28", 0)) & (0x7 << 12)) == 0
        )
    source_clear_sample_checks = []
    for sample in source_clear_samples:
        if not isinstance(sample, dict):
            source_clear_sample_checks.append(False)
            continue
        source_clear_sample_checks.append(
            sample.get("before_word_0x1c") == 0x7D007D00
            and sample.get("after_word_0x1c") == 0x7D000000
            and sample.get("after_word_0x10") == 0xFFFFFFFF
            and sample.get("after_word_0x14") == 0xFFFFFFFF
            and sample.get("after_word_0x18") == 0xFFFFFFFF
            and sample.get("low_word_cleared") is True
            and sample.get("high_word_preserved") is True
            and sample.get("projection_triple_minus_one") is True
        )
    expected_direction_table = [
        (0, "0x5a2658", 1, 0),
        (1, "0x5a2660", 1, 1),
        (2, "0x5a2668", 0, 1),
        (3, "0x5a2670", -1, 1),
        (4, "0x5a2678", -1, 0),
        (5, "0x5a2680", -1, -1),
        (6, "0x5a2688", 0, -1),
        (7, "0x5a2690", 1, -1),
    ]
    direction_table_checks = []
    for expected, entry in zip(expected_direction_table, direction_table_entries):
        if not isinstance(entry, dict):
            direction_table_checks.append(False)
            continue
        expected_index, expected_address, expected_dx, expected_dy = expected
        direction_table_checks.append(
            int(entry.get("index", -1)) == expected_index
            and entry.get("address") == expected_address
            and int(entry.get("dx", 99)) == expected_dx
            and int(entry.get("dy", 99)) == expected_dy
            and entry.get("matches_recovered") is True
        )

    normalizer_count, normalizer_present = _file_marker_counts(relation_source, "normalizer_0x4a5767")
    normalizer_ref_count, normalizer_ref_present = _file_marker_counts(
        relation_source, "normalizer_refs_0x4a5767"
    )
    propagation_count, propagation_present = _file_marker_counts(
        relation_source, "propagation_helper_0x49a318"
    )
    propagation_ref_count, propagation_ref_present = _file_marker_counts(
        relation_source, "propagation_refs_0x49a318"
    )

    relation_source_status_checks = {
        "relation_source_status": relation_source.get("status")
        == "relation_normalization_static_surface_recovered_runtime_replay_pending",
        "r6_source_status": r6_source.get("status")
        == "r6_relation_scoring_semantic_replay_closed_ordered_replay_pending",
        "relation_marker_count": int(relation_metrics.get("marker_count", -1)) == 50,
        "relation_present_marker_count": int(relation_metrics.get("present_marker_count", -1)) == 50,
        "relation_missing_marker_count": int(relation_metrics.get("missing_marker_count", -1)) == 0,
        "relation_no_native_behavior_change": relation_metrics.get("native_behavior_changed") is False,
        "relation_no_objdump": relation_metrics.get("used_objdump") is False,
        "r6_no_native_behavior_change": r6_metrics.get("native_behavior_changed") is False,
        "r6_no_objdump": r6_metrics.get("used_objdump") is False,
        "r6_relation_surface_recovered": (
            (r6_source.get("invariants") or {}).get(
                "relation_normalizer_0x4a5767_0x49a318_semantic_surface_recovered"
            )
            is True
        ),
    }
    native_count_checks = {
        "native_static_marker_count": native.get("static_marker_count") == relation_metrics.get("marker_count"),
        "native_static_present_marker_count": native.get("static_present_marker_count")
        == relation_metrics.get("present_marker_count"),
        "native_static_missing_marker_count": native.get("static_missing_marker_count")
        == relation_metrics.get("missing_marker_count"),
        "native_normalizer_marker_count": native.get("normalizer_0x4a5767_marker_count")
        == normalizer_count,
        "native_normalizer_present_marker_count": native.get(
            "normalizer_0x4a5767_present_marker_count"
        )
        == normalizer_present,
        "native_normalizer_reference_marker_count": native.get(
            "normalizer_0x4a5767_reference_marker_count"
        )
        == normalizer_ref_count,
        "native_normalizer_reference_present_marker_count": native.get(
            "normalizer_0x4a5767_reference_present_marker_count"
        )
        == normalizer_ref_present,
        "native_propagation_marker_count": native.get("propagation_0x49a318_marker_count")
        == propagation_count,
        "native_propagation_present_marker_count": native.get(
            "propagation_0x49a318_present_marker_count"
        )
        == propagation_present,
        "native_propagation_reference_marker_count": native.get(
            "propagation_0x49a318_reference_marker_count"
        )
        == propagation_ref_count,
        "native_propagation_reference_present_marker_count": native.get(
            "propagation_0x49a318_reference_present_marker_count"
        )
        == propagation_ref_present,
    }
    same_run_relation_vector_materialized = (
        native.get("status") == "same_run_relation_vector_materialized_runtime_replay_pending"
        and native.get("relation_vector_runtime_order_materialized") is True
        and native.get("generator_0x10e4_relation_pointer_records_materialized") is True
        and native.get("generator_0x10e8_relation_pointer_end_materialized") is True
        and int(native.get("runtime_relation_vector_record_count", -1)) == 13
    )
    native_contract_checks = {
        "native_status_diagnostic": native.get("status")
        in {
            "diagnostic_relation_normalization_contract_ported_runtime_replay_pending",
            "same_run_relation_vector_materialized_runtime_replay_pending",
        },
        "native_contract_ported": native.get("relation_normalization_contract_ported_plain_cpp") is True,
        "native_4a59e2_pack_materialized": native.get(
            "helper_0x4a59e2_pack_materialized_plain_cpp"
        )
        is True,
        "native_4a5767_full_grid_reset_materialized": native.get(
            "full_grid_reset_0x4a5767_materialized_plain_cpp"
        )
        is True,
        "native_49a318_source_cell_clear_primitive_materialized": native.get(
            "propagation_source_cell_clear_0x49a318_primitive_materialized_plain_cpp"
        )
        is True,
        "native_49a318_source_cell_projection_triple_primitive_materialized": native.get(
            "propagation_source_cell_projection_triple_minus_one_primitive_materialized_plain_cpp"
        )
        is True,
        "native_keeps_49a318_source_cell_clear_live_application_pending": native.get(
            "propagation_source_cell_clear_live_application_pending"
        )
        is True,
        "native_49a318_direction_table_materialized": native.get(
            "propagation_direction_table_0x5a2658_materialized_plain_cpp"
        )
        is True,
        "native_keeps_49a318_direction_table_live_application_pending": native.get(
            "propagation_direction_table_live_application_pending"
        )
        is True,
        "native_49a318_direction_table_entry_count": int(
            native.get("propagation_direction_table_entry_count", -1)
        )
        == 8,
        "native_49a318_direction_table_unique_entry_count": int(
            native.get("propagation_direction_table_unique_entry_count", -1)
        )
        == 8,
        "native_49a318_direction_table_cardinal_entry_count": int(
            native.get("propagation_direction_table_cardinal_entry_count", -1)
        )
        == 4,
        "native_49a318_direction_table_diagonal_entry_count": int(
            native.get("propagation_direction_table_diagonal_entry_count", -1)
        )
        == 4,
        "native_49a318_direction_table_entries_present": len(direction_table_entries) == 8,
        "native_49a318_direction_table_entries_match_recovered": all(direction_table_checks)
        and len(direction_table_checks) == 8,
        "native_reset_projection_gate_materialized": native.get(
            "generated_cell_word_0x1c_reset_gate_materialized"
        )
        is True,
        "native_reset_projection_triple_materialized": native.get(
            "generated_cell_projection_triple_reset_materialized"
        )
        is True,
        "native_reset_cell_count_matches": int(native.get("reset_cell_count", -1))
        == native_cell_count,
        "native_reset_word_0x1c_all_cells": int(
            native.get("reset_word_0x1c_0x7d007d00_count", -1)
        )
        == native_cell_count,
        "native_reset_projection_triple_all_cells": int(
            native.get("reset_projection_triple_minus_one_count", -1)
        )
        == native_cell_count,
        "native_reset_word_0x20_byte3_all_cells": int(
            native.get("reset_word_0x20_byte3_minus_one_count", -1)
        )
        == native_cell_count,
        "native_reset_word_0x28_bits_12_14_zero_all_cells": int(
            native.get("reset_word_0x28_bits_12_14_zero_count", -1)
        )
        == native_cell_count,
        "native_reset_samples_present": 0 < len(reset_samples) <= 8,
        "native_reset_samples_match_reset_words": all(reset_sample_checks),
        "native_49a318_source_clear_samples_present": 0 < len(source_clear_samples) <= 8,
        "native_49a318_source_clear_sample_count_matches": int(
            native.get("propagation_source_cell_clear_sample_count", -1)
        )
        == len(source_clear_samples),
        "native_49a318_source_clear_low_word_zero_count_matches": int(
            native.get("propagation_source_cell_clear_low_word_zero_count", -1)
        )
        == len(source_clear_samples),
        "native_49a318_source_clear_high_word_preserved_count_matches": int(
            native.get("propagation_source_cell_clear_high_word_preserved_count", -1)
        )
        == len(source_clear_samples),
        "native_49a318_source_clear_projection_triple_count_matches": int(
            native.get("propagation_source_cell_projection_triple_minus_one_sample_count", -1)
        )
        == len(source_clear_samples),
        "native_49a318_source_clear_samples_match_recovered_primitive": all(
            source_clear_sample_checks
        ),
        "native_static_surface_recovered": native.get("static_surface_markers_recovered") is True,
        "native_r6_surface_recovered": native.get("r6_semantic_surface_recovered") is True,
        "native_diagnostic_only": native.get("diagnostic_only") is True,
        "native_behavior_unchanged": native.get("native_behavior_changed") is False,
        "native_no_objdump": native.get("used_objdump") is False,
        "native_keeps_runtime_replay_pending": native.get("runtime_ordered_replay_materialized") is False,
        "native_keeps_word20_low_word_pending": native.get(
            "generated_cell_word_0x20_low_word_propagation_materialized"
        )
        is False,
        "native_keeps_projection_gate_pending": native.get(
            "generated_cell_word_0x1c_projection_gate_materialized"
        )
        is False,
        "native_keeps_projection_triple_pending": native.get(
            "generated_cell_projection_triple_materialized"
        )
        is False,
        "native_keeps_object_reference_filter_pending": native.get(
            "object_reference_vector_filter_materialized"
        )
        is False,
        "native_keeps_descriptor_policy_pending": native.get("descriptor_policy_table_materialized")
        is False,
        "native_keeps_generated_cell_replay_pending": native.get(
            "generated_cell_mutation_replay_complete"
        )
        is False,
        "native_selected_template_vector_profile_available": native.get(
            "selected_template_vector_profile_available"
        )
        is True,
        "native_hc4_seed10_template_vector_validated": native.get(
            "same_run_h3maped_hc4_seed10_template_vector_validated"
        )
        is True,
        "native_selected_template_vector_candidate_count": int(
            native.get("selected_template_vector_candidate_count", -1)
        )
        == 23,
        "native_selected_template_vector_selected_index": int(
            native.get("selected_template_vector_selected_index", -1)
        )
        == 2,
        "native_selected_template_vector_rng_value": int(
            native.get("selected_template_vector_rng_value", -1)
        )
        == 71,
        "native_selected_template_source_catalog_index": int(
            native.get("selected_template_source_catalog_index", -1)
        )
        == 15,
        "native_selected_template_source_name": native.get("selected_template_source_name")
        == "2SM4d(2)",
        "native_selected_template_zone_count": int(native.get("selected_template_zone_count", -1))
        == 10,
        "native_selected_template_connection_count": int(
            native.get("selected_template_connection_count", -1)
        )
        == 15,
        "native_flat_template_link_seed_count": int(native.get("flat_template_link_seed_count", -1))
        == 15,
        "native_flat_template_link_seed_border_guard_count": int(
            native.get("flat_template_link_seed_border_guard_count", -1)
        )
        == 0,
        "native_flat_link_seeds_not_relation_vector": native.get(
            "flat_template_link_seeds_are_runtime_relation_vector"
        )
        is False,
        "native_generator_0x10e4_relation_records_pending": (
            native.get("generator_0x10e4_relation_pointer_records_materialized") is False
            or same_run_relation_vector_materialized
        ),
        "native_generator_0x10e8_relation_end_pending": (
            native.get("generator_0x10e8_relation_pointer_end_materialized") is False
            or same_run_relation_vector_materialized
        ),
        "native_relation_vector_blocker_names_0x10e4": "generator_plus_0x10e4"
        in str(native.get("relation_vector_blocked_reason", "")),
        "native_relation_vector_blocker_names_0x49a318": (
            "0x49a318" in str(native.get("relation_vector_blocked_reason", ""))
            or (
                same_run_relation_vector_materialized
                and "0x4a5a23" in str(native.get("relation_vector_blocked_reason", ""))
            )
        ),
    }
    prerequisite_checks = {
        "prerequisite_exposes_relation_contract": prerequisite.get(
            "relation_normalization_contract_ported_plain_cpp"
        )
        is True,
        "prerequisite_exposes_4a59e2_pack": prerequisite.get(
            "relation_normalization_4a59e2_pack_materialized_plain_cpp"
        )
        is True,
        "prerequisite_exposes_full_grid_reset": prerequisite.get(
            "relation_normalization_full_grid_reset_materialized_plain_cpp"
        )
        is True,
        "prerequisite_exposes_49a318_source_cell_clear_primitive": prerequisite.get(
            "relation_normalization_source_cell_clear_0x49a318_primitive_materialized"
        )
        is True,
        "prerequisite_exposes_49a318_source_cell_projection_triple_primitive": prerequisite.get(
            "relation_normalization_source_cell_projection_triple_minus_one_primitive_materialized"
        )
        is True,
        "prerequisite_keeps_49a318_source_cell_clear_live_application_pending": prerequisite.get(
            "relation_normalization_source_cell_clear_live_application_pending"
        )
        is True,
        "prerequisite_exposes_49a318_direction_table": prerequisite.get(
            "relation_normalization_direction_table_0x5a2658_materialized"
        )
        is True,
        "prerequisite_keeps_49a318_direction_table_live_application_pending": prerequisite.get(
            "relation_normalization_direction_table_live_application_pending"
        )
        is True,
        "prerequisite_exposes_projection_gate_reset": prerequisite.get(
            "relation_normalization_projection_gate_reset_materialized"
        )
        is True,
        "prerequisite_exposes_projection_triple_reset": prerequisite.get(
            "relation_normalization_projection_triple_reset_materialized"
        )
        is True,
        "prerequisite_keeps_runtime_replay_pending": prerequisite.get(
            "relation_normalization_runtime_replay_pending"
        )
        is True,
        "prerequisite_keeps_word20_low_word_pending": prerequisite.get(
            "relation_normalization_word20_low_word_propagation_pending"
        )
        is True,
        "prerequisite_keeps_projection_gate_pending": prerequisite.get(
            "relation_normalization_projection_gate_pending"
        )
        is True,
        "prerequisite_keeps_projection_triple_pending": prerequisite.get(
            "relation_normalization_projection_triple_pending"
        )
        is True,
        "prerequisite_keeps_object_reference_filter_pending": prerequisite.get(
            "relation_normalization_object_reference_filter_pending"
        )
        is True,
        "prerequisite_keeps_generated_cell_replay_pending": prerequisite.get(
            "generated_cell_mutation_replay_complete"
        )
        is False,
    }
    private_state_checks = {
        "private_compare_status_mismatch": private_compare.get("status") == "mismatch",
        "generated_cells_status_mismatch": generated_cells.get("status") == "mismatch",
        "private_compare_expected_cell_count": private_compare.get("expected_cell_count") == 5184,
        "private_compare_word20_low_word_mismatch_present": int(
            mismatch_counts.get("word_0x20_low_word_mismatch", -1)
        )
        > 0,
        "private_compare_word20_high_word_mismatch_present": int(
            mismatch_counts.get("word_0x20_high_word_mismatch", 0)
        )
        > 0,
        "private_compare_word24_mismatch_present": int(mismatch_counts.get("word_0x24_mismatch", 0))
        > 0,
        "private_compare_word28_mismatch_present": int(mismatch_counts.get("word_0x28_mismatch", 0))
        > 0,
    }
    selected_candidate_relation_checks: dict[str, bool] = {}
    selected_candidate_relation_summary: dict[str, Any] = {}
    if isinstance(selected_candidate_relation, dict):
        owners = selected_candidate_relation.get("owners")
        if not isinstance(owners, list):
            raise ValueError("selected-candidate relation summary missing owners")
        owner_record_counts = [
            int((owner.get("relation_vector") or {}).get("count", len(owner.get("records", []))))
            for owner in owners
            if isinstance(owner, dict)
        ]
        owner_border_counts = [
            int(owner.get("border_guard_record_count", 0))
            for owner in owners
            if isinstance(owner, dict)
        ]
        selected_total = int(selected_candidate_relation.get("total_relation_record_count", -1))
        selected_border = int(
            selected_candidate_relation.get("border_guard_relation_record_count", -1)
        )
        selected_stride = int(
            (selected_candidate_relation.get("invariants") or {}).get(
                "relation_record_stride_bytes", -1
            )
        )
        selected_candidate_relation_summary = {
            "path": str(selected_candidate_relation_path),
            "status": selected_candidate_relation.get("status", ""),
            "owner_count": len(owners),
            "total_record_count": selected_total,
            "border_guard_record_count": selected_border,
            "record_stride_bytes": selected_stride,
            "owner_record_counts": owner_record_counts,
            "owner_border_guard_counts": owner_border_counts,
        }
        selected_candidate_relation_checks = {
            "selected_candidate_relation_source_status": selected_candidate_relation.get("status")
            == "selected_candidate_has_border_guard_records",
            "selected_candidate_relation_source_stride": selected_stride == 28,
            "native_selected_candidate_relation_profile_available": native.get(
                "selected_candidate_relation_record_profile_available"
            )
            is True,
            "native_selected_candidate_relation_topology_recorded": native.get(
                "same_run_h3maped_hc4_seed10_selected_candidate_relation_topology_recorded"
            )
            is True,
            "native_selected_candidate_relation_owner_count": int(
                native.get("selected_candidate_relation_owner_count", -1)
            )
            == len(owners),
            "native_selected_candidate_relation_total_count": int(
                native.get("selected_candidate_relation_total_record_count", -1)
            )
            == selected_total,
            "native_selected_candidate_relation_border_count": int(
                native.get("selected_candidate_relation_border_guard_record_count", -1)
            )
            == selected_border,
            "native_selected_candidate_relation_stride": int(
                native.get("selected_candidate_relation_record_stride_bytes", -1)
            )
            == selected_stride,
            "native_selected_candidate_relation_owner_counts": native.get(
                "selected_candidate_relation_owner_record_counts"
            )
            == owner_record_counts,
            "native_selected_candidate_relation_owner_border_counts": native.get(
                "selected_candidate_relation_owner_border_guard_counts"
            )
            == owner_border_counts,
            "native_flat_template_link_seed_delta_records": int(
                native.get("template_vs_selected_candidate_relation_record_count_delta", 999)
            )
            == int(native.get("flat_template_link_seed_count", 0)) - selected_total,
            "native_flat_template_link_seed_delta_border_guards": int(
                native.get("template_vs_selected_candidate_border_guard_record_count_delta", 999)
            )
            == int(native.get("flat_template_link_seed_border_guard_count", 0)) - selected_border,
            "native_flat_template_link_seed_surface_not_selected_candidate_relation_records": native.get(
                "flat_template_link_seed_surface_matches_selected_candidate_relation_records"
            )
            is False,
            "native_selected_candidate_relation_not_generator_0x10e4_vector": native.get(
                "selected_candidate_relation_records_are_generator_0x10e4_runtime_vector"
            )
            is False,
        }

    all_checks = {
        **relation_source_status_checks,
        **native_count_checks,
        **native_contract_checks,
        **prerequisite_checks,
        **private_state_checks,
        **selected_candidate_relation_checks,
    }
    failed_checks = [key for key, passed in all_checks.items() if not passed]
    status = "pass" if not failed_checks else "mismatch"
    return {
        "schema_id": "rmg_h3maped_relation_normalization_contract_verify_v1",
        "status": status,
        "native_snapshot": str(snapshot_path),
        "relation_normalization_summary": str(relation_normalization_path),
        "r6_summary": str(r6_summary_path),
        "private_state_compare": str(private_state_compare_path),
        "selected_candidate_relation_summary": selected_candidate_relation_summary,
        "checks": all_checks,
        "failed_checks": failed_checks,
        "native_runtime_ordered_replay_materialized": native.get(
            "runtime_ordered_replay_materialized"
        ),
        "native_full_grid_reset_0x4a5767_materialized": native.get(
            "full_grid_reset_0x4a5767_materialized_plain_cpp"
        ),
        "native_49a318_source_cell_clear_primitive_materialized": native.get(
            "propagation_source_cell_clear_0x49a318_primitive_materialized_plain_cpp"
        ),
        "native_49a318_source_cell_projection_triple_primitive_materialized": native.get(
            "propagation_source_cell_projection_triple_minus_one_primitive_materialized_plain_cpp"
        ),
        "native_49a318_source_cell_clear_live_application_pending": native.get(
            "propagation_source_cell_clear_live_application_pending"
        ),
        "native_49a318_direction_table_materialized": native.get(
            "propagation_direction_table_0x5a2658_materialized_plain_cpp"
        ),
        "native_49a318_direction_table_live_application_pending": native.get(
            "propagation_direction_table_live_application_pending"
        ),
        "native_49a318_direction_table_entry_count": native.get(
            "propagation_direction_table_entry_count"
        ),
        "native_reset_cell_count": native.get("reset_cell_count"),
        "native_reset_word_0x1c_0x7d007d00_count": native.get(
            "reset_word_0x1c_0x7d007d00_count"
        ),
        "native_49a318_source_cell_clear_sample_count": native.get(
            "propagation_source_cell_clear_sample_count"
        ),
        "native_word20_low_word_propagation_materialized": native.get(
            "generated_cell_word_0x20_low_word_propagation_materialized"
        ),
        "native_hc4_seed10_template_vector_validated": native.get(
            "same_run_h3maped_hc4_seed10_template_vector_validated"
        ),
        "native_selected_template_vector_candidate_count": native.get(
            "selected_template_vector_candidate_count"
        ),
        "native_selected_template_vector_selected_index": native.get(
            "selected_template_vector_selected_index"
        ),
        "native_selected_template_vector_rng_value": native.get(
            "selected_template_vector_rng_value"
        ),
        "native_selected_template_source_name": native.get("selected_template_source_name"),
        "native_flat_template_link_seed_count": native.get("flat_template_link_seed_count"),
        "native_selected_candidate_relation_total_record_count": native.get(
            "selected_candidate_relation_total_record_count"
        ),
        "native_selected_candidate_relation_border_guard_record_count": native.get(
            "selected_candidate_relation_border_guard_record_count"
        ),
        "native_template_vs_selected_candidate_relation_record_count_delta": native.get(
            "template_vs_selected_candidate_relation_record_count_delta"
        ),
        "native_template_vs_selected_candidate_border_guard_record_count_delta": native.get(
            "template_vs_selected_candidate_border_guard_record_count_delta"
        ),
        "native_relation_vector_blocked_reason": native.get("relation_vector_blocked_reason"),
        "private_word20_low_word_mismatch_count": mismatch_counts.get(
            "word_0x20_low_word_mismatch"
        ),
        "private_word20_high_word_mismatch_count": mismatch_counts.get(
            "word_0x20_high_word_mismatch"
        ),
        "private_word24_mismatch_count": mismatch_counts.get("word_0x24_mismatch"),
        "private_word28_mismatch_count": mismatch_counts.get("word_0x28_mismatch"),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native-phase-snapshot", type=Path, required=True)
    parser.add_argument("--relation-normalization-summary", type=Path, required=True)
    parser.add_argument("--r6-summary", type=Path, required=True)
    parser.add_argument("--private-state-compare", type=Path, required=True)
    parser.add_argument("--selected-candidate-relation-summary", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()

    report = verify(
        args.native_phase_snapshot,
        args.relation_normalization_summary,
        args.r6_summary,
        args.private_state_compare,
        args.selected_candidate_relation_summary,
    )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    with args.out.open("w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, sort_keys=True)
        handle.write("\n")
    print(
        "RMG_H3MAPED_RELATION_NORMALIZATION_CONTRACT_VERIFY "
        f"status={report['status']} "
        f"word20_low_mismatch={report.get('private_word20_low_word_mismatch_count')} "
        f"failed={len(report['failed_checks'])} out={args.out}"
    )
    return 0 if report["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
