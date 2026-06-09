#!/usr/bin/env python3
"""Summarize live H3MapEd object-vector growth inside 0x4a61bc.

This is a recovery checkpoint only. It identifies which sampled 0x4a61bc
internal boundary grows the generator object vector without changing native RMG.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_LEDGER = Path(
    ".artifacts/rmg_recovery/4a61bc_internal_append_trace_20260609/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_OUT = Path(".artifacts/rmg_recovery/4a61bc_internal_append_summary_20260609.json")

ADDR_ENTRY = "0x004a61bc"
ADDR_CANDIDATE_VECTOR = "0x004a633e"
ADDR_RANDOM_SELECT = "0x004a63f8"
ADDR_BEFORE_FIRST_PROJECT = "0x004a6479"
ADDR_AFTER_FIRST_PROJECT = "0x004a647e"
ADDR_AFTER_FIRST_LOCAL_APPEND = "0x004a649c"
ADDR_BEFORE_SECOND_PROJECT = "0x004a64b0"
ADDR_AFTER_SECOND_PROJECT = "0x004a64b5"
ADDR_AFTER_SECOND_LOCAL_APPEND = "0x004a64d3"
ADDR_AFTER_LOCAL_CLEANUP = "0x004a64e4"
ADDR_BORDER_GUARD_GATE = "0x004a64e7"
ADDR_FALLBACK_GATE = "0x004a6551"
ADDR_BEFORE_5E03 = "0x004a6578"
ADDR_AFTER_5E03 = "0x004a657d"
ADDR_BEFORE_FINAL_CLEANUP = "0x004a658d"
ADDR_SUCCESS_RETURN = "0x004a6592"

ORDERED_BOUNDARIES = [
    ADDR_ENTRY,
    ADDR_CANDIDATE_VECTOR,
    ADDR_RANDOM_SELECT,
    ADDR_BEFORE_FIRST_PROJECT,
    ADDR_AFTER_FIRST_PROJECT,
    ADDR_AFTER_FIRST_LOCAL_APPEND,
    ADDR_BEFORE_SECOND_PROJECT,
    ADDR_AFTER_SECOND_PROJECT,
    ADDR_AFTER_SECOND_LOCAL_APPEND,
    ADDR_AFTER_LOCAL_CLEANUP,
    ADDR_BORDER_GUARD_GATE,
    ADDR_FALLBACK_GATE,
    ADDR_BEFORE_5E03,
    ADDR_AFTER_5E03,
    ADDR_BEFORE_FINAL_CLEANUP,
    ADDR_SUCCESS_RETURN,
]


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
    if event_address(event) == ADDR_ENTRY:
        return registers.get("ecx")
    return registers.get("ebx")


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
    anchor, begin, end, capacity = words[:4]
    byte_span = end - begin
    cap_span = capacity - begin
    count = byte_span // 4 if byte_span >= 0 and byte_span % 4 == 0 else None
    capacity_count = cap_span // 4 if cap_span >= 0 and cap_span % 4 == 0 else None
    return {
        "generator": hex32(generator),
        "anchor": hex32(anchor),
        "begin": hex32(begin),
        "end": hex32(end),
        "capacity": hex32(capacity),
        "count": count,
        "capacity_count": capacity_count,
    }


def event_summary(index: int, event: dict[str, Any]) -> dict[str, Any]:
    registers = event.get("registers", {})
    return {
        "event_index": index,
        "address": event_address(event),
        "eax": hex32(registers.get("eax")),
        "ebx": hex32(registers.get("ebx")),
        "ecx": hex32(registers.get("ecx")),
        "edx": hex32(registers.get("edx")),
        "esi": hex32(registers.get("esi")),
        "edi": hex32(registers.get("edi")),
        "object_vector": object_vector_snapshot(event),
    }


def group_calls(events: list[dict[str, Any]]) -> list[list[dict[str, Any]]]:
    groups: list[list[dict[str, Any]]] = []
    current: list[dict[str, Any]] = []
    for index, event in enumerate(events):
        item = event_summary(index, event)
        if item["address"] == ADDR_ENTRY:
            if current:
                groups.append(current)
            current = [item]
        elif current:
            current.append(item)
    if current:
        groups.append(current)
    return groups


def count_at(group: list[dict[str, Any]], address: str) -> int | None:
    for item in group:
        if item["address"] == address:
            vector = item.get("object_vector") or {}
            count = vector.get("count")
            return count if isinstance(count, int) else None
    return None


def vector_at(group: list[dict[str, Any]], address: str) -> dict[str, Any] | None:
    for item in group:
        if item["address"] == address:
            vector = item.get("object_vector")
            return vector if isinstance(vector, dict) else None
    return None


def growth_edges(group: list[dict[str, Any]]) -> list[dict[str, Any]]:
    edges: list[dict[str, Any]] = []
    previous: dict[str, Any] | None = None
    for item in group:
        vector = item.get("object_vector")
        if not isinstance(vector, dict) or not isinstance(vector.get("count"), int):
            continue
        if previous:
            previous_vector = previous["object_vector"]
            previous_count = previous_vector["count"]
            current_count = vector["count"]
            if current_count > previous_count:
                edges.append(
                    {
                        "pre_event_index": previous["event_index"],
                        "pre_address": previous["address"],
                        "post_event_index": item["event_index"],
                        "post_address": item["address"],
                        "pre_count": previous_count,
                        "post_count": current_count,
                        "pre_begin": previous_vector.get("begin"),
                        "post_begin": vector.get("begin"),
                        "pre_capacity_count": previous_vector.get("capacity_count"),
                        "post_capacity_count": vector.get("capacity_count"),
                        "reallocated": previous_vector.get("begin") != vector.get("begin"),
                    }
                )
        previous = item
    return edges


def summarize_call(index: int, group: list[dict[str, Any]]) -> dict[str, Any]:
    entry_vector = vector_at(group, ADDR_ENTRY)
    before_5e03 = vector_at(group, ADDR_BEFORE_5E03)
    after_5e03 = vector_at(group, ADDR_AFTER_5E03)
    success = any(item["address"] == ADDR_SUCCESS_RETURN for item in group)
    edges = growth_edges(group)
    return {
        "call_index": index,
        "event_indexes": [item["event_index"] for item in group],
        "addresses": [item["address"] for item in group],
        "complete_success_path": success,
        "entry_count": (entry_vector or {}).get("count"),
        "success_count": count_at(group, ADDR_SUCCESS_RETURN),
        "counts_by_boundary": {
            address: count_at(group, address)
            for address in ORDERED_BOUNDARIES
            if count_at(group, address) is not None
        },
        "growth_edges": edges,
        "growth_across_0x4a5e03": bool(
            before_5e03
            and after_5e03
            and isinstance(before_5e03.get("count"), int)
            and isinstance(after_5e03.get("count"), int)
            and after_5e03["count"] > before_5e03["count"]
        ),
        "pre_0x4a5e03": before_5e03,
        "post_0x4a5e03": after_5e03,
    }


def summarize(ledger_path: Path) -> dict[str, Any]:
    ledger = read_json(ledger_path)
    events = ledger.get("events", [])
    groups = group_calls(events)
    call_summaries = [summarize_call(index, group) for index, group in enumerate(groups)]
    complete_calls = [call for call in call_summaries if call["complete_success_path"]]
    calls_with_growth = [call for call in call_summaries if call["growth_edges"]]
    calls_with_5e03_growth = [call for call in call_summaries if call["growth_across_0x4a5e03"]]
    non_5e03_growth = [
        edge
        for call in call_summaries
        for edge in call["growth_edges"]
        if not (
            edge["pre_address"] == ADDR_BEFORE_5E03
            and edge["post_address"] == ADDR_AFTER_5E03
        )
    ]
    return {
        "schema": "h3maped_rmg_4a61bc_internal_append_summary_v1",
        "ledger": str(ledger_path),
        "event_count": len(events),
        "address_counts": dict(sorted(Counter(event_address(event) for event in events).items())),
        "child_returncode": ledger.get("child_returncode"),
        "call_count": len(call_summaries),
        "complete_success_call_count": len(complete_calls),
        "calls_with_growth_count": len(calls_with_growth),
        "calls_with_growth_across_0x4a5e03_count": len(calls_with_5e03_growth),
        "non_0x4a5e03_growth_edges": non_5e03_growth,
        "call_summaries": call_summaries,
        "recovered_contract": (
            "In this sampled 0x4a61bc run, the generator object vector at "
            "generator+0xec8/+0xecc stays stable through the candidate scan, "
            "random selection, both 0x4a5a23 projection calls, both local "
            "0x40bb15 appends, the local cleanup, the Border Guard byte gate, "
            "and the fallback gate. Each complete sampled successful call grows "
            "the generator object vector by one only across 0x4a6578 -> "
            "0x4a5e03 -> 0x4a657d. One sampled growth reallocates the vector."
        ),
        "remaining_gap": (
            "Recover 0x4a5e03 callee-side construction/commit and generated-cell "
            "mutation semantics for the object records appended from 0x4a61bc, "
            "then link those records to later 0x4a79a3 payload-loop and "
            "0x4a696b/0x4a7605 consumers."
        ),
        "native_behavior_changed": False,
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
        "RMG_H3MAPED_4A61BC_INTERNAL_APPEND_SUMMARY "
        f"calls={summary['call_count']} "
        f"complete={summary['complete_success_call_count']} "
        f"growth={summary['calls_with_growth_count']} "
        f"growth_across_0x4a5e03={summary['calls_with_growth_across_0x4a5e03_count']} "
        f"non_0x4a5e03_growth_edges={len(summary['non_0x4a5e03_growth_edges'])} "
        f"out={args.out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
