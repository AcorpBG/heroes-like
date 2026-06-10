#!/usr/bin/env python3
"""Summarize H3MapEd selected-object constructor reuse evidence."""

from __future__ import annotations

import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

from rmg_h3maped_4aa3e9_ordered_summary import hex32, normalize_address


DEFAULT_LEDGER = Path(
    ".artifacts/rmg_recovery/small2p_selected_constructor_reuse_trace_20260610/"
    "winedbg_interactive_trace_ledger.partial.json"
)

SELECTED_RETURN_SITE = "0x004aa168"
WRAPPER_RETURN_SITE = "0x004aa343"
FINAL_COMMIT_SITE = "0x004aa3e9"
FINAL_SLOT8_SITE = "0x004aa5f6"

PROJECTION_VTABLES = {"0x00540b00", "0x00540b14"}
PROJECTION_METHOD_AND_CLEANUP_SITES = {
    "0x0049c019",
    "0x0049c0a6",
    "0x004ad947",
    "0x004adb72",
    "0x004adef7",
    "0x004add76",
}

CONSTRUCTOR_CHECKPOINTS = {
    "0x0049c57c": {
        "name": "candidate_0x49c553_base_record",
        "pointer_register": "eax",
        "expected_selected_vtable": "0x00540a74",
    },
    "0x0049c5b6": {
        "name": "candidate_0x49c58a_derived_record",
        "pointer_register": "esi",
        "expected_selected_vtable": "0x00540ac4",
    },
    "0x0049c832": {
        "name": "candidate_0x49c806_derived_record",
        "pointer_register": "esi",
        "expected_selected_vtable": "0x00540ab0",
    },
    "0x0049c8dc": {
        "name": "candidate_0x49c8b0_derived_record",
        "pointer_register": "esi",
        "expected_selected_vtable": "0x00540ad8",
    },
    "0x0049ca0f": {
        "name": "candidate_0x49c9e3_derived_record",
        "pointer_register": "esi",
        "expected_selected_vtable": "0x00540b64",
    },
    "0x0049cd7b": {
        "name": "candidate_0x49ccec_derived_record",
        "pointer_register": "esi",
        "expected_selected_vtable": "0x00540b78",
    },
    "0x0049cb37": {
        "name": "projection_0x49cac2_record",
        "pointer_register": "esi",
        "expected_selected_vtable": "0x00540b14",
    },
    "0x0049cbfc": {
        "name": "projection_0x49cb83_record",
        "pointer_register": "esi",
        "expected_selected_vtable": "0x00540b14",
    },
    "0x0049cc97": {
        "name": "projection_0x49cc22_record",
        "pointer_register": "esi",
        "expected_selected_vtable": "0x00540b14",
    },
    "0x0049cdec": {
        "name": "projection_0x49cdb1_record",
        "pointer_register": "esi",
        "expected_selected_vtable": "0x00540b00",
    },
}


def word_at(event: dict[str, Any], pointer: int | None, word_index: int = 0) -> int | None:
    if pointer is None:
        return None
    target = pointer + word_index * 4
    for line in event.get("memory_lines", []):
        address = line.get("address")
        if address is None:
            continue
        words = line.get("words", [])
        offset = target - address
        if offset >= 0 and offset % 4 == 0:
            index = offset // 4
            if 0 <= index < len(words):
                return int(words[index])
    return None


def object_vtable(event: dict[str, Any], pointer: int | None) -> str:
    value = word_at(event, pointer, 0)
    return hex32(value) if value is not None else "not-dumped"


def compact_record(record: dict[str, Any]) -> dict[str, Any]:
    constructor = record.get("constructor")
    return {
        "event_index": record["event_index"],
        "vtable": record["vtable"],
        "constructor": constructor,
    }


def collect_selected_returns(events: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], dict[str, list[dict[str, Any]]]]:
    selected: list[dict[str, Any]] = []
    by_pointer: dict[str, list[dict[str, Any]]] = defaultdict(list)
    latest_constructor_by_pointer: dict[int, dict[str, Any]] = {}

    for index, event in enumerate(events):
        address = normalize_address(event.get("address", "0"))
        registers = event.get("registers", {})
        if address in CONSTRUCTOR_CHECKPOINTS:
            checkpoint = CONSTRUCTOR_CHECKPOINTS[address]
            pointer = registers.get(checkpoint["pointer_register"])
            if pointer is None:
                continue
            latest_constructor_by_pointer[pointer] = {
                "event_index": index,
                "site": address,
                "name": checkpoint["name"],
                "expected_selected_vtable": checkpoint["expected_selected_vtable"],
                "pointer": hex32(pointer),
                "pre_write_vtable_in_dump": object_vtable(event, pointer),
            }
            continue

        if address != SELECTED_RETURN_SITE:
            continue
        pointer = registers.get("eax")
        if pointer is None:
            continue
        constructor = latest_constructor_by_pointer.get(pointer)
        if constructor and index - int(constructor["event_index"]) > 2:
            constructor = None
        record = {
            "event_index": index,
            "pointer": hex32(pointer),
            "vtable": object_vtable(event, pointer),
            "constructor": constructor,
        }
        selected.append(record)
        by_pointer[record["pointer"]].append(record)

    return selected, by_pointer


