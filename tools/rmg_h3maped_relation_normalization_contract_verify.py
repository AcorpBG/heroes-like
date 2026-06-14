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
) -> dict[str, Any]:
    snapshot = _load_json(snapshot_path)
    relation_source = _load_json(relation_normalization_path)
    r6_source = _load_json(r6_summary_path)
    private_compare = _load_json(private_state_compare_path)

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
    native_contract_checks = {
        "native_status_diagnostic": native.get("status")
        == "diagnostic_relation_normalization_contract_ported_runtime_replay_pending",
        "native_contract_ported": native.get("relation_normalization_contract_ported_plain_cpp") is True,
        "native_4a59e2_pack_materialized": native.get(
            "helper_0x4a59e2_pack_materialized_plain_cpp"
        )
        is True,
        "native_4a5767_full_grid_reset_materialized": native.get(
            "full_grid_reset_0x4a5767_materialized_plain_cpp"
        )
        is True,
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
        "private_compare_word20_low_word_mismatch_all_cells": int(
            mismatch_counts.get("word_0x20_low_word_mismatch", -1)
        )
        == 5184,
        "private_compare_word20_high_word_mismatch_present": int(
            mismatch_counts.get("word_0x20_high_word_mismatch", 0)
        )
        > 0,
        "private_compare_word24_mismatch_present": int(mismatch_counts.get("word_0x24_mismatch", 0))
        > 0,
        "private_compare_word28_mismatch_present": int(mismatch_counts.get("word_0x28_mismatch", 0))
        > 0,
    }

    all_checks = {
        **relation_source_status_checks,
        **native_count_checks,
        **native_contract_checks,
        **prerequisite_checks,
        **private_state_checks,
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
        "checks": all_checks,
        "failed_checks": failed_checks,
        "native_runtime_ordered_replay_materialized": native.get(
            "runtime_ordered_replay_materialized"
        ),
        "native_full_grid_reset_0x4a5767_materialized": native.get(
            "full_grid_reset_0x4a5767_materialized_plain_cpp"
        ),
        "native_reset_cell_count": native.get("reset_cell_count"),
        "native_reset_word_0x1c_0x7d007d00_count": native.get(
            "reset_word_0x1c_0x7d007d00_count"
        ),
        "native_word20_low_word_propagation_materialized": native.get(
            "generated_cell_word_0x20_low_word_propagation_materialized"
        ),
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
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()

    report = verify(
        args.native_phase_snapshot,
        args.relation_normalization_summary,
        args.r6_summary,
        args.private_state_compare,
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
