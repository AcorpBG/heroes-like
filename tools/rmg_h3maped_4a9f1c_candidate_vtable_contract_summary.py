#!/usr/bin/env python3
"""Summarize H3MapEd 0x4a9f1c selected candidate vtable contracts.

This is source-recovery evidence only. It combines the live selected-create
trace with raw vtable bytes from the canonical H3MapEd executable so selected
candidate records are no longer anonymous vtable pointers.
"""

from __future__ import annotations

import argparse
import json
import struct
from collections import Counter
from pathlib import Path
from typing import Any

from rmg_h3maped_4a9f1c_selected_create_summary import (
    DEFAULT_LEDGER,
    DEFAULT_LOG,
    classify_cycle,
    group_cycles,
    hex32,
)
from rmg_h3maped_recovery_trace import parse_winedbg_log


DEFAULT_BINARY = Path(
    ".artifacts/rmg_20seed_2p_small_h3maped_20260605/"
    "small_2p_seed_58_manual20/runtime/h3maped.exe"
)
DEFAULT_OUT = Path(".artifacts/rmg_recovery/medium_4a9f1c_candidate_vtable_contract_summary_20260608.json")

IMAGE_SECTIONS = [
    {"name": ".text", "vma": 0x401000, "size": 0x12DE0E, "file_offset": 0x1000},
    {"name": ".rdata", "vma": 0x52F000, "size": 0x4A3AE, "file_offset": 0x12F000},
    {"name": ".data", "vma": 0x57A000, "size": 0x1F000, "file_offset": 0x17A000},
]


SELECTED_AND_ADJACENT_CANDIDATE_CONTRACTS: dict[str, dict[str, Any]] = {
    "0x00540ba0": {
        "create": "0x0049c553",
        "score": "0x0049c54d",
        "predicate": "0x0049c54a",
        "rtti_or_metadata": "0x00557978",
        "score_contract": "returns candidate+0x0c as the value",
        "create_contract": "allocates 0x1c object and initializes base object record through 0x49ba89",
        "returned_object_vtable": "0x00540a74",
    },
    "0x00540bb0": {
        "create": "0x0049c58a",
        "score": "0x0049c54d",
        "predicate": "0x0049c54a",
        "rtti_or_metadata": "0x005579c8",
        "score_contract": "returns candidate+0x0c as the value",
        "create_contract": "allocates 0x1c object, initializes through 0x49ba89, then installs vtable 0x540ac4",
        "returned_object_vtable": "0x00540ac4",
    },
    "0x00540c10": {
        "create": "0x0049c8b0",
        "score": "0x0049c54d",
        "predicate": "0x0049c54a",
        "rtti_or_metadata": "0x00557bc0",
        "score_contract": "returns candidate+0x0c as the value",
        "create_contract": "allocates 0x1c object, initializes through 0x49ba89, then installs vtable 0x540ad8",
        "returned_object_vtable": "0x00540ad8",
    },
    "0x00540c40": {
        "create": "0x0049c9e3",
        "score": "0x0049c54d",
        "predicate": "0x0049c54a",
        "rtti_or_metadata": "0x00557cb0",
        "score_contract": "returns candidate+0x0c as the value",
        "create_contract": "allocates 0x1c object, initializes through 0x49ba89, then installs vtable 0x540b64",
        "returned_object_vtable": "0x00540b64",
    },
    "0x00540c60": {
        "create": "0x0049cac2",
        "score": "0x0049ca8b",
        "predicate": "0x0049baf5",
        "rtti_or_metadata": "0x00557d50",
        "score_contract": (
            "cursor/flag gated scorer: rejects with -1 when generator+0xf58 does not match candidate+0x08 "
            "or generator+0x10b4 is nonzero; otherwise derives value from 0x49c64b"
        ),
        "create_contract": (
            "projection constructor A: builds a 0x540b28 base record through 0x49c0d3, selects a descriptor "
            "through 0x4a9e40, then allocates a 0x540b14 projection object"
        ),
        "returned_object_vtable": "0x00540b14",
        "object_layout_note": "returned 0x540b14 projection objects do not use descriptor at object+0x04",
    },
    "0x00540c70": {
        "create": "0x0049cb83",
        "score": "0x0049cb60",
        "predicate": "0x0049baf5",
        "rtti_or_metadata": "0x00557da0",
        "score_contract": (
            "cursor/flag gated scorer: rejects with -1 when generator+0xf58 does not match candidate+0x08 "
            "or generator+0x10b4 is nonzero; otherwise returns candidate+0x0c"
        ),
        "create_contract": "projection constructor B: creates 0x540b14 with a 0x540b28 base record",
        "returned_object_vtable": "0x00540b14",
        "object_layout_note": "returned 0x540b14 projection objects do not use descriptor at object+0x04",
    },
    "0x00540c80": {
        "create": "0x0049cc22",
        "score": "0x0049cb60",
        "predicate": "0x0049baf5",
        "rtti_or_metadata": "0x00557df0",
        "score_contract": (
            "cursor/flag gated scorer: rejects with -1 when generator+0xf58 does not match candidate+0x08 "
            "or generator+0x10b4 is nonzero; otherwise returns candidate+0x0c"
        ),
        "create_contract": "projection constructor C: creates 0x540b14 with a 0x540b28 base record",
        "returned_object_vtable": "0x00540b14",
        "object_layout_note": "returned 0x540b14 projection objects do not use descriptor at object+0x04",
    },
    "0x00540c90": {
        "create": "0x0049ccec",
        "score": "0x0049c54d",
        "predicate": "0x0049c54a",
        "rtti_or_metadata": "0x00557e40",
        "score_contract": "returns candidate+0x0c as the value",
        "create_contract": "randomly selects a matching global object/source row and returns object vtable 0x540b78",
        "returned_object_vtable": "0x00540b78",
    },
    "0x00540ca0": {
        "create": "0x0049cdb1",
        "score": "0x0049cd97",
        "predicate": "0x0049baf5",
        "rtti_or_metadata": "0x00557e88",
        "score_contract": "cursor-gated scorer: returns candidate+0x0c only when generator+0xf5c matches candidate+0x08",
        "create_contract": "adjacent projection constructor that installs projection vtable 0x540b00",
        "returned_object_vtable": "0x00540b00",
        "object_layout_note": "returned 0x540b00 projection objects do not use descriptor at object+0x04",
    },
}


