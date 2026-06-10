#!/usr/bin/env python3
"""Verify the H3MapEd refcounted byte-buffer helper frontier.

This checkpoint resolves the helper-family gap left by the source-record parser
summary. The helpers are generic byte-buffer/string-holder lifecycle utilities;
this script intentionally does not claim object catalog identity.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
COPY_HELPER_DIR = ROOT / "ghidra_source_record_copy_helpers_dump_20260610"
CALLEE_DIR = ROOT / "ghidra_source_record_copy_helper_callees_dump_20260610"
LIFECYCLE_DIR = ROOT / "ghidra_source_record_copy_helper_lifecycle_dump_20260610"
PARSER_SUMMARY = ROOT / "source_record_parser_summary_20260610.json"
DEFAULT_OUT = ROOT / "source_record_copy_helper_summary_20260610.json"

ASSIGN_SLICE = COPY_HELPER_DIR / "target_004019a4_FUN_004019a4.txt"
ASSIGN_SLICE_REFS = COPY_HELPER_DIR / "target_004019a4_references.txt"
ERASE_RANGE = COPY_HELPER_DIR / "target_00401aa7_FUN_00401aa7.txt"
ERASE_RANGE_REFS = COPY_HELPER_DIR / "target_00401aa7_references.txt"
ENSURE_CAPACITY = COPY_HELPER_DIR / "target_00401b0e_FUN_00401b0e.txt"
ENSURE_CAPACITY_REFS = COPY_HELPER_DIR / "target_00401b0e_references.txt"
RELEASE_RESET = COPY_HELPER_DIR / "target_004016fd_FUN_004016fd.txt"
UNSHARE = CALLEE_DIR / "target_00401caa_FUN_00401caa.txt"
UNSHARE_REFS = CALLEE_DIR / "target_00401caa_references.txt"
COPY_INTO = LIFECYCLE_DIR / "target_00401a72_FUN_00401a72.txt"
COPY_INTO_REFS = LIFECYCLE_DIR / "target_00401a72_references.txt"
ALLOCATE_ROUNDED = CALLEE_DIR / "target_00401bed_FUN_00401bed.txt"
ALLOCATE_ROUNDED_REFS = CALLEE_DIR / "target_00401bed_references.txt"
GROWTH_COMMIT = LIFECYCLE_DIR / "target_00401c51_FUN_00401c51.txt"
GROWTH_COMMIT_REFS = LIFECYCLE_DIR / "target_00401c51_references.txt"

REFERENCE_CHECKS = [
    {
        "id": "assign_slice_used_by_source_record_parser_first_blob",
        "path": ASSIGN_SLICE_REFS,
        "marker": "from=004c029e type=UNCONDITIONAL_CALL caller=FUN_004c025c",
    },
    {
        "id": "assign_slice_used_by_source_record_parser_record_copy",
        "path": ASSIGN_SLICE_REFS,
        "marker": "from=004c02e1 type=UNCONDITIONAL_CALL caller=FUN_004c025c",
    },
    {
        "id": "assign_slice_used_by_source_payload_loader",
        "path": ASSIGN_SLICE_REFS,
        "marker": "from=0041f428 type=UNCONDITIONAL_CALL caller=FUN_0041f350",
    },
    {
        "id": "assign_slice_used_by_source_payload_loader_record_copy",
        "path": ASSIGN_SLICE_REFS,
        "marker": "from=0041f46d type=UNCONDITIONAL_CALL caller=FUN_0041f350",
    },
    {
        "id": "erase_range_used_by_source_record_parser",
        "path": ERASE_RANGE_REFS,
        "marker": "from=004c02ce type=UNCONDITIONAL_CALL caller=FUN_004c025c",
    },
    {
        "id": "erase_range_used_by_source_payload_loader_a",
        "path": ERASE_RANGE_REFS,
        "marker": "from=0041f44d type=UNCONDITIONAL_CALL caller=FUN_0041f350",
    },
    {
        "id": "erase_range_used_by_source_payload_loader_b",
        "path": ERASE_RANGE_REFS,
        "marker": "from=0041f498 type=UNCONDITIONAL_CALL caller=FUN_0041f350",
    },
    {
        "id": "ensure_capacity_called_by_assign_slice",
        "path": ENSURE_CAPACITY_REFS,
        "marker": "from=00401a38 type=UNCONDITIONAL_CALL caller=FUN_004019a4",
    },
    {
        "id": "ensure_capacity_called_by_erase_range",
        "path": ENSURE_CAPACITY_REFS,
        "marker": "from=00401af3 type=UNCONDITIONAL_CALL caller=FUN_00401aa7",
    },
    {
        "id": "unshare_called_by_erase_range",
        "path": UNSHARE_REFS,
        "marker": "from=00401abc type=UNCONDITIONAL_CALL caller=FUN_00401aa7",
    },
    {
        "id": "allocate_rounded_called_by_ensure_capacity",
        "path": ALLOCATE_ROUNDED_REFS,
        "marker": "from=00401b87 type=UNCONDITIONAL_CALL caller=FUN_00401b0e",
    },
    {
        "id": "copy_into_called_by_unshare",
        "path": COPY_INTO_REFS,
        "marker": "from=00401cd2 type=UNCONDITIONAL_CALL caller=FUN_00401caa",
    },
    {
        "id": "growth_commit_called_by_allocate_rounded",
        "path": GROWTH_COMMIT_REFS,
        "marker": "from=00401c2a type=UNCONDITIONAL_CALL caller=FUN_00401bed",
    },
]

FUNCTION_CHECKS = {
    "0x4019a4_assign_slice": {
        "path": ASSIGN_SLICE,
        "checks": [
            {"id": "target_holder_in_ecx", "marker": "004019b0: MOV EDI,ECX"},
            {"id": "source_holder_arg", "marker": "004019ab: MOV EBX,dword ptr [EBP + 0x8]"},
            {"id": "start_offset_arg", "marker": "004019a7: MOV EAX,dword ptr [EBP + 0xc]"},
            {"id": "count_clamp_arg", "marker": "004019c6: CMP dword ptr [EBP + 0x10],ESI"},
            {"id": "self_slice_erase_suffix", "marker": "004019dd: CALL 0x00401aa7"},
            {"id": "self_slice_erase_prefix", "marker": "004019e9: CALL 0x00401aa7"},
            {"id": "target_release_before_share", "marker": "00401a0e: CALL 0x004016fd"},
            {"id": "share_copies_data_pointer", "marker": "00401a1f: MOV dword ptr [EDI + 0x4],EAX"},
            {"id": "share_copies_length", "marker": "00401a25: MOV dword ptr [EDI + 0x8],ECX"},
            {"id": "share_copies_capacity", "marker": "00401a2b: MOV dword ptr [EDI + 0xc],ECX"},
            {"id": "share_increments_marker", "marker": "00401a2e: INC byte ptr [EAX + -0x1]"},
            {"id": "copy_path_ensures_capacity", "marker": "00401a38: CALL 0x00401b0e"},
            {"id": "copy_path_copies_bytes", "marker": "00401a57: CALL 0x004e6380"},
            {"id": "copy_path_sets_length", "marker": "00401a62: MOV dword ptr [EDI + 0x8],ESI"},
            {"id": "copy_path_zero_terminates", "marker": "00401a65: AND byte ptr [EAX + ESI*0x1],0x0"},
        ],
    },
    "0x401aa7_erase_range": {
        "path": ERASE_RANGE,
        "checks": [
            {"id": "target_holder_in_ecx", "marker": "00401aae: MOV EDI,ECX"},
            {"id": "start_index_arg", "marker": "00401aa9: MOV ESI,dword ptr [ESP + 0xc]"},
            {"id": "start_bounds_check", "marker": "00401ab0: CMP dword ptr [EDI + 0x8],ESI"},
            {"id": "unshares_before_mutation", "marker": "00401abc: CALL 0x00401caa"},
            {"id": "erase_count_arg", "marker": "00401ac4: MOV EBX,dword ptr [ESP + 0x14]"},
            {"id": "tail_move", "marker": "00401ae1: CALL 0x004e66c0"},
            {"id": "shrinks_or_normalizes", "marker": "00401af3: CALL 0x00401b0e"},
            {"id": "sets_new_length", "marker": "00401aff: MOV dword ptr [EDI + 0x8],ESI"},
            {"id": "zero_terminates", "marker": "00401b02: AND byte ptr [ESI + EAX*0x1],0x0"},
        ],
    },
    "0x401b0e_ensure_capacity_or_shrink": {
        "path": ENSURE_CAPACITY,
        "checks": [
            {"id": "target_holder_in_ecx", "marker": "00401b14: MOV ESI,ECX"},
            {"id": "desired_length_arg", "marker": "00401b10: MOV EDI,dword ptr [ESP + 0xc]"},
            {"id": "reads_data_pointer", "marker": "00401b20: MOV ECX,dword ptr [ESI + 0x4]"},
            {"id": "release_shared_buffer_a", "marker": "00401b40: CALL 0x004016fd"},
            {"id": "clear_sets_length", "marker": "00401b5b: MOV dword ptr [ESI + 0x8],EDX"},
            {"id": "clear_zero_terminates", "marker": "00401b5e: MOV byte ptr [ECX],DL"},
            {"id": "release_shared_buffer_b", "marker": "00401b78: CALL 0x004016fd"},
            {"id": "delegates_allocation", "marker": "00401b87: CALL 0x00401bed"},
            {"id": "success_return", "marker": "00401b8c: MOV AL,0x1"},
        ],
    },
    "0x4016fd_release_reset": {
        "path": RELEASE_RESET,
        "checks": [
            {"id": "target_holder_in_ecx", "marker": "00401703: MOV ESI,ECX"},
            {"id": "reads_data_pointer", "marker": "00401707: MOV EAX,dword ptr [ESI + 0x4]"},
            {"id": "frees_unique_buffer", "marker": "00401723: CALL 0x005044da"},
            {"id": "clears_data_pointer", "marker": "00401729: AND dword ptr [ESI + 0x4],0x0"},
            {"id": "clears_length", "marker": "0040172d: AND dword ptr [ESI + 0x8],0x0"},
            {"id": "clears_capacity", "marker": "00401731: AND dword ptr [ESI + 0xc],0x0"},
        ],
    },
    "0x401caa_unshare": {
        "path": UNSHARE,
        "checks": [
            {"id": "target_holder_in_ecx", "marker": "00401cac: MOV EDI,ECX"},
            {"id": "reads_data_pointer", "marker": "00401cae: MOV ESI,dword ptr [EDI + 0x4]"},
            {"id": "releases_shared_reference", "marker": "00401cc2: CALL 0x004016fd"},
            {"id": "allocates_or_clones_source", "marker": "00401cc8: CALL 0x004e62c0"},
            {"id": "copies_back_into_holder", "marker": "00401cd2: CALL 0x00401a72"},
        ],
    },
    "0x401a72_copy_into_holder": {
        "path": COPY_INTO,
        "checks": [
            {"id": "ensures_capacity", "marker": "00401a7d: CALL 0x00401b0e"},
            {"id": "copies_bytes", "marker": "00401a8e: CALL 0x004e6380"},
            {"id": "stores_length", "marker": "00401a99: MOV dword ptr [ESI + 0x8],EDI"},
            {"id": "zero_terminates", "marker": "00401a9c: AND byte ptr [EAX + EDI*0x1],0x0"},
        ],
    },
    "0x401bed_allocate_rounded_capacity": {
        "path": ALLOCATE_ROUNDED,
        "checks": [
            {"id": "desired_capacity_arg", "marker": "00401bfd: MOV EDI,dword ptr [EBP + 0x8]"},
            {"id": "rounds_capacity", "marker": "00401c00: OR EDI,0x1f"},
            {"id": "allocates_buffer", "marker": "00401c21: CALL 0x005044b1"},
            {"id": "jumps_to_growth_commit", "marker": "00401c2a: JMP 0x00401c51"},
        ],
    },
    "0x401c51_growth_commit": {
        "path": GROWTH_COMMIT,
        "checks": [
            {"id": "reads_old_length", "marker": "00401c51: MOV EAX,dword ptr [ESI + 0x8]"},
            {"id": "copies_old_bytes", "marker": "00401c67: CALL 0x004e6380"},
            {"id": "releases_old_buffer", "marker": "00401c76: CALL 0x004016fd"},
            {"id": "stores_new_data_pointer", "marker": "00401c7f: MOV dword ptr [ESI + 0x4],EAX"},
            {"id": "stores_new_capacity", "marker": "00401c88: MOV dword ptr [ESI + 0xc],EDI"},
            {"id": "stores_new_length", "marker": "00401c95: MOV dword ptr [ESI + 0x8],EDI"},
            {"id": "zero_terminates", "marker": "00401c98: AND byte ptr [EAX + EDI*0x1],0x0"},
        ],
    },
}

REQUIRED_SUMMARY_STATUSES = {
    PARSER_SUMMARY: "source_record_parser_surface_recovered_catalog_identity_pending",
}


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""


def read_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def check_marker(path: Path, check: dict[str, str]) -> dict[str, Any]:
    return {**check, "path": str(path), "present": check["marker"] in read_text(path)}


def check_markers(path: Path, checks: list[dict[str, str]]) -> list[dict[str, Any]]:
    return [check_marker(path, check) for check in checks]


def check_summary_status(path: Path, expected_status: str) -> dict[str, Any]:
    data = read_json(path)
    status = data.get("status")
    return {
        "path": str(path),
        "expected_status": expected_status,
        "actual_status": status,
        "present": path.exists(),
        "matches": status == expected_status,
    }


def summarize() -> dict[str, Any]:
    reference_checks = [check_marker(check["path"], check) for check in REFERENCE_CHECKS]
    function_checks: dict[str, list[dict[str, Any]]] = {}
    for function_id, spec in FUNCTION_CHECKS.items():
        function_checks[function_id] = check_markers(spec["path"], spec["checks"])
    summary_status_checks = [
        check_summary_status(path, expected) for path, expected in REQUIRED_SUMMARY_STATUSES.items()
    ]
    all_checks = reference_checks + [
        check for checks in function_checks.values() for check in checks
    ]
    missing = [check["id"] for check in all_checks if not check["present"]]
    missing_summary_statuses = [
        check["path"] for check in summary_status_checks if not check["matches"]
    ]
    recovered = not missing and not missing_summary_statuses
    return {
        "schema_id": "h3maped_rmg_source_record_copy_helper_frontier_v1",
        "status": (
            "source_record_copy_helper_surface_recovered_identity_mapping_pending"
            if recovered
            else "source_record_copy_helper_surface_incomplete"
        ),
        "dumps": {
            "copy_helper_dir": str(COPY_HELPER_DIR),
            "callee_dir": str(CALLEE_DIR),
            "lifecycle_dir": str(LIFECYCLE_DIR),
            "parser_summary": str(PARSER_SUMMARY),
        },
        "marker_count": len(all_checks),
        "present_marker_count": sum(1 for check in all_checks if check["present"]),
        "missing_marker_ids": missing,
        "summary_status_checks": summary_status_checks,
        "missing_summary_status_paths": missing_summary_statuses,
        "reference_checks": reference_checks,
        "function_checks": function_checks,
        "recovered_boundary": {
            "holder_layout": (
                "Generic refcounted byte-buffer/string-holder with data pointer at +0x04, "
                "length at +0x08, capacity at +0x0c, and a marker/refcount byte immediately "
                "before the data pointer."
            ),
            "0x4019a4": (
                "Assigns/copies a slice from one holder to another, sharing full source "
                "buffers when possible and otherwise ensuring capacity, copying bytes, "
                "setting length, and zero-terminating."
            ),
            "0x401aa7": (
                "Erases a range from a holder after unsharing it, shifts the tail left, "
                "shrinks/normalizes capacity, updates length, and zero-terminates."
            ),
            "0x401b0e": (
                "Ensures capacity, clears, shrinks, or delegates allocation for a holder, "
                "including release of shared buffers."
            ),
            "0x4016fd": (
                "Releases or decrements the current buffer reference and resets holder "
                "+0x04/+0x08/+0x0c."
            ),
            "0x401caa": "Unshares a holder before in-place mutation by cloning shared data.",
            "0x401a72": "Copies bytes into an existing holder after ensuring capacity.",
            "0x401bed_0x401c51": (
                "Rounds requested capacity, allocates a new buffer, copies old bytes, "
                "releases the old buffer, stores new data/length/capacity, and zero-terminates."
            ),
        },
        "remaining_unrecovered": [
            "Human field names of the data held in these buffers at each source-record parser field.",
            "Final source catalog/template mapping from parsed source records to objects.txt/objtmplt.txt type, subtype, and DEF rows.",
            "Allocator/memory primitive internals below 0x5044b1, 0x4e6380, 0x4e66c0, and 0x4e62c0 are intentionally not recovered unless future source-identity proof requires them.",
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
        "RMG_H3MAPED_SOURCE_RECORD_COPY_HELPERS "
        f"status={summary['status']} "
        f"markers={summary['present_marker_count']}/{summary['marker_count']} "
        f"out={args.out}"
    )
    return 0 if summary["status"].endswith("_pending") else 1


if __name__ == "__main__":
    raise SystemExit(main())
