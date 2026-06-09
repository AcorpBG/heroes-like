#!/usr/bin/env python3
"""Summarize same-run 0x4a61bc append to 0x4a79a3 payload linkage."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_LEDGER = Path(
    ".artifacts/rmg_recovery/4a61bc_payload_link_dynamic_trace_20260609/"
    "winedbg_4a61bc_payload_link_dynamic_trace_ledger.json"
)
DEFAULT_OUT = Path(".artifacts/rmg_recovery/4a61bc_payload_link_summary_20260609.json")

ADDR_INITIAL = "0x004a6578"
ADDR_5E03 = "0x004a5e03"
ADDR_OBJECT = "0x004a5e55"
ADDR_AFTER_5E03 = "0x004a657d"
ADDR_4A79A3 = "0x004a79a3"
ADDR_PAYLOAD = "0x004a7d36"
ADDR_COUNT = "0x004a7d99"
DISPATCH_SITES = {"0x004a696b", "0x004a7605", "0x004a7df4", "0x004a7e21", "0x004a7e25"}


def hex32(value: int | None) -> str | None:
    return None if value is None else f"0x{value & 0xFFFFFFFF:08x}"


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def event_address(event: dict[str, Any]) -> str:
    return str(event.get("address", "")).lower()


def memory_words(event: dict[str, Any], address: int | None, count: int) -> list[int | None]:
    if address is None:
        return []
    result: list[int | None] = []
    for offset in range(count):
        target = address + offset * 4
        found: int | None = None
        for line in event.get("memory_lines", []):
            base = int(line.get("address", -1))
            words = line.get("words", [])
            if base <= target < base + len(words) * 4 and (target - base) % 4 == 0:
                found = int(words[(target - base) // 4]) & 0xFFFFFFFF
                break
        result.append(found)
    return result


def stack_return(event: dict[str, Any]) -> str | None:
    esp = event.get("registers", {}).get("esp")
    if not isinstance(esp, int):
        return None
    words = memory_words(event, esp, 1)
    return hex32(words[0] if words else None)


def vector_payload_words(event: dict[str, Any]) -> list[int]:
    eax = event.get("registers", {}).get("eax")
    if not isinstance(eax, int):
        return []
    return [word for word in memory_words(event, eax, 64) if word is not None]


def record_summary(event_index: int, event: dict[str, Any], pointer: int | None) -> dict[str, Any]:
    words = memory_words(event, pointer, 16)
    descriptor = words[1] if len(words) > 1 else None
    descriptor_words = memory_words(event, descriptor if isinstance(descriptor, int) else None, 16)
    return {
        "event_index": event_index,
        "site": event_address(event),
        "record_pointer": hex32(pointer),
        "return_address": stack_return(event),
        "record_vtable": hex32(words[0] if len(words) > 0 else None),
        "descriptor_pointer": hex32(descriptor if isinstance(descriptor, int) else None),
        "coordinate_or_payload_words_08_10": [
            words[2] if len(words) > 2 else None,
            words[3] if len(words) > 3 else None,
            words[4] if len(words) > 4 else None,
        ],
        "field_1c": words[7] if len(words) > 7 else None,
        "field_20": words[8] if len(words) > 8 else None,
        "field_24": hex32(words[9] if len(words) > 9 else None),
        "record_words": [hex32(word) for word in words],
        "descriptor_words": [hex32(word) for word in descriptor_words],
    }


def selected_object_from_events(events: list[dict[str, Any]]) -> dict[str, Any] | None:
    for index, event in enumerate(events):
        if event_address(event) != ADDR_OBJECT:
            continue
        pointer = event.get("registers", {}).get("eax")
        return record_summary(index, event, pointer if isinstance(pointer, int) else None)
    return None


def payload_records(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for index, event in enumerate(events):
        if event_address(event) != ADDR_PAYLOAD:
            continue
        pointer = event.get("registers", {}).get("edx")
        records.append(record_summary(index, event, pointer if isinstance(pointer, int) else None))
    return records


def dispatch_records(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for index, event in enumerate(events):
        if event_address(event) not in DISPATCH_SITES:
            continue
        esi = event.get("registers", {}).get("esi")
        ecx = event.get("registers", {}).get("ecx")
        edx = event.get("registers", {}).get("edx")
        records.append(
            {
                "event_index": index,
                "site": event_address(event),
                "return_address": stack_return(event),
                "esi": hex32(esi if isinstance(esi, int) else None),
                "ecx": hex32(ecx if isinstance(ecx, int) else None),
                "edx": hex32(edx if isinstance(edx, int) else None),
                "esi_words": [hex32(word) for word in memory_words(event, esi if isinstance(esi, int) else None, 16)],
                "ecx_words": [hex32(word) for word in memory_words(event, ecx if isinstance(ecx, int) else None, 16)],
                "edx_words": [hex32(word) for word in memory_words(event, edx if isinstance(edx, int) else None, 16)],
            }
        )
    return records


def summarize(ledger_path: Path) -> dict[str, Any]:
    ledger = load_json(ledger_path)
    events = ledger.get("events", [])
    meta = ledger.get("dynamic_trace_meta", {})
    counts = Counter(event_address(event) for event in events)
    selected = selected_object_from_events(events)
    payload = payload_records(events)
    non_null_payload = [
        record for record in payload if record.get("record_pointer") not in {None, "0x00000000"}
    ]
    dispatch = dispatch_records(events)
    selected_pointer = selected.get("record_pointer") if selected else meta.get("object_record")
    meta_object_pointer = meta.get("object_record")
    payload_by_pointer = {record.get("record_pointer"): record for record in non_null_payload}
    linked_payload_record = payload_by_pointer.get(selected_pointer)
    count_events = [event for event in events if event_address(event) == ADDR_COUNT]
    shifted_counts = [
        event.get("registers", {}).get("edx")
        for event in count_events
        if isinstance(event.get("registers", {}).get("edx"), int)
    ]
    first_payload_vector = next(
        (vector_payload_words(event) for event in events if event_address(event) == ADDR_PAYLOAD),
        [],
    )
    payload_pointers_all = [record.get("record_pointer") for record in payload]
    payload_pointers = [record.get("record_pointer") for record in non_null_payload]
    vector_entries = [hex32(value) for value in first_payload_vector[: len(non_null_payload)]]

    link_proven = linked_payload_record is not None
    reached_payload_loop = bool(payload)
    reached_dispatch = bool(dispatch)
    status = (
        "same_run_4a61bc_append_reaches_4a79a3_payload"
        if link_proven
        else "same_run_4a61bc_append_payload_link_not_proven"
    )
    return {
        "schema_id": "h3maped_4a61bc_payload_link_summary_v1",
        "status": status,
        "native_behavior_changed": False,
        "ledger": str(ledger_path),
        "event_count": len(events),
        "address_counts": dict(sorted(counts.items())),
        "dynamic_trace_meta": meta,
        "selected_4a61bc_object_record": selected,
        "payload_record_stop_count": len(payload),
        "payload_record_count": len(non_null_payload),
        "payload_pointers_all_stops": payload_pointers_all,
        "payload_pointers": payload_pointers,
        "payload_record_vtable_counts": dict(
            sorted(Counter(record.get("record_vtable") or "missing" for record in non_null_payload).items())
        ),
        "first_payload_vector_entries": vector_entries,
        "shifted_counts_at_0x4a7d99": shifted_counts,
        "linked_payload_record": linked_payload_record,
        "dispatch_records": dispatch,
        "invariants": {
            "selected_object_record_captured": selected_pointer is not None,
            "metadata_object_matches_first_selected_record": meta_object_pointer in {None, selected_pointer},
            "selected_4a61bc_reached_after_boundary": bool(meta.get("reached_after_selected_4a61bc"))
            or counts.get(ADDR_AFTER_5E03, 0) > 0,
            "same_trace_reaches_or_is_inside_4a79a3_payload_loop": counts.get(ADDR_4A79A3, 0) > 0
            or reached_payload_loop,
            "same_trace_reaches_payload_loop": reached_payload_loop,
            "same_trace_reaches_downstream_dispatch_sites": reached_dispatch,
            "payload_count_checkpoint_hit": bool(shifted_counts),
            "payload_shifted_count_matches_non_null_payload_records": not shifted_counts
            or shifted_counts[-1] == len(non_null_payload),
            "payload_vector_entries_match_non_null_payload_pointers": not vector_entries
            or vector_entries == payload_pointers[: len(vector_entries)],
            "selected_object_pointer_reappears_in_payload": link_proven,
        },
        "source_backed_conclusion": (
            "The selected 0x4a61bc-origin object record appears as a later 0x4a7d36 payload "
            "record in this same H3MapEd run."
            if link_proven
            else "This trace captures the selected 0x4a61bc-origin object record and continues "
            "to later payload/dispatch evidence, but the selected pointer does not appear in "
            "the sampled 0x4a7d36 payload records. The same-run append-to-payload link remains "
            "unproven for this sampled record."
        ),
        "remaining_gap": (
            "After this pointer link, continue into callee-side 0x4a696b/0x4a7605 mutation replay, "
            "natural endpoint success, and cleanup/uncommit runtime behavior."
            if link_proven
            else "Capture a same-run chain where the selected 0x4a61bc object pointer is observed "
            "in the later 0x4a7d36 payload loop, or prove from static phase ordering that this "
            "append surface feeds a separate consumer path."
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    summary = summarize(args.ledger)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_4A61BC_PAYLOAD_LINK_SUMMARY "
        f"status={summary['status']} "
        f"selected={summary['selected_4a61bc_object_record'].get('record_pointer') if summary['selected_4a61bc_object_record'] else None} "
        f"payload_records={summary['payload_record_count']} "
        f"out={args.out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
