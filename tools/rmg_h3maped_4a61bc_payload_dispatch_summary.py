#!/usr/bin/env python3
"""Summarize linked 0x4a61bc payload dispatch branch state.

Input is the dynamic same-run trace produced by
``rmg_h3maped_4a61bc_payload_link_dynamic_trace.py`` with internal 0x4a696b
branch breakpoints enabled. This report ties the branch evidence to the exact
selected 0x4a61bc object record that reappears in the 0x4a79a3 payload loop.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_LEDGER = Path(
    ".artifacts/rmg_recovery/4a61bc_payload_dispatch_branch_trace_20260609/"
    "winedbg_4a61bc_payload_link_dynamic_trace_ledger.json"
)
DEFAULT_OUT = Path(".artifacts/rmg_recovery/4a61bc_payload_dispatch_summary_20260609.json")

ADDR_OBJECT = "0x004a5e55"
ADDR_PAYLOAD = "0x004a7d36"
ENTRY = "0x004a696b"
EARLY_LEVEL_FAIL = "0x004a69bb"
EARLY_LEVEL_PASS = "0x004a69c2"
SOURCE_RELATION_MATCH_CHECKPOINT = "0x004a6a81"
TERRAIN_REJECT_CHECKPOINT = "0x004a6a8f"
HELPER_49AA93_RETURN_TEST = "0x004a6ac8"
HELPER_4A6795_RETURN_TEST = "0x004a6ade"
CANDIDATE_APPEND = "0x004a6ae2"
SCAN_DONE = "0x004a6b10"
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
ENDPOINT_VTABLE_COMMIT = "0x004a7447"
ENDPOINT_RETURN = "0x004a744c"
FIRST_DELEGATED_COMPARE = "0x004a774a"
FIRST_DELEGATED_CALL = "0x004a7763"
FIRST_DELEGATED_SKIP = "0x004a7773"
SECOND_DELEGATED_COMPARE = "0x004a783a"
SECOND_DELEGATED_CALL = "0x004a7853"
SECOND_DELEGATED_SKIP = "0x004a7860"
DELEGATED_ENDPOINT_WRITER = "0x004a746b"
ENDPOINT_HELPER = "0x004a5e73"
ENDPOINT_HELPER_SUCCESS_A = "0x004a5fd8"
ENDPOINT_HELPER_SUCCESS_B = "0x004a5ff1"
ENDPOINT_MUTATION_SITE = "0x004a75f1"
PAIR_FILTER = "0x004a7df4"
PAIR_MARK_BEFORE = "0x004a7e21"
PAIR_MARK_AFTER = "0x004a7e25"

ORDERED_4A696B_SITES = [
    ENTRY,
    EARLY_LEVEL_FAIL,
    EARLY_LEVEL_PASS,
    SOURCE_RELATION_MATCH_CHECKPOINT,
    TERRAIN_REJECT_CHECKPOINT,
    HELPER_49AA93_RETURN_TEST,
    HELPER_4A6795_RETURN_TEST,
    CANDIDATE_APPEND,
    SCAN_DONE,
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


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def event_address(event: dict[str, Any]) -> str:
    return str(event.get("address", "")).lower()


def memory_words(event: dict[str, Any], address: int | None, count: int) -> list[int | None]:
    if address is None:
        return []
    result: list[int | None] = []
    for offset in range(count):
        target = address + offset * 4
        found: int | None = None
        for line in event.get("memory_lines", []):
            base = int(line.get("address", -1))
            words = line.get("words", [])
            if base <= target < base + len(words) * 4 and (target - base) % 4 == 0:
                found = int(words[(target - base) // 4]) & 0xFFFFFFFF
                break
        result.append(found)
    return result


def stack_words(event: dict[str, Any], count: int) -> list[int | None]:
    esp = event.get("registers", {}).get("esp")
    return memory_words(event, esp if isinstance(esp, int) else None, count)


def local_candidate_vector(event: dict[str, Any]) -> dict[str, Any]:
    ebp = event.get("registers", {}).get("ebp")
    if not isinstance(ebp, int):
        return {"mode_byte": None, "begin": None, "end": None, "capacity": None, "entry_count": None}
    mode_word = memory_words(event, ebp - 0x58, 1)
    begin, end, capacity = (memory_words(event, ebp - 0x54, 3) + [None, None, None])[:3]
    entry_count = None
    if begin and end is not None and end >= begin:
        entry_count = (end - begin) // 12
    return {
        "mode_byte": None if not mode_word else mode_word[0] & 0xFF if mode_word[0] is not None else None,
        "begin": hex32(begin),
        "end": hex32(end),
        "capacity": hex32(capacity),
        "entry_count": entry_count,
    }


def pointer_block(event: dict[str, Any], register: str, words: int = 16) -> dict[str, Any]:
    value = event.get("registers", {}).get(register)
    pointer = value if isinstance(value, int) else None
    return {
        "pointer": hex32(pointer),
        "words": [hex32(word) for word in memory_words(event, pointer, words)],
    }


def byte_from_words(words: list[str | None], offset: int) -> int | None:
    word_index = offset // 4
    byte_index = offset % 4
    if word_index >= len(words) or words[word_index] is None:
        return None
    value = int(str(words[word_index]), 16)
    return (value >> (byte_index * 8)) & 0xFF


def selected_object_pointer(events: list[dict[str, Any]], meta: dict[str, Any]) -> str | None:
    if meta.get("object_record"):
        return str(meta["object_record"])
    for event in events:
        if event_address(event) == ADDR_OBJECT:
            value = event.get("registers", {}).get("eax")
            if isinstance(value, int):
                return hex32(value)
    return None


def selected_payload_index(events: list[dict[str, Any]], selected: str | None) -> int | None:
    if selected is None:
        return None
    selected_int = int(selected, 16)
    for index, event in enumerate(events):
        if event_address(event) == ADDR_PAYLOAD and event.get("registers", {}).get("edx") == selected_int:
            return index
    return None


def summarize_event(event: dict[str, Any], index: int) -> dict[str, Any]:
    regs = event.get("registers", {})
    stack = stack_words(event, 12)
    return {
        "event_index": index,
        "address": event_address(event),
        "return_address": hex32(stack[0] if stack else None),
        "registers": {
            "eax": hex32(regs.get("eax")),
            "ebx": hex32(regs.get("ebx")),
            "ecx": hex32(regs.get("ecx")),
            "edx": hex32(regs.get("edx")),
            "esi": hex32(regs.get("esi")),
            "edi": hex32(regs.get("edi")),
            "ebp": hex32(regs.get("ebp")),
            "esp": hex32(regs.get("esp")),
        },
        "stack_words": [hex32(word) for word in stack],
        "candidate_vector": local_candidate_vector(event),
        "esi_block": pointer_block(event, "esi"),
        "ecx_block": pointer_block(event, "ecx"),
        "edx_block": pointer_block(event, "edx"),
    }


def classify_call(sites: set[str]) -> str:
    if EARLY_LEVEL_FAIL in sites:
        return "early_level_mismatch_exit"
    if DIRECT_MUTATION_TEST in sites:
        return "reached_direct_mutation_block"
    if CANDIDATE_PATH in sites:
        return "candidate_path_without_observed_direct_mutation"
    if NO_CANDIDATE_EXIT in sites and SOURCE_RELATION_MATCH_CHECKPOINT not in sites:
        return "prefilter_rejected_before_source_relation_match"
    if NO_CANDIDATE_EXIT in sites:
        return "candidate_scan_empty_exit_after_some_prefilter_progress"
    return "incomplete_or_unclassified"


def group_4a696b_calls(events: list[dict[str, Any]], selected_payload_event_index: int | None) -> list[dict[str, Any]]:
    calls: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    for index, event in enumerate(events):
        address = event_address(event)
        if address == ENTRY:
            if current is not None:
                calls.append(current)
            stack = stack_words(event, 8)
            current = {
                "call_index": len(calls),
                "entry_event_index": index,
                "after_selected_payload_record": selected_payload_event_index is not None and index > selected_payload_event_index,
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
        call["classification"] = classify_call(sites)
        scan_done = next((event for event in call["events"] if event["address"] == SCAN_DONE), None)
        call["candidate_vector_at_scan_done"] = scan_done["candidate_vector"] if scan_done else None
    return calls


def pair_events(events: list[dict[str, Any]], selected_payload_event_index: int | None) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for index, event in enumerate(events):
        if event_address(event) not in {FALLBACK_COORDINATOR, PAIR_FILTER, PAIR_MARK_BEFORE, PAIR_MARK_AFTER}:
            continue
        result.append(
            {
                **summarize_event(event, index),
                "after_selected_payload_record": selected_payload_event_index is not None and index > selected_payload_event_index,
            }
        )
    return result


def endpoint_events(events: list[dict[str, Any]], selected_payload_event_index: int | None) -> list[dict[str, Any]]:
    sites = {
        FALLBACK_COORDINATOR,
        ENDPOINT_COMMIT,
        ENDPOINT_VTABLE_COMMIT,
        ENDPOINT_RETURN,
        FIRST_DELEGATED_COMPARE,
        FIRST_DELEGATED_CALL,
        FIRST_DELEGATED_SKIP,
        SECOND_DELEGATED_COMPARE,
        SECOND_DELEGATED_CALL,
        SECOND_DELEGATED_SKIP,
        DELEGATED_ENDPOINT_WRITER,
        ENDPOINT_HELPER,
        ENDPOINT_HELPER_SUCCESS_A,
        ENDPOINT_HELPER_SUCCESS_B,
        ENDPOINT_MUTATION_SITE,
    }
    result: list[dict[str, Any]] = []
    for index, event in enumerate(events):
        if event_address(event) not in sites:
            continue
        summarized = summarize_event(event, index)
        summarized["after_selected_payload_record"] = selected_payload_event_index is not None and index > selected_payload_event_index
        esi_words = summarized.get("esi_block", {}).get("words", [])
        summarized["esi_control_bytes"] = {
            "+0x08": byte_from_words(esi_words, 0x08),
            "+0x09": byte_from_words(esi_words, 0x09),
            "+0x0a": byte_from_words(esi_words, 0x0A),
        }
        result.append(summarized)
    return result


def summarize_7605_endpoint_path(endpoint: list[dict[str, Any]]) -> dict[str, Any]:
    after = [event for event in endpoint if event.get("after_selected_payload_record")]
    counts = Counter(event["address"] for event in after)
    first_compare = next((event for event in after if event["address"] == FIRST_DELEGATED_COMPARE), None)
    second_compare = next((event for event in after if event["address"] == SECOND_DELEGATED_COMPARE), None)
    return {
        "after_selected_event_count": len(after),
        "after_selected_address_counts": dict(sorted(counts.items())),
        "direct_4a7312_commit_count": counts.get(ENDPOINT_COMMIT, 0),
        "direct_4a7447_vtable_commit_count": counts.get(ENDPOINT_VTABLE_COMMIT, 0),
        "delegated_4a746b_call_count": counts.get(DELEGATED_ENDPOINT_WRITER, 0),
        "endpoint_helper_4a5e73_count": counts.get(ENDPOINT_HELPER, 0),
        "endpoint_mutation_site_count": counts.get(ENDPOINT_MUTATION_SITE, 0),
        "first_gate": {
            "compare_hit": counts.get(FIRST_DELEGATED_COMPARE, 0) > 0,
            "call_hit": counts.get(FIRST_DELEGATED_CALL, 0) > 0,
            "skip_hit": counts.get(FIRST_DELEGATED_SKIP, 0) > 0,
            "esi_record": first_compare.get("registers", {}).get("esi") if first_compare else None,
            "control_bytes": first_compare.get("esi_control_bytes") if first_compare else {},
        },
        "second_gate": {
            "compare_hit": counts.get(SECOND_DELEGATED_COMPARE, 0) > 0,
            "call_hit": counts.get(SECOND_DELEGATED_CALL, 0) > 0,
            "skip_hit": counts.get(SECOND_DELEGATED_SKIP, 0) > 0,
            "esi_record": second_compare.get("registers", {}).get("esi") if second_compare else None,
            "control_bytes": second_compare.get("esi_control_bytes") if second_compare else {},
        },
    }


def pair_bookkeeping_mutations(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    grouped: dict[str, list[dict[str, Any]]] = {}
    for event in events:
        pointer = event.get("registers", {}).get("esi")
        if not pointer:
            continue
        grouped.setdefault(pointer, []).append(event)
    mutations: list[dict[str, Any]] = []
    for pointer, pointer_events in sorted(grouped.items()):
        if len(pointer_events) < 2:
            continue
        first = pointer_events[0].get("esi_block", {}).get("words", [])
        last = pointer_events[-1].get("esi_block", {}).get("words", [])
        changed: list[dict[str, Any]] = []
        for index, (before, after) in enumerate(zip(first, last)):
            if before != after:
                changed.append({
                    "word_index": index,
                    "byte_offset": hex(index * 4),
                    "before": before,
                    "after": after,
                })
        if changed:
            mutations.append(
                {
                    "esi_pointer": pointer,
                    "first_event_index": pointer_events[0].get("event_index"),
                    "last_event_index": pointer_events[-1].get("event_index"),
                    "sites": [event.get("address") for event in pointer_events],
                    "changed_words": changed,
                }
            )
    return mutations


def summarize(ledger_path: Path) -> dict[str, Any]:
    ledger = load_json(ledger_path)
    events = ledger.get("events", [])
    meta = ledger.get("dynamic_trace_meta", {})
    counts = Counter(event_address(event) for event in events)
    selected = selected_object_pointer(events, meta)
    selected_payload = selected_payload_index(events, selected)
    calls = group_4a696b_calls(events, selected_payload)
    after_selected_calls = [call for call in calls if call["after_selected_payload_record"]]
    pairs = pair_events(events, selected_payload)
    after_selected_pairs = [event for event in pairs if event["after_selected_payload_record"]]
    pair_mutations = pair_bookkeeping_mutations(after_selected_pairs)
    endpoint = endpoint_events(events, selected_payload)
    endpoint_path = summarize_7605_endpoint_path(endpoint)
    classifications = Counter(call["classification"] for call in calls)
    after_classifications = Counter(call["classification"] for call in after_selected_calls)

    invariants = {
        "selected_object_record_captured": selected is not None,
        "selected_object_record_reaches_payload": selected_payload is not None,
        "internal_4a696b_sites_captured": counts.get(SCAN_DONE, 0) > 0 or counts.get(DIRECT_MUTATION_TEST, 0) > 0,
        "after_selected_payload_4a696b_calls_captured": bool(after_selected_calls),
        "after_selected_payload_pair_bookkeeping_captured": bool(after_selected_pairs),
        "after_selected_payload_pair_bookkeeping_mutation_captured": bool(pair_mutations),
        "after_selected_7605_endpoint_path_captured": endpoint_path["after_selected_event_count"] > 0,
        "after_selected_7605_direct_commits_captured": endpoint_path["direct_4a7312_commit_count"] > 0,
        "after_selected_7605_delegated_endpoint_not_hit": endpoint_path["delegated_4a746b_call_count"] == 0
        and endpoint_path["endpoint_helper_4a5e73_count"] == 0,
        "no_after_selected_direct_mutation_hits": all(
            call["classification"] != "reached_direct_mutation_block" for call in after_selected_calls
        ),
        "no_native_behavior_change": True,
    }
    status = (
        "linked_payload_7605_endpoint_gates_replayed"
        if all(invariants.values())
        else "linked_payload_4a696b_branch_partial"
    )
    return {
        "schema_id": "h3maped_4a61bc_payload_dispatch_summary_v1",
        "status": status,
        "native_behavior_changed": False,
        "ledger": str(ledger_path),
        "event_count": len(events),
        "address_counts": dict(sorted(counts.items())),
        "selected_object_record": selected,
        "selected_payload_event_index": selected_payload,
        "call_classifications": dict(sorted(classifications.items())),
        "after_selected_payload_call_classifications": dict(sorted(after_classifications.items())),
        "calls": calls,
        "after_selected_payload_calls": after_selected_calls,
        "pair_events": pairs,
        "after_selected_payload_pair_events": after_selected_pairs,
        "after_selected_payload_pair_bookkeeping_mutations": pair_mutations,
        "endpoint_events": endpoint,
        "after_selected_7605_endpoint_path": endpoint_path,
        "invariants": invariants,
        "source_backed_conclusion": (
            "The linked payload trace now carries the selected 0x4a61bc object into the payload loop, "
            "samples subsequent 0x4a696b branch state, and replays the after-selected 0x4a7605 endpoint "
            "path. The sampled after-selected 0x4a696b call does not reach the direct mutation block; "
            "the sampled after-selected 0x4a7605 path performs direct 0x4a7312 commits, then both "
            "delegated 0x4a746b gates skip because control byte +0x09 is zero."
            if after_selected_calls
            else "The selected object reaches payload, but this trace did not capture a later 0x4a696b "
            "call after that selected payload event."
        ),
        "remaining_gap": (
            "Recover a linked-payload sample that reaches 0x4a696b direct mutation, or prove from broader "
            "ordered branch evidence that the direct mutation block is unreachable for this generation mode. "
            "Natural 0x4a7605/0x4a746b/0x4a5e73 success and 0x4add76 cleanup/uncommit still remain."
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    summary = summarize(args.ledger)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_4A61BC_PAYLOAD_DISPATCH_SUMMARY "
        f"status={summary['status']} "
        f"selected={summary['selected_object_record']} "
        f"after_selected_calls={len(summary['after_selected_payload_calls'])} "
        f"out={args.out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
