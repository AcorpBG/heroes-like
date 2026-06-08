#!/usr/bin/env python3
"""Summarize the current 0x4a901a weighted post-gate frontier.

This checkpoint intentionally does not claim full 0x540a9c materialization.
It records the narrower recovered surface: a weighted candidate can pass the
0x4a9150 value floor and reach the 0x4a9167 helper call, while sampled
post-scan paths still reach the empty local-vector gate and return false
before allocation, constructor, ready, or projection-dispatch sites.
"""

from __future__ import annotations

import argparse
import collections
import json
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_ELIGIBILITY_LEDGER = (
    ROOT / "4a901a_large_4p_eligibility_probe_20260609" / "winedbg_interactive_trace_ledger.json"
)
DEFAULT_APPEND_LEDGER = (
    ROOT
    / "4a901a_large_4p_weighted_append_probe_20260609_parse"
    / "winedbg_recovery_trace_ledger.json"
)
DEFAULT_HELPER_LEDGER = (
    ROOT / "4a901a_large_4p_helper_return_probe_20260609" / "winedbg_interactive_trace_ledger.json"
)
DEFAULT_STATIC_4A901A = ROOT / "ghidra_object_projection_helper_dump" / "caller_004a901a_FUN_004a901a.txt"
DEFAULT_OUT = ROOT / "4a901a_postgate_frontier_summary_20260609.json"


