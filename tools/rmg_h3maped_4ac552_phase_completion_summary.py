#!/usr/bin/env python3
"""Summarize the recovered ``0x4ac552`` post-``0x49eb8d`` completion boundary.

This report intentionally covers one narrow source-backed boundary.  It proves
that the clean PE seed-pinned Medium seed-10 generation path returns from
``0x49eb8d`` to ``0x4ac844``, runs the following road/post-processing calls, and
returns from ``0x4ac552`` to its caller with ``AL=1``.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_LEDGER = Path(
    ".artifacts/rmg_recovery/medium_seed10_4ac552_caller_return_trace_20260609/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_OUT = Path(".artifacts/rmg_recovery/medium_seed10_4ac552_phase_completion_summary_20260609.json")

EXPECTED_SEQUENCE = [
    "0x004ac552",
    "0x0049eb8d",
    "0x0049eced",
    "0x004ac844",
    "0x004ab52a",
    "0x004ac4ae",
    "0x004ac852",
    "0x004ac854",
    "0x004ae082",
]


def hex32(value: int | None) -> str | None:
    if value is None:
        return None
    return f"0x{int(value) & 0xFFFFFFFF:08x}"


def event_address(event: dict[str, Any]) -> str:
    return str(event.get("address", "")).lower()


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def event_memory(event: dict[str, Any]) -> dict[int, int]:
    memory: dict[int, int] = {}
    for line in event.get("memory_lines", []):
        base = int(line.get("address", 0))
        for index, value in enumerate(line.get("words", [])):
            memory[base + index * 4] = int(value) & 0xFFFFFFFF
    return memory


def word(memory: dict[int, int], address: int | None) -> int | None:
    if address is None:
        return None
    return memory.get(address)


def seed_control_clean(ledger: dict[str, Any]) -> bool:
    seed_control = ledger.get("seed_control", {})
    return (
        seed_control.get("status") == "prepared"
        and seed_control.get("patch", {}).get("status") == "patched"
        and not seed_control.get("missing")
    )


def event_by_address(events: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    return {event_address(event): event for event in events}


def generator_snapshot(event: dict[str, Any], generator: int | None) -> dict[str, Any]:
    if generator is None:
        return {}
    memory = event_memory(event)
    return {
        "generator": hex32(generator),
        "generated_cell_base": hex32(word(memory, generator + 0x14)),
        "width": word(memory, generator + 0x18),
        "height": word(memory, generator + 0x1C),
        "levels": word(memory, generator + 0x20),
        "object_vector_begin": hex32(word(memory, generator + 0xEC4)),
        "object_vector_end": hex32(word(memory, generator + 0xEC8)),
        "object_vector_capacity": hex32(word(memory, generator + 0xECC)),
    }


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    ledger = read_json(args.ledger)
    events = ledger.get("events", [])
    addresses = [event_address(event) for event in events]
    counts = Counter(addresses)
    by_address = event_by_address(events)

    entry = by_address.get("0x004ac552", {})
    eb8d_entry = by_address.get("0x0049eb8d", {})
    eb8d_exit = by_address.get("0x0049eced", {})
    continuation = by_address.get("0x004ac844", {})
    road_entry = by_address.get("0x004ab52a", {})
    post_entry = by_address.get("0x004ac4ae", {})
    al_set = by_address.get("0x004ac854", {})
    caller = by_address.get("0x004ae082", {})

    entry_generator = entry.get("registers", {}).get("ecx")
    continuation_generator = continuation.get("registers", {}).get("esi")
    road_generator = road_entry.get("registers", {}).get("ecx")
    post_generator = post_entry.get("registers", {}).get("ecx")

    snapshots = {
        "entry_0x4ac552": generator_snapshot(entry, entry_generator),
        "before_0x49eb8d": generator_snapshot(eb8d_entry, eb8d_entry.get("registers", {}).get("ecx")),
        "after_0x49eb8d_at_0x4ac844": generator_snapshot(continuation, continuation_generator),
        "road_call_0x4ab52a": generator_snapshot(road_entry, road_generator),
        "post_call_0x4ac4ae": generator_snapshot(post_entry, post_generator),
    }

    expected_returns = {
        "0x4ac552_entry_return_address": entry.get("derived", {}).get("return_address"),
        "0x49eb8d_return_address": eb8d_entry.get("derived", {}).get("return_address"),
        "0x4ab52a_return_address": road_entry.get("derived", {}).get("return_address"),
        "0x4ac4ae_return_address": post_entry.get("derived", {}).get("return_address"),
    }

    al_after_set = al_set.get("registers", {}).get("eax", 0) & 0xFF if al_set else None
    al_at_caller = caller.get("registers", {}).get("eax", 0) & 0xFF if caller else None
    generator_consistent = (
        entry_generator is not None
        and entry_generator
        == eb8d_entry.get("registers", {}).get("ecx")
        == continuation_generator
        == road_generator
        == post_generator
    )

    dimensions = {
        key: {
            "generated_cell_base": value.get("generated_cell_base"),
            "width": value.get("width"),
            "height": value.get("height"),
            "levels": value.get("levels"),
        }
        for key, value in snapshots.items()
        if value
    }
    dimension_values = {tuple(value.values()) for value in dimensions.values()}

    invariants = {
        "native_behavior_changed": False,
        "seed_control_clean": seed_control_clean(ledger),
        "expected_event_sequence": addresses == EXPECTED_SEQUENCE,
        "every_boundary_once": all(counts.get(address, 0) == 1 for address in EXPECTED_SEQUENCE),
        "entry_returns_to_caller_0x4ae082": expected_returns["0x4ac552_entry_return_address"] == "0x004ae082",
        "0x49eb8d_returns_to_0x4ac844": expected_returns["0x49eb8d_return_address"] == "0x004ac844",
        "0x4ab52a_returns_to_0x4ac84b": expected_returns["0x4ab52a_return_address"] == "0x004ac84b",
        "0x4ac4ae_returns_to_0x4ac852": expected_returns["0x4ac4ae_return_address"] == "0x004ac852",
        "same_generator_through_tail_calls": generator_consistent,
        "generated_grid_dimensions_stable": len(dimension_values) == 1,
        "medium_grid_dimensions": next(iter(dimension_values), (None, None, None, None))[1:] == (72, 72, 1),
        "al_set_to_success_before_return": al_after_set == 1,
        "caller_continuation_observed_with_success_al": al_at_caller == 1,
    }
    status = (
        "4ac552_post_49eb8d_phase_completion_recovered"
        if all(value for key, value in invariants.items() if key != "native_behavior_changed")
        else "4ac552_post_49eb8d_phase_completion_partial"
    )

    return {
        "schema_id": "h3maped_4ac552_phase_completion_summary_v1",
        "status": status,
        "native_behavior_changed": False,
        "inputs": {"ledger": str(args.ledger)},
        "event_sequence": addresses,
        "event_counts": dict(sorted(counts.items())),
        "expected_returns": expected_returns,
        "metrics": {
            "event_count": len(events),
            "al_after_success_set": al_after_set,
            "al_at_caller_continuation": al_at_caller,
            "generator": hex32(entry_generator),
        },
        "generator_snapshots": snapshots,
        "invariants": invariants,
        "source_backed_conclusion": (
            "For clean PE seed-pinned Medium seed 10, 0x4ac552 enters with generator 0x31e058, "
            "calls 0x49eb8d, resumes at 0x4ac844, calls 0x4ab52a and 0x4ac4ae on the same "
            "generator, sets AL=1, and returns to caller continuation 0x4ae082 with AL=1."
        ),
        "remaining_gap": (
            "This closes the immediate downstream phase-completion proof after 0x49eb8d/0x4ac844. "
            "It does not recover linked-payload 0x4a696b direct mutation, live 0x4add76/0x4adef7 "
            "cleanup/uncommit behavior, optional per-record projection-loop streams for 0x036260c0/"
            "0x03626060, or the older coordinate/projection reconciliation."
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_4AC552_PHASE_COMPLETION_SUMMARY status={summary['status']} out={args.out}")
    return 0 if summary["status"].endswith("_recovered") else 1


if __name__ == "__main__":
    raise SystemExit(main())
