#!/usr/bin/env python3
"""Summarize live H3MapEd 0x4a9f1c post-counter branch replay.

This is recovery evidence only. It parses a focused ``winedbg`` trace after the
``0x4a9f1c`` descriptor-type counter checks and classifies the next branch
family that accepts or rejects sampled candidates. It does not change native
RMG behavior.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

from rmg_h3maped_recovery_trace import parse_winedbg_log


TRACE_DIR = Path(".artifacts/rmg_recovery/medium_4a9f1c_post_counter_branch_trace_20260608")
DEFAULT_LEDGER = TRACE_DIR / "winedbg_interactive_trace_ledger.json"
DEFAULT_LOG = TRACE_DIR / "winedbg_interactive_trace.log"
DEFAULT_OUT = Path(".artifacts/rmg_recovery/medium_4a9f1c_post_counter_branch_summary_20260608.json")

CYCLE_START = "0x004a9fd5"
RELATION_COUNTER_BRANCH_SITE = "0x004a9ff7"
VALUE_SCORE_RETURN = "0x004aa004"
LOWER_BOUND_BRANCH_SITE = "0x004aa014"
UPPER_BOUND_BRANCH_SITE = "0x004aa01d"
DESCRIPTOR_SELECT_RETURN = "0x004aa039"
DESCRIPTOR_NULL_BRANCH_SITE = "0x004aa03e"
PLACEMENT_GATE_RETURN = "0x004aa063"
PLACEMENT_GATE_BRANCH_SITE = "0x004aa065"
VALUE_BAND_LOW_BRANCH_SITE = "0x004aa099"
VALUE_BAND_ACCEPT_BRANCH_SITE = "0x004aa0a4"
ACCEPTED_VECTOR_APPEND = "0x004aa0c9"
PLACEMENT_GATE_LOOP = "0x004aa0ec"
LOOP_CONTINUATION = "0x004aa0ef"
SELECTED_CREATE_CALL = "0x004aa166"
SELECTED_CREATE_RETURN = "0x004aa168"


def hex32(value: int | None) -> str | None:
    if value is None:
        return None
    return f"0x{int(value) & 0xFFFFFFFF:08x}"


def signed32(value: int | None) -> int | None:
    if value is None:
        return None
    value = int(value) & 0xFFFFFFFF
    if value & 0x80000000:
        return value - 0x100000000
    return value


def word_at(event: dict[str, Any] | None, address: int | None) -> int | None:
    if not event or address is None:
        return None
    for line in event.get("memory_lines", []):
        base = int(line.get("address", -1))
        words = line.get("words", [])
        byte_delta = int(address) - base
        if byte_delta < 0 or byte_delta % 4 != 0:
            continue
        index = byte_delta // 4
        if 0 <= index < len(words):
            return int(words[index]) & 0xFFFFFFFF
    return None


def first_event(cycle: list[dict[str, Any]], address: str) -> dict[str, Any] | None:
    for event in cycle:
        if event.get("address") == address:
            return event
    return None


def group_cycles(events: list[dict[str, Any]]) -> list[list[dict[str, Any]]]:
    cycle_addresses = {
        CYCLE_START,
        RELATION_COUNTER_BRANCH_SITE,
        VALUE_SCORE_RETURN,
        LOWER_BOUND_BRANCH_SITE,
        UPPER_BOUND_BRANCH_SITE,
        DESCRIPTOR_SELECT_RETURN,
        DESCRIPTOR_NULL_BRANCH_SITE,
        PLACEMENT_GATE_RETURN,
        PLACEMENT_GATE_BRANCH_SITE,
        VALUE_BAND_LOW_BRANCH_SITE,
        VALUE_BAND_ACCEPT_BRANCH_SITE,
        ACCEPTED_VECTOR_APPEND,
        PLACEMENT_GATE_LOOP,
        LOOP_CONTINUATION,
        SELECTED_CREATE_CALL,
        SELECTED_CREATE_RETURN,
    }
    cycles: list[list[dict[str, Any]]] = []
    current: list[dict[str, Any]] | None = None
    for event in events:
        address = event.get("address")
        if address == CYCLE_START:
            current = []
            cycles.append(current)
        if current is None or address not in cycle_addresses:
            continue
        current.append(event)
        if address == LOOP_CONTINUATION or address == SELECTED_CREATE_RETURN:
            current = None
    return cycles


def classify_path(addresses: list[str]) -> str:
    if LOOP_CONTINUATION not in addresses and SELECTED_CREATE_RETURN not in addresses:
        return "incomplete_trace_cut"
    if VALUE_SCORE_RETURN not in addresses:
        return "incomplete_before_value_score"
    if LOWER_BOUND_BRANCH_SITE not in addresses:
        return "value_score_negative"
    if UPPER_BOUND_BRANCH_SITE not in addresses:
        return "value_below_lower_bound"
    if DESCRIPTOR_SELECT_RETURN not in addresses:
        return "value_above_upper_bound"
    if DESCRIPTOR_NULL_BRANCH_SITE in addresses and ACCEPTED_VECTOR_APPEND not in addresses:
        return "descriptor_selection_null"
    if PLACEMENT_GATE_BRANCH_SITE in addresses and PLACEMENT_GATE_LOOP in addresses:
        return "placement_gate_rejected"
    if VALUE_BAND_LOW_BRANCH_SITE in addresses and ACCEPTED_VECTOR_APPEND not in addresses:
        return "value_band_floor_rejected"
    if ACCEPTED_VECTOR_APPEND in addresses:
        return "accepted_candidate_appended"
    if SELECTED_CREATE_RETURN in addresses:
        return "selected_create_returned"
    return "unclassified_post_counter_path"


def candidate_words(event: dict[str, Any] | None, candidate_pointer: int | None) -> list[int]:
    if event is None or candidate_pointer is None:
        return []
    for line in event.get("memory_lines", []):
        if int(line.get("address", -1)) == int(candidate_pointer):
            return [int(word) & 0xFFFFFFFF for word in line.get("words", [])]
    return []


def classify_cycle(cycle: list[dict[str, Any]]) -> dict[str, Any]:
    start = first_event(cycle, CYCLE_START)
    score_event = first_event(cycle, VALUE_SCORE_RETURN)
    descriptor_event = first_event(cycle, DESCRIPTOR_SELECT_RETURN)
    append_event = first_event(cycle, ACCEPTED_VECTOR_APPEND)
    terminal = first_event(cycle, LOOP_CONTINUATION) or first_event(cycle, SELECTED_CREATE_RETURN)
    addresses = [event.get("address") for event in cycle]

    start_regs = start.get("registers", {}) if start else {}
    score_regs = score_event.get("registers", {}) if score_event else {}
    descriptor_regs = descriptor_event.get("registers", {}) if descriptor_event else {}
    append_regs = append_event.get("registers", {}) if append_event else {}
    ebp = start_regs.get("ebp")
    candidate_pointer = start_regs.get("ecx")
    words = candidate_words(start, candidate_pointer)

    lower_bound = signed32(word_at(start, ebp + 0x0C if isinstance(ebp, int) else None))
    upper_bound = signed32(word_at(start, ebp + 0x10 if isinstance(ebp, int) else None))
    score = signed32(score_regs.get("eax"))
    descriptor_pointer = descriptor_regs.get("eax")

    return {
        "path_class": classify_path(addresses),
        "complete_cycle": terminal is not None,
        "observed_addresses": addresses,
        "type_index": start_regs.get("esi"),
        "candidate_pointer": hex32(candidate_pointer),
        "candidate_vtable": hex32(words[0]) if len(words) > 0 else None,
        "candidate_type_field": signed32(words[1]) if len(words) > 1 else None,
        "candidate_value_field": signed32(words[3]) if len(words) > 3 else None,
        "candidate_weight_field": signed32(words[4]) if len(words) > 4 else None,
        "lower_bound": lower_bound,
        "upper_bound": upper_bound,
        "value_score_return": score,
        "descriptor_selection_return": hex32(descriptor_pointer),
        "accepted_weight_total_after_append": signed32(append_regs.get("eax")),
        "terminal_address": terminal.get("address") if terminal else None,
    }


def count_by_type_and_path(cycles: list[dict[str, Any]]) -> list[dict[str, Any]]:
    grouped: dict[tuple[str, str], int] = Counter()
    for cycle in cycles:
        type_index = cycle.get("type_index")
        type_key = str(type_index) if isinstance(type_index, int) else "unknown"
        grouped[(type_key, str(cycle.get("path_class")))] += 1
    return [
        {"type_index": type_key, "path_class": path_class, "count": count}
        for (type_key, path_class), count in sorted(grouped.items())
    ]


def value_ranges_by_path(cycles: list[dict[str, Any]]) -> list[dict[str, Any]]:
    grouped: dict[str, list[int]] = defaultdict(list)
    for cycle in cycles:
        score = cycle.get("value_score_return")
        if isinstance(score, int):
            grouped[str(cycle.get("path_class"))].append(score)
    rows: list[dict[str, Any]] = []
    for path_class, values in sorted(grouped.items()):
        rows.append(
            {
                "path_class": path_class,
                "min_value_score": min(values),
                "max_value_score": max(values),
                "sample_count": len(values),
            }
        )
    return rows


def load_metadata(ledger_path: Path) -> dict[str, Any]:
    if not ledger_path.exists():
        return {}
    data = json.loads(ledger_path.read_text(encoding="utf-8"))
    return {
        "ledger_path": str(ledger_path),
        "breakpoints": data.get("breakpoints", []),
        "address_commands": data.get("address_command", []),
        "max_events": data.get("max_events"),
        "schema_id": data.get("schema_id"),
    }


def build_summary(log_path: Path, ledger_path: Path) -> dict[str, Any]:
    parsed = parse_winedbg_log(log_path)
    cycles = [classify_cycle(cycle) for cycle in group_cycles(parsed["events"])]
    path_counts = Counter(str(cycle.get("path_class")) for cycle in cycles)
    complete_cycles = [cycle for cycle in cycles if cycle.get("complete_cycle")]
    selected_create_cycles = [
        cycle for cycle in cycles if SELECTED_CREATE_RETURN in cycle.get("observed_addresses", [])
    ]

    return {
        "status": "passed_live_replay_post_counter_paths_classified" if complete_cycles else "failed_no_complete_cycles",
        "native_behavior_changed": False,
        "scope": "live same-run post-counter 0x4a9f1c branch replay for sampled candidates",
        "trace": {
            "log_path": str(log_path),
            **load_metadata(ledger_path),
        },
        "event_count": parsed["event_count"],
        "candidate_cycle_count": len(cycles),
        "complete_candidate_cycles": len(complete_cycles),
        "incomplete_trace_cut_cycles": path_counts.get("incomplete_trace_cut", 0),
        "path_counts": dict(sorted(path_counts.items())),
        "type_path_counts": count_by_type_and_path(cycles),
        "value_score_ranges_by_path": value_ranges_by_path(cycles),
        "selected_create_cycles": len(selected_create_cycles),
        "first_cycles_by_path": {
            path_class: next(cycle for cycle in cycles if cycle.get("path_class") == path_class)
            for path_class in sorted(path_counts)
        },
        "recovered_contract": [
            "After sampled counter checks pass, 0x4a9f1c calls the candidate vtable +0x04 scorer and stores the signed return as the candidate value.",
            "A negative value score branches directly to 0x4aa0ef before lower-bound comparison.",
            "Nonnegative scores below stack lower bound [EBP+0x0c] branch to 0x4aa0ef at the lower-bound site.",
            "Scores above stack upper bound [EBP+0x10] branch to 0x4aa0ef at the upper-bound site.",
            "Candidates that pass value bounds call 0x4a9e40 for descriptor selection and, when accepted, append candidate/descriptor entries before looping.",
        ],
        "explicit_non_claims": [
            "This report classifies a bounded Medium trace; it does not prove these are the only possible post-counter branches.",
            "This report does not capture final selected-object creation through 0x4aa166/0x4aa168.",
            "This report does not name candidate vtable implementations or descriptor type semantics.",
            "This report does not justify native RMG density scalars, retries, new gates, or final-map delta tuning.",
        ],
        "remaining_blockers": [
            "Capture the final accepted-vector selection and selected-create path through 0x4aa166/0x4aa168 in the same branch framing.",
            "Name candidate vtable +0x04 scorer implementations and descriptor type semantics from source-backed data.",
            "Recover a generation path that actually reaches 0x4add76 cleanup/uncommit.",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log", type=Path, default=DEFAULT_LOG)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    if not args.log.exists():
        raise SystemExit(f"missing trace log: {args.log}")

    summary = build_summary(args.log, args.ledger)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_4A9F1C_POST_COUNTER_BRANCH_SUMMARY "
        f"status={summary['status']} complete_cycles={summary['complete_candidate_cycles']} out={args.out}"
    )
    return 1 if summary["status"].startswith("failed") else 0


if __name__ == "__main__":
    raise SystemExit(main())
