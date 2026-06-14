#!/usr/bin/env python3
"""Verify native 0x4a79a3 endpoint-dispatch diagnostics against recovered H3MapEd evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


def _load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def _native_endpoint_summary(snapshot: dict[str, Any]) -> dict[str, Any]:
    summary = snapshot.get("plain_cpp_object_vector_endpoint_dispatch_summary")
    if not isinstance(summary, dict):
        raise ValueError("native snapshot missing plain_cpp_object_vector_endpoint_dispatch_summary")
    return summary


def _native_prerequisite(snapshot: dict[str, Any]) -> dict[str, Any]:
    summary = snapshot.get("plain_cpp_object_vector_prerequisite_contract_summary")
    if not isinstance(summary, dict):
        raise ValueError("native snapshot missing plain_cpp_object_vector_prerequisite_contract_summary")
    return summary


def _surface_by_entry(static_surface: dict[str, Any], entry: str) -> dict[str, Any]:
    surfaces = static_surface.get("surfaces")
    if not isinstance(surfaces, list):
        raise ValueError("static surface summary missing surfaces")
    for surface in surfaces:
        if isinstance(surface, dict) and surface.get("entry") == entry:
            return surface
    raise ValueError(f"static surface summary missing surface {entry}")


def _static_call_count(surface: dict[str, Any], key: str) -> int:
    calls = surface.get("expected_call_counts")
    if not isinstance(calls, dict):
        raise ValueError(f"surface {surface.get('entry')} missing expected_call_counts")
    record = calls.get(key)
    if not isinstance(record, dict):
        raise ValueError(f"surface {surface.get('entry')} missing call count {key}")
    return int(record.get("actual_count"))


def _trace_address_count(trace_summary: dict[str, Any], address: str) -> int:
    trace = trace_summary.get("trace")
    if not isinstance(trace, dict):
        raise ValueError("cell mutation summary missing trace")
    counts = trace.get("address_counts")
    if not isinstance(counts, dict):
        raise ValueError("cell mutation summary missing trace.address_counts")
    return int(counts.get(address, 0))


def _trace_direct_mutation_hit_count(trace_summary: dict[str, Any]) -> int:
    trace = trace_summary.get("trace")
    if not isinstance(trace, dict):
        raise ValueError("cell mutation summary missing trace")
    hits = trace.get("direct_mutation_site_hits")
    if not isinstance(hits, dict):
        raise ValueError("cell mutation summary missing trace.direct_mutation_site_hits")
    return sum(int(value) for value in hits.values())


def verify(
    snapshot_path: Path,
    filter_dispatch_path: Path,
    static_surface_path: Path,
    target_mode_path: Path,
    grid_summary_path: Path,
    cell_mutation_path: Path,
) -> dict[str, Any]:
    snapshot = _load_json(snapshot_path)
    filter_dispatch = _load_json(filter_dispatch_path)
    static_surface = _load_json(static_surface_path)
    target_mode = _load_json(target_mode_path)
    grid_summary = _load_json(grid_summary_path)
    cell_mutation = _load_json(cell_mutation_path)

    native = _native_endpoint_summary(snapshot)
    prerequisite = _native_prerequisite(snapshot)
    surface_4a696b = _surface_by_entry(static_surface, "0x004a696b")
    surface_4a7605 = _surface_by_entry(static_surface, "0x004a7605")
    target_metrics = target_mode.get("metrics") or {}
    grid_metrics = grid_summary.get("metrics") or {}

    source_status_checks = {
        "filter_dispatch_status": filter_dispatch.get("status")
        == "partial_live_recovery_4a79a3_filter_and_c8_dispatch",
        "static_surface_status": static_surface.get("status")
        == "partial_static_recovery_696b_7605_mutation_surface",
        "target_mode_status": target_mode.get("status")
        == "target_mode_4a696b_direct_mutation_unreached_pair_gate_explained",
        "grid_summary_status": grid_summary.get("status")
        == "multi_seed_4a696b_source_relation_pair_gate_recovered",
        "cell_mutation_status": cell_mutation.get("status")
        == "partial_live_recovery_4a696b_direct_mutation_sites_not_hit",
    }

    filter_invariants = filter_dispatch.get("invariants") or {}
    static_invariants = static_surface.get("invariants") or {}
    target_invariants = target_mode.get("invariants") or {}
    grid_invariants = grid_summary.get("invariants") or {}
    cell_invariants = cell_mutation.get("invariants") or {}
    invariant_checks = {
        "filter_hit_4a696b": filter_invariants.get("dispatch_trace_hit_4a696b_from_4a79a3") is True,
        "filter_hit_4a7605": filter_invariants.get("dispatch_trace_hit_4a7605_from_4a79a3") is True,
        "filter_hit_pair_marks": filter_invariants.get("dispatch_trace_hit_pair_mark_sites") is True,
        "static_4a696b_recovered": static_invariants.get("static_4a696b_direct_mutation_surface_recovered")
        is True,
        "static_4a7605_recovered": static_invariants.get("static_4a7605_fallback_coordinator_surface_recovered")
        is True,
        "target_excludes_direct_hits": target_invariants.get("corpus_has_no_source_relation_match_or_deeper_hit")
        is True,
        "grid_pair_gate_recovered": grid_invariants.get("all_complete_scans_have_zero_owner_relation_pair_matches")
        is True,
        "cell_direct_sites_not_hit": cell_invariants.get("direct_4a696b_mutation_sites_not_hit") is True,
        "cell_hit_two_4a7312_calls": cell_invariants.get("hit_two_4a7312_calls") is True,
    }

    expected_counts = {
        "source_4a696b_combined_entries": int(target_metrics.get("combined_4a696b_entries")),
        "source_4a696b_source_relation_match_hits": int(
            target_metrics.get("combined_source_relation_match_hits")
        ),
        "source_4a696b_candidate_append_hits": int(target_metrics.get("combined_candidate_append_hits")),
        "source_4a696b_direct_mutation_hits": int(target_metrics.get("combined_direct_mutation_hits")),
        "source_4a696b_complete_grid_scan_count": int(target_metrics.get("complete_grid_scan_count")),
        "source_4a696b_zero_owner_relation_pair_match_scan_count": int(
            target_metrics.get("zero_owner_relation_pair_match_scan_count")
        ),
        "source_4a696b_scanned_cell_total": int(target_metrics.get("scanned_cell_total")),
        "source_4a696b_seed_count": int(target_metrics.get("seed_count")),
        "source_4a696b_byte2_only_or_any_match_total": int(
            target_metrics.get("byte2_only_or_any_match_total")
        ),
        "source_4a696b_byte3_only_or_any_match_total": int(
            target_metrics.get("byte3_only_or_any_match_total")
        ),
        "trace_4a696b_entry_count": _trace_address_count(cell_mutation, "0x004a696b"),
        "trace_4a7605_entry_count": _trace_address_count(cell_mutation, "0x004a7605"),
        "trace_4a7312_call_count": _trace_address_count(cell_mutation, "0x004a7312"),
        "trace_4a7312_vtable_commit_count": _trace_address_count(cell_mutation, "0x004a7447"),
        "trace_4a696b_direct_mutation_site_hit_count": _trace_direct_mutation_hit_count(cell_mutation),
        "static_4a7605_endpoint_policy_4a7312_count": _static_call_count(
            surface_4a7605, "endpoint_policy_4a7312"
        ),
        "static_4a7605_endpoint_writer_4a746b_count": _static_call_count(
            surface_4a7605, "endpoint_writer_4a746b"
        ),
        "static_4a7605_materializer_4a5e03_count": _static_call_count(
            surface_4a7605, "guard_or_object_materializer_4a5e03"
        ),
        "static_4a7605_record_initializer_49ba89_count": _static_call_count(
            surface_4a7605, "record_initializer_49ba89"
        ),
        "static_4a7605_coordinate_append_40bb15_count": _static_call_count(
            surface_4a7605, "coordinate_append_40bb15"
        ),
        "static_4a7605_coordinate_merge_40bb26_count": _static_call_count(
            surface_4a7605, "coordinate_merge_40bb26"
        ),
        "static_4a7605_direct_generated_cell_28_write_count": int(
            surface_4a7605.get("direct_generated_cell_28_write_seen_in_this_dump") is True
        ),
    }
    grid_consistency_checks = {
        "grid_seed_count_matches_target": grid_metrics.get("seed_count") == target_metrics.get("seed_count"),
        "grid_scanned_cell_total_matches_target": grid_metrics.get("scanned_cell_total")
        == target_metrics.get("scanned_cell_total"),
        "grid_zero_pair_scan_count_matches_target": grid_metrics.get(
            "zero_owner_relation_pair_match_scan_count"
        )
        == target_metrics.get("zero_owner_relation_pair_match_scan_count"),
    }
    count_mismatches = [
        {"key": key, "native": native.get(key), "h3maped": expected}
        for key, expected in expected_counts.items()
        if native.get(key) != expected
    ]

    native_hard_checks = {
        "native_status_diagnostic": native.get("status")
        == "diagnostic_4a79a3_endpoint_dispatch_exclusion_ported",
        "native_diagnostic_only": native.get("diagnostic_only") is True,
        "native_behavior_unchanged": native.get("native_behavior_changed") is False,
        "native_endpoint_contract_ported": native.get("endpoint_dispatch_contract_ported_plain_cpp") is True,
        "native_filter_dispatch_recovered": native.get("filter_dispatch_summary_recovered") is True,
        "native_static_4a696b_surface_recovered": native.get(
            "static_4a696b_direct_mutation_surface_recovered"
        )
        is True
        and surface_4a696b.get("static_contract_recovered") is True,
        "native_static_4a7605_surface_recovered": native.get(
            "static_4a7605_fallback_coordinator_surface_recovered"
        )
        is True
        and surface_4a7605.get("static_contract_recovered") is True,
        "native_supported_land_excludes_direct_4a696b_mutation": native.get(
            "target_mode_4a696b_direct_mutation_excluded_supported_land"
        )
        is True
        and native.get("source_4a696b_direct_mutation_hits") == 0
        and native.get("trace_4a696b_direct_mutation_site_hit_count") == 0,
        "native_hits_dispatch_and_pair_marks": native.get("hit_4a696b_from_4a79a3") is True
        and native.get("hit_4a7605_from_4a79a3") is True
        and native.get("hit_pair_mark_sites") is True,
        "native_keeps_adoption_denied": native.get("direct_4a696b_mutation_adopted") is False
        and native.get("delegated_4a7605_afterstate_materialized") is False
        and native.get("generated_cell_mutation_replay_complete") is False,
        "prerequisite_exposes_endpoint_blockers": prerequisite.get(
            "object_vector_endpoint_dispatch_exclusion_ported_plain_cpp"
        )
        is True
        and prerequisite.get("endpoint_dispatch_4a696b_direct_mutation_excluded_supported_land") is True
        and prerequisite.get("endpoint_dispatch_4a7605_delegated_materialization_afterstate_pending") is True
        and prerequisite.get("sampled_endpoint_dispatch_4a696b_direct_mutation_hits") == 0
        and prerequisite.get("generated_cell_mutation_replay_complete") is False,
    }

    all_checks = {
        **source_status_checks,
        **invariant_checks,
        **grid_consistency_checks,
        **native_hard_checks,
    }
    failed_checks = [key for key, passed in all_checks.items() if not passed]
    status = "pass" if not failed_checks and not count_mismatches else "mismatch"
    return {
        "schema_id": "rmg_h3maped_4a79a3_endpoint_dispatch_verify_v1",
        "status": status,
        "native_snapshot": str(snapshot_path),
        "filter_dispatch_summary": str(filter_dispatch_path),
        "static_surface_summary": str(static_surface_path),
        "target_mode_summary": str(target_mode_path),
        "grid_summary": str(grid_summary_path),
        "cell_mutation_summary": str(cell_mutation_path),
        "checks": all_checks,
        "failed_checks": failed_checks,
        "count_mismatches": count_mismatches,
        "native_trace_4a696b_entry_count": native.get("trace_4a696b_entry_count"),
        "native_trace_4a7605_entry_count": native.get("trace_4a7605_entry_count"),
        "native_source_relation_match_hits": native.get("source_4a696b_source_relation_match_hits"),
        "native_direct_mutation_hits": native.get("source_4a696b_direct_mutation_hits"),
        "native_direct_4a696b_mutation_adopted": native.get("direct_4a696b_mutation_adopted"),
        "native_delegated_4a7605_afterstate_materialized": native.get(
            "delegated_4a7605_afterstate_materialized"
        ),
        "native_generated_cell_mutation_replay_complete": native.get(
            "generated_cell_mutation_replay_complete"
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native-phase-snapshot", required=True, type=Path)
    parser.add_argument("--filter-dispatch-summary", required=True, type=Path)
    parser.add_argument("--static-surface-summary", required=True, type=Path)
    parser.add_argument("--target-mode-summary", required=True, type=Path)
    parser.add_argument("--grid-summary", required=True, type=Path)
    parser.add_argument("--cell-mutation-summary", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    report = verify(
        args.native_phase_snapshot,
        args.filter_dispatch_summary,
        args.static_surface_summary,
        args.target_mode_summary,
        args.grid_summary,
        args.cell_mutation_summary,
    )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_4A79A3_ENDPOINT_DISPATCH_VERIFY "
        f"status={report['status']} "
        f"trace_4a696b={report['native_trace_4a696b_entry_count']} "
        f"trace_4a7605={report['native_trace_4a7605_entry_count']} "
        f"direct_hits={report['native_direct_mutation_hits']} "
        f"replay_complete={report['native_generated_cell_mutation_replay_complete']} "
        f"out={args.out}"
    )
    return 0 if report["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
