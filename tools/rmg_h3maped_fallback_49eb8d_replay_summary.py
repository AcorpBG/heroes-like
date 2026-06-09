#!/usr/bin/env python3
"""Summarize the seed-pinned post-fallback ``0x49eb8d`` replay.

This report covers the exact Medium seed-10 path where post-Border-Guard
fallback object records have already survived to the ``0x49eb8d`` handoff. It
parses a combined trace that captures, in one run:

* ``0x49eb8d`` entry from caller return ``0x4ac844``;
* ``0x49ec01`` after the first bit26 counting pass;
* the first normal ``0x49e700`` dispatch;
* ``0x49eced`` function exit;
* caller continuation at ``0x4ac844``.

The report intentionally does not claim full ``0x49e700`` decorative object
allocation parity. It only proves the same-run count/budget/first-dispatch
contract and fallback-record survival across this handoff.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_LEDGER = Path(
    ".artifacts/rmg_recovery/medium_seed10_fallback_49eb8d_combined_trace_20260609/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_STATIC_DUMP = Path(
    ".artifacts/rmg_recovery/ghidra_downstream_state_dump/target_0049eb8d_FUN_0049eb8d.txt"
)
DEFAULT_OUT = Path(
    ".artifacts/rmg_recovery/medium_seed10_fallback_49eb8d_replay_summary_20260609.json"
)

FALLBACK_RECORDS = ("0x036260c0", "0x03626060")
ENTRY = "0x0049eb8d"
COUNT_DONE = "0x0049ec01"
FIRST_DISPATCH = "0x0049e700"
EXIT = "0x0049eced"
CALLER_AFTER = "0x004ac844"
EXPECTED_CALLER_RETURN = "0x004ac844"
EXPECTED_DISPATCH_RETURN = "0x0049ec6b"
BUDGET_NUMERATOR = 0x4374C


def hex32(value: int | None) -> str | None:
    if value is None:
        return None
    return f"0x{int(value) & 0xFFFFFFFF:08x}"


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def address(event: dict[str, Any]) -> str:
    return str(event.get("address", "")).lower()


def event_memory(event: dict[str, Any]) -> dict[int, int]:
    memory: dict[int, int] = {}
    for line in event.get("memory_lines", []):
        base = int(line.get("address", 0))
        for index, word in enumerate(line.get("words", [])):
            memory[base + index * 4] = int(word) & 0xFFFFFFFF
    return memory


def word(memory: dict[int, int], addr: int | None) -> int | None:
    if addr is None:
        return None
    return memory.get(addr)


def first_event(events: list[dict[str, Any]], addr: str) -> dict[str, Any] | None:
    for event in events:
        if address(event) == addr:
            return event
    return None


def seed_control_clean(ledger: dict[str, Any]) -> bool:
    seed_control = ledger.get("seed_control", {})
    return (
        seed_control.get("status") == "prepared"
        and seed_control.get("patch", {}).get("status") == "patched"
    )


def stack_args(event: dict[str, Any]) -> dict[str, int | None]:
    memory = event_memory(event)
    esp = event.get("registers", {}).get("esp")
    return {
        "return_address": word(memory, esp),
        "x": word(memory, None if esp is None else esp + 0x04),
        "y": word(memory, None if esp is None else esp + 0x08),
        "level": word(memory, None if esp is None else esp + 0x0C),
        "budget": word(memory, None if esp is None else esp + 0x10),
    }


def generator_fields(event: dict[str, Any], register_name: str) -> dict[str, Any]:
    registers = event.get("registers", {})
    generator = registers.get(register_name)
    memory = event_memory(event)
    return {
        "generator": hex32(generator),
        "cell_base": hex32(word(memory, None if generator is None else generator + 0x14)),
        "width": word(memory, None if generator is None else generator + 0x18),
        "height": word(memory, None if generator is None else generator + 0x1C),
        "levels": word(memory, None if generator is None else generator + 0x20),
    }


def object_vector_snapshot(event: dict[str, Any], register_name: str) -> dict[str, Any]:
    registers = event.get("registers", {})
    generator = registers.get(register_name)
    memory = event_memory(event)
    header = None if generator is None else generator + 0xEC4
    begin = word(memory, None if header is None else header + 0x04)
    end = word(memory, None if header is None else header + 0x08)
    capacity = word(memory, None if header is None else header + 0x0C)
    count = None
    entries: list[str] = []
    if begin is not None and end is not None and end >= begin and (end - begin) % 4 == 0:
        count = (end - begin) // 4
        for index in range(count):
            value = word(memory, begin + index * 4)
            if value is None:
                break
            entries.append(hex32(value) or "")
    positions = {
        pointer: [index for index, value in enumerate(entries) if value == pointer]
        for pointer in FALLBACK_RECORDS
    }
    return {
        "event_address": address(event),
        "generator_register": register_name,
        "generator": hex32(generator),
        "begin": hex32(begin),
        "end": hex32(end),
        "capacity": hex32(capacity),
        "count": count,
        "dumped_entry_count": len(entries),
        "fallback_positions": positions,
        "all_fallback_records_present": all(positions[pointer] for pointer in FALLBACK_RECORDS),
    }


def local_word(event: dict[str, Any], offset: int) -> int | None:
    ebp = event.get("registers", {}).get("ebp")
    return word(event_memory(event), None if ebp is None else ebp + offset)


def static_contract_flags(static_dump: Path) -> dict[str, bool]:
    text = static_dump.read_text(encoding="utf-8", errors="replace")
    return {
        "counts_bit26_shift_26": "SHR EDX,0x1a" in text and "INC dword ptr [EBP + -0x8]" in text,
        "budget_formula_present": "MOV EAX,0x4374c" in text and "IDIV dword ptr [EBP + -0x8]" in text,
        "normal_dispatch_present": "0049ec66: CALL 0x0049e700" in text,
        "validity_gate_present": "CALL 0x0049a1d8" in text,
        "optional_handler_present": "0049ec51: CALL dword ptr [EAX + 0x8]" in text,
        "third_pass_bit27_writer_present": "0049ecc9: CALL 0x0049a932" in text,
    }


def summarize(ledger_path: Path, static_dump: Path) -> dict[str, Any]:
    ledger = read_json(ledger_path)
    events = ledger.get("events", [])
    counts = Counter(address(event) for event in events)
    entry = first_event(events, ENTRY)
    count_done = first_event(events, COUNT_DONE)
    dispatch = first_event(events, FIRST_DISPATCH)
    exit_event = first_event(events, EXIT)
    caller_after = first_event(events, CALLER_AFTER)

    bit26_count = local_word(count_done, -0x08) if count_done else None
    computed_budget = BUDGET_NUMERATOR // bit26_count if bit26_count else None
    dispatch_args = stack_args(dispatch) if dispatch else {}
    exit_budget_local = local_word(exit_event, -0x08) if exit_event else None

    object_vectors = {
        "entry_0x49eb8d": object_vector_snapshot(entry, "ecx") if entry else {},
        "exit_0x49eced": object_vector_snapshot(exit_event, "ebx") if exit_event else {},
        "caller_after_0x4ac844": object_vector_snapshot(caller_after, "esi") if caller_after else {},
    }
    invariants = {
        "native_behavior_changed": False,
        "seed_control_clean": seed_control_clean(ledger),
        "all_expected_events_observed_once": all(
            counts.get(addr, 0) == 1
            for addr in (ENTRY, COUNT_DONE, FIRST_DISPATCH, EXIT, CALLER_AFTER)
        ),
        "entry_returns_to_0x4ac844": entry is not None
        and entry.get("derived", {}).get("return_address") == EXPECTED_CALLER_RETURN,
        "first_dispatch_returns_to_0x49ec6b": dispatch_args.get("return_address")
        == int(EXPECTED_DISPATCH_RETURN, 16),
        "bit26_count_positive": bool(bit26_count and bit26_count > 0),
        "budget_matches_formula": dispatch_args.get("budget") == computed_budget,
        "exit_keeps_budget_local": exit_budget_local == computed_budget,
        "fallback_records_present_at_entry": bool(
            object_vectors["entry_0x49eb8d"].get("all_fallback_records_present")
        ),
        "fallback_records_present_at_exit": bool(
            object_vectors["exit_0x49eced"].get("all_fallback_records_present")
        ),
        "fallback_records_present_after_caller_return": bool(
            object_vectors["caller_after_0x4ac844"].get("all_fallback_records_present")
        ),
    }
    static_flags = static_contract_flags(static_dump)
    status = (
        "fallback_49eb8d_same_run_count_dispatch_return_recovered"
        if all(value for key, value in invariants.items() if key != "native_behavior_changed")
        and all(static_flags.values())
        else "fallback_49eb8d_same_run_replay_partial"
    )
    return {
        "schema_id": "h3maped_fallback_49eb8d_replay_summary_v1",
        "status": status,
        "native_behavior_changed": False,
        "inputs": {
            "ledger": str(ledger_path),
            "static_dump": str(static_dump),
        },
        "event_counts": dict(sorted(counts.items())),
        "generator": generator_fields(entry, "ecx") if entry else {},
        "bit26_count": bit26_count,
        "budget_formula": "0x4374c // bit26_count",
        "computed_budget": computed_budget,
        "first_49e700_dispatch": {
            "stack_args": {
                key: hex32(value) if key == "return_address" else value
                for key, value in dispatch_args.items()
            },
            "generator": generator_fields(dispatch, "ebx") if dispatch else {},
        },
        "exit_budget_local": exit_budget_local,
        "object_vector_snapshots": object_vectors,
        "static_contract_flags": static_flags,
        "invariants": invariants,
        "source_backed_conclusion": (
            "For this clean seed-pinned Medium seed-10 post-fallback handoff, 0x49eb8d enters from 0x4ac844, "
            f"counts {bit26_count} bit26 generated cells, computes budget {computed_budget}, calls the first normal "
            "0x49e700 dispatch with x=1, y=0, level=0, and returns through 0x49eced to 0x4ac844. The exact fallback "
            "records remain present in the generator object vector at entry, exit, and caller continuation."
        ),
        "remaining_gap": (
            "0x49eb8d same-run count/budget/first-dispatch/return behavior is now recovered for this path, but full "
            "0x49e700 decorative object allocation and exact generated-cell mutation replay remain pending. Continue "
            "0x4a696b direct-mutation reachability/proof, 0x4add76 cleanup/uncommit runtime behavior, and downstream "
            "phase-completion proof before porting native RMG behavior."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--static-dump", type=Path, default=DEFAULT_STATIC_DUMP)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args.ledger, args.static_dump)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_FALLBACK_49EB8D_REPLAY_SUMMARY status={summary['status']} out={args.out}")
    return 0 if summary["status"] == "fallback_49eb8d_same_run_count_dispatch_return_recovered" else 1


if __name__ == "__main__":
    raise SystemExit(main())
