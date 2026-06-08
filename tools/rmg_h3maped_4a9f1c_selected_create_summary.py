#!/usr/bin/env python3
"""Summarize live H3MapEd 0x4a9f1c accepted-vector selected-create replay.

This is recovery evidence only. It parses a focused ``winedbg`` trace of the
``0x4a9f1c`` path after candidate filtering has ended: accepted-vector size,
weighted RNG selection, selected candidate value writeback, selected descriptor
argument, and selected object-record creation through the candidate vtable
``+0x00`` slot.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

from rmg_h3maped_recovery_trace import parse_winedbg_log


TRACE_DIR = Path(".artifacts/rmg_recovery/medium_4a9f1c_selected_create_branch_trace_20260608")
DEFAULT_LEDGER = TRACE_DIR / "winedbg_interactive_trace_ledger.json"
DEFAULT_LOG = TRACE_DIR / "winedbg_interactive_trace.log"
DEFAULT_OUT = Path(".artifacts/rmg_recovery/medium_4a9f1c_selected_create_summary_20260608.json")

VECTOR_EXIT = "0x004aa0fc"
NONEMPTY_VECTOR_BRANCH = "0x004aa101"
RNG_CALL = "0x004aa110"
RNG_RETURN = "0x004aa115"
RNG_MODULO_RETURN = "0x004aa11c"
SELECTED_INDEX_READY = "0x004aa142"
SELECTED_VECTOR_OFFSET_READY = "0x004aa149"
SELECTED_CANDIDATE_READY = "0x004aa14c"
SELECTED_VALUE_CALL = "0x004aa151"
SELECTED_VALUE_RETURN = "0x004aa154"
SELECTED_CREATE_CALL = "0x004aa166"
SELECTED_CREATE_RETURN = "0x004aa168"
SELECTED_RETURN_STORED = "0x004aa16a"


def hex32(value: int | None) -> str | None:
    if value is None:
        return None
    return f"0x{int(value) & 0xFFFFFFFF:08x}"


def signed32(value: int | None) -> int | None:
    if value is None:
        return None
    value = int(value) & 0xFFFFFFFF
    if value & 0x80000000:
        return value - 0x100000000
    return value


def first_event(cycle: list[dict[str, Any]], address: str) -> dict[str, Any] | None:
    for event in cycle:
        if event.get("address") == address:
            return event
    return None


def word_at(event: dict[str, Any] | None, address: int | None) -> int | None:
    if event is None or address is None:
        return None
    for line in event.get("memory_lines", []):
        base = int(line.get("address", -1))
        words = line.get("words", [])
        byte_delta = int(address) - base
        if byte_delta < 0 or byte_delta % 4 != 0:
            continue
        index = byte_delta // 4
        if 0 <= index < len(words):
            return int(words[index]) & 0xFFFFFFFF
    return None


def words_at_base(event: dict[str, Any] | None, address: int | None) -> list[int]:
    if event is None or address is None:
        return []
    for line in event.get("memory_lines", []):
        if int(line.get("address", -1)) == int(address):
            return [int(word) & 0xFFFFFFFF for word in line.get("words", [])]
    return []


def group_cycles(events: list[dict[str, Any]]) -> list[list[dict[str, Any]]]:
    cycle_addresses = {
        VECTOR_EXIT,
        NONEMPTY_VECTOR_BRANCH,
        RNG_CALL,
        RNG_RETURN,
        RNG_MODULO_RETURN,
        SELECTED_INDEX_READY,
        SELECTED_VECTOR_OFFSET_READY,
        SELECTED_CANDIDATE_READY,
        SELECTED_VALUE_CALL,
        SELECTED_VALUE_RETURN,
        SELECTED_CREATE_CALL,
        SELECTED_CREATE_RETURN,
        SELECTED_RETURN_STORED,
    }
    cycles: list[list[dict[str, Any]]] = []
    current: list[dict[str, Any]] | None = None
    for event in events:
        address = event.get("address")
        if address == VECTOR_EXIT:
            current = []
            cycles.append(current)
        if current is None or address not in cycle_addresses:
            continue
        current.append(event)
        if address == SELECTED_RETURN_STORED:
            current = None
    return cycles


def classify_cycle(cycle: list[dict[str, Any]]) -> dict[str, Any]:
    vector_exit = first_event(cycle, VECTOR_EXIT)
    rng_call = first_event(cycle, RNG_CALL)
    rng_return = first_event(cycle, RNG_RETURN)
    modulo_return = first_event(cycle, RNG_MODULO_RETURN)
    selected_index = first_event(cycle, SELECTED_INDEX_READY)
    vector_offset = first_event(cycle, SELECTED_VECTOR_OFFSET_READY)
    candidate_ready = first_event(cycle, SELECTED_CANDIDATE_READY)
    value_call = first_event(cycle, SELECTED_VALUE_CALL)
    value_return = first_event(cycle, SELECTED_VALUE_RETURN)
    create_call = first_event(cycle, SELECTED_CREATE_CALL)
    create_return = first_event(cycle, SELECTED_CREATE_RETURN)
    return_stored = first_event(cycle, SELECTED_RETURN_STORED)

    exit_regs = vector_exit.get("registers", {}) if vector_exit else {}
    ebp = exit_regs.get("ebp")
    caller_return = word_at(vector_exit, ebp + 4 if isinstance(ebp, int) else None)
    lower_bound = signed32(word_at(vector_exit, ebp + 0x0C if isinstance(ebp, int) else None))
    upper_bound = signed32(word_at(vector_exit, ebp + 0x10 if isinstance(ebp, int) else None))

    accepted_vector_bytes = rng_call.get("registers", {}).get("esi") if rng_call else None
    accepted_vector_count = int(accepted_vector_bytes) // 4 if isinstance(accepted_vector_bytes, int) else None
    rng_value = rng_return.get("registers", {}).get("eax") if rng_return else None
    weighted_remainder = modulo_return.get("registers", {}).get("edx") if modulo_return else None
    selected_index_value = selected_index.get("registers", {}).get("eax") if selected_index else None
    selected_vector_offset = vector_offset.get("registers", {}).get("esi") if vector_offset else None
    selected_candidate = candidate_ready.get("registers", {}).get("ecx") if candidate_ready else None
    selected_value = signed32(value_return.get("registers", {}).get("eax")) if value_return else None
    selected_descriptor_arg = word_at(create_call, create_call.get("registers", {}).get("esp")) if create_call else None
    selected_object = create_return.get("registers", {}).get("eax") if create_return else None

    candidate_words = words_at_base(candidate_ready, selected_candidate)
    object_words = words_at_base(create_return, selected_object)
    object_descriptor = object_words[1] if len(object_words) > 1 else None
    output_value_pointer = word_at(create_call, ebp + 0x14 if isinstance(ebp, int) else None)
    output_value_stored = word_at(create_return, output_value_pointer)

    return {
        "reached_create_return": create_return is not None,
        "complete_cycle": return_stored is not None and bool(return_stored.get("registers")),
        "observed_addresses": [event.get("address") for event in cycle],
        "caller_return": hex32(caller_return),
        "lower_bound": lower_bound,
        "upper_bound": upper_bound,
        "accepted_vector_bytes": accepted_vector_bytes,
        "accepted_vector_count": accepted_vector_count,
        "rng_value": rng_value,
        "weighted_remainder": signed32(weighted_remainder),
        "selected_index": selected_index_value,
        "selected_vector_offset": selected_vector_offset,
        "selected_index_matches_offset": (
            isinstance(selected_index_value, int)
            and isinstance(selected_vector_offset, int)
            and selected_vector_offset == selected_index_value * 4
        ),
        "selected_candidate_pointer": hex32(selected_candidate),
        "selected_candidate_vtable": hex32(candidate_words[0]) if len(candidate_words) > 0 else None,
        "selected_candidate_type": signed32(candidate_words[1]) if len(candidate_words) > 1 else None,
        "selected_candidate_value_field": signed32(candidate_words[3]) if len(candidate_words) > 3 else None,
        "selected_candidate_weight_field": signed32(candidate_words[4]) if len(candidate_words) > 4 else None,
        "selected_value_return": selected_value,
        "selected_value_within_bounds": (
            isinstance(selected_value, int)
            and isinstance(lower_bound, int)
            and isinstance(upper_bound, int)
            and lower_bound <= selected_value <= upper_bound
        ),
        "selected_descriptor_arg": hex32(selected_descriptor_arg),
        "selected_object_pointer": hex32(selected_object),
        "selected_object_vtable": hex32(object_words[0]) if len(object_words) > 0 else None,
        "selected_object_descriptor": hex32(object_descriptor),
        "selected_object_descriptor_matches_arg": (
            selected_descriptor_arg is not None and object_descriptor == selected_descriptor_arg
        ),
        "selected_object_return_observed_in_esi_after_move": (
            return_stored is not None
            and selected_object is not None
            and return_stored.get("registers", {}).get("esi") == selected_object
        ),
        "output_value_pointer": hex32(output_value_pointer),
        "output_value_stored": signed32(output_value_stored),
        "output_value_matches_selected_value": (
            output_value_stored is not None
            and selected_value is not None
            and signed32(output_value_stored) == selected_value
        ),
    }


def count_values(cycles: list[dict[str, Any]], key: str) -> dict[str, int]:
    counts: Counter[str] = Counter()
    for cycle in cycles:
        value = cycle.get(key)
        counts[str(value)] += 1
    return dict(sorted(counts.items()))


def load_metadata(ledger_path: Path) -> dict[str, Any]:
    if not ledger_path.exists():
        return {}
    data = json.loads(ledger_path.read_text(encoding="utf-8"))
    return {
        "ledger_path": str(ledger_path),
        "breakpoints": data.get("breakpoints", []),
        "address_commands": data.get("address_command", []),
        "max_events": data.get("max_events"),
        "schema_id": data.get("schema_id"),
    }


def build_summary(log_path: Path, ledger_path: Path) -> dict[str, Any]:
    parsed = parse_winedbg_log(log_path)
    cycles = [classify_cycle(cycle) for cycle in group_cycles(parsed["events"])]
    complete_cycles = [cycle for cycle in cycles if cycle.get("complete_cycle")]
    create_return_cycles = [cycle for cycle in cycles if cycle.get("reached_create_return")]
    invariant_failures: list[str] = []
    checks = {
        "selected_index_matches_offset": "selected index did not match byte offset",
        "selected_value_within_bounds": "selected value was outside bounds",
        "output_value_matches_selected_value": "output value pointer did not receive selected value",
    }
    for index, cycle in enumerate(complete_cycles):
        for key, message in checks.items():
            if not cycle.get(key):
                invariant_failures.append(f"cycle {index}: {message}")

    return {
        "status": "passed_live_replay_selected_create" if complete_cycles and not invariant_failures else "failed_selected_create_invariants",
        "native_behavior_changed": False,
        "scope": "live same-run selected-create replay for accepted 0x4a9f1c candidates",
        "trace": {
            "log_path": str(log_path),
            **load_metadata(ledger_path),
        },
        "event_count": parsed["event_count"],
        "selected_create_cycle_count": len(cycles),
        "selected_create_return_cycles": len(create_return_cycles),
        "complete_selected_create_cycles": len(complete_cycles),
        "caller_return_counts_create_return_cycles": count_values(create_return_cycles, "caller_return"),
        "caller_return_counts_complete_cycles": count_values(complete_cycles, "caller_return"),
        "selected_candidate_type_counts_create_return_cycles": count_values(
            create_return_cycles, "selected_candidate_type"
        ),
        "selected_candidate_type_counts_complete_cycles": count_values(complete_cycles, "selected_candidate_type"),
        "selected_candidate_vtable_counts_create_return_cycles": count_values(
            create_return_cycles, "selected_candidate_vtable"
        ),
        "selected_candidate_vtable_counts_complete_cycles": count_values(complete_cycles, "selected_candidate_vtable"),
        "selected_object_vtable_counts_create_return_cycles": count_values(
            create_return_cycles, "selected_object_vtable"
        ),
        "selected_object_vtable_counts_complete_cycles": count_values(complete_cycles, "selected_object_vtable"),
        "accepted_vector_count_range": {
            "min": min(cycle["accepted_vector_count"] for cycle in complete_cycles),
            "max": max(cycle["accepted_vector_count"] for cycle in complete_cycles),
        }
        if complete_cycles
        else {"min": None, "max": None},
        "selected_value_range": {
            "min": min(cycle["selected_value_return"] for cycle in complete_cycles),
            "max": max(cycle["selected_value_return"] for cycle in complete_cycles),
        }
        if complete_cycles
        else {"min": None, "max": None},
        "all_selected_index_offsets_match": all(cycle.get("selected_index_matches_offset") for cycle in complete_cycles),
        "all_selected_values_within_bounds": all(cycle.get("selected_value_within_bounds") for cycle in complete_cycles),
        "object_descriptor_match_count": sum(
            1 for cycle in create_return_cycles if cycle.get("selected_object_descriptor_matches_arg")
        ),
        "object_descriptor_mismatch_count": sum(
            1 for cycle in create_return_cycles if not cycle.get("selected_object_descriptor_matches_arg")
        ),
        "selected_object_return_observed_in_esi_after_move_count": sum(
            1 for cycle in complete_cycles if cycle.get("selected_object_return_observed_in_esi_after_move")
        ),
        "all_output_values_match_selected_values": all(cycle.get("output_value_matches_selected_value") for cycle in complete_cycles),
        "invariant_failures": invariant_failures,
        "first_cycles": complete_cycles[:8],
        "recovered_contract": [
            "When the accepted candidate vector is non-empty, 0x4a9f1c calls 0x4e7276 and takes the modulo against accumulated candidate weight.",
            "The weighted remainder walks accepted candidate weights to produce a selected candidate index.",
            "The selected index is multiplied by four and indexes the accepted candidate vector and parallel descriptor vector.",
            "The selected candidate vtable +0x04 value is written to the caller output value pointer.",
            "The selected candidate vtable +0x00 create callback receives generator, selector/relation, and selected descriptor arguments.",
            "The created object record returned in EAX is stored in ESI before 0x4a9f1c teardown/return.",
        ],
        "explicit_non_claims": [
            "This report classifies a bounded Medium trace; it does not name candidate vtable implementations.",
            "This report does not recover descriptor type semantic names.",
            "This report does not capture 0x4add76 cleanup/uncommit.",
            "This report does not justify native RMG density scalars, retries, new gates, or final-map delta tuning.",
        ],
        "remaining_blockers": [
            "Name candidate vtable scorer/create implementations and descriptor type semantics from source-backed data.",
            "Recover a generation path that actually reaches 0x4add76 cleanup/uncommit.",
            "Continue linking selected-created object records into wrapper/placement consumers across 0x4aa1db and 0x4adef7.",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log", type=Path, default=DEFAULT_LOG)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    if not args.log.exists():
        raise SystemExit(f"missing trace log: {args.log}")

    summary = build_summary(args.log, args.ledger)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_4A9F1C_SELECTED_CREATE_SUMMARY "
        f"status={summary['status']} complete_cycles={summary['complete_selected_create_cycles']} out={args.out}"
    )
    return 1 if summary["status"].startswith("failed") else 0


if __name__ == "__main__":
    raise SystemExit(main())
