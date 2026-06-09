#!/usr/bin/env python3
"""Summarize the first recovered ``0x49e700`` decorative dispatch boundary.

The report joins three clean PE seed-pinned Medium seed-10 traces:

* a high-volume candidate trace proving scorer and accepted-candidate append
  activity;
* a selection/commit trace proving RNG selection, object allocation, commit
  callback dispatch, and post-commit coordinate appends;
* a bounded return trace proving the same path can reach the ``0x49eb50``
  cleanup/return boundary.

This is a runtime boundary recovery report. It does not claim full generated
cell mutation parity for every decorative object emitted by ``0x49e700``.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_CANDIDATE_TRACE = Path(
    ".artifacts/rmg_recovery/medium_seed10_49e700_first_dispatch_trace_20260609/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_SELECTION_TRACE = Path(
    ".artifacts/rmg_recovery/medium_seed10_49e700_selection_commit_trace_20260609/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_RETURN_TRACE = Path(
    ".artifacts/rmg_recovery/medium_seed10_49e700_return_trace_20260609/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_STATIC_DUMP = Path(
    ".artifacts/rmg_recovery/ghidra_downstream_helper_dump/target_0049e700_FUN_0049e700.txt"
)
DEFAULT_OUT = Path(".artifacts/rmg_recovery/medium_seed10_49e700_first_dispatch_summary_20260609.json")

ENTRY = "0x0049e700"
SCORER_CALL = "0x0049e8eb"
ACCEPT_WEIGHT_APPEND = "0x0049e904"
ACCEPT_RECORD_APPEND = "0x0049e91f"
RNG_SELECT = "0x0049e9ad"
ALLOCATE_RECORD = "0x0049ea07"
COMMIT_CALLBACK = "0x0049ea25"
POST_COMMIT_COORD_APPEND = "0x0049eb01"
RETURN_BOUNDARY = "0x0049eb50"


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
        for index, value in enumerate(line.get("words", [])):
            memory[base + index * 4] = int(value) & 0xFFFFFFFF
    return memory


def word(memory: dict[int, int], addr: int | None) -> int | None:
    if addr is None:
        return None
    return memory.get(addr)


def first_event(events: list[dict[str, Any]], target: str) -> dict[str, Any] | None:
    for event in events:
        if address(event) == target:
            return event
    return None


def seed_control_clean(ledger: dict[str, Any]) -> bool:
    seed_control = ledger.get("seed_control", {})
    return (
        seed_control.get("status") == "prepared"
        and seed_control.get("patch", {}).get("status") == "patched"
    )


def event_counts(ledger: dict[str, Any]) -> dict[str, int]:
    return dict(sorted(Counter(address(event) for event in ledger.get("events", [])).items()))


def stack_args(event: dict[str, Any] | None) -> dict[str, int | str | None]:
    if event is None:
        return {}
    memory = event_memory(event)
    esp = event.get("registers", {}).get("esp")
    return {
        "return_address": hex32(word(memory, esp)),
        "x": word(memory, None if esp is None else esp + 0x04),
        "y": word(memory, None if esp is None else esp + 0x08),
        "level": word(memory, None if esp is None else esp + 0x0C),
        "budget": word(memory, None if esp is None else esp + 0x10),
    }


def local_vector(event: dict[str, Any] | None, start_offset: int) -> dict[str, Any]:
    if event is None:
        return {}
    memory = event_memory(event)
    ebp = event.get("registers", {}).get("ebp")
    if ebp is None:
        return {}
    begin = word(memory, ebp + start_offset + 0x04)
    end = word(memory, ebp + start_offset + 0x08)
    capacity = word(memory, ebp + start_offset + 0x0C)
    stride_count = None
    if begin is not None and end is not None and end >= begin:
        stride_count = end - begin
    return {
        "anchor": hex32(ebp + start_offset),
        "raw_words": [word(memory, ebp + start_offset + offset) for offset in range(0, 0x10, 4)],
        "begin": hex32(begin),
        "end": hex32(end),
        "capacity": hex32(capacity),
        "byte_span": stride_count,
    }


def static_flags(path: Path) -> dict[str, bool]:
    text = path.read_text(encoding="utf-8", errors="replace")
    return {
        "entry_initializes_coordinate_worklist": "0049e732: CALL 0x004ae20e" in text,
        "pops_coordinate_worklist": "0049e765: CALL 0x004ae23e" in text,
        "maps_generated_cell": "0049e78d: CALL 0x0049eb6d" in text,
        "calls_descriptor_mask": "0049e8d1: CALL 0x0041e951" in text,
        "calls_scorer": "0049e8eb: CALL 0x0049e1bf" in text,
        "appends_weight": "0049e904: CALL 0x0042d8d8" in text,
        "appends_candidate_record": "0049e91f: CALL 0x0040bb26" in text,
        "selects_with_rng": "0049e9ad: CALL 0x004e7276" in text,
        "allocates_object_record": "0049ea07: CALL 0x0049ba89" in text,
        "calls_commit_callback": "0049ea25: CALL dword ptr [EDX + 0x4]" in text,
        "appends_post_commit_coordinate": "0049eb01: CALL 0x004ae1fd" in text,
        "cleans_local_vectors": "0049eb57: CALL 0x0042c92d" in text,
    }


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    candidate = read_json(args.candidate_trace)
    selection = read_json(args.selection_trace)
    returned = read_json(args.return_trace)
    candidate_counts = event_counts(candidate)
    selection_counts = event_counts(selection)
    return_counts = event_counts(returned)
    return_events = returned.get("events", [])
    entry = first_event(return_events, ENTRY)
    first_scorer = first_event(return_events, SCORER_CALL)
    first_accept_weight = first_event(return_events, ACCEPT_WEIGHT_APPEND)
    first_accept_record = first_event(return_events, ACCEPT_RECORD_APPEND)
    first_rng = first_event(return_events, RNG_SELECT)
    first_allocate = first_event(return_events, ALLOCATE_RECORD)
    first_commit = first_event(return_events, COMMIT_CALLBACK)
    first_post_commit = first_event(return_events, POST_COMMIT_COORD_APPEND)
    return_boundary = first_event(return_events, RETURN_BOUNDARY)

    flags = static_flags(args.static_dump)
    invariants = {
        "native_behavior_changed": False,
        "seed_control_clean_for_all_traces": all(
            seed_control_clean(ledger) for ledger in (candidate, selection, returned)
        ),
        "candidate_trace_reaches_scorer": candidate_counts.get(SCORER_CALL, 0) > 0,
        "candidate_trace_reaches_accepted_candidate_appends": candidate_counts.get(ACCEPT_WEIGHT_APPEND, 0) > 0
        and candidate_counts.get(ACCEPT_RECORD_APPEND, 0) > 0,
        "selection_trace_reaches_rng_allocation_commit": selection_counts.get(RNG_SELECT, 0) > 0
        and selection_counts.get(ALLOCATE_RECORD, 0) > 0
        and selection_counts.get(COMMIT_CALLBACK, 0) > 0,
        "selection_trace_reaches_post_commit_coordinate_appends": selection_counts.get(
            POST_COMMIT_COORD_APPEND, 0
        )
        > 0,
        "return_trace_observes_ordered_boundary_once": all(
            return_counts.get(target, 0) == 1
            for target in (
                ENTRY,
                SCORER_CALL,
                ACCEPT_WEIGHT_APPEND,
                ACCEPT_RECORD_APPEND,
                RNG_SELECT,
                ALLOCATE_RECORD,
                COMMIT_CALLBACK,
                POST_COMMIT_COORD_APPEND,
                RETURN_BOUNDARY,
            )
        ),
        "return_trace_entry_returns_to_49ec6b": stack_args(entry).get("return_address") == "0x0049ec6b",
        "return_trace_reaches_cleanup_return_boundary": return_boundary is not None,
    }
    status = (
        "49e700_first_dispatch_selection_commit_return_boundary_recovered"
        if all(value for key, value in invariants.items() if key != "native_behavior_changed")
        and all(flags.values())
        else "49e700_first_dispatch_boundary_partial"
    )

    return {
        "schema_id": "h3maped_49e700_first_dispatch_summary_v1",
        "status": status,
        "native_behavior_changed": False,
        "inputs": {
            "candidate_trace": str(args.candidate_trace),
            "selection_trace": str(args.selection_trace),
            "return_trace": str(args.return_trace),
            "static_dump": str(args.static_dump),
        },
        "event_counts": {
            "candidate_trace": candidate_counts,
            "selection_trace": selection_counts,
            "return_trace": return_counts,
        },
        "first_dispatch": {
            "stack_args": stack_args(entry),
            "first_scorer_stack_args": stack_args(first_scorer),
            "first_commit_stack_args": stack_args(first_commit),
            "first_post_commit_stack_args": stack_args(first_post_commit),
            "local_vectors": {
                "accepted_weight_vector_at_rng": local_vector(first_rng, -0x44),
                "accepted_record_vector_at_rng": local_vector(first_rng, -0x58),
                "post_commit_coordinate_vector_at_return": local_vector(return_boundary, -0x58),
            },
            "sample_registers": {
                "scorer": first_scorer.get("registers", {}) if first_scorer else {},
                "accepted_weight_append": first_accept_weight.get("registers", {})
                if first_accept_weight
                else {},
                "accepted_record_append": first_accept_record.get("registers", {})
                if first_accept_record
                else {},
                "rng": first_rng.get("registers", {}) if first_rng else {},
                "allocate": first_allocate.get("registers", {}) if first_allocate else {},
                "commit_callback": first_commit.get("registers", {}) if first_commit else {},
                "post_commit_append": first_post_commit.get("registers", {})
                if first_post_commit
                else {},
                "return_boundary": return_boundary.get("registers", {}) if return_boundary else {},
            },
        },
        "static_contract_flags": flags,
        "invariants": invariants,
        "source_backed_conclusion": (
            "The first clean seed-pinned Medium 0x49e700 dispatch now has ordered runtime evidence for scorer calls, "
            "accepted candidate accumulation, RNG selection, object record allocation, vtable commit callback dispatch, "
            "post-commit coordinate appends, and cleanup/return boundary. This recovers the dispatch boundary but not "
            "the full generated-cell mutation set for every emitted decorative object."
        ),
        "remaining_gap": (
            "Recover exact generated-cell before/after mutation sets for the 0x49ea25 commit callback and 0x49eb01 "
            "post-commit coordinate appends across the full first 0x49e700 dispatch. Then prove downstream phase "
            "completion beyond 0x4ac844 before porting native RMG behavior."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate-trace", type=Path, default=DEFAULT_CANDIDATE_TRACE)
    parser.add_argument("--selection-trace", type=Path, default=DEFAULT_SELECTION_TRACE)
    parser.add_argument("--return-trace", type=Path, default=DEFAULT_RETURN_TRACE)
    parser.add_argument("--static-dump", type=Path, default=DEFAULT_STATIC_DUMP)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_49E700_FIRST_DISPATCH_SUMMARY status={summary['status']} out={args.out}")
    return 0 if summary["status"].endswith("_recovered") else 1


if __name__ == "__main__":
    raise SystemExit(main())
