#!/usr/bin/env python3
"""Summarize H3MapEd 0x540b14 projection selected-member lifetime evidence."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

from rmg_h3maped_4aa3e9_ordered_summary import hex32, normalize_address


DEFAULT_LEDGER = Path(
    ".artifacts/rmg_recovery/small2p_540b14_same_wrapper_lifetime_trace_lite_20260610/"
    "winedbg_interactive_trace_ledger.partial.json"
)

PROJECTION_RETURN_SITES = {"0x0049cb52", "0x0049cc12", "0x0049ccb0", "0x0049cdf4"}
SELECTED_RETURN_SITE = "0x004aa168"
WRAPPER_RETURN_SITE = "0x004aa343"
FINAL_COMMIT_SITE = "0x004aa3e9"
FINAL_SLOT8_SITE = "0x004aa5f6"
PROJECTION_METHOD_AND_CLEANUP_SITES = {
    "0x0049c019",
    "0x0049c0a6",
    "0x004ad947",
    "0x004adb72",
    "0x004adef7",
    "0x004add76",
}
PROJECTION_VTABLES = {0x00540B00, 0x00540B14}


def word_at(event: dict[str, Any], pointer: int | None, word_index: int = 0) -> int | None:
    if pointer is None:
        return None
    target = pointer + word_index * 4
    for line in event.get("memory_lines", []):
        address = line.get("address")
        if address is None:
            continue
        words = line.get("words", [])
        offset = target - address
        if offset >= 0 and offset % 4 == 0:
            index = offset // 4
            if 0 <= index < len(words):
                return int(words[index])
    return None


def words_at(event: dict[str, Any], pointer: int | None, count: int) -> list[int | None]:
    return [word_at(event, pointer, index) for index in range(count)]


def object_vtable(event: dict[str, Any], pointer: int | None) -> int | None:
    return word_at(event, pointer, 0)


def wrapper_vector(event: dict[str, Any], wrapper: int | None) -> dict[str, Any]:
    words = words_at(event, wrapper, 24)
    begin = words[11] if len(words) > 11 else None
    end = words[12] if len(words) > 12 else None
    capacity = words[13] if len(words) > 13 else None
    count: int | None = None
    live: list[int | None] = []
    if isinstance(begin, int) and isinstance(end, int) and begin <= end and end - begin <= 0x100:
        count = (end - begin) // 4
        live = [word_at(event, begin, index) for index in range(count)]
    return {
        "begin": hex32(begin) if begin is not None else "missing",
        "end": hex32(end) if end is not None else "missing",
        "capacity": hex32(capacity) if capacity is not None else "missing",
        "count": count,
        "live_members": [hex32(value) if value is not None else "missing" for value in live],
    }


def selected_return_record(event: dict[str, Any]) -> dict[str, Any]:
    pointer = event.get("registers", {}).get("eax")
    vtable = object_vtable(event, pointer)
    return {
        "pointer": hex32(pointer) if pointer is not None else "missing",
        "vtable": hex32(vtable) if vtable is not None else "missing",
    }


def find_projection_selected_returns(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for index, event in enumerate(events):
        address = normalize_address(event.get("address", "0"))
        if address not in PROJECTION_RETURN_SITES:
            continue
        for selected_index in range(index + 1, min(len(events), index + 4)):
            selected = events[selected_index]
            if normalize_address(selected.get("address", "0")) != SELECTED_RETURN_SITE:
                continue
            record = selected_return_record(selected)
            try:
                vtable = int(record["vtable"], 16)
            except ValueError:
                break
            if vtable in PROJECTION_VTABLES:
                records.append(
                    {
                        "constructor_event_index": index,
                        "constructor_site": address,
                        "selected_return_event_index": selected_index,
                        **record,
                    }
                )
            break
    return records


def projection_start_indices(projection_returns: list[dict[str, Any]]) -> dict[int, int]:
    starts: dict[int, int] = {}
    for record in projection_returns:
        pointer = int(record["pointer"], 16)
        index = int(record["selected_return_event_index"])
        starts[pointer] = min(starts.get(pointer, index), index)
    return starts


def eligible_projection_hits(values: list[int], starts: dict[int, int], event_index: int) -> list[int]:
    return [value for value in values if value in starts and event_index >= starts[value]]


def find_wrapper_returns_with_projection(
    events: list[dict[str, Any]], projection_starts: dict[int, int]
) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for index, event in enumerate(events):
        if normalize_address(event.get("address", "0")) != WRAPPER_RETURN_SITE:
            continue
        wrapper = event.get("registers", {}).get("ebx")
        vector = wrapper_vector(event, wrapper)
        live_values = [int(value, 16) for value in vector["live_members"] if value != "missing"]
        hits = eligible_projection_hits(live_values, projection_starts, index)
        if not hits:
            continue
        records.append(
            {
                "event_index": index,
                "wrapper": hex32(wrapper) if wrapper is not None else "missing",
                "vector": vector,
                "projection_members": [hex32(value) for value in hits],
                "projection_member_vtables_in_dump": {
                    hex32(value): hex32(object_vtable(event, value))
                    if object_vtable(event, value) is not None
                    else "not-dumped"
                    for value in hits
                },
            }
        )
    return records


def find_reselected_projection_addresses(
    events: list[dict[str, Any]], projection_starts: dict[int, int]
) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for index, event in enumerate(events):
        if normalize_address(event.get("address", "0")) != SELECTED_RETURN_SITE:
            continue
        pointer = event.get("registers", {}).get("eax")
        if pointer not in projection_starts or index < projection_starts[pointer]:
            continue
        vtable = object_vtable(event, pointer)
        if vtable in PROJECTION_VTABLES:
            continue
        records.append({"event_index": index, "pointer": hex32(pointer), "vtable": hex32(vtable)})
    return records


def find_final_dispatches(
    events: list[dict[str, Any]], projection_starts: dict[int, int]
) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for index, event in enumerate(events):
        if normalize_address(event.get("address", "0")) != FINAL_SLOT8_SITE:
            continue
        registers = event.get("registers", {})
        member = registers.get("ecx")
        vtable = registers.get("eax")
        slot8 = word_at(event, vtable, 2)
        wrapper = registers.get("ebx")
        vector = wrapper_vector(event, wrapper)
        records.append(
            {
                "event_index": index,
                "wrapper": hex32(wrapper) if wrapper is not None else "missing",
                "member": hex32(member) if member is not None else "missing",
                "member_was_previous_projection_pointer": member in projection_starts
                and index >= projection_starts[member],
                "vtable": hex32(vtable) if vtable is not None else "missing",
                "slot8_target": hex32(slot8) if slot8 is not None else "missing",
                "vector": vector,
            }
        )
    return records


def summarize(ledger: dict[str, Any]) -> dict[str, Any]:
    events = ledger.get("events", [])
    address_counts = Counter(
        normalize_address(event.get("address", "0")) for event in events if event.get("address")
    )
    projection_returns = find_projection_selected_returns(events)
    projection_starts = projection_start_indices(projection_returns)
    wrapper_returns = find_wrapper_returns_with_projection(events, projection_starts)
    reselected = find_reselected_projection_addresses(events, projection_starts)
    final_dispatches = find_final_dispatches(events, projection_starts)
    final_previous_projection_dispatches = [
        record for record in final_dispatches if record["member_was_previous_projection_pointer"]
    ]
    projection_or_cleanup_counts = {
        address: address_counts.get(address, 0) for address in sorted(PROJECTION_METHOD_AND_CLEANUP_SITES)
    }
    return {
        "schema_id": "h3maped_540b14_same_wrapper_lifetime_summary_v1",
        "ledger": ledger.get("log_path", ""),
        "event_count": int(ledger.get("event_count", len(events))),
        "breakpoints": ledger.get("breakpoints", []),
        "address_counts": dict(sorted(address_counts.items())),
        "projection_selected_returns": projection_returns,
        "wrapper_returns_with_projection_members": wrapper_returns,
        "reselected_previous_projection_addresses": reselected,
        "final_dispatches": final_dispatches,
        "final_dispatches_of_previous_projection_addresses": final_previous_projection_dispatches,
        "projection_method_and_cleanup_counts": projection_or_cleanup_counts,
        "invariants": {
            "same_log_has_projection_returns_and_final_commits": bool(projection_returns)
            and address_counts.get(FINAL_COMMIT_SITE, 0) > 0
            and address_counts.get(FINAL_SLOT8_SITE, 0) > 0,
            "projection_members_reach_wrapper_return": bool(wrapper_returns),
            "previous_projection_address_reselected_as_non_projection": bool(reselected),
            "previous_projection_address_final_dispatches_as_ordinary_slot8": bool(
                final_previous_projection_dispatches
            )
            and all(record["slot8_target"] == "0x0049baf5" for record in final_previous_projection_dispatches),
            "projection_methods_and_cleanup_not_hit": not any(projection_or_cleanup_counts.values()),
        },
        "recovered_boundary": (
            "In this Small 2-player/no-water Wine trace, 0x540b14 selected objects are observed in "
            "0x4aa1db wrapper return vectors, but no 0x49c019/0x49c0a6/0x4ad947/0x4adb72/"
            "0x4adef7/0x4add76 method or cleanup target executes. One previously projection-backed "
            "heap address is later reselected as ordinary vtable 0x540a74 and final 0x4aa3e9 dispatch "
            "calls its ordinary slot +0x08 target 0x49baf5."
        ),
        "remaining_gap": (
            "The exact mutator between the projection wrapper return and the later ordinary reselection "
            "is still unrecovered: this trace does not prove whether the projection object is destroyed, "
            "freed/reused by the allocator, or overwritten by a constructor before the later 0x4aa168 "
            "ordinary return."
        ),
        "native_behavior_changed": False,
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
        "RMG_H3MAPED_540B14_SAME_WRAPPER_LIFETIME_SUMMARY "
        f"status={status} events={summary['event_count']} "
        f"projection_returns={len(summary['projection_selected_returns'])} "
        f"wrapper_projection_returns={len(summary['wrapper_returns_with_projection_members'])} "
        f"final_previous_projection_dispatches={len(summary['final_dispatches_of_previous_projection_addresses'])} "
        f"out={args.out}"
    )
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
