#!/usr/bin/env python3
"""Summarize H3MapEd 0x4aa3e9 inner callback and mutation traces."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


ENTRY = "0x004aa3e9"
SLOT4_CALLBACK = "0x004aa44a"
SOURCE_BIT27_CLEAR = "0x004aa591"
SOURCE_BIT26_SET = "0x004aa5a4"
DEST_BIT26_MIRROR = "0x004aa5ae"
DEST_BIT27_MIRROR = "0x004aa5b8"
SLOT8_CALLBACK = "0x004aa5f6"
PRE_RETURN = "0x004aa5fc"


def normalize_address(value: str) -> str:
    return "0x%08x" % int(value, 0)


def hex32(value: int | None) -> str:
    return "0x%08x" % (value & 0xFFFFFFFF) if isinstance(value, int) else ""


def signed32(value: int | None) -> int | None:
    if value is None:
        return None
    value &= 0xFFFFFFFF
    return value - 0x100000000 if value & 0x80000000 else value


def contiguous_words_at(event: dict[str, Any], address: int | None, max_words: int) -> list[int]:
    if not isinstance(address, int):
        return []
    lines_by_address: dict[int, list[int]] = {}
    for line in event.get("memory_lines", []):
        line_address = int(line.get("address", -1))
        if line_address < 0 or line_address in lines_by_address:
            continue
        lines_by_address[line_address] = [int(word) & 0xFFFFFFFF for word in line.get("words", [])]

    words: list[int] = []
    expected = address
    while expected in lines_by_address and len(words) < max_words:
        line_words = lines_by_address[expected]
        take = min(len(line_words), max_words - len(words))
        words.extend(line_words[:take])
        expected += len(line_words) * 4
    return words


def stack_words(event: dict[str, Any], max_words: int = 16) -> list[int]:
    return contiguous_words_at(event, event.get("registers", {}).get("esp"), max_words)


def word_at(words: list[int], offset: int) -> int | None:
    index = offset // 4
    return words[index] if index < len(words) else None


def cell_state(event: dict[str, Any], pointer: int | None) -> dict[str, Any]:
    words = contiguous_words_at(event, pointer, 12)
    w28 = word_at(words, 0x28)
    return {
        "cell": hex32(pointer),
        "w20": hex32(word_at(words, 0x20)),
        "w24": hex32(word_at(words, 0x24)),
        "w28": hex32(w28),
        "bit22": bool((w28 or 0) & 0x00400000),
        "bit26": bool((w28 or 0) & 0x04000000),
        "bit27": bool((w28 or 0) & 0x08000000),
        "words_prefix": [hex32(word) for word in words],
    }


def wrapper_member_count(event: dict[str, Any], wrapper: int | None) -> int | None:
    words = contiguous_words_at(event, wrapper, 40)
    begin = word_at(words, 0x2C)
    end = word_at(words, 0x30)
    if not isinstance(begin, int) or not isinstance(end, int) or end < begin:
        return None
    return (end - begin) // 4


def entry_record(event: dict[str, Any], event_index: int) -> dict[str, Any]:
    stack = stack_words(event)
    wrapper = stack[1] if len(stack) > 1 else None
    return {
        "entry_event": event_index,
        "wrapper": hex32(wrapper),
        "selected_coordinate_arg": {
            "x": signed32(stack[2] if len(stack) > 2 else None),
            "y": signed32(stack[3] if len(stack) > 3 else None),
            "level": signed32(stack[4] if len(stack) > 4 else None),
        },
        "member_count": wrapper_member_count(event, wrapper),
        "return_address": hex32(stack[0] if stack else None),
    }


def member_state(event: dict[str, Any], pointer: int | None) -> dict[str, Any]:
    words = contiguous_words_at(event, pointer, 12)
    return {
        "member": hex32(pointer),
        "vtable": hex32(word_at(words, 0x00)),
        "descriptor": hex32(word_at(words, 0x04)),
        "relative_coordinate": {
            "x": signed32(word_at(words, 0x08)),
            "y": signed32(word_at(words, 0x0C)),
            "level": signed32(word_at(words, 0x10)),
        },
        "words_prefix": [hex32(word) for word in words],
    }


def callback_record(event: dict[str, Any], event_index: int, slot: str) -> dict[str, Any]:
    registers = event.get("registers", {})
    stack = stack_words(event)
    if slot == "+0x04":
        member = stack[0] if stack else None
        vtable = registers.get("edx")
        absolute_coordinate = {
            "x": signed32(stack[1] if len(stack) > 1 else None),
            "y": signed32(stack[2] if len(stack) > 2 else None),
            "level": signed32(stack[3] if len(stack) > 3 else None),
        }
        slot_target = word_at(contiguous_words_at(event, vtable, 4), 0x04)
    else:
        member = registers.get("ecx")
        vtable = registers.get("eax")
        absolute_coordinate = None
        slot_target = word_at(contiguous_words_at(event, vtable, 4), 0x08)
    return {
        "event": event_index,
        "slot": slot,
        "member": hex32(member),
        "vtable": hex32(vtable),
        "slot_target": hex32(slot_target),
        "absolute_coordinate": absolute_coordinate,
        "member_state": member_state(event, member),
    }


def mutation_record(event: dict[str, Any], event_index: int, kind: str) -> dict[str, Any]:
    registers = event.get("registers", {})
    stack = stack_words(event)
    cell = registers.get("ecx")
    return {
        "event": event_index,
        "kind": kind,
        "argument": signed32(stack[0] if stack else None),
        "cell_state_before_call": cell_state(event, cell),
    }


def summarize_ledger(ledger: dict[str, Any]) -> dict[str, Any]:
    calls: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    orphan_events = 0

    for event_index, event in enumerate(ledger.get("events", []), start=1):
        address = normalize_address(str(event.get("address", "0")))
        if address == ENTRY:
            if current is not None:
                current["outcome"] = "missing_exit"
            current = {**entry_record(event, event_index), "slot4_callbacks": [], "slot8_callbacks": [], "mutations": []}
            calls.append(current)
            continue

        if current is None:
            orphan_events += 1
            continue

        if address == SLOT4_CALLBACK:
            current["slot4_callbacks"].append(callback_record(event, event_index, "+0x04"))
        elif address == SLOT8_CALLBACK:
            current["slot8_callbacks"].append(callback_record(event, event_index, "+0x08"))
        elif address == SOURCE_BIT27_CLEAR:
            current["mutations"].append(mutation_record(event, event_index, "source_bit27_clear"))
        elif address == SOURCE_BIT26_SET:
            current["mutations"].append(mutation_record(event, event_index, "source_bit26_set"))
        elif address == DEST_BIT26_MIRROR:
            current["mutations"].append(mutation_record(event, event_index, "destination_bit26_mirror"))
        elif address == DEST_BIT27_MIRROR:
            current["mutations"].append(mutation_record(event, event_index, "destination_bit27_mirror"))
        elif address == PRE_RETURN:
            current["exit_event"] = event_index
            current["outcome"] = "paired"
            current = None

    event_counts = Counter(normalize_address(str(event.get("address", "0"))) for event in ledger.get("events", []))
    mutation_counts = Counter(
        mutation["kind"]
        for call in calls
        for mutation in call.get("mutations", [])
    )
    slot4_targets = Counter(
        callback["slot_target"]
        for call in calls
        for callback in call.get("slot4_callbacks", [])
        if callback.get("slot_target")
    )
    slot8_targets = Counter(
        callback["slot_target"]
        for call in calls
        for callback in call.get("slot8_callbacks", [])
        if callback.get("slot_target")
    )

    paired_calls = [call for call in calls if call.get("outcome") == "paired"]
    calls_with_member_counts = [call for call in paired_calls if isinstance(call.get("member_count"), int)]
    source_sets = [
        mutation
        for call in paired_calls
        for mutation in call.get("mutations", [])
        if mutation["kind"] == "source_bit26_set"
    ]
    destination_bit26 = [
        mutation
        for call in paired_calls
        for mutation in call.get("mutations", [])
        if mutation["kind"] == "destination_bit26_mirror"
    ]
    destination_bit27 = [
        mutation
        for call in paired_calls
        for mutation in call.get("mutations", [])
        if mutation["kind"] == "destination_bit27_mirror"
    ]

    return {
        "schema_id": "h3maped_4aa3e9_inner_summary_v1",
        "ledger": ledger.get("log_path", ""),
        "event_count": int(ledger.get("event_count", 0)),
        "event_counts": dict(event_counts),
        "call_count": len(calls),
        "paired_call_count": len(paired_calls),
        "orphan_event_count": orphan_events,
        "slot4_callback_count": sum(len(call.get("slot4_callbacks", [])) for call in calls),
        "slot8_callback_count": sum(len(call.get("slot8_callbacks", [])) for call in calls),
        "slot4_targets": dict(slot4_targets),
        "slot8_targets": dict(slot8_targets),
        "mutation_counts": dict(mutation_counts),
        "calls_prefix": calls[:12],
        "invariants": {
            "has_paired_calls": bool(paired_calls),
            "member_count_matches_slot4_callbacks": bool(calls_with_member_counts)
            and all(call["member_count"] == len(call.get("slot4_callbacks", [])) for call in calls_with_member_counts),
            "member_count_matches_slot8_callbacks": bool(calls_with_member_counts)
            and all(call["member_count"] == len(call.get("slot8_callbacks", [])) for call in calls_with_member_counts),
            "has_destination_mirror_pairs": bool(destination_bit26)
            and len(destination_bit26) == len(destination_bit27),
            "source_clear_arguments_are_zero": all(
                mutation["argument"] == 0
                for call in paired_calls
                for mutation in call.get("mutations", [])
                if mutation["kind"] == "source_bit27_clear"
            ),
            "source_set_arguments_are_one": bool(source_sets)
            and all(mutation["argument"] == 1 for mutation in source_sets),
            "source_sets_are_subset_of_cleared_cells": all(
                mutation["cell_state_before_call"]["cell"]
                in {
                    prior["cell_state_before_call"]["cell"]
                    for call in paired_calls
                    for prior in call.get("mutations", [])
                    if prior["kind"] == "source_bit27_clear"
                }
                for mutation in source_sets
            ),
        },
    }


def merge_summaries(summaries: list[dict[str, Any]]) -> dict[str, Any]:
    combined_event_counts = Counter()
    combined_mutation_counts = Counter()
    combined_slot4_targets = Counter()
    combined_slot8_targets = Counter()
    for summary in summaries:
        combined_event_counts.update(summary.get("event_counts", {}))
        combined_mutation_counts.update(summary.get("mutation_counts", {}))
        combined_slot4_targets.update(summary.get("slot4_targets", {}))
        combined_slot8_targets.update(summary.get("slot8_targets", {}))
    return {
        "schema_id": "h3maped_4aa3e9_inner_combined_summary_v1",
        "summary_count": len(summaries),
        "summaries": summaries,
        "combined_event_counts": dict(combined_event_counts),
        "combined_mutation_counts": dict(combined_mutation_counts),
        "combined_slot4_targets": dict(combined_slot4_targets),
        "combined_slot8_targets": dict(combined_slot8_targets),
        "combined_invariants": {
            "has_paired_call_evidence": any(summary["invariants"]["has_paired_calls"] for summary in summaries),
            "callback_summaries_match_member_counts": any(
                summary["invariants"]["member_count_matches_slot4_callbacks"]
                and summary["invariants"]["member_count_matches_slot8_callbacks"]
                and summary["slot4_callback_count"] > 0
                and summary["slot8_callback_count"] > 0
                for summary in summaries
            ),
            "has_destination_mirror_pairs": combined_mutation_counts["destination_bit26_mirror"] > 0
            and combined_mutation_counts["destination_bit26_mirror"] == combined_mutation_counts["destination_bit27_mirror"],
            "has_source_clear_and_set_mutations": any(
                summary["mutation_counts"].get("source_bit27_clear", 0) > 0
                and summary["mutation_counts"].get("source_bit26_set", 0) > 0
                and summary["invariants"]["source_clear_arguments_are_zero"]
                and summary["invariants"]["source_set_arguments_are_one"]
                for summary in summaries
            ),
        },
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, action="append", required=True)
    parser.add_argument("--out", type=Path, required=True)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summaries = [summarize_ledger(json.loads(path.read_text(encoding="utf-8"))) for path in args.ledger]
    output = merge_summaries(summaries) if len(summaries) > 1 else summaries[0]
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(output, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    invariants = output.get("combined_invariants", output.get("invariants", {}))
    status = "pass" if invariants and all(invariants.values()) else "partial"
    print(
        "RMG_H3MAPED_4AA3E9_INNER_SUMMARY "
        f"status={status} ledgers={len(args.ledger)} out={args.out}"
    )
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
