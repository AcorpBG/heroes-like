#!/usr/bin/env python3
"""Summarize H3MapEd 0x4a9f1c selected-create dispatch into 49c constructors."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

from rmg_h3maped_4aa3e9_ordered_summary import hex32, normalize_address


DEFAULT_LEDGER = Path(
    ".artifacts/rmg_recovery/direct_generation_49c_selected_create_dispatch_trace/winedbg_recovery_trace_ledger.json"
)

SELECTED_VALUE_SITE = "0x004aa151"
SELECTED_CREATE_SITE = "0x004aa166"

CANDIDATE_CREATE_TO_CONSTRUCTOR = {
    "0x00540c60": "0x0049cac2",
    "0x00540c70": "0x0049cb83",
    "0x00540c80": "0x0049cc22",
    "0x00540ca0": "0x0049cdb1",
}

PROJECTION_CONSTRUCTORS = set(CANDIDATE_CREATE_TO_CONSTRUCTOR.values())
PROJECTION_METHOD_AND_DRIVER_TARGETS = {
    "0x0049c019",
    "0x0049c0a6",
    "0x004adb72",
    "0x004ad947",
    "0x004ad7f7",
    "0x004adb07",
}


def vtable_from_event(event: dict[str, Any]) -> str:
    registers = event.get("registers", {})
    value = registers.get("eax")
    if value is None:
        return "unknown"
    return hex32(value)


def summarize(ledger: dict[str, Any]) -> dict[str, Any]:
    events = ledger.get("events", [])
    addresses = [normalize_address(event.get("address", "0")) for event in events]
    address_counts = Counter(addresses)

    selected_vtables: dict[str, dict[str, int]] = {}
    for site in [SELECTED_VALUE_SITE, SELECTED_CREATE_SITE]:
        counts = Counter(vtable_from_event(event) for event in events if normalize_address(event.get("address", "0")) == site)
        selected_vtables[site] = dict(sorted(counts.items()))

    constructor_followthrough: list[dict[str, Any]] = []
    mismatches: list[dict[str, Any]] = []
    for index, event in enumerate(events):
        address = normalize_address(event.get("address", "0"))
        if address not in PROJECTION_CONSTRUCTORS:
            continue
        previous = events[index - 1] if index else {}
        previous_address = normalize_address(previous.get("address", "0")) if previous else ""
        previous_vtable = vtable_from_event(previous) if previous else "0x00000000"
        expected_constructor = CANDIDATE_CREATE_TO_CONSTRUCTOR.get(previous_vtable, "")
        record = {
            "event_index": index + 1,
            "constructor": address,
            "previous_event_address": previous_address,
            "previous_selected_create_vtable": previous_vtable,
            "expected_constructor_for_vtable": expected_constructor,
            "matches_selected_create": previous_address == SELECTED_CREATE_SITE and expected_constructor == address,
        }
        constructor_followthrough.append(record)
        if not record["matches_selected_create"]:
            mismatches.append(record)

    constructor_counts = {
        address: address_counts.get(address, 0)
        for address in sorted(PROJECTION_CONSTRUCTORS)
        if address_counts.get(address, 0)
    }
    method_counts = {
        address: address_counts.get(address, 0)
        for address in sorted(PROJECTION_METHOD_AND_DRIVER_TARGETS)
        if address_counts.get(address, 0)
    }

    return {
        "schema_id": "h3maped_49c_selected_dispatch_summary_v1",
        "ledger": ledger.get("log_path", ""),
        "event_count": int(ledger.get("event_count", 0)),
        "breakpoints": ledger.get("breakpoints", []),
        "address_counts": dict(sorted(address_counts.items())),
        "selected_candidate_vtable_counts": selected_vtables,
        "projection_constructor_counts": constructor_counts,
        "projection_method_or_driver_counts": method_counts,
        "constructor_followthrough": constructor_followthrough,
        "invariants": {
            "selected_value_site_hit": address_counts.get(SELECTED_VALUE_SITE, 0) > 0,
            "selected_create_site_hit": address_counts.get(SELECTED_CREATE_SITE, 0) > 0,
            "selected_value_and_create_counts_track": address_counts.get(SELECTED_VALUE_SITE, 0)
            == address_counts.get(SELECTED_CREATE_SITE, 0),
            "projection_constructor_hit": bool(constructor_counts),
            "constructor_hits_follow_matching_selected_create_vtable": bool(constructor_followthrough) and not mismatches,
            "projection_methods_and_downstream_drivers_not_hit_in_this_bounded_trace": not method_counts,
        },
        "notes": [
            "This is selected candidate-create dispatch evidence, not projection-method execution replay.",
            "Captured 0x4aa151/0x4aa166 selected descriptor dispatch and direct follow-through into sampled 49c projection constructors.",
            "No 0x540b00+0x08 or 0x540b14+0x08 projection-method dispatch was captured in this bounded trace.",
        ],
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
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
        "RMG_H3MAPED_49C_SELECTED_DISPATCH_SUMMARY "
        f"status={status} events={summary['event_count']} "
        f"constructors={sum(summary['projection_constructor_counts'].values())} "
        f"method_or_driver_hits={sum(summary['projection_method_or_driver_counts'].values())} out={args.out}"
    )
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
