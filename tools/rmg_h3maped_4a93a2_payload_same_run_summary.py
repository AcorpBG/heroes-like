#!/usr/bin/env python3
"""Summarize same-run 0x4a93a2 record materialization into 0x4a79a3 payload.

This is recovery evidence only. It verifies that records created by the
0x4a93a2 ordinary-record producer in a live run later appear in the 0x4a79a3
payload loop, without changing native RMG behavior.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_LEDGER = Path(
    ".artifacts/rmg_recovery/same_run_4a93a2_payload_link_trace_lite_20260608/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_STATIC_4A93A2 = Path(
    ".artifacts/rmg_recovery/ghidra_object_projection_helper_dump/"
    "caller_004a93a2_FUN_004a93a2.txt"
)
DEFAULT_OUT = Path(".artifacts/rmg_recovery/same_run_4a93a2_payload_link_summary_20260608.json")

ENTRY = "0x004a93a2"
VTABLE_WRITE = "0x004a9524"
RECORD_READY = "0x004a9536"
VIRTUAL_DISPATCH = "0x004a9583"
SOURCE_FLAG_WRITE = "0x004a95a4"
SOURCE_ROUTE_WRITE = "0x004a95e6"
PAYLOAD_ENTRY = "0x004a79a3"
PAYLOAD_RECORD = "0x004a7d36"
PAYLOAD_COUNT = "0x004a7d99"
ORDINARY_RELATION_VTABLE = 0x00540A9C


def hex32(value: int | None) -> str | None:
    return None if value is None else f"0x{value & 0xFFFFFFFF:08x}"


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""


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


def record_words_at_register(event: dict[str, Any], register: str, count: int = 12) -> list[int | None]:
    pointer = event.get("registers", {}).get(register)
    return memory_words(event, pointer if isinstance(pointer, int) else None, count)


def record_summary(pointer: int | None, words: list[int | None]) -> dict[str, Any]:
    return {
        "record_pointer": hex32(pointer),
        "record_vtable": hex32(words[0] if len(words) > 0 else None),
        "descriptor_pointer": hex32(words[1] if len(words) > 1 else None),
        "coordinate_or_payload_words_08_10": [
            words[2] if len(words) > 2 else None,
            words[3] if len(words) > 3 else None,
            words[4] if len(words) > 4 else None,
        ],
        "field_18": words[6] if len(words) > 6 else None,
        "field_1c_sequence": words[7] if len(words) > 7 else None,
        "field_20_index": words[8] if len(words) > 8 else None,
        "field_24": words[9] if len(words) > 9 else None,
        "field_24_low_byte": (words[9] & 0xFF) if len(words) > 9 and words[9] is not None else None,
        "field_28": words[10] if len(words) > 10 else None,
        "field_2c": words[11] if len(words) > 11 else None,
        "record_words": [hex32(word) for word in words],
    }


def entry_summary(index: int, event: dict[str, Any]) -> dict[str, Any]:
    words = stack_words(event, 6)
    regs = event.get("registers", {})
    return {
        "event_index": index,
        "generator_ecx": hex32(regs.get("ecx") if isinstance(regs.get("ecx"), int) else None),
        "source_record_arg": hex32(words[1] if len(words) > 1 else None),
        "route_or_mode_arg": words[2] if len(words) > 2 else None,
        "index_arg": words[3] if len(words) > 3 else None,
        "enabled_arg": words[4] if len(words) > 4 else None,
        "stack_words": [hex32(word) for word in words],
    }


def group_producer_cycles(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    cycles: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    for index, event in enumerate(events):
        address = event.get("address")
        if address == ENTRY:
            if current is not None:
                cycles.append(current)
            current = {"entry": entry_summary(index, event)}
        elif current is None:
            continue
        elif address == VTABLE_WRITE:
            regs = event.get("registers", {})
            esi = regs.get("esi")
            current["vtable_write"] = {
                "event_index": index,
                "record_pointer": hex32(esi if isinstance(esi, int) else None),
                "pre_write_record": record_summary(esi if isinstance(esi, int) else None, record_words_at_register(event, "esi")),
            }
        elif address == RECORD_READY:
            regs = event.get("registers", {})
            esi = regs.get("esi")
            current["record_ready"] = {
                "event_index": index,
                "record_pointer": hex32(esi if isinstance(esi, int) else None),
                "record": record_summary(esi if isinstance(esi, int) else None, record_words_at_register(event, "esi")),
            }
        elif address == VIRTUAL_DISPATCH:
            regs = event.get("registers", {})
            stack = stack_words(event, 8)
            current["virtual_dispatch"] = {
                "event_index": index,
                "record_pointer_from_stack": hex32(stack[0] if stack else None),
                "candidate_or_dispatch_eax": hex32(regs.get("eax") if isinstance(regs.get("eax"), int) else None),
                "relation_vtable_edx": hex32(regs.get("edx") if isinstance(regs.get("edx"), int) else None),
                "stack_words": [hex32(word) for word in stack],
            }
        elif address == SOURCE_FLAG_WRITE:
            current["source_flag_write"] = {"event_index": index}
        elif address == SOURCE_ROUTE_WRITE:
            current["source_route_write"] = {"event_index": index}
    if current is not None:
        cycles.append(current)
    return cycles


def payload_records(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for index, event in enumerate(events):
        if event.get("address") != PAYLOAD_RECORD:
            continue
        regs = event.get("registers", {})
        edx = regs.get("edx")
        if not isinstance(edx, int) or edx == 0:
            records.append(
                {
                    "event_index": index,
                    "record_pointer": hex32(edx if isinstance(edx, int) else None),
                    "record": None,
                }
            )
            continue
        records.append(
            {
                "event_index": index,
                "record_pointer": hex32(edx),
                "record": record_summary(edx, record_words_at_register(event, "edx")),
            }
        )
    return records


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    ledger = load_json(args.ledger)
    events = ledger.get("events", [])
    counts = Counter(event.get("address") for event in events)
    static_text = read_text(args.static_4a93a2)

    cycles = group_producer_cycles(events)
    payload = payload_records(events)
    non_null_payload = [record for record in payload if record["record_pointer"] not in {None, "0x00000000"}]
    ready_records = [cycle.get("record_ready", {}) for cycle in cycles]
    ready_pointers = [record.get("record_pointer") for record in ready_records]
    payload_pointers = [record["record_pointer"] for record in non_null_payload]
    first_payload_pointers = payload_pointers[: len(ready_pointers)]

    payload_by_pointer = {record["record_pointer"]: record for record in non_null_payload}
    paired_records: list[dict[str, Any]] = []
    for cycle_index, cycle in enumerate(cycles):
        ready = cycle.get("record_ready", {})
        pointer = ready.get("record_pointer")
        payload_record = payload_by_pointer.get(pointer)
        ready_record = ready.get("record", {})
        later_record = payload_record.get("record") if payload_record else None
        paired_records.append(
            {
                "cycle_index": cycle_index,
                "entry": cycle.get("entry"),
                "record_pointer": pointer,
                "ready_record": ready_record,
                "payload_record": later_record,
                "payload_event_index": payload_record.get("event_index") if payload_record else None,
                "same_pointer_reaches_payload": payload_record is not None,
                "index_arg_matches_ready_field_20": cycle.get("entry", {}).get("index_arg")
                == ready_record.get("field_20_index"),
                "index_arg_matches_payload_field_20": cycle.get("entry", {}).get("index_arg")
                == (later_record or {}).get("field_20_index"),
                "enabled_arg_matches_ready_field_24_low_byte": cycle.get("entry", {}).get("enabled_arg")
                == ready_record.get("field_24_low_byte"),
                "enabled_arg_matches_payload_field_24_low_byte": cycle.get("entry", {}).get("enabled_arg")
                == (later_record or {}).get("field_24_low_byte"),
                "coordinates_filled_after_ready": ready_record.get("coordinate_or_payload_words_08_10")
                != (later_record or {}).get("coordinate_or_payload_words_08_10"),
            }
        )

    count_event = next((event for event in events if event.get("address") == PAYLOAD_COUNT), {})
    shifted_count = count_event.get("registers", {}).get("edx")
    invariants = {
        "trace_reaches_payload_entry": counts.get(PAYLOAD_ENTRY, 0) == 1,
        "trace_reaches_payload_count": counts.get(PAYLOAD_COUNT, 0) == 1,
        "producer_cycles_reach_ready_records": len(ready_pointers) == counts.get(ENTRY, 0) >= 1,
        "producer_ready_records_are_540a9c": all(
            (record.get("record", {}).get("record_vtable") == "0x00540a9c") for record in ready_records
        ),
        "producer_ready_pointers_are_first_non_null_payload_records": ready_pointers == first_payload_pointers,
        "all_ready_records_reach_payload": all(pair["same_pointer_reaches_payload"] for pair in paired_records),
        "all_index_args_match_ready_and_payload_field_20": all(
            pair["index_arg_matches_ready_field_20"] and pair["index_arg_matches_payload_field_20"]
            for pair in paired_records
        ),
        "all_enabled_args_match_ready_and_payload_field_24_low_byte": all(
            pair["enabled_arg_matches_ready_field_24_low_byte"]
            and pair["enabled_arg_matches_payload_field_24_low_byte"]
            for pair in paired_records
        ),
        "coordinates_are_filled_between_ready_and_payload": any(
            pair["coordinates_filled_after_ready"] for pair in paired_records
        ),
        "payload_shifted_count_matches_non_null_payload_records": shifted_count == len(non_null_payload),
        "static_4a93a2_key_writes_present": all(
            needle in static_text
            for needle in (
                "004a9524: MOV dword ptr [ESI],0x540a9c",
                "004a952a: MOV dword ptr [ESI + 0x20],EAX",
                "004a9530: MOV byte ptr [ESI + 0x24],AL",
                "004a9533: MOV dword ptr [ESI + 0x1c],EDI",
            )
        ),
    }
    status = "same_run_4a93a2_payload_link_recovered" if all(invariants.values()) else "incomplete"

    return {
        "schema_id": "h3maped_4a93a2_payload_same_run_summary_v1",
        "status": status,
        "native_behavior_changed": False,
        "inputs": {
            "ledger": str(args.ledger),
            "static_4a93a2": str(args.static_4a93a2),
        },
        "event_count": ledger.get("event_count", len(events)),
        "address_counts": dict(sorted((key, value) for key, value in counts.items() if key)),
        "payload_shifted_count_at_0x4a7d99": shifted_count,
        "producer_ready_record_pointers": ready_pointers,
        "first_non_null_payload_record_pointers": first_payload_pointers,
        "invariants": invariants,
        "paired_records": paired_records,
        "recovered_contract": [
            "In this same run, 0x4a93a2 creates ordinary 0x540a9c records.",
            "At 0x4a9536 the created records already have descriptor pointer, sequence field +0x1c, index field +0x20, and enabled byte +0x24 initialized.",
            "The same record pointers become the first non-null records consumed by the 0x4a79a3 payload loop at 0x4a7d36.",
            "The coordinate/payload words at +0x08/+0x0c/+0x10 are still unset at 0x4a9536 and populated before 0x4a7d36, so that fill mutation remains a separate recovery target.",
        ],
        "remaining_gap": (
            "Recover the exact mutation between 0x4a9536 and 0x4a7d36 that fills the created 0x540a9c "
            "record coordinate/payload fields, likely through the 0x4a9583 relation vslot path and 0x4a54a7. "
            "Then recover the analogous 0x4a5c07/0x540a88 and 0x4a901a/0x540a9c producer paths plus "
            "generated-cell/vector before/after deltas before native RMG behavior changes."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--static-4a93a2", type=Path, default=DEFAULT_STATIC_4A93A2)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_4A93A2_PAYLOAD_SAME_RUN_SUMMARY "
        f"status={summary['status']} out={args.out}"
    )
    return 0 if summary["status"] == "same_run_4a93a2_payload_link_recovered" else 1


if __name__ == "__main__":
    raise SystemExit(main())
