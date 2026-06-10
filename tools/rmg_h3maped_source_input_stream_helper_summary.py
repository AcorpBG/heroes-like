#!/usr/bin/env python3
"""Verify the H3MapEd RMG source-input stream-helper frontier.

This checkpoint sits below the 0x43b0ff versioned parser layout. It proves
the guarded stream-read primitives and classifies the structured payload
helpers that still need deeper recovery before source records can be mapped to
catalog rows.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DUMP_DIR = ROOT / "ghidra_source_input_stream_helpers_dump_20260610"
DEFAULT_OUT = ROOT / "source_input_stream_helper_summary_20260610.json"

FILES = {
    "read_byte_guard_a_0x40763d": DUMP_DIR / "target_0040763d_FUN_0040763d.txt",
    "read_byte_guard_b_0x402461": DUMP_DIR / "target_00402461_FUN_00402461.txt",
    "read_dword_guard_0x407675": DUMP_DIR / "target_00407675_FUN_00407675.txt",
    "length_prefixed_blob_0x4190cb": DUMP_DIR / "target_004190cb_FUN_004190cb.txt",
    "triple_byte_record_0x43acf0": DUMP_DIR / "target_0043acf0_FUN_0043acf0.txt",
    "tagged_record_0x43ad49": DUMP_DIR / "target_0043ad49_FUN_0043ad49.txt",
    "tagged_or_triple_record_0x43aec6": DUMP_DIR / "target_0043aec6_FUN_0043aec6.txt",
    "bitset_insert_0x43bb1b": DUMP_DIR / "target_0043bb1b_FUN_0043bb1b.txt",
    "bitset_insert_0x43bb58": DUMP_DIR / "target_0043bb58_FUN_0043bb58.txt",
    "range_bitset_insert_0x43bb95": DUMP_DIR / "target_0043bb95_FUN_0043bb95.txt",
    "fixed_0x9c_bitset_insert_0x43bbe1": DUMP_DIR / "target_0043bbe1_FUN_0043bbe1.txt",
    "fixed_0x80_bitset_insert_0x43bc24": DUMP_DIR / "target_0043bc24_FUN_0043bc24.txt",
    "range_bitset_insert_0x43bc67": DUMP_DIR / "target_0043bc67_FUN_0043bc67.txt",
}

REFERENCE_FILES = {
    "read_byte_guard_a_0x40763d": DUMP_DIR / "target_0040763d_references.txt",
    "read_byte_guard_b_0x402461": DUMP_DIR / "target_00402461_references.txt",
    "read_dword_guard_0x407675": DUMP_DIR / "target_00407675_references.txt",
    "length_prefixed_blob_0x4190cb": DUMP_DIR / "target_004190cb_references.txt",
}

CHECKS: dict[str, list[dict[str, str]]] = {
    "read_byte_guard_a_0x40763d": [
        {"id": "read_count_one", "marker": "00407646: PUSH 0x1"},
        {"id": "calls_virtual_reader", "marker": "0040764f: CALL dword ptr [EAX + 0x18]"},
        {"id": "requires_one_byte_returned", "marker": "00407652: CMP EAX,0x1"},
        {"id": "diagnostic_on_short_read", "marker": "00407669: CALL 0x004e633b"},
        {"id": "returns_stream_wrapper", "marker": "0040766e: MOV EAX,ESI"},
    ],
    "read_byte_guard_b_0x402461": [
        {"id": "read_count_one", "marker": "0040246a: PUSH 0x1"},
        {"id": "calls_virtual_reader", "marker": "00402473: CALL dword ptr [EAX + 0x18]"},
        {"id": "requires_one_byte_returned", "marker": "00402476: CMP EAX,0x1"},
        {"id": "diagnostic_on_short_read", "marker": "0040248d: CALL 0x004e633b"},
        {"id": "returns_stream_wrapper", "marker": "00402492: MOV EAX,ESI"},
    ],
    "read_dword_guard_0x407675": [
        {"id": "read_count_four", "marker": "0040767e: PUSH 0x4"},
        {"id": "calls_virtual_reader", "marker": "00407687: CALL dword ptr [EAX + 0x18]"},
        {"id": "requires_four_bytes_returned", "marker": "0040768a: CMP EAX,0x4"},
        {"id": "diagnostic_on_short_read", "marker": "004076a1: CALL 0x004e633b"},
        {"id": "returns_stream_wrapper", "marker": "004076a6: MOV EAX,ESI"},
    ],
    "length_prefixed_blob_0x4190cb": [
        {"id": "reads_dword_length", "marker": "0041910a: CALL 0x00407675"},
        {"id": "uses_0x200_chunk_limit", "marker": "0041912b: MOV EDI,0x200"},
        {"id": "reads_chunk_into_stack_buffer", "marker": "00419143: CALL 0x0041941a"},
        {"id": "loops_until_remaining_zero", "marker": "00419178: JNZ 0x0041912b"},
    ],
    "triple_byte_record_0x43acf0": [
        {"id": "reads_first_byte", "marker": "0043acfe: CALL 0x00402461"},
        {"id": "writes_first_dword", "marker": "0043ad0c: MOV dword ptr [ESI],EAX"},
        {"id": "reads_second_byte", "marker": "0043ad12: CALL 0x00402461"},
        {"id": "writes_second_dword", "marker": "0043ad1b: MOV dword ptr [ESI + 0x4],EAX"},
        {"id": "reads_third_byte", "marker": "0043ad24: CALL 0x00402461"},
        {"id": "writes_third_dword", "marker": "0043ad33: MOV dword ptr [ESI + 0x8],EAX"},
        {"id": "all_ff_normalizes_to_negative_one", "marker": "0043ad38: OR dword ptr [ESI],0xffffffff"},
    ],
    "tagged_record_0x43ad49": [
        {"id": "reads_tag_byte", "marker": "0043ad57: CALL 0x0040763d"},
        {"id": "stores_tag_dword", "marker": "0043ad66: MOV dword ptr [ESI],EAX"},
        {"id": "sentinel_minus_one_exit", "marker": "0043ad63: CMP EAX,-0x1"},
        {"id": "reads_bool_0x04", "marker": "0043ad74: CALL 0x0040763d"},
        {"id": "stores_bool_0x04", "marker": "0043ad82: MOV byte ptr [ESI + 0x4],AL"},
        {"id": "reads_bool_0x05", "marker": "0043ad89: CALL 0x0040763d"},
        {"id": "stores_bool_0x05", "marker": "0043ad95: MOV byte ptr [ESI + 0x5],AL"},
        {"id": "dispatches_tags_zero_to_ten", "marker": "0043ada3: JMP dword ptr [EAX*0x4 + 0x43ae9a]"},
    ],
    "tagged_or_triple_record_0x43aec6": [
        {"id": "reads_selector_byte", "marker": "0043aed4: CALL 0x0040763d"},
        {"id": "stores_selector_dword", "marker": "0043aee0: MOV dword ptr [ESI],EAX"},
        {"id": "selector_two_reads_word", "marker": "0043aef3: CALL 0x0040237c"},
        {"id": "selector_zero_or_one_reads_triple", "marker": "0043af06: CALL 0x0043acf0"},
    ],
    "bitset_insert_0x43bb1b": [
        {"id": "reads_bitset_source", "marker": "0043bb26: CALL 0x0043bf8f"},
        {"id": "iterates_shift_mask", "marker": "0043bb35: SHL EAX,CL"},
        {"id": "inserts_selected_bits", "marker": "0043bb4a: CALL 0x0042d05f"},
    ],
    "bitset_insert_0x43bb58": [
        {"id": "reads_bitset_source", "marker": "0043bb63: CALL 0x0043bfc7"},
        {"id": "iterates_shift_mask", "marker": "0043bb72: SHL EAX,CL"},
        {"id": "inserts_selected_bits", "marker": "0043bb87: CALL 0x00416b35"},
    ],
    "range_bitset_insert_0x43bb95": [
        {"id": "compares_start_pair", "marker": "0043bba6: CMP EBX,dword ptr [EBP + 0x14]"},
        {"id": "compares_end_pair", "marker": "0043bbab: CMP ESI,dword ptr [EBP + 0x18]"},
        {"id": "range_value_helper", "marker": "0043bbb9: CALL 0x00416b09"},
        {"id": "inserts_value", "marker": "0043bbc8: CALL 0x0042d05f"},
        {"id": "stores_output_cursor", "marker": "0043bbd9: MOV dword ptr [EAX + 0x4],EDI"},
    ],
    "fixed_0x9c_bitset_insert_0x43bbe1": [
        {"id": "reads_0x14_byte_source", "marker": "0043bbef: CALL 0x0043bfff"},
        {"id": "iterates_shift_mask", "marker": "0043bbfe: SHL EAX,CL"},
        {"id": "inserts_selected_bits", "marker": "0043bc13: CALL 0x0042d83c"},
        {"id": "fixed_bound_0x9c", "marker": "0043bc19: CMP ESI,0x9c"},
    ],
    "fixed_0x80_bitset_insert_0x43bc24": [
        {"id": "reads_0x10_byte_source", "marker": "0043bc32: CALL 0x00438937"},
        {"id": "iterates_shift_mask", "marker": "0043bc41: SHL EAX,CL"},
        {"id": "inserts_selected_bits", "marker": "0043bc56: CALL 0x0043bee8"},
        {"id": "fixed_bound_0x80", "marker": "0043bc5c: CMP ESI,0x80"},
    ],
    "range_bitset_insert_0x43bc67": [
        {"id": "compares_start_pair", "marker": "0043bc78: CMP EBX,dword ptr [EBP + 0x14]"},
        {"id": "compares_end_pair", "marker": "0043bc7d: CMP ESI,dword ptr [EBP + 0x18]"},
        {"id": "range_value_helper", "marker": "0043bc8b: CALL 0x0043beb9"},
        {"id": "inserts_value", "marker": "0043bc9a: CALL 0x0042d83c"},
        {"id": "stores_output_cursor", "marker": "0043bcab: MOV dword ptr [EAX + 0x4],EDI"},
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


def count_callers(path: Path) -> tuple[int, list[str]]:
    callers = []
    for line in read_text(path).splitlines():
        if not line.strip().startswith("from="):
            continue
        caller = "unknown"
        for part in line.split():
            if part.startswith("caller="):
                caller = part.split("=", 1)[1]
                break
        callers.append(caller)
    return len(callers), sorted(set(callers))


def summarize() -> dict[str, Any]:
    files = {key: summarize_file(key, path) for key, path in FILES.items()}
    all_checks = [check for result in files.values() for check in result["checks"]]
    missing = [check["id"] for check in all_checks if not check["present"]]
    reference_counts = {}
    reference_callers = {}
    for key, path in REFERENCE_FILES.items():
        count, callers = count_callers(path)
        reference_counts[key] = count
        reference_callers[key] = callers

    recovered = not missing
    return {
        "schema_id": "h3maped_rmg_source_input_stream_helper_frontier_v1",
        "status": "source_input_stream_helper_surface_recovered_nested_semantics_pending"
        if recovered
        else "source_input_stream_helper_surface_incomplete",
        "dump_dir": str(DUMP_DIR),
        "files": files,
        "marker_count": len(all_checks),
        "present_marker_count": sum(1 for check in all_checks if check["present"]),
        "missing_marker_ids": missing,
        "reference_counts": reference_counts,
        "reference_callers": reference_callers,
        "recovered_boundary": {
            "primitive_guards": {
                "0x40763d": "guarded one-byte read through source/input vtable +0x18",
                "0x402461": "second guarded one-byte read wrapper through source/input vtable +0x18",
                "0x407675": "guarded four-byte read through source/input vtable +0x18",
            },
            "structured_helpers": {
                "0x4190cb": "length-prefixed blob/vector copy using 0x407675 length and 0x200-byte chunks",
                "0x43acf0": "three one-byte values widened into dwords, with all-0xff sentinel normalized to -1 triplet",
                "0x43ad49": "tagged record with tag byte, two boolean bytes, and tag dispatch for 0..10",
                "0x43aec6": "selector record that either reads a word payload for selector 2 or delegates to 0x43acf0 for selector 0/1",
                "0x43bb1b/0x43bb58/0x43bb95/0x43bbe1/0x43bc24/0x43bc67": "bitset and range-to-container population helpers with fixed/ranged bounds",
            },
        },
        "remaining_unrecovered": [
            "Human names for the 0x43b0ff fields that consume each structured helper.",
            "Nested helper semantics below 0x4190cb, 0x43bb1b, 0x43bb58, 0x43bb95, 0x43bbe1, 0x43bc24, and 0x43bc67, including container type names.",
            "Exact meaning of the 0x43ad49 tag table entries 0..10.",
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
        "RMG_H3MAPED_SOURCE_INPUT_STREAM_HELPERS "
        f"status={summary['status']} "
        f"markers={summary['present_marker_count']}/{summary['marker_count']} "
        f"out={args.out}"
    )
    return 0 if summary["status"].endswith("_pending") else 1


if __name__ == "__main__":
    raise SystemExit(main())
