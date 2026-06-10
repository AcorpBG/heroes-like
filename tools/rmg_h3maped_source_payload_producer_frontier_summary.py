#!/usr/bin/env python3
"""Verify the current H3MapEd RMG source-payload producer frontier.

This checkpoint names the loader/constructor boundary for source-side object
payload records without claiming final object identity. It is intentionally
limited to Ghidra-exported evidence and existing Wine/Python summaries.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_OUT = ROOT / "source_payload_producer_frontier_summary_20260610.json"

FILES = {
    "source_loader_0x41f350": ROOT
    / "ghidra_source_payload_producer_frontier_dump_20260610"
    / "target_0041f350_FUN_0041f350.txt",
    "generic_dynamic_lookup_0x4e6da2": ROOT
    / "ghidra_source_payload_producer_frontier_dump_20260610"
    / "target_004e6da2_FUN_004e6da2.txt",
    "generic_dynamic_lookup_0x4e6da2_refs": ROOT
    / "ghidra_source_payload_producer_frontier_dump_20260610"
    / "target_004e6da2_references.txt",
    "holder_payload_accessor_0x42df99": ROOT
    / "ghidra_source_payload_producer_helpers_dump_20260610"
    / "target_0042df99_FUN_0042df99.txt",
    "holder_payload_accessor_0x42dd11": ROOT
    / "ghidra_source_payload_producer_helpers_dump_20260610"
    / "target_0042dd11_FUN_0042dd11.txt",
    "holder_payload_accessor_0x42dd3d": ROOT
    / "ghidra_source_payload_producer_helpers_dump_20260610"
    / "target_0042dd3d_FUN_0042dd3d.txt",
}

CHECKS: dict[str, list[dict[str, str]]] = {
    "source_loader_0x41f350": [
        {
            "id": "stores_source_object_primary_pointer",
            "marker": "0041f36b: MOV dword ptr [EBX],EAX",
            "meaning": "0x41f350 initializes the source object primary pointer.",
        },
        {
            "id": "stores_source_object_secondary_pointer",
            "marker": "0041f373: MOV dword ptr [EBX + 0x4],EAX",
            "meaning": "0x41f350 initializes the source object secondary pointer.",
        },
        {
            "id": "parses_input_source_blob",
            "marker": "0041f3cc: CALL 0x0043b0ff",
            "meaning": "The loader parses the caller-provided source/input blob before populating records.",
        },
        {
            "id": "maps_header_through_global_family_table",
            "marker": "0041f3e1: MOV ECX,0x535214",
            "meaning": "The parsed source header is matched against the global family table.",
        },
        {
            "id": "global_family_table_upper_bound",
            "marker": "0041f3f5: CMP EAX,0x535224",
            "meaning": "The global family table scan stops at 0x535224.",
        },
        {
            "id": "stores_resolved_family_index",
            "marker": "0041f404: MOV dword ptr [EBX + 0x8],EAX",
            "meaning": "The source object stores the resolved family/table index at +0x08.",
        },
        {
            "id": "stores_source_mode_byte",
            "marker": "0041f40f: MOV byte ptr [EBX + 0xc],AL",
            "meaning": "The source object stores the parsed mode byte at +0x0c.",
        },
        {
            "id": "writes_record_metadata_0x20",
            "marker": "0041f4aa: MOV dword ptr [EAX + 0x20],ECX",
            "meaning": "The loader writes copied source-record field +0x20.",
        },
        {
            "id": "writes_record_metadata_0x24",
            "marker": "0041f4ba: MOV dword ptr [EAX + 0x24],ECX",
            "meaning": "The loader writes copied source-record field +0x24.",
        },
        {
            "id": "uses_record_collection_iterator",
            "marker": "0041f4c7: CALL 0x004744b1",
            "meaning": "The loader iterates a source-side collection before nested record population.",
        },
        {
            "id": "indexes_0x4c_source_records_first_path",
            "marker": "0041f7f5: IMUL EAX,EAX,0x4c",
            "meaning": "The loader indexes 0x4c-byte source records.",
        },
        {
            "id": "indexes_0x4c_source_records_second_path",
            "marker": "0041f969: IMUL EAX,EAX,0x4c",
            "meaning": "A second path indexes the same 0x4c-byte source-record layout.",
        },
        {
            "id": "copies_0x4c_records_to_destination",
            "marker": "0041fab7: CALL 0x004c025c",
            "meaning": "The loader copies populated 0x4c-byte records into the destination vector.",
        },
        {
            "id": "uses_dynamic_lookup_first_variant",
            "marker": "0041f8f7: CALL 0x004e6da2",
            "meaning": "The loader performs a generic dynamic lookup/cast for one nested payload variant.",
        },
        {
            "id": "uses_dynamic_lookup_second_variant",
            "marker": "0041f9a7: CALL 0x004e6da2",
            "meaning": "The loader performs a generic dynamic lookup/cast for another nested payload variant.",
        },
        {
            "id": "dispatches_record_variant_builder",
            "marker": "0041f818: CALL 0x00428d45",
            "meaning": "The loader dispatches a still-unrecovered variant/filter builder.",
        },
    ],
    "generic_dynamic_lookup_0x4e6da2": [
        {
            "id": "normalizes_dynamic_source",
            "marker": "004e6de5: CALL 0x004e6eee",
            "meaning": "0x4e6da2 is a generic dynamic lookup/cast helper, not a source-record producer.",
        },
        {
            "id": "uses_first_lookup_branch",
            "marker": "004e6e17: CALL 0x004e6f08",
            "meaning": "The helper selects one generic lookup branch.",
        },
        {
            "id": "uses_second_lookup_branch",
            "marker": "004e6e2c: CALL 0x004e6f62",
            "meaning": "The helper selects another generic lookup branch.",
        },
        {
            "id": "uses_third_lookup_branch",
            "marker": "004e6e33: CALL 0x004e705b",
            "meaning": "The helper selects a third generic lookup branch.",
        },
        {
            "id": "finalizes_dynamic_result",
            "marker": "004e6e47: CALL 0x004e7193",
            "meaning": "Successful dynamic lookup result is finalized outside source identity semantics.",
        },
    ],
    "holder_payload_accessor_0x42df99": [
        {
            "id": "ensures_unique_holder",
            "marker": "0042dfa3: CALL 0x004337d5",
            "meaning": "The helper clones/ensures unique holder state when shared.",
        },
        {
            "id": "returns_holder_payload_plus_0x04",
            "marker": "0042dfab: ADD EAX,0x4",
            "meaning": "The helper returns the holder payload base at +0x04.",
        },
    ],
    "holder_payload_accessor_0x42dd11": [
        {
            "id": "ensures_unique_holder",
            "marker": "0042dd1b: CALL 0x00432def",
            "meaning": "The helper clones/ensures unique holder state when shared.",
        },
        {
            "id": "returns_holder_payload_plus_0x04",
            "marker": "0042dd23: ADD EAX,0x4",
            "meaning": "The helper returns the holder payload base at +0x04.",
        },
    ],
    "holder_payload_accessor_0x42dd3d": [
        {
            "id": "ensures_unique_holder",
            "marker": "0042dd47: CALL 0x00432f7e",
            "meaning": "The helper clones/ensures unique holder state when shared.",
        },
        {
            "id": "returns_holder_payload_plus_0x04",
            "marker": "0042dd4f: ADD EAX,0x4",
            "meaning": "The helper returns the holder payload base at +0x04.",
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


def count_ghidra_reference_lines(path: Path) -> int:
    text = read_text(path)
    return sum(1 for line in text.splitlines() if "instruction=CALL 0x004e6da2" in line)


def summarize() -> dict[str, Any]:
    files = {key: summarize_file(key, path) for key, path in FILES.items()}
    all_checks = [check for result in files.values() for check in result["checks"]]
    missing = [check["id"] for check in all_checks if not check["present"]]
    reference_count = count_ghidra_reference_lines(FILES["generic_dynamic_lookup_0x4e6da2_refs"])
    recovered = not missing and reference_count >= 50

    return {
        "schema_id": "h3maped_rmg_source_payload_producer_frontier_v1",
        "status": (
            "source_payload_loader_boundary_recovered_catalog_semantics_pending"
            if recovered
            else "source_payload_loader_boundary_incomplete"
        ),
        "files": files,
        "marker_count": len(all_checks),
        "present_marker_count": sum(1 for check in all_checks if check["present"]),
        "missing_marker_ids": missing,
        "generic_dynamic_lookup_reference_count": reference_count,
        "recovered_boundary": {
            "loader": "0x41f350",
            "loader_role": (
                "source object and source-record loader/constructor for the payload family "
                "later consumed through 0x42a83a and copied as 0x4c source records"
            ),
            "proved": [
                "0x41f350 initializes source object +0x00/+0x04 plus derived family index +0x08 and mode byte +0x0c.",
                "0x41f350 parses caller input through 0x43b0ff and maps the parsed family token through 0x535214..0x535224.",
                "0x41f350 writes source-record fields +0x20 and +0x24 and iterates/copies 0x4c-byte source records.",
                "0x42df99 and sibling 0x42ddxx helpers are holder payload accessors that copy-on-write when shared and return payload+0x04.",
                "0x4e6da2 is a generic dynamic lookup/cast helper with many callers, not the source catalog identity producer.",
            ],
        },
        "remaining_unrecovered": [
            "Exact input/source parse semantics inside 0x43b0ff and 0x433d7d.",
            "Exact variant/filter semantics of 0x422868, 0x428d45, 0x420e6b, 0x434073, and related calls from 0x41f350.",
            "The final mapping from populated 0x4c records and nested payload variants to objects.txt/objtmplt.txt type, subtype, and DEF rows.",
            "Source-backed selected descriptor/source evidence for mixed lanes 45, 53, 54, and 79.",
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
        "RMG_H3MAPED_SOURCE_PAYLOAD_PRODUCER_FRONTIER "
        f"status={summary['status']} "
        f"markers={summary['present_marker_count']}/{summary['marker_count']} "
        f"generic_refs={summary['generic_dynamic_lookup_reference_count']} "
        f"out={args.out}"
    )
    return 0 if not summary["missing_marker_ids"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
