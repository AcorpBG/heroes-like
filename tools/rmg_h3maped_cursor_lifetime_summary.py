#!/usr/bin/env python3
"""Summarize H3MapEd endpoint cursor lifetime evidence.

This is recovery evidence only. It checks the setup/lifetime distinction between
``generator+0xf58`` and ``generator+0xf5c`` before the natural Border Guard
endpoint helper failures.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from rmg_h3maped_recovery_trace import parse_winedbg_log


DEFAULT_LIFECYCLE_LOG = Path(
    ".artifacts/rmg_recovery/medium_cursor_state_lifecycle_probe_20260608/"
    "winedbg_interactive_trace.log"
)
DEFAULT_CALLSITE_SUMMARY = Path(
    ".artifacts/rmg_recovery/medium_seed10_4a61bc_5e73_callsite_summary_20260608.json"
)
DEFAULT_STATIC_DUMP = Path(
    ".artifacts/rmg_recovery/ghidra_candidate_container_fill_49f0cd_dump_20260607/"
    "caller_0049ecf2_FUN_0049ecf2.txt"
)
DEFAULT_OUT = Path(
    ".artifacts/rmg_recovery/medium_cursor_lifetime_summary_20260608.json"
)


def event_by_address(ledger: dict[str, Any], address: str) -> dict[str, Any]:
    address = address.lower()
    for event in ledger.get("events", []):
        if str(event.get("address", "")).lower() == address:
            return event
    raise ValueError(f"event {address} not found in {ledger.get('log_path')}")


def words_at(event: dict[str, Any], address: int) -> list[int]:
    lines = sorted(
        (
            int(line.get("address", -1)),
            [int(word) & 0xFFFFFFFF for word in line.get("words", [])],
        )
        for line in event.get("memory_lines", [])
    )
    for index, (start, words) in enumerate(lines):
        if not (start <= address < start + len(words) * 4):
            continue
        offset = (address - start) // 4
        stitched = words[offset:]
        expected_next = start + len(words) * 4
        for next_start, next_words in lines[index + 1 :]:
            if next_start != expected_next:
                break
            stitched.extend(next_words)
            expected_next = next_start + len(next_words) * 4
        return stitched
    return []


def hex_words(words: list[int], count: int | None = None) -> list[str]:
    if count is not None:
        words = words[:count]
    return ["0x%08x" % (word & 0xFFFFFFFF) for word in words]


def require_words(label: str, event: dict[str, Any], address: int, count: int) -> list[int]:
    words = words_at(event, address)
    if len(words) < count:
        raise ValueError(f"{label}: missing {count} words at 0x{address:08x}")
    return words[:count]


def setup_snapshot(event: dict[str, Any], base_register: str) -> dict[str, Any]:
    registers = event.get("registers", {})
    base = int(registers[base_register])
    f58_words = require_words(
        f"{event.get('address')} {base_register}+0xf58", event, base + 0xF58, 4
    )
    state_1100_words = require_words(
        f"{event.get('address')} {base_register}+0x1100", event, base + 0x1100, 4
    )
    return {
        "address": event.get("address"),
        "base_register": base_register,
        "generator": "0x%08x" % base,
        "f58": f58_words[0],
        "f5c": f58_words[1],
        "f58_words": hex_words(f58_words),
        "state_1100_words": hex_words(state_1100_words),
        "state_1104_begin": state_1100_words[1],
        "state_1108_end": state_1100_words[2],
    }


def summarize(
    lifecycle_log: Path,
    callsite_summary_path: Path,
    static_dump_path: Path,
) -> dict[str, Any]:
    lifecycle = parse_winedbg_log(lifecycle_log)
    static_text = static_dump_path.read_text(encoding="utf-8")
    callsite_summary = json.loads(callsite_summary_path.read_text(encoding="utf-8"))

    setup_49ee6b = setup_snapshot(event_by_address(lifecycle, "0x0049ee6b"), "esi")
    before_49f95a = setup_snapshot(event_by_address(lifecycle, "0x0049ee9f"), "esi")
    after_49f95a = setup_snapshot(event_by_address(lifecycle, "0x0049ef4a"), "esi")
    first_4a61bc = setup_snapshot(event_by_address(lifecycle, "0x004a61bc"), "ecx")

    d8_scan = callsite_summary.get("d8_scan", {})
    keys = d8_scan.get("d8_record_keys_plus_20", [])
    if not keys:
        keys = [
            record.get("record_key_plus_20")
            for record in d8_scan.get("d8_scanned_records", [])
        ]
    keys = [int(key) for key in keys if key is not None]
    cursor = int(d8_scan.get("cursor_plus_f5c", -1))

    static_writes_f58 = "0049ee6b: MOV dword ptr [ESI + 0xf58],EBX" in static_text
    static_49ee6b_writes_f5c = "0049ee6b: MOV dword ptr [ESI + 0xf5c]" in static_text

    f5c_values = [
        setup_49ee6b["f5c"],
        before_49f95a["f5c"],
        after_49f95a["f5c"],
        first_4a61bc["f5c"],
    ]
    post_f58_write_values = [
        before_49f95a["f58"],
        after_49f95a["f58"],
        first_4a61bc["f58"],
    ]

    invariants = {
        "native_behavior_changed": False,
        "static_setup_writes_f58_not_f5c": static_writes_f58
        and not static_49ee6b_writes_f5c,
        "f58_is_zero_after_49ee6b_through_first_relation_pass": all(
            value == 0 for value in post_f58_write_values
        ),
        "f5c_remains_stale_through_setup_and_first_relation_pass": all(
            value == 0x7A1BEFDF for value in f5c_values
        ),
        "49f95a_allocates_byte_state_without_changing_f5c": (
            before_49f95a["state_1104_begin"] == 0
            and before_49f95a["state_1108_end"] == 0
            and after_49f95a["state_1104_begin"] != 0
            and after_49f95a["state_1108_end"] != 0
            and before_49f95a["f5c"] == after_49f95a["f5c"]
        ),
        "natural_border_guard_failure_uses_same_stale_f5c": cursor == 0x7A1BEFDF,
        "natural_border_guard_d8_keys_are_compact_zero_to_seven": keys
        == list(range(8)),
        "stale_f5c_is_not_an_active_endpoint_key": cursor not in keys,
    }
    status = "cursor_lifetime_f58_zero_f5c_unseeded"
    required_invariants = {
        key: value for key, value in invariants.items() if key != "native_behavior_changed"
    }
    if not all(required_invariants.values()):
        status = "cursor_lifetime_evidence_incomplete"

    return {
        "schema_id": "h3maped_cursor_lifetime_summary_v1",
        "status": status,
        "source_lifecycle_log": str(lifecycle_log),
        "source_static_dump": str(static_dump_path),
        "source_callsite_summary": str(callsite_summary_path),
        "setup_snapshots": {
            "at_0x49ee6b_before_f58_zero_write": setup_49ee6b,
            "at_0x49ee9f_before_49f95a": before_49f95a,
            "at_0x49ef4a_after_49f95a": after_49f95a,
            "at_first_0x4a61bc": first_4a61bc,
        },
        "natural_border_guard_first_failure": {
            "cursor_plus_f5c": "0x%08x" % cursor,
            "d8_keys_plus_20": keys,
            "callsite": callsite_summary.get("callsite", {}).get("callsite_address"),
            "entry_stack": callsite_summary.get("callsite", {}).get("entry_stack"),
        },
        "invariants": invariants,
        "interpretation": (
            "The candidate-container setup path initializes generator+0xf58 and "
            "generator+0x1104, but it does not initialize generator+0xf5c. The "
            "first natural Border Guard endpoint helper failure therefore is not "
            "explained by a missing 0x49ecf2/0x49f95a direct write; it is either "
            "an optional endpoint-object miss that falls back through later "
            "connection materialization, or it depends on a still-unreplayed prior "
            "successful endpoint consumer that marks the byte-state vector."
        ),
        "remaining_blocker": (
            "Replay the full Border Guard materialization sequence after the first "
            "0x4a5e73 failures: prove whether H3MapEd intentionally falls back to "
            "0x4a5e03/0x4a7605-style connection materialization, or capture the "
            "earlier successful endpoint consumer that advances generator+0xf5c "
            "before a later +0x09 Border Guard call."
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lifecycle-log", type=Path, default=DEFAULT_LIFECYCLE_LOG)
    parser.add_argument("--callsite-summary", type=Path, default=DEFAULT_CALLSITE_SUMMARY)
    parser.add_argument("--static-dump", type=Path, default=DEFAULT_STATIC_DUMP)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    summary = summarize(args.lifecycle_log, args.callsite_summary, args.static_dump)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_CURSOR_LIFETIME_SUMMARY "
        f"status={summary['status']} "
        f"f58={summary['setup_snapshots']['at_first_0x4a61bc']['f58_words'][0]} "
        f"f5c={summary['setup_snapshots']['at_first_0x4a61bc']['f58_words'][1]} "
        f"out={args.out}"
    )
    return 0 if summary["status"] == "cursor_lifetime_f58_zero_f5c_unseeded" else 1


if __name__ == "__main__":
    raise SystemExit(main())
