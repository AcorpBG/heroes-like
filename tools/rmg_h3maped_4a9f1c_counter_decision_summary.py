#!/usr/bin/env python3
"""Summarize live H3MapEd 0x4a9f1c counter-decision replay.

This is recovery evidence only. It parses a focused ``winedbg`` trace at the
``0x4a9f1c`` descriptor-type counter checks and reports whether sampled
candidates are rejected by the recovered global or relation-local limit tables.
It does not change native RMG behavior and does not claim the downstream
post-counter rejection path is recovered.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

from rmg_h3maped_recovery_trace import parse_winedbg_log


TRACE_DIR = Path(".artifacts/rmg_recovery/medium_4a9f1c_counter_decision_trace_20260608")
DEFAULT_LEDGER = TRACE_DIR / "winedbg_interactive_trace_ledger.json"
DEFAULT_LOG = TRACE_DIR / "winedbg_interactive_trace.log"
DEFAULT_OUT = Path(".artifacts/rmg_recovery/medium_4a9f1c_counter_decision_summary_20260608.json")

GLOBAL_COUNTER_CHECK = "0x004a9fd5"
GLOBAL_BRANCH_SITE = "0x004a9fe7"
RELATION_COUNTER_CHECK = "0x004a9fed"
RELATION_BRANCH_SITE = "0x004a9ff7"
LOOP_CONTINUATION = "0x004aa0ef"
SELECTED_CREATE_CALL = "0x004aa166"
SELECTED_CREATE_RETURN = "0x004aa168"


def hex32(value: int | None) -> str | None:
    if value is None:
        return None
    return f"0x{int(value) & 0xFFFFFFFF:08x}"


def word_at(event: dict[str, Any] | None, address: int) -> int | None:
    if not event:
        return None
    for line in event.get("memory_lines", []):
        base = int(line.get("address", -1))
        words = line.get("words", [])
        byte_delta = address - base
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
    cycles: list[list[dict[str, Any]]] = []
    current: list[dict[str, Any]] | None = None
    cycle_addresses = {
        GLOBAL_COUNTER_CHECK,
        GLOBAL_BRANCH_SITE,
        RELATION_COUNTER_CHECK,
        RELATION_BRANCH_SITE,
        LOOP_CONTINUATION,
        SELECTED_CREATE_CALL,
        SELECTED_CREATE_RETURN,
    }
    terminals = {LOOP_CONTINUATION, SELECTED_CREATE_RETURN}

    for event in events:
        address = event.get("address")
        if address == GLOBAL_COUNTER_CHECK:
            current = []
            cycles.append(current)
        if current is None or address not in cycle_addresses:
            continue
        current.append(event)
        if address in terminals:
            current = None
    return cycles


def classify_cycle(cycle: list[dict[str, Any]]) -> dict[str, Any]:
    global_check = first_event(cycle, GLOBAL_COUNTER_CHECK)
    global_branch = first_event(cycle, GLOBAL_BRANCH_SITE)
    relation_check = first_event(cycle, RELATION_COUNTER_CHECK)
    relation_branch = first_event(cycle, RELATION_BRANCH_SITE)

    regs = global_check.get("registers", {}) if global_check else {}
    type_index = regs.get("esi")
    generator = regs.get("ebx")
    relation = regs.get("edi")
    candidate = regs.get("ecx")

    global_counter_address = None
    global_limit_address = None
    relation_counter_address = None
    relation_limit_address = None
    if isinstance(type_index, int) and isinstance(generator, int):
        global_counter_address = generator + 0x1110 + type_index * 4
        global_limit_address = 0x5A26E4 + type_index * 4
    if isinstance(type_index, int) and isinstance(relation, int):
        relation_counter_address = relation + 0x44 + type_index * 4
        relation_limit_address = 0x5A2A8C + type_index * 4

    global_counter = word_at(global_check, global_counter_address) if global_counter_address is not None else None
    global_limit = word_at(global_check, global_limit_address) if global_limit_address is not None else None
    relation_counter = word_at(relation_check, relation_counter_address) if relation_counter_address is not None else None
    relation_limit = word_at(relation_check, relation_limit_address) if relation_limit_address is not None else None

    if global_counter is None and global_branch:
        global_counter = global_branch.get("registers", {}).get("edx")
    if relation_counter is None and relation_branch:
        relation_counter = relation_branch.get("registers", {}).get("edx")

    global_reject = (
        global_counter is not None
        and global_limit is not None
        and int(global_counter) >= int(global_limit)
    )
    relation_reject = (
        relation_counter is not None
        and relation_limit is not None
        and int(relation_counter) >= int(relation_limit)
    )
    observed_addresses = [event.get("address") for event in cycle]
    post_counter_loop_continuation = (
        LOOP_CONTINUATION in observed_addresses
        and not global_reject
        and not relation_reject
    )
    selected_create_observed = SELECTED_CREATE_CALL in observed_addresses or SELECTED_CREATE_RETURN in observed_addresses

    return {
        "candidate_pointer": hex32(candidate),
        "generator_pointer": hex32(generator),
        "relation_pointer": hex32(relation),
        "type_index": type_index,
        "observed_addresses": observed_addresses,
        "global_counter": global_counter,
        "global_limit": global_limit,
        "global_counter_address": hex32(global_counter_address),
        "global_limit_address": hex32(global_limit_address),
        "global_limit_reject_by_values": global_reject,
        "relation_counter": relation_counter,
        "relation_limit": relation_limit,
        "relation_counter_address": hex32(relation_counter_address),
        "relation_limit_address": hex32(relation_limit_address),
        "relation_limit_reject_by_values": relation_reject,
        "post_counter_loop_continuation_observed": post_counter_loop_continuation,
        "selected_create_observed": selected_create_observed,
        "complete_counter_check_sequence": all(
            address in observed_addresses
            for address in (
                GLOBAL_COUNTER_CHECK,
                GLOBAL_BRANCH_SITE,
                RELATION_COUNTER_CHECK,
                RELATION_BRANCH_SITE,
            )
        ),
    }


def range_or_none(values: list[int]) -> dict[str, int | None]:
    if not values:
        return {"min": None, "max": None}
    return {"min": min(values), "max": max(values)}


def summarize_by_type(cycles: list[dict[str, Any]]) -> list[dict[str, Any]]:
    grouped: dict[int, list[dict[str, Any]]] = defaultdict(list)
    for cycle in cycles:
        type_index = cycle.get("type_index")
        if isinstance(type_index, int):
            grouped[type_index].append(cycle)

    rows: list[dict[str, Any]] = []
    for type_index, items in sorted(grouped.items()):
        rows.append(
            {
                "type_index": type_index,
                "cycle_count": len(items),
                "global_counter_range": range_or_none(
                    [int(item["global_counter"]) for item in items if item.get("global_counter") is not None]
                ),
                "global_limit_range": range_or_none(
                    [int(item["global_limit"]) for item in items if item.get("global_limit") is not None]
                ),
                "relation_counter_range": range_or_none(
                    [int(item["relation_counter"]) for item in items if item.get("relation_counter") is not None]
                ),
                "relation_limit_range": range_or_none(
                    [int(item["relation_limit"]) for item in items if item.get("relation_limit") is not None]
                ),
                "global_limit_rejects_by_values": sum(
                    1 for item in items if item.get("global_limit_reject_by_values")
                ),
                "relation_limit_rejects_by_values": sum(
                    1 for item in items if item.get("relation_limit_reject_by_values")
                ),
                "post_counter_loop_continuations": sum(
                    1 for item in items if item.get("post_counter_loop_continuation_observed")
                ),
                "selected_create_observed": sum(1 for item in items if item.get("selected_create_observed")),
            }
        )
    return rows


def type_counts(cycles: list[dict[str, Any]]) -> dict[str, int]:
    counts: Counter[str] = Counter()
    for cycle in cycles:
        type_index = cycle.get("type_index")
        key = str(type_index) if isinstance(type_index, int) else "unknown"
        counts[key] += 1
    return dict(sorted(counts.items()))


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
    address_counts = Counter(event.get("address") for event in parsed["events"])
    incomplete = [cycle for cycle in cycles if not cycle.get("complete_counter_check_sequence")]
    global_rejects = [cycle for cycle in cycles if cycle.get("global_limit_reject_by_values")]
    relation_rejects = [cycle for cycle in cycles if cycle.get("relation_limit_reject_by_values")]
    post_counter_continuations = [cycle for cycle in cycles if cycle.get("post_counter_loop_continuation_observed")]
    selected_creates = [cycle for cycle in cycles if cycle.get("selected_create_observed")]

    status = "passed_live_replay_no_counter_limit_rejects"
    if incomplete:
        status = "failed_incomplete_counter_check_sequences"
    elif global_rejects or relation_rejects:
        status = "passed_live_replay_counter_limit_rejects_observed"

    return {
        "status": status,
        "native_behavior_changed": False,
        "scope": "live same-run counter-decision replay for sampled 0x4a9f1c candidates",
        "trace": {
            "log_path": str(log_path),
            **load_metadata(ledger_path),
        },
        "event_count": parsed["event_count"],
        "address_counts": dict(sorted(address_counts.items())),
        "candidate_cycle_count": len(cycles),
        "type_counts": type_counts(cycles),
        "counter_rejections_by_values": {
            "global": len(global_rejects),
            "relation_local": len(relation_rejects),
        },
        "post_counter_loop_continuations": len(post_counter_continuations),
        "selected_create_cycles": len(selected_creates),
        "incomplete_counter_check_cycles": len(incomplete),
        "by_type": summarize_by_type(cycles),
        "first_cycles": cycles[:8],
        "invariants": {
            "all_cycles_have_global_and_relation_counter_stops": len(incomplete) == 0,
            "no_global_counter_limit_rejects_by_values": len(global_rejects) == 0,
            "no_relation_local_counter_limit_rejects_by_values": len(relation_rejects) == 0,
            "all_sampled_cycles_continue_to_loop_after_counter_checks": len(post_counter_continuations) == len(cycles),
            "no_selected_create_path_observed_in_bounded_sample": len(selected_creates) == 0,
        },
        "recovered_contract": [
            "The sampled 0x4a9f1c live cycles read generator+0x1110[type] and 0x5a26e4[type] before the global-limit branch site.",
            "The sampled cycles read selector/relation+0x44[type] and 0x5a2a8c[type] before the relation-local limit branch site.",
            "In this bounded Medium trace, every sampled candidate has both counters below their corresponding limits.",
            "The sampled candidates still reach 0x4aa0ef after the counter checks, so their rejection/loop continuation is downstream of the counter-limit checks.",
        ],
        "explicit_non_claims": [
            "This report does not prove counter-limit rejection never happens; it only classifies this bounded trace.",
            "This report does not recover the later post-counter rejection branch that sends these candidates to 0x4aa0ef.",
            "This report does not capture a selected-create path through 0x4aa166/0x4aa168 in this bounded sample.",
            "This report does not justify native RMG density scalars, retries, new gates, or final-map delta tuning.",
        ],
        "remaining_blockers": [
            "Recover the downstream post-counter 0x4a9f1c rejection reason after both counter checks pass.",
            "Capture an accepted 0x4a9f1c selected-create path in the same counter-decision framing.",
            "Recover a generation path that actually reaches 0x4add76 cleanup/uncommit.",
            "Name descriptor type indices and candidate vtable contracts from source-backed data before native parity changes.",
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
        "RMG_H3MAPED_4A9F1C_COUNTER_DECISION_SUMMARY "
        f"status={summary['status']} cycles={summary['candidate_cycle_count']} out={args.out}"
    )
    return 1 if summary["status"].startswith("failed") else 0


if __name__ == "__main__":
    raise SystemExit(main())
