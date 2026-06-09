#!/usr/bin/env python3
"""Summarize live H3MapEd object-vector growth inside 0x4a79a3.

This is a recovery checkpoint only. It identifies where the generator object
vector grows during the sampled 0x4a79a3 path without changing native RMG.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_LEDGER = Path(
    ".artifacts/rmg_recovery/4a79a3_internal_growth_entries_trace_20260609/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_OUT = Path(".artifacts/rmg_recovery/4a79a3_internal_growth_summary_20260609.json")

ADDR_ENTRY = "0x004a79a3"
ADDR_AFTER_LOOKUP = "0x004a7be4"
ADDR_AFTER_4A61BC = "0x004a7bfa"
ADDR_AFTER_4A696B = "0x004a7c09"
ADDR_AFTER_4A6CF2 = "0x004a7c24"
ADDR_PAYLOAD_GATE = "0x004a7d2c"
ADDR_PAYLOAD = "0x004a7d36"
ADDR_PAYLOAD_DONE = "0x004a7d99"
ADDR_OPTIONAL_HANDLER = "0x004a7e80"


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
    if address == ADDR_OPTIONAL_HANDLER:
        # At this site EBX is still the generator. The following 0x4a7e96 stop
        # has already replaced EBX with generator+0xed4 and is intentionally
        # not treated as a generator snapshot.
        return registers.get("ebx")
    return registers.get("ebx")


def memory_line_at(event: dict[str, Any], address: int) -> list[int] | None:
    for line in event.get("memory_lines", []):
        if line.get("address") == address:
            return list(line.get("words", []))
    return None


def vector_entries(event: dict[str, Any], begin: int, count: int) -> list[str]:
    entries: list[str] = [""] * count
    for line in event.get("memory_lines", []):
        address = int(line.get("address", -1))
        if address < begin or address >= begin + count * 4:
            continue
        first_index = (address - begin) // 4
        for offset, word in enumerate(line.get("words", [])):
            index = first_index + offset
            if 0 <= index < count:
                entries[index] = hex32(word) or ""
    return entries


def object_vector_snapshot(event: dict[str, Any]) -> dict[str, Any] | None:
    generator = event_generator(event)
    if generator is None:
        return None
    words = memory_line_at(event, generator + 0xEC4)
    if not words or len(words) < 4:
        return None
    anchor, begin, end, capacity = words[:4]
    byte_span = end - begin
    cap_span = capacity - begin
    count = byte_span // 4 if byte_span >= 0 and byte_span % 4 == 0 else None
    capacity_count = cap_span // 4 if cap_span >= 0 and cap_span % 4 == 0 else None
    entries = vector_entries(event, begin, count or 0) if count is not None else []
    return {
        "generator": hex32(generator),
        "anchor": hex32(anchor),
        "begin": hex32(begin),
        "end": hex32(end),
        "capacity": hex32(capacity),
        "count": count,
        "capacity_count": capacity_count,
        "entries": entries,
    }


def event_summary(index: int, event: dict[str, Any]) -> dict[str, Any]:
    registers = event.get("registers", {})
    vector = object_vector_snapshot(event)
    return {
        "event_index": index,
        "address": event_address(event),
        "eax": hex32(registers.get("eax")),
        "ebx": hex32(registers.get("ebx")),
        "ecx": hex32(registers.get("ecx")),
        "edx": hex32(registers.get("edx")),
        "esi": hex32(registers.get("esi")),
        "edi": hex32(registers.get("edi")),
        "object_vector": vector,
    }


def append_pairs(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    pairs: list[dict[str, Any]] = []
    pending: tuple[int, dict[str, Any], dict[str, Any] | None] | None = None
    for index, event in enumerate(events):
        address = event_address(event)
        if address == ADDR_AFTER_LOOKUP:
            pending = (index, event, object_vector_snapshot(event))
            continue
        if address != ADDR_AFTER_4A61BC or pending is None:
            continue
        pre_index, _pre_event, pre_vector = pending
        post_vector = object_vector_snapshot(event)
        pending = None
        pre_count = pre_vector.get("count") if pre_vector else None
        post_count = post_vector.get("count") if post_vector else None
        appended: list[str] = []
        if isinstance(pre_count, int) and isinstance(post_count, int) and post_count > pre_count:
            appended = (post_vector.get("entries") or [])[pre_count:post_count]
        pairs.append(
            {
                "pre_event_index": pre_index,
                "post_event_index": index,
                "return_eax": hex32(event.get("registers", {}).get("eax")),
                "return_al_nonzero": bool((event.get("registers", {}).get("eax") or 0) & 0xFF),
                "pre_count": pre_count,
                "post_count": post_count,
                "pre_begin": pre_vector.get("begin") if pre_vector else None,
                "post_begin": post_vector.get("begin") if post_vector else None,
                "pre_capacity_count": pre_vector.get("capacity_count") if pre_vector else None,
                "post_capacity_count": post_vector.get("capacity_count") if post_vector else None,
                "reallocated": bool(
                    pre_vector
                    and post_vector
                    and pre_vector.get("begin") != post_vector.get("begin")
                ),
                "appended_entries": appended,
            }
        )
    return pairs


def summarize(ledger_path: Path) -> dict[str, Any]:
    ledger = read_json(ledger_path)
    events = ledger.get("events", [])
    summaries = [event_summary(index, event) for index, event in enumerate(events)]
    pairs = append_pairs(events)
    positive_pairs = [pair for pair in pairs if (pair.get("post_count") or 0) > (pair.get("pre_count") or 0)]
    reallocation_pairs = [pair for pair in pairs if pair.get("reallocated")]
    reached_payload_loop = any(
        event_address(event) in {ADDR_PAYLOAD_GATE, ADDR_PAYLOAD, ADDR_PAYLOAD_DONE}
        for event in events
    )
    return {
        "schema": "h3maped_rmg_4a79a3_internal_growth_summary_v1",
        "ledger": str(ledger_path),
        "event_count": len(events),
        "address_counts": dict(sorted(Counter(event_address(event) for event in events).items())),
        "child_returncode": ledger.get("child_returncode"),
        "reached_payload_loop": reached_payload_loop,
        "object_vector_sequence": [
            {
                "event_index": item["event_index"],
                "address": item["address"],
                "count": (item.get("object_vector") or {}).get("count"),
                "capacity_count": (item.get("object_vector") or {}).get("capacity_count"),
                "begin": (item.get("object_vector") or {}).get("begin"),
                "end": (item.get("object_vector") or {}).get("end"),
                "capacity": (item.get("object_vector") or {}).get("capacity"),
            }
            for item in summaries
            if item.get("object_vector")
        ],
        "append_pairs_after_0x4a61bc": pairs,
        "positive_append_count": len(positive_pairs),
        "reallocation_count": len(reallocation_pairs),
        "appended_entries": [
            entry
            for pair in positive_pairs
            for entry in pair.get("appended_entries", [])
        ],
        "recovered_contract": (
            "In this sampled 0x4a79a3 run, the generator object vector is already "
            "non-empty at entry and grows before the payload loop through repeated "
            "0x49b3fb -> 0x4a61bc pairs. Each positive 0x4a61bc return at "
            "0x4a7bfa appends one object-record pointer to generator+0xec8/+0xecc; "
            "one sampled append reallocates the vector when count advances past "
            "capacity 8. The trace does not reach the later 0x4a7d2c/0x4a7d36 "
            "payload loop, so payload-loop mutation remains separate pending work."
        ),
        "remaining_gap": (
            "Recover 0x4a61bc callee-side object construction/commit semantics and "
            "generated-cell mutations for these appended records, then connect that "
            "ordered growth to the later 0x4a7d2c payload loop and downstream "
            "0x4a696b/0x4a7605 paths."
        ),
        "native_behavior_changed": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    summary = summarize(args.ledger)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_4A79A3_INTERNAL_GROWTH "
        f"events={summary['event_count']} "
        f"positive_appends={summary['positive_append_count']} "
        f"reallocations={summary['reallocation_count']} "
        f"out={args.out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
