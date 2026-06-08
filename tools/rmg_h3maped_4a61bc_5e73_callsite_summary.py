#!/usr/bin/env python3
"""Summarize the first natural seed-10 0x4a61bc -> 0x4a5e73 failure.

This report joins two focused WineDbg ledgers:

- the first ``0x4a61bc`` Border Guard call site through ``0x4a5f84``;
- the matching ``0x4a5e73`` ``+0xd8`` scan with one stop per compared record.

It verifies the first natural Border Guard materialization attempt calls
``0x4a5e73`` with normal coordinate arguments, but fails before any ``+0xc8``
lookup because ``generator+0xf5c`` is a stale/unseeded value while the ``+0xd8``
record keys are the compact range ``0..7``.

The report is recovery evidence only. It does not change native RMG behavior.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_CALLSITE_LEDGER = Path(
    ".artifacts/rmg_recovery/medium_seed10_4a61bc_first_5f84_callsite_probe_20260608/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_D8_SCAN_LEDGER = Path(
    ".artifacts/rmg_recovery/medium_seed10_4a5e73_d8_scan_probe_20260608/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_OUT = Path(
    ".artifacts/rmg_recovery/medium_seed10_4a61bc_5e73_callsite_summary_20260608.json"
)


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def words_at(event: dict[str, Any], address: int) -> list[int]:
    for line in event.get("memory_lines", []):
        if int(line.get("address", 0)) == address:
            return [int(word) & 0xFFFFFFFF for word in line.get("words", [])]
    return []


def contiguous_words(event: dict[str, Any], address: int, line_count: int = 2) -> list[int]:
    words: list[int] = []
    cursor = address
    for _ in range(line_count):
        line_words = words_at(event, cursor)
        if not line_words:
            break
        words.extend(line_words)
        cursor += len(line_words) * 4
    return words


def vector_header(event: dict[str, Any], base_address: int) -> dict[str, Any]:
    words = words_at(event, base_address)
    if len(words) < 3:
        return {}
    begin, end, capacity = words[:3]
    return {
        "begin": "0x%08x" % begin,
        "end": "0x%08x" % end,
        "capacity": "0x%08x" % capacity,
        "dword_count": (end - begin) // 4 if end >= begin else -1,
    }


def parse_callsite(callsite_ledger: dict[str, Any]) -> dict[str, Any]:
    events = callsite_ledger.get("events", [])
    if [event.get("address") for event in events] != [
        "0x004a64ff",
        "0x004a5e73",
        "0x004a5ed7",
        "0x004a5f84",
    ]:
        raise ValueError("callsite ledger does not match expected first-failure event order")

    callsite = events[0]
    entry = events[1]
    failure_cmp = events[2]
    failure = events[3]
    entry_regs = entry.get("registers", {})
    generator = int(entry_regs.get("ecx", 0))
    stack_words = contiguous_words(entry, int(entry_regs.get("esp", 0)), 2)
    if len(stack_words) < 6:
        raise ValueError("0x4a5e73 entry stack dump is incomplete")

    callsite_regs = callsite.get("registers", {})
    callsite_stack = contiguous_words(callsite, int(callsite_regs.get("esp", 0)), 2)
    callsite_name = "unknown"
    if str(callsite.get("address", "")).lower() == "0x004a64ff":
        callsite_name = "first_0x4a61bc_selected_coordinate_call"

    return {
        "callsite_address": callsite.get("address"),
        "callsite_name": callsite_name,
        "generator": "0x%08x" % generator,
        "entry_stack": {
            "return_address": "0x%08x" % stack_words[0],
            "x": stack_words[1],
            "y": stack_words[2],
            "level": stack_words[3],
            "repeat_count": stack_words[4],
            "source_arg": "0x%08x" % stack_words[5],
            "raw_words": ["0x%08x" % word for word in stack_words],
        },
        "callsite_stack_words": ["0x%08x" % word for word in callsite_stack],
        "headers": {
            "c8": vector_header(entry, generator + 0xC8),
            "d8": vector_header(entry, generator + 0xD8),
            "f58_words": ["0x%08x" % word for word in words_at(entry, generator + 0xF58)],
            "state_1104": vector_header(entry, generator + 0x1104),
        },
        "failure_registers": {
            "at_0x4a5ed7": failure_cmp.get("registers", {}),
            "at_0x4a5f84": failure.get("registers", {}),
        },
    }


def parse_d8_scan(scan_ledger: dict[str, Any]) -> dict[str, Any]:
    events = scan_ledger.get("events", [])
    addresses = [str(event.get("address", "")).lower() for event in events]
    if not addresses or addresses[0] != "0x004a5e73" or addresses[-1] != "0x004a5f84":
        raise ValueError("scan ledger does not start at 0x4a5e73 and end at 0x4a5f84")

    entry = events[0]
    generator = int(entry.get("registers", {}).get("ecx", 0))
    f58_words = words_at(entry, generator + 0xF58)
    cursor = f58_words[1] if len(f58_words) > 1 else None
    records: list[dict[str, Any]] = []
    for event in events:
        if str(event.get("address", "")).lower() != "0x004a5eb4":
            continue
        regs = event.get("registers", {})
        record_ptr = int(regs.get("eax", 0))
        record_words = contiguous_words(event, record_ptr, 3)
        key_words = words_at(event, record_ptr + 0x20)
        key = key_words[0] if key_words else None
        records.append(
            {
                "scan_index_ecx": int(regs.get("ecx", -1)),
                "record_pointer": "0x%08x" % record_ptr,
                "record_key_plus_20": key,
                "record_key_plus_20_hex": "0x%08x" % key if key is not None else None,
                "record_first_dword": record_words[0] if record_words else None,
                "raw_record_words": ["0x%08x" % word for word in record_words[:12]],
            }
        )

    failure = events[-1]
    return {
        "entry_headers": {
            "c8": vector_header(entry, generator + 0xC8),
            "d8": vector_header(entry, generator + 0xD8),
            "f58_words": ["0x%08x" % word for word in f58_words],
        },
        "cursor_plus_f5c": cursor,
        "cursor_plus_f5c_hex": "0x%08x" % cursor if cursor is not None else None,
        "d8_scanned_records": records,
        "failure": {
            "address": failure.get("address"),
            "eax_count": int(failure.get("registers", {}).get("eax", -1)),
            "ecx_scan_index": int(failure.get("registers", {}).get("ecx", -1)),
            "edx_d8_begin": "0x%08x" % int(failure.get("registers", {}).get("edx", 0)),
            "edi_cursor": "0x%08x" % int(failure.get("registers", {}).get("edi", 0)),
        },
    }


def summarize(callsite_path: Path, d8_scan_path: Path) -> dict[str, Any]:
    callsite_ledger = load_json(callsite_path)
    scan_ledger = load_json(d8_scan_path)
    callsite = parse_callsite(callsite_ledger)
    d8_scan = parse_d8_scan(scan_ledger)
    keys = [record.get("record_key_plus_20") for record in d8_scan["d8_scanned_records"]]
    cursor = d8_scan.get("cursor_plus_f5c")
    d8_count = d8_scan.get("entry_headers", {}).get("d8", {}).get("dword_count")
    status = "natural_bg_first_5e73_cursor_unseeded_against_d8_key_range"
    if not (
        callsite["callsite_address"] == "0x004a64ff"
        and callsite["entry_stack"]["x"] == 33
        and callsite["entry_stack"]["y"] == 26
        and callsite["entry_stack"]["level"] == 0
        and callsite["entry_stack"]["repeat_count"] == 1
        and d8_count == 8
        and keys == list(range(8))
        and cursor == 0x7A1BEFDF
        and d8_scan["failure"]["eax_count"] == 8
        and d8_scan["failure"]["ecx_scan_index"] == 8
    ):
        status = "natural_bg_first_5e73_callsite_evidence_incomplete"

    return {
        "schema_id": "h3maped_4a61bc_5e73_callsite_summary_v1",
        "status": status,
        "source_callsite_ledger": str(callsite_path),
        "source_d8_scan_ledger": str(d8_scan_path),
        "callsite": callsite,
        "d8_scan": d8_scan,
        "invariants": {
            "native_behavior_changed": False,
            "first_callsite_is_4a64ff": callsite["callsite_address"] == "0x004a64ff",
            "entry_arguments_are_normal_coordinate_repeat_source_shape": (
                callsite["entry_stack"]["x"] == 33
                and callsite["entry_stack"]["y"] == 26
                and callsite["entry_stack"]["level"] == 0
                and callsite["entry_stack"]["repeat_count"] == 1
            ),
            "d8_vector_has_eight_entries": d8_count == 8,
            "d8_record_keys_are_zero_through_seven": keys == list(range(8)),
            "cursor_is_stale_unseeded_value_not_d8_key": cursor == 0x7A1BEFDF
            and cursor not in keys,
            "failure_occurs_before_c8_match_or_generated_cell_mutation": (
                d8_scan["failure"]["address"] == "0x004a5f84"
                and d8_scan["failure"]["ecx_scan_index"] == d8_count
            ),
        },
        "remaining_blocker": (
            "0x4a5e73 is being called from the first 0x4a61bc Border Guard "
            "call site with valid-looking coordinate/count/source arguments, but "
            "the d8 scan expects generator+0xf5c to be one of the compact keys "
            "0..7. The cursor remains 0x7a1befdf, so the missing state is the "
            "source precondition that initializes/selects the active endpoint "
            "key before this call, not the 0x4a61bc coordinate argument shape."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--callsite-ledger", type=Path, default=DEFAULT_CALLSITE_LEDGER)
    parser.add_argument("--d8-scan-ledger", type=Path, default=DEFAULT_D8_SCAN_LEDGER)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args.callsite_ledger, args.d8_scan_ledger)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(
        "RMG_H3MAPED_4A61BC_5E73_CALLSITE_SUMMARY "
        f"status={summary['status']} "
        f"callsite={summary['callsite']['callsite_address']} "
        f"args=({summary['callsite']['entry_stack']['x']},"
        f"{summary['callsite']['entry_stack']['y']},"
        f"{summary['callsite']['entry_stack']['level']}) "
        f"d8_keys={[record['record_key_plus_20'] for record in summary['d8_scan']['d8_scanned_records']]} "
        f"cursor={summary['d8_scan']['cursor_plus_f5c_hex']} "
        f"out={args.out}"
    )
    return 0 if summary["status"].endswith("d8_key_range") else 1


if __name__ == "__main__":
    raise SystemExit(main())
