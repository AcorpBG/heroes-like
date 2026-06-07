#!/usr/bin/env python3
"""Summarize H3MapEd 0x4a79a3 object-vector payload records."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

from rmg_h3maped_recovery_trace import parse_winedbg_log


DEFAULT_LOG = Path(
    ".artifacts/rmg_recovery/direct_generation_4a79a3_object_descriptor_payload_trace/"
    "winedbg_interactive_trace.log"
)
DEFAULT_OUT = Path(".artifacts/rmg_recovery/4a79a3_payload_trace_summary.json")

VECTOR_RECORD_SITE = "0x004a7d36"
COUNT_SITE = "0x004a7d99"


def hex32(value: int | None) -> str | None:
    return None if value is None else f"0x{value & 0xFFFFFFFF:08x}"


def memory_words(event: dict[str, Any], address: int | None, count: int) -> list[int | None]:
    if address is None:
        return []
    result: list[int | None] = []
    for offset in range(count):
        target = address + offset * 4
        found: int | None = None
        for line in event.get("memory_lines", []):
            base = int(line["address"])
            words = line.get("words", [])
            if base <= target < base + len(words) * 4 and (target - base) % 4 == 0:
                found = int(words[(target - base) // 4]) & 0xFFFFFFFF
                break
        result.append(found)
    return result


def vector_payload_words(event: dict[str, Any]) -> list[int]:
    eax = event.get("registers", {}).get("eax")
    if not isinstance(eax, int):
        return []
    words = memory_words(event, eax, 24)
    return [word for word in words if word is not None]


def record_from_event(index: int, event: dict[str, Any]) -> dict[str, Any] | None:
    regs = event.get("registers", {})
    edx = regs.get("edx")
    if not isinstance(edx, int) or edx == 0:
        return None
    record_words = memory_words(event, edx, 12)
    if len(record_words) < 4 or any(word is None for word in record_words[:4]):
        return None
    descriptor = record_words[1]
    descriptor_words = memory_words(event, descriptor, 24) if isinstance(descriptor, int) else []
    descriptor_source = descriptor_words[0] if descriptor_words else None
    return {
        "event_index": index,
        "record_pointer": hex32(edx),
        "record_words": [hex32(word) for word in record_words],
        "record_vtable": hex32(record_words[0]),
        "descriptor_pointer": hex32(descriptor if isinstance(descriptor, int) else None),
        "coordinate_or_payload_words_08_10": [
            record_words[2],
            record_words[3],
            record_words[4],
        ],
        "field_1c": record_words[7],
        "field_20": record_words[8],
        "field_24": record_words[9],
        "field_28": record_words[10],
        "field_2c": record_words[11],
        "descriptor_words": [hex32(word) for word in descriptor_words],
        "descriptor_source_pointer": hex32(descriptor_source if isinstance(descriptor_source, int) else None),
        "descriptor_source_words_sampled": bool(descriptor_words and descriptor_words[0] is not None),
    }


def summarize(log_path: Path) -> dict[str, Any]:
    ledger = parse_winedbg_log(log_path)
    events = ledger["events"]
    records: list[dict[str, Any]] = []
    vector_payload: list[int] = []
    count_after_shift: int | None = None
    for index, event in enumerate(events):
        if event["address"] == VECTOR_RECORD_SITE:
            if not vector_payload:
                vector_payload = vector_payload_words(event)
            record = record_from_event(index, event)
            if record is not None:
                records.append(record)
        elif event["address"] == COUNT_SITE:
            edx = event.get("registers", {}).get("edx")
            if isinstance(edx, int):
                count_after_shift = edx

    vector_entries = vector_payload[: count_after_shift or len(vector_payload)]
    record_pointers = [int(record["record_pointer"], 16) for record in records]
    vtable_counts = Counter(record["record_vtable"] for record in records)
    descriptor_counts = Counter(record["descriptor_pointer"] for record in records)
    source_counts = Counter(record["descriptor_source_pointer"] for record in records)
    invariants = {
        "trace_has_events": bool(events),
        "count_checkpoint_hit": count_after_shift is not None,
        "vector_payload_dumped": bool(vector_payload),
        "record_payloads_dumped": bool(records),
        "record_count_matches_shifted_count": count_after_shift == len(records),
        "vector_entries_match_record_pointers": vector_entries == record_pointers,
        "descriptor_wrappers_dumped": all(record["descriptor_words"] for record in records),
    }
    status = "partial_live_recovery_4a79a3_object_record_payload" if all(invariants.values()) else "incomplete"
    return {
        "schema_id": "h3maped_4a79a3_payload_trace_summary_v1",
        "log_path": str(log_path),
        "event_count": len(events),
        "address_counts": dict(sorted(Counter(event["address"] for event in events).items())),
        "status": status,
        "invariants": invariants,
        "shifted_count_at_0x4a7d99": count_after_shift,
        "vector_entries": [hex32(value) for value in vector_entries],
        "record_count": len(records),
        "record_vtable_counts": dict(sorted(vtable_counts.items())),
        "record_vtable_static_origins": {
            "0x00540a9c": [
                "0x4a901a writes this vtable at 0x4a92c3 after 0x49ba89 initialization",
                "0x4a93a2 writes this vtable at 0x4a9524 after 0x49ba89 initialization",
            ],
            "0x00540a88": [
                "0x4a5c07 writes this vtable at 0x4a5dd9 after 0x49ba89 initialization",
                "0x4a5c07 is called by 0x4aa354 in the recovered reward/guard chain",
            ],
        },
        "descriptor_pointer_counts": dict(sorted(descriptor_counts.items())),
        "descriptor_source_pointer_counts": dict(sorted(source_counts.items())),
        "records": records,
        "recovered_contract": (
            "In this sampled direct-generation run, the 0x4a79a3 object-vector loop exposes each entry as "
            "a pointer in EDX at 0x4a7d36. The vector payload entries exactly match the dumped object-record "
            "pointers, and 0x4a7d99 confirms the shifted dword count."
        ),
        "remaining_gap": (
            "The record vtables, descriptor wrapper fields, and nested descriptor source pointers are now "
            "captured, but their exact semantic names and the downstream connection/blocker/guard GeneratedCell "
            "writes are still not replayed end-to-end."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log", type=Path, default=DEFAULT_LOG)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args.log)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_4A79A3_PAYLOAD_TRACE_SUMMARY "
        f"status={summary['status']} records={summary['record_count']} out={args.out}"
    )
    return 0 if summary["status"] == "partial_live_recovery_4a79a3_object_record_payload" else 1


if __name__ == "__main__":
    raise SystemExit(main())
