#!/usr/bin/env python3
"""Summarize recovered H3MapEd compact connection-record fields.

This is a recovery checkpoint, not a native RMG behavior change. It names the
human-readable surface around record byte +0x09 and records the remaining
downstream replay gaps explicitly.
"""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_SCAN = DEFAULT_ROOT / "connection_record_offset_access_scan.txt"
DEFAULT_GATE = DEFAULT_ROOT / "7605_branch_gate_summary.json"
DEFAULT_OUT = DEFAULT_ROOT / "connection_record_field_summary.json"
DEFAULT_PRODUCER_STATIC = DEFAULT_ROOT / "connection_record_producer_static_summary.json"
DEFAULT_DESCRIPTOR_CATEGORY = DEFAULT_ROOT / "medium_descriptor_category_surface_summary_20260608.json"
DEFAULT_NATURAL_BG = (
    DEFAULT_ROOT / "medium_seed10_hc1_co1_border_guard_seed_pinned_summary_20260609.json"
)
DEFAULT_BG_FOLLOWTHROUGH = (
    DEFAULT_ROOT / "medium_seed10_hc1_co1_border_guard_followthrough_seed_pinned_summary_20260609.json"
)
DEFAULT_CURSOR_LIFETIME = DEFAULT_ROOT / "medium_cursor_lifetime_summary_20260608.json"

DEFAULT_49B3FB_DUMP = DEFAULT_ROOT / "ghidra_private_state_dump/target_0049b3fb_FUN_0049b3fb.txt"
DEFAULT_4A4C8E_DUMP = DEFAULT_ROOT / "ghidra_private_state_expanded_dump/target_004a4c8e_FUN_004a4c8e.txt"
DEFAULT_4A4FC5_DUMP = DEFAULT_ROOT / "ghidra_private_state_expanded_dump/target_004a4fc5_FUN_004a4fc5.txt"
DEFAULT_4A79A3_DUMP = (
    DEFAULT_ROOT / "ghidra_coord12_candidate_vector_helper_dump/caller_004a79a3_FUN_004a79a3.txt"
)


RMG_OFFSET_9_READERS = {
    "004a6386": "0x4a61bc: checks compact record +0x09 before optional connection work",
    "004a646d": "0x4a61bc: copies compact record +0x09 into a local decision byte",
    "004a64a4": "0x4a61bc: copies compact record +0x09 into a local decision byte",
    "004a64e7": "0x4a61bc: checks compact record +0x09 before optional connection work",
    "004a6c78": "0x4a696b: checks compact record +0x09 before optional endpoint work",
    "004a7100": "0x4a6cf2: checks compact record +0x09 before optional endpoint work",
    "004a774a": "0x4a7605: first post-0x4a7312 endpoint-writer gate",
    "004a783a": "0x4a7605: second post-0x4a7312 endpoint-writer gate",
}

RMG_OFFSET_A_SITES = {
    "004a7bc7": "0x4a79a3: skip records already marked processed/paired",
    "004a7c0d": "0x4a79a3: mark first record processed",
    "004a7c2b": "0x4a79a3: mark first record processed",
    "004a7c2f": "0x4a79a3: mark paired record processed",
    "004a7cb5": "0x4a79a3: scan for unprocessed compact records",
    "004a7dd0": "0x4a79a3: skip records already marked processed/paired",
    "004a7e03": "0x4a79a3: mark first record processed",
    "004a7e21": "0x4a79a3: mark first record processed",
    "004a7e25": "0x4a79a3: mark paired record processed",
}


SCAN_RE = re.compile(
    r"^(?P<address>[0-9a-f]{8})\toffset=(?P<offset>0x[0-9a-f]+)\t"
    r"access=(?P<access>[a-z_]+)\tfunction=(?P<function>[^\t]+)\t"
    r"entry=(?P<entry>[^\t]+)\tinstruction=(?P<instruction>.+)$"
)


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8") if path.exists() else ""


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def contains_all(text: str, needles: list[str]) -> bool:
    return all(needle in text for needle in needles)


def parse_scan(path: Path) -> list[dict[str, str]]:
    entries: list[dict[str, str]] = []
    for line in read_text(path).splitlines():
        match = SCAN_RE.match(line)
        if match:
            entries.append(match.groupdict())
    return entries


