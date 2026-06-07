#!/usr/bin/env python3
"""Summarize H3MapEd 0x4a9f1c selected-object lifetime evidence."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

from rmg_h3maped_4aa3e9_ordered_summary import hex32, normalize_address


DEFAULT_LEDGER = Path(
    ".artifacts/rmg_recovery/direct_generation_49c_selected_lifetime_trace/winedbg_interactive_trace_ledger.json"
)

SELECTED_CREATE_SITE = "0x004aa166"
SELECTED_RETURN_SITE = "0x004aa168"
INITIAL_CONSUME_SITE = "0x004aa22b"
SECONDARY_CONSUME_SITE = "0x004aa2fd"
SECONDARY_VALIDATE_SITE = "0x004aa30e"
FAILED_VALIDATE_SLOT4_SITE = "0x004aa31e"
FAILED_VALIDATE_DESTROY_SITE = "0x004aa327"
STAMP_HELPER_SITE = "0x0049abd6"
SECONDARY_VALIDATOR_SITE = "0x0049d471"
SECONDARY_VALIDATOR_STAMP_CALL_SITE = "0x0049d636"

PROJECTION_METHODS = {"0x0049c019", "0x0049c0a6"}
PROJECTION_OBJECT_VTABLES = {"0x00540b00", "0x00540b14"}

RETURN_OBJECT_SITES = {
    SELECTED_RETURN_SITE: "selector_return_eax",
    INITIAL_CONSUME_SITE: "initial_consumer_eax",
    SECONDARY_CONSUME_SITE: "secondary_consumer_eax",
    SECONDARY_VALIDATE_SITE: "secondary_validate_esi",
    SECONDARY_VALIDATOR_SITE: "validator_arg_eax",
}


def vtable_at_register(event: dict[str, Any], register: str) -> str:
    registers = event.get("registers", {})
    pointer = registers.get(register)
    if pointer is None:
        return "missing-register"
    for line in event.get("memory_lines", []):
        if line.get("address") == pointer and line.get("words"):
            return hex32(int(line["words"][0]))
    return "missing-memory"


def create_callback_at_site(event: dict[str, Any]) -> str:
    registers = event.get("registers", {})
    vtable = registers.get("eax")
    if vtable is None:
        return "missing-register"
    for line in event.get("memory_lines", []):
        if line.get("address") == vtable and line.get("words"):
            return hex32(int(line["words"][0]))
    return "missing-memory"


def next_address_pairs(events: list[dict[str, Any]], start: str, following: str) -> int:
    count = 0
    for index, event in enumerate(events[:-1]):
        if normalize_address(event.get("address", "0")) != start:
            continue
        if normalize_address(events[index + 1].get("address", "0")) == following:
            count += 1
    return count


def summarize(ledger: dict[str, Any]) -> dict[str, Any]:
    events = ledger.get("events", [])
    addresses = [normalize_address(event.get("address", "0")) for event in events if event.get("address")]
    address_counts = Counter(addresses)

    selected_create_callbacks = Counter(
        create_callback_at_site(event)
        for event in events
        if normalize_address(event.get("address", "0")) == SELECTED_CREATE_SITE
    )

    returned_vtables: dict[str, dict[str, int]] = {}
    for site, label in RETURN_OBJECT_SITES.items():
        register = "esi" if site == SECONDARY_VALIDATE_SITE else "eax"
        counts = Counter(
            vtable_at_register(event, register)
            for event in events
            if normalize_address(event.get("address", "0")) == site
        )
        returned_vtables[label] = dict(sorted(counts.items()))

    returned_projection_vtable_records: list[dict[str, Any]] = []
    for site, label in RETURN_OBJECT_SITES.items():
        site_counts = returned_vtables[label]
        for vtable, count in site_counts.items():
            if vtable in PROJECTION_OBJECT_VTABLES:
                returned_projection_vtable_records.append({"site": site, "label": label, "vtable": vtable, "count": count})

    method_counts = {
        address: address_counts.get(address, 0)
        for address in sorted(PROJECTION_METHODS)
        if address_counts.get(address, 0)
    }

    pairs = {
        "return_to_initial_consumer": next_address_pairs(events, SELECTED_RETURN_SITE, INITIAL_CONSUME_SITE),
        "return_to_secondary_consumer": next_address_pairs(events, SELECTED_RETURN_SITE, SECONDARY_CONSUME_SITE),
        "secondary_consumer_to_validate": next_address_pairs(events, SECONDARY_CONSUME_SITE, SECONDARY_VALIDATE_SITE),
        "validate_to_validator_entry": next_address_pairs(events, SECONDARY_VALIDATE_SITE, SECONDARY_VALIDATOR_SITE),
        "validator_stamp_call_to_stamp_helper": next_address_pairs(
            events, SECONDARY_VALIDATOR_STAMP_CALL_SITE, STAMP_HELPER_SITE
        ),
        "failed_validate_slot4_to_destroy": next_address_pairs(
            events, FAILED_VALIDATE_SLOT4_SITE, FAILED_VALIDATE_DESTROY_SITE
        ),
    }

    return {
        "schema_id": "h3maped_49c_selected_lifetime_summary_v1",
        "ledger": ledger.get("log_path", ""),
        "event_count": int(ledger.get("event_count", len(events))),
        "breakpoints": ledger.get("breakpoints", []),
        "address_counts": dict(sorted(address_counts.items())),
        "selected_create_callback_counts": dict(sorted(selected_create_callbacks.items())),
        "returned_object_vtable_counts": returned_vtables,
        "returned_projection_vtable_records": returned_projection_vtable_records,
        "projection_method_counts": method_counts,
        "adjacent_event_pairs": pairs,
        "static_lifetime_contract": {
            "0x4a9f1c": "selected object/member selector; 0x4aa166 dispatches selected descriptor slot +0x00 and 0x4aa168 returns the created object record in EAX",
            "0x4aa1db_initial": "0x4aa226 calls 0x4a9f1c; a non-null 0x4aa22b return is accepted and stamped through 0x49abd6 at 0x4aa27e",
            "0x4aa1db_secondary": "0x4aa2f8 calls 0x4a9f1c; non-null 0x4aa2fd return is validated by 0x49d471 at 0x4aa311",
            "0x49d471": "secondary validator scans offsets and calls 0x49abd6 at 0x49d636 when it chooses a viable stamp coordinate",
            "0x4adef7": "non-wrapper replacement caller invokes 0x4a9f1c and passes a replacement object to generator/context vtable slot +0x04",
        },
        "invariants": {
            "selected_create_and_return_sites_hit": address_counts.get(SELECTED_CREATE_SITE, 0) > 0
            and address_counts.get(SELECTED_RETURN_SITE, 0) > 0,
            "returned_objects_reach_initial_or_secondary_consumer": pairs["return_to_initial_consumer"] > 0
            and pairs["return_to_secondary_consumer"] > 0,
            "secondary_consumer_reaches_validator": pairs["secondary_consumer_to_validate"] > 0
            and pairs["validate_to_validator_entry"] > 0,
            "secondary_validator_stamps_through_49abd6": pairs["validator_stamp_call_to_stamp_helper"] > 0,
            "failed_secondary_validate_cleanup_calls_slot4_then_destroy": pairs["failed_validate_slot4_to_destroy"] > 0,
            "49abd6_stamp_helper_hit": address_counts.get(STAMP_HELPER_SITE, 0) > 0,
            "projection_methods_not_hit_in_sampled_lifetime_trace": not method_counts,
            "sampled_returned_objects_do_not_use_projection_vtables_0x540b00_or_0x540b14": not returned_projection_vtable_records,
        },
        "notes": [
            "This recovers the sampled selected-create object lifetime into 0x4aa1db/0x49d471/0x49abd6, not the missing 0x540b00/0x540b14 projection-object method dispatch.",
            "The sampled returned objects used non-49c vtables such as 0x540a74, 0x540ad8, 0x540b64, and 0x540b78.",
            "The remaining recovery target is still the storage/consumer path for projection objects with vtables 0x540b00/0x540b14 after constructors 0x49cac2/0x49cb83/0x49cc22/0x49cdb1.",
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
        "RMG_H3MAPED_49C_SELECTED_LIFETIME_SUMMARY "
        f"status={status} events={summary['event_count']} "
        f"returns={summary['address_counts'].get(SELECTED_RETURN_SITE, 0)} "
        f"stamp_hits={summary['address_counts'].get(STAMP_HELPER_SITE, 0)} "
        f"projection_method_hits={sum(summary['projection_method_counts'].values())} out={args.out}"
    )
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
