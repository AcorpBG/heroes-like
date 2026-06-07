#!/usr/bin/env python3
"""Summarize H3MapEd 0x49c* projection-object constructor traces."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

from rmg_h3maped_4aa3e9_ordered_summary import hex32, normalize_address, stack_words


CONSTRUCTORS = {
    "0x0049cac2": {
        "name": "projection_constructor_a",
        "expected_initializer_return": "0x0049caf0",
        "final_vtable": "0x00540b14",
    },
    "0x0049cb83": {
        "name": "projection_constructor_b",
        "expected_initializer_return": "0x0049cbb3",
        "final_vtable": "0x00540b14",
    },
    "0x0049cc22": {
        "name": "projection_constructor_c",
        "expected_initializer_return": "0x0049cc50",
        "final_vtable": "0x00540b14",
    },
}

BASE_INITIALIZER = "0x0049c0d3"
BASE_INITIALIZER_VTABLE = "0x00540b28"
WRAPPER_EXECUTION_ADDRESSES = {
    "0x0049c019",
    "0x0049c0a6",
    "0x004adb72",
    "0x004ad947",
    "0x004ad7f7",
    "0x004adef7",
}


def event_record(event: dict[str, Any], event_index: int) -> dict[str, Any]:
    address = normalize_address(event.get("address", "0"))
    registers = event.get("registers", {})
    stack = stack_words(event, 8)
    return {
        "event_index": event_index,
        "address": address,
        "breakpoint_index": event.get("breakpoint_index"),
        "return_address": hex32(stack[0] if stack else None),
        "this_ecx": hex32(registers.get("ecx")),
        "eax": hex32(registers.get("eax")),
        "ebx": hex32(registers.get("ebx")),
        "esi": hex32(registers.get("esi")),
        "edi": hex32(registers.get("edi")),
        "stack_words": [hex32(word) for word in stack],
    }


def pair_constructors(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    pairs: list[dict[str, Any]] = []
    pending: dict[str, Any] | None = None
    for event_index, event in enumerate(events, start=1):
        address = normalize_address(event.get("address", "0"))
        record = event_record(event, event_index)
        if address in CONSTRUCTORS:
            if pending is not None:
                pairs.append({"constructor": pending, "initializer": None, "status": "missing_initializer"})
            pending = record
        elif address == BASE_INITIALIZER:
            if pending is None:
                pairs.append({"constructor": None, "initializer": record, "status": "orphan_initializer"})
            else:
                pairs.append({"constructor": pending, "initializer": record, "status": "paired"})
                pending = None
    if pending is not None:
        pairs.append({"constructor": pending, "initializer": None, "status": "missing_initializer"})
    return pairs


def summarize(constructor_ledger: dict[str, Any], wrapper_ledger: dict[str, Any] | None) -> dict[str, Any]:
    events = constructor_ledger.get("events", [])
    addresses = [normalize_address(event.get("address", "0")) for event in events]
    counts = Counter(addresses)
    pairs = pair_constructors(events)

    constructor_events = [pair for pair in pairs if pair.get("constructor")]
    paired = [pair for pair in pairs if pair.get("status") == "paired"]
    initializer_return_mismatches = []
    for pair in paired:
        constructor = pair["constructor"]
        initializer = pair["initializer"]
        expected = CONSTRUCTORS[constructor["address"]]["expected_initializer_return"]
        if initializer["return_address"] != expected:
            initializer_return_mismatches.append(
                {
                    "constructor_event_index": constructor["event_index"],
                    "constructor_address": constructor["address"],
                    "initializer_event_index": initializer["event_index"],
                    "expected_return": expected,
                    "actual_return": initializer["return_address"],
                }
            )

    wrapper_event_count = 0
    wrapper_log = ""
    wrapper_breakpoints: list[str] = []
    if wrapper_ledger is not None:
        wrapper_event_count = int(wrapper_ledger.get("event_count", 0))
        wrapper_log = str(wrapper_ledger.get("log_path", ""))
        wrapper_breakpoints = list(wrapper_ledger.get("breakpoints", []))

    return {
        "schema_id": "h3maped_49c_projection_constructor_summary_v1",
        "constructor_ledger": constructor_ledger.get("log_path", ""),
        "constructor_event_count": int(constructor_ledger.get("event_count", 0)),
        "constructor_breakpoints": constructor_ledger.get("breakpoints", []),
        "constructor_counts": dict(sorted(counts.items())),
        "constructor_pair_count": len(constructor_events),
        "paired_constructor_initializer_count": len(paired),
        "constructor_initializer_pairs": pairs,
        "wrapper_execution_ledger": wrapper_log,
        "wrapper_execution_breakpoints": wrapper_breakpoints,
        "wrapper_execution_event_count": wrapper_event_count,
        "static_recovery": {
            "base_initializer": BASE_INITIALIZER,
            "base_initializer_vtable": BASE_INITIALIZER_VTABLE,
            "final_constructor_vtable": "0x00540b14",
            "wrapper_execution_addresses": sorted(WRAPPER_EXECUTION_ADDRESSES),
            "projection_driver_vtable_entries": {
                "0x00540b08": "0x0049c019",
                "0x00540b1c": "0x0049c0a6",
            },
            "projection_driver_targets": {
                "0x0049c019": ["0x004adb72", "0x004adef7"],
                "0x0049c0a6": ["0x004ad947"],
            },
        },
        "mismatch_counts": {
            "unpaired_constructor_or_initializer": len([pair for pair in pairs if pair.get("status") != "paired"]),
            "initializer_return": len(initializer_return_mismatches),
            "wrapper_execution_events_in_nohit_trace": wrapper_event_count,
        },
        "invariants": {
            "has_constructor_events": bool(constructor_events),
            "constructors_pair_with_base_initializer": len(paired) == len(constructor_events),
            "initializer_returns_match_constructor_sites": not initializer_return_mismatches,
            "wrapper_execution_nohit_trace_has_no_events": wrapper_ledger is None or wrapper_event_count == 0,
        },
        "notes": [
            "Constructor hits show the 0x49c* projection object class is instantiated in the sampled UI/generation setup path.",
            "The base initializer 0x49c0d3 writes vtable 0x540b28; caller constructors later install final vtable 0x540b14.",
            "The separate wrapper-execution no-hit trace generated a 36x36 map without hitting 0x49c019/0x49c0a6 or their 0x4adb72/0x4ad947/0x4ad7f7 callees.",
            "This is a recovery checkpoint only. It does not prove runtime ordered replay for 0x4adb72/0x4ad947; that remains pending until a path that executes the vtable methods is captured.",
        ],
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--constructor-ledger", type=Path, required=True)
    parser.add_argument("--wrapper-ledger", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    constructor_ledger = json.loads(args.constructor_ledger.read_text(encoding="utf-8"))
    wrapper_ledger = json.loads(args.wrapper_ledger.read_text(encoding="utf-8")) if args.wrapper_ledger else None
    summary = summarize(constructor_ledger, wrapper_ledger)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    status = "pass" if all(summary["invariants"].values()) else "partial"
    print(
        "RMG_H3MAPED_49C_PROJECTION_CONSTRUCTOR_SUMMARY "
        f"status={status} events={summary['constructor_event_count']} "
        f"constructors={summary['constructor_pair_count']} "
        f"paired={summary['paired_constructor_initializer_count']} "
        f"wrapper_events={summary['wrapper_execution_event_count']} out={args.out}"
    )
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
