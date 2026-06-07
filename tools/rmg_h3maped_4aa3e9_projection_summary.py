#!/usr/bin/env python3
"""Summarize H3MapEd 0x4aa3e9 wrapper projection state traces."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


ENTRY = "0x004aa3e9"
PRE_RETURN = "0x004aa5fc"


def normalize_address(value: str) -> str:
    return "0x%08x" % int(value, 0)


def stack_words_from_esp(event: dict[str, Any]) -> list[int]:
    esp = event.get("registers", {}).get("esp")
    if not isinstance(esp, int):
        return []
    return contiguous_words_at(event, esp, max_words=16)


def contiguous_words_at(event: dict[str, Any], address: int, max_words: int) -> list[int]:
    lines_by_address: dict[int, list[int]] = {}
    for line in event.get("memory_lines", []):
        line_address = int(line.get("address", -1))
        if line_address < 0 or line_address in lines_by_address:
            continue
        lines_by_address[line_address] = [int(word) & 0xFFFFFFFF for word in line.get("words", [])]

    words: list[int] = []
    expected = address
    while expected in lines_by_address and len(words) < max_words:
        line_words = lines_by_address[expected]
        take = min(len(line_words), max_words - len(words))
        words.extend(line_words[:take])
        expected += len(line_words) * 4
    return words


def signed32(value: int | None) -> int | None:
    if value is None:
        return None
    value &= 0xFFFFFFFF
    return value - 0x100000000 if value & 0x80000000 else value


def hex32(value: int | None) -> str:
    return "0x%08x" % (value & 0xFFFFFFFF) if isinstance(value, int) else ""


def wrapper_state(event: dict[str, Any], wrapper: int) -> dict[str, Any]:
    words = contiguous_words_at(event, wrapper, max_words=40) if wrapper else []

    def word_at(offset: int) -> int | None:
        index = offset // 4
        return words[index] if index < len(words) else None

    member_begin = word_at(0x2C)
    member_end = word_at(0x30)
    member_capacity = word_at(0x34)
    member_count = None
    if isinstance(member_begin, int) and isinstance(member_end, int) and member_end >= member_begin:
        member_count = (member_end - member_begin) // 4
    member_words = contiguous_words_at(event, member_begin, max_words=16) if isinstance(member_begin, int) else []

    return {
        "wrapper": hex32(wrapper),
        "words_prefix": [hex32(word) for word in words[:32]],
        "grid_base": hex32(word_at(0x08)),
        "width": signed32(word_at(0x0C)),
        "height": signed32(word_at(0x10)),
        "levels": signed32(word_at(0x14)),
        "bounds": {
            "min_x": signed32(word_at(0x18)),
            "min_y": signed32(word_at(0x1C)),
            "max_x": signed32(word_at(0x20)),
            "max_y": signed32(word_at(0x24)),
        },
        "selected_member_vector": {
            "begin": hex32(member_begin),
            "end": hex32(member_end),
            "capacity": hex32(member_capacity),
            "count": member_count,
            "words_prefix": [hex32(word) for word in member_words],
            "member_pointers": [hex32(word) for word in member_words[: member_count or 0]],
        },
        "candidate_vector_or_flag_prefix": {
            "+0x38": hex32(word_at(0x38)),
            "+0x3c": hex32(word_at(0x3C)),
            "+0x40": hex32(word_at(0x40)),
            "+0x44": hex32(word_at(0x44)),
            "+0x48": signed32(word_at(0x48)),
            "+0x4c": signed32(word_at(0x4C)),
            "+0x50": signed32(word_at(0x50)),
        },
        "selected_coordinate": {
            "x": signed32(word_at(0x54)),
            "y": signed32(word_at(0x58)),
            "level": signed32(word_at(0x5C)),
        },
    }


def entry_record(event: dict[str, Any], index: int) -> dict[str, Any]:
    stack = stack_words_from_esp(event)
    ret = stack[0] if len(stack) > 0 else None
    wrapper = stack[1] if len(stack) > 1 else None
    x = stack[2] if len(stack) > 2 else None
    y = stack[3] if len(stack) > 3 else None
    level = stack[4] if len(stack) > 4 else None
    return {
        "entry_event": index,
        "return_address": hex32(ret),
        "wrapper": hex32(wrapper),
        "selected_coordinate_arg": {"x": signed32(x), "y": signed32(y), "level": signed32(level)},
        "entry_registers": {
            key: event.get("registers", {}).get(key)
            for key in ("eax", "ebx", "ecx", "edx", "esi", "edi", "ebp", "esp")
            if key in event.get("registers", {})
        },
        "entry_wrapper_state": wrapper_state(event, wrapper or 0),
    }


def exit_record(event: dict[str, Any], index: int) -> dict[str, Any]:
    wrapper = event.get("registers", {}).get("ebx")
    return {
        "exit_event": index,
        "wrapper": hex32(wrapper),
        "exit_registers": {
            key: event.get("registers", {}).get(key)
            for key in ("eax", "ebx", "ecx", "edx", "esi", "edi", "ebp", "esp")
            if key in event.get("registers", {})
        },
        "exit_wrapper_state": wrapper_state(event, wrapper or 0),
    }


def summarize(ledger: dict[str, Any]) -> dict[str, Any]:
    pairs: list[dict[str, Any]] = []
    pending: dict[str, Any] | None = None
    orphan_exits = 0

    for index, event in enumerate(ledger.get("events", []), start=1):
        address = normalize_address(str(event.get("address", "0")))
        if address == ENTRY:
            if pending is not None:
                pairs.append({**pending, "outcome": "missing_exit"})
            pending = entry_record(event, index)
            continue
        if address == PRE_RETURN:
            if pending is None:
                orphan_exits += 1
                continue
            exit_data = exit_record(event, index)
            arg = pending["selected_coordinate_arg"]
            exit_coord = exit_data["exit_wrapper_state"]["selected_coordinate"]
            entry_coord = pending["entry_wrapper_state"]["selected_coordinate"]
            pairs.append(
                {
                    **pending,
                    **exit_data,
                    "outcome": "paired",
                    "wrapper_matches": pending["wrapper"] == exit_data["wrapper"],
                    "selected_coordinate_changed": entry_coord != exit_coord,
                    "exit_coordinate_matches_arg": arg == exit_coord,
                    "member_count": exit_data["exit_wrapper_state"]["selected_member_vector"]["count"],
                }
            )
            pending = None

    if pending is not None:
        pairs.append({**pending, "outcome": "missing_exit"})

    outcome_counts = Counter(pair["outcome"] for pair in pairs)
    member_count_distribution = Counter(str(pair.get("member_count")) for pair in pairs if pair["outcome"] == "paired")

    return {
        "schema_id": "h3maped_4aa3e9_projection_summary_v1",
        "ledger": ledger.get("log_path", ""),
        "event_count": int(ledger.get("event_count", 0)),
        "paired_count": outcome_counts["paired"],
        "orphan_exit_count": orphan_exits,
        "outcome_counts": dict(outcome_counts),
        "member_count_distribution": dict(member_count_distribution),
        "pairs_prefix": pairs[:24],
        "invariants": {
            "has_paired_entries": outcome_counts["paired"] > 0,
            "all_paired_wrappers_match": all(pair.get("wrapper_matches") for pair in pairs if pair["outcome"] == "paired"),
            "all_paired_exit_coordinates_match_args": all(
                pair.get("exit_coordinate_matches_arg") for pair in pairs if pair["outcome"] == "paired"
            ),
            "has_selected_coordinate_mutation": any(
                pair.get("selected_coordinate_changed") for pair in pairs if pair["outcome"] == "paired"
            ),
            "has_selected_members": any(
                (pair.get("member_count") or 0) > 0 for pair in pairs if pair["outcome"] == "paired"
            ),
        },
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    ledger = json.loads(args.ledger.read_text(encoding="utf-8"))
    summary = summarize(ledger)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    status = "pass" if all(summary["invariants"].values()) else "partial"
    print(
        "RMG_H3MAPED_4AA3E9_PROJECTION_SUMMARY "
        f"status={status} paired={summary['paired_count']} "
        f"member_counts={summary['member_count_distribution']} out={args.out}"
    )
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
