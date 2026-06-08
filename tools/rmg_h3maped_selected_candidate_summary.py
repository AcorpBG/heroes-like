#!/usr/bin/env python3
"""Summarize a natural H3MapEd selected candidate-container relation dump.

The input ledger must come from ``rmg_h3maped_recovery_interactive_trace.py``
at ``0x4ac5a6`` with this command shape:

1. ``x/48x *(int*)($esi+0x10d4)``
2. ``x/24x *(int*)(*(int*)($esi+0x10d4)+$edx*4)``
3. ``x/16x *(int*)(selected+0x14)``
4. eight ``x/4x owner_i+0xc4`` relation-vector headers
5. eight ``x/32x *(int*)(owner_i+0xc8)`` relation-record spans

It records only selected-candidate private state. It does not mutate native RMG
behavior and does not infer final map parity from aggregate counts.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_LEDGER = Path(
    ".artifacts/rmg_recovery/medium_selected_candidate_relation_scan_20260608_run1/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_OUT = Path(".artifacts/rmg_recovery/selected_candidate_relation_summary.json")

STACK_MEMORY_LINE_COUNT = 2
CANDIDATE_VECTOR_LINE_COUNT = 12
SELECTED_CONTAINER_LINE_COUNT = 6
OWNER_VECTOR_LINE_COUNT = 4
OWNER_COUNT = 8
OWNER_HEADER_LINE_COUNT = 1
RELATION_DUMP_LINE_COUNT = 8
RELATION_RECORD_DWORDS = 7


def flatten_words(lines: list[dict[str, Any]]) -> list[int]:
    words: list[int] = []
    for line in lines:
        words.extend(int(word) & 0xFFFFFFFF for word in line.get("words", []))
    return words


def line_address(lines: list[dict[str, Any]], index: int) -> int | None:
    if index < 0 or index >= len(lines):
        return None
    return int(lines[index].get("address", 0)) & 0xFFFFFFFF


def parse_records(words: list[int], count: int) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for index in range(count):
        base = index * RELATION_RECORD_DWORDS
        record_words = words[base : base + RELATION_RECORD_DWORDS]
        if len(record_words) < RELATION_RECORD_DWORDS:
            break
        control = record_words[2]
        records.append(
            {
                "index": index,
                "target_owner": "0x%08x" % record_words[0],
                "value": record_words[1],
                "control_dword": "0x%08x" % control,
                "wide_flag_plus_08": control & 0xFF,
                "border_guard_flag_plus_09": (control >> 8) & 0xFF,
                "processed_flag_plus_0a": (control >> 16) & 0xFF,
                "raw_dwords": ["0x%08x" % word for word in record_words],
            }
        )
    return records


def summarize(ledger: dict[str, Any]) -> dict[str, Any]:
    events = ledger.get("events", [])
    if len(events) != 1:
        raise ValueError(f"expected exactly one 0x4ac5a6 event, found {len(events)}")
    event = events[0]
    address = str(event.get("address", "")).lower()
    if address != "0x004ac5a6":
        raise ValueError(f"expected event address 0x004ac5a6, found {address}")

    registers = event.get("registers", {})
    memory_lines = event.get("memory_lines", [])
    expected_min_lines = (
        STACK_MEMORY_LINE_COUNT
        + CANDIDATE_VECTOR_LINE_COUNT
        + SELECTED_CONTAINER_LINE_COUNT
        + OWNER_VECTOR_LINE_COUNT
        + OWNER_COUNT * OWNER_HEADER_LINE_COUNT
        + OWNER_COUNT * RELATION_DUMP_LINE_COUNT
    )
    if len(memory_lines) < expected_min_lines:
        raise ValueError(
            f"ledger has {len(memory_lines)} memory lines; expected at least "
            f"{expected_min_lines} for selected_candidate_v1"
        )

    cursor = STACK_MEMORY_LINE_COUNT
    candidate_lines = memory_lines[cursor : cursor + CANDIDATE_VECTOR_LINE_COUNT]
    cursor += CANDIDATE_VECTOR_LINE_COUNT
    selected_lines = memory_lines[cursor : cursor + SELECTED_CONTAINER_LINE_COUNT]
    cursor += SELECTED_CONTAINER_LINE_COUNT
    owner_vector_lines = memory_lines[cursor : cursor + OWNER_VECTOR_LINE_COUNT]
    cursor += OWNER_VECTOR_LINE_COUNT
    owner_header_lines = memory_lines[cursor : cursor + OWNER_COUNT * OWNER_HEADER_LINE_COUNT]
    cursor += OWNER_COUNT * OWNER_HEADER_LINE_COUNT
    relation_lines_by_owner: list[list[dict[str, Any]]] = []
    for _ in range(OWNER_COUNT):
        relation_lines_by_owner.append(memory_lines[cursor : cursor + RELATION_DUMP_LINE_COUNT])
        cursor += RELATION_DUMP_LINE_COUNT

    selected_index = int(registers.get("edx", -1))
    candidate_count = int(registers.get("edi", -1))
    candidate_words = flatten_words(candidate_lines)
    selected_pointer = (
        candidate_words[selected_index]
        if 0 <= selected_index < len(candidate_words)
        else 0
    )
    owner_vector_words = flatten_words(owner_vector_lines)[:OWNER_COUNT]
    selected_container_words = flatten_words(selected_lines)

    owners: list[dict[str, Any]] = []
    border_guard_record_count = 0
    total_relation_record_count = 0
    for owner_index in range(OWNER_COUNT):
        header_words = flatten_words(owner_header_lines[owner_index : owner_index + 1])
        begin = header_words[1] if len(header_words) > 1 else 0
        end = header_words[2] if len(header_words) > 2 else begin
        cap = header_words[3] if len(header_words) > 3 else end
        relation_count = max(0, (end - begin) // (RELATION_RECORD_DWORDS * 4))
        records = parse_records(
            flatten_words(relation_lines_by_owner[owner_index]), relation_count
        )
        total_relation_record_count += len(records)
        owner_bg_count = sum(
            1 for record in records if record["border_guard_flag_plus_09"] != 0
        )
        border_guard_record_count += owner_bg_count
        owners.append(
            {
                "owner_index": owner_index,
                "owner_pointer": (
                    "0x%08x" % owner_vector_words[owner_index]
                    if owner_index < len(owner_vector_words)
                    else "0x00000000"
                ),
                "relation_vector": {
                    "begin": "0x%08x" % begin,
                    "end": "0x%08x" % end,
                    "capacity": "0x%08x" % cap,
                    "count": relation_count,
                },
                "border_guard_record_count": owner_bg_count,
                "records": records,
            }
        )

    selected_container_header = {
        "address": "0x%08x" % line_address(selected_lines, 0)
        if line_address(selected_lines, 0) is not None
        else "0x00000000",
        "raw_dwords": ["0x%08x" % word for word in selected_container_words[:24]],
    }

    return {
        "schema_id": "h3maped_selected_candidate_relation_summary_v1",
        "status": (
            "selected_candidate_has_border_guard_records"
            if border_guard_record_count
            else "selected_candidate_has_no_border_guard_records"
        ),
        "source_ledger": ledger.get("log_path", ""),
        "event_address": address,
        "selected_index": selected_index,
        "candidate_count": candidate_count,
        "selected_candidate_pointer_from_vector": "0x%08x" % selected_pointer,
        "selected_container_header": selected_container_header,
        "owner_count_assumed": OWNER_COUNT,
        "owner_pointers": ["0x%08x" % word for word in owner_vector_words],
        "total_relation_record_count": total_relation_record_count,
        "border_guard_relation_record_count": border_guard_record_count,
        "owners": owners,
        "invariants": {
            "native_behavior_changed": False,
            "selected_pointer_matches_dump_address": selected_pointer
            == (line_address(selected_lines, 0) or 0),
            "relation_record_stride_bytes": RELATION_RECORD_DWORDS * 4,
        },
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    ledger = json.loads(args.ledger.read_text(encoding="utf-8"))
    summary = summarize(ledger)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(
        "RMG_H3MAPED_SELECTED_CANDIDATE_SUMMARY "
        f"status={summary['status']} "
        f"selected_index={summary['selected_index']} "
        f"relation_records={summary['total_relation_record_count']} "
        f"border_guard_records={summary['border_guard_relation_record_count']} "
        f"out={args.out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
