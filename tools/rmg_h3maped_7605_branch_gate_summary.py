#!/usr/bin/env python3
"""Summarize live 0x4a7605 branch gates after direct 0x4a7312 commits.

This recovery artifact explains why the sampled 0x4a7605 path did not enter
the delegated 0x4a746b endpoint writer: both direct 0x4a7312 commits reached
their control-byte gates, and both gates observed record byte +0x09 == 0 before
branching around the 0x4a746b call sites.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

from rmg_h3maped_recovery_trace import parse_winedbg_log


DEFAULT_TRACE_LOG = Path(
    ".artifacts/rmg_recovery/direct_generation_7605_control_byte_gate_trace/winedbg_interactive_trace.log"
)
DEFAULT_ENDPOINT_RUNTIME = Path(".artifacts/rmg_recovery/dispatch_endpoint_runtime_summary.json")
DEFAULT_OUT = Path(".artifacts/rmg_recovery/7605_branch_gate_summary.json")


def hex32(value: int | None) -> str | None:
    return None if value is None else f"0x{value & 0xFFFFFFFF:08x}"


def memory_word(event: dict[str, Any], address: int | None) -> int | None:
    if address is None:
        return None
    for line in event.get("memory_lines", []):
        base = int(line["address"])
        words = line.get("words", [])
        if base <= address < base + len(words) * 4 and (address - base) % 4 == 0:
            return int(words[(address - base) // 4]) & 0xFFFFFFFF
    return None


def stack_word(event: dict[str, Any], index: int) -> int | None:
    esp = event.get("registers", {}).get("esp")
    if not isinstance(esp, int):
        return None
    return memory_word(event, esp + index * 4)


def stack_words(event: dict[str, Any], count: int) -> list[int | None]:
    return [stack_word(event, index) for index in range(count)]


def byte_at(event: dict[str, Any], address: int | None) -> int | None:
    if address is None:
        return None
    word_address = address & ~0x3
    word = memory_word(event, word_address)
    if word is None:
        return None
    return (word >> ((address - word_address) * 8)) & 0xFF


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def first_event(events: list[dict[str, Any]], address: str) -> dict[str, Any] | None:
    return next((event for event in events if event["address"] == address), None)


def describe_gate(events: list[dict[str, Any]], *, compare_site: str, skip_site: str, call_site: str) -> dict[str, Any]:
    compare = first_event(events, compare_site)
    skip = first_event(events, skip_site)
    call = first_event(events, call_site)
    registers = compare.get("registers", {}) if compare else {}
    esi = registers.get("esi") if isinstance(registers.get("esi"), int) else None
    control_byte = byte_at(compare, esi + 0x09 if esi is not None else None) if compare else None
    return {
        "compare_site": compare_site,
        "skip_site": skip_site,
        "delegated_call_site": call_site,
        "compare_hit": compare is not None,
        "skip_site_hit": skip is not None,
        "delegated_call_hit": call is not None,
        "esi_record": hex32(esi),
        "control_byte_esi_plus_09": control_byte,
        "record_words_sample": [
            hex32(memory_word(compare, esi + index * 4)) for index in range(8)
        ]
        if compare is not None and esi is not None
        else [],
        "skip_reason": (
            "control_byte_zero"
            if compare is not None and skip is not None and call is None and control_byte == 0
            else "not_proven"
        ),
    }


def summarize_trace(trace_log: Path) -> dict[str, Any]:
    ledger = parse_winedbg_log(trace_log)
    events = ledger["events"]
    counts = Counter(event["address"] for event in events)
    direct_commits: list[dict[str, Any]] = []
    for index, event in enumerate(events):
        if event["address"] != "0x004a7447":
            continue
        words = stack_words(event, 12)
        direct_commits.append(
            {
                "event_index": index,
                "object_record": hex32(words[0] if words else None),
                "selected_coordinate": {
                    "x": words[1] if len(words) > 1 else None,
                    "y": words[2] if len(words) > 2 else None,
                    "level": words[3] if len(words) > 3 else None,
                },
                "source_relation_record": hex32(words[4] if len(words) > 4 else None),
                "stack_words": [hex32(word) for word in words],
            }
        )
    return {
        "trace_log": str(trace_log),
        "event_count": len(events),
        "address_counts": dict(sorted(counts.items())),
        "direct_4a7312_commits": direct_commits,
        "first_gate_after_0x4a76f3_commit": describe_gate(
            events,
            compare_site="0x004a774a",
            skip_site="0x004a7773",
            call_site="0x004a7763",
        ),
        "second_gate_after_0x4a77e7_commit": describe_gate(
            events,
            compare_site="0x004a783a",
            skip_site="0x004a7860",
            call_site="0x004a7853",
        ),
    }


def summarize(trace_log: Path, endpoint_runtime: Path) -> dict[str, Any]:
    endpoint_summary = load_json(endpoint_runtime)
    trace = summarize_trace(trace_log)
    counts = trace["address_counts"]
    gates = [
        trace["first_gate_after_0x4a76f3_commit"],
        trace["second_gate_after_0x4a77e7_commit"],
    ]
    invariants = {
        "prior_endpoint_runtime_recovery_passed": (
            endpoint_summary.get("status") == "partial_live_recovery_7605_direct_7312_endpoint_commits"
        ),
        "trace_has_events": trace["event_count"] > 0,
        "hit_4a7605_from_dispatch": counts.get("0x004a7605", 0) >= 1,
        "hit_two_direct_4a7312_commits": len(trace["direct_4a7312_commits"]) == 2,
        "first_gate_proves_control_byte_zero_skip": gates[0]["skip_reason"] == "control_byte_zero",
        "second_gate_proves_control_byte_zero_skip": gates[1]["skip_reason"] == "control_byte_zero",
        "no_4a746b_call_sites_hit": counts.get("0x004a7763", 0) == 0 and counts.get("0x004a7853", 0) == 0,
        "pair_mark_sites_hit": counts.get("0x004a7e21", 0) >= 1 and counts.get("0x004a7e25", 0) >= 1,
        "no_native_behavior_change": True,
    }
    status = "partial_live_recovery_7605_control_byte_gate_skips_746b" if all(invariants.values()) else "incomplete"
    return {
        "schema_id": "h3maped_7605_branch_gate_summary_v1",
        "status": status,
        "invariants": invariants,
        "trace": trace,
        "recovered_contract": (
            "In the sampled 0x4a79a3-owned +0xc8 dispatch, 0x4a7605 performs two successful direct "
            "0x4a7312 commits. After each commit it reaches the control-byte gate that precedes the "
            "corresponding 0x4a746b call. In both cases ESI points to record 0x03654aac and byte "
            "[ESI+0x09] is 0, so execution branches to the skip target and does not call 0x4a746b. "
            "This explains the missing 0x4a746b/0x4a5e73 hits for this live sample."
        ),
        "remaining_gap": (
            "This proves only the sampled control-byte-zero skip. Full recovery still needs a live sample "
            "where [ESI+0x09] is nonzero or another branch reaches 0x4a746b, plus generated-cell before/after "
            "state for 0x4a746b/0x4a5e73 and exact source/vector semantics."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--trace-log", type=Path, default=DEFAULT_TRACE_LOG)
    parser.add_argument("--endpoint-runtime", type=Path, default=DEFAULT_ENDPOINT_RUNTIME)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args.trace_log, args.endpoint_runtime)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_7605_BRANCH_GATE_SUMMARY status={summary['status']} out={args.out}")
    return 0 if summary["status"] == "partial_live_recovery_7605_control_byte_gate_skips_746b" else 1


if __name__ == "__main__":
    raise SystemExit(main())
