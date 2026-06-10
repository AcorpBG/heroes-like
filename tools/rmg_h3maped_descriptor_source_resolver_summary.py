#!/usr/bin/env python3
"""Verify the descriptor source resolver boundary from Ghidra exports.

This is a recovery checkpoint, not a native RMG behavior change. It records
what the Ghidra dump proves about selector/resolver/initializer functions
around descriptor wrappers and keeps the remaining source-catalog identity gap
explicit.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_DUMP = ROOT / "ghidra_descriptor_source_resolver_dump_20260610"
DEFAULT_ASSIGNMENT = ROOT / "descriptor_assignment_source_summary_20260610.json"
DEFAULT_OUT = ROOT / "descriptor_source_resolver_summary_20260610.json"


FILES = {
    "descriptor_wrapper_initializer_0x49db76": "target_0049db76_FUN_0049db76.txt",
    "descriptor_source_bucket_builder_0x49da08": "target_0049da08_FUN_0049da08.txt",
    "source_record_descriptor_resolver_0x4af785": "target_004af785_FUN_004af785.txt",
    "source_row_mode_mask_selector_0x4af89f": "target_004af89f_FUN_004af89f.txt",
    "candidate_descriptor_selector_0x4a9e40": "target_004a9e40_FUN_004a9e40.txt",
}


CHECKS: dict[str, list[dict[str, str]]] = {
    "descriptor_wrapper_initializer_0x49db76": [
        {
            "id": "reads_source_record_argument",
            "marker": "0049db79: MOV EDX,dword ptr [EBP + 0x8]",
            "meaning": "The initializer receives the source/copy record pointer as its only stack argument.",
        },
        {
            "id": "copies_low_source_record_byte_to_wrapper_0x14",
            "marker": "0049db7e: MOV CL,byte ptr [EBP + 0xb]",
            "meaning": "The initializer derives wrapper +0x14 from the low byte of the source record pointer argument.",
        },
        {
            "id": "writes_wrapper_0x14",
            "marker": "0049db81: MOV byte ptr [EAX + 0x14],CL",
            "meaning": "The wrapper stores that byte at +0x14.",
        },
        {
            "id": "zeros_wrapper_state_0x18",
            "marker": "0049db86: MOV dword ptr [EAX + 0x18],ECX",
            "meaning": "The wrapper initializes state/counter field +0x18 to zero.",
        },
        {
            "id": "zeros_wrapper_state_0x1c",
            "marker": "0049db89: MOV dword ptr [EAX + 0x1c],ECX",
            "meaning": "The wrapper initializes state/counter field +0x1c to zero.",
        },
        {
            "id": "zeros_wrapper_state_0x20",
            "marker": "0049db8c: MOV dword ptr [EAX + 0x20],ECX",
            "meaning": "The wrapper initializes state/counter field +0x20 to zero.",
        },
        {
            "id": "sets_wrapper_0x04_to_negative_one",
            "marker": "0049db8f: OR dword ptr [EAX + 0x4],0xffffffff",
            "meaning": "The wrapper initializes +0x04 to -1 before later resolver code may overwrite it.",
        },
        {
            "id": "stores_source_record_pointer_at_wrapper_0x00",
            "marker": "0049db93: MOV dword ptr [EAX],EDX",
            "meaning": "Wrapper +0x00 is the copied/source record pointer, not a final human object-kind label.",
        },
        {
            "id": "zeros_wrapper_0x10",
            "marker": "0049db95: MOV dword ptr [EAX + 0x10],ECX",
            "meaning": "Wrapper +0x10 starts at zero and can be overwritten by resolver metadata.",
        },
        {
            "id": "zeros_wrapper_0x08",
            "marker": "0049db98: MOV dword ptr [EAX + 0x8],ECX",
            "meaning": "Wrapper +0x08 starts at zero.",
        },
        {
            "id": "zeros_wrapper_0x0c",
            "marker": "0049db9b: MOV dword ptr [EAX + 0xc],ECX",
            "meaning": "Wrapper +0x0c starts at zero.",
        },
        {
            "id": "zeros_wrapper_0xe4",
            "marker": "0049db9e: MOV byte ptr [EAX + 0xe4],CL",
            "meaning": "Wrapper byte +0xe4 starts at zero.",
        },
    ],
    "descriptor_source_bucket_builder_0x49da08": [
        {
            "id": "initializes_descriptor_source_vector",
            "marker": "0049da1f: LEA ECX,[ESI + 0x24]",
            "meaning": "The builder initializes/uses the source vector rooted at owner +0x24.",
        },
        {
            "id": "walks_0x4c_source_records",
            "marker": "0049dadd: ADD EBX,0x4c",
            "meaning": "The builder walks 0x4c-byte source records.",
        },
        {
            "id": "allocates_0xe8_wrapper",
            "marker": "0049da8e: MOV EAX,0xe8",
            "meaning": "The builder allocates the same 0xe8 descriptor-wrapper object.",
        },
        {
            "id": "calls_wrapper_initializer",
            "marker": "0049dab2: CALL 0x0049db76",
            "meaning": "The builder initializes wrappers with 0x49db76.",
        },
        {
            "id": "reads_global_descriptor_table",
            "marker": "0049dabe: MOV EAX,[0x0057c648]",
            "meaning": "The builder resolves a table through global 0x57c648.",
        },
        {
            "id": "appends_wrapper_to_type_bucket",
            "marker": "0049dad5: CALL 0x0040bb26",
            "meaning": "The builder appends the wrapper into a per-type/source bucket vector.",
        },
    ],
    "source_record_descriptor_resolver_0x4af785": [
        {
            "id": "reads_global_descriptor_table",
            "marker": "004af799: MOV ECX,dword ptr [0x0057c648]",
            "meaning": "The resolver uses the global descriptor/source table pointer.",
        },
        {
            "id": "reads_source_field_0x20",
            "marker": "004af7a0: MOV EAX,dword ptr [ESI + 0x20]",
            "meaning": "The resolver keeps source record +0x20 as matching metadata.",
        },
        {
            "id": "reads_source_field_0x1c",
            "marker": "004af7a7: MOV EAX,dword ptr [ESI + 0x1c]",
            "meaning": "The resolver indexes source table lanes from source record +0x1c.",
        },
        {
            "id": "reads_table_slot_for_source_lane",
            "marker": "004af7b0: MOV EDI,dword ptr [EAX + ECX*0x1 + 0x8]",
            "meaning": "The resolver reads a table slot that chooses the per-type bucket lane.",
        },
        {
            "id": "calls_row_mode_mask_selector",
            "marker": "004af7b4: CALL 0x004af89f",
            "meaning": "The resolver converts the source mask into a row/mode selector.",
        },
        {
            "id": "scans_bucket_vector_begin",
            "marker": "004af7c6: MOV EAX,dword ptr [EBX + 0x38]",
            "meaning": "The resolver scans an existing bucket vector begin pointer.",
        },
        {
            "id": "scans_bucket_vector_end",
            "marker": "004af7cd: MOV ECX,dword ptr [EBX + 0x3c]",
            "meaning": "The resolver scans to the matching bucket vector end pointer.",
        },
        {
            "id": "checks_existing_wrapper_lane",
            "marker": "004af7e3: CMP dword ptr [EDI + 0x4],EAX",
            "meaning": "Existing wrappers are matched by lane/table metadata at +0x04.",
        },
        {
            "id": "checks_existing_source_metadata",
            "marker": "004af7ed: CMP dword ptr [EAX + 0x20],ECX",
            "meaning": "Existing wrappers are also matched against source record metadata +0x20.",
        },
        {
            "id": "allocates_source_record_copy",
            "marker": "004af811: PUSH 0x4c",
            "meaning": "When no existing wrapper matches, the resolver allocates a 0x4c source-record copy.",
        },
        {
            "id": "copies_source_record",
            "marker": "004af822: MOVSD.REP ES:EDI,ESI",
            "meaning": "The new 0x4c record is copied from the source record.",
        },
        {
            "id": "allocates_descriptor_wrapper",
            "marker": "004af82d: PUSH 0xe8",
            "meaning": "The resolver allocates a 0xe8 descriptor wrapper.",
        },
        {
            "id": "calls_wrapper_initializer",
            "marker": "004af848: CALL 0x0049db76",
            "meaning": "The resolver initializes the wrapper from the copied 0x4c source record.",
        },
        {
            "id": "appends_source_pair_to_generator_edc",
            "marker": "004af85f: LEA ECX,[EAX + 0xedc]",
            "meaning": "The resolver appends a source-pair entry to generator +0xedc.",
        },
        {
            "id": "overwrites_wrapper_0x04_with_lane_metadata",
            "marker": "004af870: MOV dword ptr [EAX + 0x4],ECX",
            "meaning": "After initialization, resolver metadata overwrites wrapper +0x04.",
        },
        {
            "id": "overwrites_wrapper_0x10_with_existing_slot_metadata",
            "marker": "004af879: MOV dword ptr [EAX + 0x10],ECX",
            "meaning": "Resolver metadata can also overwrite wrapper +0x10.",
        },
        {
            "id": "appends_wrapper_to_bucket",
            "marker": "004af883: CALL 0x0040bb26",
            "meaning": "The new wrapper is appended to the selected bucket vector.",
        },
    ],
    "source_row_mode_mask_selector_0x4af89f": [
        {
            "id": "starts_at_source_mask_0x18",
            "marker": "004af8a7: LEA EDI,[EAX + 0x18]",
            "meaning": "The selector scans the source record mask words starting at +0x18.",
        },
        {
            "id": "clears_aux_vector_when_index_reaches_10",
            "marker": "004af8b1: CALL 0x00401b93",
            "meaning": "If the starting index is already outside the 0..9 lane range, it clears the vector helper surface.",
        },
        {
            "id": "builds_bit_for_current_lane",
            "marker": "004af8be: SHL EAX,CL",
            "meaning": "The selector builds a bit mask for the current lane.",
        },
        {
            "id": "tests_mask_words",
            "marker": "004af8c5: TEST dword ptr [EDI + ECX*0x4],EAX",
            "meaning": "The selector finds the first source lane whose mask bit is present.",
        },
        {
            "id": "returns_lane_index",
            "marker": "004af8d0: MOV EAX,ESI",
            "meaning": "The function returns the selected lane/index.",
        },
    ],
    "candidate_descriptor_selector_0x4a9e40": [
        {
            "id": "selects_type_bucket",
            "marker": "004a9e66: SHL EAX,0x4",
            "meaning": "The selector multiplies the requested type by 16 to locate a bucket.",
        },
        {
            "id": "reads_bucket_begin",
            "marker": "004a9e6f: MOV EAX,dword ptr [ESI + 0x38]",
            "meaning": "The selector reads the bucket vector begin pointer.",
        },
        {
            "id": "reads_bucket_end",
            "marker": "004a9e76: MOV ECX,dword ptr [ESI + 0x3c]",
            "meaning": "The selector reads the bucket vector end pointer.",
        },
        {
            "id": "loads_candidate_wrapper",
            "marker": "004a9e82: MOV EAX,dword ptr [EAX + EBX*0x4]",
            "meaning": "The selector iterates existing wrapper entries.",
        },
        {
            "id": "dereferences_wrapper_source_record",
            "marker": "004a9e88: MOV EAX,dword ptr [EAX]",
            "meaning": "Candidate filtering is against the source record behind the wrapper.",
        },
        {
            "id": "filters_source_field_0x20",
            "marker": "004a9e8a: MOV ECX,dword ptr [EAX + 0x20]",
            "meaning": "The selector filters source record metadata field +0x20.",
        },
        {
            "id": "filters_source_field_0x24",
            "marker": "004a9e92: MOV ECX,dword ptr [EAX + 0x24]",
            "meaning": "The selector filters source record metadata field +0x24.",
        },
        {
            "id": "tests_source_mask_for_requested_lane",
            "marker": "004a9ec0: TEST dword ptr [EDI + ECX*0x4],EAX",
            "meaning": "The selector uses the source record mask words to filter candidate compatibility.",
        },
        {
            "id": "appends_passing_candidate",
            "marker": "004a9ed4: CALL 0x0040bb26",
            "meaning": "Passing wrappers are appended to a local candidate vector.",
        },
        {
            "id": "rolls_rng_for_candidate_index",
            "marker": "004a9ef1: CALL 0x004e7276",
            "meaning": "The selector chooses one passing candidate by RNG modulo candidate count.",
        },
        {
            "id": "returns_selected_candidate",
            "marker": "004a9efa: MOV ESI,dword ptr [ESI + EDX*0x4]",
            "meaning": "The selector returns the selected wrapper pointer.",
        },
    ],
}


def load_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


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
    files = {name: args.dump / filename for name, filename in FILES.items()}
    ghidra_checks = {name: evaluate_file(name, path) for name, path in files.items()}

    invariants = {
        "assignment_checkpoint_present": assignment.get("status")
        == "descriptor_assignment_boundary_recovered_constructor_retains_descriptor_source_paths_pending",
        "assignment_checkpoint_used_no_objdump": assignment.get("metrics", {}).get("used_objdump") is False,
        "all_ghidra_markers_present": all(item["all_required_markers_present"] for item in ghidra_checks.values()),
        "wrapper_initializer_recovered": ghidra_checks[
            "descriptor_wrapper_initializer_0x49db76"
        ]["all_required_markers_present"],
        "source_resolver_recovered": ghidra_checks[
            "source_record_descriptor_resolver_0x4af785"
        ]["all_required_markers_present"],
        "selector_filter_recovered": ghidra_checks[
            "candidate_descriptor_selector_0x4a9e40"
        ]["all_required_markers_present"],
    }
    status = (
        "descriptor_source_resolver_boundary_recovered_source_catalog_identity_pending"
        if all(invariants.values())
        else "descriptor_source_resolver_boundary_incomplete"
    )

    return {
        "schema_id": "h3maped_descriptor_source_resolver_summary_v1",
        "status": status,
        "scope": (
            "Ghidra-backed descriptor source resolver checkpoint for the 0x49da08, "
            "0x49db76, 0x4af785, 0x4af89f, and 0x4a9e40 surfaces. This identifies "
            "wrapper construction and selection mechanics only; it does not recover "
            "final human object identity labels or authorize native RMG behavior changes."
        ),
        "inputs": {
            "ghidra_dump": str(args.dump),
            "assignment_summary": str(args.assignment),
            "ghidra_files": {name: str(path) for name, path in files.items()},
        },
        "invariants": invariants,
        "metrics": {
            "ghidra_file_count": len(ghidra_checks),
            "required_marker_count": sum(len(item["checks"]) for item in ghidra_checks.values()),
            "present_marker_count": sum(
                1
                for item in ghidra_checks.values()
                for check in item["checks"]
                if check["present"]
            ),
            "native_behavior_changed": False,
            "used_objdump": False,
            "overall_goal_complete": False,
        },
        "ghidra_checks": ghidra_checks,
        "source_backed_conclusion": (
            "Descriptor wrapper/source behavior is now recovered at this boundary. "
            "0x49db76 initializes a 0xe8 wrapper whose +0x00 points at a 0x4c copied "
            "source record; 0x4af785 reuses an existing wrapper when lane/source "
            "metadata match, otherwise copies the source record, initializes a new "
            "wrapper, records generator +0xedc source-pair metadata, and appends the "
            "wrapper to the lane bucket. 0x4af89f selects a source lane by scanning "
            "mask words at source record +0x18. 0x4a9e40 filters bucket wrappers by "
            "the backing source record fields +0x20/+0x24 and mask compatibility, then "
            "selects one passing candidate by RNG. Therefore the current descriptor "
            "+0x00 value is a source-record pointer within the wrapper model, not the "
            "final object identity. The remaining blocker is the source catalog/object "
            "template mapping that gives those copied source records human type/subtype/"
            "DEF semantics."
        ),
        "remaining_blockers": [
            {
                "id": "source_catalog_record_semantics",
                "reason": (
                    "The wrapper and selection mechanics are recovered, but the 0x4c "
                    "source record fields still need source-backed mapping to object "
                    "type/subtype/DEF/template semantics before native RMG can use them "
                    "as exact object identities."
                ),
            },
            {
                "id": "mixed_lane_selected_descriptor_sources",
                "reason": (
                    "Mixed return lanes 45/53/54/79 still need source-backed mapping from "
                    "selected wrapper/source records to human object identities, even though "
                    "their wrapper construction and selection surfaces are now recovered."
                ),
                "affected_contexts": [
                    "0x004a5e6c | 54",
                    "0x004a744a | 45",
                    "0x004a98f0 | 53",
                    "0x004a9c3f | 79",
                ],
            },
            {
                "id": "natural_selected_create_or_endpoint_success",
                "reason": (
                    "This checkpoint does not resolve the separate endpoint/relation frontier: "
                    "natural selected-create selection of the 0x540ca0/0x49cd97 generator+0xf5c "
                    "candidate, natural 0x4a696b source/relation match, and successful "
                    "0x4a5e73 -> 0x4a606b endpoint stamping remain pending or require "
                    "source-backed exclusion for supported one-level land."
                ),
            },
        ],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dump", type=Path, default=DEFAULT_DUMP)
    parser.add_argument("--assignment", type=Path, default=DEFAULT_ASSIGNMENT)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_DESCRIPTOR_SOURCE_RESOLVER status={status} markers={present}/{total} out={out}".format(
            status=summary["status"],
            present=summary["metrics"]["present_marker_count"],
            total=summary["metrics"]["required_marker_count"],
            out=args.out,
        )
    )


if __name__ == "__main__":
    main()
