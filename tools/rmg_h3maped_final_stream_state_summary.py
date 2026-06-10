#!/usr/bin/env python3
"""Summarize the H3MapEd final-write stream adapter and wrapped sink state.

This is a source-recovery checkpoint for the final serialization stream used by
`0x4ad1e3`. It deliberately does not claim ordered private-state replay or
native RMG parity.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_ADAPTER_LEDGER = (
    ROOT
    / "medium_seed10_final_stream_state_20260610"
    / "winedbg_interactive_trace_ledger.json"
)
DEFAULT_WRAPPED_LEDGER = (
    ROOT
    / "medium_seed10_wrapped_stream_state_20260610"
    / "winedbg_interactive_trace_ledger.json"
)
DEFAULT_ADAPTER_GHIDRA_DIR = ROOT / "ghidra_final_stream_vtable_20260610"
DEFAULT_WRAPPED_GHIDRA_DIR = ROOT / "ghidra_wrapped_stream_vtable_20260610"
DEFAULT_OUT = ROOT / "final_stream_state_summary_20260610.json"

FINAL_WRITER_ENTRY = "0x004ad1e3"
FIRST_POST_HEADER_WRITE = "0x004ad206"
FINAL_ZERO_SENTINEL = "0x004ad3db"
FINAL_SENTINEL_SUCCESS = "0x004ad3de"
FINAL_WRITER_RETURN = "0x004ae09a"


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def hex32(value: int | None) -> str | None:
    if value is None:
        return None
    return f"0x{value & 0xffffffff:08x}"


def event_by_address(ledger: dict[str, Any], address: str) -> dict[str, Any] | None:
    for event in ledger.get("events", []):
        if str(event.get("address", "")).lower() == address.lower():
            return event
    return None


def words_at(event: dict[str, Any] | None, address: int | None) -> list[int]:
    if event is None or address is None:
        return []
    for line in event.get("memory_lines", []):
        if line.get("address") == address:
            return [int(word) for word in line.get("words", [])]
    return []


def contiguous_words_from(event: dict[str, Any] | None, start: int | None) -> list[int]:
    if event is None or start is None:
        return []
    by_addr = {
        int(line.get("address")): [int(word) for word in line.get("words", [])]
        for line in event.get("memory_lines", [])
        if line.get("address") is not None
    }
    out: list[int] = []
    cursor = start
    while cursor in by_addr:
        words = by_addr[cursor]
        out.extend(words)
        cursor += len(words) * 4
    return out


def stack_arg(event: dict[str, Any] | None, index: int) -> int | None:
    if event is None:
        return None
    registers = event.get("registers", {})
    esp = registers.get("esp")
    if esp is None:
        return None
    stack = words_at(event, int(esp))
    if index >= len(stack):
        return None
    return stack[index]


def table_entry(table: dict[str, Any], index: int) -> dict[str, Any]:
    for entry in table.get("entries", []):
        if int(entry.get("index", -1)) == index:
            return entry
    return {}


def parse_int_hex(raw: str | None) -> int | None:
    if raw is None:
        return None
    try:
        return int(raw, 16)
    except ValueError:
        return None


def contains_markers(path: Path, markers: list[str]) -> dict[str, bool]:
    text = path.read_text(encoding="utf-8") if path.exists() else ""
    return {marker: marker in text for marker in markers}


def changed_offsets(before: list[int], after: list[int]) -> list[dict[str, str]]:
    changes: list[dict[str, str]] = []
    for index, (left, right) in enumerate(zip(before, after)):
        if left != right:
            changes.append(
                {
                    "offset": f"+0x{index * 4:02x}",
                    "first": hex32(left) or "0x00000000",
                    "final": hex32(right) or "0x00000000",
                }
            )
    return changes


def summarize(
    adapter_ledger_path: Path,
    wrapped_ledger_path: Path,
    adapter_ghidra_dir: Path,
    wrapped_ghidra_dir: Path,
) -> dict[str, Any]:
    adapter_ledger = load_json(adapter_ledger_path)
    wrapped_ledger = load_json(wrapped_ledger_path)
    adapter_table = load_json(adapter_ghidra_dir / "table_00539918.json")
    wrapped_table = load_json(wrapped_ghidra_dir / "table_00536c94.json")

    entry_event = event_by_address(adapter_ledger, FINAL_WRITER_ENTRY)
    first_write_event = event_by_address(adapter_ledger, FIRST_POST_HEADER_WRITE)
    final_sentinel_event = event_by_address(adapter_ledger, FINAL_ZERO_SENTINEL)
    final_success_event = event_by_address(adapter_ledger, FINAL_SENTINEL_SUCCESS)
    final_return_event = event_by_address(adapter_ledger, FINAL_WRITER_RETURN)

    entry_stream = stack_arg(entry_event, 1)
    first_stream = first_write_event.get("registers", {}).get("ebx") if first_write_event else None
    adapter_words_first = contiguous_words_from(first_write_event, first_stream)
    adapter_words_final = contiguous_words_from(final_sentinel_event, first_stream)
    adapter_primary_first = adapter_words_first[:2]
    adapter_primary_final = adapter_words_final[:2]

    wrapped_first_event = event_by_address(wrapped_ledger, FIRST_POST_HEADER_WRITE)
    wrapped_final_event = event_by_address(wrapped_ledger, FINAL_ZERO_SENTINEL)
    wrapped_adapter_stream = (
        wrapped_first_event.get("registers", {}).get("ebx") if wrapped_first_event else None
    )
    wrapped_adapter_words_first = contiguous_words_from(wrapped_first_event, wrapped_adapter_stream)
    wrapped_adapter_words_final = contiguous_words_from(wrapped_final_event, wrapped_adapter_stream)
    wrapped_stream = None
    if wrapped_adapter_words_first and len(wrapped_adapter_words_first) >= 2:
        wrapped_stream = wrapped_adapter_words_first[1]
    wrapped_words_first = contiguous_words_from(wrapped_first_event, wrapped_stream)
    wrapped_words_final = contiguous_words_from(wrapped_final_event, wrapped_stream)
    wrapped_vtable = wrapped_words_first[0] if wrapped_words_first else None

    adapter_thunk_markers = contains_markers(
        adapter_ghidra_dir / "range_0045df70_0045dfc8.txt",
        [
            "0045df8f: MOV ECX,dword ptr [ECX + 0x4]",
            "0045df9c: CALL dword ptr [EAX + 0x1c]",
            "0045df9f: RET 0x8",
            "0045df7c: MOV ECX,dword ptr [ECX + 0x4]",
            "0045df89: CALL dword ptr [EAX + 0x18]",
        ],
    )
    adapter_constructor_markers = contains_markers(
        adapter_ghidra_dir / "target_004602c1_FUN_004602c1.txt",
        [
            "00460391: MOV dword ptr [EBP + -0x18],0x539918",
            "00460398: MOV dword ptr [EBP + -0x14],EAX",
            "004603ce: CALL 0x004adfe1",
        ],
    )
    wrapped_write_markers = contains_markers(
        wrapped_ghidra_dir / "target_00449cfc_FUN_00449cfc.txt",
        [
            "00449d04: CMP dword ptr [EBP + 0xc],0x0",
            "00449d0e: MOV EBX,dword ptr [EBP + 0x8]",
            "00449d2f: CALL 0x004e6380",
            "00449d53: CALL dword ptr [EAX + 0x4]",
            "00449d6f: RET 0x8",
        ],
    )

    adapter_write_entry = table_entry(adapter_table, 2)
    wrapped_write_entry = table_entry(wrapped_table, 7)
    wrapped_state_changes = changed_offsets(wrapped_words_first[:24], wrapped_words_final[:24])

    adapter_primary_stable = (
        bool(adapter_primary_first)
        and adapter_primary_first == adapter_primary_final
        and parse_int_hex(adapter_write_entry.get("value")) == 0x0045DF8F
        and all(adapter_thunk_markers.values())
        and all(adapter_constructor_markers.values())
    )
    wrapped_trace_adapter_primary_stable = (
        bool(wrapped_adapter_words_first)
        and wrapped_adapter_words_first[:2] == wrapped_adapter_words_final[:2]
    )
    stream_pointer_consistent = (
        first_stream == wrapped_adapter_stream
        and bool(adapter_primary_first)
        and bool(wrapped_adapter_words_first)
        and adapter_primary_first[:2] == wrapped_adapter_words_first[:2]
    )
    wrapped_sink_recovered = (
        wrapped_vtable == 0x00536C94
        and parse_int_hex(wrapped_write_entry.get("value")) == 0x00449CFC
        and all(wrapped_write_markers.values())
        and bool(wrapped_state_changes)
    )

    return {
        "schema_id": "h3maped_final_stream_state_summary_v1",
        "status": (
            "final_stream_adapter_and_wrapped_sink_recovered"
            if adapter_primary_stable and wrapped_sink_recovered
            else "final_stream_state_incomplete"
        ),
        "scope": {
            "profile": "H3MapEd Medium one-level no-water seed 10, human/computer down 1, computer-only down 0",
            "positive_claim": (
                "recovers the final-write stream adapter, its forwarding write thunk, and the "
                "next wrapped buffered stream sink used by 0x4ad1e3"
            ),
            "negative_claim": (
                "does not recover the ordered RMG private-state mutation chain and does not "
                "change native RMG behavior; adapter entry/return and wrapped-sink mutation are "
                "verified by separate seed-controlled traces, not a single complete writeout trace"
            ),
        },
        "inputs": {
            "adapter_ledger": str(adapter_ledger_path),
            "wrapped_ledger": str(wrapped_ledger_path),
            "adapter_ghidra_dir": str(adapter_ghidra_dir),
            "wrapped_ghidra_dir": str(wrapped_ghidra_dir),
        },
        "facts": {
            "final_writer_entry": FINAL_WRITER_ENTRY,
            "final_writer_entry_generator_ecx": hex32(
                entry_event.get("registers", {}).get("ecx") if entry_event else None
            ),
            "final_writer_entry_stream_stack_arg": hex32(entry_stream),
            "adapter_stream_object": hex32(first_stream),
            "wrapped_trace_adapter_stream_object": hex32(wrapped_adapter_stream),
            "adapter_vtable": hex32(adapter_primary_first[0] if adapter_primary_first else None),
            "adapter_wrapped_stream_pointer": hex32(wrapped_stream),
            "adapter_write_slot_index": 2,
            "adapter_write_slot_entry": adapter_write_entry.get("entry"),
            "adapter_write_slot_target": adapter_write_entry.get("value"),
            "adapter_write_slot_semantics": (
                "forward (buffer, length) from stack adapter to wrapped stream vtable slot +0x1c"
            ),
            "wrapped_stream_object": hex32(wrapped_stream),
            "wrapped_stream_vtable": hex32(wrapped_vtable),
            "wrapped_write_slot_index": 7,
            "wrapped_write_slot_entry": wrapped_write_entry.get("entry"),
            "wrapped_write_slot_target": wrapped_write_entry.get("value"),
            "wrapped_write_slot_semantics": (
                "buffered write: consumes stack buffer at +0x08 and length at +0x0c, "
                "bulk-copies through 0x4e6380 when buffer space is available, otherwise "
                "falls back to byte writes through wrapped vtable slot +0x04"
            ),
            "adapter_trace_final_zero_sentinel_edi": final_sentinel_event.get("registers", {}).get("edi")
            if final_sentinel_event
            else None,
            "wrapped_trace_final_zero_sentinel_edi": wrapped_final_event.get("registers", {}).get("edi")
            if wrapped_final_event
            else None,
            "final_sentinel_success_eax": final_success_event.get("registers", {}).get("eax")
            if final_success_event
            else None,
            "final_writer_return_eax": final_return_event.get("registers", {}).get("eax")
            if final_return_event
            else None,
        },
        "metrics": {
            "adapter_trace_event_count": adapter_ledger.get("event_count"),
            "wrapped_trace_event_count": wrapped_ledger.get("event_count"),
            "adapter_primary_dwords_stable": adapter_primary_stable,
            "wrapped_trace_adapter_primary_dwords_stable": wrapped_trace_adapter_primary_stable,
            "stream_pointer_consistent_across_traces": stream_pointer_consistent,
            "adapter_visible_stack_window_stable": adapter_words_first == adapter_words_final,
            "adapter_constructor_markers_all_present": all(adapter_constructor_markers.values()),
            "adapter_forwarding_markers_all_present": all(adapter_thunk_markers.values()),
            "adapter_final_buffer_payload_recoverable_from_adapter": False,
            "single_full_writeout_trace": False,
            "wrapped_sink_state_observed": wrapped_sink_recovered,
            "wrapped_sink_changed_dword_count": len(wrapped_state_changes),
            "wrapped_write_markers_all_present": all(wrapped_write_markers.values()),
            "wrapped_sink_buffer_or_file_state_recovery_complete": False,
            "ordered_private_state_mutation_replay_complete": False,
            "full_private_payload_replay_complete": False,
            "native_behavior_changed": False,
            "used_objdump": False,
            "overall_goal_complete": False,
        },
        "adapter_constructor_markers": adapter_constructor_markers,
        "adapter_forwarding_markers": adapter_thunk_markers,
        "wrapped_write_markers": wrapped_write_markers,
        "wrapped_sink_state_changes": wrapped_state_changes,
        "remaining_gap": (
            "The 0x539918 final stream object is only a stack-local forwarding adapter. "
            "The next live sink is the mutable 0x536c94 buffered stream object at the adapter "
            "field +0x04. Its write method 0x449cfc is source-backed, but the downstream buffer/"
            "file-handle state and the ordered RMG private-state mutation chain feeding the final "
            "writeout are still unrecovered."
        ),
        "next_recovery_target": (
            "Follow the wrapped 0x536c94 stream sink fields and flush/file-write path, especially "
            "the mutable dwords seen at offsets +0x18, +0x28, and +0x44, or resume ordered "
            "private-state replay before 0x4ad1e3. Do not port native generation behavior from "
            "this stream-sink checkpoint alone."
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--adapter-ledger", type=Path, default=DEFAULT_ADAPTER_LEDGER)
    parser.add_argument("--wrapped-ledger", type=Path, default=DEFAULT_WRAPPED_LEDGER)
    parser.add_argument("--adapter-ghidra-dir", type=Path, default=DEFAULT_ADAPTER_GHIDRA_DIR)
    parser.add_argument("--wrapped-ghidra-dir", type=Path, default=DEFAULT_WRAPPED_GHIDRA_DIR)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    summary = summarize(
        args.adapter_ledger,
        args.wrapped_ledger,
        args.adapter_ghidra_dir,
        args.wrapped_ghidra_dir,
    )
    write_json(args.out, summary)
    print(
        "RMG_H3MAPED_FINAL_STREAM_STATE "
        f"status={summary['status']} "
        f"adapter={summary['facts']['adapter_stream_object']} "
        f"wrapped={summary['facts']['wrapped_stream_object']} "
        f"wrapped_changes={summary['metrics']['wrapped_sink_changed_dword_count']} "
        f"out={args.out}"
    )
    return 0 if summary["status"] == "final_stream_adapter_and_wrapped_sink_recovered" else 1


if __name__ == "__main__":
    raise SystemExit(main())
