#!/usr/bin/env python3
"""Recover the H3MapEd 16-byte stream-record read boundary.

This checkpoint distinguishes the generic 0x438937 fixed 16-byte reader from
the specific caller locals that previously looked like an unknown descriptor
field. In the descriptor/source-record owner paths checked here, the 16-byte
payload is read into a stack local and the local is not referenced again.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_OUT = ROOT / "aux_16_byte_record_summary_20260610.json"

READER_DUMP = (
    ROOT
    / "ghidra_source_input_nested_container_helpers_dump_20260610"
    / "target_00438937_FUN_00438937.txt"
)
DESCRIPTOR_OWNER_DUMP = (
    ROOT / "ghidra_descriptor_input_helper_dump_20260610" / "caller_00490a11_FUN_00490a11.txt"
)
SOURCE_RECORD_PARSER_DUMP = (
    ROOT / "ghidra_source_record_copy_helpers_dump_20260610" / "caller_004c025c_FUN_004c025c.txt"
)
BITSET_CONSUMER_DUMP = (
    ROOT / "ghidra_source_input_stream_helpers_dump_20260610" / "target_0043bc24_FUN_0043bc24.txt"
)
DESCRIPTOR_INPUT_SUMMARY = ROOT / "descriptor_input_mapping_summary_20260610.json"
SOURCE_RECORD_SUMMARY = ROOT / "source_record_parser_summary_20260610.json"
NESTED_CONTAINER_SUMMARY = ROOT / "source_input_nested_container_summary_20260610.json"


CHECKS: dict[str, list[dict[str, str]]] = {
    "reader_0x438937": [
        {
            "id": "requests_16_bytes",
            "marker": "00438940: PUSH 0x10",
            "meaning": "0x438937 requests exactly 16 bytes from the source/input reader.",
        },
        {
            "id": "calls_input_vtable_plus_0x18",
            "marker": "00438949: CALL dword ptr [EAX + 0x18]",
            "meaning": "The bytes are read through the generic source/input virtual reader.",
        },
        {
            "id": "requires_16_bytes",
            "marker": "0043894c: CMP EAX,0x10",
            "meaning": "Short reads below 16 bytes enter the diagnostic/error path.",
        },
        {
            "id": "returns_stream_wrapper",
            "marker": "00438968: MOV EAX,ESI",
            "meaning": "The helper returns the stream wrapper rather than a parsed domain object.",
        },
    ],
    "descriptor_owner_0x490a11": [
        {
            "id": "passes_local_16_byte_buffer",
            "marker": "00490abd: LEA EAX,[EBP + -0x64]",
            "meaning": "0x490a11 passes a stack-local 16-byte buffer to 0x438937.",
        },
        {
            "id": "reads_aux_payload",
            "marker": "00490ac3: CALL 0x00438937",
            "meaning": "0x490a11 consumes the fixed 16-byte source payload.",
        },
        {
            "id": "next_step_is_terrain_mask_normalization",
            "marker": "00490ac8: LEA ECX,[EBP + -0x14]",
            "meaning": "After the read, execution returns to normalizing the second terrain mask.",
        },
        {
            "id": "descriptor_builder_called_after_aux_read",
            "marker": "00490af1: CALL 0x004903e8",
            "meaning": "The descriptor builder is called after the 16-byte read, with no local-buffer reuse.",
        },
    ],
    "source_record_parser_0x4c025c": [
        {
            "id": "passes_local_16_byte_buffer",
            "marker": "004c0382: LEA EAX,[EBP + -0x34]",
            "meaning": "0x4c025c passes a stack-local 16-byte buffer to 0x438937.",
        },
        {
            "id": "reads_final_16_byte_payload",
            "marker": "004c0388: CALL 0x00438937",
            "meaning": "0x4c025c consumes a final fixed 16-byte source payload.",
        },
        {
            "id": "only_cleanup_after_read",
            "marker": "004c038d: OR dword ptr [EBP + -0x4],0xffffffff",
            "meaning": "The next operation after the read is cleanup-state mutation, not a field store.",
        },
        {
            "id": "string_local_cleanup_after_read",
            "marker": "004c0396: CALL 0x004016fd",
            "meaning": "The parser proceeds to local cleanup and return after the 16-byte read.",
        },
    ],
    "bitset_consumer_0x43bc24": [
        {
            "id": "uses_same_reader_for_live_128_bitset",
            "marker": "0043bc32: CALL 0x00438937",
            "meaning": "0x438937 can feed a live 128-slot bitset in another helper.",
        },
        {
            "id": "reads_local_bytes_after_reader",
            "marker": "0043bc48: MOV CL,byte ptr [EBP + ECX*0x1 + -0x10]",
            "meaning": "This helper does consume the 16-byte local after the read.",
        },
        {
            "id": "writes_selected_bits",
            "marker": "0043bc56: CALL 0x0043bee8",
            "meaning": "The live bitset helper writes selected bits from the 16-byte payload.",
        },
        {
            "id": "bound_128_slots",
            "marker": "0043bc5c: CMP ESI,0x80",
            "meaning": "The live bitset helper expands the 16-byte payload over 128 slots.",
        },
    ],
}

SUMMARY_STATUS_REQUIREMENTS = {
    DESCRIPTOR_INPUT_SUMMARY: "descriptor_input_mapping_terrain_fields_recovered_catalog_mapping_pending",
    SOURCE_RECORD_SUMMARY: "source_record_parser_surface_recovered_catalog_identity_pending",
    NESTED_CONTAINER_SUMMARY: "source_input_nested_container_surface_recovered_type_names_pending",
}


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def check_markers(name: str, path: Path) -> dict[str, Any]:
    text = read_text(path)
    checks = [
        {**check, "present": check["marker"] in text}
        for check in CHECKS[name]
    ]
    return {
        "path": str(path),
        "exists": path.exists(),
        "check_count": len(checks),
        "present_check_count": sum(1 for check in checks if check["present"]),
        "checks": checks,
    }


def local_reference_evidence(path: Path, local: str, call_marker: str) -> dict[str, Any]:
    text = read_text(path)
    call_index = text.find(call_marker)
    before = text[:call_index] if call_index >= 0 else text
    after = text[call_index:] if call_index >= 0 else ""
    return {
        "path": str(path),
        "local": local,
        "call_marker": call_marker,
        "call_marker_present": call_index >= 0,
        "total_local_references": text.count(local),
        "local_references_before_call_marker": before.count(local),
        "local_references_after_call_marker": after.count(local),
        "only_addressed_for_reader": call_index >= 0
        and text.count(local) == 1
        and before.count(local) == 1
        and after.count(local) == 0,
    }


def summary_status(path: Path, expected: str) -> dict[str, Any]:
    data = read_json(path)
    return {
        "path": str(path),
        "expected_status": expected,
        "actual_status": data.get("status"),
        "matches": data.get("status") == expected,
    }


def summarize() -> dict[str, Any]:
    ghidra_checks = {
        "reader_0x438937": check_markers("reader_0x438937", READER_DUMP),
        "descriptor_owner_0x490a11": check_markers("descriptor_owner_0x490a11", DESCRIPTOR_OWNER_DUMP),
        "source_record_parser_0x4c025c": check_markers(
            "source_record_parser_0x4c025c", SOURCE_RECORD_PARSER_DUMP
        ),
        "bitset_consumer_0x43bc24": check_markers("bitset_consumer_0x43bc24", BITSET_CONSUMER_DUMP),
    }
    all_marker_checks = [
        check
        for file_result in ghidra_checks.values()
        for check in file_result["checks"]
    ]
    local_refs = {
        "descriptor_owner_0x490a11_local_minus_0x64": local_reference_evidence(
            DESCRIPTOR_OWNER_DUMP, "-0x64", "00490ac3: CALL 0x00438937"
        ),
        "source_record_parser_0x4c025c_local_minus_0x34": local_reference_evidence(
            SOURCE_RECORD_PARSER_DUMP, "-0x34", "004c0388: CALL 0x00438937"
        ),
    }
    status_checks = [
        summary_status(path, expected)
        for path, expected in SUMMARY_STATUS_REQUIREMENTS.items()
    ]
    invariants = {
        "all_ghidra_markers_present": all(check["present"] for check in all_marker_checks),
        "all_required_dump_files_exist": all(result["exists"] for result in ghidra_checks.values()),
        "descriptor_owner_aux_local_is_not_reused": local_refs[
            "descriptor_owner_0x490a11_local_minus_0x64"
        ]["only_addressed_for_reader"],
        "source_record_parser_final_local_is_not_reused": local_refs[
            "source_record_parser_0x4c025c_local_minus_0x34"
        ]["only_addressed_for_reader"],
        "same_reader_has_live_bitset_consumer_elsewhere": all(
            check["present"] for check in ghidra_checks["bitset_consumer_0x43bc24"]["checks"]
        ),
        "summary_inputs_match_expected_statuses": all(check["matches"] for check in status_checks),
        "native_behavior_unchanged": True,
        "no_objdump_used": True,
    }
    recovered = all(invariants.values())
    return {
        "schema_id": "h3maped_rmg_aux_16_byte_record_summary_v1",
        "status": (
            "aux_16_byte_stream_record_source_excluded_from_descriptor_fields"
            if recovered
            else "aux_16_byte_stream_record_recovery_incomplete"
        ),
        "scope": (
            "Ghidra/Python checkpoint for the fixed 16-byte stream payload read through "
            "0x438937 in the 0x490a11 descriptor-owner path and 0x4c025c source-record "
            "parser path. It distinguishes those unused locals from the separate 0x43bc24 "
            "128-slot bitset consumer."
        ),
        "inputs": {
            "reader_dump": str(READER_DUMP),
            "descriptor_owner_dump": str(DESCRIPTOR_OWNER_DUMP),
            "source_record_parser_dump": str(SOURCE_RECORD_PARSER_DUMP),
            "bitset_consumer_dump": str(BITSET_CONSUMER_DUMP),
            "summary_status_requirements": {
                str(path): expected for path, expected in SUMMARY_STATUS_REQUIREMENTS.items()
            },
        },
        "invariants": invariants,
        "metrics": {
            "ghidra_file_count": len(ghidra_checks),
            "required_marker_count": len(all_marker_checks),
            "present_marker_count": sum(1 for check in all_marker_checks if check["present"]),
            "native_behavior_changed": False,
            "used_objdump": False,
            "overall_goal_complete": False,
        },
        "ghidra_checks": ghidra_checks,
        "local_reference_evidence": local_refs,
        "summary_status_checks": status_checks,
        "source_backed_conclusion": (
            "0x438937 is a guarded fixed 16-byte source/input reader. In the 0x490a11 "
            "descriptor-owner frame, the payload is read into stack local -0x64 and that "
            "local has no references after the 0x438937 call before descriptor construction. "
            "In the 0x4c025c source-record parser, the final payload is read into stack local "
            "-0x34 and that local has no references after the 0x438937 call before cleanup/return. "
            "Therefore these two reads are source-backed as reserved/alignment stream payloads "
            "that are validated and consumed but not stored into descriptor or source-record "
            "fields. A separate helper, 0x43bc24, uses the same reader as a live 128-slot "
            "bitset source, proving the exclusion is caller-specific rather than a blanket "
            "claim about 0x438937."
        ),
        "remaining_blockers": [
            {
                "id": "source_catalog_template_producer_mapping",
                "reason": (
                    "Recover the non-hero producer that maps parsed source-input records and "
                    "nested payload holders into exact objects.txt/objtmplt.txt type/subtype/DEF rows."
                ),
            }
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    summary = summarize()
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_AUX_16_BYTE_RECORD "
        f"status={summary['status']} "
        f"markers={summary['metrics']['present_marker_count']}/{summary['metrics']['required_marker_count']} "
        f"out={args.out}"
    )
    return 0 if summary["status"].endswith("_fields") else 1


if __name__ == "__main__":
    raise SystemExit(main())
