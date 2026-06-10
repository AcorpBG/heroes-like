#!/usr/bin/env python3
"""Verify the H3MapEd RMG source-record parser frontier.

This checkpoint bounds 0x4c025c, the helper used by the source payload
loader to populate a single 0x4c source record from the source/input stream.
It intentionally does not assign final object type/subtype/DEF identity.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
PAYLOAD_DUMP_DIR = ROOT / "ghidra_source_payload_producer_frontier_dump_20260610"
HELPER_DUMP_DIR = ROOT / "ghidra_source_payload_producer_helpers_dump_20260610"
STREAM_DUMP_DIR = ROOT / "ghidra_source_input_stream_helpers_dump_20260610"

CALLER_DUMP = PAYLOAD_DUMP_DIR / "target_0041f350_FUN_0041f350.txt"
PARSER_DUMP = HELPER_DUMP_DIR / "target_004c025c_FUN_004c025c.txt"
PARSER_REFERENCES = HELPER_DUMP_DIR / "target_004c025c_references.txt"
FIELD20_HELPER_DUMP = STREAM_DUMP_DIR / "caller_004b3419_FUN_004b3419.txt"
STREAM_HELPER_SUMMARY = ROOT / "source_input_stream_helper_summary_20260610.json"
NESTED_HELPER_SUMMARY = ROOT / "source_input_nested_container_summary_20260610.json"
DEFAULT_OUT = ROOT / "source_record_parser_summary_20260610.json"

CALLER_CHECKS = [
    {
        "id": "caller_copies_source_record_through_parser",
        "marker": "0041fab7: CALL 0x004c025c",
    },
]

REFERENCE_CHECKS = [
    {
        "id": "reference_from_source_payload_loader",
        "marker": "from=0041fab7 type=UNCONDITIONAL_CALL caller=FUN_0041f350",
    },
    {
        "id": "reference_from_sibling_parser_owner",
        "marker": "from=004c1950 type=UNCONDITIONAL_CALL caller=FUN_004c1938",
    },
    {
        "id": "parser_reads_global_stack_guard_or_frame_cookie",
        "marker": "at=004c025c type=DATA to=0052bee4",
    },
    {
        "id": "parser_calls_length_prefixed_blob_reader",
        "marker": "at=004c028a type=UNCONDITIONAL_CALL to=004190cb",
    },
    {
        "id": "parser_calls_blob_copy_helper",
        "marker": "at=004c029e type=UNCONDITIONAL_CALL to=004019a4",
    },
    {
        "id": "parser_calls_field20_bulk_reader",
        "marker": "at=004c02eb type=UNCONDITIONAL_CALL to=004b3419",
    },
    {
        "id": "parser_calls_byte_reader",
        "marker": "at=004c02f8 type=UNCONDITIONAL_CALL to=00402461",
    },
    {
        "id": "parser_calls_bitset_writer",
        "marker": "at=004c031a type=UNCONDITIONAL_CALL to=00416b35",
    },
    {
        "id": "parser_calls_bool_reader",
        "marker": "at=004c0334 type=UNCONDITIONAL_CALL to=0040763d",
    },
    {
        "id": "parser_calls_word_reader",
        "marker": "at=004c0364 type=UNCONDITIONAL_CALL to=0040237c",
    },
    {
        "id": "parser_calls_final_16_byte_reader",
        "marker": "at=004c0388 type=UNCONDITIONAL_CALL to=00438937",
    },
]

PARSER_CHECKS = [
    {"id": "parser_entry_cookie", "marker": "004c025c: MOV EAX,0x52bee4"},
    {"id": "parser_destination_record_ecx", "marker": "004c026e: MOV ESI,ECX"},
    {"id": "parser_initial_mode_byte", "marker": "004c0269: MOV AL,byte ptr [EBP + 0xf]"},
    {"id": "parser_stream_arg", "marker": "004c027f: MOV EDI,dword ptr [EBP + 0x8]"},
    {"id": "parser_first_blob_read", "marker": "004c028a: CALL 0x004190cb"},
    {"id": "parser_temp_blob_copy", "marker": "004c029e: CALL 0x004019a4"},
    {"id": "parser_second_blob_read", "marker": "004c02a8: CALL 0x004190cb"},
    {"id": "parser_version_or_limit_compare", "marker": "004c02b1: CMP EAX,dword ptr [0x00541460]"},
    {"id": "parser_0x12c_blob_limit", "marker": "004c02ba: MOV EAX,0x12c"},
    {"id": "parser_optional_blob_resize_or_copy", "marker": "004c02ce: CALL 0x00401aa7"},
    {"id": "parser_writes_blob_to_record_10", "marker": "004c02dc: LEA ECX,[ESI + 0x10]"},
    {"id": "parser_blob_copy_to_record_10", "marker": "004c02e1: CALL 0x004019a4"},
    {"id": "parser_prepares_record_20", "marker": "004c02e6: LEA EAX,[ESI + 0x20]"},
    {"id": "parser_field20_bulk_reader", "marker": "004c02eb: CALL 0x004b3419"},
    {"id": "parser_reads_one_mask_byte", "marker": "004c02f8: CALL 0x00402461"},
    {"id": "parser_bitset_base_record_3c", "marker": "004c0300: LEA EBX,[ESI + 0x3c]"},
    {"id": "parser_bit_loop_shift", "marker": "004c0309: SHL EAX,CL"},
    {"id": "parser_bit_loop_tests_mask_byte", "marker": "004c030b: TEST byte ptr [EBP + -0xd],AL"},
    {"id": "parser_bit_loop_bool", "marker": "004c030e: SETNZ AL"},
    {"id": "parser_bit_loop_writes_bitset", "marker": "004c031a: CALL 0x00416b35"},
    {"id": "parser_bit_loop_bound", "marker": "004c0322: CMP dword ptr [EBP + 0x8],0x8"},
    {"id": "parser_version_gate_1c", "marker": "004c0328: CMP dword ptr [EBP + 0xc],0x1c"},
    {"id": "parser_reads_optional_flag_40", "marker": "004c0334: CALL 0x0040763d"},
    {"id": "parser_writes_flag_40", "marker": "004c0340: MOV byte ptr [ESI + 0x40],AL"},
    {"id": "parser_defaults_flag_40", "marker": "004c0345: MOV byte ptr [ESI + 0x40],0x1"},
    {"id": "parser_reads_flag_41", "marker": "004c034f: CALL 0x0040763d"},
    {"id": "parser_writes_flag_41", "marker": "004c035d: MOV byte ptr [ESI + 0x41],AL"},
    {"id": "parser_reads_word_44", "marker": "004c0364: CALL 0x0040237c"},
    {"id": "parser_writes_signed_word_44", "marker": "004c036d: MOV dword ptr [ESI + 0x44],EAX"},
    {"id": "parser_reads_word_48", "marker": "004c0376: CALL 0x0040237c"},
    {"id": "parser_writes_signed_word_48", "marker": "004c037f: MOV dword ptr [ESI + 0x48],EAX"},
    {"id": "parser_reads_final_16_bytes", "marker": "004c0388: CALL 0x00438937"},
]

FIELD20_HELPER_CHECKS = [
    {"id": "field20_helper_reads_destination_arg", "marker": "004b341d: MOV ESI,dword ptr [EBP + 0xc]"},
    {"id": "field20_helper_loop_count_7", "marker": "004b3421: PUSH 0x7"},
    {"id": "field20_helper_reads_dword", "marker": "004b342b: CALL 0x00407675"},
    {"id": "field20_helper_writes_dword", "marker": "004b3433: MOV dword ptr [ESI],EAX"},
    {"id": "field20_helper_advances_destination", "marker": "004b3435: ADD ESI,0x4"},
    {"id": "field20_helper_loops", "marker": "004b3439: JNZ 0x004b3424"},
]

REQUIRED_SUMMARY_STATUSES = {
    STREAM_HELPER_SUMMARY: "source_input_stream_helper_surface_recovered_nested_semantics_pending",
    NESTED_HELPER_SUMMARY: "source_input_nested_container_surface_recovered_type_names_pending",
}


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""


def read_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def check_markers(path: Path, checks: list[dict[str, str]]) -> list[dict[str, Any]]:
    text = read_text(path)
    return [{**check, "present": check["marker"] in text} for check in checks]


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
    caller_checks = check_markers(CALLER_DUMP, CALLER_CHECKS)
    reference_checks = check_markers(PARSER_REFERENCES, REFERENCE_CHECKS)
    parser_checks = check_markers(PARSER_DUMP, PARSER_CHECKS)
    field20_helper_checks = check_markers(FIELD20_HELPER_DUMP, FIELD20_HELPER_CHECKS)
    summary_status_checks = [
        check_summary_status(path, expected) for path, expected in REQUIRED_SUMMARY_STATUSES.items()
    ]
    all_checks = caller_checks + reference_checks + parser_checks + field20_helper_checks
    missing = [check["id"] for check in all_checks if not check["present"]]
    missing_summary_statuses = [
        check["path"] for check in summary_status_checks if not check["matches"]
    ]
    recovered = not missing and not missing_summary_statuses
    return {
        "schema_id": "h3maped_rmg_source_record_parser_frontier_v1",
        "status": (
            "source_record_parser_surface_recovered_catalog_identity_pending"
            if recovered
            else "source_record_parser_surface_incomplete"
        ),
        "dumps": {
            "caller_0x41f350": str(CALLER_DUMP),
            "parser_0x4c025c": str(PARSER_DUMP),
            "parser_references_0x4c025c": str(PARSER_REFERENCES),
            "field20_helper_0x4b3419": str(FIELD20_HELPER_DUMP),
            "stream_helper_summary": str(STREAM_HELPER_SUMMARY),
            "nested_helper_summary": str(NESTED_HELPER_SUMMARY),
        },
        "marker_count": len(all_checks),
        "present_marker_count": sum(1 for check in all_checks if check["present"]),
        "missing_marker_ids": missing,
        "summary_status_checks": summary_status_checks,
        "missing_summary_status_paths": missing_summary_statuses,
        "caller_checks": caller_checks,
        "reference_checks": reference_checks,
        "parser_checks": parser_checks,
        "field20_helper_checks": field20_helper_checks,
        "recovered_boundary": {
            "0x4c025c": (
                "Consumes a source/input stream pointer and destination 0x4c source-record "
                "pointer, reads/copies a length-prefixed blob into record +0x10, populates "
                "seven dwords at record +0x20 through 0x4b3419, expands one read byte into "
                "an eight-bit bitset at record +0x3c, writes version-gated boolean flags "
                "at +0x40/+0x41, writes two signed word-derived dwords at +0x44/+0x48, "
                "and performs a final guarded 0x10-byte read into a local buffer."
            ),
            "0x4b3419": (
                "Loops seven times, each time reading a guarded dword with 0x407675 and "
                "writing it to the caller-supplied destination, so the record +0x20 group "
                "is a seven-dword stream-derived field group."
            ),
            "helper_context": (
                "Existing stream-helper and nested-container summaries recover the guarded "
                "reader helpers used by this parser, including guarded byte/word/dword reads, "
                "length-prefixed blobs, and the 0x416b35 bitset writer family."
            ),
        },
        "remaining_unrecovered": [
            "Human field names for source-record offsets +0x10, +0x20..+0x38, +0x3c, +0x40, +0x41, +0x44, and +0x48.",
            "Exact helper semantics for 0x4019a4 and 0x401aa7 beyond their observed copy/resize role in this parser.",
            "Whether the final local 0x10-byte read at 0x4c0388 is stored indirectly or only validates/consumes stream padding in later unwound code paths.",
            "The exact source catalog/template producer that maps parsed source records and nested payloads to objects.txt/objtmplt.txt type, subtype, and DEF rows.",
            "Human category/provider-slot semantics for the later variant/filter builders that consume these populated records.",
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
        "RMG_H3MAPED_SOURCE_RECORD_PARSER "
        f"status={summary['status']} "
        f"markers={summary['present_marker_count']}/{summary['marker_count']} "
        f"out={args.out}"
    )
    return 0 if summary["status"].endswith("_pending") else 1


if __name__ == "__main__":
    raise SystemExit(main())
