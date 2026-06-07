#!/usr/bin/env python3
"""Summarize live H3MapEd 0x4aa3e9 source bit26 after-set traces."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ENTRY = "0x004aa3e9"
SOURCE_BIT26_SET_CALL = "0x004aa5a0"
AFTER_SOURCE_BIT26_SET = "0x004aa5a9"


def normalize_address(value: Any) -> str:
    return "0x%08x" % int(str(value), 0)


def event_memory(event: dict[str, Any]) -> dict[int, int]:
    memory: dict[int, int] = {}
    for line in event.get("memory_lines", []):
        base = int(line.get("address", 0))
        for offset, word in enumerate(line.get("words", [])):
            memory[base + offset * 4] = int(word) & 0xFFFFFFFF
    return memory


def word(memory: dict[int, int], address: int) -> int | None:
    value = memory.get(address)
    return int(value) if value is not None else None


def hex32(value: int | None) -> str:
    return "0x%08x" % value if value is not None else ""


def signed32(value: int | None) -> int | None:
    if value is None:
        return None
    value &= 0xFFFFFFFF
    return value - 0x100000000 if value & 0x80000000 else value


def stack_words(event: dict[str, Any]) -> list[int]:
    registers = event.get("registers", {})
    esp = registers.get("esp")
    if not isinstance(esp, int):
        return []
    memory = event_memory(event)
    return [word(memory, esp + offset * 4) or 0 for offset in range(8)]


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


def local_state(event: dict[str, Any]) -> dict[str, Any]:
    registers = event.get("registers", {})
    ebp = registers.get("ebp")
    memory = event_memory(event)
    if not isinstance(ebp, int):
        return {}
    return {
        "selected_x": signed32(word(memory, ebp + 0x0C)),
        "selected_y": signed32(word(memory, ebp + 0x10)),
        "selected_level": signed32(word(memory, ebp + 0x14)),
        "local_x": signed32(word(memory, ebp - 0x14)),
        "local_y": signed32(word(memory, ebp - 0x10)),
    }


def entry_state(event: dict[str, Any], event_index: int) -> dict[str, Any]:
    stack = stack_words(event)
    return {
        "event_index": event_index,
        "wrapper": hex32(stack[1] if len(stack) > 1 else None),
        "selected_coordinate_arg": {
            "x": signed32(stack[2] if len(stack) > 2 else None),
            "y": signed32(stack[3] if len(stack) > 3 else None),
            "level": signed32(stack[4] if len(stack) > 4 else None),
        },
    }


def snapshot(event: dict[str, Any], event_index: int) -> dict[str, Any]:
    return {
        "event_index": event_index,
        "source": cell_state(event, "esi"),
        "destination": cell_state(event, "edi"),
        "locals": local_state(event),
    }


def summarize(ledger: dict[str, Any]) -> dict[str, Any]:
    entries: list[dict[str, Any]] = []
    set_pairs: list[dict[str, Any]] = []
    orphan_events: list[dict[str, Any]] = []
    pending_set: dict[str, Any] | None = None
    incomplete_set_count = 0

    for event_index, event in enumerate(ledger.get("events", []), start=1):
        address = normalize_address(event.get("address", "0"))
        if address == ENTRY:
            entries.append(entry_state(event, event_index))
            continue
        if address == SOURCE_BIT26_SET_CALL:
            if pending_set is not None:
                incomplete_set_count += 1
            pending_set = snapshot(event, event_index)
            continue
        if address == AFTER_SOURCE_BIT26_SET:
            after = snapshot(event, event_index)
            if pending_set is not None:
                set_pairs.append({"before_set": pending_set, "after_set": after})
                pending_set = None
            continue
        orphan_events.append({"event_index": event_index, "address": address})

    if pending_set is not None:
        incomplete_set_count += 1

    set_mismatches: list[dict[str, Any]] = []
    for index, pair in enumerate(set_pairs, start=1):
        before = pair["before_set"]
        after = pair["after_set"]
        if (
            before["source"]["cell"] != after["source"]["cell"]
            or before["destination"]["cell"] != after["destination"]["cell"]
            or not after["source"]["bit26"]
            or before["source"]["bit27"] != after["source"]["bit27"]
        ):
            set_mismatches.append({"pair_index": index, "before": before, "after": after})

    return {
        "schema_id": "h3maped_4aa3e9_source_set_after_summary_v1",
        "ledger": ledger.get("log_path", ""),
        "event_count": int(ledger.get("event_count", 0)),
        "breakpoints": ledger.get("breakpoints", []),
        "addresses": {
            "entry": ENTRY,
            "source_bit26_set_call": SOURCE_BIT26_SET_CALL,
            "after_source_bit26_set": AFTER_SOURCE_BIT26_SET,
        },
        "entry_count": len(entries),
        "source_set_pair_count": len(set_pairs),
        "incomplete_set_count": incomplete_set_count,
        "orphan_event_count": len(orphan_events),
        "set_mismatches": set_mismatches,
        "first_source_set_pair": set_pairs[0] if set_pairs else None,
        "entries_prefix": entries[:4],
        "invariants": {
            "has_source_set_pairs": bool(set_pairs),
            "source_bit26_true_after_set": not set_mismatches,
            "no_incomplete_sets": incomplete_set_count == 0,
            "no_orphan_events": not orphan_events,
        },
        "notes": [
            "0x4aa5a0 captures source ESI and destination EDI immediately before 0x49aa63(source, true).",
            "0x4aa5a9 captures the same pair immediately after the optional source bit26-set call and before destination mirror calls.",
            "This trace proves sampled source bit26 after-set state; complete 0x4aa3e9 entry-to-return ordered replay remains pending.",
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
        "RMG_H3MAPED_4AA3E9_SOURCE_SET_AFTER_SUMMARY "
        f"status={status} set_pairs={summary['source_set_pair_count']} out={args.out}"
    )
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
