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

    invariants = {
        "no_native_behavior_change": (
            connection.get("invariants", {}).get("no_native_behavior_change") is True
            and candidate.get("native_behavior_changed") is False
            and exact_descriptor.get("native_behavior_changed") is False
            and final_role.get("native_behavior_changed") is False
        ),
        "no_objdump_used": True,
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
            "confidence": "consumer_side_working_names",
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
    ]

    remaining_semantic_blockers = [
        {
            "id": "connection_record_plus_09_producer",
            "reason": (
                "The consumer-side meaning of +0x09 is recovered as endpoint_stamping_enabled, "
                "but its producer or a nonzero live sample is still unrecovered."
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
        "semantic_frontier_working_names_recovered_remaining_producers_pending"
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
            "have source-backed working names. Producer paths and global semantic labels remain "
            "explicit blockers."
        ),
        "remaining_gap": (
            "Recover the +0x09 producer or a nonzero endpoint-stamping sample, global descriptor "
            "type labels, broader map-mode semantic scope, and cleanup/uncommit semantics before "
            "native RMG behavior changes."
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
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_SEMANTIC_FRONTIER status={summary['status']} out={args.out}")
    return 0 if summary["status"] == "semantic_frontier_working_names_recovered_remaining_producers_pending" else 1


if __name__ == "__main__":
    raise SystemExit(main())
