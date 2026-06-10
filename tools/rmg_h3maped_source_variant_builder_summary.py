#!/usr/bin/env python3
"""Verify the H3MapEd RMG source variant/filter builder frontier.

This checkpoint bounds the helper surface called from the source payload
loader at 0x41f350. It intentionally stops short of assigning human object
category names or source-catalog identities to the recovered category values
and provider slots.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
FRONTIER_DUMP_DIR = ROOT / "ghidra_source_payload_producer_frontier_dump_20260610"
HELPER_DUMP_DIR = ROOT / "ghidra_source_payload_producer_helpers_dump_20260610"
CALLER_DUMP = FRONTIER_DUMP_DIR / "target_0041f350_FUN_0041f350.txt"
DISPATCH_BUILDER_DUMP = HELPER_DUMP_DIR / "target_00422868_FUN_00422868.txt"
RANGE_PREDICATE_DUMP = HELPER_DUMP_DIR / "target_00428d45_FUN_00428d45.txt"
DYNAMIC_INSERTER_DUMP = HELPER_DUMP_DIR / "target_00420e6b_FUN_00420e6b.txt"
DYNAMIC_WRAPPER_DUMP = HELPER_DUMP_DIR / "target_00434073_FUN_00434073.txt"
DEFAULT_OUT = ROOT / "source_variant_builder_summary_20260610.json"

CALLER_CHECKS = [
    {"id": "caller_first_category_dispatch_builder", "marker": "0041f800: CALL 0x00422868"},
    {"id": "caller_range_mask_predicate", "marker": "0041f818: CALL 0x00428d45"},
    {"id": "caller_dynamic_lookup_wrapper", "marker": "0041f8d4: CALL 0x00434073"},
    {"id": "caller_range_gate_low", "marker": "0041f971: CMP ECX,0x22"},
    {"id": "caller_range_gate_high", "marker": "0041f976: CMP ECX,0x46"},
    {"id": "caller_second_category_dispatch_builder", "marker": "0041f98d: CALL 0x00422868"},
    {"id": "caller_dynamic_lookup_inserter", "marker": "0041f9bb: CALL 0x00420e6b"},
]

DISPATCH_BUILDER_CHECKS = [
    {"id": "dispatch_reads_source_record_arg", "marker": "00422888: MOV EAX,dword ptr [EBP + 0xc]"},
    {"id": "dispatch_reads_category_field_1c", "marker": "0042288e: MOV ECX,dword ptr [EAX + 0x1c]"},
    {"id": "dispatch_compares_category_4d", "marker": "00422894: CMP ECX,0x4d"},
    {"id": "dispatch_compares_category_2a", "marker": "004228a3: CMP ECX,0x2a"},
    {"id": "dispatch_compares_category_1a", "marker": "004228b2: CMP ECX,0x1a"},
    {"id": "dispatch_compares_category_45", "marker": "00422b07: CMP ECX,0x45"},
    {"id": "dispatch_compares_category_46", "marker": "00422c14: CMP ECX,0x46"},
    {"id": "dispatch_compares_category_71", "marker": "00422ca9: CMP ECX,0x71"},
    {"id": "dispatch_compares_category_a2", "marker": "004230cb: CMP ECX,0xa2"},
    {"id": "dispatch_compares_category_35", "marker": "004233b8: CMP ECX,0x35"},
    {"id": "dispatch_provider_slot_ac", "marker": "004228f1: CALL dword ptr [EDX + 0xac]"},
    {"id": "dispatch_appends_candidate", "marker": "00422921: CALL 0x00412041"},
    {"id": "dispatch_releases_candidate_temp", "marker": "00422929: CALL 0x0042bfe6"},
    {"id": "dispatch_cleans_temp_a", "marker": "00422938: CALL 0x0042c913"},
    {"id": "dispatch_cleans_temp_b", "marker": "00422afd: CALL 0x004c6488"},
    {"id": "dispatch_provider_slot_bc", "marker": "0042352e: CALL dword ptr [EDX + 0xbc]"},
    {"id": "dispatch_final_append", "marker": "00423561: CALL 0x00412041"},
    {"id": "dispatch_final_release", "marker": "00423569: CALL 0x0042bfe6"},
    {"id": "dispatch_cleans_temp_c", "marker": "00423578: CALL 0x0042c8d9"},
    {"id": "dispatch_non_null_result_gate", "marker": "00423582: JNZ 0x004235af"},
    {"id": "dispatch_null_result_diagnostic", "marker": "004235aa: CALL 0x004e633b"},
    {"id": "dispatch_writes_output_present_byte", "marker": "004235bf: MOV byte ptr [ESI],CL"},
    {"id": "dispatch_writes_output_pointer", "marker": "004235c1: MOV dword ptr [ESI + 0x4],EAX"},
    {"id": "dispatch_final_accumulator_cleanup", "marker": "004235ca: CALL 0x0042bfe6"},
]

RANGE_PREDICATE_CHECKS = [
    {"id": "range_reads_lower_bound_40", "marker": "00428d59: MOV ECX,dword ptr [EAX + 0x40]"},
    {"id": "range_reads_upper_bound_44", "marker": "00428d72: MOV EDX,dword ptr [EAX + 0x44]"},
    {"id": "range_checks_global_table_low", "marker": "00428d66: CMP EDX,dword ptr [EDI*0x4 + 0x535214]"},
    {"id": "range_checks_global_table_high", "marker": "00428d82: CMP EDI,dword ptr [EBX*0x4 + 0x535214]"},
    {"id": "range_calls_descriptor_mask_predicate", "marker": "00428dbe: CALL 0x0041e915"},
    {"id": "range_returns_true", "marker": "00428dea: MOV AL,0x1"},
    {"id": "range_returns_false", "marker": "00428de1: XOR AL,AL"},
]

DYNAMIC_INSERTER_CHECKS = [
    {"id": "inserter_reads_mode_byte", "marker": "00420e75: CMP byte ptr [EBP + 0xc],BL"},
    {"id": "inserter_selects_holder_family", "marker": "00420e7d: MOV ECX,dword ptr [EDI + 0x18]"},
    {"id": "inserter_copy_on_write_if_shared", "marker": "00420e8d: CALL 0x00432d56"},
    {"id": "inserter_queries_holder_payload", "marker": "00420e9a: CALL 0x0042a70f"},
    {"id": "inserter_first_dynamic_lookup", "marker": "00420eac: CALL 0x004e6da2"},
    {"id": "inserter_applies_lookup_result", "marker": "00420ebb: CALL 0x004c242d"},
    {"id": "inserter_second_dynamic_lookup", "marker": "00420ed3: CALL 0x004e6da2"},
    {"id": "inserter_existing_payload_delegate", "marker": "00420ee8: CALL 0x00428439"},
    {"id": "inserter_missing_payload_delegate", "marker": "00420ef7: CALL 0x004284d0"},
]

DYNAMIC_WRAPPER_CHECKS = [
    {"id": "wrapper_dynamic_lookup", "marker": "0043408a: CALL 0x004e6da2"},
    {"id": "wrapper_zero_result_branch", "marker": "00434094: JZ 0x004340a6"},
    {"id": "wrapper_existing_result_delegate", "marker": "0043409f: CALL 0x0042825d"},
    {"id": "wrapper_missing_result_delegate", "marker": "004340b3: CALL 0x004389a7"},
]


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""


def check_markers(path: Path, checks: list[dict[str, str]]) -> list[dict[str, Any]]:
    text = read_text(path)
    return [{**check, "present": check["marker"] in text} for check in checks]


def summarize() -> dict[str, Any]:
    caller_checks = check_markers(CALLER_DUMP, CALLER_CHECKS)
    dispatch_builder_checks = check_markers(DISPATCH_BUILDER_DUMP, DISPATCH_BUILDER_CHECKS)
    range_predicate_checks = check_markers(RANGE_PREDICATE_DUMP, RANGE_PREDICATE_CHECKS)
    dynamic_inserter_checks = check_markers(DYNAMIC_INSERTER_DUMP, DYNAMIC_INSERTER_CHECKS)
    dynamic_wrapper_checks = check_markers(DYNAMIC_WRAPPER_DUMP, DYNAMIC_WRAPPER_CHECKS)
    all_checks = (
        caller_checks
        + dispatch_builder_checks
        + range_predicate_checks
        + dynamic_inserter_checks
        + dynamic_wrapper_checks
    )
    missing = [check["id"] for check in all_checks if not check["present"]]
    recovered = not missing
    return {
        "schema_id": "h3maped_rmg_source_variant_builder_frontier_v1",
        "status": "source_variant_builder_surface_recovered_category_semantics_pending"
        if recovered
        else "source_variant_builder_surface_incomplete",
        "dumps": {
            "caller": str(CALLER_DUMP),
            "category_dispatch_builder_0x422868": str(DISPATCH_BUILDER_DUMP),
            "range_mask_predicate_0x428d45": str(RANGE_PREDICATE_DUMP),
            "dynamic_lookup_inserter_0x420e6b": str(DYNAMIC_INSERTER_DUMP),
            "dynamic_lookup_wrapper_0x434073": str(DYNAMIC_WRAPPER_DUMP),
        },
        "marker_count": len(all_checks),
        "present_marker_count": sum(1 for check in all_checks if check["present"]),
        "missing_marker_ids": missing,
        "caller_checks": caller_checks,
        "dispatch_builder_checks": dispatch_builder_checks,
        "range_predicate_checks": range_predicate_checks,
        "dynamic_inserter_checks": dynamic_inserter_checks,
        "dynamic_wrapper_checks": dynamic_wrapper_checks,
        "recovered_boundary": {
            "0x41f350_builder_calls": [
                "0x422868 is called twice from the source payload loader.",
                "0x428d45 is called as a bounded source-family range/mask predicate.",
                "0x434073 is called as a dynamic lookup wrapper.",
                "0x420e6b is called after the 0x22..0x46 caller-side range gate.",
            ],
            "0x422868": (
                "Reads source record +0x1c as a category/lane selector, dispatches through "
                "category constants and global provider vtable slots, accumulates provider "
                "results with 0x412041, requires a non-null accumulated result, and writes "
                "an output present byte plus pointer."
            ),
            "0x428d45": (
                "Reads source-family bounds from input +0x40/+0x44, checks them against "
                "global table 0x535214, and calls descriptor mask predicate 0x41e915 before "
                "returning true or false."
            ),
            "0x420e6b": (
                "Selects one of two holder families from +0x18 by caller mode byte, clones "
                "shared holder state, performs dynamic lookups through 0x4e6da2, applies the "
                "first lookup through 0x4c242d, and delegates existing/missing payload paths "
                "to 0x428439 or 0x4284d0."
            ),
            "0x434073": (
                "Wraps a dynamic lookup through 0x4e6da2 and delegates existing-result and "
                "missing-result paths to 0x42825d or 0x4389a7."
            ),
        },
        "remaining_unrecovered": [
            "Human names for source record +0x1c category/lane values used by 0x422868.",
            "Human meanings of global provider vtable slots used by 0x422868.",
            "Exact final mapping from parsed source-input fields and populated 0x4c source records into objects.txt/objtmplt.txt type, subtype, and DEF rows.",
            "Dynamic lookup helper internals below 0x4e6da2/0x4c242d only where needed for final source-catalog identity.",
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
        "RMG_H3MAPED_SOURCE_VARIANT_BUILDER "
        f"status={summary['status']} "
        f"markers={summary['present_marker_count']}/{summary['marker_count']} "
        f"out={args.out}"
    )
    return 0 if summary["status"].endswith("_pending") else 1


if __name__ == "__main__":
    raise SystemExit(main())
