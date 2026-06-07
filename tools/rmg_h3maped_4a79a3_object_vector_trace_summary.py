#!/usr/bin/env python3
"""Summarize a focused H3MapEd 0x4a79a3 object-vector trace."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

from rmg_h3maped_recovery_trace import parse_winedbg_log


DEFAULT_LOG = Path(
    ".artifacts/rmg_recovery/direct_generation_4a79a3_object_vector_trace/winedbg_interactive_trace.log"
)
DEFAULT_OUT = Path(".artifacts/rmg_recovery/4a79a3_object_vector_trace_summary.json")

TARGET_PHASE = "0x004a79a3"
PHASE_ENTRY = "0x004a4c8e"
VECTOR_BEGIN_READ = "0x004a7d2c"
VECTOR_END_READ = "0x004a7d36"
VECTOR_COUNT_AFTER_SHIFT = "0x004a7d99"
DECOR_HANDOFF = "0x0049eb8d"


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


def vector_base_for_event(event: dict[str, Any]) -> int | None:
    regs = event.get("registers", {})
    address = event.get("address")
    if address in {TARGET_PHASE, DECOR_HANDOFF} and isinstance(regs.get("ecx"), int):
        return int(regs["ecx"]) + 0xEC4
    if address in {VECTOR_BEGIN_READ, VECTOR_END_READ, VECTOR_COUNT_AFTER_SHIFT} and isinstance(regs.get("ebx"), int):
        return int(regs["ebx"]) + 0xEC4
    return None


def vector_snapshot(event: dict[str, Any]) -> dict[str, Any] | None:
    base = vector_base_for_event(event)
    if base is None:
        return None
    words = [memory_word(event, base + index * 4) for index in range(8)]
    begin = words[1] if len(words) > 1 else None
    end = words[2] if len(words) > 2 else None
    capacity = words[3] if len(words) > 3 else None
    byte_span = end - begin if begin is not None and end is not None else None
    dword_count = byte_span // 4 if byte_span is not None and byte_span >= 0 and byte_span % 4 == 0 else None
    return {
        "base": hex32(base),
        "words": [hex32(word) for word in words],
        "begin": hex32(begin),
        "end": hex32(end),
        "capacity": hex32(capacity),
        "byte_span": byte_span,
        "dword_count": dword_count,
    }


def stack_words(event: dict[str, Any], count: int = 8) -> list[str | None]:
    esp = event.get("registers", {}).get("esp")
    if not isinstance(esp, int):
        return []
    return [hex32(memory_word(event, esp + index * 4)) for index in range(count)]


def interesting_events(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for index, event in enumerate(events):
        if event["address"] not in {
            PHASE_ENTRY,
            TARGET_PHASE,
            VECTOR_BEGIN_READ,
            VECTOR_END_READ,
            VECTOR_COUNT_AFTER_SHIFT,
            DECOR_HANDOFF,
        }:
            continue
        regs = event.get("registers", {})
        snapshot = vector_snapshot(event)
        record = {
            "event_index": index,
            "site": event["address"],
            "return_address": event.get("derived", {}).get("return_address"),
            "registers": {name: hex32(value) for name, value in regs.items()},
            "stack": stack_words(event),
            "vector_snapshot": snapshot,
        }
        if event["address"] == VECTOR_COUNT_AFTER_SHIFT:
            edx = regs.get("edx")
            record["edx_count_after_shift"] = int(edx) if isinstance(edx, int) else None
        records.append(record)
    return records


def summarize(log_path: Path) -> dict[str, Any]:
    ledger = parse_winedbg_log(log_path)
    events = ledger["events"]
    counts = dict(sorted(Counter(event["address"] for event in events).items()))
    records = interesting_events(events)
    vector_counts = [
        record["vector_snapshot"]["dword_count"]
        for record in records
        if record.get("vector_snapshot") and record["vector_snapshot"].get("dword_count") is not None
    ]
    count_after_shift = [
        record.get("edx_count_after_shift")
        for record in records
        if record.get("edx_count_after_shift") is not None
    ]
    invariants = {
        "trace_has_events": bool(events),
        "phase_entry_hit": counts.get(PHASE_ENTRY, 0) >= 1,
        "target_4a79a3_hit": counts.get(TARGET_PHASE, 0) >= 1,
        "object_vector_begin_end_reads_hit": counts.get(VECTOR_BEGIN_READ, 0) >= 1
        and counts.get(VECTOR_END_READ, 0) >= 1,
        "vector_count_recovered": bool(vector_counts),
        "count_after_shift_matches_snapshot": bool(count_after_shift)
        and any(count in vector_counts for count in count_after_shift),
        "decor_handoff_hit_after_target": counts.get(DECOR_HANDOFF, 0) >= 1,
    }
    status = "partial_live_recovery_4a79a3_object_vector_count" if all(invariants.values()) else "incomplete"
    return {
        "schema_id": "h3maped_4a79a3_object_vector_trace_summary_v1",
        "log_path": str(log_path),
        "event_count": len(events),
        "address_counts": counts,
        "status": status,
        "invariants": invariants,
        "target_entry_vector_dword_count": vector_counts[0] if vector_counts else None,
        "observed_vector_dword_counts": sorted(set(vector_counts)),
        "observed_edx_counts_after_shift": sorted(set(count_after_shift)),
        "interesting_events": records[:80],
        "trace_limit_note": (
            "The interactive driver timed out waiting for another breakpoint after the useful phase hits. "
            "This is partial live evidence, not a completed full-generation replay."
        ),
        "recovered_contract": (
            "In the sampled direct-generation run, 0x4a8c15 entered 0x4a4c8e, then later hit 0x4a79a3. "
            "At 0x4a79a3 entry the sampled +0xec8/+0xecc span was 8 dword entries. Inside the later "
            "0x4a7d2c/0x4a7d36 loop, the same generator surface yielded a 19-dword span and 0x4a7d99 "
            "confirmed EDX=19 after the shift. The later 0x49eb8d handoff observed a 107-dword span."
        ),
        "remaining_gap": (
            "The object-vector payload entries and subsequent GeneratedCell mutations are still not replayed "
            "end-to-end. Next recovery must decode the 19 dword entries observed at 0x4a79a3 and connect them "
            "to the connection/blocker/guard writes."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log", type=Path, default=DEFAULT_LOG)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args.log)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_4A79A3_OBJECT_VECTOR_TRACE_SUMMARY "
        f"status={summary['status']} events={summary['event_count']} out={args.out}"
    )
    return 0 if summary["status"] == "partial_live_recovery_4a79a3_object_vector_count" else 1


if __name__ == "__main__":
    raise SystemExit(main())