def find_projection_reuse_transitions(
    selected_by_pointer: dict[str, list[dict[str, Any]]]
) -> list[dict[str, Any]]:
    transitions: list[dict[str, Any]] = []
    for pointer, records in selected_by_pointer.items():
        last_projection: dict[str, Any] | None = None
        for record in records:
            if record["vtable"] in PROJECTION_VTABLES:
                last_projection = record
                continue
            if last_projection is None:
                continue
            constructor = record.get("constructor") or {}
            transitions.append(
                {
                    "pointer": pointer,
                    "projection_selected_return": compact_record(last_projection),
                    "later_non_projection_selected_return": compact_record(record),
                    "later_constructor_site": constructor.get("site", "missing"),
                    "later_constructor_name": constructor.get("name", "missing"),
                    "later_constructor_expected_vtable": constructor.get(
                        "expected_selected_vtable", "missing"
                    ),
                }
            )
            last_projection = None
    return transitions


def find_final_dispatches(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for index, event in enumerate(events):
        if normalize_address(event.get("address", "0")) != FINAL_SLOT8_SITE:
            continue
        registers = event.get("registers", {})
        member = registers.get("ecx")
        vtable = registers.get("eax")
        slot8 = word_at(event, vtable, 2)
        records.append(
            {
                "event_index": index,
                "member": hex32(member) if member is not None else "missing",
                "vtable": hex32(vtable) if vtable is not None else "missing",
                "slot8_target": hex32(slot8) if slot8 is not None else "missing",
            }
        )
    return records


def summarize(ledger: dict[str, Any]) -> dict[str, Any]:
    events = ledger.get("events", [])
    address_counts = Counter(
        normalize_address(event.get("address", "0")) for event in events if event.get("address")
    )
    selected_returns, selected_by_pointer = collect_selected_returns(events)
    reused_pointer_groups = {
        pointer: records
        for pointer, records in selected_by_pointer.items()
        if len({record["vtable"] for record in records}) > 1
    }
    projection_reuse_transitions = find_projection_reuse_transitions(selected_by_pointer)
    final_dispatches = find_final_dispatches(events)
    instrumented_selected_returns = [
        record for record in selected_returns if record.get("constructor")
    ]
    projection_or_cleanup_counts = {
        address: address_counts.get(address, 0)
        for address in sorted(PROJECTION_METHOD_AND_CLEANUP_SITES)
    }
    constructor_counts = {
        address: address_counts.get(address, 0)
        for address in sorted(CONSTRUCTOR_CHECKPOINTS)
    }
    final_slot_targets = Counter(record["slot8_target"] for record in final_dispatches)
    return {
        "schema_id": "h3maped_selected_constructor_reuse_summary_v1",
        "ledger": ledger.get("log_path", ""),
        "partial_reason": ledger.get("partial_reason", ""),
        "event_count": int(ledger.get("event_count", len(events))),
        "address_counts": dict(sorted(address_counts.items())),
        "constructor_checkpoint_counts": constructor_counts,
        "selected_return_count": len(selected_returns),
        "selected_return_vtable_counts": dict(
            sorted(Counter(record["vtable"] for record in selected_returns).items())
        ),
        "selected_pointer_count": len(selected_by_pointer),
        "selected_pointers_with_multiple_vtables": len(reused_pointer_groups),
        "projection_to_non_projection_reuse_count": len(projection_reuse_transitions),
        "projection_to_non_projection_reuse_examples": projection_reuse_transitions[:10],
        "final_dispatch_count": len(final_dispatches),
        "final_dispatch_slot_targets": dict(sorted(final_slot_targets.items())),
        "final_dispatches": final_dispatches,
        "projection_method_and_cleanup_counts": projection_or_cleanup_counts,
        "invariants": {
            "instrumented_constructor_pairs_match_selected_vtables": bool(
                instrumented_selected_returns
            )
            and all(
                record["constructor"]["expected_selected_vtable"] == record["vtable"]
                for record in instrumented_selected_returns
            ),
            "same_pointer_reused_for_multiple_selected_vtables": bool(reused_pointer_groups),
            "projection_pointer_later_reused_by_non_projection_constructor": bool(
                projection_reuse_transitions
            ),
            "final_dispatches_use_ordinary_slot8_in_sample": bool(final_dispatches)
            and all(record["slot8_target"] == "0x0049baf5" for record in final_dispatches),
            "projection_methods_and_cleanup_not_hit": not any(projection_or_cleanup_counts.values()),
        },
        "recovered_boundary": (
            "The sampled projection-to-ordinary change is not an observed 0x540b14 slot +0x08 "
            "method mutation. The same heap addresses are later returned by selected-object "
            "constructors with non-projection vtables, proving constructor/allocator-slot reuse "
            "at the selected-object boundary."
        ),
        "remaining_gap": (
            "The destructor/free owner that releases or recycles these selected-object allocations "
            "is still unrecovered. Native RMG behavior must still not be changed from this evidence "
            "alone because the complete selected-object lifetime and cleanup ownership is not proven."
        ),
        "native_behavior_changed": False,
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
        "RMG_H3MAPED_SELECTED_CONSTRUCTOR_REUSE_SUMMARY "
        f"status={status} events={summary['event_count']} "
        f"selected_returns={summary['selected_return_count']} "
        f"reused_pointer_groups={summary['selected_pointers_with_multiple_vtables']} "
        f"projection_to_non_projection_reuse={summary['projection_to_non_projection_reuse_count']} "
        f"final_dispatches={summary['final_dispatch_count']} out={args.out}"
    )
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
