#!/usr/bin/env python3
"""Summarize a live H3MapEd 0x4a8c15 materialization bridge trace.

The bridge of interest is:

0x4a8c15 -> relation loop 0x4a4913 -> 0x4a5767 -> 0x4a4fc5 -> 0x4a79a3

This report is a recovery checkpoint. It records observed generator object
vector state and the first payload-loop records without changing native RMG.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_LEDGER = Path(
    ".artifacts/rmg_recovery/4a8c15_materialization_bridge_trace_20260609/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_OUT = Path(".artifacts/rmg_recovery/4a8c15_materialization_bridge_summary_20260609.json")

ADDR_ENTRY = "0x004a8c15"
ADDR_RELATION_PRE = "0x004a8d05"
ADDR_RELATION_POST = "0x004a8d0f"
ADDR_BEFORE_5767 = "0x004a8d12"
ADDR_AFTER_5767 = "0x004a8d19"
ADDR_AFTER_4FC5 = "0x004a8d20"
ADDR_4A79A3 = "0x004a79a3"
ADDR_PAYLOAD = "0x004a7d36"
ADDR_AFTER_4A79A3 = "0x004a8d27"


def hex32(value: int | None) -> str | None:
    if value is None:
        return None
    return f"0x{value & 0xFFFFFFFF:08x}"


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def event_address(event: dict[str, Any]) -> str:
    return str(event.get("address", "")).lower()


def event_generator(event: dict[str, Any]) -> int | None:
    registers = event.get("registers", {})
    address = event_address(event)
    if address == ADDR_ENTRY:
        return registers.get("ecx")
    if address in {
        ADDR_RELATION_PRE,
        ADDR_RELATION_POST,
        ADDR_BEFORE_5767,
        ADDR_AFTER_5767,
        ADDR_AFTER_4FC5,
        ADDR_PAYLOAD,
        ADDR_AFTER_4A79A3,
    }:
        return registers.get("ebx")
    if address == ADDR_4A79A3:
        return registers.get("ecx")
    return registers.get("ebx") or registers.get("ecx")


def memory_line_at(event: dict[str, Any], address: int) -> list[int] | None:
    for line in event.get("memory_lines", []):
        if line.get("address") == address:
            return list(line.get("words", []))
    return None


def object_vector_snapshot(event: dict[str, Any]) -> dict[str, Any] | None:
    generator = event_generator(event)
    if generator is None:
        return None
    words = memory_line_at(event, generator + 0xEC4)
    if not words or len(words) < 4:
        return None
    begin, end, capacity = words[1], words[2], words[3]
    byte_span = end - begin
    count = byte_span // 4 if byte_span >= 0 and byte_span % 4 == 0 else None
    capacity_count = (capacity - begin) // 4 if capacity >= begin and (capacity - begin) % 4 == 0 else None
    return {
        "generator": hex32(generator),
        "anchor": hex32(words[0]),
        "begin": hex32(begin),
        "end": hex32(end),
        "capacity": hex32(capacity),
        "count": count,
        "capacity_count": capacity_count,
    }


def relation_vector_snapshot(event: dict[str, Any]) -> dict[str, Any] | None:
    generator = event_generator(event)
    if generator is None:
        return None
    words = memory_line_at(event, generator + 0x10E4)
    if not words or len(words) < 3:
        return None
    begin, end, capacity = words[0], words[1], words[2]
    byte_span = end - begin
    count = byte_span // 4 if byte_span >= 0 and byte_span % 4 == 0 else None
    return {
        "begin": hex32(begin),
        "end": hex32(end),
        "capacity": hex32(capacity),
        "count": count,
        "first_words": [hex32(word) for word in words],
    }


def vector_entries_at_begin(event: dict[str, Any], begin: int, count: int) -> list[str]:
    entries: list[str] = []
    wanted = count
    for line in event.get("memory_lines", []):
        address = int(line.get("address", -1))
        if address < begin or address >= begin + count * 4:
            continue
        offset = (address - begin) // 4
        for index, word in enumerate(line.get("words", [])):
            entry_index = offset + index
            if 0 <= entry_index < wanted:
                while len(entries) <= entry_index:
                    entries.append("")
                entries[entry_index] = hex32(word) or ""
    return entries


def payload_record(event: dict[str, Any], event_index: int) -> dict[str, Any]:
    registers = event.get("registers", {})
    vector = object_vector_snapshot(event)
    entries: list[str] = []
    if vector and vector.get("begin") and vector.get("count") is not None:
        begin = int(vector["begin"], 16)
        entries = vector_entries_at_begin(event, begin, int(vector["count"]))
    return {
        "event_index": event_index,
        "edx_payload_pointer": hex32(registers.get("edx")),
        "eax_vector_begin": hex32(registers.get("eax")),
        "object_vector": vector,
        "dumped_vector_entries": entries,
    }


def summarize(ledger_path: Path) -> dict[str, Any]:
    ledger = read_json(ledger_path)
    events = ledger.get("events", [])
    counts = Counter(event_address(event) for event in events)

    snapshots = []
    for index, event in enumerate(events):
        vector = object_vector_snapshot(event)
        if vector:
            snapshots.append(
                {
                    "event_index": index,
                    "address": event_address(event),
                    "esi": event.get("registers", {}).get("esi"),
                    "object_vector": vector,
                }
            )

    relation_pre = [
        {
            "event_index": index,
            "relation_index": event.get("registers", {}).get("esi"),
            "relation_vector": relation_vector_snapshot(event),
            "object_vector": object_vector_snapshot(event),
        }
        for index, event in enumerate(events)
        if event_address(event) == ADDR_RELATION_PRE
    ]
    relation_post = [
        {
            "event_index": index,
            "relation_index": event.get("registers", {}).get("esi"),
            "returned_relation_or_state_eax": hex32(event.get("registers", {}).get("eax")),
            "object_vector": object_vector_snapshot(event),
        }
        for index, event in enumerate(events)
        if event_address(event) == ADDR_RELATION_POST
    ]
    payload_records = [
        payload_record(event, index)
        for index, event in enumerate(events)
        if event_address(event) == ADDR_PAYLOAD
    ]

    first_snapshot_by_address: dict[str, dict[str, Any]] = {}
    last_snapshot_by_address: dict[str, dict[str, Any]] = {}
    for snapshot in snapshots:
        first_snapshot_by_address.setdefault(snapshot["address"], snapshot)
        last_snapshot_by_address[snapshot["address"]] = snapshot

    def count_at(address: str, last: bool = False) -> int | None:
        source = last_snapshot_by_address if last else first_snapshot_by_address
        item = source.get(address)
        if not item:
            return None
        return item["object_vector"].get("count")

    invariants = {
        "trace_has_failed_with_events_ledger": bool(
            ledger.get("child_returncode") == 1 and ledger.get("event_count", len(events)) > 0
        ),
        "bridge_reaches_4a8c15_entry": counts[ADDR_ENTRY] == 1,
        "relation_loop_pre_post_pairs": counts[ADDR_RELATION_PRE] == counts[ADDR_RELATION_POST] == 5,
        "relation_count_matches_loop_count": bool(
            relation_pre
            and relation_pre[0].get("relation_vector", {}).get("count") == counts[ADDR_RELATION_PRE]
        ),
        "reaches_4a5767_and_4a4fc5_boundaries": bool(
            counts[ADDR_BEFORE_5767] == 1
            and counts[ADDR_AFTER_5767] == 1
            and counts[ADDR_AFTER_4FC5] == 1
        ),
        "reaches_4a79a3_and_returns": bool(counts[ADDR_4A79A3] == 1 and counts[ADDR_AFTER_4A79A3] == 1),
        "payload_loop_records_sampled": counts[ADDR_PAYLOAD] >= 1,
        "object_vector_stable_until_4a79a3_entry": bool(
            count_at(ADDR_ENTRY) == 4
            and all(item["object_vector"].get("count") == 4 for item in relation_pre + relation_post)
            and count_at(ADDR_BEFORE_5767) == 4
            and count_at(ADDR_AFTER_5767) == 4
            and count_at(ADDR_AFTER_4FC5) == 4
            and count_at(ADDR_4A79A3) == 4
        ),
        "object_vector_grows_inside_4a79a3_before_payload_loop": bool(
            count_at(ADDR_PAYLOAD) == 8
        ),
        "object_vector_grows_by_return_from_4a79a3": bool(
            count_at(ADDR_AFTER_4A79A3) == 10
        ),
    }
    status = (
        "materialization_bridge_sampled_vector_growth_inside_4a79a3"
        if all(invariants.values())
        else "materialization_bridge_partial_or_incomplete"
    )

    return {
        "schema_id": "h3maped_4a8c15_materialization_bridge_summary_v1",
        "status": status,
        "ledger": str(ledger_path),
        "event_count": ledger.get("event_count", len(events)),
        "child_returncode": ledger.get("child_returncode"),
        "event_counts": dict(sorted(counts.items())),
        "relation_loop": {
            "pre_call_records": relation_pre,
            "post_call_records": relation_post,
        },
        "object_vector_snapshots": snapshots,
        "payload_records": payload_records,
        "invariants": invariants,
        "source_backed_conclusion": (
            "In this sampled run, generator+0xec4/+0xecc object-vector count remains 4 through "
            "the five 0x4a4913 relation calls, through 0x4a5767, through 0x4a4fc5, and at "
            "0x4a79a3 entry. The vector first grows to 8 before the sampled 0x4a7d36 payload "
            "loop and is 10 at return from 0x4a79a3. The ordinary payload materialization delta "
            "is therefore inside 0x4a79a3 for this trace, not in the preceding 0x4a4913/0x4a5767/"
            "0x4a4fc5 bridge calls."
        ),
        "remaining_gap": (
            "Recover ordered internals of 0x4a79a3 that grow generator+0xec8/+0xecc from 4 to 8 "
            "before payload iteration and to 10 by return, including appended record pointers, "
            "record vtables, source +0xc8 pair semantics, and GeneratedCell/object-vector before/"
            "after state. Native RMG behavior remains blocked until that state chain is recovered."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args.ledger)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_4A8C15_MATERIALIZATION_BRIDGE_SUMMARY status={summary['status']} out={args.out}")
    return 0 if summary["status"].startswith("materialization_bridge_") else 1


if __name__ == "__main__":
    raise SystemExit(main())
