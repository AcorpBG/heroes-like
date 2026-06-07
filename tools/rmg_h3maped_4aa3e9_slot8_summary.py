#!/usr/bin/env python3
"""Summarize H3MapEd 0x4aa3e9 selected-member slot +0x08 callbacks."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

from rmg_h3maped_4aa3e9_inner_summary import hex32, normalize_address


DEFAULT_LEDGER = Path(".artifacts/rmg_recovery/direct_generation_4aa3e9_slot8_broad_trace/winedbg_recovery_trace_ledger.json")

ENTRY = "0x004aa3e9"
SLOT8_CALLBACK = "0x004aa5f6"
PRE_RETURN = "0x004aa5fc"
PROJECTION_METHOD_AND_DRIVER_TARGETS = {
    "0x0049c019",
    "0x0049c0a6",
    "0x004adb72",
    "0x004ad947",
    "0x004ad7f7",
    "0x004adb07",
}
PROJECTION_OBJECT_VTABLES = {"0x00540b00", "0x00540b14"}


def words_at(event: dict[str, Any], address: int | None, max_words: int = 12) -> list[int]:
    if not isinstance(address, int):
        return []
    by_address = {
        int(line.get("address", -1)): [int(word) & 0xFFFFFFFF for word in line.get("words", [])]
        for line in event.get("memory_lines", [])
    }
    out: list[int] = []
    cursor = address
    while cursor in by_address and len(out) < max_words:
        line_words = by_address[cursor]
        take = min(len(line_words), max_words - len(out))
        out.extend(line_words[:take])
        cursor += len(line_words) * 4
    return out


def word_at(words: list[int], offset: int) -> int | None:
    index = offset // 4
    return words[index] if index < len(words) else None


def slot8_record(event: dict[str, Any], event_index: int) -> dict[str, Any]:
    registers = event.get("registers", {})
    member = registers.get("ecx")
    vtable = registers.get("eax")
    vtable_words = words_at(event, vtable, 4)
    member_words = words_at(event, member, 12)
    return {
        "event_index": event_index,
        "member": hex32(member),
        "vtable": hex32(vtable),
        "slot_target": hex32(word_at(vtable_words, 0x08)),
        "member_descriptor": hex32(word_at(member_words, 0x04)),
        "member_coordinate": {
            "x": word_at(member_words, 0x08),
            "y": word_at(member_words, 0x0C),
            "level": word_at(member_words, 0x10),
        },
        "member_words_prefix": [hex32(word) for word in member_words],
    }


def summarize(ledger: dict[str, Any]) -> dict[str, Any]:
    events = ledger.get("events", [])
    address_counts = Counter(normalize_address(event.get("address", "0")) for event in events)
    slot8_records = [
        slot8_record(event, index)
        for index, event in enumerate(events, start=1)
        if normalize_address(event.get("address", "0")) == SLOT8_CALLBACK
    ]
    slot8_vtables = Counter(record["vtable"] for record in slot8_records)
    slot8_targets = Counter(record["slot_target"] for record in slot8_records)
    projection_method_counts = {
        address: address_counts.get(address, 0)
        for address in sorted(PROJECTION_METHOD_AND_DRIVER_TARGETS)
        if address_counts.get(address, 0)
    }
    projection_vtable_records = [
        record for record in slot8_records if record.get("vtable") in PROJECTION_OBJECT_VTABLES
    ]

    return {
        "schema_id": "h3maped_4aa3e9_slot8_summary_v1",
        "ledger": ledger.get("log_path", ""),
        "event_count": int(ledger.get("event_count", 0)),
        "trace_result": ledger.get("trace_result", ""),
        "address_counts": dict(sorted(address_counts.items())),
        "slot8_callback_count": len(slot8_records),
        "slot8_vtable_counts": dict(sorted(slot8_vtables.items())),
        "slot8_target_counts": dict(sorted(slot8_targets.items())),
        "projection_method_or_driver_counts": projection_method_counts,
        "projection_vtable_slot8_records": projection_vtable_records,
        "slot8_records_prefix": slot8_records[:12],
        "invariants": {
            "has_paired_4aa3e9_boundaries": address_counts.get(ENTRY, 0) > 0
            and address_counts.get(ENTRY, 0) == address_counts.get(PRE_RETURN, 0),
            "has_slot8_callbacks": bool(slot8_records),
            "all_slot8_callbacks_resolve_to_49baf5": bool(slot8_records)
            and set(slot8_targets) == {"0x0049baf5"},
            "no_projection_object_vtable_seen_at_slot8": not projection_vtable_records,
            "projection_methods_and_downstream_drivers_not_hit": not projection_method_counts,
        },
        "notes": [
            "This is a focused selected-member slot +0x08 callback distribution checkpoint.",
            "The trace timed out waiting for a later breakpoint after useful events; the captured paired calls are still valid evidence for the sampled slot +0x08 surface.",
            "No projection-object vtables 0x540b00/0x540b14 and no 49c projection-method/driver hits were captured in this bounded trace.",
        ],
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--out", type=Path, required=True)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    ledger = json.loads(args.ledger.read_text(encoding="utf-8"))
    summary = summarize(ledger)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    status = "pass" if all(summary["invariants"].values()) else "partial"
    print(
        "RMG_H3MAPED_4AA3E9_SLOT8_SUMMARY "
        f"status={status} events={summary['event_count']} "
        f"slot8={summary['slot8_callback_count']} "
        f"targets={summary['slot8_target_counts']} out={args.out}"
    )
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