def load_ledger(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def hex32(value: int | None) -> str | None:
    if value is None:
        return None
    return f"0x{value & 0xFFFFFFFF:08x}"


def event_counts(events: list[dict[str, Any]]) -> dict[str, int]:
    return dict(collections.Counter(event.get("address") for event in events))


def memory_map(event: dict[str, Any]) -> dict[int, int]:
    result: dict[int, int] = {}
    for line in event.get("memory_lines", []):
        address = line.get("address")
        if not isinstance(address, int):
            continue
        for index, word in enumerate(line.get("words", [])):
            if isinstance(word, int):
                result[address + index * 4] = word & 0xFFFFFFFF
    return result


def word_at(event: dict[str, Any], address: int) -> int | None:
    return memory_map(event).get(address)


def local_word(event: dict[str, Any], offset: int) -> int | None:
    ebp = event.get("registers", {}).get("ebp")
    if not isinstance(ebp, int):
        return None
    return word_at(event, ebp + offset)


def stack_words(event: dict[str, Any], count: int = 9) -> list[int]:
    esp = event.get("registers", {}).get("esp")
    if not isinstance(esp, int):
        return []
    mem = memory_map(event)
    return [mem[esp + index * 4] for index in range(count) if esp + index * 4 in mem]


def call_args_4a901a(event: dict[str, Any]) -> dict[str, str | None]:
    words = stack_words(event)
    labels = [
        "return_address",
        "source_wrapper",
        "arg_0c_category_or_x",
        "arg_10_selector_or_y",
        "arg_14_enabled_or_level",
        "arg_18_required_value",
        "arg_1c_relation_index",
        "generator",
        "trailing_callsite_word",
    ]
    return {label: hex32(words[index]) for index, label in enumerate(labels) if index < len(words)}


def first_event(events: list[dict[str, Any]], address: str) -> dict[str, Any] | None:
    for event in events:
        if event.get("address") == address:
            return event
    return None


def weighted_entry_before(events: list[dict[str, Any]], ordinal: int) -> dict[str, Any] | None:
    for event in reversed(events[:ordinal]):
        if event.get("address") != "0x004a901a":
            continue
        args = call_args_4a901a(event)
        if args.get("arg_14_enabled_or_level") == "0x00000000":
            return event
    return None


def eligibility_summary(events: list[dict[str, Any]]) -> dict[str, Any]:
    value_index = next((index for index, event in enumerate(events) if event.get("address") == "0x004a9150"), None)
    helper_index = next((index for index, event in enumerate(events) if event.get("address") == "0x004a9167"), None)
    value_event = events[value_index] if value_index is not None else None
    helper_event = events[helper_index] if helper_index is not None else None
    entry = weighted_entry_before(events, value_index) if value_index is not None else None
    threshold = None
    if entry is not None:
        threshold_arg = call_args_4a901a(entry).get("arg_18_required_value")
        threshold = int(threshold_arg, 16) if threshold_arg is not None else None

    sample: dict[str, Any] = {
        "weighted_entry_args": call_args_4a901a(entry) if entry is not None else None,
        "reaches_value_floor": value_event is not None,
        "reaches_helper_callsite": helper_event is not None,
    }
    if value_event is not None:
        eax = value_event.get("registers", {}).get("eax")
        low_word = (eax & 0xFFFF) if isinstance(eax, int) else None
        sample.update(
            {
                "cell_low_word_at_0x4a9150": low_word,
                "required_value": threshold,
                "passes_value_floor": low_word is not None and threshold is not None and low_word >= threshold,
                "candidate_xy": [local_word(value_event, -0x3C), local_word(value_event, -0x38)],
                "projected_xy": [local_word(value_event, -0x30), local_word(value_event, -0x2C)],
                "descriptor_offset_xy": [local_word(value_event, -0x24), local_word(value_event, -0x20)],
                "candidate_score_saved_local": local_word(value_event, -0x1C),
            }
        )
    if helper_event is not None:
        sample["helper_call_stack_words"] = [hex32(word) for word in stack_words(helper_event, 8)]
    return sample


def vector_gate_samples(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    samples: list[dict[str, Any]] = []
    for ordinal, event in enumerate(events):
        if event.get("address") != "0x004a9273":
            continue
        begin = local_word(event, -0x54)
        end = local_word(event, -0x50)
        cap = local_word(event, -0x4C)
        samples.append(
            {
                "ordinal": ordinal,
                "candidate_vector_begin": hex32(begin),
                "candidate_vector_end": hex32(end),
                "candidate_vector_cap": hex32(cap),
                "candidate_vector_empty": begin == 0,
                "eax": hex32(event.get("registers", {}).get("eax")),
                "edx": hex32(event.get("registers", {}).get("edx")),
            }
        )
    return samples


def return_samples(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    samples: list[dict[str, Any]] = []
    for ordinal, event in enumerate(events):
        if event.get("address") != "0x004a9391":
            continue
        samples.append(
            {
                "ordinal": ordinal,
                "return_eax": hex32(event.get("registers", {}).get("eax")),
                "return_false": event.get("registers", {}).get("eax") == 0,
            }
        )
    return samples


def static_markers(path: Path) -> dict[str, bool]:
    text = path.read_text(encoding="utf-8", errors="replace")
    markers = [
        "004a914a: CMP EAX,dword ptr [EBP + 0x18]",
        "004a9150: JL 0x004a9259",
        "004a9167: CALL 0x0049aa93",
        "004a9248: CALL 0x004ae52a",
        "004a9254: CALL 0x004ae1fd",
        "004a9273: CMP dword ptr [EBP + -0x54],0x0",
        "004a9287: JNZ 0x004a9290",
        "004a9290: PUSH 0x28",
        "004a92bb: CALL 0x0049ba89",
        "004a9322: CALL dword ptr [EDX + 0x4]",
        "004a9391: MOV ECX,dword ptr [EBP + -0xc]",
    ]
    return {marker: marker in text for marker in markers}


def build_summary(args: argparse.Namespace) -> dict[str, Any]:
    eligibility_events = load_ledger(args.eligibility_ledger)["events"]
    append_events = load_ledger(args.append_ledger)["events"]
    helper_events = load_ledger(args.helper_ledger)["events"]
    append_counts = event_counts(append_events)
    helper_counts = event_counts(helper_events)
    vector_samples = vector_gate_samples(append_events)
    append_or_materialization_hits = sum(
        append_counts.get(address, 0)
        for address in (
            "0x004a9248",
            "0x004a9254",
            "0x004a9290",
            "0x004a92bb",
            "0x004a92d5",
            "0x004a9322",
        )
    )
    conditions = {
        "value_floor_pass_reaches_helper_callsite": eligibility_summary(eligibility_events).get("passes_value_floor")
        is True
        and eligibility_summary(eligibility_events).get("reaches_helper_callsite") is True,
        "append_trace_reaches_vector_gate": append_counts.get("0x004a9273", 0) > 0,
        "append_trace_no_append_or_materialization": append_or_materialization_hits == 0,
        "append_trace_returns_false": all(sample["return_false"] for sample in return_samples(append_events)),
        "append_trace_vector_gate_samples_empty": bool(vector_samples)
        and all(sample["candidate_vector_empty"] for sample in vector_samples),
        "helper_return_probe_no_accepted_helper_return": helper_counts.get("0x004a9174", 0) == 0,
    }
    status = (
        "weighted_value_floor_pass_reaches_helper_but_materialization_still_unrecovered"
        if all(conditions.values())
        else "weighted_postgate_frontier_incomplete"
    )
    return {
        "schema_id": "rmg_h3maped_4a901a_postgate_frontier_summary.v1",
        "status": status,
        "inputs": {
            "eligibility_ledger": str(args.eligibility_ledger),
            "append_ledger": str(args.append_ledger),
            "helper_ledger": str(args.helper_ledger),
            "static_4a901a": str(args.static_4a901a),
        },
        "counts": {
            "eligibility": event_counts(eligibility_events),
            "append": append_counts,
            "helper_return": helper_counts,
        },
        "conditions": conditions,
        "eligibility_sample": eligibility_summary(eligibility_events),
        "append_vector_gate_samples": vector_samples[:20],
        "append_return_samples": return_samples(append_events)[:20],
        "static_markers": static_markers(args.static_4a901a),
        "recovered": [
            "A Large one-level no-water weighted 0x4a901a candidate can pass the 0x4a9150 value floor.",
            "The passing sample reaches the 0x4a9167 helper call site with candidate coordinates on the stack.",
            "The local candidate-vector gate at 0x4a9273 is now observed directly in weighted 0x4a901a runs.",
        ],
        "not_recovered": [
            "No sampled weighted 0x4a901a run reached the append calls at 0x4a9248 or 0x4a9254.",
            "No sampled weighted 0x4a901a run reached allocation 0x4a9290, constructor 0x4a92bb, ready site 0x4a92d5, or projection dispatch 0x4a9322.",
            "The exact 0x49aa93 helper-return and append-acceptance conditions are still not recovered end-to-end for a successful materialization.",
        ],
        "next_required_step": (
            "Capture one weighted 0x4a901a candidate from 0x4a9150 through 0x4a916c/0x4a9174, "
            "0x4a9248/0x4a9254 append, 0x4a9290 allocation, 0x4a92bb construction, "
            "0x4a9322 projection dispatch, and generated-cell/vector before/after deltas. "
            "If the helper rejects, recover the 0x49aa93 predicate inputs for that candidate."
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--eligibility-ledger", type=Path, default=DEFAULT_ELIGIBILITY_LEDGER)
    parser.add_argument("--append-ledger", type=Path, default=DEFAULT_APPEND_LEDGER)
    parser.add_argument("--helper-ledger", type=Path, default=DEFAULT_HELPER_LEDGER)
    parser.add_argument("--static-4a901a", type=Path, default=DEFAULT_STATIC_4A901A)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    summary = build_summary(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_4A901A_POSTGATE_FRONTIER status={summary['status']} out={args.out}")
    return (
        0
        if summary["status"] == "weighted_value_floor_pass_reaches_helper_but_materialization_still_unrecovered"
        else 1
    )


if __name__ == "__main__":
    raise SystemExit(main())
