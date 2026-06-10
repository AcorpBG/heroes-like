#!/usr/bin/env python3
"""Summarize recovered H3MapEd RMG working semantic names.

This verifier consolidates fields that are no longer just hex offsets in the
current recovery evidence. The output is deliberately a working-name frontier:
it records source-backed names that are useful for native-port planning while
keeping producer paths and global descriptor labels as explicit blockers.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_CONNECTION_FIELDS = Path(".artifacts/rmg_recovery/connection_record_field_summary.json")
DEFAULT_CANDIDATE_VTABLES = Path(
    ".artifacts/rmg_recovery/medium_4a9f1c_candidate_vtable_contract_summary_20260608.json"
)
DEFAULT_EXACT_DESCRIPTOR_RELATION = Path(
    ".artifacts/rmg_recovery/medium_seed10_fallback_exact_descriptor_relation_summary_20260609.json"
)
DEFAULT_FINAL_ROLE_FRONTIER = Path(
    ".artifacts/rmg_recovery/medium_seed10_fallback_final_role_frontier_summary_20260609.json"
)
DEFAULT_BORDER_GUARD_CHAIN = Path(
    ".artifacts/rmg_recovery/border_guard_downstream_chain_summary_20260610.json"
)
DEFAULT_4A5E73 = Path(".artifacts/rmg_recovery/4a5e73_cursor_frontier_summary_20260610.json")
DEFAULT_4A5E73_CALLER_GATES = Path(
    ".artifacts/rmg_recovery/4a5e73_caller_gate_surface_summary_20260610.json"
)
DEFAULT_CURSOR_OWNER = Path(
    ".artifacts/rmg_recovery/cursor_writer_owner_exclusion_summary_20260610.json"
)
DEFAULT_CURSOR_SOURCE = Path(
    ".artifacts/rmg_recovery/cursor_source_frontier_summary_20260610.json"
)
DEFAULT_4A606B = Path(".artifacts/rmg_recovery/4a606b_reachability_summary_20260610.json")
DEFAULT_OUT = Path(".artifacts/rmg_recovery/semantic_frontier_summary_20260610.json")


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def has_keys(mapping: dict[str, Any], keys: set[str]) -> bool:
    return keys.issubset(set(mapping))


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    connection = load_json(args.connection_fields)
    candidate = load_json(args.candidate_vtables)
    exact_descriptor = load_json(args.exact_descriptor_relation)
    final_role = load_json(args.final_role_frontier)
    border_guard_chain = load_json(args.border_guard_chain)
    four_a5e73 = load_json(args.four_a5e73)
    four_a5e73_caller_gates = load_json(args.four_a5e73_caller_gates)
    cursor_owner = load_json(args.cursor_owner)
    cursor_source = load_json(args.cursor_source)
    four_a606b = load_json(args.four_a606b)

    connection_fields = connection.get("recovered_fields", {})
    candidate_fields = candidate.get("recovered_contract", {}).get("candidate_record_fields", {})
    final_invariants = final_role.get("invariants", {})
    descriptor_invariants = exact_descriptor.get("invariants", {})

    final_records = final_role.get("records", [])
    descriptor_types = sorted(
        {
            record.get("descriptor_relation", {}).get("descriptor_type")
            for record in final_records
            if record.get("descriptor_relation", {}).get("descriptor_type") is not None
        }
    )

    plus9_field = connection_fields.get("+0x09", {})
    invariants = {
        "no_native_behavior_change": (
            connection.get("invariants", {}).get("no_native_behavior_change") is True
            and candidate.get("native_behavior_changed") is False
            and exact_descriptor.get("native_behavior_changed") is False
            and final_role.get("native_behavior_changed") is False
        ),
        "no_objdump_used": True,
        "connection_plus9_source_producer_recovered": connection.get("status")
        == "recovered_connection_record_plus9_border_guard_surface"
        and plus9_field.get("source_producer", {}).get("source_row_name") == "Border Guard",
        "exact_seed10_border_guard_downstream_chain_recovered": border_guard_chain.get("status")
        == "exact_seed10_border_guard_downstream_chain_recovered_broader_linkage_pending"
        and border_guard_chain.get("invariants", {}).get("exact_fallback_final_role_recovered")
        is True,
        "current_4a5e73_cursor_precondition_recovered_success_path_unhit": (
            four_a5e73.get("status")
            == "target_mode_4a5e73_cursor_precondition_recovered_success_path_unhit"
            and four_a5e73.get("invariants", {}).get("static_contract_recovered") is True
            and four_a5e73.get("invariants", {}).get(
                "current_corpus_has_no_5e73_success_path_hit"
            )
            is True
        ),
        "current_4a5e73_caller_gate_surface_recovered": (
            four_a5e73_caller_gates.get("status")
            == "4a5e73_all_caller_gate_surface_recovered_current_scope_success_path_still_unrecovered"
            and four_a5e73_caller_gates.get("invariants", {}).get("six_static_callers_recovered")
            is True
            and four_a5e73_caller_gates.get("invariants", {}).get(
                "inactive_current_corpus_callsite_family_has_no_runtime_hits"
            )
            is True
        ),
        "cursor_writer_owner_frontier_recovered": (
            cursor_owner.get("status")
            == "cursor_writer_owner_frontier_nonself_writers_bound_to_unhit_projection_slots"
            and cursor_owner.get("invariants", {}).get(
                "non_self_cursor_writers_are_projection_chain_entries"
            )
            is True
            and cursor_owner.get("invariants", {}).get(
                "projection_slot_chain_unhit_in_current_target_corpus"
            )
            is True
        ),
        "cursor_source_frontier_recovered_success_path_still_unrecovered": (
            cursor_source.get("status")
            == "cursor_source_frontier_setup_and_writer_surface_recovered_success_path_still_unrecovered"
            and cursor_source.get("invariants", {}).get("setup_initializes_f58_not_f5c") is True
            and cursor_source.get("invariants", {}).get("direct_f5c_writer_surface_exhausted")
            is True
            and cursor_source.get("invariants", {}).get(
                "non_self_f5c_writers_bound_to_unhit_projection_chain"
            )
            is True
            and cursor_source.get("invariants", {}).get(
                "sampled_projection_slot_recycle_boundary_recovered"
            )
            is True
            and cursor_source.get("metrics", {}).get("used_objdump") is False
        ),
        "current_4a606b_static_contract_recovered_no_live_hit": (
            four_a606b.get("status")
            == "target_mode_4a606b_static_contract_recovered_no_live_hit"
            and four_a606b.get("invariants", {}).get("static_contract_recovered") is True
            and four_a606b.get("invariants", {}).get("current_corpus_has_no_live_4a606b_hit")
            is True
        ),
        "connection_record_offsets_named": has_keys(connection_fields, {"+0x08", "+0x09", "+0x0a"}),
        "candidate_record_offsets_named": has_keys(
            candidate_fields, {"+0x00", "+0x04", "+0x08", "+0x0c"}
        ),
        "selected_candidate_vtable_contracts_recovered": candidate.get("status")
        == "passed_selected_candidate_vtable_contracts"
        and not candidate.get("selected_candidate_vtables_without_contract"),
        "descriptor_projection_mechanics_recovered_for_sample": (
            descriptor_invariants.get("all_descriptor_projection_flags_nonzero") is True
            and descriptor_invariants.get("all_source_coordinates_match_descriptor_offsets") is True
            and descriptor_invariants.get("all_relation_counter_slots_match_source_owner_relation")
            is True
            and descriptor_invariants.get("all_relation_counters_increment_by_one") is True
        ),
        "exact_final_role_descriptor_relation_recovered": (
            final_invariants.get("exact_descriptor_relation_recovered_for_all_fallback_records")
            is True
            and final_invariants.get("exact_coordinates_match_for_all_fallback_records") is True
        ),
    }

    recovered_working_names = [
        {
            "domain": "connection_record",
            "fields": connection_fields,
            "confidence": "source_and_consumer_working_names_for_plus09_consumer_side_for_other_bytes",
        },
        {
            "domain": "candidate_record",
            "fields": candidate_fields,
            "confidence": "vtable_contract_and_selected_create_working_names",
        },
        {
            "domain": "object_descriptor",
            "fields": {
                "+0x1c": {
                    "working_name": "descriptor_type_counter_index",
                    "evidence": [
                        "Exact fallback records use descriptor type 54.",
                        "Relation counter slot is relation+0x44 + descriptor_type*4.",
                    ],
                },
                "+0x29": {
                    "working_name": "projection_path_enabled_flag",
                    "evidence": [
                        "Exact descriptor/relation replay proves descriptor +0x29 is nonzero on sampled projection-path records.",
                        "0x4a54a7 returns after the basic commit when this flag is zero; nonzero reaches source-cell projection mechanics.",
                    ],
                },
                "+0x2c/+0x30": {
                    "working_name": "source_cell_x_y_offsets",
                    "evidence": [
                        "Exact descriptor/relation replay proves subtracting these offsets from object coordinates selects the source generated cell.",
                    ],
                },
            },
            "descriptor_types_seen": descriptor_types,
            "confidence": "exact_seed10_fallback_records_only",
        },
        {
            "domain": "relation_record",
            "fields": {
                "+0x44 + descriptor_type*4": {
                    "working_name": "per_relation_descriptor_type_occupancy_counter",
                    "evidence": [
                        "Exact fallback records increment this slot by one.",
                        "Counter address matches the relation selected by GeneratedCell+0x20 byte2.",
                    ],
                }
            },
            "confidence": "exact_seed10_fallback_records_only",
        },
        {
            "domain": "generated_cell",
            "fields": {
                "+0x20 byte2": {
                    "working_name": "source_owner_relation_index",
                    "evidence": [
                        "Exact fallback descriptor/relation replay selects generator+0x10e4 relation pointer from this byte.",
                    ],
                },
                "+0x20 low word": {
                    "working_name": "projection_distance_or_local_score",
                    "evidence": [
                        "0x4a54a7 clears the source low word and projection writes preserve high word while lowering low word.",
                    ],
                },
            },
            "confidence": "exact_seed10_fallback_and_projection_write_records",
        },
        {
            "domain": "border_guard_downstream_chain",
            "fields": {
                "connection_record+0x09": "template Border Guard flag",
                "0x4a5e73": "stale-cursor endpoint attempts fail for exact seed-10 sample",
                "0x4a7605 -> 0x4a5e03": "fallback materializes exact records 0x036260c0 and 0x03626060",
                "0x4a54a7/0x49eb8d/0x4ac552": "commit, survival, first 0x49e700 mutation set, and phase tail recovered for exact records",
            },
            "confidence": "exact_seed10_one_level_no_water_record_chain_only",
        },
        {
            "domain": "connection_endpoint_cursor_precondition",
            "fields": {
                "0x4a5e73": "endpoint helper keyed by generator+0xf5c",
                "generator+0xf5c": "current endpoint/index cursor; stale in all current natural and forced Border Guard samples",
                "generator+0xf5c writer surface": "widened Ghidra endpoint-state scan still bounds direct writers to 0x4a5e73, 0x4adb72, and 0x4add76",
                "generator+0xd8/+0xdc": "index-keyed pointer vector searched before endpoint mutation",
                "generator+0xc8/+0xcc": "second index-keyed pointer vector required for success-path projection",
                "generator+0x1104/+0x1108": "byte-state vector marked and advanced after success",
                "runtime_corpus": "current corpus has live entries and failures, but zero success-path mutation hits",
            },
            "confidence": "static_contract_recovered_current_target_corpus_success_path_unhit_only",
        },
        {
            "domain": "cursor_writer_owner_frontier",
            "fields": {
                "0x4a5e73": "self cursor writer and endpoint helper; success path unhit in current corpus",
                "0x4adb72": "non-self cursor writer owned only by projection slot 0x540b00+0x08 through 0x49c019",
                "0x4add76": "non-self cursor writer owned only by 0x4adef7 under the projection slot chain",
                "projection_slot_runtime": "current one-level land corpus has zero projection/cleanup slot events or stops",
                "selected_projection_recycle": "sampled 0x540b14 projection objects are destroyed/freed/reused before ordinary final slot +0x08 dispatch",
            },
            "confidence": "current_one_level_land_target_mode_projection_slot_exclusion_only",
        },
        {
            "domain": "connection_region_generated_cell_writer",
            "fields": {
                "0x4a606b": "static generated-cell endpoint/region stamp helper",
                "0x4a6516/0x4a6548": "only recovered direct callers, both inside 0x4a61bc",
                "runtime_corpus": "current target corpus has breakpoint-only evidence and zero live hits",
            },
            "confidence": "static_contract_recovered_current_target_corpus_no_live_hit_only",
        },
    ]

    remaining_semantic_blockers = [
        {
            "id": "connection_relation_control_downstream_linkage",
            "reason": (
                "The +0x09 producer and exact seed-10 Border Guard fallback chain are recovered, "
                "0x4a5e73 is recovered as the cursor-keyed endpoint helper with no current "
                "success-path hits, the non-self +0xf5c writers are bound to the unhit "
                "projection/cleanup slot chain, and 0x4a606b has a recovered static contract "
                "with no live hit in the current target corpus. Relation/control linkage still "
                "needs broader map-mode/source-state proof that finds a source path that seeds "
                "generator+0xf5c outside those excluded writers before a successful 0x4a5e73 "
                "call, naturally reaches projection-slot dispatch, or excludes endpoint stamping "
                "for the supported one-level land scope."
            ),
        },
        {
            "id": "descriptor_type_human_labels",
            "reason": (
                "Numeric descriptor types are usable as counter indices, but their human object "
                "families are not globally named."
            ),
        },
        {
            "id": "global_semantic_scope",
            "reason": (
                "Descriptor/relation/generated-cell working names are exact-record scoped unless "
                "broader map-mode/source-state evidence proves the same semantics elsewhere."
            ),
        },
        {
            "id": "cleanup_uncommit_semantics",
            "reason": "The cleanup/uncommit state behind 0x4add76/0x4adef7 remains runtime-unrecovered.",
        },
    ]

    status = (
        "semantic_frontier_working_names_seed10_chain_cursor_source_and_4a606b_frontiers_recovered_broader_scope_pending"
        if all(invariants.values())
        else "semantic_frontier_inputs_incomplete"
    )

    return {
        "schema_id": "h3maped_semantic_frontier_summary_v1",
        "status": status,
        "scope": (
            "Working semantic names recovered from current Wine/Ghidra/Python evidence. These "
            "names are not authority for native behavior changes without the corresponding "
            "state/phase recovery."
        ),
        "inputs": {
            "connection_fields": str(args.connection_fields),
            "candidate_vtables": str(args.candidate_vtables),
            "exact_descriptor_relation": str(args.exact_descriptor_relation),
            "final_role_frontier": str(args.final_role_frontier),
            "border_guard_chain": str(args.border_guard_chain),
            "4a5e73_cursor_frontier": str(args.four_a5e73),
            "4a5e73_caller_gate_surface": str(args.four_a5e73_caller_gates),
            "cursor_writer_owner_frontier": str(args.cursor_owner),
            "cursor_source_frontier": str(args.cursor_source),
            "4a606b_reachability": str(args.four_a606b),
        },
        "invariants": invariants,
        "metrics": {
            "native_behavior_changed": False,
            "used_objdump": False,
            "overall_goal_complete": False,
            "recovered_working_name_domain_count": len(recovered_working_names),
            "remaining_semantic_blocker_count": len(remaining_semantic_blockers),
            "descriptor_types_seen": descriptor_types,
        },
        "recovered_working_names": recovered_working_names,
        "remaining_semantic_blockers": remaining_semantic_blockers,
        "source_backed_conclusion": (
            "The current evidence is no longer purely hex-level for several direct-RMG state "
            "surfaces: connection record bytes +0x08/+0x09/+0x0a, selected candidate record "
            "fields +0x00/+0x04/+0x08/+0x0c, descriptor projection flag/offset fields, "
            "relation descriptor-type counters, and selected GeneratedCell +0x20 roles now "
            "have source-backed working names. Connection byte +0x09 is recovered as the "
            "template connection Border Guard flag produced by 0x49f7c4. The exact seed-10 "
            "Border Guard downstream chain is recovered through stale-cursor endpoint misses, "
            "fallback materialization, 0x4a54a7 commit/projection state, object-vector survival, "
            "first 0x49e700 mutation set, and 0x4ac552 phase tail for two exact records. Broader "
            "0x4a5e73 is statically recovered as the cursor-keyed endpoint helper and has zero "
            "success-path mutation hits in the current corpus; all six static 0x4a5e73 callers "
            "are grouped by gate, with current runtime hits limited to stale-cursor 0x4a61bc "
            "entries and forced-failing 0x4a746b entries while 0x4a696b/0x4a6cf2 caller families "
            "remain unhit in the current corpus; the only non-self direct +0xf5c "
            "writers are bound to projection/cleanup slot methods that current one-level land "
            "evidence never dispatches; the cursor-source frontier now consumes a widened "
            "Ghidra endpoint-state scan that still finds no additional direct +0xf5c writer, "
            "consolidates that setup initializes +0xf58/+0x1104 but not +0xf5c, and proves "
            "sampled projection objects are destroyed/freed/reused before ordinary final dispatch; "
            "0x4a606b is statically "
            "recovered and has no live hit in the current target corpus. Broader "
            "relation/control linkage, global semantic labels, and broader scope remain "
            "explicit blockers."
        ),
        "remaining_gap": (
            "Recover broader relation/control downstream linkage outside the exact seed-10 chain, "
            "including any source path that seeds generator+0xf5c outside the currently excluded "
            "non-self writer chain before a successful 0x4a5e73 call and reaches 0x4a606b, a "
            "natural projection-slot dispatch in a broader supported state, or a source-backed "
            "exclusion for the supported one-level land scope, "
            "global descriptor type labels, broader map-mode semantic scope, and cleanup/uncommit "
            "semantics before native RMG behavior changes."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--connection-fields", type=Path, default=DEFAULT_CONNECTION_FIELDS)
    parser.add_argument("--candidate-vtables", type=Path, default=DEFAULT_CANDIDATE_VTABLES)
    parser.add_argument(
        "--exact-descriptor-relation",
        type=Path,
        default=DEFAULT_EXACT_DESCRIPTOR_RELATION,
    )
    parser.add_argument("--final-role-frontier", type=Path, default=DEFAULT_FINAL_ROLE_FRONTIER)
    parser.add_argument("--border-guard-chain", type=Path, default=DEFAULT_BORDER_GUARD_CHAIN)
    parser.add_argument("--four-a5e73", type=Path, default=DEFAULT_4A5E73)
    parser.add_argument(
        "--four-a5e73-caller-gates",
        type=Path,
        default=DEFAULT_4A5E73_CALLER_GATES,
    )
    parser.add_argument("--cursor-owner", type=Path, default=DEFAULT_CURSOR_OWNER)
    parser.add_argument("--cursor-source", type=Path, default=DEFAULT_CURSOR_SOURCE)
    parser.add_argument("--four-a606b", type=Path, default=DEFAULT_4A606B)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_SEMANTIC_FRONTIER status={summary['status']} out={args.out}")
    return (
        0
        if summary["status"]
        == "semantic_frontier_working_names_seed10_chain_cursor_source_and_4a606b_frontiers_recovered_broader_scope_pending"
        else 1
    )


if __name__ == "__main__":
    raise SystemExit(main())
