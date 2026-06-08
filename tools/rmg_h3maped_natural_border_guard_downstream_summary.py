#!/usr/bin/env python3
"""Summarize a natural selected-Border-Guard downstream H3MapEd replay.

This parses a raw WineDbg log from a source-valid run whose selected candidate
container contains relation records with byte ``+0x09 != 0``. It focuses on
the downstream branch and cursor behavior:

- ``0x4a64e7`` relation/control byte check.
- ``0x4a64ff`` / ``0x4a6531`` Border Guard materialization call sites.
- ``0x4a5e73`` cursor/vector entry state.
- ``0x4a5f84`` early failure when the cursor does not match ``+0xd8`` entries.
- ``0x4a5fd8`` / ``0x4a5ff1`` generated-cell mutation sites when reached.

The report is evidence only. It does not change native RMG behavior.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

from rmg_h3maped_recovery_trace import parse_winedbg_log


DEFAULT_TRACE_LOG = Path(
    ".artifacts/rmg_recovery/medium_seed10_natural_border_guard_downstream_replay_20260608/"
    "winedbg_interactive_trace.log"
)
DEFAULT_OUT = Path(
    ".artifacts/rmg_recovery/medium_seed10_natural_border_guard_downstream_replay_20260608/"
    "natural_border_guard_downstream_summary.json"
)


def flatten_memory_lines(lines: list[dict[str, Any]]) -> list[int]:
    words: list[int] = []
    for line in lines:
        words.extend(int(word) & 0xFFFFFFFF for word in line.get("words", []))
    return words


def words_at(event: dict[str, Any], address: int) -> list[int]:
    for line in event.get("memory_lines", []):
        if int(line.get("address", 0)) == address:
            return [int(word) & 0xFFFFFFFF for word in line.get("words", [])]
    return []


def vector_summary(begin: int, end: int, capacity: int) -> dict[str, Any]:
    return {
        "begin": "0x%08x" % begin,
        "end": "0x%08x" % end,
        "capacity": "0x%08x" % capacity,
        "dword_count": (end - begin) // 4 if end >= begin else -1,
    }


def summarize(log_path: Path) -> dict[str, Any]:
    ledger = parse_winedbg_log(log_path)
    events = ledger.get("events", [])
    counts = Counter(str(event.get("address", "")).lower() for event in events)

    branch_checks: list[dict[str, Any]] = []
    for event_index, event in enumerate(events, start=1):
        if str(event.get("address", "")).lower() != "0x004a64e7":
            continue
        registers = event.get("registers", {})
        record_pointer = int(registers.get("eax", 0))
        record_words = flatten_memory_lines(event.get("memory_lines", [])[2:4])
        control = record_words[2] if len(record_words) > 2 else 0
        branch_checks.append(
            {
                "event_index": event_index,
                "record_pointer": "0x%08x" % record_pointer,
                "control_dword": "0x%08x" % control,
                "border_guard_flag_plus_09": (control >> 8) & 0xFF,
                "raw_dwords": ["0x%08x" % word for word in record_words[:7]],
            }
        )

    entries_5e73: list[dict[str, Any]] = []
    for event_index, event in enumerate(events, start=1):
        if str(event.get("address", "")).lower() != "0x004a5e73":
            continue
        registers = event.get("registers", {})
        generator = int(registers.get("ecx", 0))
        cursor_words = words_at(event, generator + 0xF58)
        d8_words = words_at(event, generator + 0xD8)
        c8_words = words_at(event, generator + 0xC8)
        entries_5e73.append(
            {
                "event_index": event_index,
                "source_record_eax": "0x%08x" % int(registers.get("eax", 0)),
                "generator_ecx": "0x%08x" % generator,
                "cursor_plus_f5c": (
                    "0x%08x" % cursor_words[1]
                    if len(cursor_words) > 1
                    else "missing"
                ),
                "raw_f58_words": ["0x%08x" % word for word in cursor_words],
                "d8_vector": (
                    vector_summary(d8_words[0], d8_words[1], d8_words[2])
                    if len(d8_words) >= 3
                    else {}
                ),
                "c8_vector": (
                    vector_summary(c8_words[0], c8_words[1], c8_words[2])
                    if len(c8_words) >= 3
                    else {}
                ),
            }
        )

    failures_5f84: list[dict[str, Any]] = []
    for event_index, event in enumerate(events, start=1):
        if str(event.get("address", "")).lower() != "0x004a5f84":
            continue
        registers = event.get("registers", {})
        failures_5f84.append(
            {
                "event_index": event_index,
                "eax_scan_count": int(registers.get("eax", -1)),
                "edi_cursor": "0x%08x" % int(registers.get("edi", 0)),
                "edx_d8_begin": "0x%08x" % int(registers.get("edx", 0)),
                "source_arg_esi": "0x%08x" % int(registers.get("esi", 0)),
            }
        )

    branch_bg_count = sum(
        1 for check in branch_checks if check["border_guard_flag_plus_09"] != 0
    )
    success_mutation_count = counts["0x004a5fd8"] + counts["0x004a5ff1"]
    status = "natural_border_guard_branch_reaches_5e73_but_cursor_unseeded"
    if success_mutation_count:
        status = "natural_border_guard_reaches_generated_cell_mutation"
    elif not branch_bg_count:
        status = "no_natural_border_guard_branch_records_observed"

    return {
        "schema_id": "h3maped_natural_border_guard_downstream_summary_v1",
        "status": status,
        "source_log": str(log_path),
        "event_count": len(events),
        "event_counts": dict(sorted(counts.items())),
        "branch_checks": branch_checks,
        "branch_checks_with_border_guard": branch_bg_count,
        "border_guard_call_sites": {
            "0x4a64ff": counts["0x004a64ff"],
            "0x4a6531": counts["0x004a6531"],
        },
        "entries_4a5e73": entries_5e73,
        "failures_4a5f84": failures_5f84,
        "generated_cell_mutation_hits": {
            "0x4a5fd8": counts["0x004a5fd8"],
            "0x4a5ff1": counts["0x004a5ff1"],
            "0x4a606b": counts["0x004a606b"],
        },
        "invariants": {
            "native_behavior_changed": False,
            "natural_border_guard_branch_observed": branch_bg_count > 0,
            "all_4a5e73_entries_failed_at_4a5f84": bool(entries_5e73)
            and len(entries_5e73) == len(failures_5f84),
            "generated_cell_mutation_not_reached": success_mutation_count == 0,
            "cursor_unseeded_value_observed": any(
                entry.get("cursor_plus_f5c") == "0x7a1befdf"
                for entry in entries_5e73
            ),
        },
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
        json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(
        "RMG_H3MAPED_NATURAL_BORDER_GUARD_DOWNSTREAM_SUMMARY "
        f"status={summary['status']} "
        f"events={summary['event_count']} "
        f"bg_branch_checks={summary['branch_checks_with_border_guard']} "
        f"entries_4a5e73={len(summary['entries_4a5e73'])} "
        f"failures_4a5f84={len(summary['failures_4a5f84'])} "
        f"out={args.out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
