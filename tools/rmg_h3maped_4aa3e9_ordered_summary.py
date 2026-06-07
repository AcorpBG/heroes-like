#!/usr/bin/env python3
"""Summarize one ordered live H3MapEd 0x4aa3e9 entry-to-return trace."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ENTRY = "0x004aa3e9"
SLOT4_CALLBACK = "0x004aa44a"
SOURCE_BIT27_CLEAR_BEFORE = "0x004aa591"
SOURCE_BIT27_CLEAR_AFTER = "0x004aa596"
SOURCE_BIT26_SET_BEFORE = "0x004aa5a0"
SOURCE_BRANCH_AFTER = "0x004aa5a9"
DEST_BIT26_MIRROR_BEFORE = "0x004aa5ae"
DEST_BIT26_MIRROR_AFTER = "0x004aa5b3"
DEST_BIT27_MIRROR_BEFORE = "0x004aa5b8"
DEST_BIT27_MIRROR_AFTER = "0x004aa5bd"
SLOT8_CALLBACK = "0x004aa5f6"
PRE_RETURN = "0x004aa5fc"


def normalize_address(value: Any) -> str:
    return "0x%08x" % int(str(value), 0)


def event_memory(event: dict[str, Any]) -> dict[int, int]:
    memory: dict[int, int] = {}
    for line in event.get("memory_lines", []):
        base = int(line.get("address", 0))
        for offset, value in enumerate(line.get("words", [])):
            memory[base + offset * 4] = int(value) & 0xFFFFFFFF
    return memory


def word(memory: dict[int, int], address: int | None) -> int | None:
    if not isinstance(address, int):
        return None
    value = memory.get(address)
    return int(value) if value is not None else None


def hex32(value: int | None) -> str:
    return "0x%08x" % (value & 0xFFFFFFFF) if isinstance(value, int) else ""


def signed32(value: int | None) -> int | None:
    if value is None:
        return None
    value &= 0xFFFFFFFF
    return value - 0x100000000 if value & 0x80000000 else value


def stack_words(event: dict[str, Any], count: int = 8) -> list[int]:
    registers = event.get("registers", {})
    esp = registers.get("esp")
    memory = event_memory(event)
    if not isinstance(esp, int):
        return []
    return [word(memory, esp + index * 4) or 0 for index in range(count)]


def cell_state(event: dict[str, Any], register: str) -> dict[str, Any]:
    registers = event.get("registers", {})
    pointer = registers.get(register)
    memory = event_memory(event)
    w24 = word(memory, pointer + 0x24) if isinstance(pointer, int) else None
    w28 = word(memory, pointer + 0x28) if isinstance(pointer, int) else None
    return {
        "cell": hex32(pointer),
        "w20": hex32(word(memory, pointer + 0x20) if isinstance(pointer, int) else None),
        "w24": hex32(w24),
        "w28": hex32(w28),
        "terrain_low6": (w24 & 0x3F) if isinstance(w24, int) else None,
        "bit22": bool((w28 or 0) & 0x00400000),
        "bit25": bool((w28 or 0) & 0x02000000),
        "bit26": bool((w28 or 0) & 0x04000000),
        "bit27": bool((w28 or 0) & 0x08000000),
    }


def wrapper_state(event: dict[str, Any], wrapper: int | None) -> dict[str, Any]:
    memory = event_memory(event)
    begin = word(memory, wrapper + 0x2C) if isinstance(wrapper, int) else None
    end = word(memory, wrapper + 0x30) if isinstance(wrapper, int) else None
    member_count = None
    if isinstance(begin, int) and isinstance(end, int) and end >= begin:
        member_count = (end - begin) // 4
    return {
        "wrapper": hex32(wrapper),
        "member_begin": hex32(begin),
        "member_end": hex32(end),
        "member_count": member_count,
        "selected_coordinate": {
            "x": signed32(word(memory, wrapper + 0x54) if isinstance(wrapper, int) else None),
            "y": signed32(word(memory, wrapper + 0x58) if isinstance(wrapper, int) else None),
            "level": signed32(word(memory, wrapper + 0x5C) if isinstance(wrapper, int) else None),
        },
    }


def local_state(event: dict[str, Any]) -> dict[str, Any]:
    registers = event.get("registers", {})
    ebp = registers.get("ebp")
    memory = event_memory(event)
    if not isinstance(ebp, int):
        return {}
    return {
        "loop_x": signed32(word(memory, ebp - 0x14)),
        "loop_y": signed32(word(memory, ebp - 0x10)),
        "loop_x_end": signed32(word(memory, ebp - 0x34)),
        "loop_y_end": signed32(word(memory, ebp - 0x30)),
        "selected_x": signed32(word(memory, ebp + 0x0C)),
        "selected_y": signed32(word(memory, ebp + 0x10)),
        "selected_level": signed32(word(memory, ebp + 0x14)),
    }


def snapshot(event: dict[str, Any], event_index: int, kind: str) -> dict[str, Any]:
    return {
        "event_index": event_index,
        "kind": kind,
        "source": cell_state(event, "esi"),
        "destination": cell_state(event, "edi"),
        "argument": signed32(stack_words(event, 1)[0] if stack_words(event, 1) else None),
        "locals": local_state(event),
    }


def entry_record(event: dict[str, Any], event_index: int) -> dict[str, Any]:
    stack = stack_words(event, 5)
    wrapper = stack[1] if len(stack) > 1 else None
    return {
        "event_index": event_index,
        "return_address": hex32(stack[0] if stack else None),
        "wrapper": hex32(wrapper),
        "selected_coordinate_arg": {
            "x": signed32(stack[2] if len(stack) > 2 else None),
            "y": signed32(stack[3] if len(stack) > 3 else None),
            "level": signed32(stack[4] if len(stack) > 4 else None),
        },
        "wrapper_state": wrapper_state(event, wrapper),
    }


def slot_callback_record(event: dict[str, Any], event_index: int, kind: str) -> dict[str, Any]:
    registers = event.get("registers", {})
    stack = stack_words(event, 4)
    member = stack[0] if kind == "slot4" and stack else registers.get("ecx")
    return {
        "event_index": event_index,
        "kind": kind,
        "member": hex32(member),
        "slot_target": hex32(
            word(event_memory(event), registers.get("edx" if kind == "slot4" else "eax") + (0x04 if kind == "slot4" else 0x08))
            if isinstance(registers.get("edx" if kind == "slot4" else "eax"), int)
            else None
        ),
    }


def pair_append(pairs: list[dict[str, Any]], before: dict[str, Any] | None, after: dict[str, Any]) -> dict[str, Any] | None:
    if before is None:
        return None
    pairs.append({"before": before, "after": after})
    return None


def summarize(ledger: dict[str, Any]) -> dict[str, Any]:
    entries: list[dict[str, Any]] = []
    slot4_callbacks: list[dict[str, Any]] = []
    slot8_callbacks: list[dict[str, Any]] = []
    source_clear_pairs: list[dict[str, Any]] = []
    source_set_pairs: list[dict[str, Any]] = []
    dest_bit26_pairs: list[dict[str, Any]] = []
    dest_bit27_pairs: list[dict[str, Any]] = []
    branch_after_count = 0
    pre_return: dict[str, Any] | None = None
    orphan_events: list[dict[str, Any]] = []
    pending_source_clear: dict[str, Any] | None = None
    pending_source_set: dict[str, Any] | None = None
    pending_dest_bit26: dict[str, Any] | None = None
    pending_dest_bit27: dict[str, Any] | None = None

    for event_index, event in enumerate(ledger.get("events", []), start=1):
        address = normalize_address(event.get("address", "0"))
        if address == ENTRY:
            entries.append(entry_record(event, event_index))
        elif address == SLOT4_CALLBACK:
            slot4_callbacks.append(slot_callback_record(event, event_index, "slot4"))
        elif address == SOURCE_BIT27_CLEAR_BEFORE:
            pending_source_clear = snapshot(event, event_index, "source_bit27_clear_before")
        elif address == SOURCE_BIT27_CLEAR_AFTER:
            pending_source_clear = pair_append(
                source_clear_pairs,
                pending_source_clear,
                snapshot(event, event_index, "source_bit27_clear_after"),
            )
        elif address == SOURCE_BIT26_SET_BEFORE:
            pending_source_set = snapshot(event, event_index, "source_bit26_set_before")
        elif address == SOURCE_BRANCH_AFTER:
            branch_after_count += 1
            if pending_source_set is not None:
                pending_source_set = pair_append(
                    source_set_pairs,
                    pending_source_set,
                    snapshot(event, event_index, "source_bit26_set_after"),
                )
        elif address == DEST_BIT26_MIRROR_BEFORE:
            pending_dest_bit26 = snapshot(event, event_index, "dest_bit26_before")
        elif address == DEST_BIT26_MIRROR_AFTER:
            pending_dest_bit26 = pair_append(
                dest_bit26_pairs,
                pending_dest_bit26,
                snapshot(event, event_index, "dest_bit26_after"),
            )
        elif address == DEST_BIT27_MIRROR_BEFORE:
            pending_dest_bit27 = snapshot(event, event_index, "dest_bit27_before")
        elif address == DEST_BIT27_MIRROR_AFTER:
            pending_dest_bit27 = pair_append(
                dest_bit27_pairs,
                pending_dest_bit27,
                snapshot(event, event_index, "dest_bit27_after"),
            )
        elif address == SLOT8_CALLBACK:
            slot8_callbacks.append(slot_callback_record(event, event_index, "slot8"))
        elif address == PRE_RETURN:
            wrapper = event.get("registers", {}).get("ebx")
            pre_return = {
                "event_index": event_index,
                "wrapper": hex32(wrapper),
                "wrapper_state": wrapper_state(event, wrapper),
            }
        else:
            orphan_events.append({"event_index": event_index, "address": address})

    def same_cell(pair: dict[str, Any], cell_key: str) -> bool:
        return pair["before"][cell_key]["cell"] == pair["after"][cell_key]["cell"]

    dest_bit26_mismatches = [
        pair for pair in dest_bit26_pairs
        if not same_cell(pair, "destination") or pair["after"]["destination"]["bit26"] != bool(pair["before"]["argument"])
    ]
    dest_bit27_mismatches = [
        pair for pair in dest_bit27_pairs
        if not same_cell(pair, "destination") or pair["after"]["destination"]["bit27"] != bool(pair["before"]["argument"])
    ]
    source_clear_mismatches = [
        pair for pair in source_clear_pairs
        if not same_cell(pair, "source") or pair["after"]["source"]["bit27"]
    ]
    source_set_mismatches = [
        pair for pair in source_set_pairs
        if not same_cell(pair, "source") or not pair["after"]["source"]["bit26"]
    ]

    entry = entries[0] if entries else None
    entry_member_count = entry["wrapper_state"]["member_count"] if entry else None
    pre_return_member_count = pre_return["wrapper_state"]["member_count"] if pre_return else None
    selected_arg = entry["selected_coordinate_arg"] if entry else None
    pre_return_coord = pre_return["wrapper_state"]["selected_coordinate"] if pre_return else None

    return {
        "schema_id": "h3maped_4aa3e9_ordered_summary_v1",
        "ledger": ledger.get("log_path", ""),
        "event_count": int(ledger.get("event_count", 0)),
        "breakpoints": ledger.get("breakpoints", []),
        "entry_count": len(entries),
        "slot4_callback_count": len(slot4_callbacks),
        "slot8_callback_count": len(slot8_callbacks),
        "branch_after_count": branch_after_count,
        "source_clear_pair_count": len(source_clear_pairs),
        "source_set_pair_count": len(source_set_pairs),
        "destination_bit26_pair_count": len(dest_bit26_pairs),
        "destination_bit27_pair_count": len(dest_bit27_pairs),
        "orphan_event_count": len(orphan_events),
        "entry": entry,
        "pre_return": pre_return,
        "first_destination_bit26_pair": dest_bit26_pairs[0] if dest_bit26_pairs else None,
        "first_destination_bit27_pair": dest_bit27_pairs[0] if dest_bit27_pairs else None,
        "first_source_clear_pair": source_clear_pairs[0] if source_clear_pairs else None,
        "first_source_set_pair": source_set_pairs[0] if source_set_pairs else None,
        "mismatch_counts": {
            "destination_bit26": len(dest_bit26_mismatches),
            "destination_bit27": len(dest_bit27_mismatches),
            "source_clear": len(source_clear_mismatches),
            "source_set": len(source_set_mismatches),
        },
        "invariants": {
            "single_entry": len(entries) == 1,
            "has_pre_return": pre_return is not None,
            "wrapper_matches": bool(entry and pre_return and entry["wrapper"] == pre_return["wrapper"]),
            "selected_coordinate_matches_at_return": bool(selected_arg and selected_arg == pre_return_coord),
            "member_count_matches_slot4_callbacks": isinstance(entry_member_count, int)
            and entry_member_count == len(slot4_callbacks),
            "member_count_matches_slot8_callbacks": isinstance(pre_return_member_count, int)
            and pre_return_member_count == len(slot8_callbacks),
            "has_destination_pairs": bool(dest_bit26_pairs) and len(dest_bit26_pairs) == len(dest_bit27_pairs),
            "destination_bit26_matches_argument": not dest_bit26_mismatches,
            "destination_bit27_matches_argument": not dest_bit27_mismatches,
            "source_clear_after_bit27_false": not source_clear_mismatches,
            "source_set_after_bit26_true": not source_set_mismatches,
            "branch_after_matches_destination_pairs": branch_after_count == len(dest_bit26_pairs),
            "no_unpaired_mutations": not any(
                pending is not None
                for pending in (pending_source_clear, pending_source_set, pending_dest_bit26, pending_dest_bit27)
            ),
        },
        "notes": [
            "This summary is intentionally limited to one ordered 0x4aa3e9 invocation.",
            "It proves the sampled entry-to-return mutation ordering for the chosen wrapper projection call.",
            "Caller-side reward/object-vector commit ordering before and after 0x4aa3e9 remains separate recovery work.",
        ],
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, required=True)
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
        "RMG_H3MAPED_4AA3E9_ORDERED_SUMMARY "
        f"status={status} events={summary['event_count']} "
        f"dest_pairs={summary['destination_bit26_pair_count']} out={args.out}"
    )
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
