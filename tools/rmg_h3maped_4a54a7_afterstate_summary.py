#!/usr/bin/env python3
"""Summarize ``0x4a54a7`` after-state for post-Border-Guard materialization.

The input trace follows the natural Medium seed-10 Border Guard failure
follow-through into the two downstream ``0x4a7605 -> 0x4a5e03`` materialization
calls. This report filters only those two calls, then records the
``0x4a54a7`` object-vector append and generated-cell after-state. It is
recovery evidence only and does not change native RMG behavior.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

from rmg_h3maped_recovery_trace import parse_winedbg_log


DEFAULT_TRACE_LOG = Path(
    ".artifacts/rmg_recovery/medium_seed10_4a54a7_cell_ref_trace_20260608/"
    "winedbg_interactive_trace.log"
)
DEFAULT_OUT = Path(
    ".artifacts/rmg_recovery/medium_seed10_4a54a7_afterstate_summary_20260608.json"
)

TARGET_RETURNS = {
    "0x004a77ad": "first_0x4a7605_materialization",
    "0x004a789a": "second_0x4a7605_materialization",
}


def hex_word(value: int | None) -> str | None:
    if value is None:
        return None
    return "0x%08x" % (int(value) & 0xFFFFFFFF)


def first_words(event: dict[str, Any]) -> list[int]:
    if not event.get("memory_lines"):
        return []
    return [int(word) & 0xFFFFFFFF for word in event["memory_lines"][0].get("words", [])]


def return_address(event: dict[str, Any]) -> str:
    derived = event.get("derived", {})
    if derived.get("return_address"):
        return str(derived["return_address"])
    words = first_words(event)
    return hex_word(words[0]) or "missing" if words else "missing"


def block_words_at(event: dict[str, Any], address: int, max_words: int) -> list[int]:
    by_address: dict[int, list[int]] = {}
    for memory_line in event.get("memory_lines", []):
        line_address = int(memory_line.get("address", -1))
        words = [
            int(word) & 0xFFFFFFFF for word in memory_line.get("words", [])
        ]
        if words:
            by_address[line_address] = words
    words: list[int] = []
    cursor = address
    while len(words) < max_words and cursor in by_address:
        line_words = by_address[cursor]
        words.extend(line_words)
        cursor += len(line_words) * 4
    return words[:max_words]


def words_at(event: dict[str, Any], address: int | None, max_words: int = 4) -> list[int]:
    if address is None:
        return []
    return block_words_at(event, address, max_words)


def registers(event: dict[str, Any]) -> dict[str, str]:
    return {
        name: hex_word(int(value)) or "missing"
        for name, value in event.get("registers", {}).items()
        if name in {"eax", "ebx", "ecx", "edx", "esi", "edi", "ebp", "esp"}
    }


def cell_state(event: dict[str, Any], pointer: int) -> dict[str, Any]:
    words = block_words_at(event, pointer, 16)
    object_begin = words[1] if len(words) > 1 else None
    object_end = words[2] if len(words) > 2 else None
    object_cap = words[3] if len(words) > 3 else None
    object_ref_words = words_at(event, object_begin, 4)
    return {
        "cell_pointer": hex_word(pointer),
        "raw_words": [hex_word(word) for word in words],
        "object_ref_vector": {
            "begin": hex_word(object_begin),
            "end": hex_word(object_end),
            "capacity_or_aux": hex_word(object_cap),
            "empty": object_begin == object_end,
            "first_words": [hex_word(word) for word in object_ref_words],
        },
        "projection_triple": {
            "x": words[4] if len(words) > 4 else None,
            "y": words[5] if len(words) > 5 else None,
            "level": words[6] if len(words) > 6 else None,
        },
        "generated_cell_words": {
            "+0x20": hex_word(words[8] if len(words) > 8 else None),
            "+0x24": hex_word(words[9] if len(words) > 9 else None),
            "+0x28": hex_word(words[10] if len(words) > 10 else None),
            "+0x2c": hex_word(words[11] if len(words) > 11 else None),
        },
    }


def vector_header(event: dict[str, Any], generator: int) -> dict[str, Any]:
    words = block_words_at(event, generator + 0xEC4, 4)
    return {
        "header_address": hex_word(generator + 0xEC4),
        "raw_words": [hex_word(word) for word in words],
        "anchor_or_allocator": hex_word(words[0] if len(words) > 0 else None),
        "begin": hex_word(words[1] if len(words) > 1 else None),
        "end": hex_word(words[2] if len(words) > 2 else None),
        "capacity": hex_word(words[3] if len(words) > 3 else None),
    }


def entry_args(event: dict[str, Any]) -> dict[str, Any]:
    words = first_words(event)
    level_words = event.get("memory_lines", [{}])[1].get("words", []) if len(event.get("memory_lines", [])) > 1 else []
    return {
        "return_address": return_address(event),
        "arg0": hex_word(words[1] if len(words) > 1 else None),
        "x": words[2] if len(words) > 2 else None,
        "y": words[3] if len(words) > 3 else None,
        "level": int(level_words[0]) & 0xFFFFFFFF if level_words else None,
    }


def stack_callback(event: dict[str, Any]) -> dict[str, Any]:
    words = first_words(event)
    level_words = event.get("memory_lines", [{}])[1].get("words", []) if len(event.get("memory_lines", [])) > 1 else []
    return {
        "object_record_pointer": hex_word(words[1] if len(words) > 1 else None),
        "coordinate": {
            "x": words[2] if len(words) > 2 else None,
            "y": words[3] if len(words) > 3 else None,
            "level": int(level_words[0]) & 0xFFFFFFFF if level_words else None,
        },
        "return_address": hex_word(words[0] if words else None),
    }


def find_next(events: list[dict[str, Any]], start: int, address: str, *, return_to: str | None = None) -> tuple[int, dict[str, Any]] | tuple[None, None]:
    for index in range(start, len(events)):
        event = events[index]
        if str(event.get("address", "")).lower() != address:
            continue
        if return_to is not None and return_address(event) != return_to:
            continue
        return index, event
    return None, None


def summarize_target(events: list[dict[str, Any]], entry_index: int) -> dict[str, Any]:
    entry = events[entry_index]
    ret = return_address(entry)
    cell_index, cell_event = find_next(events, entry_index + 1, "0x004a5e4a")
    callback_index, callback_event = find_next(events, entry_index + 1, "0x004a5e69")
    commit_index, commit_event = find_next(events, entry_index + 1, "0x004a54a7", return_to="0x004a5e6c")
    append_index, append_event = find_next(events, (commit_index or entry_index) + 1, "0x004a54ef")
    after_index, after_event = find_next(events, (commit_index or entry_index) + 1, "0x004a5756")
    final_index, final_event = find_next(events, (commit_index or entry_index) + 1, "0x004a5e6c")
    if any(value is None for value in [cell_event, callback_event, commit_event, append_event, after_event, final_event]):
        return {
            "sequence_name": TARGET_RETURNS[ret],
            "status": "incomplete",
            "entry_event_index": entry_index + 1,
        }

    cell_pointer = int(cell_event.get("registers", {}).get("eax", 0))
    object_pointer = first_words(callback_event)[0]
    generator = int(commit_event.get("registers", {}).get("ecx", 0))
    append_old_end = int(append_event.get("registers", {}).get("edx", 0))
    before_header = vector_header(commit_event, generator)
    after_header = vector_header(append_event, generator)
    old_slot_words = words_at(append_event, append_old_end, 4)

    return {
        "sequence_name": TARGET_RETURNS[ret],
        "status": "complete",
        "entry_event_index": entry_index + 1,
        "entry_args": entry_args(entry),
        "pre_commit_cell_event_index": (cell_index or 0) + 1,
        "pre_commit_cell": cell_state(cell_event, cell_pointer),
        "vtable_callback_event_index": (callback_index or 0) + 1,
        "vtable_callback": {
            "object_record_pointer": hex_word(object_pointer),
            "coordinate": {
                "x": first_words(callback_event)[1],
                "y": first_words(callback_event)[2],
                "level": first_words(callback_event)[3],
            },
        },
        "commit_entry_event_index": (commit_index or 0) + 1,
        "commit_entry": {
            "registers": registers(commit_event),
            "stack": stack_callback(commit_event),
            "generator_object_vector_before": before_header,
        },
        "append_return_event_index": (append_index or 0) + 1,
        "append_return": {
            "registers": registers(append_event),
            "generator_object_vector_after": after_header,
            "old_end_slot": {
                "address": hex_word(append_old_end),
                "words": [hex_word(word) for word in old_slot_words],
            },
        },
        "post_commit_cell_event_index": (after_index or 0) + 1,
        "post_commit_cell": cell_state(after_event, cell_pointer),
        "post_return_cell_event_index": (final_index or 0) + 1,
        "post_return_cell": cell_state(final_event, cell_pointer),
    }


def summarize(log_path: Path) -> dict[str, Any]:
    ledger = parse_winedbg_log(log_path)
    events = ledger.get("events", [])
    counts = Counter(str(event.get("address", "")).lower() for event in events)
    targets = [
        summarize_target(events, index)
        for index, event in enumerate(events)
        if str(event.get("address", "")).lower() == "0x004a5e03"
        and return_address(event) in TARGET_RETURNS
    ]

    def vector_end_advanced(target: dict[str, Any]) -> bool:
        before = target.get("commit_entry", {}).get("generator_object_vector_before", {})
        after = target.get("append_return", {}).get("generator_object_vector_after", {})
        if not before.get("end") or not after.get("end"):
            return False
        return int(after["end"], 16) == int(before["end"], 16) + 4

    def old_slot_matches_object(target: dict[str, Any]) -> bool:
        object_pointer = target.get("vtable_callback", {}).get("object_record_pointer")
        words = target.get("append_return", {}).get("old_end_slot", {}).get("words", [])
        return bool(words) and words[0] == object_pointer

    def cell_ref_matches_object(target: dict[str, Any]) -> bool:
        object_pointer = target.get("vtable_callback", {}).get("object_record_pointer")
        words = target.get("post_return_cell", {}).get("object_ref_vector", {}).get("first_words", [])
        return bool(words) and words[0] == object_pointer

    def low_word_cleared(target: dict[str, Any]) -> bool:
        before = target.get("pre_commit_cell", {}).get("generated_cell_words", {}).get("+0x20")
        after = target.get("post_return_cell", {}).get("generated_cell_words", {}).get("+0x20")
        if before is None or after is None:
            return False
        return (int(before, 16) & 0xFFFF) != 0 and (int(after, 16) & 0xFFFF) == 0

    complete_targets = [target for target in targets if target.get("status") == "complete"]
    invariants = {
        "native_behavior_changed": False,
        "two_target_sequences_complete": len(complete_targets) == 2,
        "target_commit_calls_return_to_0x4a5e6c": all(
            target.get("commit_entry", {}).get("stack", {}).get("return_address") == "0x004a5e6c"
            for target in complete_targets
        ),
        "object_vector_end_advances_one_dword": all(vector_end_advanced(target) for target in complete_targets),
        "object_vector_old_end_slot_contains_object_record": all(old_slot_matches_object(target) for target in complete_targets),
        "cell_object_ref_vector_contains_object_record": all(cell_ref_matches_object(target) for target in complete_targets),
        "target_cell_plus_0x20_low_word_cleared": all(low_word_cleared(target) for target in complete_targets),
    }
    completion_invariants = {
        key: value for key, value in invariants.items() if key != "native_behavior_changed"
    }
    status = (
        "post_border_guard_4a54a7_object_vector_and_cell_afterstate_recovered"
        if all(completion_invariants.values()) and invariants["native_behavior_changed"] is False
        else "post_border_guard_4a54a7_afterstate_incomplete"
    )
    return {
        "schema_id": "h3maped_4a54a7_afterstate_summary_v1",
        "status": status,
        "source_log": str(log_path),
        "event_count": len(events),
        "event_counts": dict(sorted(counts.items())),
        "target_sequences": targets,
        "invariants": invariants,
        "native_behavior_changed": False,
        "remaining_blocker": (
            "The sampled 0x4a54a7 target-cell/object-vector after-state is recovered for the two "
            "post-Border-Guard 0x4a5e03 materialization records. Remaining end-to-end recovery still "
            "needs the full 0x4a54a7 projection-loop write set, descriptor +0x29/+0x2c/+0x30 semantic "
            "names, relation-counter roles, and the connection from these writes back to relation/control "
            "records and later phase consumers."
        ),
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
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n")
    print(f"RMG_H3MAPED_4A54A7_AFTERSTATE_SUMMARY status={summary['status']} out={args.out}")
    return 0 if summary["status"].endswith("recovered") else 1


if __name__ == "__main__":
    raise SystemExit(main())
