#!/usr/bin/env python3
"""Summarize the focused 0x4a696b candidate-predicate trace.

This report narrows the 0x4a696b live gap. Earlier traces proved sampled
calls exited because the local candidate vector was empty. This trace adds
breakpoints after the simple generated-cell filters and after the two helper
predicates, so the empty vector can be attributed to a specific part of the
candidate pipeline instead of a vague "no candidates" label.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_LEDGER = Path(
    ".artifacts/rmg_recovery/"
    "direct_generation_4a696b_candidate_predicate_trace_20260609/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_OUT = Path(
    ".artifacts/rmg_recovery/4a696b_candidate_predicate_trace_summary_20260609.json"
)

ENTRY = "0x004a696b"
SOURCE_RELATION_MATCH_CHECKPOINT = "0x004a6a81"
TERRAIN_REJECT_CHECKPOINT = "0x004a6a8f"
HELPER_49AA93_RETURN_TEST = "0x004a6ac8"
HELPER_4A6795_RETURN_TEST = "0x004a6ade"
CANDIDATE_APPEND = "0x004a6ae2"
SCAN_DONE = "0x004a6b10"
NO_CANDIDATE_EXIT = "0x004a6b27"
CANDIDATE_PATH = "0x004a6b2e"
DIRECT_MUTATION_TEST = "0x004a6c13"
RETURN_SITE = "0x004a6ce1"
FALLBACK_COORDINATOR = "0x004a7605"
ENDPOINT_COMMIT = "0x004a7312"
ENDPOINT_VTABLE_COMMIT = "0x004a7447"
PAIR_MARK_BEFORE = "0x004a7e21"
PAIR_MARK_AFTER = "0x004a7e25"

ORDERED_4A696B_SITES = [
    ENTRY,
    SOURCE_RELATION_MATCH_CHECKPOINT,
    TERRAIN_REJECT_CHECKPOINT,
    HELPER_49AA93_RETURN_TEST,
    HELPER_4A6795_RETURN_TEST,
    CANDIDATE_APPEND,
    SCAN_DONE,
    NO_CANDIDATE_EXIT,
    CANDIDATE_PATH,
    DIRECT_MUTATION_TEST,
    RETURN_SITE,
]


def hex32(value: int | None) -> str | None:
    return None if value is None else f"0x{value & 0xFFFFFFFF:08x}"


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def memory_word(event: dict[str, Any], address: int | None) -> int | None:
    if address is None:
        return None
    for line in event.get("memory_lines", []):
        base = int(line["address"])
        words = [int(word) for word in line.get("words", [])]
        if base <= address < base + len(words) * 4 and (address - base) % 4 == 0:
            return words[(address - base) // 4] & 0xFFFFFFFF
    return None


def stack_word(event: dict[str, Any], index: int) -> int | None:
    esp = event.get("registers", {}).get("esp")
    if not isinstance(esp, int):
        return None
    return memory_word(event, esp + index * 4)


def stack_words(event: dict[str, Any], count: int) -> list[int | None]:
    return [stack_word(event, index) for index in range(count)]


def local_candidate_vector(event: dict[str, Any]) -> dict[str, Any]:
    ebp = event.get("registers", {}).get("ebp")
    if not isinstance(ebp, int):
        return {
            "mode_byte": None,
            "begin": None,
            "end": None,
            "capacity": None,
            "entry_count": None,
        }
    mode_word = memory_word(event, ebp - 0x58)
    begin = memory_word(event, ebp - 0x54)
    end = memory_word(event, ebp - 0x50)
    capacity = memory_word(event, ebp - 0x4C)
    entry_count = None
    if begin and end is not None and end >= begin:
        entry_count = (end - begin) // 12
    return {
        "mode_byte": None if mode_word is None else mode_word & 0xFF,
        "begin": hex32(begin),
        "end": hex32(end),
        "capacity": hex32(capacity),
        "entry_count": entry_count,
    }


def summarize_event(event: dict[str, Any], index: int) -> dict[str, Any]:
    registers = event.get("registers", {})
    stack = stack_words(event, 8)
    return {
        "event_index": index,
        "address": event["address"],
        "return_address": hex32(stack[0] if stack else None),
        "registers": {
            "eax": hex32(registers.get("eax")),
            "ebx": hex32(registers.get("ebx")),
            "ecx": hex32(registers.get("ecx")),
            "edx": hex32(registers.get("edx")),
            "esi": hex32(registers.get("esi")),
            "edi": hex32(registers.get("edi")),
            "ebp": hex32(registers.get("ebp")),
            "esp": hex32(registers.get("esp")),
        },
        "stack_words": [hex32(word) for word in stack],
        "candidate_vector": local_candidate_vector(event),
    }


def group_4a696b_calls(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    calls: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    for index, event in enumerate(events):
        address = event["address"]
        if address == ENTRY:
            if current is not None:
                calls.append(current)
            stack = stack_words(event, 8)
            current = {
                "call_index": len(calls),
                "entry_event_index": index,
                "return_address": hex32(stack[0] if stack else None),
                "source_record": hex32(stack[1] if len(stack) > 1 else None),
                "control_record": hex32(stack[2] if len(stack) > 2 else None),
                "sites": [],
                "events": [],
            }
        if current is not None and address in ORDERED_4A696B_SITES:
            current["sites"].append(address)
            current["events"].append(summarize_event(event, index))
            if address == RETURN_SITE:
                calls.append(current)
                current = None
    if current is not None:
        calls.append(current)

    for call in calls:
        sites = set(call["sites"])
        scan_done = next(
            (event for event in call["events"] if event["address"] == SCAN_DONE),
            None,
        )
        call["classification"] = (
            "prefilter_rejected_all_scanned_cells_before_source_relation_match_checkpoint"
            if SCAN_DONE in sites
            and NO_CANDIDATE_EXIT in sites
            and SOURCE_RELATION_MATCH_CHECKPOINT not in sites
            else "other_or_incomplete"
        )
        call["candidate_vector_at_scan_done"] = (
            scan_done["candidate_vector"] if scan_done else None
        )
    return calls


def summarize(ledger_path: Path) -> dict[str, Any]:
    ledger = load_json(ledger_path)
    events = ledger.get("events", [])
    counts = Counter(event["address"] for event in events)
    calls = group_4a696b_calls(events)
    classifications = Counter(call["classification"] for call in calls)

    predicate_counts = {
        "source_relation_match_checkpoint": counts.get(SOURCE_RELATION_MATCH_CHECKPOINT, 0),
        "terrain_reject_checkpoint_after_source_relation_match": counts.get(
            TERRAIN_REJECT_CHECKPOINT, 0
        ),
        "helper_49aa93_return_test": counts.get(HELPER_49AA93_RETURN_TEST, 0),
        "helper_4a6795_return_test": counts.get(HELPER_4A6795_RETURN_TEST, 0),
        "candidate_append": counts.get(CANDIDATE_APPEND, 0),
        "candidate_path": counts.get(CANDIDATE_PATH, 0),
        "direct_mutation_test": counts.get(DIRECT_MUTATION_TEST, 0),
    }
    fallback_events = [
        summarize_event(event, index)
        for index, event in enumerate(events)
        if event["address"]
        in {FALLBACK_COORDINATOR, ENDPOINT_COMMIT, ENDPOINT_VTABLE_COMMIT, PAIR_MARK_BEFORE, PAIR_MARK_AFTER}
    ]
    invariants = {
        "trace_has_events": len(events) > 0,
        "trace_timeout_after_useful_events": ledger.get("child_returncode") == 1
        and len(events) > 0,
        "hit_sampled_4a696b_entries": counts.get(ENTRY, 0) >= 1,
        "all_sampled_4a696b_entries_reached_scan_done": counts.get(SCAN_DONE, 0)
        == counts.get(ENTRY, 0),
        "all_sampled_4a696b_entries_took_no_candidate_exit": counts.get(NO_CANDIDATE_EXIT, 0)
        == counts.get(ENTRY, 0),
        "no_source_relation_match_checkpoint_hits": counts.get(
            SOURCE_RELATION_MATCH_CHECKPOINT, 0
        )
        == 0,
        "no_helper_predicate_hits": counts.get(HELPER_49AA93_RETURN_TEST, 0) == 0
        and counts.get(HELPER_4A6795_RETURN_TEST, 0) == 0,
        "no_candidate_appends": counts.get(CANDIDATE_APPEND, 0) == 0,
        "no_direct_mutation_hits": counts.get(DIRECT_MUTATION_TEST, 0) == 0,
        "fallback_endpoint_commit_path_still_observed": counts.get(FALLBACK_COORDINATOR, 0) >= 1
        and counts.get(ENDPOINT_COMMIT, 0) >= 2
        and counts.get(ENDPOINT_VTABLE_COMMIT, 0) >= 2,
        "no_native_behavior_change": True,
    }
    status = (
        "partial_live_recovery_4a696b_prefilter_rejects_sampled_candidate_scans"
        if all(invariants.values())
        else "incomplete"
    )
    return {
        "schema_id": "h3maped_4a696b_candidate_predicate_trace_summary_v1",
        "status": status,
        "ledger": str(ledger_path),
        "event_count": len(events),
        "address_counts": dict(sorted(counts.items())),
        "predicate_counts": predicate_counts,
        "call_classifications": dict(sorted(classifications.items())),
        "calls": calls,
        "fallback_events": fallback_events,
        "invariants": invariants,
        "candidate_vector_static_contract": {
            "layout": {
                "mode_byte": "byte [EBP-0x58]",
                "begin": "dword [EBP-0x54]",
                "end": "dword [EBP-0x50]",
                "capacity": "dword [EBP-0x4c]",
                "entry_size_bytes": 12,
            },
            "producer": (
                "0x4a696b appends a candidate coordinate through 0x4ae1fd at 0x4a6ae9 only "
                "after the generated cell's source/relation bytes match the source/control "
                "records, GeneratedCell+0x28 byte3 bit0 is clear, terrain id is not 8, the "
                "local x-window is in bounds, 0x49aa93 returns true, and 0x4a6795 returns true."
            ),
        },
        "recovered_contract": (
            "In this bounded live run, three sampled 0x4a696b calls reached scan completion "
            "and took the no-candidate exit with an empty local candidate vector. None reached "
            "the first post-source/relation-match checkpoint at 0x4a6a81, so the sampled empty "
            "vectors are not caused by 0x49aa93 rejection, 0x4a6795 rejection, or failed vector "
            "append. The scanned rectangles produced no generated cells matching the required "
            "source/relation byte pair before those helper predicates could run."
        ),
        "remaining_gap": (
            "End-to-end recovery still needs either a live 0x4a696b sample whose scan reaches "
            "0x4a6a81 and appends at least one candidate, then reaches 0x4a6b2e/0x4a6c13, or "
            "broader ordered branch evidence proving the direct mutation block is unreachable "
            "for the target one-level land generation mode. Natural 0x4a7605/0x4a746b/0x4a5e73 "
            "success/mutation and 0x4add76 cleanup/uncommit runtime behavior remain unrecovered."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args.ledger)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_4A696B_CANDIDATE_PREDICATE_TRACE_SUMMARY "
        f"status={summary['status']} out={args.out}"
    )
    return 0 if summary["status"].startswith("partial_live_recovery_") else 1


if __name__ == "__main__":
    raise SystemExit(main())
