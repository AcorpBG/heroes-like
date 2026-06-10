#!/usr/bin/env python3
"""Verify the current H3MapEd RMG source-input layout frontier.

This checkpoint narrows the input/source parser below the 0x41f350 source
payload loader. It proves the local versioned record layout and size guard
surface without claiming final catalog row identity or full field semantics.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_OUT = ROOT / "source_input_layout_frontier_summary_20260610.json"

FILES = {
    "loader_0x41f350": ROOT
    / "ghidra_source_payload_producer_frontier_dump_20260610"
    / "target_0041f350_FUN_0041f350.txt",
    "input_parser_0x43b0ff": ROOT
    / "ghidra_source_payload_producer_helpers_dump_20260610"
    / "target_0043b0ff_FUN_0043b0ff.txt",
    "input_parser_0x43b0ff_refs": ROOT
    / "ghidra_source_payload_producer_helpers_dump_20260610"
    / "target_0043b0ff_references.txt",
    "size_guard_0x433d7d": ROOT
    / "ghidra_source_payload_producer_helpers_dump_20260610"
    / "target_00433d7d_FUN_00433d7d.txt",
    "size_guard_0x433d7d_refs": ROOT
    / "ghidra_source_payload_producer_helpers_dump_20260610"
    / "target_00433d7d_references.txt",
}

CHECKS: dict[str, list[dict[str, str]]] = {
    "loader_0x41f350": [
        {
            "id": "passes_local_input_record_to_parser",
            "marker": "0041f3c2: LEA ECX,[EBP + 0xfffffbec]",
            "meaning": "0x41f350 parses into a local source-input record before family-table matching.",
        },
        {
            "id": "calls_input_parser_once",
            "marker": "0041f3cc: CALL 0x0043b0ff",
            "meaning": "The source loader calls the parser at 0x43b0ff.",
        },
        {
            "id": "passes_parser_record_to_size_guard",
            "marker": "0041f3d4: LEA ECX,[EBP + -0x10]",
            "meaning": "The parsed caller source/input wrapper is reused for the guard check.",
        },
        {
            "id": "calls_size_guard_once",
            "marker": "0041f3dc: CALL 0x00433d7d",
            "meaning": "The source loader runs the 0x433d7d size/version guard after parsing.",
        },
        {
            "id": "uses_parser_family_value_for_global_match",
            "marker": "0041f3ea: CMP EDX,dword ptr [EBP + 0xfffffbf0]",
            "meaning": "The global source-family table match consumes a field written by 0x43b0ff.",
        },
    ],
    "input_parser_0x43b0ff": [
        {
            "id": "mode_byte_initializes_first_subrecord",
            "marker": "0043b11e: MOV byte ptr [ESI],AL",
            "meaning": "The caller mode byte initializes the first local subrecord.",
        },
        {
            "id": "mode_byte_initializes_second_subrecord",
            "marker": "0043b133: MOV byte ptr [EDI],AL",
            "meaning": "The caller mode byte initializes a second local subrecord.",
        },
        {
            "id": "allocates_eight_0x54_records",
            "marker": "0043b149: PUSH 0x54",
            "meaning": "The parser allocates/initializes an eight-record area with 0x54-byte elements.",
        },
        {
            "id": "record_array_base_0x34",
            "marker": "0043b146: LEA EAX,[EBX + 0x34]",
            "meaning": "The 0x54-byte record array is anchored at parser output +0x34.",
        },
        {
            "id": "record_stride_0x54",
            "marker": "0043b44a: ADD ESI,0x54",
            "meaning": "The parser iterates eight 0x54-byte nested records.",
        },
        {
            "id": "record_loop_count_eight",
            "marker": "0043b228: MOV dword ptr [EBP + -0x30],0x8",
            "meaning": "The nested record loop is count eight.",
        },
        {
            "id": "version_guard_0x08",
            "marker": "0043b268: CMP dword ptr [EBP + 0xc],0x8",
            "meaning": "Some nested fields are gated on input version/size >= 8.",
        },
        {
            "id": "version_guard_0x09",
            "marker": "0043b2ea: CMP dword ptr [EBP + 0xc],0x9",
            "meaning": "Some nested fields are gated on input version/size >= 9.",
        },
        {
            "id": "version_guard_0x0a",
            "marker": "0043b194: CMP dword ptr [EBP + 0xc],0xa",
            "meaning": "Top-level presence/boolean field selection changes at version/size 10.",
        },
        {
            "id": "version_guard_0x0d",
            "marker": "0043b352: CMP dword ptr [EBP + 0xc],0xd",
            "meaning": "A nested field group is gated on input version/size >= 13.",
        },
        {
            "id": "version_guard_0x10",
            "marker": "0043b28b: CMP dword ptr [EBP + 0xc],0x10",
            "meaning": "A nested field group is gated on input version/size >= 16.",
        },
        {
            "id": "version_guard_0x11",
            "marker": "0043b309: CMP dword ptr [EBP + 0xc],0x11",
            "meaning": "A nested field group is gated on input version/size >= 17.",
        },
        {
            "id": "version_guard_0x12",
            "marker": "0043b3bf: CMP dword ptr [EBP + 0xc],0x12",
            "meaning": "A nested byte-stream/vector group is gated on input version/size >= 18.",
        },
        {
            "id": "version_guard_0x14",
            "marker": "0043b204: CMP dword ptr [EBP + 0xc],0x14",
            "meaning": "A top-level byte field is gated on input version/size >= 20.",
        },
        {
            "id": "version_guard_0x19",
            "marker": "0043b585: CMP dword ptr [EBP + 0xc],0x19",
            "meaning": "A late repeated group is gated on input version/size >= 25.",
        },
        {
            "id": "version_guard_0x1a",
            "marker": "0043b270: CMP dword ptr [EBP + 0xc],0x1a",
            "meaning": "A late nested boolean/int group is gated on input version/size >= 26.",
        },
        {
            "id": "top_level_bool_0x00",
            "marker": "0043b1b1: MOV byte ptr [EBX],AL",
            "meaning": "The parser writes a top-level boolean-like field at output +0x00.",
        },
        {
            "id": "top_level_value_0x04",
            "marker": "0043b1ca: MOV dword ptr [EBX + 0x4],EAX",
            "meaning": "The parser writes a top-level value at output +0x04.",
        },
        {
            "id": "top_level_bool_0x08",
            "marker": "0043b1e3: MOV byte ptr [EBX + 0x8],AL",
            "meaning": "The parser writes a top-level boolean-like field at output +0x08.",
        },
        {
            "id": "top_level_signed_byte_0x2c",
            "marker": "0043b208: MOV dword ptr [EBX + 0x2c],EAX",
            "meaning": "The parser writes a sign-extended byte-derived field at output +0x2c.",
        },
        {
            "id": "top_level_optional_byte_0x30",
            "marker": "0043b21c: MOV dword ptr [EBX + 0x30],EAX",
            "meaning": "The parser writes an optional byte-derived field at output +0x30.",
        },
        {
            "id": "nested_bool_before_record",
            "marker": "0043b243: MOV byte ptr [ESI + -0x4],AL",
            "meaning": "Each nested record has a boolean-like field just before its aligned body.",
        },
        {
            "id": "nested_bool_minus_three",
            "marker": "0043b258: MOV byte ptr [ESI + -0x3],AL",
            "meaning": "Each nested record has another boolean-like field near the record header.",
        },
        {
            "id": "nested_signed_field_0x00",
            "marker": "0043b26c: MOV dword ptr [ESI],EAX",
            "meaning": "Each nested record writes a sign-extended byte-derived field at +0x00.",
        },
        {
            "id": "nested_bool_0x04",
            "marker": "0043b288: MOV byte ptr [ESI + 0x4],AL",
            "meaning": "Each nested record writes a boolean-like field at +0x04.",
        },
        {
            "id": "nested_optional_payload_0x08",
            "marker": "0043b296: CALL 0x0043bb1b",
            "meaning": "A version-gated helper populates nested record payload at +0x08.",
        },
        {
            "id": "nested_bool_0x0c",
            "marker": "0043b2e7: MOV byte ptr [ESI + 0xc],AL",
            "meaning": "Each nested record writes a boolean-like field at +0x0c.",
        },
        {
            "id": "nested_bool_0x0d",
            "marker": "0043b304: MOV byte ptr [ESI + 0xd],AL",
            "meaning": "Each nested record writes a boolean-like field at +0x0d.",
        },
        {
            "id": "nested_bool_0x0e",
            "marker": "0043b323: MOV byte ptr [ESI + 0xe],AL",
            "meaning": "Each nested record writes a boolean-like field at +0x0e.",
        },
        {
            "id": "nested_default_0x10",
            "marker": "0043b338: OR dword ptr [ESI + 0x10],0xffffffff",
            "meaning": "Missing older-input nested field +0x10 defaults to -1.",
        },
        {
            "id": "nested_payload_0x14",
            "marker": "0043b345: CALL 0x0043acf0",
            "meaning": "A helper populates nested record payload at +0x14.",
        },
        {
            "id": "nested_bool_0x20",
            "marker": "0043b36c: MOV byte ptr [ESI + 0x20],AL",
            "meaning": "Each nested record writes a boolean-like field at +0x20.",
        },
        {
            "id": "nested_optional_0x24",
            "marker": "0043b37e: MOV dword ptr [ESI + 0x24],EAX",
            "meaning": "Each nested record writes an optional byte-derived field at +0x24.",
        },
        {
            "id": "nested_optional_0x28",
            "marker": "0043b392: MOV dword ptr [ESI + 0x28],EAX",
            "meaning": "Each nested record writes an optional byte-derived field at +0x28.",
        },
        {
            "id": "nested_payload_0x2c",
            "marker": "0043b39a: CALL 0x004190cb",
            "meaning": "A helper populates nested record payload at +0x2c.",
        },
        {
            "id": "nested_default_0x3c",
            "marker": "0043b3bb: AND dword ptr [ESI + 0x3c],0x0",
            "meaning": "Missing older-input nested field +0x3c defaults to 0.",
        },
        {
            "id": "nested_byte_stream_0x44",
            "marker": "0043b42e: MOV dword ptr [EDX + ECX*0x1],EAX",
            "meaning": "A version-gated byte stream writes into nested record payload at +0x44.",
        },
        {
            "id": "top_level_payload_0x2d4",
            "marker": "0043b472: CALL 0x0043ad49",
            "meaning": "The parser populates a top-level payload at output +0x2d4.",
        },
        {
            "id": "top_level_payload_0x2f0",
            "marker": "0043b482: CALL 0x0043aec6",
            "meaning": "The parser populates a top-level payload at output +0x2f0.",
        },
        {
            "id": "top_level_count_0x300",
            "marker": "0043b49b: MOV dword ptr [EBX + 0x300],EAX",
            "meaning": "The parser writes a top-level count/value at output +0x300.",
        },
        {
            "id": "top_level_repeat_0x304",
            "marker": "0043b4bf: MOV dword ptr [ESI],EAX",
            "meaning": "The parser writes an eight-entry top-level repeated group starting at +0x304.",
        },
        {
            "id": "top_level_payload_0x324",
            "marker": "0043b517: LEA EAX,[EBX + 0x324]",
            "meaning": "The parser routes a top-level payload anchored at output +0x324.",
        },
        {
            "id": "top_level_payload_0x338",
            "marker": "0043b54c: LEA ESI,[EBX + 0x338]",
            "meaning": "The parser routes a late top-level payload anchored at output +0x338.",
        },
    ],
    "size_guard_0x433d7d": [
        {
            "id": "reads_source_wrapper_pointer",
            "marker": "00433d88: MOV ECX,dword ptr [ESI]",
            "meaning": "The guard unwraps the source/input wrapper pointer.",
        },
        {
            "id": "calls_virtual_size_or_version_reader",
            "marker": "00433d8f: CALL dword ptr [EAX + 0x18]",
            "meaning": "The guard calls the source/input object's virtual size/version reader.",
        },
        {
            "id": "compares_required_minimum_0x1f",
            "marker": "00433d92: CMP EAX,0x1f",
            "meaning": "The guard enforces a minimum returned value of 0x1f.",
        },
        {
            "id": "emits_guard_diagnostic",
            "marker": "00433da9: CALL 0x004e633b",
            "meaning": "If the returned value is below 0x1f, the guard emits a diagnostic/assertion path.",
        },
    ],
}


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""


def summarize_file(key: str, path: Path) -> dict[str, Any]:
    text = read_text(path)
    checks = []
    for check in CHECKS.get(key, []):
        checks.append({**check, "present": check["marker"] in text})
    return {
        "path": str(path),
        "exists": path.exists(),
        "check_count": len(checks),
        "present_check_count": sum(1 for check in checks if check["present"]),
        "checks": checks,
    }


def count_reference_callers(path: Path, target: str) -> tuple[int, list[str]]:
    text = read_text(path)
    callers = []
    needle = f"instruction=CALL {target}"
    for line in text.splitlines():
        if needle not in line:
            continue
        caller = "unknown"
        for part in line.split():
            if part.startswith("caller="):
                caller = part.split("=", 1)[1]
        callers.append(caller)
    return len(callers), sorted(set(callers))


def summarize() -> dict[str, Any]:
    files = {key: summarize_file(key, path) for key, path in FILES.items()}
    all_checks = [check for result in files.values() for check in result["checks"]]
    missing = [check["id"] for check in all_checks if not check["present"]]
    parser_ref_count, parser_ref_callers = count_reference_callers(
        FILES["input_parser_0x43b0ff_refs"], "0x0043b0ff"
    )
    guard_ref_count, guard_ref_callers = count_reference_callers(
        FILES["size_guard_0x433d7d_refs"], "0x00433d7d"
    )
    recovered = (
        not missing
        and parser_ref_count == 1
        and parser_ref_callers == ["FUN_0041f350"]
        and guard_ref_count == 1
        and guard_ref_callers == ["FUN_0041f350"]
    )
    return {
        "schema_id": "h3maped_rmg_source_input_layout_frontier_v1",
        "status": (
            "source_input_versioned_layout_recovered_field_semantics_pending"
            if recovered
            else "source_input_versioned_layout_incomplete"
        ),
        "files": files,
        "marker_count": len(all_checks),
        "present_marker_count": sum(1 for check in all_checks if check["present"]),
        "missing_marker_ids": missing,
        "reference_counts": {
            "0x43b0ff": parser_ref_count,
            "0x433d7d": guard_ref_count,
        },
        "reference_callers": {
            "0x43b0ff": parser_ref_callers,
            "0x433d7d": guard_ref_callers,
        },
        "recovered_boundary": {
            "parser": "0x43b0ff",
            "guard": "0x433d7d",
            "owner": "0x41f350",
            "proved": [
                "0x43b0ff and 0x433d7d have exactly one Ghidra call reference each, both from 0x41f350.",
                "0x41f350 parses into a local source-input record and uses one parsed field for the global source-family table match at 0x535214..0x535224.",
                "0x433d7d unwraps the source/input wrapper, calls a virtual reader at vtable +0x18, and requires the returned value to be at least 0x1f.",
                "0x43b0ff initializes a versioned parser-output record with top-level fields, an eight-entry nested record array, and repeated/payload groups.",
                "The nested array has eight records with a 0x54-byte stride and version gates at 0x08, 0x09, 0x0a, 0x0d, 0x10, 0x11, 0x12, 0x14, 0x19, and 0x1a.",
            ],
        },
        "remaining_unrecovered": [
            "Human semantic labels for individual 0x43b0ff output fields and nested 0x54-byte record fields.",
            "Exact stream helper semantics for 0x40763d, 0x407675, 0x402461, 0x4190cb, 0x43acf0, 0x43ad49, 0x43aec6, 0x43bb1b, 0x43bb58, 0x43bb95, 0x43bbe1, 0x43bc24, and 0x43bc67.",
            "The final mapping from parsed source-input fields to populated 0x4c source records and objects.txt/objtmplt.txt rows.",
            "Variant/filter builder semantics called later from 0x41f350, including 0x422868, 0x428d45, 0x420e6b, and 0x434073.",
        ],
        "native_behavior_changed": False,
        "used_objdump": False,
        "overall_goal_complete": False,
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize()
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_SOURCE_INPUT_LAYOUT_FRONTIER "
        f"status={summary['status']} "
        f"markers={summary['present_marker_count']}/{summary['marker_count']} "
        f"parser_refs={summary['reference_counts']['0x43b0ff']} "
        f"guard_refs={summary['reference_counts']['0x433d7d']} "
        f"out={args.out}"
    )
    return 0 if summary["status"].endswith("_pending") else 1


if __name__ == "__main__":
    raise SystemExit(main())
