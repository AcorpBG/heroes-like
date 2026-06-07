#!/usr/bin/env python3
"""Summarize H3MapEd 49c projection-object consumer/stamp path evidence."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

from rmg_h3maped_4aa3e9_ordered_summary import hex32, normalize_address


DEFAULT_LEDGER = Path(
    ".artifacts/rmg_recovery/direct_generation_49c_consumer_stamp_trace/winedbg_interactive_trace_ledger.json"
)

SELECTED_RETURN_SITE = "0x004aa168"
INITIAL_CONSUME_SITE = "0x004aa22b"
INITIAL_ACCEPT_SITE = "0x004aa23d"
INITIAL_STAMP_ARG_SITE = "0x004aa27e"
SECONDARY_CONSUME_SITE = "0x004aa2fd"
SECONDARY_VALIDATE_SITE = "0x004aa30e"
SECONDARY_VALIDATOR_SITE = "0x0049d471"
SECONDARY_STAMP_ARG_SITE = "0x0049d636"
STAMP_HELPER_SITE = "0x0049abd6"

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


def object_record(event: dict[str, Any], pointer: int | None) -> dict[str, Any]:
    words = words_at(event, pointer)
    return {
        "pointer": hex32(pointer) if pointer is not None else "missing",
        "vtable": hex32(words[0]) if words else "missing-memory",
        "words": [hex32(word) for word in words],
        "field_plus_1c": hex32(words[7]) if len(words) > 7 else "missing",
        "field_plus_20": hex32(words[8]) if len(words) > 8 else "missing",
        "field_plus_24": hex32(words[9]) if len(words) > 9 else "missing",
    }


def object_record_from_register(event: dict[str, Any], register: str) -> dict[str, Any]:
    return object_record(event, event.get("registers", {}).get(register))


def stack_word(event: dict[str, Any], word_index: int) -> int | None:
    return word_at(event, event.get("registers", {}).get("esp"), word_index)


def next_non_constructor_events(events: list[dict[str, Any]], start_index: int, count: int = 10) -> list[tuple[int, dict[str, Any]]]:
    return [
        (index, events[index])
        for index in range(start_index + 1, min(len(events), start_index + 1 + count))
    ]


def summarize_projection_return(
    events: list[dict[str, Any]], index: int, selected_event: dict[str, Any], pre_return_event: dict[str, Any]
) -> dict[str, Any]:
    selected_pointer = selected_event.get("registers", {}).get("eax")
    record: dict[str, Any] = {
        "event_index": index + 1,
        "constructor_pre_return_site": normalize_address(pre_return_event.get("address", "0")),
        "constructor_name": CONSTRUCTOR_PRE_RETURNS.get(normalize_address(pre_return_event.get("address", "0")), "unknown"),
        "selected_return_site": SELECTED_RETURN_SITE,
        "selected_object": object_record_from_register(selected_event, "eax"),
        "consumer_path": "missing",
        "path_events": [],
        "initial_stamp_arg_at_0x4aa27e": "missing",
        "stamp_helper_arg_at_0x49abd6": "missing",
        "stamp_helper_arg_matches_selected_object": False,
        "secondary_validator_arg_matches_selected_object": False,
    }

    path_events: list[str] = []
    for event_index, event in next_non_constructor_events(events, index, 14):
        address = normalize_address(event.get("address", "0"))
        path_events.append(address)
        if address == INITIAL_CONSUME_SITE:
            record["consumer_path"] = "initial_0x4aa22b"
        elif address == SECONDARY_CONSUME_SITE:
            record["consumer_path"] = "secondary_0x4aa2fd"
        elif address == INITIAL_STAMP_ARG_SITE and selected_pointer is not None:
            arg = stack_word(event, 0)
            record["initial_stamp_arg_at_0x4aa27e"] = hex32(arg) if arg is not None else "missing"
        elif address == STAMP_HELPER_SITE and selected_pointer is not None:
            arg = stack_word(event, 1)
            record["stamp_helper_arg_at_0x49abd6"] = hex32(arg) if arg is not None else "missing"
            record["stamp_helper_arg_matches_selected_object"] = arg == selected_pointer
            break
        elif address == SECONDARY_VALIDATE_SITE and selected_pointer is not None:
            record["secondary_validator_arg_matches_selected_object"] = (
                event.get("registers", {}).get("esi") == selected_pointer
            )
        elif address == SECONDARY_STAMP_ARG_SITE and selected_pointer is not None:
            arg = stack_word(event, 0)
            record["secondary_stamp_arg_at_0x49d636"] = hex32(arg) if arg is not None else "missing"

    record["path_events"] = path_events
    return record


def summarize(ledger: dict[str, Any]) -> dict[str, Any]:
    events = ledger.get("events", [])
    addresses = [normalize_address(event.get("address", "0")) for event in events if event.get("address")]
    address_counts = Counter(addresses)

    projection_return_records: list[dict[str, Any]] = []
    for index, event in enumerate(events):
        address = normalize_address(event.get("address", "0"))
        if address != SELECTED_RETURN_SITE or index == 0:
            continue
        pre_return_event = events[index - 1]
        pre_return_address = normalize_address(pre_return_event.get("address", "0"))
        if pre_return_address not in CONSTRUCTOR_PRE_RETURNS:
            continue
        selected_object = object_record_from_register(event, "eax")
        if selected_object.get("vtable") not in PROJECTION_OBJECT_VTABLES:
            continue
        projection_return_records.append(summarize_projection_return(events, index, event, pre_return_event))

    consumer_paths = Counter(record["consumer_path"] for record in projection_return_records)
    projection_vtables = Counter(record["selected_object"]["vtable"] for record in projection_return_records)
    constructor_names = Counter(record["constructor_name"] for record in projection_return_records)

    return {
        "schema_id": "h3maped_49c_consumer_stamp_summary_v1",
        "ledger": ledger.get("log_path", ""),
        "event_count": int(ledger.get("event_count", len(events))),
        "breakpoints": ledger.get("breakpoints", []),
        "address_counts": dict(sorted(address_counts.items())),
        "projection_return_records": projection_return_records,
        "projection_return_vtable_counts": dict(sorted(projection_vtables.items())),
        "projection_return_constructor_counts": dict(sorted(constructor_names.items())),
        "projection_return_consumer_path_counts": dict(sorted(consumer_paths.items())),
        "static_consumer_contract": {
            "0x4aa22b_initial": "accepted EAX object is stored in [EBP+0x0c], appended to wrapper+0x28, and passed to 0x49abd6 at 0x4aa27e with selected coordinates",
            "0x4aa2fd_secondary": "accepted EAX object is moved to ESI, validated by 0x49d471, and only stamped through 0x49d636 -> 0x49abd6 if the validator accepts",
            "0x49abd6": "stamp helper receives object record at stack +0x04 and coordinate triple at stack +0x08/+0x0c/+0x10",
        },
        "invariants": {
            "projection_constructor_returns_observed": bool(projection_return_records),
            "sampled_projection_returns_are_0x540b14": bool(projection_return_records)
            and set(projection_vtables) == {"0x00540b14"},
            "sampled_projection_returns_enter_initial_consumer": bool(projection_return_records)
            and set(consumer_paths) == {"initial_0x4aa22b"},
            "sampled_projection_returns_reach_stamp_helper": bool(projection_return_records)
            and all(record["stamp_helper_arg_matches_selected_object"] for record in projection_return_records),
            "sampled_projection_returns_do_not_enter_secondary_validator": bool(projection_return_records)
            and not any(record["secondary_validator_arg_matches_selected_object"] for record in projection_return_records),
        },
        "notes": [
            "This recovers the sampled post-adoption consumer/stamp path for 0x540b14 projection objects.",
            "Both sampled 0x540b14 projection returns enter the initial 0x4aa22b path and are passed as the object argument to 0x49abd6.",
            "No sampled 0x540b14 projection return enters the secondary 0x4aa2fd/0x49d471 validator path in this trace.",
            "This trace did not instrument later 0x540b14+0x08/0x540b00+0x08 method dispatch; that remains the next unrecovered runtime surface.",
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
        "RMG_H3MAPED_49C_CONSUMER_STAMP_SUMMARY "
        f"status={status} events={summary['event_count']} "
        f"projection_returns={sum(summary['projection_return_vtable_counts'].values())} "
        f"paths={summary['projection_return_consumer_path_counts']} out={args.out}"
    )
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
