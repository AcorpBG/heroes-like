#!/usr/bin/env python3
"""Summarize post-Border-Guard ``0x4a7605 -> 0x4a5e03`` side-effect evidence.

This report parses the focused Medium seed-10 WineDbg trace that follows the
natural Border Guard endpoint misses into the two downstream materialization
calls. It records only recovered H3MapEd state and does not change native RMG
behavior.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

from rmg_h3maped_recovery_trace import parse_winedbg_log


DEFAULT_TRACE_LOG = Path(
    ".artifacts/rmg_recovery/medium_seed10_7605_4a5e03_side_effect_trace_20260608/"
    "winedbg_interactive_trace.log"
)
DEFAULT_OUT = Path(
    ".artifacts/rmg_recovery/medium_seed10_4a5e03_side_effect_summary_20260608.json"
)

TARGET_RETURNS = {
    "0x004a77ad": "first_0x4a7605_materialization",
    "0x004a789a": "second_0x4a7605_materialization",
}
RETURN_TO_CALLSITE = {
    "0x004a77ad": "0x004a77a8",
    "0x004a789a": "0x004a7895",
}


def hex_word(value: int | None) -> str | None:
    if value is None:
        return None
    return "0x%08x" % (int(value) & 0xFFFFFFFF)


def words_at(event: dict[str, Any], address: int | None = None) -> list[int]:
    for memory_line in event.get("memory_lines", []):
        if address is None or int(memory_line.get("address", -1)) == address:
            return [int(word) & 0xFFFFFFFF for word in memory_line.get("words", [])]
    return []


def block_words_at(event: dict[str, Any], address: int, max_words: int) -> list[int]:
    by_address: dict[int, list[int]] = {}
    for memory_line in event.get("memory_lines", []):
        line_address = int(memory_line.get("address", -1))
        by_address[line_address] = [
            int(word) & 0xFFFFFFFF for word in memory_line.get("words", [])
        ]
    words: list[int] = []
    cursor = address
    while len(words) < max_words and cursor in by_address:
        words.extend(by_address[cursor])
        cursor += len(by_address[cursor]) * 4
    return words[:max_words]


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


def registers(event: dict[str, Any], names: tuple[str, ...] = ("eax", "ebx", "ecx", "edx", "esi", "edi", "esp")) -> dict[str, str]:
    raw = event.get("registers", {})
    return {
        name: hex_word(int(raw[name])) or "missing"
        for name in names
        if name in raw
    }


def entry_args(event: dict[str, Any]) -> dict[str, Any]:
    first = first_words(event)
    second = event.get("memory_lines", [{}])[1].get("words", []) if len(event.get("memory_lines", [])) > 1 else []
    level = int(second[0]) & 0xFFFFFFFF if second else None
    return {
        "return_address": return_address(event),
        "arg0": hex_word(first[1] if len(first) > 1 else None),
        "x": first[2] if len(first) > 2 else None,
        "y": first[3] if len(first) > 3 else None,
        "level": level,
    }


def callsite_args(event: dict[str, Any]) -> dict[str, Any]:
    words = first_words(event)
    return {
        "arg0": hex_word(words[0] if len(words) > 0 else None),
        "x": words[1] if len(words) > 1 else None,
        "y": words[2] if len(words) > 2 else None,
        "level": words[3] if len(words) > 3 else None,
    }


def cell_summary(event: dict[str, Any]) -> dict[str, Any]:
    cell_pointer = int(event.get("registers", {}).get("eax", 0))
    words = block_words_at(event, cell_pointer, 16)
    cell20 = words[8] if len(words) > 8 else None
    owner_byte = ((cell20 or 0) >> 16) & 0xFF if cell20 is not None else None
    if owner_byte is not None and owner_byte >= 0x80:
        owner_byte -= 0x100
    return {
        "cell_pointer": hex_word(cell_pointer),
        "raw_words": [hex_word(word) for word in words],
        "object_ref_vector": {
            "begin": hex_word(words[1] if len(words) > 1 else None),
            "end": hex_word(words[2] if len(words) > 2 else None),
            "empty": len(words) > 2 and words[1] == words[2],
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
        "owner_relation_index_from_plus_0x20_byte2": owner_byte,
        "owner_relation_pointer_edx": hex_word(int(event.get("registers", {}).get("edx", 0))),
    }


def object_record_summary(event: dict[str, Any]) -> dict[str, Any]:
    object_pointer = int(event.get("registers", {}).get("eax", 0))
    words = block_words_at(event, object_pointer, 8)
    return {
        "object_record_pointer": hex_word(object_pointer),
        "raw_words": [hex_word(word) for word in words],
        "vtable": hex_word(words[0] if len(words) > 0 else None),
        "descriptor_or_payload_pointer": hex_word(words[1] if len(words) > 1 else None),
        "word_plus_0x1c": hex_word(words[7] if len(words) > 7 else None),
        "returned_nonzero": object_pointer != 0,
    }


def commit_callback_summary(event: dict[str, Any]) -> dict[str, Any]:
    words = first_words(event)
    return {
        "stack_object_record_pointer": hex_word(words[0] if len(words) > 0 else None),
        "stack_coordinate": {
            "x": words[1] if len(words) > 1 else None,
            "y": words[2] if len(words) > 2 else None,
            "level": words[3] if len(words) > 3 else None,
        },
        "generator_ecx": hex_word(int(event.get("registers", {}).get("ecx", 0))),
        "generator_vtable_edx": hex_word(int(event.get("registers", {}).get("edx", 0))),
        "resolved_vtable_slot_plus_0x04": "0x004a54a7",
    }


def summarize_target_sequence(events: list[dict[str, Any]], entry_index: int) -> dict[str, Any]:
    entry = events[entry_index]
    ret = return_address(entry)
    sequence: dict[str, Any] = {
        "sequence_name": TARGET_RETURNS[ret],
        "entry_event_index": entry_index + 1,
        "return_address": ret,
        "expected_callsite": RETURN_TO_CALLSITE[ret],
        "entry_args": entry_args(entry),
        "entry_registers": registers(entry),
        "post_commit_cell_after_state_captured": False,
    }
    for event in events[max(0, entry_index - 1) : entry_index]:
        if str(event.get("address", "")).lower() == RETURN_TO_CALLSITE[ret]:
            sequence["callsite_args"] = callsite_args(event)
            sequence["callsite_event_index"] = events.index(event) + 1
    for offset, event in enumerate(events[entry_index + 1 : entry_index + 8], start=entry_index + 2):
        address = str(event.get("address", "")).lower()
        if address == "0x004a5e2b":
            sequence["computed_cell_pointer_event"] = {
                "event_index": offset,
                "cell_pointer_eax": hex_word(int(event.get("registers", {}).get("eax", 0))),
            }
        elif address == "0x004a5e4a":
            sequence["pre_commit_cell"] = {"event_index": offset, **cell_summary(event)}
        elif address == "0x004a5e55":
            sequence["constructed_object_record"] = {"event_index": offset, **object_record_summary(event)}
        elif address == "0x004a5e59":
            sequence["nonzero_object_branch"] = {
                "event_index": offset,
                "eax": hex_word(int(event.get("registers", {}).get("eax", 0))),
                "branch_enters_vtable_commit": int(event.get("registers", {}).get("eax", 0)) != 0,
            }
        elif address == "0x004a5e69":
            sequence["vtable_commit_callback"] = {"event_index": offset, **commit_callback_summary(event)}
        elif address == "0x004a5e6c":
            sequence["after_vtable_callback_site"] = {
                "event_index": offset,
                "registers": registers(event),
            }
    return sequence


def summarize(log_path: Path) -> dict[str, Any]:
    ledger = parse_winedbg_log(log_path)
    events = ledger.get("events", [])
    counts = Counter(str(event.get("address", "")).lower() for event in events)
    targets = [
        summarize_target_sequence(events, index)
        for index, event in enumerate(events)
        if str(event.get("address", "")).lower() == "0x004a5e03"
        and return_address(event) in TARGET_RETURNS
    ]
    object_pointer_matches_commit = all(
        target.get("constructed_object_record", {}).get("object_record_pointer")
        == target.get("vtable_commit_callback", {}).get("stack_object_record_pointer")
        for target in targets
    )
    coordinate_matches_entry = all(
        target.get("entry_args", {}).get("x") == target.get("vtable_commit_callback", {}).get("stack_coordinate", {}).get("x")
        and target.get("entry_args", {}).get("y") == target.get("vtable_commit_callback", {}).get("stack_coordinate", {}).get("y")
        and target.get("entry_args", {}).get("level") == target.get("vtable_commit_callback", {}).get("stack_coordinate", {}).get("level")
        for target in targets
    )
    cells_empty = all(
        target.get("pre_commit_cell", {}).get("object_ref_vector", {}).get("empty") is True
        for target in targets
    )
    all_reach_commit = all("vtable_commit_callback" in target for target in targets)
    status = "post_border_guard_4a5e03_delegates_to_4a54a7_commit_replay_pending"
    if len(targets) != 2 or not all_reach_commit:
        status = "post_border_guard_4a5e03_evidence_incomplete"
    return {
        "schema_id": "h3maped_4a5e03_side_effect_summary_v1",
        "status": status,
        "source_log": str(log_path),
        "event_count": len(events),
        "event_counts": dict(sorted(counts.items())),
        "target_sequences": targets,
        "static_vtable_context": {
            "generator_vtable": "0x00540cbc",
            "slot_plus_0x00": "0x0049ef5c",
            "slot_plus_0x04": "0x004a54a7",
            "source": "Recovered from h3maped.exe .rdata vtable bytes at 0x540cbc.",
        },
        "invariants": {
            "native_behavior_changed": False,
            "two_post_border_guard_7605_4a5e03_calls_observed": len(targets) == 2,
            "both_target_cells_had_empty_object_ref_vectors_before_commit": cells_empty,
            "both_4a5c07_object_records_returned_nonzero": all(
                target.get("constructed_object_record", {}).get("returned_nonzero") is True
                for target in targets
            ),
            "object_record_pointer_passed_to_vtable_commit": object_pointer_matches_commit,
            "entry_coordinate_passed_to_vtable_commit": coordinate_matches_entry,
            "vtable_slot_plus_0x04_resolves_to_0x4a54a7": all(
                target.get("vtable_commit_callback", {}).get("resolved_vtable_slot_plus_0x04") == "0x004a54a7"
                for target in targets
            ),
            "post_commit_cell_after_state_captured": False,
        },
        "remaining_blocker": (
            "Recover 0x4a54a7 callee-side generated-cell/object-vector side effects "
            "for the two 0x4a5e03-created object records and coordinates, including "
            "post-commit GeneratedCell+0x20/+0x24/+0x28/+0x2c after-state and the "
            "generator +0xec4/+0xecc object-vector insertion."
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
    print(f"RMG_H3MAPED_4A5E03_SIDE_EFFECT_SUMMARY status={summary['status']} out={args.out}")
    return 0 if summary["status"].endswith("replay_pending") else 1


if __name__ == "__main__":
    raise SystemExit(main())
