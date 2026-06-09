#!/usr/bin/env python3
"""Summarize the live H3MapEd ``0x4a7312`` fallback endpoint commit path.

This is a narrow recovery checkpoint for the path that is actually observed
after sampled ``0x4a696b`` calls exit before their direct mutation block.  It
does not infer native RMG behavior and it does not claim after-state parity.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from rmg_h3maped_recovery_trace import parse_winedbg_log


DEFAULT_LOG = Path(
    ".artifacts/rmg_recovery/direct_generation_4a696b_cell_mutation_trace_20260608/"
    "winedbg_interactive_trace.log"
)
DEFAULT_STATIC_DUMP = Path(
    ".artifacts/rmg_recovery/ghidra_4a7312_policy_dump/"
    "target_004a7312_FUN_004a7312.txt"
)
DEFAULT_OUT = Path(".artifacts/rmg_recovery/4a7312_endpoint_commit_summary_20260609.json")

ENTRY = "0x004a7312"
HELPER_GATE = "0x004a73d0"
CANDIDATE_APPEND = "0x004a73e0"
RNG = "0x004a741b"
VTABLE_COMMIT = "0x004a7447"
CLEANUP = "0x004a7453"


def normalize_address(value: Any) -> str:
    if isinstance(value, str):
        return f"0x{int(value, 0) & 0xFFFFFFFF:08x}"
    return f"0x{int(value) & 0xFFFFFFFF:08x}"


def hex32(value: int | None) -> str | None:
    if value is None:
        return None
    return f"0x{value & 0xFFFFFFFF:08x}"


def event_address(event: dict[str, Any]) -> str:
    return normalize_address(event.get("address", "0"))


def memory_lines(event: dict[str, Any]) -> dict[int, list[int]]:
    return {
        int(line.get("address", -1)): [int(word) & 0xFFFFFFFF for word in line.get("words", [])]
        for line in event.get("memory_lines", [])
    }


def words_at(event: dict[str, Any], address: int | None, max_words: int = 16) -> list[int]:
    if not isinstance(address, int):
        return []
    by_address = memory_lines(event)
    out: list[int] = []
    cursor = address
    while cursor in by_address and len(out) < max_words:
        line_words = by_address[cursor]
        take = min(len(line_words), max_words - len(out))
        out.extend(line_words[:take])
        cursor += len(line_words) * 4
    return out


def word(words: list[int], index: int) -> int | None:
    if index < 0 or index >= len(words):
        return None
    return words[index]


def stack_words(event: dict[str, Any], max_words: int = 16) -> list[int]:
    registers = event.get("registers", {})
    return words_at(event, registers.get("esp"), max_words)


def summarize_entry(event: dict[str, Any], index: int) -> dict[str, Any]:
    stack = stack_words(event, 12)
    registers = event.get("registers", {})
    return {
        "event_index": index,
        "return_address": hex32(word(stack, 0)),
        "object_record_arg1": hex32(word(stack, 1)),
        "source_relation_record_arg2": hex32(word(stack, 2)),
        "generator_context_ecx": hex32(registers.get("ecx")),
        "control_record_esi": hex32(registers.get("esi")),
        "stack_words_prefix": [hex32(value) for value in stack],
    }


def summarize_commit(event: dict[str, Any], index: int) -> dict[str, Any]:
    stack = stack_words(event, 12)
    registers = event.get("registers", {})
    selected = {
        "x": word(stack, 1),
        "y": word(stack, 2),
        "level": word(stack, 3),
    }
    candidate_tail = words_at(event, registers.get("esi"), 12)
    return {
        "event_index": index,
        "object_record_arg": hex32(word(stack, 0)),
        "selected_coordinate": selected,
        "source_relation_record_context": hex32(word(stack, 4)),
        "control_record_context": hex32(word(stack, 5)),
        "generator_context_ecx": hex32(registers.get("ecx")),
        "generator_vtable_edx": hex32(registers.get("edx")),
        "call_site": VTABLE_COMMIT,
        "called_slot": "generator_context_vtable+0x04",
        "stack_words_prefix": [hex32(value) for value in stack],
        "candidate_record_stream_after_selected_prefix": [hex32(value) for value in candidate_tail],
    }


def static_contract(static_text: str) -> dict[str, Any]:
    required_sites = {
        "entry": "004a7312:",
        "generated_cell_word20_read": "004a73b2: MOV EAX,dword ptr [EAX + EDX*0x1 + 0x20]",
        "byte3_relation_compare": "004a73bc: CMP EAX,dword ptr [EBP + 0xc]",
        "helper_49aa93_gate": "004a73d0: CALL 0x0049aa93",
        "candidate_vector_append_4ae1fd": "004a73e0: CALL 0x004ae1fd",
        "rng_call": "004a741b: CALL 0x004e7276",
        "selected_candidate_to_vtable_slot4": "004a7447: CALL dword ptr [EDX + 0x4]",
        "local_candidate_vector_cleanup": "004a7453: CALL 0x0042c92d",
        "ret_8": "004a7468: RET 0x8",
    }
    return {
        "required_static_sites_present": {
            name: needle in static_text for name, needle in required_sites.items()
        },
        "recovered_contract": [
            "ECX is the generator/context pointer and stack +0x08 is the object record argument.",
            "Stack +0x0c is the source/relation record used to derive the scan rectangle and relation byte.",
            "The function scans generated cells using the generator grid fields and reads GeneratedCell+0x20.",
            "A cell is considered for this endpoint only when the extracted byte3 relation/class matches the source/relation record value.",
            "Candidate cells then pass through helper 0x49aa93 and are appended as 12-byte coordinate records through 0x4ae1fd.",
            "If the local candidate vector is non-empty, the selected candidate is chosen with 0x4e7276 and committed through generator/context vtable slot +0x04.",
            "The vtable commit receives the original object record and selected coordinate triple; the local candidate vector is destroyed by 0x42c92d before return.",
        ],
    }


def summarize(log_path: Path, static_dump: Path) -> dict[str, Any]:
    ledger = parse_winedbg_log(log_path)
    events = ledger.get("events", [])
    entries = [
        summarize_entry(event, index)
        for index, event in enumerate(events)
        if event_address(event) == ENTRY
    ]
    commits = [
        summarize_commit(event, index)
        for index, event in enumerate(events)
        if event_address(event) == VTABLE_COMMIT
    ]
    address_counts: dict[str, int] = {}
    for event in events:
        address = event_address(event)
        address_counts[address] = address_counts.get(address, 0) + 1

    static = static_contract(static_dump.read_text(encoding="utf-8"))
    entry_objects = {entry["object_record_arg1"] for entry in entries}
    commit_objects = {commit["object_record_arg"] for commit in commits}
    entry_generators = {entry["generator_context_ecx"] for entry in entries}
    commit_generators = {commit["generator_context_ecx"] for commit in commits}
    static_sites = static["required_static_sites_present"]

    invariants = {
        "trace_has_events": bool(events),
        "hit_4a7312_entries": len(entries) == 2,
        "hit_two_vtable_commits": len(commits) == 2,
        "committed_objects_match_entry_objects": commit_objects.issubset(entry_objects),
        "commit_generator_matches_entry_generator": commit_generators.issubset(entry_generators),
        "all_commits_have_coordinate_triples": all(
            all(commit["selected_coordinate"][key] is not None for key in ("x", "y", "level"))
            for commit in commits
        ),
        "all_static_contract_sites_present": all(static_sites.values()),
        "no_native_behavior_change": True,
    }

    status = (
        "partial_live_recovery_4a7312_endpoint_commit_contract"
        if all(invariants.values())
        else "partial_live_recovery_4a7312_endpoint_commit_incomplete"
    )
    return {
        "schema_id": "h3maped_4a7312_endpoint_commit_summary_v1",
        "status": status,
        "log": str(log_path),
        "static_dump": str(static_dump),
        "event_count": ledger.get("event_count", len(events)),
        "address_counts": address_counts,
        "entries": entries,
        "vtable_commits": commits,
        "static_contract": static,
        "invariants": invariants,
        "source_backed_conclusion": (
            "The observed fallback endpoint path enters 0x4a7312 twice and commits two selected "
            "object records through the generator/context vtable slot +0x04. Static recovery shows "
            "the endpoint builds a 12-byte coordinate candidate vector from GeneratedCell+0x20 byte3 "
            "relation/class matches gated by 0x49aa93, selects one candidate with 0x4e7276, and passes "
            "the original object record plus selected coordinate triple to the vtable commit."
        ),
        "remaining_gap": (
            "This artifact recovers the live endpoint selection and commit call contract. The target-cell "
            "and object-vector after-state for these same two sampled commits is covered separately by "
            ".artifacts/rmg_recovery/direct_endpoint_afterstate_dynamic_summary_20260608.json. Full "
            "end-to-end recovery still needs the unreached 0x4a696b source/relation-match/direct-mutation "
            "path or a source-backed unreachability proof for the target mode, plus live cleanup/uncommit "
            "behavior if 0x4add76/0x4adef7 is ever reached."
        ),
        "native_behavior_changed": False,
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log", type=Path, default=DEFAULT_LOG)
    parser.add_argument("--static-dump", type=Path, default=DEFAULT_STATIC_DUMP)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args.log, args.static_dump)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    passed = all(summary["invariants"].values())
    print(
        "RMG_H3MAPED_4A7312_ENDPOINT_COMMIT_SUMMARY "
        f"status={'pass' if passed else 'partial'} "
        f"commits={len(summary['vtable_commits'])} "
        f"out={args.out}"
    )
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