def canonical_hex(value: str | int | None) -> str | None:
    if value is None:
        return None
    if isinstance(value, str):
        return hex32(int(value, 16))
    return hex32(value)


def binary_offset_for_va(virtual_address: int) -> int:
    for section in IMAGE_SECTIONS:
        vma = int(section["vma"])
        size = int(section["size"])
        if vma <= virtual_address < vma + size:
            return int(section["file_offset"]) + (virtual_address - vma)
    raise ValueError(f"virtual address outside known sections: 0x{virtual_address:08x}")


def read_vtable_words(binary: Path, vtable: str) -> list[str]:
    data = binary.read_bytes()
    offset = binary_offset_for_va(int(vtable, 16))
    raw = data[offset : offset + 16]
    if len(raw) != 16:
        raise ValueError(f"short vtable read at {vtable}")
    return [hex32(word) for word in struct.unpack("<IIII", raw)]


def load_selected_cycles(log_path: Path) -> list[dict[str, Any]]:
    parsed = parse_winedbg_log(log_path)
    return [cycle for cycle in (classify_cycle(raw) for raw in group_cycles(parsed["events"])) if cycle["reached_create_return"]]


def count_values(cycles: list[dict[str, Any]], key: str) -> dict[str, int]:
    counter = Counter(str(cycle.get(key)) for cycle in cycles)
    return dict(sorted(counter.items()))


def contract_words(contract: dict[str, Any]) -> list[str]:
    return [
        canonical_hex(contract["create"]) or "",
        canonical_hex(contract["score"]) or "",
        canonical_hex(contract["predicate"]) or "",
        canonical_hex(contract["rtti_or_metadata"]) or "",
    ]


