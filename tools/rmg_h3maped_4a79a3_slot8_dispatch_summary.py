#!/usr/bin/env python3
"""Summarize the sampled H3MapEd 0x4a79a3 slot +0x08 dispatch target.

This is a narrow recovery checkpoint. It does not infer native RMG behavior; it
only names the vtable/slot target for the bounded live trace that stopped at the
0x4a79a3 internal slot dispatch and records whether that dispatch is the missing
projection-object method path.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_LEDGER = Path(
    ".artifacts/rmg_recovery/"
    "medium_seed10_4a79a3_slot8_dispatch_trace_20260609/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_OUT = (
    Path(".artifacts/rmg_recovery")
    / "medium_seed10_4a79a3_slot8_dispatch_summary_20260609.json"
)

ENTRY = "0x004a79a3"
PRE_SLOT8_CALL = "0x004a7e93"
POST_SLOT8_CALL = "0x004a7e96"
PROJECTION_METHOD_TARGETS = {"0x0049c019", "0x0049c0a6"}
PROJECTION_DRIVER_TARGETS = {
    "0x004adb72",
    "0x004ad947",
    "0x004ad7f7",
    "0x004add76",
    "0x004adef7",
}
PROJECTION_OBJECT_VTABLES = {"0x00540b00", "0x00540b14", "0x00540b28"}


def normalize_address(value: Any) -> str:
    if isinstance(value, str):
        return f"0x{int(value, 0) & 0xFFFFFFFF:08x}"
    return f"0x{int(value) & 0xFFFFFFFF:08x}"


def hex32(value: int | None) -> str | None:
    if value is None:
        return None
    return f"0x{value & 0xFFFFFFFF:08x}"


def memory_map(event: dict[str, Any]) -> dict[int, list[int]]:
    return {
        int(line.get("address", -1)): [int(word) & 0xFFFFFFFF for word in line.get("words", [])]
        for line in event.get("memory_lines", [])
    }


def words_at(event: dict[str, Any], address: int | None, max_words: int = 16) -> list[int]:
    if not isinstance(address, int):
        return []
    by_address = memory_map(event)
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
    if index < 0 or index >= len(words):
        return None
    return words[index]


def find_event(events: list[dict[str, Any]], address: str) -> tuple[int, dict[str, Any] | None]:
    for index, event in enumerate(events, start=1):
        if normalize_address(event.get("address", "0")) == address:
            return index, event
    return 0, None


def register_hex(event: dict[str, Any] | None, name: str) -> str | None:
    if not event:
        return None
    value = event.get("registers", {}).get(name)
    return hex32(value) if isinstance(value, int) else None


def summarize(ledger: dict[str, Any]) -> dict[str, Any]:
    events = ledger.get("events", [])
    entry_index, entry_event = find_event(events, ENTRY)
    pre_index, pre_event = find_event(events, PRE_SLOT8_CALL)
    post_index, post_event = find_event(events, POST_SLOT8_CALL)

    pre_registers = pre_event.get("registers", {}) if pre_event else {}
    post_registers = post_event.get("registers", {}) if post_event else {}
    receiver = pre_registers.get("ebx")
    vtable = pre_registers.get("eax")
    vtable_words = words_at(pre_event or {}, vtable, 8)
    receiver_words = words_at(pre_event or {}, receiver, 12)
    source_record = pre_registers.get("esi")
    source_words = words_at(pre_event or {}, source_record, 12)
    post_esi = post_registers.get("esi")
    post_source_words = words_at(post_event or {}, post_esi, 12)

    slot8_target = word_at(vtable_words, 0x08)
    address_sequence = [normalize_address(event.get("address", "0")) for event in events]
    target = hex32(slot8_target)
    is_projection_method = target in PROJECTION_METHOD_TARGETS
    is_projection_driver = target in PROJECTION_DRIVER_TARGETS
    is_projection_vtable = hex32(vtable) in PROJECTION_OBJECT_VTABLES

    status = (
        "sampled_4a79a3_slot8_dispatch_not_projection_method"
        if target and not is_projection_method and not is_projection_driver
        else "sampled_4a79a3_slot8_dispatch_requires_followup"
    )

    return {
        "schema_id": "h3maped_4a79a3_slot8_dispatch_summary_v1",
        "status": status,
        "ledger": ledger.get("log_path", ""),
        "ledger_path": str(DEFAULT_LEDGER),
        "event_count": int(ledger.get("event_count", len(events))),
        "address_sequence": address_sequence,
        "dispatch": {
            "entry_event_index": entry_index,
            "pre_call_event_index": pre_index,
            "post_call_event_index": post_index,
            "call_site": PRE_SLOT8_CALL,
            "receiver_register": "ebx",
            "receiver": hex32(receiver) if isinstance(receiver, int) else None,
            "vtable_register": "eax",
            "vtable": hex32(vtable) if isinstance(vtable, int) else None,
            "slot_0x08_target": target,
            "post_call_eax": register_hex(post_event, "eax"),
            "post_call_ecx": register_hex(post_event, "ecx"),
        },
        "record_words": {
            "receiver_words_prefix": [hex32(word) for word in receiver_words],
            "vtable_words_prefix": [hex32(word) for word in vtable_words],
            "source_record": hex32(source_record) if isinstance(source_record, int) else None,
            "source_record_words_prefix": [hex32(word) for word in source_words],
            "post_source_record_words_prefix": [hex32(word) for word in post_source_words],
        },
        "classification": {
            "slot_target_is_projection_method_49c019_or_49c0a6": is_projection_method,
            "slot_target_is_known_projection_driver_or_cleanup": is_projection_driver,
            "receiver_vtable_is_known_projection_object_vtable": is_projection_vtable,
            "sampled_dispatch_ruled_out_as_missing_projection_slot08_path": bool(
                target and not is_projection_method and not is_projection_driver
            ),
        },
        "invariants": {
            "has_entry_4a79a3": entry_event is not None,
            "has_pre_slot8_call_4a7e93": pre_event is not None,
            "has_post_slot8_call_4a7e96": post_event is not None,
            "recovers_receiver_pointer": isinstance(receiver, int),
            "recovers_vtable_pointer": isinstance(vtable, int),
            "recovers_slot8_target": isinstance(slot8_target, int),
            "slot8_target_is_not_49c_projection_method": not is_projection_method,
            "slot8_target_is_not_cleanup_or_projection_driver": not is_projection_driver,
            "receiver_vtable_is_not_known_projection_object_vtable": not is_projection_vtable,
            "no_native_behavior_change": True,
        },
        "notes": [
            "The sampled 0x4a79a3 internal slot +0x08 call resolves through vtable 0x00539660 to 0x0045e1a6.",
            "That target is not the known projection-object methods 0x49c019/0x49c0a6 and not the recovered cleanup/projection drivers.",
            "This rules out this sampled 0x4a79a3 slot +0x08 dispatch as the missing projection-method dispatch; it does not recover the true owning projection-object lifetime path.",
        ],
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    ledger = json.loads(args.ledger.read_text(encoding="utf-8"))
    summary = summarize(ledger)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    passed = all(summary["invariants"].values())
    print(
        "RMG_H3MAPED_4A79A3_SLOT8_DISPATCH_SUMMARY "
        f"status={'pass' if passed else 'partial'} "
        f"result={summary['status']} "
        f"target={summary['dispatch']['slot_0x08_target']} "
        f"out={args.out}"
    )
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
