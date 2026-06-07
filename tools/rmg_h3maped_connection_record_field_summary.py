#!/usr/bin/env python3
"""Summarize recovered H3MapEd compact connection-record fields.

This is a recovery checkpoint, not a native RMG behavior change. It names the
human-readable surface around record byte +0x09 and records the remaining
producer gap explicitly.
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
    dump_49b3fb: Path,
    dump_4a4c8e: Path,
    dump_4a4fc5: Path,
    dump_4a79a3: Path,
) -> dict[str, Any]:
    scan_entries = parse_scan(scan_path)
    scan = summarize_scan(scan_entries)
    gate = read_json(gate_path)
    text_49b3fb = read_text(dump_49b3fb)
    text_4a4c8e = read_text(dump_4a4c8e)
    text_4a4fc5 = read_text(dump_4a4fc5)
    text_4a79a3 = read_text(dump_4a79a3)

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
        "no_native_behavior_change": True,
    }

    writer_candidates = scan["non_stack_offset_9_writer_candidates"]
    status = "partial_recovery_connection_record_plus9_consumer_surface" if all(invariants.values()) else "incomplete"
    return {
        "schema_id": "h3maped_connection_record_field_summary_v1",
        "status": status,
        "invariants": invariants,
        "source_artifacts": {
            "offset_scan": str(scan_path),
            "gate_summary": str(gate_path),
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
                "working_name": "connection_recipe.endpoint_stamping_enabled",
                "evidence": [
                    "0x4a61bc, 0x4a696b, 0x4a6cf2, and 0x4a7605 read this byte in connection dispatch/endpoint paths.",
                    "The sampled 0x4a7605 run saw byte +0x09 == 0 at both gates and skipped both 0x4a746b endpoint-writer call sites.",
                    "The known RMG +0x09 sites found by the full Ghidra scan are reads, not writes.",
                ],
                "confidence": "medium_high_consumer_surface_not_producer",
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
            "producer_status": "not_recovered",
            "only_non_stack_plus9_writer_candidate": (
                writer_candidates[0] if len(writer_candidates) == 1 else None
            ),
            "candidate_classification": (
                "0x4b3c03 copies bytes +0x08/+0x09 from a 12-byte local record returned by a vtable "
                "slot into a caller output record. It is a serialization/copy adapter candidate, not "
                "the semantic producer of the RMG compact connection record until the owning caller and "
                "vtable source are tied to generator+0xc8/+0xcc."
            ),
        },
        "recovered_contract": (
            "Byte +0x09 is best named as a connection recipe endpoint-stamping enable flag for now. "
            "When it is zero, the sampled 0x4a7605 path performs direct 0x4a7312 endpoint placement "
            "but skips delegated 0x4a746b/0x4a5e73 endpoint/corridor stamping. This is a connection "
            "recipe option, not an object body mask, generated-cell bit, water/island flag, or two-level flag."
        ),
        "remaining_gap": (
            "The semantic producer of compact record byte +0x09 is still not recovered. The next exact "
            "target is the upstream source behind 0x4b3c03's vtable copy path or a runtime watchpoint "
            "on a generator+0xc8 record byte +0x09 before 0x4a79a3 consumes it. Native RMG behavior must "
            "not change until that producer or a nonzero live sample is recovered."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scan", type=Path, default=DEFAULT_SCAN)
    parser.add_argument("--gate-summary", type=Path, default=DEFAULT_GATE)
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
        args.dump_49b3fb,
        args.dump_4a4c8e,
        args.dump_4a4fc5,
        args.dump_4a79a3,
    )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_CONNECTION_RECORD_FIELD_SUMMARY status={summary['status']} out={args.out}")
    return 0 if summary["status"] == "partial_recovery_connection_record_plus9_consumer_surface" else 1


if __name__ == "__main__":
    raise SystemExit(main())
