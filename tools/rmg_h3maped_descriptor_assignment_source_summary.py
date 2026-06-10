#!/usr/bin/env python3
"""Verify the descriptor +0x00 assignment/source boundary from Ghidra exports.

This is a narrow recovery checkpoint. It does not recover final descriptor
identity and it does not change native RMG behavior. Its purpose is to prove
from Wine/Ghidra-derived text exports that the ordinary object-record
constructor retains an already-built descriptor pointer, while the current
mixed descriptor +0x00 identity blocker lives upstream in descriptor
selection/source construction.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_PRODUCER_CONTEXT = ROOT / "descriptor_producer_context_summary_20260610.json"
DEFAULT_OUT = ROOT / "descriptor_assignment_source_summary_20260610.json"

DEFAULT_GHIDRA_FILES = {
    "object_record_constructor_0x49ba89": ROOT
    / "ghidra_selected_recycle_owner_dump_20260610"
    / "target_0049ba89_FUN_0049ba89.txt",
    "fallback_owner_0x4a5c07": ROOT
    / "ghidra_selected_recycle_owner_dump_20260610"
    / "caller_004a5c07_FUN_004a5c07.txt",
    "weighted_projection_owner_0x4a901a": ROOT
    / "ghidra_selected_recycle_owner_dump_20260610"
    / "caller_004a901a_FUN_004a901a.txt",
    "selected_mine_owner_0x4a9641": ROOT
    / "ghidra_49b76d_policy_helper_dump"
    / "caller_004a9641_FUN_004a9641.txt",
    "selected_resource_owner_0x4a9911": ROOT
    / "ghidra_42ccc6_42cc99_descriptor_predicate_dump"
    / "caller_004a9911_FUN_004a9911.txt",
    "selector_filter_0x4a9e40": ROOT
    / "ghidra_4a9f1c_reward_guard_object_selector_dump"
    / "target_004a9e40_FUN_004a9e40.txt",
    "source_handler_descriptor_resolver_0x4af785": ROOT
    / "ghidra_4af463_source_handler_init_dump"
    / "target_004af785_FUN_004af785.txt",
}


CHECKS: dict[str, list[dict[str, Any]]] = {
    "object_record_constructor_0x49ba89": [
        {
            "id": "reads_descriptor_pointer_argument",
            "marker": "0049ba89: MOV EAX,dword ptr [ESP + 0x4]",
            "meaning": "Loads the descriptor pointer argument supplied to the constructor.",
        },
        {
            "id": "stores_descriptor_pointer_on_record",
            "marker": "0049ba96: MOV dword ptr [ESI + 0x4],EAX",
            "meaning": "Stores the descriptor pointer at object-record +0x04.",
        },
        {
            "id": "increments_descriptor_refcount",
            "marker": "0049ba99: INC dword ptr [EAX + 0x8]",
            "meaning": "Increments descriptor +0x08 refcount on the supplied descriptor.",
        },
        {
            "id": "initializes_record_coordinate_x",
            "marker": "0049ba9c: OR dword ptr [ESI + 0x8],0xffffffff",
            "meaning": "Initializes object-record coordinate field +0x08 to -1.",
        },
        {
            "id": "initializes_record_coordinate_y",
            "marker": "0049baa0: OR dword ptr [ESI + 0xc],0xffffffff",
            "meaning": "Initializes object-record coordinate field +0x0c to -1.",
        },
        {
            "id": "initializes_record_coordinate_z",
            "marker": "0049baa4: OR dword ptr [ESI + 0x10],0xffffffff",
            "meaning": "Initializes object-record coordinate field +0x10 to -1.",
        },
    ],
    "fallback_owner_0x4a5c07": [
        {
            "id": "constructs_fallback_record_with_existing_descriptor",
            "marker": "004a5dd1: CALL 0x0049ba89",
            "meaning": "Fallback owner allocates an object record and passes an existing descriptor pointer into 0x49ba89.",
        },
        {
            "id": "sets_fallback_record_vtable",
            "marker": "004a5dd9: MOV dword ptr [ESI],0x540a88",
            "meaning": "After base construction, fallback owner installs its concrete object-record vtable.",
        },
    ],
    "weighted_projection_owner_0x4a901a": [
        {
            "id": "constructs_weighted_record_with_existing_descriptor",
            "marker": "004a92bb: CALL 0x0049ba89",
            "meaning": "Weighted/projection owner allocates an object record using an existing descriptor pointer.",
        },
        {
            "id": "dispatches_projection_callback",
            "marker": "004a9322: CALL dword ptr [EDX + 0x4]",
            "meaning": "The owner dispatches a slot +0x04 callback that reaches the sampled 0x4a54a7 commit lane.",
        },
    ],
    "selected_mine_owner_0x4a9641": [
        {
            "id": "dispatches_selected_object_callback",
            "marker": "004a98ed: CALL dword ptr [EDX + 0x4]",
            "meaning": "Selected-object owner dispatches the callback that returns at 0x4a98f0.",
        },
    ],
    "selected_resource_owner_0x4a9911": [
        {
            "id": "constructs_first_selected_record",
            "marker": "004a9a24: CALL 0x0049ba89",
            "meaning": "Selected-resource owner can construct a first object record from an existing descriptor pointer.",
        },
        {
            "id": "calls_descriptor_selector_filter",
            "marker": "004a9b05: CALL 0x004a9e40",
            "meaning": "Selected-resource owner calls 0x4a9e40 to select/filter a descriptor from candidate data.",
        },
        {
            "id": "constructs_second_selected_record",
            "marker": "004a9c16: CALL 0x0049ba89",
            "meaning": "Selected-resource owner can construct the record that is later dispatched through the callback.",
        },
        {
            "id": "dispatches_selected_resource_callback",
            "marker": "004a9c3c: CALL dword ptr [EDX + 0x4]",
            "meaning": "Selected-resource owner dispatches the callback that returns at 0x4a9c3f.",
        },
    ],
    "selector_filter_0x4a9e40": [
        {
            "id": "reads_bucket_vector_begin",
            "marker": "004a9e6f: MOV EAX,dword ptr [ESI + 0x38]",
            "meaning": "Descriptor selector reads a candidate/bucket vector begin pointer.",
        },
        {
            "id": "reads_bucket_vector_end",
            "marker": "004a9e76: MOV ECX,dword ptr [ESI + 0x3c]",
            "meaning": "Descriptor selector reads the matching candidate/bucket vector end pointer.",
        },
        {
            "id": "loads_candidate_descriptor_or_record",
            "marker": "004a9e82: MOV EAX,dword ptr [EAX + EBX*0x4]",
            "meaning": "Descriptor selector iterates existing vector members.",
        },
        {
            "id": "reads_selected_record_vtable_or_descriptor_owner",
            "marker": "004a9e88: MOV EAX,dword ptr [EAX]",
            "meaning": "Descriptor selector dereferences selected vector data for filtering.",
        },
        {
            "id": "filters_descriptor_field_0x20",
            "marker": "004a9e8a: MOV ECX,dword ptr [EAX + 0x20]",
            "meaning": "Descriptor selector filters on a descriptor/record field at +0x20.",
        },
        {
            "id": "filters_descriptor_field_0x24",
            "marker": "004a9e92: MOV ECX,dword ptr [EAX + 0x24]",
            "meaning": "Descriptor selector filters on a descriptor/record field at +0x24.",
        },
    ],
    "source_handler_descriptor_resolver_0x4af785": [
        {
            "id": "reads_source_object_record_field_0x20",
            "marker": "004af7a0: MOV EAX,dword ptr [ESI + 0x20]",
            "meaning": "Source-handler resolver reads object/source metadata before descriptor lookup.",
        },
        {
            "id": "reads_source_object_record_field_0x1c",
            "marker": "004af7a7: MOV EAX,dword ptr [ESI + 0x1c]",
            "meaning": "Source-handler resolver indexes source tables from object/source metadata.",
        },
        {
            "id": "reads_source_table_slot",
            "marker": "004af7b0: MOV EDI,dword ptr [EAX + ECX*0x1 + 0x8]",
            "meaning": "Source-handler resolver reads a table slot used to reach descriptor candidate data.",
        },
    ],
}


def load_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def evaluate_file(name: str, path: Path) -> dict[str, Any]:
    text = load_text(path)
    checks: list[dict[str, Any]] = []
    for check in CHECKS[name]:
        checks.append(
            {
                "id": check["id"],
                "marker": check["marker"],
                "present": check["marker"] in text,
                "meaning": check["meaning"],
            }
        )
    return {
        "id": name,
        "path": str(path),
        "all_required_markers_present": all(check["present"] for check in checks),
        "checks": checks,
    }


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    producer_context = load_json(args.producer_context)
    files = DEFAULT_GHIDRA_FILES.copy()
    files.update(args.ghidra_file_overrides)

    ghidra_checks = {
        name: evaluate_file(name, path)
        for name, path in files.items()
    }

    constructor_text = load_text(files["object_record_constructor_0x49ba89"])
    constructor_negative_checks = [
        {
            "id": "does_not_write_descriptor_plus_0x00",
            "present": "MOV dword ptr [EAX]" in constructor_text
            or "STORE (const, 0x1a1, 4) , (register, 0x0, 4)" in constructor_text,
            "meaning": (
                "No direct write to the supplied descriptor base pointer appears in the "
                "constructor export; the only descriptor-side mutation verified here is "
                "the refcount increment at descriptor +0x08."
            ),
            "expected_present": False,
        },
    ]

    producer_invariants = producer_context.get("invariants", {})
    producer_metrics = producer_context.get("metrics", {})
    invariants = {
        "producer_context_checkpoint_present": producer_context.get("status")
        == "descriptor_producer_contexts_named_assignment_paths_pending",
        "producer_context_has_no_native_behavior_change": producer_metrics.get("native_behavior_changed") is False,
        "producer_context_used_no_objdump": producer_metrics.get("used_objdump") is False
        and producer_invariants.get("no_objdump_used") is True,
        "all_ghidra_markers_present": all(
            item["all_required_markers_present"] for item in ghidra_checks.values()
        ),
        "object_record_constructor_is_descriptor_retainer": all(
            check["present"] for check in ghidra_checks["object_record_constructor_0x49ba89"]["checks"]
        )
        and not any(check["present"] for check in constructor_negative_checks),
    }
    status = (
        "descriptor_assignment_boundary_recovered_constructor_retains_descriptor_source_paths_pending"
        if all(invariants.values())
        else "descriptor_assignment_boundary_incomplete"
    )

    return {
        "schema_id": "h3maped_descriptor_assignment_source_summary_v1",
        "status": status,
        "scope": (
            "Narrow Ghidra-backed checkpoint for descriptor +0x00 assignment/source recovery. "
            "It verifies that 0x49ba89 constructs object records from existing descriptor "
            "pointers and moves the remaining descriptor +0x00 identity blocker upstream to "
            "descriptor source/selector construction paths."
        ),
        "inputs": {
            "producer_context": str(args.producer_context),
            "ghidra_files": {name: str(path) for name, path in files.items()},
        },
        "input_statuses": {
            "producer_context": producer_context.get("status"),
        },
        "invariants": invariants,
        "metrics": {
            "ghidra_file_count": len(ghidra_checks),
            "required_marker_count": sum(len(item["checks"]) for item in ghidra_checks.values()),
            "present_marker_count": sum(
                1 for item in ghidra_checks.values() for check in item["checks"] if check["present"]
            ),
            "native_behavior_changed": False,
            "used_objdump": False,
            "overall_goal_complete": False,
        },
        "ghidra_checks": ghidra_checks,
        "negative_checks": {
            "object_record_constructor_0x49ba89": constructor_negative_checks,
        },
        "source_backed_conclusion": (
            "0x49ba89 is not the descriptor +0x00 assignment site. It reads an existing "
            "descriptor pointer from the stack, stores it at object-record +0x04, increments "
            "descriptor +0x08, and initializes object-record coordinate fields. The sampled "
            "owners construct or dispatch records with those existing descriptor pointers; "
            "0x4a9e40 and 0x4af785 are upstream selector/resolver surfaces. The remaining "
            "work is to recover the static/data constructor or loader paths that populate "
            "descriptor records and to prove the selected descriptor source for mixed "
            "type 45/53/54/79 lanes before using descriptor +0x00 as final object identity."
        ),
        "remaining_blockers": [
            {
                "id": "descriptor_static_or_loader_constructor",
                "reason": (
                    "The current Ghidra evidence proves object-record construction retains "
                    "existing descriptor pointers, but it does not yet identify the static "
                    "catalog/data loader or constructor that writes descriptor +0x00 values."
                ),
            },
            {
                "id": "mixed_lane_selected_descriptor_sources",
                "reason": (
                    "Type 45/53/54/79 descriptor +0x00 values are mixed or class-word-like "
                    "in the current exact samples. Each lane still needs source-backed "
                    "descriptor selection evidence before native RMG can treat the word as "
                    "human object identity."
                ),
                "affected_contexts": [
                    "0x004a5e6c | 54",
                    "0x004a744a | 45",
                    "0x004a98f0 | 53",
                    "0x004a9c3f | 79",
                ],
            },
        ],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--producer-context", type=Path, default=DEFAULT_PRODUCER_CONTEXT)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    args.ghidra_file_overrides = {}

    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_DESCRIPTOR_ASSIGNMENT_SOURCE status={status} markers={present}/{total} out={out}".format(
            status=summary["status"],
            present=summary["metrics"]["present_marker_count"],
            total=summary["metrics"]["required_marker_count"],
            out=args.out,
        )
    )


if __name__ == "__main__":
    main()
