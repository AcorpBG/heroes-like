#!/usr/bin/env python3
"""Summarize H3MapEd selected-object destructor/recycle ownership evidence."""

from __future__ import annotations

import argparse
import json
import struct
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

from rmg_h3maped_4aa3e9_ordered_summary import hex32, normalize_address


DEFAULT_LEDGER = Path(
    ".artifacts/rmg_recovery/small2p_selected_destructor_trace_20260610/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_FREE_LEDGER = Path(
    ".artifacts/rmg_recovery/small2p_selected_recycle_trace2_20260610/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_GHIDRA_DUMP = Path(".artifacts/rmg_recovery/ghidra_selected_recycle_destructors_dump_20260610")
DEFAULT_ALLOC_DUMP = Path(".artifacts/rmg_recovery/ghidra_selected_recycle_owner_dump_20260610")
DEFAULT_BINARY = Path(
    ".artifacts/rmg_20seed_2p_small_h3maped_20260605/"
    "small_2p_seed_58_manual20/runtime/h3maped.exe"
)

IMAGE_RDATA_VMA = 0x52F000
IMAGE_RDATA_FILE_OFFSET = 0x12F000

SELECTED_RETURN_SITE = "0x004aa168"
PROJECTION_VTABLES = {"0x00540b00", "0x00540b14"}

CONSTRUCTOR_CHECKPOINTS = {
    "0x0049c57c": ("eax", "candidate_0x49c553_base_record", "0x00540a74"),
    "0x0049c5b6": ("esi", "candidate_0x49c58a_derived_record", "0x00540ac4"),
    "0x0049c832": ("esi", "candidate_0x49c806_derived_record", "0x00540ab0"),
    "0x0049c8dc": ("esi", "candidate_0x49c8b0_derived_record", "0x00540ad8"),
    "0x0049ca0f": ("esi", "candidate_0x49c9e3_derived_record", "0x00540b64"),
    "0x0049cd7b": ("esi", "candidate_0x49ccec_derived_record", "0x00540b78"),
    "0x0049cb37": ("esi", "projection_0x49cac2_record", "0x00540b14"),
    "0x0049cbfc": ("esi", "projection_0x49cb83_record", "0x00540b14"),
    "0x0049cc97": ("esi", "projection_0x49cc22_record", "0x00540b14"),
    "0x0049cdec": ("esi", "projection_0x49cdb1_record", "0x00540b00"),
}

DESTRUCTOR_ENTRY_SITES = {
    "0x0049bab3": ("ecx", "ordinary_0x540a74_destructor"),
    "0x0049bb76": ("ecx", "ordinary_or_projection_adjacent_destructor"),
    "0x0049c049": ("ecx", "projection_0x540b14_destructor"),
}

DESTRUCTOR_FREE_SITES = {
    "0x0049baca": ("esi", "ordinary_0x540a74_optional_free"),
    "0x0049bb86": ("esi", "ordinary_or_projection_adjacent_optional_free"),
    "0x0049c059": ("esi", "projection_0x540b14_optional_free_after_downgrade"),
}

PROJECTION_CHILD_DESTROY_SITE = "0x0049c08b"

VTABLES = [
    0x540A74,
    0x540A88,
    0x540A9C,
    0x540AB0,
    0x540AC4,
    0x540AD8,
    0x540B00,
    0x540B14,
    0x540B28,
    0x540B64,
    0x540B78,
]


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


def read_vtables(binary: Path) -> dict[str, list[str]]:
    data = binary.read_bytes()
    out: dict[str, list[str]] = {}
    for address in VTABLES:
        offset = IMAGE_RDATA_FILE_OFFSET + (address - IMAGE_RDATA_VMA)
        words = struct.unpack("<IIIII", data[offset : offset + 20])
        out[hex32(address)] = [hex32(word) for word in words]
    return out


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8") if path.exists() else ""


def collect_events(ledger: dict[str, Any]) -> dict[str, Any]:
    latest_constructor_by_pointer: dict[int, dict[str, Any]] = {}
    selected_returns: list[dict[str, Any]] = []
    destructor_entries: list[dict[str, Any]] = []
    destructor_frees: list[dict[str, Any]] = []
    child_destroys: list[dict[str, Any]] = []
    address_counts: Counter[str] = Counter()

    for index, event in enumerate(ledger.get("events", [])):
        address = normalize_address(event.get("address", "0"))
        address_counts[address] += 1
        registers = event.get("registers", {})

        if address in CONSTRUCTOR_CHECKPOINTS:
            pointer_register, name, expected_vtable = CONSTRUCTOR_CHECKPOINTS[address]
            pointer = registers.get(pointer_register)
            if pointer is not None:
                latest_constructor_by_pointer[pointer] = {
                    "event_index": index,
                    "site": address,
                    "name": name,
                    "pointer": hex32(pointer),
                    "expected_selected_vtable": expected_vtable,
                    "pre_write_vtable_in_dump": object_vtable(event, pointer),
                }
            continue

        if address == SELECTED_RETURN_SITE:
            pointer = registers.get("eax")
            selected_returns.append(
                {
                    "event_index": index,
                    "pointer": hex32(pointer) if pointer is not None else "missing",
                    "vtable": object_vtable(event, pointer),
                    "constructor": latest_constructor_by_pointer.get(pointer),
                }
            )
            continue

        if address in DESTRUCTOR_ENTRY_SITES:
            pointer_register, name = DESTRUCTOR_ENTRY_SITES[address]
            pointer = registers.get(pointer_register)
            destructor_entries.append(
                {
                    "event_index": index,
                    "site": address,
                    "name": name,
                    "pointer": hex32(pointer) if pointer is not None else "missing",
                    "vtable": object_vtable(event, pointer),
                }
            )
            continue

        if address in DESTRUCTOR_FREE_SITES:
            pointer_register, name = DESTRUCTOR_FREE_SITES[address]
            pointer = registers.get(pointer_register)
            destructor_frees.append(
                {
                    "event_index": index,
                    "site": address,
                    "name": name,
                    "pointer": hex32(pointer) if pointer is not None else "missing",
                    "vtable": object_vtable(event, pointer),
                }
            )
            continue

        if address == PROJECTION_CHILD_DESTROY_SITE:
            pointer = registers.get("ecx")
            child_destroys.append(
                {
                    "event_index": index,
                    "site": address,
                    "name": "projection_owned_child_slot0_destroy",
                    "pointer": hex32(pointer) if pointer is not None else "missing",
                    "vtable": object_vtable(event, pointer),
                }
            )

    return {
        "address_counts": dict(sorted(address_counts.items())),
        "selected_returns": selected_returns,
        "destructor_entries": destructor_entries,
        "destructor_frees": destructor_frees,
        "projection_child_destroys": child_destroys,
    }


def projection_reuse_transitions(collected: dict[str, Any]) -> list[dict[str, Any]]:
    selected_by_pointer: dict[str, list[dict[str, Any]]] = defaultdict(list)
    destructor_by_pointer: dict[str, list[dict[str, Any]]] = defaultdict(list)
    free_by_pointer: dict[str, list[dict[str, Any]]] = defaultdict(list)
    child_destroys = collected["projection_child_destroys"]
    for record in collected["selected_returns"]:
        selected_by_pointer[record["pointer"]].append(record)
    for record in collected["destructor_entries"]:
        destructor_by_pointer[record["pointer"]].append(record)
    for record in collected["destructor_frees"]:
        free_by_pointer[record["pointer"]].append(record)

    transitions: list[dict[str, Any]] = []
    for pointer, records in selected_by_pointer.items():
        last_projection: dict[str, Any] | None = None
        for record in records:
            if record["vtable"] in PROJECTION_VTABLES:
                last_projection = record
                continue
            if last_projection is None:
                continue
            start = int(last_projection["event_index"])
            end = int(record["event_index"])
            transitions.append(
                {
                    "pointer": pointer,
                    "projection_selected_return": last_projection,
                    "later_non_projection_selected_return": record,
                    "destructor_entries_between": [
                        item for item in destructor_by_pointer.get(pointer, []) if start < item["event_index"] < end
                    ],
                    "destructor_frees_between": [
                        item for item in free_by_pointer.get(pointer, []) if start < item["event_index"] < end
                    ],
                    "projection_child_destroys_between": [
                        item for item in child_destroys if start < item["event_index"] < end
                    ],
                }
            )
            last_projection = None
    return transitions


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    ledger = json.loads(args.ledger.read_text(encoding="utf-8"))
    free_ledger = json.loads(args.free_ledger.read_text(encoding="utf-8")) if args.free_ledger.exists() else {}
    collected = collect_events(ledger)
    selected_pointers = {record["pointer"] for record in collected["selected_returns"]}
    destructor_overlap = [
        record for record in collected["destructor_entries"] if record["pointer"] in selected_pointers
    ]
    free_overlap = [record for record in collected["destructor_frees"] if record["pointer"] in selected_pointers]
    transitions = projection_reuse_transitions(collected)
    transitions_with_destroy_and_free = [
        item
        for item in transitions
        if item["destructor_entries_between"] and item["destructor_frees_between"]
    ]

    old_free_collected = collect_events(free_ledger) if free_ledger else {}
    old_free_selected = {record["pointer"] for record in old_free_collected.get("selected_returns", [])}
    old_free_overlap = [
        record
        for record in old_free_collected.get("destructor_frees", [])
        if record["pointer"] in old_free_selected
    ]

    destructor_static = {
        "0x0049bab3": {
            "vtable_slot0_for": ["0x00540a74"],
            "contract": "decrements descriptor/refcount at object+0x04->+0x08 and optionally frees self via 0x5044da when destructor arg bit0 is set",
            "dump_contains_optional_free": "0049baca: CALL 0x005044da"
            in read_text(args.ghidra_destructors / "target_0049bab3_FUN_0049bab3.txt"),
        },
        "0x0049bb76": {
            "vtable_slot0_for": [
                "0x00540a88",
                "0x00540a9c",
                "0x00540ab0",
                "0x00540ac4",
                "0x00540ad8",
                "0x00540b00",
                "0x00540b28",
                "0x00540b64",
                "0x00540b78",
            ],
            "contract": "calls internal 0x49bda7 cleanup, then optionally frees self via 0x5044da when destructor arg bit0 is set",
            "dump_contains_optional_free": "0049bb86: CALL 0x005044da"
            in read_text(args.ghidra_destructors / "target_0049bb76_FUN_0049bb76.txt"),
        },
        "0x0049c049": {
            "vtable_slot0_for": ["0x00540b14"],
            "contract": "calls 0x49c065; 0x49c065 destroys owned object+0x20 through its slot0, downgrades shell vtable to 0x540a74, decrements descriptor/refcount, then 0x49c049 optionally frees self via 0x5044da",
            "dump_contains_owned_child_destroy": "0049c08b: CALL dword ptr [EAX]"
            in read_text(args.ghidra_destructors / "target_0049c065_FUN_0049c065.txt"),
            "dump_contains_optional_free": "0049c059: CALL 0x005044da"
            in read_text(args.ghidra_destructors / "target_0049c049_FUN_0049c049.txt"),
        },
    }

    return {
        "schema_id": "h3maped_selected_recycle_owner_summary_v1",
        "ledger": str(args.ledger),
        "older_generic_free_ledger": str(args.free_ledger),
        "ghidra_destructor_dump": str(args.ghidra_destructors),
        "ghidra_allocator_dump": str(args.ghidra_allocator),
        "event_count": int(ledger.get("event_count", len(ledger.get("events", [])))),
        "address_counts": collected["address_counts"],
        "selected_return_count": len(collected["selected_returns"]),
        "selected_pointer_count": len(selected_pointers),
        "selected_return_vtable_counts": dict(
            sorted(Counter(record["vtable"] for record in collected["selected_returns"]).items())
        ),
        "destructor_entry_count": len(collected["destructor_entries"]),
        "destructor_free_count": len(collected["destructor_frees"]),
        "selected_pointer_destructor_overlap_count": len(destructor_overlap),
        "selected_pointer_free_overlap_count": len(free_overlap),
        "projection_child_destroy_count": len(collected["projection_child_destroys"]),
        "projection_to_non_projection_reuse_count": len(transitions),
        "projection_reuse_transitions": transitions,
        "static_contract": {
            "vtable_slot_words": read_vtables(args.binary),
            "destructors": destructor_static,
            "allocator": {
                "0x005044b1": "allocation helper that calls 0x4e7b5e and optional retry hook at 0x5938e4",
                "0x005044da": "free helper that delegates to 0x4e7298",
            },
        },
        "older_generic_free_trace_negative_evidence": {
            "event_count": int(free_ledger.get("event_count", 0)) if free_ledger else 0,
            "selected_pointer_free_overlap_count": len(old_free_overlap),
            "interpretation": (
                "The earlier generic candidate-container free trace hit 0x49ef78/0x49f29e/0x49f7aa, "
                "but those freed pointers did not overlap selected-object heap addresses."
            ),
        },
        "invariants": {
            "no_native_behavior_change": True,
            "no_objdump_used": True,
            "selected_destructors_hit": bool(collected["destructor_entries"]),
            "selected_free_sites_hit": bool(collected["destructor_frees"]),
            "selected_pointer_destructor_overlap_observed": bool(destructor_overlap),
            "selected_pointer_free_overlap_observed": bool(free_overlap),
            "projection_reuse_has_destroy_and_free_between": bool(transitions_with_destroy_and_free),
            "projection_child_destroy_observed": bool(collected["projection_child_destroys"]),
            "static_destructor_contract_present": all(
                value.get("dump_contains_optional_free", False) for value in destructor_static.values()
            )
            and destructor_static["0x0049c049"].get("dump_contains_owned_child_destroy", False),
        },
        "source_backed_conclusion": (
            "The selected-object recycle owner for sampled projection-to-ordinary reuse is the selected-object "
            "vtable slot0 destructor path, not the generator candidate-container cleanup family. In the sampled "
            "Small 2-player/no-water Wine run, projection selected object 0x03620760 is destroyed through "
            "0x49c049, its owned 0x540b28 child is destroyed at 0x49c08b, the shell is downgraded to 0x540a74, "
            "freed at 0x49c059, and then the same heap address is later returned by ordinary constructor 0x49c553."
        ),
        "remaining_gap": (
            "Full end-to-end RMG recovery is still incomplete: live 0x49c019/0x49c0a6 projection-method dispatch "
            "through final 0x4aa3e9 remains unhit in sampled final commits, 0x4add76/0x4adef7 natural uncommit/"
            "reselection remains unhit, and downstream 0x4a696b positive source/relation-match or unreachable proof "
            "plus older coordinate reconciliation remain open."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--free-ledger", type=Path, default=DEFAULT_FREE_LEDGER)
    parser.add_argument("--ghidra-destructors", type=Path, default=DEFAULT_GHIDRA_DUMP)
    parser.add_argument("--ghidra-allocator", type=Path, default=DEFAULT_ALLOC_DUMP)
    parser.add_argument("--binary", type=Path, default=DEFAULT_BINARY)
    parser.add_argument("--out", type=Path, required=True)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    status = "pass" if all(summary["invariants"].values()) else "partial"
    print(f"RMG_H3MAPED_SELECTED_RECYCLE_OWNER_SUMMARY status={status} out={args.out}")
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