def summarize_scan(entries: list[dict[str, str]]) -> dict[str, Any]:
    offset_counts = Counter(entry["offset"] for entry in entries)
    access_counts = Counter((entry["offset"], entry["access"]) for entry in entries)
    offset9 = [entry for entry in entries if entry["offset"] == "0x9"]
    offset9_writers = [
        entry for entry in offset9 if entry["access"] in {"write", "read_write"} and "[EBP + 0x9]" not in entry["instruction"]
    ]
    rmg_offset9_readers = [
        {**entry, "meaning": RMG_OFFSET_9_READERS[entry["address"]]}
        for entry in offset9
        if entry["address"] in RMG_OFFSET_9_READERS
    ]
    rmg_offseta_sites = [
        {**entry, "meaning": RMG_OFFSET_A_SITES[entry["address"]]}
        for entry in entries
        if entry["address"] in RMG_OFFSET_A_SITES
    ]
    return {
        "scan_path": str(DEFAULT_SCAN),
        "entry_count": len(entries),
        "offset_counts": dict(sorted(offset_counts.items())),
        "access_counts": {
            f"{offset}:{access}": count for (offset, access), count in sorted(access_counts.items())
        },
        "known_rmg_offset_9_readers": rmg_offset9_readers,
        "known_rmg_offset_a_processed_marker_sites": rmg_offseta_sites,
        "non_stack_offset_9_writer_candidates": offset9_writers,
    }


