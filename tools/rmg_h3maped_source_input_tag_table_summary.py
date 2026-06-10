#!/usr/bin/env python3
"""Verify the H3MapEd RMG source-input 0x43ad49 tag table frontier.

This checkpoint recovers the local dispatch table and payload shapes for the
tagged source-input helper. It intentionally stops short of assigning human
domain names to the tag values.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DUMP_DIR = ROOT / "ghidra_source_input_tag_table_dump_20260610"
STREAM_DUMP_DIR = ROOT / "ghidra_source_input_stream_helpers_dump_20260610"
TABLE_JSON = DUMP_DIR / "table_0043ae9a.json"
RANGE_DUMP = DUMP_DIR / "range_0043adaa_0043ae95.txt"
TAGGED_READER_DUMP = STREAM_DUMP_DIR / "target_0043ad49_FUN_0043ad49.txt"
DEFAULT_OUT = ROOT / "source_input_tag_table_summary_20260610.json"

EXPECTED_TABLE = {
    0: "0x43adaa",
    1: "0x43add8",
    2: "0x43ae1c",
    3: "0x43ae41",
    4: "0x43ae73",
    5: "0x43ae73",
    6: "0x43ae73",
    7: "0x43ae73",
    8: "0x43ae96",
    9: "0x43ae96",
    10: "0x43ae78",
}

TAGGED_READER_CHECKS = [
    {"id": "reads_tag_byte", "marker": "0043ad57: CALL 0x0040763d"},
    {"id": "stores_tag_dword", "marker": "0043ad66: MOV dword ptr [ESI],EAX"},
    {"id": "sentinel_minus_one_returns", "marker": "0043ad68: JZ 0x0043ae96"},
    {"id": "reads_bool_04", "marker": "0043ad74: CALL 0x0040763d"},
    {"id": "stores_bool_04", "marker": "0043ad82: MOV byte ptr [ESI + 0x4],AL"},
    {"id": "reads_bool_05", "marker": "0043ad89: CALL 0x0040763d"},
    {"id": "stores_bool_05", "marker": "0043ad95: MOV byte ptr [ESI + 0x5],AL"},
    {"id": "bounds_tags_zero_to_ten", "marker": "0043ad9a: CMP EAX,0xa"},
    {"id": "dispatch_table", "marker": "0043ada3: JMP dword ptr [EAX*0x4 + 0x43ae9a]"},
]

RANGE_CHECKS = [
    {"id": "tag0_version_0x15_gate", "marker": "0043adaa: CMP dword ptr [EBP + 0x10],0x15"},
    {"id": "tag0_new_word_read", "marker": "0043adb6: CALL 0x0040237c"},
    {"id": "tag0_new_writes_plus_08", "marker": "0043adbf: MOV dword ptr [ESI + 0x8],EAX"},
    {"id": "tag0_old_byte_read", "marker": "0043adcd: CALL 0x0040763d"},
    {"id": "tag1_version_0x14_gate", "marker": "0043add8: CMP dword ptr [EBP + 0x10],0x14"},
    {"id": "tag1_new_word_read", "marker": "0043ade4: CALL 0x0040237c"},
    {"id": "tag1_old_byte_read", "marker": "0043adf8: CALL 0x00402461"},
    {"id": "tag1_ff_normalizes_to_minus_one", "marker": "0043ae08: OR dword ptr [ESI + 0x8],0xffffffff"},
    {"id": "tag1_reads_dword_payload", "marker": "0043ae12: CALL 0x00407675"},
    {"id": "tag1_writes_plus_0c", "marker": "0043ae3c: MOV dword ptr [ESI + 0xc],EAX"},
    {"id": "tag2_reads_byte_payload", "marker": "0043ae22: CALL 0x0040763d"},
    {"id": "tag2_writes_plus_08", "marker": "0043ae2b: MOV dword ptr [ESI + 0x8],EAX"},
    {"id": "tag2_reads_dword_payload", "marker": "0043ae34: CALL 0x00407675"},
    {"id": "tag3_reads_triplet", "marker": "0043ae46: CALL 0x0043acf0"},
    {"id": "tag3_reads_plus_14_byte", "marker": "0043ae53: CALL 0x0040763d"},
    {"id": "tag3_writes_plus_14", "marker": "0043ae5c: MOV dword ptr [ESI + 0x14],EAX"},
    {"id": "tag3_reads_plus_18_byte", "marker": "0043ae65: CALL 0x0040763d"},
    {"id": "tag3_writes_plus_18", "marker": "0043ae6e: MOV dword ptr [ESI + 0x18],EAX"},
    {"id": "tags4_to_7_shift_output_plus_08", "marker": "0043ae73: ADD ESI,0x8"},
    {"id": "tags4_to_7_read_triplet", "marker": "0043ae8f: CALL 0x0043acf0"},
    {"id": "tag10_reads_byte_payload", "marker": "0043ae7e: CALL 0x00402461"},
    {"id": "tag10_writes_plus_08", "marker": "0043ae87: MOV dword ptr [ESI + 0x8],EAX"},
    {"id": "tag10_shift_output_plus_0c", "marker": "0043ae8a: ADD ESI,0xc"},
    {"id": "tag10_reads_triplet", "marker": "0043ae8f: CALL 0x0043acf0"},
]


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""


def load_table() -> dict[int, str]:
    if not TABLE_JSON.exists():
        return {}
    data = json.loads(TABLE_JSON.read_text(encoding="utf-8"))
    return {int(entry["index"]): entry["value"].lower() for entry in data.get("entries", [])}


def check_markers(path: Path, checks: list[dict[str, str]]) -> list[dict[str, Any]]:
    text = read_text(path)
    return [{**check, "present": check["marker"] in text} for check in checks]


def summarize() -> dict[str, Any]:
    table = load_table()
    table_checks = [
        {
            "id": f"tag_{index}_target",
            "index": index,
            "expected": expected,
            "actual": table.get(index),
            "present": table.get(index) == expected,
        }
        for index, expected in EXPECTED_TABLE.items()
    ]
    tagged_reader_checks = check_markers(TAGGED_READER_DUMP, TAGGED_READER_CHECKS)
    range_checks = check_markers(RANGE_DUMP, RANGE_CHECKS)
    all_checks = table_checks + tagged_reader_checks + range_checks
    missing = [check["id"] for check in all_checks if not check["present"]]
    recovered = not missing
    return {
        "schema_id": "h3maped_rmg_source_input_tag_table_frontier_v1",
        "status": "source_input_tag_table_payload_surface_recovered_human_meanings_pending"
        if recovered
        else "source_input_tag_table_payload_surface_incomplete",
        "table_json": str(TABLE_JSON),
        "range_dump": str(RANGE_DUMP),
        "tagged_reader_dump": str(TAGGED_READER_DUMP),
        "marker_count": len(all_checks),
        "present_marker_count": sum(1 for check in all_checks if check["present"]),
        "missing_marker_ids": missing,
        "table_entries": table_checks,
        "tagged_reader_checks": tagged_reader_checks,
        "range_checks": range_checks,
        "recovered_boundary": {
            "common_header": "tag byte at +0x00, two boolean bytes at +0x04/+0x05, -1 tag returns with no extra payload",
            "tag_payloads": {
                "0": "version-gated scalar at +0x08: word for version >= 0x15, signed byte otherwise",
                "1": "version-gated scalar at +0x08: word for version >= 0x14, unsigned byte otherwise with 0xff normalized to -1; then dword at +0x0c",
                "2": "signed byte at +0x08 and dword at +0x0c",
                "3": "three-byte triplet at +0x08, signed byte at +0x14, signed byte at +0x18",
                "4": "three-byte triplet at +0x08",
                "5": "same payload shape as tag 4",
                "6": "same payload shape as tag 4",
                "7": "same payload shape as tag 4",
                "8": "no extra payload beyond common header",
                "9": "no extra payload beyond common header",
                "10": "unsigned byte at +0x08 and three-byte triplet at +0x0c",
            },
        },
        "remaining_unrecovered": [
            "Human meaning of tag values 0..10.",
            "Human names for output fields +0x08, +0x0c, +0x14, and +0x18.",
            "Final mapping from tagged payloads into populated 0x4c source records and objects.txt/objtmplt.txt rows.",
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
        "RMG_H3MAPED_SOURCE_INPUT_TAG_TABLE "
        f"status={summary['status']} "
        f"markers={summary['present_marker_count']}/{summary['marker_count']} "
        f"out={args.out}"
    )
    return 0 if summary["status"].endswith("_pending") else 1


if __name__ == "__main__":
    raise SystemExit(main())
