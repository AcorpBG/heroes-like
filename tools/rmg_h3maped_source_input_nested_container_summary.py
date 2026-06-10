#!/usr/bin/env python3
"""Verify the H3MapEd RMG source-input nested container helper frontier.

This checkpoint sits below the source-input stream helper surface. It proves
the fixed-size guarded read wrappers, counted read wrapper, dynamic byte-buffer
helpers, and bitset helper families used by the 0x43b0ff source parser without
claiming final human field names.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DUMP_DIR = ROOT / "ghidra_source_input_nested_container_helpers_dump_20260610"
DEFAULT_OUT = ROOT / "source_input_nested_container_summary_20260610.json"

FILES = {
    "read_word_guard_0x40237c": DUMP_DIR / "target_0040237c_FUN_0040237c.txt",
    "read_word_guard_0x43bf8f": DUMP_DIR / "target_0043bf8f_FUN_0043bf8f.txt",
    "read_byte_guard_0x43bfc7": DUMP_DIR / "target_0043bfc7_FUN_0043bfc7.txt",
    "read_0x14_guard_0x43bfff": DUMP_DIR / "target_0043bfff_FUN_0043bfff.txt",
    "read_0x10_guard_0x438937": DUMP_DIR / "target_00438937_FUN_00438937.txt",
    "raw_counted_read_0x41941a": DUMP_DIR / "target_0041941a_FUN_0041941a.txt",
    "byte_buffer_normalize_0x4193cb": DUMP_DIR / "target_004193cb_FUN_004193cb.txt",
    "byte_buffer_insert_0x4192c0": DUMP_DIR / "target_004192c0_FUN_004192c0.txt",
    "byte_buffer_reserve_0x419302": DUMP_DIR / "target_00419302_FUN_00419302.txt",
    "bitset_test_0x416b09": DUMP_DIR / "target_00416b09_FUN_00416b09.txt",
    "bitset_set_clear_0x416b35": DUMP_DIR / "target_00416b35_FUN_00416b35.txt",
    "bitset_set_clear_0x42d05f": DUMP_DIR / "target_0042d05f_FUN_0042d05f.txt",
    "bitset_set_clear_0x42d83c": DUMP_DIR / "target_0042d83c_FUN_0042d83c.txt",
    "bitset_test_0x43beb9": DUMP_DIR / "target_0043beb9_FUN_0043beb9.txt",
    "bitset_set_clear_0x43bee8": DUMP_DIR / "target_0043bee8_FUN_0043bee8.txt",
}

CHECKS: dict[str, list[dict[str, str]]] = {
    "read_word_guard_0x40237c": [
        {"id": "read_count_two", "marker": "00402385: PUSH 0x2"},
        {"id": "calls_virtual_reader", "marker": "0040238e: CALL dword ptr [EAX + 0x18]"},
        {"id": "requires_two_bytes_returned", "marker": "00402391: CMP EAX,0x2"},
        {"id": "diagnostic_on_short_read", "marker": "004023a8: CALL 0x004e633b"},
        {"id": "returns_stream_wrapper", "marker": "004023ad: MOV EAX,ESI"},
    ],
    "read_word_guard_0x43bf8f": [
        {"id": "read_count_two", "marker": "0043bf98: PUSH 0x2"},
        {"id": "calls_virtual_reader", "marker": "0043bfa1: CALL dword ptr [EAX + 0x18]"},
        {"id": "requires_two_bytes_returned", "marker": "0043bfa4: CMP EAX,0x2"},
        {"id": "diagnostic_on_short_read", "marker": "0043bfbb: CALL 0x004e633b"},
        {"id": "returns_stream_wrapper", "marker": "0043bfc0: MOV EAX,ESI"},
    ],
    "read_byte_guard_0x43bfc7": [
        {"id": "read_count_one", "marker": "0043bfd0: PUSH 0x1"},
        {"id": "calls_virtual_reader", "marker": "0043bfd9: CALL dword ptr [EAX + 0x18]"},
        {"id": "requires_one_byte_returned", "marker": "0043bfdc: CMP EAX,0x1"},
        {"id": "diagnostic_on_short_read", "marker": "0043bff3: CALL 0x004e633b"},
        {"id": "returns_stream_wrapper", "marker": "0043bff8: MOV EAX,ESI"},
    ],
    "read_0x14_guard_0x43bfff": [
        {"id": "read_count_0x14", "marker": "0043c008: PUSH 0x14"},
        {"id": "calls_virtual_reader", "marker": "0043c011: CALL dword ptr [EAX + 0x18]"},
        {"id": "requires_0x14_bytes_returned", "marker": "0043c014: CMP EAX,0x14"},
        {"id": "diagnostic_on_short_read", "marker": "0043c02b: CALL 0x004e633b"},
        {"id": "returns_stream_wrapper", "marker": "0043c030: MOV EAX,ESI"},
    ],
    "read_0x10_guard_0x438937": [
        {"id": "read_count_0x10", "marker": "00438940: PUSH 0x10"},
        {"id": "calls_virtual_reader", "marker": "00438949: CALL dword ptr [EAX + 0x18]"},
        {"id": "requires_0x10_bytes_returned", "marker": "0043894c: CMP EAX,0x10"},
        {"id": "diagnostic_on_short_read", "marker": "00438963: CALL 0x004e633b"},
        {"id": "returns_stream_wrapper", "marker": "00438968: MOV EAX,ESI"},
    ],
    "raw_counted_read_0x41941a": [
        {"id": "pushes_count_arg", "marker": "00419423: PUSH dword ptr [EBP + 0xc]"},
        {"id": "pushes_dest_arg", "marker": "00419428: PUSH dword ptr [EBP + 0x8]"},
        {"id": "calls_virtual_reader", "marker": "0041942d: CALL dword ptr [EAX + 0x18]"},
        {"id": "requires_requested_count_returned", "marker": "00419430: CMP EAX,dword ptr [EBP + 0xc]"},
        {"id": "diagnostic_on_short_read", "marker": "00419447: CALL 0x004e633b"},
        {"id": "returns_stream_wrapper", "marker": "0041944c: MOV EAX,ESI"},
    ],
    "byte_buffer_normalize_0x4193cb": [
        {"id": "reads_current_end_pointer", "marker": "004193ce: MOV EAX,dword ptr [ESI + 0x4]"},
        {"id": "checks_byte_before_end", "marker": "004193d5: MOV AL,byte ptr [EAX + -0x1]"},
        {"id": "releases_backing_storage_conditionally", "marker": "004193e5: CALL 0x00401b0e"},
        {"id": "marks_last_byte_ff", "marker": "004193f1: OR byte ptr [ESI + -0x1],0xff"},
    ],
    "byte_buffer_insert_0x4192c0": [
        {"id": "normalizes_buffer_first", "marker": "004192c4: CALL 0x004193cb"},
        {"id": "inserts_range", "marker": "004192ec: CALL 0x00401aa7"},
        {"id": "returns_begin_plus_offset", "marker": "004192f5: LEA ECX,[EAX + ESI*0x1]"},
    ],
    "byte_buffer_reserve_0x419302": [
        {"id": "reads_capacity_or_end", "marker": "00419302: MOV EDX,dword ptr [ECX + 0x8]"},
        {"id": "compares_requested_against_capacity", "marker": "00419309: CMP EAX,EDX"},
        {"id": "uses_insert_or_resize_helper", "marker": "00419314: CALL 0x00401aa7"},
        {"id": "grows_remaining_capacity", "marker": "00419320: CALL 0x00419372"},
    ],
    "bitset_test_0x416b09": [
        {"id": "checks_bound_8", "marker": "00416b10: CMP ESI,0x8"},
        {"id": "capacity_helper", "marker": "00416b17: CALL 0x00416bac"},
        {"id": "bit_index_mask", "marker": "00416b20: AND ECX,0x1f"},
        {"id": "word_index_shift", "marker": "00416b26: SHR ESI,0x5"},
        {"id": "tests_word_bit", "marker": "00416b29: AND EAX,dword ptr [EDI + ESI*0x4]"},
    ],
    "bitset_set_clear_0x416b35": [
        {"id": "checks_bound_8", "marker": "00416b3d: CMP EDI,0x8"},
        {"id": "capacity_helper", "marker": "00416b42: CALL 0x00416bac"},
        {"id": "bit_index_mask", "marker": "00416b54: AND ECX,0x1f"},
        {"id": "sets_word_bit", "marker": "00416b60: OR dword ptr [EAX],EDX"},
        {"id": "clears_word_bit", "marker": "00416b76: AND dword ptr [EAX],EDX"},
    ],
    "bitset_set_clear_0x42d05f": [
        {"id": "checks_bound_9", "marker": "0042d067: CMP EDI,0x9"},
        {"id": "capacity_helper", "marker": "0042d06c: CALL 0x0042f6f4"},
        {"id": "bit_index_mask", "marker": "0042d07e: AND ECX,0x1f"},
        {"id": "word_index_shift", "marker": "0042d082: SHR EAX,0x5"},
        {"id": "sets_word_bit", "marker": "0042d08a: OR dword ptr [EAX],EDX"},
        {"id": "clears_word_bit", "marker": "0042d0a0: AND dword ptr [EAX],EDX"},
    ],
    "bitset_set_clear_0x42d83c": [
        {"id": "checks_bound_0x9c", "marker": "0042d844: CMP EDI,0x9c"},
        {"id": "capacity_helper", "marker": "0042d84c: CALL 0x00430070"},
        {"id": "bit_index_mask", "marker": "0042d85e: AND ECX,0x1f"},
        {"id": "word_index_shift", "marker": "0042d862: SHR EAX,0x5"},
        {"id": "sets_word_bit", "marker": "0042d86a: OR dword ptr [EAX],EDX"},
        {"id": "clears_word_bit", "marker": "0042d880: AND dword ptr [EAX],EDX"},
    ],
    "bitset_test_0x43beb9": [
        {"id": "checks_bound_0x80", "marker": "0043bec0: CMP ESI,0x80"},
        {"id": "capacity_helper", "marker": "0043beca: CALL 0x0043bf35"},
        {"id": "bit_index_mask", "marker": "0043bed3: AND ECX,0x1f"},
        {"id": "word_index_shift", "marker": "0043bed9: SHR ESI,0x5"},
        {"id": "tests_word_bit", "marker": "0043bedc: AND EAX,dword ptr [EDI + ESI*0x4]"},
    ],
    "bitset_set_clear_0x43bee8": [
        {"id": "checks_bound_0x80", "marker": "0043bef0: CMP EDI,0x80"},
        {"id": "capacity_helper", "marker": "0043bef8: CALL 0x0043bf35"},
        {"id": "bit_index_mask", "marker": "0043bf0a: AND ECX,0x1f"},
        {"id": "word_index_shift", "marker": "0043bf0e: SHR EAX,0x5"},
        {"id": "sets_word_bit", "marker": "0043bf16: OR dword ptr [EAX],EDX"},
        {"id": "clears_word_bit", "marker": "0043bf2c: AND dword ptr [EAX],EDX"},
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


def summarize() -> dict[str, Any]:
    files = {key: summarize_file(key, path) for key, path in FILES.items()}
    all_checks = [check for result in files.values() for check in result["checks"]]
    missing = [check["id"] for check in all_checks if not check["present"]]
    recovered = not missing and all(result["exists"] for result in files.values())
    return {
        "schema_id": "h3maped_rmg_source_input_nested_container_frontier_v1",
        "status": "source_input_nested_container_surface_recovered_type_names_pending"
        if recovered
        else "source_input_nested_container_surface_incomplete",
        "dump_dir": str(DUMP_DIR),
        "files": files,
        "marker_count": len(all_checks),
        "present_marker_count": sum(1 for check in all_checks if check["present"]),
        "missing_marker_ids": missing,
        "recovered_boundary": {
            "guarded_reads": {
                "0x40237c": "guarded two-byte read through source/input vtable +0x18",
                "0x43bf8f": "guarded two-byte read through source/input vtable +0x18",
                "0x43bfc7": "guarded one-byte read through source/input vtable +0x18",
                "0x43bfff": "guarded 0x14-byte read through source/input vtable +0x18",
                "0x438937": "guarded 0x10-byte read through source/input vtable +0x18",
                "0x41941a": "generic guarded counted read into caller buffer",
            },
            "dynamic_byte_buffer_helpers": {
                "0x4193cb": "normalizes/release-marks a byte buffer before mutation",
                "0x4192c0": "normalizes then inserts/copies a byte range and returns the inserted pointer",
                "0x419302": "ensures/reserves byte-buffer capacity through insert/resize helpers",
            },
            "bitset_helpers": {
                "0x416b09": "bit test helper with capacity helper 0x416bac and bound 0x8",
                "0x416b35": "bit set/clear helper with capacity helper 0x416bac and bound 0x8",
                "0x42d05f": "bit set/clear helper with capacity helper 0x42f6f4 and bound 0x9",
                "0x42d83c": "bit set/clear helper with capacity helper 0x430070 and bound 0x9c",
                "0x43beb9": "bit test helper with capacity helper 0x43bf35 and bound 0x80",
                "0x43bee8": "bit set/clear helper with capacity helper 0x43bf35 and bound 0x80",
            },
        },
        "remaining_unrecovered": [
            "Human domain names for the bitset/container families.",
            "Exact capacity-helper internals below 0x416bac, 0x42f6f4, 0x430070, and 0x43bf35.",
            "Final field names for the 0x43b0ff parser-output members that own these containers.",
            "Final mapping from parsed helper payloads into populated 0x4c source records and objects.txt/objtmplt.txt rows.",
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
        "RMG_H3MAPED_SOURCE_INPUT_NESTED_CONTAINERS "
        f"status={summary['status']} "
        f"markers={summary['present_marker_count']}/{summary['marker_count']} "
        f"out={args.out}"
    )
    return 0 if summary["status"].endswith("_pending") else 1


if __name__ == "__main__":
    raise SystemExit(main())
