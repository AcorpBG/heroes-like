#!/usr/bin/env python3
"""Summarize the same-run 0x4a54a7 coordinate fill and payload handoff.

This is recovery evidence only. It verifies that ordinary 0x540a9c records
created by the 0x4a93a2 producer have unset coordinate fields at 0x4a9536,
are stamped by the 0x4a54a7 -> 0x49abd6 path, and later appear unchanged in
the 0x4a79a3/0x4a7d36 payload loop.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_STAMP_LEDGER = Path(
    ".artifacts/rmg_recovery/same_run_4a93a2_4a54a7_coord_fill_trace_20260608/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_PAYLOAD_LEDGER = Path(
    ".artifacts/rmg_recovery/same_run_4a93a2_4a54a7_afterstamp_to_payload_trace_20260608/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_STATIC_4A54A7 = Path(
    ".artifacts/rmg_recovery/ghidra_4a54a7_relation_vslot4_dump/"
    "target_004a54a7_FUN_004a54a7.txt"
)
DEFAULT_OUT = Path(".artifacts/rmg_recovery/same_run_4a54a7_coord_fill_summary_20260608.json")

RECORD_READY = "0x004a9536"
VIRTUAL_DISPATCH = "0x004a9583"
STAMP_PRE_CALL = "0x004a54d1"
STAMP_POST_CALL = "0x004a54d6"
PAYLOAD_RECORD = "0x004a7d36"
PAYLOAD_COUNT = "0x004a7d99"

ORDINARY_RELATION_VTABLE = 0x00540A9C
OBJECT_RELATION_VTABLE = 0x00540A88


def hex32(value: int | None) -> str | None:
    if value is None:
        return None
    return f"0x{value & 0xFFFFFFFF:08x}"


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


def stack_words(event: dict[str, Any], count: int) -> list[int | None]:
    esp = event.get("registers", {}).get("esp")
    return memory_words(event, esp if isinstance(esp, int) else None, count)


def record_words(event: dict[str, Any], pointer: int | None, count: int = 12) -> list[int | None]:
    return memory_words(event, pointer, count)


def record_words_at_register(event: dict[str, Any], register: str, count: int = 12) -> list[int | None]:
    pointer = event.get("registers", {}).get(register)
    return record_words(event, pointer if isinstance(pointer, int) else None, count)


def find_record_line_pointer(event: dict[str, Any]) -> int | None:
    for line in event.get("memory_lines", []):
        words = line.get("words", [])
        if words and int(words[0]) in {ORDINARY_RELATION_VTABLE, OBJECT_RELATION_VTABLE, 0x00540A74}:
            return int(line.get("address", 0))
    return None


def record_summary(pointer: int | None, words: list[int | None]) -> dict[str, Any]:
    coords = [
        words[2] if len(words) > 2 else None,
        words[3] if len(words) > 3 else None,
        words[4] if len(words) > 4 else None,
    ]
    return {
        "record_pointer": hex32(pointer),
        "record_vtable": hex32(words[0] if len(words) > 0 else None),
        "descriptor_pointer": hex32(words[1] if len(words) > 1 else None),
        "coordinate_words_08_10": coords,
        "field_18": hex32(words[6] if len(words) > 6 else None),
        "field_1c_sequence": words[7] if len(words) > 7 else None,
        "field_20_index": words[8] if len(words) > 8 else None,
        "field_24": hex32(words[9] if len(words) > 9 else None),
        "field_24_low_byte": (words[9] & 0xFF) if len(words) > 9 and words[9] is not None else None,
        "field_28": words[10] if len(words) > 10 else None,
        "field_2c": words[11] if len(words) > 11 else None,
        "record_words": [hex32(word) for word in words],
        "coordinate_fields_unset": coords == [0xFFFFFFFF, 0xFFFFFFFF, 0xFFFFFFFF],
        "coordinate_fields_set": all(value not in {None, 0xFFFFFFFF} for value in coords),
    }


def ready_records(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for index, event in enumerate(events):
        if event.get("address") != RECORD_READY:
            continue
        pointer = event.get("registers", {}).get("esi")
        if not isinstance(pointer, int):
            pointer = None
        records.append(
            {
                "event_index": index,
                "record_pointer": hex32(pointer),
                "record": record_summary(pointer, record_words(event, pointer)),
            }
        )
    return records


def virtual_dispatches(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    dispatches: list[dict[str, Any]] = []
    for index, event in enumerate(events):
        if event.get("address") != VIRTUAL_DISPATCH:
            continue
        words = stack_words(event, 6)
        dispatches.append(
            {
                "event_index": index,
                "record_pointer_from_stack": hex32(words[0] if len(words) > 0 else None),
                "x_arg": words[1] if len(words) > 1 else None,
                "y_arg": words[2] if len(words) > 2 else None,
                "level_arg": words[3] if len(words) > 3 else None,
                "stack_words": [hex32(word) for word in words],
            }
        )
    return dispatches


def stamp_records(events: list[dict[str, Any]], address: str) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for index, event in enumerate(events):
        if event.get("address") != address:
            continue
        pointer = find_record_line_pointer(event)
        records.append(
            {
                "event_index": index,
                "record_pointer": hex32(pointer),
                "record": record_summary(pointer, record_words(event, pointer)),
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


def pair_by_order(before: list[dict[str, Any]], after: list[dict[str, Any]]) -> list[dict[str, Any]]:
    pairs: list[dict[str, Any]] = []
    for index, (pre, post) in enumerate(zip(before, after)):
        pre_record = pre.get("record", {})
        post_record = post.get("record", {})
        pairs.append(
            {
                "pair_index": index,
                "pre_event_index": pre.get("event_index"),
                "post_event_index": post.get("event_index"),
                "record_pointer": post.get("record_pointer"),
                "same_pointer": pre.get("record_pointer") == post.get("record_pointer"),
                "pre_coordinates": pre_record.get("coordinate_words_08_10"),
                "post_coordinates": post_record.get("coordinate_words_08_10"),
                "has_captured_record_words": bool(pre_record.get("record_words")) and bool(post_record.get("record_words")),
                "coordinates_changed_from_unset_to_args": pre_record.get("coordinate_fields_unset")
                and post_record.get("coordinate_fields_set"),
                "pre_record": pre_record,
                "post_record": post_record,
            }
        )
    return pairs


def build_payload_handoff(events: list[dict[str, Any]]) -> dict[str, Any]:
    ready = ready_records(events)
    dispatches = virtual_dispatches(events)
    afterstamp = stamp_records(events, STAMP_POST_CALL)
    payload = payload_records(events)
    non_null_payload = [record for record in payload if record.get("record")]

    ready_by_pointer = {record["record_pointer"]: record for record in ready}
    after_by_pointer = {record["record_pointer"]: record for record in afterstamp}
    payload_by_pointer = {record["record_pointer"]: record for record in non_null_payload}

    produced: list[dict[str, Any]] = []
    for index, ready_record in enumerate(ready):
        pointer = ready_record["record_pointer"]
        dispatch = dispatches[index] if index < len(dispatches) else {}
        after_record = after_by_pointer.get(pointer)
        payload_record = payload_by_pointer.get(pointer)
        produced.append(
            {
                "cycle_index": index,
                "record_pointer": pointer,
                "ready_event_index": ready_record.get("event_index"),
                "dispatch_event_index": dispatch.get("event_index"),
                "afterstamp_event_index": after_record.get("event_index") if after_record else None,
                "payload_event_index": payload_record.get("event_index") if payload_record else None,
                "dispatch_args": {
                    "x": dispatch.get("x_arg"),
                    "y": dispatch.get("y_arg"),
                    "level": dispatch.get("level_arg"),
                },
                "ready_record": ready_record.get("record"),
                "afterstamp_record": after_record.get("record") if after_record else None,
                "payload_record": payload_record.get("record") if payload_record else None,
                "ready_unset": ready_record.get("record", {}).get("coordinate_fields_unset"),
                "dispatch_args_match_afterstamp_coordinates": [
                    dispatch.get("x_arg"),
                    dispatch.get("y_arg"),
                    dispatch.get("level_arg"),
                ]
                == ((after_record or {}).get("record") or {}).get("coordinate_words_08_10"),
                "afterstamp_coordinates_match_payload_coordinates": ((after_record or {}).get("record") or {}).get(
                    "coordinate_words_08_10"
                )
                == ((payload_record or {}).get("record") or {}).get("coordinate_words_08_10"),
                "same_record_reaches_payload": payload_record is not None,
            }
        )

    payload_count_event = next((event for event in events if event.get("address") == PAYLOAD_COUNT), {})
    shifted_count = payload_count_event.get("registers", {}).get("edx")
    return {
        "ready_records": ready,
        "virtual_dispatches": dispatches,
        "afterstamp_records": afterstamp,
        "payload_records": payload,
        "produced_0x4a93a2_records": produced,
        "counts": {
            "ready_records": len(ready),
            "afterstamp_records": len(afterstamp),
            "non_null_payload_records": len(non_null_payload),
            "payload_shifted_count_edx": shifted_count,
        },
        "invariants": {
            "all_ready_records_are_540a9c": all(
                record.get("record", {}).get("record_vtable") == hex32(ORDINARY_RELATION_VTABLE) for record in ready
            ),
            "all_ready_records_start_with_unset_coordinates": all(
                record.get("record", {}).get("coordinate_fields_unset") for record in ready
            ),
            "all_ready_records_have_matching_virtual_dispatch": len(ready) == len(dispatches)
            and all(
                ready[index]["record_pointer"] == dispatches[index]["record_pointer_from_stack"]
                for index in range(len(ready))
            ),
            "all_ready_records_have_afterstamp_records": all(
                record["record_pointer"] in after_by_pointer for record in ready
            ),
            "all_ready_records_reach_payload": all(record["record_pointer"] in payload_by_pointer for record in ready),
            "all_dispatch_args_match_afterstamp_coordinates": all(
                produced_record["dispatch_args_match_afterstamp_coordinates"] for produced_record in produced
            ),
            "all_afterstamp_coordinates_match_payload_coordinates": all(
                produced_record["afterstamp_coordinates_match_payload_coordinates"] for produced_record in produced
            ),
            "payload_count_matches_non_null_payload_records": shifted_count == len(non_null_payload),
        },
        "pointer_sets": {
            "ready": sorted(ready_by_pointer),
            "afterstamp": sorted(after_by_pointer),
            "payload": sorted(payload_by_pointer),
            "ready_afterstamp_overlap": sorted(set(ready_by_pointer) & set(after_by_pointer)),
            "ready_payload_overlap": sorted(set(ready_by_pointer) & set(payload_by_pointer)),
            "afterstamp_payload_overlap": sorted(set(after_by_pointer) & set(payload_by_pointer)),
        },
    }


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    stamp_ledger = load_json(args.stamp_ledger)
    payload_ledger = load_json(args.payload_ledger)
    stamp_events = stamp_ledger.get("events", [])
    payload_events = payload_ledger.get("events", [])
    pre_records = stamp_records(stamp_events, STAMP_PRE_CALL)
    post_records = stamp_records(stamp_events, STAMP_POST_CALL)
    stamp_pairs = pair_by_order(pre_records, post_records)
    captured_stamp_pairs = [pair for pair in stamp_pairs if pair["has_captured_record_words"]]
    payload_handoff = build_payload_handoff(payload_events)
    static_text = args.static_4a54a7.read_text(encoding="utf-8", errors="replace") if args.static_4a54a7.exists() else ""

    invariants = {
        "stamp_trace_has_pre_and_post_pairs": len(pre_records) == len(post_records) > 0,
        "stamp_trace_has_captured_record_pairs": len(captured_stamp_pairs) > 0,
        "captured_stamp_pairs_keep_same_record_pointer": all(pair["same_pointer"] for pair in captured_stamp_pairs),
        "captured_stamp_pairs_change_coordinates_from_unset_to_set": all(
            pair["coordinates_changed_from_unset_to_args"] for pair in captured_stamp_pairs
        ),
        "payload_trace_all_ready_records_are_stamped_and_payloaded": all(
            payload_handoff["invariants"].values()
        ),
        "static_4a54a7_calls_49abd6_before_post_breakpoint": all(
            needle in static_text
            for needle in (
                "004a54d1: CALL 0x0049abd6",
                "004a54d6: MOV ESI,dword ptr [EBP + -0x18]",
            )
        ),
    }

    return {
        "schema_id": "h3maped_4a54a7_coord_fill_same_run_summary_v1",
        "status": (
            "same_run_4a54a7_coordinate_fill_and_payload_handoff_recovered"
            if all(invariants.values())
            else "incomplete_4a54a7_coordinate_fill_recovery"
        ),
        "inputs": {
            "stamp_ledger": str(args.stamp_ledger),
            "payload_ledger": str(args.payload_ledger),
            "static_4a54a7": str(args.static_4a54a7),
        },
        "event_counts": {
            "stamp_ledger": dict(Counter(event.get("address") for event in stamp_events)),
            "payload_ledger": dict(Counter(event.get("address") for event in payload_events)),
        },
        "recovered_contract": {
            "0x4a93a2": "creates 0x540a9c records with descriptor/index/enabled fields but unset coordinate words",
            "0x4a9583": "dispatches the created record plus x/y/level stack arguments through the relation vslot",
            "0x4a54a7_0x4a54d1": "calls 0x49abd6 with the object record and coordinate triple",
            "0x4a54d6": "same record now has coordinate words +0x08/+0x0c/+0x10 filled",
            "0x4a7d36": "the same stamped records are consumed by the later payload loop",
        },
        "invariants": invariants,
        "capture_counts": {
            "stamp_pre_call_events": len(pre_records),
            "stamp_post_call_events": len(post_records),
            "captured_stamp_pairs": len(captured_stamp_pairs),
            "uncaptured_stamp_pairs": len(stamp_pairs) - len(captured_stamp_pairs),
        },
        "stamp_pairs": stamp_pairs,
        "payload_handoff": payload_handoff,
        "remaining_recovery_gaps": [
            "Recover analogous 0x4a5c07/0x540a88 producer path.",
            "Recover analogous 0x4a901a/0x540a9c producer path.",
            "Recover generated-cell/vector before/after deltas for these producer paths.",
            "Continue 0x4a696b nonzero candidate/direct mutation recovery.",
            "Recover natural 0x4a7605/0x4a746b/0x4a5e73 success/mutation path.",
            "Recover actual 0x4add76 cleanup/uncommit runtime path.",
        ],
        "native_rmg_behavior_changed": False,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stamp-ledger", type=Path, default=DEFAULT_STAMP_LEDGER)
    parser.add_argument("--payload-ledger", type=Path, default=DEFAULT_PAYLOAD_LEDGER)
    parser.add_argument("--static-4a54a7", type=Path, default=DEFAULT_STATIC_4A54A7)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_4A54A7_COORD_FILL_SUMMARY status={summary['status']} out={args.out}")


if __name__ == "__main__":
    main()
