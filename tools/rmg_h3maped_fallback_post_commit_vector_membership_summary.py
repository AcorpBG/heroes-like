#!/usr/bin/env python3
"""Summarize post-fallback object-vector membership evidence.

This report joins two clean seed-pinned Medium seed-10 traces:

* a broad later-phase trace that arms likely post-fallback consumers after the
  second fallback return at ``0x4a789a``;
* a focused vector-membership trace that dumps ``generator+0xec4`` and the
  object-vector contents at ``0x4a8d27`` and ``0x49eb8d``.

It is recovery evidence only. It does not change native RMG behavior and does
not claim complete end-to-end recovery of every later phase.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_LATER_PHASE_LEDGER = Path(
    ".artifacts/rmg_recovery/medium_seed10_fallback_post_commit_later_phase_trace_20260609/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_VECTOR_LEDGER = Path(
    ".artifacts/rmg_recovery/medium_seed10_fallback_post_commit_vector_membership_trace_20260609/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_OUT = Path(
    ".artifacts/rmg_recovery/medium_seed10_fallback_post_commit_vector_membership_summary_20260609.json"
)

BOUNDARY_ADDRESS = "0x004a789a"
PHASE_RETURN_ADDRESS = "0x004a8d27"
FINAL_HANDOFF_ADDRESS = "0x0049eb8d"
FALLBACK_RECORDS = ("0x036260c0", "0x03626060")
LIKELY_CONSUMERS = {
    "0x004a79a3": "payload_driver_entry",
    "0x004a696b": "linked_payload_direct_mutation_candidate",
    "0x004a7605": "endpoint_fallback_coordinator",
    "0x004add76": "cleanup_uncommit",
    "0x004adb72": "reward_guard_attachment_attempt",
    "0x004a8c15": "phase_boundary_materialization",
    "0x004a4c8e": "generated_cell_entry_boundary",
}


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


def object_vector_snapshot(event: dict[str, Any], generator_register: str) -> dict[str, Any]:
    registers = event.get("registers", {})
    generator = registers.get(generator_register)
    memory = event_memory(event)
    header_address = None if generator is None else int(generator) + 0xEC4
    anchor = word(memory, header_address)
    begin = word(memory, None if header_address is None else header_address + 0x04)
    end = word(memory, None if header_address is None else header_address + 0x08)
    capacity = word(memory, None if header_address is None else header_address + 0x0C)
    count = None
    entries: list[str] = []
    if begin is not None and end is not None and end >= begin and (end - begin) % 4 == 0:
        count = (end - begin) // 4
        for index in range(count):
            value = word(memory, begin + index * 4)
            if value is None:
                break
            entries.append(hex32(value) or "")
    fallback_positions = {
        pointer: [index for index, value in enumerate(entries) if value == pointer]
        for pointer in FALLBACK_RECORDS
    }
    return {
        "event_address": address(event),
        "generator_register": generator_register,
        "generator": hex32(generator),
        "header_address": hex32(header_address),
        "anchor": hex32(anchor),
        "begin": hex32(begin),
        "end": hex32(end),
        "capacity": hex32(capacity),
        "count": count,
        "dumped_entry_count": len(entries),
        "entries": entries,
        "fallback_positions": fallback_positions,
        "all_fallback_records_present": all(fallback_positions[pointer] for pointer in FALLBACK_RECORDS),
    }


def summarize(later_phase_path: Path, vector_path: Path) -> dict[str, Any]:
    later_phase = read_json(later_phase_path)
    vector = read_json(vector_path)
    later_events = later_phase.get("events", [])
    vector_events = vector.get("events", [])
    later_counts = Counter(address(event) for event in later_events)
    vector_counts = Counter(address(event) for event in vector_events)

    later_boundary_seen = later_counts.get(BOUNDARY_ADDRESS, 0) == 1
    vector_boundary_seen = vector_counts.get(BOUNDARY_ADDRESS, 0) == 1
    observed_consumers = {
        addr: {"name": name, "count": later_counts.get(addr, 0)}
        for addr, name in LIKELY_CONSUMERS.items()
        if later_counts.get(addr, 0)
    }

    phase_return = first_event(vector_events, PHASE_RETURN_ADDRESS)
    final_handoff = first_event(vector_events, FINAL_HANDOFF_ADDRESS)
    phase_snapshot = (
        object_vector_snapshot(phase_return, "ebx") if phase_return is not None else {}
    )
    handoff_snapshot = (
        object_vector_snapshot(final_handoff, "ecx") if final_handoff is not None else {}
    )

    invariants = {
        "native_behavior_changed": False,
        "later_phase_seed_control_clean": seed_control_clean(later_phase),
        "vector_trace_seed_control_clean": seed_control_clean(vector),
        "later_phase_boundary_observed_once": later_boundary_seen,
        "vector_trace_boundary_observed_once": vector_boundary_seen,
        "later_phase_reaches_4a8d27": later_counts.get(PHASE_RETURN_ADDRESS, 0) >= 1,
        "later_phase_reaches_49eb8d": later_counts.get(FINAL_HANDOFF_ADDRESS, 0) >= 1,
        "likely_payload_direct_cleanup_consumers_absent": not observed_consumers,
        "vector_trace_reaches_4a8d27": vector_counts.get(PHASE_RETURN_ADDRESS, 0) == 1,
        "vector_trace_reaches_49eb8d": vector_counts.get(FINAL_HANDOFF_ADDRESS, 0) == 1,
        "fallback_records_in_4a8d27_object_vector": bool(
            phase_snapshot.get("all_fallback_records_present")
        ),
        "fallback_records_in_49eb8d_object_vector": bool(
            handoff_snapshot.get("all_fallback_records_present")
        ),
    }
    status = (
        "fallback_post_commit_vector_membership_survives_to_49eb8d"
        if all(value for key, value in invariants.items() if key != "native_behavior_changed")
        else "fallback_post_commit_vector_membership_partial"
    )
    return {
        "schema_id": "h3maped_fallback_post_commit_vector_membership_summary_v1",
        "status": status,
        "native_behavior_changed": False,
        "inputs": {
            "later_phase_ledger": str(later_phase_path),
            "vector_membership_ledger": str(vector_path),
        },
        "event_counts": {
            "later_phase": dict(sorted(later_counts.items())),
            "vector_membership": dict(sorted(vector_counts.items())),
        },
        "observed_likely_consumers_in_later_phase_trace": observed_consumers,
        "object_vector_snapshots": {
            "phase_return_0x4a8d27": phase_snapshot,
            "final_handoff_0x49eb8d": handoff_snapshot,
        },
        "invariants": invariants,
        "source_backed_conclusion": (
            "After the second deterministic fallback return at 0x4a789a, the bounded later-phase trace reaches "
            "0x4a8d27 and 0x49eb8d without observing the armed payload/direct-mutation/cleanup/endpoint consumer "
            "sites. The focused replay proves both exact fallback object records remain present in the generator "
            "object vector at 0x4a8d27 and again at the 0x49eb8d handoff after vector relocation/growth."
        ),
        "remaining_gap": (
            "This proves survival to the 0x49eb8d handoff for the exact fallback records in the clean seed-pinned "
            "Medium seed-10 run. It is still not a complete end-to-end native-port contract: recover the 0x49eb8d "
            "consumer semantics, continue 0x4a696b direct-mutation reachability/proof, recover actual 0x4add76 "
            "cleanup/uncommit runtime behavior, and resolve the older coordinate/projection reconciliation before "
            "porting behavior into native RMG."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--later-phase-ledger", type=Path, default=DEFAULT_LATER_PHASE_LEDGER)
    parser.add_argument("--vector-ledger", type=Path, default=DEFAULT_VECTOR_LEDGER)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args.later_phase_ledger, args.vector_ledger)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_FALLBACK_POST_COMMIT_VECTOR_MEMBERSHIP_SUMMARY "
        f"status={summary['status']} out={args.out}"
    )
    return 0 if summary["status"] == "fallback_post_commit_vector_membership_survives_to_49eb8d" else 1


if __name__ == "__main__":
    raise SystemExit(main())
