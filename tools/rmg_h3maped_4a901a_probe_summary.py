#!/usr/bin/env python3
"""Summarize a same-run probe for the 0x4a901a / 0x540a9c producer path.

This is recovery evidence only. It intentionally does not change native RMG
behavior. The sampled run is useful because it proves that the ordinary
0x540a9c payload records in this trace are not runtime evidence for a hit
0x4a901a constructor path.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_LEDGER = Path(
    ".artifacts/rmg_recovery/same_run_4a901a_probe_trace_20260608/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_STATIC_4A901A = Path(
    ".artifacts/rmg_recovery/ghidra_object_projection_helper_dump/"
    "caller_004a901a_FUN_004a901a.txt"
)
DEFAULT_OUT = Path(".artifacts/rmg_recovery/same_run_4a901a_probe_summary_20260608.json")

PROBE_ADDRESSES = [
    "0x004a901a",
    "0x004a92bb",
    "0x004a92d5",
    "0x004a9322",
    "0x004a9325",
]
OBSERVED_ADDRESSES = ["0x004a54d6", "0x004a7d36", "0x004a7d99"]

STAMP_POST_CALL = "0x004a54d6"
PAYLOAD_RECORD = "0x004a7d36"
PAYLOAD_COUNT = "0x004a7d99"

VTABLE_540A9C = 0x00540A9C
VTABLE_540A88 = 0x00540A88


def hex32(value: int | None) -> str | None:
    return None if value is None else f"0x{value & 0xFFFFFFFF:08x}"


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


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


def record_words_at_register(event: dict[str, Any], register: str, count: int = 12) -> list[int | None]:
    pointer = event.get("registers", {}).get(register)
    return memory_words(event, pointer if isinstance(pointer, int) else None, count)


def find_record_line_pointer(event: dict[str, Any]) -> int | None:
    for line in event.get("memory_lines", []):
        words = line.get("words", [])
        if words and int(words[0]) in {VTABLE_540A9C, VTABLE_540A88}:
            return int(line.get("address", 0))
    return None


def record_summary(pointer: int | None, words: list[int | None]) -> dict[str, Any]:
    return {
        "record_pointer": hex32(pointer),
        "record_vtable": hex32(words[0] if len(words) > 0 else None),
        "descriptor_pointer": hex32(words[1] if len(words) > 1 else None),
        "coordinate_words_08_10": [
            words[2] if len(words) > 2 else None,
            words[3] if len(words) > 3 else None,
            words[4] if len(words) > 4 else None,
        ],
        "field_18": hex32(words[6] if len(words) > 6 else None),
        "field_1c_sequence": words[7] if len(words) > 7 else None,
        "field_20_index": words[8] if len(words) > 8 else None,
        "field_24": hex32(words[9] if len(words) > 9 else None),
        "field_24_low_byte": (words[9] & 0xFF) if len(words) > 9 and words[9] is not None else None,
        "field_28": words[10] if len(words) > 10 else None,
        "field_2c": words[11] if len(words) > 11 else None,
        "record_words": [hex32(word) for word in words],
    }


def afterstamp_records(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for index, event in enumerate(events):
        if event.get("address") != STAMP_POST_CALL:
            continue
        pointer = find_record_line_pointer(event)
        records.append(
            {
                "event_index": index,
                "record_pointer": hex32(pointer),
                "record": record_summary(pointer, memory_words(event, pointer, 12)),
            }
        )
    return records


def payload_records(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for index, event in enumerate(events):
        if event.get("address") != PAYLOAD_RECORD:
            continue
        pointer = event.get("registers", {}).get("edx")
        if not isinstance(pointer, int) or pointer == 0:
            records.append({"event_index": index, "record_pointer": hex32(pointer if isinstance(pointer, int) else None), "record": None})
            continue
        records.append(
            {
                "event_index": index,
                "record_pointer": hex32(pointer),
                "record": record_summary(pointer, record_words_at_register(event, "edx")),
            }
        )
    return records


def vtable_counts(records: list[dict[str, Any]]) -> dict[str, int]:
    counts = Counter()
    for record in records:
        summary = record.get("record")
        if not summary:
            continue
        counts[summary.get("record_vtable")] += 1
    return dict(sorted(counts.items()))


def static_contract(path: Path) -> dict[str, Any]:
    exists = path.exists()
    text = path.read_text(encoding="utf-8", errors="replace") if exists else ""
    return {
        "source_file": str(path),
        "available": exists,
        "static_only_not_runtime_proof": True,
        "contract": {
            "entry": "0x004a901a",
            "base_record_constructor_call": "0x004a92bb -> 0x0049ba89",
            "vtable_write": "0x004a92c3 writes 0x00540a9c",
            "source_pointer_write": "0x004a92c9 writes [record+0x20] from arg_10",
            "control_byte_write": "0x004a92cf writes [record+0x24] from arg_14",
            "dispatch": "0x004a9322 calls vtable slot +0x04, statically matching 0x4a54a7 in adjacent evidence",
            "generated_vector_append": "0x004a9347 appends an adjusted coordinate through 0x004ae1fd",
        },
        "contains_expected_sites": all(
            marker in text
            for marker in [
                "004a901a",
                "004a92bb",
                "004a92c3",
                "004a9322",
                "004a9347",
            ]
        )
        if exists
        else False,
    }


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    ledger = load_json(args.ledger)
    events = ledger.get("events", [])
    counts = Counter(event.get("address") for event in events)

    afterstamp = afterstamp_records(events)
    payload = payload_records(events)
    non_null_payload = [record for record in payload if record.get("record")]
    payload_count_event = next((event for event in events if event.get("address") == PAYLOAD_COUNT), {})
    payload_count = payload_count_event.get("registers", {}).get("edx")

    afterstamp_pointers = [record.get("record_pointer") for record in afterstamp]
    payload_pointers = [record.get("record_pointer") for record in non_null_payload]
    paired = []
    payload_by_pointer = {record.get("record_pointer"): record for record in non_null_payload}
    for index, record in enumerate(afterstamp):
        pointer = record.get("record_pointer")
        payload_record = payload_by_pointer.get(pointer)
        paired.append(
            {
                "pair_index": index,
                "record_pointer": pointer,
                "afterstamp_event_index": record.get("event_index"),
                "payload_event_index": payload_record.get("event_index") if payload_record else None,
                "same_pointer_reaches_payload": payload_record is not None,
                "afterstamp_vtable": record.get("record", {}).get("record_vtable"),
                "payload_vtable": (payload_record or {}).get("record", {}).get("record_vtable"),
                "afterstamp_coordinates": record.get("record", {}).get("coordinate_words_08_10"),
                "payload_coordinates": (payload_record or {}).get("record", {}).get("coordinate_words_08_10"),
                "coordinates_match": record.get("record", {}).get("coordinate_words_08_10")
                == (payload_record or {}).get("record", {}).get("coordinate_words_08_10"),
            }
        )

    invariants = {
        "no_4a901a_probe_address_was_hit": all(counts.get(address, 0) == 0 for address in PROBE_ADDRESSES),
        "ordinary_projection_stream_was_observed": counts.get(STAMP_POST_CALL, 0) == 19
        and counts.get(PAYLOAD_RECORD, 0) == 20
        and counts.get(PAYLOAD_COUNT, 0) == 1,
        "non_null_payload_count_matches_4a7d99_edx": len(non_null_payload) == payload_count == 19,
        "afterstamp_and_payload_pointers_match_by_set": sorted(afterstamp_pointers) == sorted(payload_pointers),
        "afterstamp_and_payload_pointers_match_by_order": afterstamp_pointers == payload_pointers,
        "observed_vtables_are_expected_ordinary_records": vtable_counts(afterstamp)
        == {"0x00540a88": 11, "0x00540a9c": 8}
        and vtable_counts(non_null_payload) == {"0x00540a88": 11, "0x00540a9c": 8},
    }

    status = (
        "same_run_4a901a_not_hit_payload_ordinary_records_observed"
        if all(invariants.values())
        else "same_run_4a901a_probe_summary_incomplete"
    )
    return {
        "schema_id": "rmg_h3maped_4a901a_probe_summary.v1",
        "status": status,
        "source_ledger": str(args.ledger),
        "trace_event_count": len(events),
        "hit_counts": {address: counts.get(address, 0) for address in [*PROBE_ADDRESSES, *OBSERVED_ADDRESSES]},
        "vtable_counts": {
            "afterstamp_4a54d6": vtable_counts(afterstamp),
            "payload_4a7d36_non_null": vtable_counts(non_null_payload),
        },
        "payload": {
            "total_4a7d36_events": len(payload),
            "null_payload_events": len(payload) - len(non_null_payload),
            "non_null_payload_records": len(non_null_payload),
            "payload_count_edx_at_4a7d99": payload_count,
        },
        "pointer_handoff": {
            "afterstamp_record_pointers": afterstamp_pointers,
            "payload_record_pointers": payload_pointers,
            "pairs": paired,
        },
        "static_4a901a_contract": static_contract(args.static_4a901a),
        "invariants": invariants,
        "recovery_meaning": {
            "recovered": "The sampled run's ordinary object-record payload stream is internally paired through 0x4a54d6 -> 0x4a7d36.",
            "not_recovered": "This trace does not recover a runtime 0x4a901a producer chain because every 0x4a901a-family breakpoint was cold.",
            "next_required_step": "Drive or identify a natural H3MapEd path that actually hits 0x4a901a/0x4a8db2, then capture constructor, 0x4a54a7 projection, generated-cell before/after, and vector deltas in that same run.",
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--static-4a901a", type=Path, default=DEFAULT_STATIC_4A901A)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_4A901A_PROBE_SUMMARY status={summary['status']} out={args.out}")
    return 0 if summary["status"] == "same_run_4a901a_not_hit_payload_ordinary_records_observed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
