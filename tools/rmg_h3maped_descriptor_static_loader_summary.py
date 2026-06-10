#!/usr/bin/env python3
"""Verify the descriptor static/stream loader field-writer surface.

This is a narrow H3MapEd RMG recovery checkpoint. It proves from existing
Ghidra exports that 0x4903e8 is a descriptor field builder/writer reached by
the objects.txt row loader and the objtmplt/source stream loader. It does not
claim final selected object identity for mixed lanes 45/53/54/79.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_ASSIGNMENT = ROOT / "descriptor_assignment_source_summary_20260610.json"
DEFAULT_PRODUCER_CONTEXT = ROOT / "descriptor_producer_context_summary_20260610.json"
DEFAULT_OUT = ROOT / "descriptor_static_loader_summary_20260610.json"

DEFAULT_GHIDRA_FILES = {
    "descriptor_field_builder_0x4903e8": ROOT
    / "ghidra_source_record_copy_helpers_dump_20260610"
    / "caller_004903e8_FUN_004903e8.txt",
    "objects_txt_row_loader_owner_0x4907c9": ROOT
    / "ghidra_source_record_copy_helpers_dump_20260610"
    / "caller_004907c9_FUN_004907c9.txt",
    "objtmplt_or_source_stream_owner_0x490a11": ROOT
    / "ghidra_source_record_copy_helpers_dump_20260610"
    / "caller_00490a11_FUN_00490a11.txt",
    "object_table_loader_0x490c4c": ROOT
    / "ghidra_object_table_loader_dump_20260610"
    / "target_00490c4c_FUN_00490c4c.txt",
}


CHECKS: dict[str, list[dict[str, Any]]] = {
    "descriptor_field_builder_0x4903e8": [
        {
            "id": "destination_descriptor_object_in_ecx",
            "marker": "004903f7: MOV EBX,ECX",
            "meaning": "Captures the destination descriptor/object pointer in EBX.",
        },
        {
            "id": "reads_first_builder_input",
            "marker": "0049041a: CALL 0x00491eed",
            "meaning": "Calls the first source/input helper before writing descriptor +0x00.",
        },
        {
            "id": "writes_descriptor_word_plus_0x00",
            "marker": "0049041f: MOV dword ptr [EBX],EAX",
            "meaning": "Writes the descriptor/object base word at +0x00.",
        },
        {
            "id": "initializes_mask_work_record",
            "marker": "00490433: CALL 0x0049060f",
            "meaning": "Initializes the local mask/work record used while filling descriptor fields.",
        },
        {
            "id": "copies_or_expands_source_mask_payload",
            "marker": "0049043f: CALL 0x004915a6",
            "meaning": "Copies or expands source mask payload before descriptor mask writes.",
        },
        {
            "id": "writes_first_mask_word",
            "marker": "0049054d: MOV dword ptr [ESI],EAX",
            "meaning": "Writes the first dword of a descriptor mask/payload pair.",
        },
        {
            "id": "writes_second_mask_word",
            "marker": "00490553: MOV dword ptr [ESI + 0x4],EAX",
            "meaning": "Writes the second dword of a descriptor mask/payload pair.",
        },
        {
            "id": "reads_first_extent_or_policy_value",
            "marker": "00490588: CALL 0x00491472",
            "meaning": "Reads/converts one late source value used for descriptor policy fields.",
        },
        {
            "id": "reads_second_extent_or_policy_value",
            "marker": "004905a0: CALL 0x00491472",
            "meaning": "Reads/converts a second late source value used for descriptor policy fields.",
        },
        {
            "id": "writes_descriptor_plus_0x34",
            "marker": "004905cd: MOV dword ptr [EBX + 0x34],ECX",
            "meaning": "Writes descriptor field +0x34, already known as width/extent in later placement helpers.",
        },
        {
            "id": "writes_descriptor_plus_0x38",
            "marker": "004905d7: MOV dword ptr [EBX + 0x38],ECX",
            "meaning": "Writes descriptor field +0x38, already known as height/extent in later placement helpers.",
        },
        {
            "id": "writes_descriptor_plus_0x3c",
            "marker": "004905e1: MOV dword ptr [EBX + 0x3c],EDX",
            "meaning": "Writes descriptor bitset/policy field +0x3c.",
        },
        {
            "id": "writes_descriptor_plus_0x40",
            "marker": "004905e8: MOV dword ptr [EBX + 0x40],ECX",
            "meaning": "Writes descriptor field +0x40.",
        },
        {
            "id": "writes_descriptor_plus_0x44",
            "marker": "004905f4: MOV dword ptr [EBX + 0x44],EDX",
            "meaning": "Writes descriptor field +0x44.",
        },
    ],
    "objects_txt_row_loader_owner_0x4907c9": [
        {
            "id": "reads_row_blob_or_name",
            "marker": "00490832: CALL 0x00491fa1",
            "meaning": "Consumes a row/source field before descriptor construction.",
        },
        {
            "id": "reads_first_90f3f_field",
            "marker": "0049083a: CALL 0x00490f3f",
            "meaning": "Reads one row/source field used by the 0x4903e8 input frame.",
        },
        {
            "id": "reads_second_90f3f_field",
            "marker": "00490842: CALL 0x00490f3f",
            "meaning": "Reads a second row/source field used by the 0x4903e8 input frame.",
        },
        {
            "id": "reads_first_91136_field",
            "marker": "0049084a: CALL 0x00491136",
            "meaning": "Reads one row/source field used by the 0x4903e8 input frame.",
        },
        {
            "id": "reads_second_91136_field",
            "marker": "00490852: CALL 0x00491136",
            "meaning": "Reads a second row/source field used by the 0x4903e8 input frame.",
        },
        {
            "id": "reads_first_2bc12_field",
            "marker": "0049085b: CALL 0x0042bc12",
            "meaning": "Reads one row/source scalar used before descriptor construction.",
        },
        {
            "id": "reads_second_2bc12_field",
            "marker": "00490862: CALL 0x0042bc12",
            "meaning": "Reads a second row/source scalar used before descriptor construction.",
        },
        {
            "id": "reads_third_2bc12_field",
            "marker": "00490869: CALL 0x0042bc12",
            "meaning": "Reads a third row/source scalar used before descriptor construction.",
        },
        {
            "id": "reads_fourth_2bc12_field",
            "marker": "00490870: CALL 0x0042bc12",
            "meaning": "Reads a fourth row/source scalar used before descriptor construction.",
        },
        {
            "id": "calls_descriptor_field_builder",
            "marker": "0049089e: CALL 0x004903e8",
            "meaning": "Calls 0x4903e8 after preparing the row/source input frame.",
        },
        {
            "id": "consumes_descriptor_plus_0x3c",
            "marker": "004908a8: MOV EAX,dword ptr [ESI + 0x3c]",
            "meaning": "Immediately consumes 0x4903e8 output field +0x3c.",
        },
        {
            "id": "consumes_descriptor_plus_0x40",
            "marker": "004908ae: MOV EAX,dword ptr [ESI + 0x40]",
            "meaning": "Immediately consumes 0x4903e8 output field +0x40.",
        },
    ],
    "objtmplt_or_source_stream_owner_0x490a11": [
        {
            "id": "reads_length_prefixed_blob",
            "marker": "00490a61: CALL 0x004190cb",
            "meaning": "Reads/copies a length-prefixed stream blob before descriptor construction.",
        },
        {
            "id": "reads_first_9213a_field",
            "marker": "00490a6b: CALL 0x0049213a",
            "meaning": "Reads one stream field used by the 0x4903e8 input frame.",
        },
        {
            "id": "reads_second_9213a_field",
            "marker": "00490a75: CALL 0x0049213a",
            "meaning": "Reads a second stream field used by the 0x4903e8 input frame.",
        },
        {
            "id": "reads_first_bitset_container",
            "marker": "00490a7f: CALL 0x0043bb1b",
            "meaning": "Reads/populates one bitset/range container before descriptor construction.",
        },
        {
            "id": "reads_second_bitset_container",
            "marker": "00490a89: CALL 0x0043bb1b",
            "meaning": "Reads/populates a second bitset/range container before descriptor construction.",
        },
        {
            "id": "reads_first_dword",
            "marker": "00490aa3: CALL 0x00407675",
            "meaning": "Reads one guarded dword before descriptor construction.",
        },
        {
            "id": "reads_second_dword",
            "marker": "00490aaa: CALL 0x00407675",
            "meaning": "Reads a second guarded dword before descriptor construction.",
        },
        {
            "id": "reads_first_byte",
            "marker": "00490ab1: CALL 0x0040763d",
            "meaning": "Reads one guarded byte before descriptor construction.",
        },
        {
            "id": "reads_second_byte",
            "marker": "00490ab8: CALL 0x0040763d",
            "meaning": "Reads a second guarded byte before descriptor construction.",
        },
        {
            "id": "reads_triple_or_selector_record",
            "marker": "00490ac3: CALL 0x00438937",
            "meaning": "Reads/populates one nested stream record before descriptor construction.",
        },
        {
            "id": "calls_descriptor_field_builder",
            "marker": "00490af1: CALL 0x004903e8",
            "meaning": "Calls 0x4903e8 after preparing the source-stream input frame.",
        },
        {
            "id": "passes_descriptor_plus_0x3c",
            "marker": "00490afc: LEA ECX,[ESI + 0x3c]",
            "meaning": "Immediately passes 0x4903e8 output field +0x3c to follow-up processing.",
        },
    ],
    "object_table_loader_0x490c4c": [
        {
            "id": "objects_txt_row_loader_call",
            "marker": "00490cea: CALL 0x004907c9",
            "meaning": "The recovered object table loader calls the 0x4907c9 row owner.",
        },
    ],
}


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def load_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def evaluate_file(name: str, path: Path) -> dict[str, Any]:
    text = load_text(path)
    checks = []
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
    assignment = load_json(args.assignment)
    producer_context = load_json(args.producer_context)
    files = DEFAULT_GHIDRA_FILES.copy()
    files.update(args.ghidra_file_overrides)
    ghidra_checks = {name: evaluate_file(name, path) for name, path in files.items()}

    invariants = {
        "assignment_boundary_checkpoint_present": assignment.get("status")
        == "descriptor_assignment_boundary_recovered_constructor_retains_descriptor_source_paths_pending",
        "producer_context_checkpoint_present": producer_context.get("status")
        == "descriptor_producer_contexts_named_assignment_paths_pending",
        "all_ghidra_markers_present": all(
            item["all_required_markers_present"] for item in ghidra_checks.values()
        ),
        "descriptor_plus_0x00_writer_named": any(
            check["id"] == "writes_descriptor_word_plus_0x00" and check["present"]
            for check in ghidra_checks["descriptor_field_builder_0x4903e8"]["checks"]
        ),
        "both_known_loader_owners_call_builder": all(
            any(
                check["id"] == "calls_descriptor_field_builder" and check["present"]
                for check in ghidra_checks[name]["checks"]
            )
            for name in [
                "objects_txt_row_loader_owner_0x4907c9",
                "objtmplt_or_source_stream_owner_0x490a11",
            ]
        ),
        "native_behavior_unchanged": True,
        "no_objdump_used": True,
    }
    status = (
        "descriptor_static_loader_field_writer_recovered_selected_source_mapping_pending"
        if all(invariants.values())
        else "descriptor_static_loader_field_writer_incomplete"
    )

    return {
        "schema_id": "h3maped_descriptor_static_loader_summary_v1",
        "status": status,
        "scope": (
            "Ghidra/Python checkpoint for the descriptor static/stream loader surface. "
            "It verifies that 0x4903e8 writes descriptor fields and is called by the "
            "known objects.txt row owner and source-stream owner. It does not prove final "
            "selected descriptor identity for mixed type 45/53/54/79 lanes."
        ),
        "inputs": {
            "assignment": str(args.assignment),
            "producer_context": str(args.producer_context),
            "ghidra_files": {name: str(path) for name, path in files.items()},
        },
        "input_statuses": {
            "assignment": assignment.get("status"),
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
        "source_backed_conclusion": (
            "0x4903e8 is now source-backed as the descriptor field builder/writer candidate: "
            "it receives the destination object in ECX/EBX, writes descriptor +0x00, writes "
            "mask/policy payload words, and writes descriptor fields +0x34, +0x38, +0x3c, "
            "+0x40, and +0x44. 0x4907c9 reaches it from the objects.txt row-loader path, "
            "and 0x490a11 reaches it from the source/objtmplt-style stream path. This moves "
            "the blocker from an unnamed static/data constructor to a concrete field-writer "
            "surface, but final selected mixed-lane identity is still pending."
        ),
        "remaining_blockers": [
            {
                "id": "descriptor_4903e8_input_field_semantics",
                "reason": (
                    "The descriptor field writer and owners are named, but the exact human "
                    "meaning of each input field prepared by 0x4907c9 and 0x490a11 still "
                    "needs source/input mapping."
                ),
            },
            {
                "id": "mixed_lane_selected_descriptor_sources",
                "reason": (
                    "Type 45/53/54/79 selected descriptor samples still need live pointer "
                    "linkage to specific 0x4903e8-built descriptors and proof of whether "
                    "descriptor +0x00 is a row id, class word, or other source value per lane."
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
    parser.add_argument("--assignment", type=Path, default=DEFAULT_ASSIGNMENT)
    parser.add_argument("--producer-context", type=Path, default=DEFAULT_PRODUCER_CONTEXT)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    args.ghidra_file_overrides = {}

    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_DESCRIPTOR_STATIC_LOADER status={status} markers={present}/{total} out={out}".format(
            status=summary["status"],
            present=summary["metrics"]["present_marker_count"],
            total=summary["metrics"]["required_marker_count"],
            out=args.out,
        )
    )


if __name__ == "__main__":
    main()
