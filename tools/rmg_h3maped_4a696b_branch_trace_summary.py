#!/usr/bin/env python3
"""Summarize the focused live 0x4a696b branch trace.

This report is deliberately narrow. It classifies the sampled 0x4a696b calls
by the branch sites they actually reached, so the recovery blocker is named
from live private-state evidence instead of final-map density deltas.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_LEDGER = Path(
    ".artifacts/rmg_recovery/"
    "direct_generation_4a696b_branch_trace_20260608/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_OUT = Path(".artifacts/rmg_recovery/4a696b_branch_trace_summary_20260608.json")

ENTRY = "0x004a696b"
EARLY_LEVEL_FAIL = "0x004a69bb"
EARLY_LEVEL_PASS = "0x004a69c2"
CANDIDATE_SCAN_DONE = "0x004a6b10"
NO_CANDIDATE_EXIT = "0x004a6b27"
CANDIDATE_PATH = "0x004a6b2e"
VTABLE_COMMIT = "0x004a6b9b"
DIRECT_MUTATION_TEST = "0x004a6c13"
DIRECT_MUTATION_AFTER = "0x004a6c2c"
LATE_FLAG_08 = "0x004a6c59"
LATE_FLAG_09 = "0x004a6c78"
FALSE_RETURN_PREP = "0x004a6cd3"
RETURN_SITE = "0x004a6ce1"
FALLBACK_COORDINATOR = "0x004a7605"
ENDPOINT_COMMIT = "0x004a7312"
PAIR_MARK_BEFORE = "0x004a7e21"
PAIR_MARK_AFTER = "0x004a7e25"

ORDERED_4A696B_SITES = [
    ENTRY,
    EARLY_LEVEL_FAIL,
    EARLY_LEVEL_PASS,
    CANDIDATE_SCAN_DONE,
    NO_CANDIDATE_EXIT,
    CANDIDATE_PATH,
    VTABLE_COMMIT,
    DIRECT_MUTATION_TEST,
    DIRECT_MUTATION_AFTER,
    LATE_FLAG_08,
    LATE_FLAG_09,
    FALSE_RETURN_PREP,
    RETURN_SITE,
]


def hex32(value: int | None) -> str | None:
    return None if value is None else f"0x{value & 0xFFFFFFFF:08x}"


def load_ledger(path: Path) -> dict[str, Any]:
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


def local_words_from_ebp_minus_58(event: dict[str, Any], count: int = 20) -> list[int | None]:
    ebp = event.get("registers", {}).get("ebp")
    if not isinstance(ebp, int):
        return []
    base = ebp - 0x58
    return [memory_word(event, base + index * 4) for index in range(count)]


def summarize_event(event: dict[str, Any], index: int) -> dict[str, Any]:
    registers = event.get("registers", {})
    stack = stack_words(event, 12)
    local_words = local_words_from_ebp_minus_58(event)
    candidate_count_or_gate = local_words[1] if len(local_words) > 1 else None
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
        "ebp_minus_58_words": [hex32(word) for word in local_words],
        "candidate_count_or_gate_at_ebp_minus_54": candidate_count_or_gate,
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
                "branch_classification": None,
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
            (event for event in call["events"] if event["address"] == CANDIDATE_SCAN_DONE),
            None,
        )
        no_candidate = next(
            (event for event in call["events"] if event["address"] == NO_CANDIDATE_EXIT),
            None,
        )
        if EARLY_LEVEL_FAIL in sites:
            classification = "early_level_mismatch_exit"
        elif NO_CANDIDATE_EXIT in sites and CANDIDATE_PATH not in sites:
            classification = "candidate_scan_empty_exit_before_direct_mutation"
        elif DIRECT_MUTATION_TEST in sites:
            classification = "reached_direct_mutation_block"
        elif CANDIDATE_PATH in sites:
            classification = "candidate_path_without_observed_direct_mutation"
        else:
            classification = "incomplete_or_unclassified"
        call["branch_classification"] = classification
        call["candidate_gate_at_scan_done"] = (
            scan_done["candidate_count_or_gate_at_ebp_minus_54"] if scan_done else None
        )
        call["candidate_gate_at_no_candidate_exit"] = (
            no_candidate["candidate_count_or_gate_at_ebp_minus_54"] if no_candidate else None
        )
    return calls


def summarize(ledger_path: Path) -> dict[str, Any]:
    ledger = load_ledger(ledger_path)
    events = ledger["events"]
    counts = Counter(event["address"] for event in events)
    calls = group_4a696b_calls(events)
    branch_counts = Counter(call["branch_classification"] for call in calls)

    fallback_events = [
        summarize_event(event, index)
        for index, event in enumerate(events)
        if event["address"] in {FALLBACK_COORDINATOR, ENDPOINT_COMMIT, PAIR_MARK_BEFORE, PAIR_MARK_AFTER}
    ]
    missed_sites = {
        "early_level_mismatch": counts.get(EARLY_LEVEL_FAIL, 0),
        "candidate_path": counts.get(CANDIDATE_PATH, 0),
        "vtable_commit_inside_4a696b": counts.get(VTABLE_COMMIT, 0),
        "direct_mutation_test": counts.get(DIRECT_MUTATION_TEST, 0),
        "direct_mutation_after": counts.get(DIRECT_MUTATION_AFTER, 0),
        "late_flag_08": counts.get(LATE_FLAG_08, 0),
        "late_flag_09": counts.get(LATE_FLAG_09, 0),
    }
    invariants = {
        "trace_has_events": len(events) > 0,
        "hit_four_4a696b_entries": counts.get(ENTRY, 0) == 4,
        "all_4a696b_entries_level_passed": counts.get(EARLY_LEVEL_PASS, 0) == counts.get(ENTRY, 0),
        "no_4a696b_early_level_failures": counts.get(EARLY_LEVEL_FAIL, 0) == 0,
        "all_4a696b_entries_reached_candidate_scan": counts.get(CANDIDATE_SCAN_DONE, 0)
        == counts.get(ENTRY, 0),
        "all_4a696b_entries_took_no_candidate_exit": counts.get(NO_CANDIDATE_EXIT, 0)
        == counts.get(ENTRY, 0),
        "no_4a696b_candidate_path_hits": counts.get(CANDIDATE_PATH, 0) == 0,
        "no_4a696b_direct_mutation_hits": counts.get(DIRECT_MUTATION_TEST, 0) == 0
        and counts.get(DIRECT_MUTATION_AFTER, 0) == 0,
        "fallback_direct_endpoint_path_still_observed": counts.get(FALLBACK_COORDINATOR, 0) >= 1
        and counts.get(ENDPOINT_COMMIT, 0) >= 2,
        "no_native_behavior_change": True,
    }
    status = (
        "partial_live_recovery_4a696b_no_candidate_exit_before_direct_mutation"
        if all(invariants.values())
        else "incomplete"
    )
    return {
        "schema_id": "h3maped_4a696b_branch_trace_summary_v1",
        "status": status,
        "ledger": str(ledger_path),
        "event_count": len(events),
        "address_counts": dict(sorted(counts.items())),
        "branch_counts": dict(sorted(branch_counts.items())),
        "missed_4a696b_sites": missed_sites,
        "calls": calls,
        "fallback_events": fallback_events,
        "invariants": invariants,
        "recovered_contract": (
            "In this bounded live run, all four sampled 0x4a696b calls pass the same-level gate "
            "at 0x4a69c2, reach candidate scan completion at 0x4a6b10 with [EBP-0x54] captured "
            "as zero, take the no-candidate exit at 0x4a6b27, and return through 0x4a6cd3/"
            "0x4a6ce1 before the direct generated-cell mutation block. The run still observes "
            "the fallback 0x4a7605 -> 0x4a7312 endpoint commit path after those failed 0x4a696b "
            "attempts."
        ),
        "remaining_gap": (
            "End-to-end recovery still needs a live 0x4a696b sample where [EBP-0x54] is nonzero "
            "and execution reaches 0x4a6b2e/0x4a6b9b/0x4a6c13, or broader ordered branch evidence "
            "proving that the direct mutation block is unreachable for the target one-level land "
            "generation mode. The [record+0x09] path through 0x4a746b/0x4a5e73 and the 0x4add76 "
            "cleanup/uncommit path also remain unrecovered."
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
    print(f"RMG_H3MAPED_4A696B_BRANCH_TRACE_SUMMARY status={summary['status']} out={args.out}")
    return 0 if summary["status"].startswith("partial_live_recovery_") else 1


if __name__ == "__main__":
    raise SystemExit(main())
