#!/usr/bin/env python3
"""Summarize natural Border Guard endpoint-failure follow-through evidence.

This parses the focused WineDbg trace that starts before the natural
``0x4a61bc`` Border Guard endpoint helper calls and continues far enough to
show the downstream materialization path. The report is recovery evidence only:
it does not tune, compare, or mutate native RMG behavior.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

from rmg_h3maped_recovery_trace import parse_winedbg_log


DEFAULT_TRACE_LOG = Path(
    ".artifacts/rmg_recovery/medium_seed10_4a64ff_failure_followthrough_probe_20260608/"
    "winedbg_interactive_trace.log"
)
DEFAULT_OUT = Path(
    ".artifacts/rmg_recovery/medium_seed10_border_guard_followthrough_summary_20260608.json"
)

BG_WATCH_ADDRESSES = {
    "0x004a64ff",
    "0x004a5e73",
    "0x004a5ed7",
    "0x004a5f84",
    "0x004a651f",
    "0x004a6531",
    "0x004a6551",
}


def stack_words(event: dict[str, Any]) -> list[int]:
    if not event.get("memory_lines"):
        return []
    return [int(word) & 0xFFFFFFFF for word in event["memory_lines"][0].get("words", [])]


def return_address(event: dict[str, Any]) -> str:
    derived = event.get("derived", {})
    if derived.get("return_address"):
        return str(derived["return_address"])
    words = stack_words(event)
    if not words:
        return "missing"
    return "0x%08x" % words[0]


def hex_word(value: int) -> str:
    return "0x%08x" % (value & 0xFFFFFFFF)


def callsite_arg_summary(event: dict[str, Any]) -> dict[str, Any]:
    words = stack_words(event)
    return {
        "arg_words": [hex_word(word) for word in words],
        "interpreted_coordinate_if_call_args": {
            "x": words[0] if len(words) > 0 else None,
            "y": words[1] if len(words) > 1 else None,
            "level": words[2] if len(words) > 2 else None,
            "repeat_or_arg4": words[3] if len(words) > 3 else None,
        },
    }


def function_entry_arg_summary(event: dict[str, Any]) -> dict[str, Any]:
    words = stack_words(event)
    return {
        "return_address": return_address(event),
        "arg_words_after_return": [hex_word(word) for word in words[1:]],
    }


def event_brief(event: dict[str, Any], event_index: int) -> dict[str, Any]:
    registers = event.get("registers", {})
    return {
        "event_index": event_index,
        "address": event.get("address"),
        "return_address": return_address(event),
        "registers": {
            name: hex_word(int(registers[name]))
            for name in ("eax", "ecx", "edx", "esi", "edi", "ebp", "esp")
            if name in registers
        },
        "stack": function_entry_arg_summary(event),
    }


def find_border_guard_sequences(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    sequences: list[dict[str, Any]] = []
    index = 0
    while index < len(events):
        if str(events[index].get("address", "")).lower() != "0x004a64ff":
            index += 1
            continue
        first_index = index
        first_expected = [
            "0x004a64ff",
            "0x004a5e73",
            "0x004a5ed7",
            "0x004a5f84",
            "0x004a651f",
            "0x004a6531",
            "0x004a5e73",
            "0x004a5ed7",
            "0x004a5f84",
            "0x004a6551",
        ]
        window = events[index : index + len(first_expected)]
        window_addresses = [str(event.get("address", "")).lower() for event in window]
        if window_addresses != first_expected:
            index += 1
            continue
        sequence_events = [
            event_brief(event, first_index + offset + 1)
            for offset, event in enumerate(window)
        ]
        sequences.append(
            {
                "sequence_number": len(sequences) + 1,
                "events": sequence_events,
                "first_endpoint_call_args": callsite_arg_summary(window[0]),
                "second_endpoint_call_args": callsite_arg_summary(window[5]),
                "failure_cursors": [
                    hex_word(int(window[3].get("registers", {}).get("edi", 0))),
                    hex_word(int(window[8].get("registers", {}).get("edi", 0))),
                ],
                "failure_scan_counts": [
                    int(window[3].get("registers", {}).get("eax", -1)),
                    int(window[8].get("registers", {}).get("eax", -1)),
                ],
                "final_fallthrough": event_brief(window[-1], first_index + len(window)),
            }
        )
        index += len(first_expected)
    return sequences


def downstream_5e03_calls(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    calls: list[dict[str, Any]] = []
    for event_index, event in enumerate(events, start=1):
        if str(event.get("address", "")).lower() != "0x004a5e03":
            continue
        ret = return_address(event)
        caller = "unknown"
        if ret == "0x004a657d":
            caller = "0x4a61bc_after_0x4a6578"
        elif ret in {"0x004a77ad", "0x004a789a"}:
            caller = "0x4a7605_downstream_materialization"
        elif ret == "0x004a9af6":
            caller = "0x4a9af6_later_generation_path"
        calls.append(
            {
                "event_index": event_index,
                "return_address": ret,
                "caller_class": caller,
                "args": function_entry_arg_summary(event),
                "registers": event_brief(event, event_index)["registers"],
            }
        )
    return calls


def summarize(log_path: Path) -> dict[str, Any]:
    ledger = parse_winedbg_log(log_path)
    events = ledger.get("events", [])
    counts = Counter(str(event.get("address", "")).lower() for event in events)
    sequences = find_border_guard_sequences(events)
    calls_5e03 = downstream_5e03_calls(events)

    last_bg_index = max(
        (int(seq["events"][-1]["event_index"]) for seq in sequences),
        default=0,
    )
    post_bg_5e03 = [call for call in calls_5e03 if call["event_index"] > last_bg_index]
    post_bg_7605 = [
        call
        for call in post_bg_5e03
        if call["caller_class"] == "0x4a7605_downstream_materialization"
    ]
    pre_bg_4a6578_5e03 = [
        call
        for call in calls_5e03
        if call["event_index"] < (sequences[0]["events"][0]["event_index"] if sequences else 0)
        and call["caller_class"] == "0x4a61bc_after_0x4a6578"
    ]

    all_cursors_stale = all(
        cursor == "0x7a1befdf"
        for sequence in sequences
        for cursor in sequence["failure_cursors"]
    )
    all_failures_scan_eight = all(
        count == 8 for sequence in sequences for count in sequence["failure_scan_counts"]
    )
    status = "border_guard_endpoint_failures_followed_by_7605_5e03_materialization"
    if not sequences or not post_bg_7605:
        status = "border_guard_followthrough_evidence_incomplete"

    return {
        "schema_id": "h3maped_border_guard_followthrough_summary_v1",
        "status": status,
        "source_log": str(log_path),
        "event_count": len(events),
        "event_counts": dict(sorted(counts.items())),
        "border_guard_sequences": sequences,
        "downstream_4a5e03_calls": calls_5e03,
        "post_border_guard_4a5e03_calls": post_bg_5e03,
        "pre_border_guard_4a6578_4a5e03_calls": pre_bg_4a6578_5e03,
        "invariants": {
            "native_behavior_changed": False,
            "three_natural_border_guard_endpoint_pairs_observed": len(sequences) == 3,
            "six_4a5e73_calls_observed": counts["0x004a5e73"] == 6,
            "all_border_guard_4a5e73_calls_failed_at_4a5f84": counts["0x004a5f84"] == 6,
            "all_border_guard_failures_used_stale_f5c": all_cursors_stale,
            "all_border_guard_failures_scanned_eight_d8_entries": all_failures_scan_eight,
            "post_border_guard_7605_4a5e03_calls_observed": len(post_bg_7605) == 2,
            "post_border_guard_4a6578_callsite_not_observed": not any(
                call["caller_class"] == "0x4a61bc_after_0x4a6578"
                for call in post_bg_5e03
            ),
        },
        "interpretation": (
            "The natural Medium seed-10 Border Guard branch attempts three endpoint "
            "pairs through 0x4a64ff/0x4a6531. Each pair calls 0x4a5e73 twice, and "
            "all six calls fail at 0x4a5f84 because generator+0xf5c is the stale "
            "0x7a1befdf value rather than one of the eight active +0xd8 keys. "
            "After those misses, execution does not use the earlier 0x4a61bc "
            "0x4a6578 callsite; it continues into two 0x4a7605-owned 0x4a5e03 "
            "materialization calls. The side effects of 0x4a5e03 remain the next "
            "live replay target."
        ),
        "remaining_blocker": (
            "Recover 0x4a5e03 callee-side generated-cell and object/vector side "
            "effects for the post-Border-Guard 0x4a7605 calls, then connect those "
            "writes back to the relation/control records and generated-cell "
            "before/after state. Until that is captured, the native RMG must not "
            "replace this path with density scalars, brute-force retries, or "
            "final-map delta tuning."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--trace-log", type=Path, default=DEFAULT_TRACE_LOG)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args.trace_log)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(
        "RMG_H3MAPED_BORDER_GUARD_FOLLOWTHROUGH_SUMMARY "
        f"status={summary['status']} "
        f"events={summary['event_count']} "
        f"bg_sequences={len(summary['border_guard_sequences'])} "
        f"post_bg_7605_5e03={sum(1 for call in summary['post_border_guard_4a5e03_calls'] if call['caller_class'] == '0x4a7605_downstream_materialization')} "
        f"out={args.out}"
    )
    return 0 if summary["status"].endswith("materialization") else 1


if __name__ == "__main__":
    raise SystemExit(main())
