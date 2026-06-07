#!/usr/bin/env python3
"""Summarize H3MapEd 49c projection constructor return/adoption evidence."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

from rmg_h3maped_4aa3e9_ordered_summary import hex32, normalize_address


DEFAULT_LEDGER = Path(
    ".artifacts/rmg_recovery/direct_generation_49c_constructor_return_trace/winedbg_interactive_trace_ledger.json"
)

SELECTED_CREATE_SITE = "0x004aa166"
SELECTED_RETURN_SITE = "0x004aa168"

CONSTRUCTOR_ENTRIES = {
    "0x0049cac2": "projection_object_constructor_a",
    "0x0049cb83": "projection_object_constructor_b",
    "0x0049cc22": "projection_object_constructor_c",
    "0x0049cdb1": "projection_object_adjacent_constructor",
}

CONSTRUCTOR_PRE_RETURNS = {
    "0x0049cb52": "projection_object_constructor_a",
    "0x0049cc12": "projection_object_constructor_b",
    "0x0049ccb0": "projection_object_constructor_c",
    "0x0049cdf4": "projection_object_adjacent_constructor",
}

PROJECTION_OBJECT_VTABLES = {"0x00540b00", "0x00540b14"}


def words_at(event: dict[str, Any], pointer: int | None, word_count: int = 12) -> list[int]:
    if pointer is None:
        return []
    by_index: dict[int, int] = {}
    for line in event.get("memory_lines", []):
        address = line.get("address")
        if address is None:
            continue
        for index, word in enumerate(line.get("words", [])):
            offset = address + index * 4 - pointer
            if offset >= 0 and offset % 4 == 0:
                by_index[offset // 4] = int(word)
    return [by_index[index] for index in range(word_count) if index in by_index]


def word_at(event: dict[str, Any], pointer: int | None, word_index: int) -> int | None:
    if pointer is None:
        return None
    for line in event.get("memory_lines", []):
        address = line.get("address")
        if address is None:
            continue
        words = line.get("words", [])
        byte_offset = pointer + word_index * 4 - address
        if byte_offset < 0 or byte_offset % 4:
            continue
        index = byte_offset // 4
        if 0 <= index < len(words):
            return int(words[index])
    return None


def vtable_at_register(event: dict[str, Any], register: str) -> str:
    registers = event.get("registers", {})
    pointer = registers.get(register)
    value = word_at(event, pointer, 0)
    return hex32(value) if value is not None else "missing-memory"


def selected_callback(event: dict[str, Any]) -> str:
    registers = event.get("registers", {})
    vtable = registers.get("eax")
    value = word_at(event, vtable, 0)
    return hex32(value) if value is not None else "missing-memory"


def object_record(event: dict[str, Any], register: str) -> dict[str, Any]:
    registers = event.get("registers", {})
    pointer = registers.get(register)
    words = words_at(event, pointer)
    return {
        "register": register,
        "pointer": hex32(pointer) if pointer is not None else "missing-register",
        "words": [hex32(word) for word in words],
        "vtable": hex32(words[0]) if words else "missing-memory",
        "descriptor_or_payload_plus_04": hex32(words[1]) if len(words) > 1 else "missing",
        "field_plus_1c": hex32(words[7]) if len(words) > 7 else "missing",
        "child_or_base_pointer_plus_20": hex32(words[8]) if len(words) > 8 else "missing",
        "field_plus_24": hex32(words[9]) if len(words) > 9 else "missing",
    }


def summarize(ledger: dict[str, Any]) -> dict[str, Any]:
    events = ledger.get("events", [])
    addresses = [normalize_address(event.get("address", "0")) for event in events if event.get("address")]
    address_counts = Counter(addresses)

    selected_create_callbacks = Counter(
        selected_callback(event)
        for event in events
        if normalize_address(event.get("address", "0")) == SELECTED_CREATE_SITE
    )

    constructor_pre_return_records: list[dict[str, Any]] = []
    selected_return_records: list[dict[str, Any]] = []
    for index, event in enumerate(events):
        address = normalize_address(event.get("address", "0"))
        if address not in CONSTRUCTOR_PRE_RETURNS:
            continue
        previous_address = normalize_address(events[index - 1].get("address", "0")) if index else ""
        next_event = events[index + 1] if index + 1 < len(events) else {}
        next_address = normalize_address(next_event.get("address", "0")) if next_event else ""
        constructor_name = CONSTRUCTOR_PRE_RETURNS[address]
        pre_return_object = object_record(event, "eax")
        base_object = object_record(event, "edi")
        selected_return_object = object_record(next_event, "eax") if next_address == SELECTED_RETURN_SITE else {}
        stack_pointer = next_event.get("registers", {}).get("ecx") if next_event else None
        continuation = word_at(next_event, stack_pointer, 4) if next_address == SELECTED_RETURN_SITE else None
        record = {
            "event_index": index + 1,
            "constructor_name": constructor_name,
            "constructor_pre_return_site": address,
            "previous_event_address": previous_address,
            "next_event_address": next_address,
            "pre_return_object": pre_return_object,
            "base_object_from_edi": base_object,
            "selected_return_object": selected_return_object,
            "selected_return_continuation_from_ecx_plus_10": hex32(continuation)
            if continuation is not None
            else "missing",
            "returns_to_selected_create_site": next_address == SELECTED_RETURN_SITE,
            "selected_return_matches_pre_return_pointer": bool(selected_return_object)
            and selected_return_object.get("pointer") == pre_return_object.get("pointer"),
            "selected_return_has_projection_vtable": selected_return_object.get("vtable") in PROJECTION_OBJECT_VTABLES,
        }
        constructor_pre_return_records.append(record)
        if next_address == SELECTED_RETURN_SITE:
            selected_return_records.append(record)

    selected_projection_return_records = [
        record
        for record in selected_return_records
        if record.get("selected_return_object", {}).get("vtable") in PROJECTION_OBJECT_VTABLES
    ]
    continuation_counts = Counter(
        record["selected_return_continuation_from_ecx_plus_10"] for record in selected_projection_return_records
    )
    selected_projection_return_vtables = Counter(
        record["selected_return_object"]["vtable"] for record in selected_projection_return_records
    )

    return {
        "schema_id": "h3maped_49c_constructor_return_summary_v1",
        "ledger": ledger.get("log_path", ""),
        "event_count": int(ledger.get("event_count", len(events))),
        "breakpoints": ledger.get("breakpoints", []),
        "address_counts": dict(sorted(address_counts.items())),
        "selected_create_callback_counts": dict(sorted(selected_create_callbacks.items())),
        "projection_constructor_entry_counts": {
            address: address_counts.get(address, 0)
            for address in sorted(CONSTRUCTOR_ENTRIES)
            if address_counts.get(address, 0)
        },
        "projection_constructor_pre_return_counts": {
            address: address_counts.get(address, 0)
            for address in sorted(CONSTRUCTOR_PRE_RETURNS)
            if address_counts.get(address, 0)
        },
        "constructor_pre_return_records": constructor_pre_return_records,
        "selected_projection_return_vtable_counts": dict(sorted(selected_projection_return_vtables.items())),
        "selected_projection_return_continuation_counts": dict(sorted(continuation_counts.items())),
        "invariants": {
            "selected_create_site_hit": address_counts.get(SELECTED_CREATE_SITE, 0) > 0,
            "selected_return_site_hit": address_counts.get(SELECTED_RETURN_SITE, 0) > 0,
            "projection_constructor_entries_hit": any(address_counts.get(address, 0) for address in CONSTRUCTOR_ENTRIES),
            "projection_constructor_pre_returns_hit": any(
                address_counts.get(address, 0) for address in CONSTRUCTOR_PRE_RETURNS
            ),
            "projection_constructor_pre_returns_flow_to_selected_return": bool(constructor_pre_return_records)
            and all(record["returns_to_selected_create_site"] for record in constructor_pre_return_records),
            "selected_return_matches_constructor_return_pointer": bool(selected_return_records)
            and all(record["selected_return_matches_pre_return_pointer"] for record in selected_return_records),
            "selected_return_carries_projection_vtable": bool(selected_projection_return_records),
            "sampled_projection_returns_are_0x540b14": bool(selected_projection_return_records)
            and set(selected_projection_return_vtables) == {"0x00540b14"},
            "adjacent_0x540b00_constructor_not_hit_in_this_sample": address_counts.get("0x0049cdb1", 0) == 0,
        },
        "notes": [
            "This recovers the 0x540b14 constructor return/adoption edge: sampled 49c constructor returns flow into 0x4aa168 and keep the same EAX object pointer/vtable.",
            "The sampled returned object records have the 0x540b14 projection-object vtable and a child/base pointer at +0x20.",
            "The 0x49cdb1/0x540b00 adjacent constructor was instrumented but not hit in this bounded generation sample.",
            "This does not yet recover the later 0x540b14+0x08 method dispatch into 0x49c0a6 or the 0x540b00+0x08 dispatch into 0x49c019.",
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
        "RMG_H3MAPED_49C_CONSTRUCTOR_RETURN_SUMMARY "
        f"status={status} events={summary['event_count']} "
        f"constructor_returns={sum(summary['projection_constructor_pre_return_counts'].values())} "
        f"projection_returns={sum(summary['selected_projection_return_vtable_counts'].values())} "
        f"vtables={summary['selected_projection_return_vtable_counts']} out={args.out}"
    )
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
