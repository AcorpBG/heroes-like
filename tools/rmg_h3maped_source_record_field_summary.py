#!/usr/bin/env python3
"""Verify the recovered H3MapEd 0x4c source-record field surface.

This is a recovery checkpoint only. It records what the current Ghidra exports
and Wine relation-builder summary prove about copied 0x4c source records. It
does not authorize native RMG behavior changes and does not turn descriptor
words into final object-template identities.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_DESCRIPTOR_DUMP = ROOT / "ghidra_descriptor_source_resolver_dump_20260610"
DEFAULT_RELATION_DUMP = ROOT / "ghidra_4a93a2_connection_record_append_dump"
DEFAULT_DESCRIPTOR_SUMMARY = ROOT / "descriptor_source_resolver_summary_20260610.json"
DEFAULT_RELATION_SUMMARY = ROOT / "relation_builder_runtime_summary.json"
DEFAULT_OUT = ROOT / "source_record_field_surface_summary_20260610.json"


FILES = {
    "descriptor_source_bucket_builder_0x49da08": DEFAULT_DESCRIPTOR_DUMP
    / "target_0049da08_FUN_0049da08.txt",
    "source_record_descriptor_resolver_0x4af785": DEFAULT_DESCRIPTOR_DUMP
    / "target_004af785_FUN_004af785.txt",
    "source_row_mode_mask_selector_0x4af89f": DEFAULT_DESCRIPTOR_DUMP
    / "target_004af89f_FUN_004af89f.txt",
    "candidate_descriptor_selector_0x4a9e40": DEFAULT_DESCRIPTOR_DUMP
    / "target_004a9e40_FUN_004a9e40.txt",
    "relation_branch_dispatcher_0x4a8d2c": DEFAULT_RELATION_DUMP
    / "caller_004a8d2c_FUN_004a8d2c.txt",
    "relation_builder_0x4a93a2": DEFAULT_RELATION_DUMP / "target_004a93a2_FUN_004a93a2.txt",
}


CHECKS: dict[str, list[dict[str, str]]] = {
    "descriptor_source_bucket_builder_0x49da08": [
        {
            "id": "walks_records_at_0x4c_stride",
            "marker": "0049dadd: ADD EBX,0x4c",
            "meaning": "The source stream is walked as fixed 0x4c-byte records.",
        },
        {
            "id": "sorts_wrapper_backing_source_by_0x20",
            "marker": "0049db35: CMP EBX,dword ptr [EDI + 0x20]",
            "meaning": "Existing wrapper backing records are ordered/compared by source record +0x20.",
        },
    ],
    "source_record_descriptor_resolver_0x4af785": [
        {
            "id": "reads_source_lane_0x1c",
            "marker": "004af7a7: MOV EAX,dword ptr [ESI + 0x1c]",
            "meaning": "Source record +0x1c selects the resolver lane/table bucket.",
        },
        {
            "id": "reads_source_metadata_0x20",
            "marker": "004af7a0: MOV EAX,dword ptr [ESI + 0x20]",
            "meaning": "Source record +0x20 participates in wrapper reuse/matching.",
        },
        {
            "id": "matches_existing_wrapper_source_0x20",
            "marker": "004af7ed: CMP dword ptr [EAX + 0x20],ECX",
            "meaning": "Wrapper reuse requires the backing source record +0x20 metadata to match.",
        },
        {
            "id": "allocates_source_record_copy_size_0x4c",
            "marker": "004af811: PUSH 0x4c",
            "meaning": "Unmatched source records are copied into a new 0x4c record.",
        },
        {
            "id": "copies_source_record_body",
            "marker": "004af822: MOVSD.REP ES:EDI,ESI",
            "meaning": "The resolver copies the source record, rather than synthesizing a native object category.",
        },
    ],
    "source_row_mode_mask_selector_0x4af89f": [
        {
            "id": "mask_words_begin_at_0x18",
            "marker": "004af8a7: LEA EDI,[EAX + 0x18]",
            "meaning": "Source record mask words used for lane/mode selection begin at +0x18.",
        },
    ],
    "candidate_descriptor_selector_0x4a9e40": [
        {
            "id": "selector_reads_backing_source_0x20",
            "marker": "004a9e8a: MOV ECX,dword ptr [EAX + 0x20]",
            "meaning": "Candidate selection filters wrappers through backing source record +0x20.",
        },
        {
            "id": "selector_reads_backing_source_0x24",
            "marker": "004a9e92: MOV ECX,dword ptr [EAX + 0x24]",
            "meaning": "Candidate selection also filters through backing source record +0x24.",
        },
        {
            "id": "selector_scans_mask_words_at_0x18",
            "marker": "004a9ea3: LEA EDI,[EAX + 0x18]",
            "meaning": "Candidate selection reuses source mask words starting at +0x18.",
        },
    ],
    "relation_branch_dispatcher_0x4a8d2c": [
        {
            "id": "loads_wrapper_backing_source_record",
            "marker": "004a8d38: MOV ESI,dword ptr [EDI]",
            "meaning": "The relation branch dispatcher consumes wrapper +0x00 as the backing source record.",
        },
        {
            "id": "source_lane_indexes_generator_ee4",
            "marker": "004a8d47: MOV ECX,dword ptr [EBX + ECX*0x4 + 0xee4]",
            "meaning": "Source record +0x1c is used to index generator +0xee4 relation/lane state.",
        },
        {
            "id": "positive_source_0x24_enables_relation_call",
            "marker": "004a8d43: CMP dword ptr [ESI + 0x24],0x0",
            "meaning": "Positive source record +0x24 gates the first enabled relation-builder call.",
        },
        {
            "id": "positive_source_0x20_enables_relation_call",
            "marker": "004a8d63: CMP dword ptr [ESI + 0x20],0x0",
            "meaning": "Positive source record +0x20 gates the second relation-builder call.",
        },
        {
            "id": "positive_source_0x34_enables_relation_call",
            "marker": "004a8d7d: CMP dword ptr [ESI + 0x34],0x0",
            "meaning": "Positive source record +0x34 gates an enabled relation-builder call with index -1.",
        },
        {
            "id": "positive_source_0x30_enables_relation_call",
            "marker": "004a8d96: CMP dword ptr [ESI + 0x30],0x0",
            "meaning": "Positive source record +0x30 gates a disabled relation-builder call with index -1.",
        },
    ],
    "relation_builder_0x4a93a2": [
        {
            "id": "rejects_index_negative_one",
            "marker": "004a93af: CMP dword ptr [EBP + 0xc],-0x1",
            "meaning": "Relation builder calls with index -1 return false immediately in this function.",
        },
        {
            "id": "source_record_argument_loaded",
            "marker": "004a93c1: MOV EDX,dword ptr [EBP + 0x8]",
            "meaning": "The builder receives the source/wrapper record pointer as its first stack argument.",
        },
        {
            "id": "copies_source_group_0x10_to_local",
            "marker": "004a93cd: LEA ESI,[EDX + 0x10]",
            "meaning": "The builder copies the source record field group beginning at +0x10 into locals.",
        },
        {
            "id": "copies_source_group_0x20_to_local",
            "marker": "004a93e2: LEA ESI,[EDX + 0x20]",
            "meaning": "The builder copies the source record field group beginning at +0x20 into locals.",
        },
        {
            "id": "marks_source_record_0x3c",
            "marker": "004a95a4: MOV byte ptr [EAX + 0x3c],0x1",
            "meaning": "Successful relation building marks source record byte +0x3c.",
        },
        {
            "id": "reads_relation_source_state_0x28",
            "marker": "004a95d7: MOV ECX,dword ptr [EAX + 0x28]",
            "meaning": "Successful relation building reads source/related record state at +0x28.",
        },
        {
            "id": "writes_relation_source_state_0x28",
            "marker": "004a95e6: MOV dword ptr [EAX + 0x28],ECX",
            "meaning": "Successful relation building clears bit26 and sets bit27 in source/related record +0x28.",
        },
    ],
}


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def summarize_file(key: str, path: Path) -> dict[str, Any]:
    text = read_text(path)
    checks = []
    for check in CHECKS[key]:
        checks.append({**check, "present": check["marker"] in text})
    return {
        "path": str(path),
        "exists": path.exists(),
        "check_count": len(checks),
        "present_check_count": sum(1 for check in checks if check["present"]),
        "checks": checks,
    }


def summarize(
    descriptor_summary_path: Path,
    relation_summary_path: Path,
) -> dict[str, Any]:
    files = {key: summarize_file(key, path) for key, path in FILES.items()}
    descriptor_summary = read_json(descriptor_summary_path)
    relation_summary = read_json(relation_summary_path)
    all_checks = [check for result in files.values() for check in result["checks"]]
    missing = [check["id"] for check in all_checks if not check["present"]]
    relation_invariants = relation_summary.get("invariants", {})
    descriptor_invariants = descriptor_summary.get("invariants", {})

    relation_required = {
        "builder_entry_hit_eight_times": relation_invariants.get("builder_entry_hit_eight_times") is True,
        "append_builder_hit_eight_times": relation_invariants.get("append_builder_hit_eight_times")
        is True,
        "source_flag_write_hit_eight_times": relation_invariants.get(
            "source_flag_write_hit_eight_times"
        )
        is True,
        "source_route_state_write_hit_eight_times": relation_invariants.get(
            "source_route_state_write_hit_eight_times"
        )
        is True,
    }
    descriptor_required = {
        "descriptor_source_resolver_complete": descriptor_summary.get("status")
        == "descriptor_source_resolver_boundary_recovered_source_catalog_identity_pending",
        "descriptor_wrapper_points_to_source_record": descriptor_invariants.get(
            "wrapper_initializer_recovered"
        )
        is True,
    }

    status = (
        "source_record_field_surface_recovered_identity_mapping_pending"
        if not missing and all(relation_required.values()) and all(descriptor_required.values())
        else "incomplete"
    )
    return {
        "schema_id": "h3maped_source_record_field_surface_summary_v1",
        "status": status,
        "scope": (
            "Ghidra/Wine checkpoint for copied 0x4c source-record field usage. "
            "This is source recovery, not native RMG implementation."
        ),
        "inputs": {
            "descriptor_summary": str(descriptor_summary_path),
            "relation_summary": str(relation_summary_path),
            "ghidra_files": {key: str(path) for key, path in FILES.items()},
        },
        "files": files,
        "relation_required_invariants": relation_required,
        "descriptor_required_invariants": descriptor_required,
        "metrics": {
            "marker_count": len(all_checks),
            "present_marker_count": sum(1 for check in all_checks if check["present"]),
            "missing_marker_count": len(missing),
            "used_objdump": False,
            "native_behavior_changed": False,
            "overall_goal_complete": False,
        },
        "recovered_field_surface": [
            "0x4c source records are copied before wrapper construction; wrappers keep the backing source record pointer at wrapper +0x00.",
            "Source record +0x18 starts the mask-word surface used by resolver and selector code.",
            "Source record +0x1c is a resolver/relation lane index and is used to index generator +0xee4.",
            "Source record +0x20 and +0x24 participate in wrapper selection, sorting/reuse, and positive branch gating.",
            "Source record +0x30 and +0x34 are additional positive branch gates for relation-builder calls with index -1.",
            "0x4a93a2 copies field groups beginning at source record +0x10 and +0x20, and successful relation building marks +0x3c plus mutates a related +0x28 bit-state word.",
        ],
        "remaining_gap": (
            "The recovered field surface still does not prove final object identity for every copied "
            "0x4c source record. The remaining blocker is the source-catalog/object-template producer "
            "mapping that ties these records to exact type/subtype/DEF rows, especially mixed "
            "descriptor lanes 45/53/54/79 where descriptor +0x00 is not a universal row pointer."
        ),
        "native_behavior_changed": False,
        "used_objdump": False,
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--descriptor-summary", type=Path, default=DEFAULT_DESCRIPTOR_SUMMARY)
    parser.add_argument("--relation-summary", type=Path, default=DEFAULT_RELATION_SUMMARY)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args.descriptor_summary, args.relation_summary)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    metrics = summary["metrics"]
    print(
        "RMG_H3MAPED_SOURCE_RECORD_FIELD_SURFACE "
        f"status={summary['status']} "
        f"markers={metrics['present_marker_count']}/{metrics['marker_count']} "
        f"out={args.out}"
    )
    return 0 if summary["status"] == "source_record_field_surface_recovered_identity_mapping_pending" else 1


if __name__ == "__main__":
    raise SystemExit(main())