def summarize(
    scan_path: Path,
    gate_path: Path,
    producer_static_path: Path,
    descriptor_category_path: Path,
    natural_bg_path: Path,
    bg_followthrough_path: Path,
    cursor_lifetime_path: Path,
    dump_49b3fb: Path,
    dump_4a4c8e: Path,
    dump_4a4fc5: Path,
    dump_4a79a3: Path,
) -> dict[str, Any]:
    scan_entries = parse_scan(scan_path)
    scan = summarize_scan(scan_entries)
    gate = read_json(gate_path)
    producer_static = read_json(producer_static_path)
    descriptor_category = read_json(descriptor_category_path)
    natural_bg = read_json(natural_bg_path)
    bg_followthrough = read_json(bg_followthrough_path)
    cursor_lifetime = read_json(cursor_lifetime_path)
    text_49b3fb = read_text(dump_49b3fb)
    text_4a4c8e = read_text(dump_4a4c8e)
    text_4a4fc5 = read_text(dump_4a4fc5)
    text_4a79a3 = read_text(dump_4a79a3)
    selected_relation_control = (
        descriptor_category.get("recovered_surfaces", {}).get("selected_relation_control_surface", {})
    )
    border_guard_counts = selected_relation_control.get("border_guard_flag_plus_09_counts", {})
    border_guard_record_count = int(
        selected_relation_control.get("border_guard_relation_record_count", 0)
    )

    invariants = {
        "offset_scan_exists": scan_path.exists() and bool(scan_entries),
        "lookup_helper_scans_generator_c8_cc_stride_1c": contains_all(
            text_49b3fb,
            [
                "0049b404: MOV EDI,dword ptr [ECX + 0xc8]",
                "0049b411: MOV EAX,dword ptr [ECX + 0xcc]",
                "0049b417: PUSH 0x1c",
                "0049b43c: IMUL ESI,ESI,0x1c",
                "0049b431: CMP EAX,dword ptr [EBP + 0x8]",
            ],
        ),
        "route_shaper_reads_record_plus_8_mode": contains_all(
            text_4a4c8e,
            [
                "004a4daf: CALL 0x0049b3fb",
                "004a4dc6: CMP byte ptr [EAX + 0x8],0x0",
            ],
        ),
        "secondary_route_shaper_uses_lookup_helper": "004a517a: CALL 0x0049b3fb" in text_4a4fc5,
        "dispatcher_marks_plus_a_processed": contains_all(
            text_4a79a3,
            [
                "004a7bc7: CMP byte ptr [ESI + 0xa],0x0",
                "004a7c0d: MOV byte ptr [ESI + 0xa],0x1",
                "004a7e21: MOV byte ptr [ESI + 0xa],0x1",
                "004a7e25: MOV byte ptr [EAX + 0xa],0x1",
            ],
        ),
        "known_rmg_plus_9_sites_are_reads": bool(scan["known_rmg_offset_9_readers"])
        and all(entry["access"] == "read" for entry in scan["known_rmg_offset_9_readers"]),
        "sampled_7605_gate_zero_skips_746b": gate.get("status")
        == "partial_live_recovery_7605_control_byte_gate_skips_746b",
        "plus9_source_meaning_recovered_as_border_guard_flag": (
            descriptor_category.get("status") == "descriptor_category_surfaces_separated"
            and border_guard_record_count > 0
            and int(border_guard_counts.get("1", 0)) > 0
            and "Border Guard" in selected_relation_control.get("meaning_recovered", "")
        ),
        "natural_plus9_branch_reaches_5e73_under_seed_control": (
            natural_bg.get("status") == "natural_border_guard_branch_reaches_5e73_but_cursor_unseeded"
            and natural_bg.get("invariants", {}).get("natural_border_guard_branch_observed") is True
            and natural_bg.get("invariants", {}).get("generated_cell_mutation_not_reached") is True
        ),
        "natural_plus9_followthrough_falls_back_to_7605_5e03": (
            bg_followthrough.get("status")
            == "border_guard_endpoint_failures_followed_by_7605_5e03_materialization"
            and bg_followthrough.get("invariants", {}).get(
                "post_border_guard_7605_4a5e03_calls_observed"
            )
            is True
        ),
        "cursor_lifetime_explains_stale_f5c_failures": (
            cursor_lifetime.get("status") == "cursor_lifetime_f58_zero_f5c_unseeded"
            and cursor_lifetime.get("invariants", {}).get(
                "natural_border_guard_failure_uses_same_stale_f5c"
            )
            is True
        ),
        "no_native_behavior_change": True,
    }

    writer_candidates = scan["non_stack_offset_9_writer_candidates"]
    status = "recovered_connection_record_plus9_border_guard_surface" if all(invariants.values()) else "incomplete"
    return {
        "schema_id": "h3maped_connection_record_field_summary_v1",
        "status": status,
        "invariants": invariants,
        "source_artifacts": {
            "offset_scan": str(scan_path),
            "gate_summary": str(gate_path),
            "producer_static_summary": str(producer_static_path),
            "descriptor_category_surface": str(descriptor_category_path),
            "natural_border_guard_seed_pinned": str(natural_bg_path),
            "border_guard_followthrough": str(bg_followthrough_path),
            "cursor_lifetime": str(cursor_lifetime_path),
            "dump_49b3fb": str(dump_49b3fb),
            "dump_4a4c8e": str(dump_4a4c8e),
            "dump_4a4fc5": str(dump_4a4fc5),
            "dump_4a79a3": str(dump_4a79a3),
        },
        "compact_record_family": {
            "vector_owner": "generator/context",
            "vector_begin": "generator+0xc8",
            "vector_end": "generator+0xcc",
            "stride_bytes": 28,
            "lookup_helper": "0x49b3fb",
            "lookup_key": (
                "0x49b3fb scans the 0x1c-byte compact records and compares the first dword "
                "pointed to by each slot against the requested relation/source id."
            ),
            "human_domain": (
                "These records are connection/zone-relation recipes consumed by route and endpoint "
                "stamping code. Current evidence does not tie +0x09 to map size, water, underground, "
                "island mode, or terrain type."
            ),
        },
        "recovered_fields": {
            "+0x08": {
                "working_name": "connection_recipe.adjacency_stamp_mode_or_required_mark",
                "evidence": [
                    "0x4a4c8e calls 0x49b3fb for a neighboring relation/source id.",
                    "If the lookup returns a record and byte +0x08 is zero, 0x4a4c8e sets its local route-stamp flag.",
                ],
                "confidence": "medium_consumer_only",
            },
            "+0x09": {
                "working_name": "connection_recipe.border_guard_endpoint_stamping_enabled",
                "evidence": [
                    "0x4a61bc, 0x4a696b, 0x4a6cf2, and 0x4a7605 read this byte in connection dispatch/endpoint paths.",
                    "The sampled 0x4a7605 run saw byte +0x09 == 0 at both gates and skipped both 0x4a746b endpoint-writer call sites.",
                    "The known RMG +0x09 sites found by the full Ghidra scan are reads, not writes.",
                    "0x49f7c4 relation-builder output and selected-relation scans recover byte +0x09 as the template connection Border Guard flag.",
                    "Clean seed-pinned Medium seed-10 traces naturally reach the +0x09 Border Guard branch, then fail stale-cursor 0x4a5e73 attempts and continue through 0x4a7605 -> 0x4a5e03 fallback materialization.",
                ],
                "source_producer": {
                    "function": "0x49f7c4",
                    "source_row_field": "+0x140",
                    "source_row_name": "Border Guard",
                    "record_byte": "+0x09",
                },
                "confidence": "high_source_and_consumer_surface",
            },
            "+0x0a": {
                "working_name": "connection_recipe.processed_or_paired_marker",
                "evidence": [
                    "0x4a79a3 tests +0x0a before dispatching records.",
                    "0x4a79a3 writes +0x0a = 1 on one or both paired records after dispatch.",
                ],
                "confidence": "high_consumer_side_bookkeeping",
            },
        },
        "offset_access_scan": scan,
        "writer_recovery": {
            "producer_status": "recovered_for_0x49f7c4_relation_records",
            "only_non_stack_plus9_writer_candidate": (
                writer_candidates[0] if len(writer_candidates) == 1 else None
            ),
            "candidate_classification": (
                "0x4b3c03 copies bytes +0x08/+0x09 from a 12-byte local record returned by a vtable "
                "slot into a caller output record. It is a serialization/copy adapter candidate, not "
                "the semantic producer of the RMG compact connection record until the owning caller and "
                "vtable source are tied to generator+0xc8/+0xcc."
            ),
            "recovered_semantic_producer": {
                "function": "0x49f7c4 owner-pair relation builder",
                "record_stride_bytes": 28,
                "field_mapping": {
                    "connection_row+0x13c": "Wide -> relation/control byte +0x08",
                    "connection_row+0x140": "Border Guard -> relation/control byte +0x09",
                    "relation/control byte +0x0a": "cleared before reciprocal append; later processed/pair marker",
                },
                "selected_relation_evidence": selected_relation_control,
            },
            "static_followup": {
                "status": producer_static.get("status", "missing"),
                "classification": producer_static.get("candidate", {}).get("classification"),
                "result": producer_static.get("human_readable_result"),
                "next_recovery_target": producer_static.get("next_recovery_target"),
            },
        },
        "recovered_contract": (
            "Byte +0x09 is the template connection Border Guard flag for recovered 0x49f7c4 "
            "relation records. When it is zero, the sampled 0x4a7605 path performs direct "
            "0x4a7312 endpoint placement but skips delegated 0x4a746b/0x4a5e73 endpoint/corridor "
            "stamping. When it is one in the clean seed-10 Medium sample, H3MapEd naturally "
            "attempts three Border Guard endpoint pairs, all six 0x4a5e73 calls fail on stale "
            "generator+0xf5c, and generation then continues through 0x4a7605 -> 0x4a5e03 fallback "
            "materialization. This is connection-row metadata, not an object body mask, "
            "generated-cell bit, water/island flag, or two-level flag."
        ),
        "remaining_gap": (
            "The +0x09 producer and natural branch meaning are recovered for the sampled relation "
            "records. Remaining work is not to guess another producer; it is to complete ordered "
            "relation/control linkage through 0x4a61bc/0x4a696b/0x4a7605, broader map-mode/source-state "
            "scope, successful or intentionally-unreachable 0x4a606b endpoint stamping, and cleanup/"
            "uncommit semantics if that path is reached. Native RMG behavior must not change from this "
            "checkpoint alone."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scan", type=Path, default=DEFAULT_SCAN)
    parser.add_argument("--gate-summary", type=Path, default=DEFAULT_GATE)
    parser.add_argument("--producer-static-summary", type=Path, default=DEFAULT_PRODUCER_STATIC)
    parser.add_argument("--descriptor-category", type=Path, default=DEFAULT_DESCRIPTOR_CATEGORY)
    parser.add_argument("--natural-bg", type=Path, default=DEFAULT_NATURAL_BG)
    parser.add_argument("--bg-followthrough", type=Path, default=DEFAULT_BG_FOLLOWTHROUGH)
    parser.add_argument("--cursor-lifetime", type=Path, default=DEFAULT_CURSOR_LIFETIME)
    parser.add_argument("--dump-49b3fb", type=Path, default=DEFAULT_49B3FB_DUMP)
    parser.add_argument("--dump-4a4c8e", type=Path, default=DEFAULT_4A4C8E_DUMP)
    parser.add_argument("--dump-4a4fc5", type=Path, default=DEFAULT_4A4FC5_DUMP)
    parser.add_argument("--dump-4a79a3", type=Path, default=DEFAULT_4A79A3_DUMP)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(
        args.scan,
        args.gate_summary,
        args.producer_static_summary,
        args.descriptor_category,
        args.natural_bg,
        args.bg_followthrough,
        args.cursor_lifetime,
        args.dump_49b3fb,
        args.dump_4a4c8e,
        args.dump_4a4fc5,
        args.dump_4a79a3,
    )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_CONNECTION_RECORD_FIELD_SUMMARY status={summary['status']} out={args.out}")
    return 0 if summary["status"] == "recovered_connection_record_plus9_border_guard_surface" else 1


if __name__ == "__main__":
    raise SystemExit(main())
