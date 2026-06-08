#!/usr/bin/env python3
"""Summarize the forced +0x09 Border Guard route trace.

This is recovery evidence for the control-flow meaning of relation/control
byte +0x09 in the sampled 0x4a7605 path. The trace deliberately flips the byte
at 0x4a774a, so it is not natural-generation proof. It proves what the flag
routes into, and what still does not happen downstream.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_LEDGER = Path(
    ".artifacts/rmg_recovery/"
    "direct_generation_forced_border_guard_byte_probe_20260607_candidate1/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_OUT = Path(".artifacts/rmg_recovery/forced_border_guard_route_summary_20260608.json")


def hex32(value: int | None) -> str | None:
    return None if value is None else f"0x{value & 0xFFFFFFFF:08x}"


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def memory_word(event: dict[str, Any], address: int | None) -> int | None:
    if address is None:
        return None
    # Address commands can dump the same range before and after a debugger-side
    # mutation. Use the last matching line so forced-byte traces summarize the
    # post-command state that execution continued with.
    for line in reversed(event.get("memory_lines", [])):
        base = int(line["address"])
        words = [int(word) for word in line.get("words", [])]
        if base <= address < base + len(words) * 4 and (address - base) % 4 == 0:
            return words[(address - base) // 4] & 0xFFFFFFFF
    return None


def stack_words(event: dict[str, Any], count: int) -> list[int | None]:
    esp = event.get("registers", {}).get("esp")
    if not isinstance(esp, int):
        return []
    return [memory_word(event, esp + index * 4) for index in range(count)]


def first_words_at(event: dict[str, Any], address: int | None, count: int) -> list[int | None]:
    if address is None:
        return []
    return [memory_word(event, address + index * 4) for index in range(count)]


def event_summary(event: dict[str, Any], index: int) -> dict[str, Any]:
    regs = event.get("registers", {})
    stack = stack_words(event, 10)
    esi = regs.get("esi") if isinstance(regs.get("esi"), int) else None
    return {
        "event_index": index,
        "address": event["address"],
        "return_address": hex32(stack[0] if stack else None),
        "registers": {key: hex32(regs.get(key)) for key in ["eax", "ebx", "ecx", "edx", "esi", "edi", "ebp", "esp"]},
        "stack_words": [hex32(word) for word in stack],
        "esi_first_12_dwords": [hex32(word) for word in first_words_at(event, esi, 12)],
        "esi_plus_8_first_dword": hex32(memory_word(event, esi + 8) if esi is not None else None),
        "esi_plus_09_byte_from_dump": (
            ((memory_word(event, esi + 8) or 0) >> 8) & 0xFF if esi is not None else None
        ),
    }


def summarize(ledger_path: Path) -> dict[str, Any]:
    ledger = load_json(ledger_path)
    events = ledger.get("events", [])
    counts = Counter(event.get("address") for event in events)

    selected_events = [event_summary(event, index) for index, event in enumerate(events)]
    first_flag_event = next(
        (event for event in selected_events if event["address"] == "0x004a774a"),
        None,
    )
    second_flag_event = next(
        (event for event in selected_events if event["address"] == "0x004a783a"),
        None,
    )
    route_pairs: list[dict[str, Any]] = []
    pending: dict[str, Any] | None = None
    for event in selected_events:
        address = event["address"]
        if address == "0x004a746b":
            pending = {
                "call_4a746b": event,
                "call_4a7593": None,
                "call_4a5e73": None,
                "post_return": None,
            }
        elif pending is not None and address == "0x004a7593":
            pending["call_4a7593"] = event
        elif pending is not None and address == "0x004a5e73":
            pending["call_4a5e73"] = event
        elif pending is not None and address in {"0x004a7773", "0x004a7860"}:
            pending["post_return"] = event
            route_pairs.append(pending)
            pending = None

    mutation_hits = {
        "0x4a5fd8_clear_cell_2c": counts.get("0x004a5fd8", 0),
        "0x4a5ff1_write_cell_28": counts.get("0x004a5ff1", 0),
        "0x4a75f1_success_exit": counts.get("0x004a75f1", 0),
    }
    invariants = {
        "native_behavior_changed": False,
        "trace_is_forced_not_natural": True,
        "forced_first_record_plus_09_seen": bool(first_flag_event)
        and first_flag_event["esi_plus_09_byte_from_dump"] == 1,
        "second_record_plus_09_remained_set": bool(second_flag_event)
        and second_flag_event["esi_plus_09_byte_from_dump"] == 1,
        "two_4a746b_calls_observed": counts.get("0x004a746b", 0) == 2,
        "two_4a7593_to_4a5e73_delegations_observed": counts.get("0x004a7593", 0) == 2
        and counts.get("0x004a5e73", 0) == 2,
        "two_failed_returns_observed": counts.get("0x004a7773", 0) == 1
        and counts.get("0x004a7860", 0) == 1,
        "generated_cell_mutation_not_reached": all(count == 0 for count in mutation_hits.values()),
    }
    pass_invariants = {key: value for key, value in invariants.items() if key != "native_behavior_changed"}
    status = (
        "forced_plus09_routes_to_4a746b_5e73_without_mutation"
        if invariants["native_behavior_changed"] is False and all(pass_invariants.values())
        else "forced_plus09_route_evidence_incomplete"
    )
    return {
        "schema_id": "h3maped_forced_border_guard_route_summary_v1",
        "status": status,
        "ledger": str(ledger_path),
        "event_count": len(events),
        "address_counts": dict(sorted(counts.items())),
        "first_forced_flag_event": first_flag_event,
        "second_flag_event": second_flag_event,
        "route_pairs": route_pairs,
        "mutation_hits": mutation_hits,
        "invariants": invariants,
        "recovered_contract": (
            "When the sampled 0x4a7605 relation/control byte +0x09 is forced to 1 at "
            "0x4a774a, execution enters two 0x4a746b endpoint-writer calls. Each call "
            "delegates through 0x4a7593 into 0x4a5e73 and returns through the failure "
            "continuations 0x4a7773 and 0x4a7860. The generated-cell mutation sites "
            "0x4a5fd8/0x4a5ff1 and the 0x4a746b success exit 0x4a75f1 are not reached."
        ),
        "remaining_gap": (
            "This forced-byte trace proves the +0x09 route shape, but not a natural successful "
            "Border Guard endpoint materialization. End-to-end recovery still needs a natural "
            "+0x09 path with 0x4a5e73 cursor/vector state that reaches 0x4a5fd8/0x4a5ff1, "
            "or ordered evidence proving those mutation sites are not reachable for the target "
            "one-level land generation mode."
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
    print(f"RMG_H3MAPED_FORCED_BORDER_GUARD_ROUTE_SUMMARY status={summary['status']} out={args.out}")
    return 0 if summary["status"] == "forced_plus09_routes_to_4a746b_5e73_without_mutation" else 1


if __name__ == "__main__":
    raise SystemExit(main())