def build_summary(binary: Path, log_path: Path, ledger_path: Path) -> dict[str, Any]:
    selected_cycles = load_selected_cycles(log_path)
    complete_cycles = [cycle for cycle in selected_cycles if cycle.get("complete_cycle")]

    binary_vtables: dict[str, list[str]] = {}
    vtable_mismatches: dict[str, dict[str, Any]] = {}
    for vtable, contract in SELECTED_AND_ADJACENT_CANDIDATE_CONTRACTS.items():
        words = read_vtable_words(binary, vtable)
        expected = contract_words(contract)
        binary_vtables[vtable] = words
        if words != expected:
            vtable_mismatches[vtable] = {"expected": expected, "actual": words}

    selected_records: list[dict[str, Any]] = []
    invariant_failures: list[str] = []
    for index, cycle in enumerate(selected_cycles):
        vtable = cycle.get("selected_candidate_vtable")
        contract = SELECTED_AND_ADJACENT_CANDIDATE_CONTRACTS.get(str(vtable), {})
        expected_object_vtable = contract.get("returned_object_vtable")
        object_vtable_matches = expected_object_vtable == cycle.get("selected_object_vtable")
        field_score_matches = None
        if contract.get("score") == "0x0049c54d":
            field_score_matches = cycle.get("selected_candidate_value_field") == cycle.get("selected_value_return")
        record = {
            "cycle_index": index,
            "complete_cycle": cycle.get("complete_cycle"),
            "caller_return": cycle.get("caller_return"),
            "candidate_vtable": vtable,
            "candidate_type": cycle.get("selected_candidate_type"),
            "candidate_value_field": cycle.get("selected_candidate_value_field"),
            "selected_value_return": cycle.get("selected_value_return"),
            "candidate_create_function": contract.get("create"),
            "candidate_score_function": contract.get("score"),
            "candidate_predicate_function": contract.get("predicate"),
            "score_contract": contract.get("score_contract"),
            "create_contract": contract.get("create_contract"),
            "selected_object_vtable": cycle.get("selected_object_vtable"),
            "expected_object_vtable": expected_object_vtable,
            "object_vtable_matches_contract": object_vtable_matches,
            "field_score_matches_selected_value": field_score_matches,
            "object_descriptor_matches_arg": cycle.get("selected_object_descriptor_matches_arg"),
            "object_layout_note": contract.get("object_layout_note"),
        }
        selected_records.append(record)
        if not contract:
            invariant_failures.append(f"cycle {index}: unknown selected candidate vtable {vtable}")
        elif not object_vtable_matches:
            invariant_failures.append(
                f"cycle {index}: selected object vtable {cycle.get('selected_object_vtable')} "
                f"does not match contract {expected_object_vtable}"
            )
        if field_score_matches is False:
            invariant_failures.append(f"cycle {index}: 0x49c54d selected value did not equal candidate+0x0c")

    selected_vtables = {str(cycle.get("selected_candidate_vtable")) for cycle in selected_cycles}
    selected_without_contract = sorted(selected_vtables - set(SELECTED_AND_ADJACENT_CANDIDATE_CONTRACTS))
    projection_selected_count = sum(
        1 for cycle in selected_cycles if cycle.get("selected_object_vtable") in {"0x00540b00", "0x00540b14"}
    )

    return {
        "status": "passed_selected_candidate_vtable_contracts" if not invariant_failures and not vtable_mismatches else "failed_selected_candidate_vtable_contracts",
        "native_behavior_changed": False,
        "binary": str(binary),
        "trace": {"log_path": str(log_path), "ledger_path": str(ledger_path)},
        "selected_create_return_cycles": len(selected_cycles),
        "complete_selected_create_cycles": len(complete_cycles),
        "selected_candidate_vtable_counts": count_values(selected_cycles, "selected_candidate_vtable"),
        "selected_object_vtable_counts": count_values(selected_cycles, "selected_object_vtable"),
        "projection_selected_create_return_count": projection_selected_count,
        "binary_vtable_words": binary_vtables,
        "vtable_mismatches": vtable_mismatches,
        "selected_records": selected_records,
        "selected_candidate_vtables_without_contract": selected_without_contract,
        "invariant_failures": invariant_failures,
        "recovered_contract": {
            "candidate_record_fields": {
                "+0x00": "candidate vtable pointer",
                "+0x04": "descriptor type/category index consumed by generator+0x1110 and relation-local +0x44 counters",
                "+0x08": "cursor/source discriminator for gated projection scorers 0x49ca8b/0x49cb60/0x49cd97",
                "+0x0c": "direct value returned by scorer 0x49c54d and by gated scorer variants after cursor checks",
            },
            "selected_vtable_contracts": SELECTED_AND_ADJACENT_CANDIDATE_CONTRACTS,
        },
        "explicit_non_claims": [
            "This report names candidate vtable slot contracts and selected returned object families; it does not name every descriptor type semantically.",
            "This report does not recover the later 0x540b00/0x540b14 projection-method consumer.",
            "This report does not recover 0x4add76 cleanup/uncommit.",
            "This report does not justify native RMG density tuning or behavior changes.",
        ],
        "remaining_blockers": [
            "Name descriptor type/category semantics beyond the recovered numeric counter index.",
            "Recover a generation path that actually reaches 0x4add76 cleanup/uncommit.",
            "Recover pointer-paired downstream consumer linkage for returned projection objects, especially 0x540b00/0x540b14 slot +0x08 dispatch.",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path, default=DEFAULT_BINARY)
    parser.add_argument("--log", type=Path, default=DEFAULT_LOG)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    for path in [args.binary, args.log]:
        if not path.exists():
            raise SystemExit(f"missing required input: {path}")

    summary = build_summary(args.binary, args.log, args.ledger)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_4A9F1C_CANDIDATE_VTABLE_CONTRACT_SUMMARY "
        f"status={summary['status']} selected_returns={summary['selected_create_return_cycles']} "
        f"projection_returns={summary['projection_selected_create_return_count']} out={args.out}"
    )
    return 1 if summary["status"].startswith("failed") else 0


if __name__ == "__main__":
    raise SystemExit(main())
