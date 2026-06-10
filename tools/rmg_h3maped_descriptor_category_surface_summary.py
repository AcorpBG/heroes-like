#!/usr/bin/env python3
"""Aggregate recovered H3MapEd descriptor/category surfaces.

This is a source-recovery checkpoint. It keeps three currently recovered
surfaces separate:

* 0x4a9f1c candidate record +0x04 type/category indices
* 0x4a54a7 committed descriptor +0x1c type/class counters
* selected candidate-container relation/control flags

The point is to prevent accidental semantic overreach. Numeric categories and
field roles are recovered where traces prove them; human object-kind names for
all categories are still not recovered.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any


DEFAULT_CANDIDATE_VTABLE = Path(
    ".artifacts/rmg_recovery/medium_4a9f1c_candidate_vtable_contract_summary_20260608.json"
)
DEFAULT_CANDIDATE_CURSOR_GATE = Path(
    ".artifacts/rmg_recovery/candidate_cursor_gate_frontier_summary_20260610.json"
)
DEFAULT_POST_COUNTER = Path(
    ".artifacts/rmg_recovery/medium_4a9f1c_post_counter_branch_summary_20260608.json"
)
DEFAULT_COUNTER_DECISION = Path(
    ".artifacts/rmg_recovery/medium_4a9f1c_counter_decision_summary_20260608.json"
)
DEFAULT_DESCRIPTOR_RELATION = Path(
    ".artifacts/rmg_recovery/medium_seed10_4a54a7_descriptor_relation_summary_20260608.json"
)
DEFAULT_RELATION_GLOB = (
    ".artifacts/rmg_recovery/"
    "medium_selected_candidate_relation_scan_20260608_medium_seed*_runtime/"
    "selected_candidate_relation_summary.json"
)
DEFAULT_OUT = Path(
    ".artifacts/rmg_recovery/medium_descriptor_category_surface_summary_20260608.json"
)


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def sorted_counter(counter: Counter[Any]) -> dict[str, int]:
    return {str(key): counter[key] for key in sorted(counter, key=lambda item: str(item))}


def sorted_set(values: set[Any]) -> list[Any]:
    return sorted(values, key=lambda item: str(item))


def summarize_4a9f1c_candidate_surface(vtable_summary: dict[str, Any]) -> dict[str, Any]:
    by_type: dict[int, dict[str, Any]] = {}
    grouped: dict[int, list[dict[str, Any]]] = defaultdict(list)
    for record in vtable_summary.get("selected_records", []):
        type_index = record.get("candidate_type")
        if type_index is None:
            continue
        grouped[int(type_index)].append(record)

    for type_index, records in sorted(grouped.items()):
        value_fields = [
            int(record["candidate_value_field"])
            for record in records
            if record.get("candidate_value_field") is not None
        ]
        selected_values = [
            int(record["selected_value_return"])
            for record in records
            if record.get("selected_value_return") is not None
        ]
        object_vtables = {record.get("selected_object_vtable") for record in records}
        candidate_vtables = {record.get("candidate_vtable") for record in records}
        by_type[type_index] = {
            "sample_count": len(records),
            "candidate_vtables": sorted_set(candidate_vtables),
            "selected_object_vtables": sorted_set(object_vtables),
            "candidate_create_functions": sorted_set(
                {record.get("candidate_create_function") for record in records}
            ),
            "candidate_score_functions": sorted_set(
                {record.get("candidate_score_function") for record in records}
            ),
            "caller_returns": sorted_counter(Counter(record.get("caller_return") for record in records)),
            "candidate_value_field_range": {
                "min": min(value_fields) if value_fields else None,
                "max": max(value_fields) if value_fields else None,
            },
            "selected_value_return_range": {
                "min": min(selected_values) if selected_values else None,
                "max": max(selected_values) if selected_values else None,
            },
            "projection_object_return_observed": any(
                vtable in {"0x00540b00", "0x00540b14"} for vtable in object_vtables
            ),
        }

    return {
        "surface": "0x4a9f1c candidate record +0x04",
        "meaning_recovered": (
            "candidate type/category index used by 0x4a9f1c counter checks, "
            "limit tables, candidate value filtering, and selected-create dispatch"
        ),
        "selected_create_return_cycles": vtable_summary.get("selected_create_return_cycles"),
        "complete_selected_create_cycles": vtable_summary.get("complete_selected_create_cycles"),
        "candidate_type_count": len(by_type),
        "candidate_types": {str(key): value for key, value in by_type.items()},
        "vtable_contracts_recovered": vtable_summary.get("recovered_contract", {}).get(
            "selected_vtable_contracts", {}
        ),
        "non_claim": "These numeric indices are not yet complete human object-kind names.",
    }


def summarize_candidate_cursor_gate_surface(
    cursor_gate: dict[str, Any], vtable_summary: dict[str, Any]
) -> dict[str, Any]:
    selected_by_gate = cursor_gate.get("selected_records_by_gate", {})
    contract_by_gate = cursor_gate.get("contract_by_gate", {})

    selected_type_by_vtable: dict[str, list[int]] = defaultdict(list)
    for record in vtable_summary.get("selected_records", []):
        vtable = record.get("candidate_vtable")
        type_index = record.get("candidate_type")
        if vtable is not None and type_index is not None:
            selected_type_by_vtable[str(vtable)].append(int(type_index))

    selected_f58 = selected_by_gate.get("generator+0xf58_and_0x10b4_gate", [])
    selected_f5c = selected_by_gate.get("generator+0xf5c_gate", [])
    contract_f5c = contract_by_gate.get("generator+0xf5c_gate", [])

    f5c_unselected_contracts = []
    for contract in contract_f5c:
        vtable = str(contract.get("candidate_vtable"))
        f5c_unselected_contracts.append(
            {
                **contract,
                "sampled_candidate_type_indices": sorted(selected_type_by_vtable.get(vtable, [])),
                "sampled_selected_create_count": len(selected_type_by_vtable.get(vtable, [])),
            }
        )

    return {
        "surface": "0x4a9f1c cursor-gated candidate scorer split",
        "meaning_recovered": (
            "selected candidate scorer contracts separate generator+0xf58/generator+0x10b4 "
            "projection gating from the only currently recovered generator+0xf5c-gated "
            "candidate scorer"
        ),
        "selected_f58_gated_projection_records": selected_f58,
        "selected_f5c_gated_records": selected_f5c,
        "f5c_gated_contracts_without_sampled_selected_type": f5c_unselected_contracts,
        "selected_f58_candidate_type_indices": sorted(
            {
                int(record["candidate_type"])
                for record in selected_f58
                if record.get("candidate_type") is not None
            }
        ),
        "non_claim": (
            "The 0x540ca0/0x49cd97 candidate is source-recovered as +0xf5c-gated, "
            "but no sampled selected-create return gives it a candidate+0x04 type index "
            "or downstream object semantics."
        ),
    }


def summarize_4a9f1c_counter_surface(
    counter_decision: dict[str, Any], post_counter: dict[str, Any]
) -> dict[str, Any]:
    by_type: dict[str, dict[str, Any]] = {}
    for record in counter_decision.get("by_type", []):
        by_type[str(record["type_index"])] = {
            "counter_check_sample_count": record.get("cycle_count"),
            "global_counter_range": record.get("global_counter_range"),
            "global_limit_range": record.get("global_limit_range"),
            "relation_counter_range": record.get("relation_counter_range"),
            "relation_limit_range": record.get("relation_limit_range"),
            "global_limit_rejects_by_values": record.get("global_limit_rejects_by_values"),
            "relation_limit_rejects_by_values": record.get("relation_limit_rejects_by_values"),
            "post_counter_loop_continuations": record.get("post_counter_loop_continuations"),
            "post_counter_paths": {},
        }
    for record in post_counter.get("type_path_counts", []):
        type_entry = by_type.setdefault(str(record["type_index"]), {"post_counter_paths": {}})
        type_entry.setdefault("post_counter_paths", {})[record["path_class"]] = record["count"]

    return {
        "surface": "0x4a9f1c counter and post-counter filters",
        "meaning_recovered": (
            "same-run sampled counter values and value-filter outcomes for candidate "
            "type/category indices before selected-create"
        ),
        "candidate_cycle_count": counter_decision.get("candidate_cycle_count"),
        "post_counter_candidate_cycle_count": post_counter.get("candidate_cycle_count"),
        "by_type": by_type,
        "value_score_ranges_by_path": post_counter.get("value_score_ranges_by_path", []),
        "non_claim": "The samples explain observed filter paths; they do not name every candidate type semantically.",
    }


def summarize_4a54a7_descriptor_surface(descriptor_relation: dict[str, Any]) -> dict[str, Any]:
    grouped: dict[int, list[dict[str, Any]]] = defaultdict(list)
    for invocation in descriptor_relation.get("invocations", []):
        descriptor = invocation.get("descriptor", {})
        type_index = descriptor.get("type_index_from_descriptor_plus_0x1c")
        if type_index is None:
            continue
        grouped[int(type_index)].append(invocation)

    by_type: dict[str, dict[str, Any]] = {}
    for type_index, invocations in sorted(grouped.items()):
        descriptors = [invocation.get("descriptor", {}) for invocation in invocations]
        offsets = {
            (
                descriptor.get("projection_offset_x_plus_0x2c"),
                descriptor.get("projection_offset_y_plus_0x30"),
            )
            for descriptor in descriptors
        }
        dimensions = {
            (
                descriptor.get("mask_width_plus_0x34"),
                descriptor.get("mask_height_plus_0x38"),
            )
            for descriptor in descriptors
        }
        by_type[str(type_index)] = {
            "commit_invocation_count": len(invocations),
            "descriptor_ids_or_class_words": sorted_set(
                {descriptor.get("id_or_class_word_0x00") for descriptor in descriptors}
            ),
            "projection_flag_values": sorted_set(
                {descriptor.get("projection_flag_plus_0x29") for descriptor in descriptors}
            ),
            "projection_offsets_x_y": [list(pair) for pair in sorted_set(offsets)],
            "mask_dimensions_w_h": [list(pair) for pair in sorted_set(dimensions)],
            "return_addresses": sorted_counter(
                Counter(invocation.get("return_address") for invocation in invocations)
            ),
            "source_owner_bytes": sorted_set(
                {
                    invocation.get("relation_counter", {}).get(
                        "source_owner_byte_from_cell_plus_0x20_byte2"
                    )
                    for invocation in invocations
                }
            ),
            "all_relation_counters_incremented_by_one": all(
                invocation.get("relation_counter", {}).get("counter_incremented_by_one")
                for invocation in invocations
            ),
            "all_source_coordinates_match_descriptor_offsets": all(
                invocation.get("source_cell", {}).get(
                    "coordinate_matches_descriptor_offset_source"
                )
                for invocation in invocations
            ),
        }

    return {
        "surface": "0x4a54a7 descriptor +0x1c commits",
        "meaning_recovered": (
            "descriptor type/class counter index used to increment generator+0x1110 "
            "and relation+0x44[type] after object footprint commit"
        ),
        "invocation_count": descriptor_relation.get("invocation_count"),
        "descriptor_type_counts": descriptor_relation.get("descriptor_type_counts"),
        "invariants": descriptor_relation.get("invariants", {}),
        "by_type": by_type,
        "field_roles": {
            "descriptor+0x29": "projection-enable byte for source-cell relation counter projection",
            "descriptor+0x2c": "source-cell x offset subtracted from object x",
            "descriptor+0x30": "source-cell y offset subtracted from object y",
            "descriptor+0x34": "descriptor mask width",
            "descriptor+0x38": "descriptor mask height",
            "relation+0x44 + descriptor_type*4": "per-relation descriptor-type occupancy counter",
        },
        "non_claim": (
            "This sampled commit surface proves counter mechanics and source-cell offsets; "
            "it does not name every descriptor type as a final map object category."
        ),
    }


def summarize_relation_control_surfaces(paths: list[Path]) -> dict[str, Any]:
    selected_runs = []
    total_records = 0
    border_guard_records = 0
    control_words = Counter()
    wide_flags = Counter()
    border_guard_flags = Counter()
    processed_flags = Counter()

    for path in paths:
        summary = load_json(path)
        run_total = 0
        run_border = 0
        run_control_words = Counter()
        for owner in summary.get("owners", []):
            for record in owner.get("records", []):
                run_total += 1
                total_records += 1
                control_word = record.get("control_dword")
                run_control_words[control_word] += 1
                control_words[control_word] += 1
                wide_flags[int(record.get("wide_flag_plus_08", 0))] += 1
                bg_flag = int(record.get("border_guard_flag_plus_09", 0))
                border_guard_flags[bg_flag] += 1
                processed_flags[int(record.get("processed_flag_plus_0a", 0))] += 1
                if bg_flag:
                    run_border += 1
                    border_guard_records += 1
        selected_runs.append(
            {
                "path": str(path),
                "status": summary.get("status"),
                "candidate_count": summary.get("candidate_count"),
                "selected_index": summary.get("selected_index"),
                "selected_candidate_pointer_from_vector": summary.get(
                    "selected_candidate_pointer_from_vector"
                ),
                "total_relation_record_count": run_total,
                "border_guard_relation_record_count": run_border,
                "control_dword_counts": sorted_counter(run_control_words),
            }
        )

    return {
        "surface": "selected candidate-container owner relation records",
        "meaning_recovered": (
            "relation-record control byte +0x09 is the template connection Border Guard flag; "
            "byte +0x08 is Wide and byte +0x0a is cleared/processed state in sampled records"
        ),
        "sampled_run_count": len(paths),
        "total_relation_record_count": total_records,
        "border_guard_relation_record_count": border_guard_records,
        "control_dword_counts": sorted_counter(control_words),
        "wide_flag_plus_08_counts": sorted_counter(wide_flags),
        "border_guard_flag_plus_09_counts": sorted_counter(border_guard_flags),
        "processed_flag_plus_0a_counts": sorted_counter(processed_flags),
        "selected_runs": selected_runs,
        "non_claim": (
            "This relation/control surface is not the same field as 0x4a9f1c candidate+0x04 "
            "or 0x4a54a7 descriptor+0x1c."
        ),
    }


def build_summary(args: argparse.Namespace) -> dict[str, Any]:
    vtable_summary = load_json(args.candidate_vtable)
    candidate_cursor_gate = load_json(args.candidate_cursor_gate)
    post_counter = load_json(args.post_counter)
    counter_decision = load_json(args.counter_decision)
    descriptor_relation = load_json(args.descriptor_relation)
    relation_paths = sorted(Path().glob(args.relation_glob))

    if not relation_paths:
        raise ValueError(f"no selected relation summaries matched {args.relation_glob}")

    recovered_surfaces = {
        "candidate_type_surface_4a9f1c": summarize_4a9f1c_candidate_surface(
            vtable_summary
        ),
        "candidate_cursor_gate_surface_4a9f1c": summarize_candidate_cursor_gate_surface(
            candidate_cursor_gate, vtable_summary
        ),
        "candidate_filter_surface_4a9f1c": summarize_4a9f1c_counter_surface(
            counter_decision, post_counter
        ),
        "descriptor_commit_surface_4a54a7": summarize_4a54a7_descriptor_surface(
            descriptor_relation
        ),
        "selected_relation_control_surface": summarize_relation_control_surfaces(
            relation_paths
        ),
    }
    invariants = {
        "candidate_vtable_contracts_passed": vtable_summary.get("status")
        == "passed_selected_candidate_vtable_contracts",
        "candidate_cursor_gate_frontier_passed": candidate_cursor_gate.get("status")
        == "candidate_cursor_gate_frontier_selected_path_f58_only_f5c_candidate_unselected",
        "f5c_gated_candidate_has_no_sampled_selected_type": all(
            row.get("sampled_selected_create_count") == 0
            for row in recovered_surfaces["candidate_cursor_gate_surface_4a9f1c"][
                "f5c_gated_contracts_without_sampled_selected_type"
            ]
        ),
        "sampled_f58_projection_has_type83": recovered_surfaces[
            "candidate_cursor_gate_surface_4a9f1c"
        ]["selected_f58_candidate_type_indices"]
        == [83],
        "descriptor_relation_surface_has_invariants": bool(
            recovered_surfaces["descriptor_commit_surface_4a54a7"]["invariants"]
        ),
        "relation_control_surface_has_border_guard_records": recovered_surfaces[
            "selected_relation_control_surface"
        ]["border_guard_relation_record_count"]
        > 0,
        "no_objdump_used": True,
        "no_native_behavior_change": True,
    }
    status = (
        "descriptor_category_surfaces_separated_candidate_cursor_gate_named"
        if all(invariants.values())
        else "descriptor_category_surfaces_incomplete"
    )

    return {
        "schema_id": "h3maped_descriptor_category_surface_summary_v1",
        "status": status,
        "native_behavior_changed": False,
        "inputs": {
            "candidate_vtable": str(args.candidate_vtable),
            "candidate_cursor_gate": str(args.candidate_cursor_gate),
            "post_counter": str(args.post_counter),
            "counter_decision": str(args.counter_decision),
            "descriptor_relation": str(args.descriptor_relation),
            "relation_summaries": [str(path) for path in relation_paths],
        },
        "invariants": invariants,
        "metrics": {
            "native_behavior_changed": False,
            "overall_goal_complete": False,
            "used_objdump": False,
            "sampled_candidate_type_count": recovered_surfaces[
                "candidate_type_surface_4a9f1c"
            ]["candidate_type_count"],
            "selected_f58_gated_candidate_count": candidate_cursor_gate.get("metrics", {}).get(
                "selected_f58_gated_candidate_count"
            ),
            "selected_f5c_gated_candidate_count": candidate_cursor_gate.get("metrics", {}).get(
                "selected_f5c_gated_candidate_count"
            ),
            "f5c_gated_contract_without_sampled_type_count": len(
                recovered_surfaces["candidate_cursor_gate_surface_4a9f1c"][
                    "f5c_gated_contracts_without_sampled_selected_type"
                ]
            ),
            "descriptor_commit_type_count": len(
                recovered_surfaces["descriptor_commit_surface_4a54a7"]["by_type"]
            ),
            "relation_control_sampled_run_count": recovered_surfaces[
                "selected_relation_control_surface"
            ]["sampled_run_count"],
        },
        "recovered_surfaces": recovered_surfaces,
        "source_backed_human_readable_conclusions": [
            (
                "0x4a9f1c candidate+0x04 is a candidate type/category counter index "
                "used by the selector; selected-create vtables and returned object "
                "families are recovered for sampled and adjacent vtable records."
            ),
            (
                "The sampled projection selected-create path has candidate type 83 and is "
                "gated by generator+0xf58, not generator+0xf5c."
            ),
            (
                "The only recovered generator+0xf5c-gated candidate contract is "
                "0x540ca0/0x49cd97, and current selected-create samples give it no "
                "candidate+0x04 type index or downstream object semantics."
            ),
            (
                "0x4a54a7 descriptor+0x1c is the committed descriptor type/class "
                "counter index for generator+0x1110 and relation+0x44[type]."
            ),
            (
                "relation-record byte +0x09 is the template connection Border Guard "
                "flag, byte +0x08 is Wide, and byte +0x0a is cleared in sampled "
                "builder output."
            ),
            (
                "These are separate surfaces. Treating them as one final object "
                "category enum would be an overclaim."
            ),
        ],
        "remaining_blockers": [
            (
                "Recover human semantic names for descriptor/candidate numeric type "
                "indices only where the source object/template mapping proves them."
            ),
            (
                "Recover a natural selected-create path for 0x540ca0/0x49cd97, or "
                "source-backed proof that supported one-level land cannot select that "
                "+0xf5c-gated candidate before endpoint stamping."
            ),
            (
                "Recover pointer-paired downstream consumer linkage for returned "
                "projection objects, especially 0x540b00/0x540b14 slot +0x08 into "
                "0x49c019/0x49c0a6."
            ),
            (
                "Recover a generation path that actually hits 0x4add76 cleanup/uncommit "
                "before porting replacement/uncommit behavior."
            ),
            (
                "Recover relation/control linkage from committed 0x4a54a7 projection "
                "records into later consumers."
            ),
        ],
        "explicit_non_claims": [
            "This report does not change native RMG behavior.",
            "This report does not make final-map density or parity claims.",
            "This report does not name every descriptor type semantically.",
            "This report does not collapse selected-candidate relation flags into object descriptor type indices.",
        ],
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate-vtable", type=Path, default=DEFAULT_CANDIDATE_VTABLE)
    parser.add_argument("--candidate-cursor-gate", type=Path, default=DEFAULT_CANDIDATE_CURSOR_GATE)
    parser.add_argument("--post-counter", type=Path, default=DEFAULT_POST_COUNTER)
    parser.add_argument("--counter-decision", type=Path, default=DEFAULT_COUNTER_DECISION)
    parser.add_argument("--descriptor-relation", type=Path, default=DEFAULT_DESCRIPTOR_RELATION)
    parser.add_argument("--relation-glob", default=DEFAULT_RELATION_GLOB)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = build_summary(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    relation_surface = summary["recovered_surfaces"]["selected_relation_control_surface"]
    print(
        "RMG_H3MAPED_DESCRIPTOR_CATEGORY_SURFACE_SUMMARY "
        f"status={summary['status']} "
        f"candidate_types={summary['recovered_surfaces']['candidate_type_surface_4a9f1c']['candidate_type_count']} "
        f"descriptor_types={len(summary['recovered_surfaces']['descriptor_commit_surface_4a54a7']['by_type'])} "
        f"relation_runs={relation_surface['sampled_run_count']} "
        f"border_guard_records={relation_surface['border_guard_relation_record_count']} "
        f"out={args.out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
