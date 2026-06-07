#!/usr/bin/env python3
"""Pair H3MapEd 0x49d2e0 candidate entries with accept/reject outcomes."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


ENTRY = "0x0049d2e0"
REJECT = "0x0049d3e8"
ACCEPT = "0x0049d468"

CALLER_LABELS = {
    "0x0049d5a5": "0x49d471 secondary-member validator",
    "0x0049d111": "0x49cf34 selected-member candidate filter",
}


def normalize_address(value: str) -> str:
    return "0x%08x" % int(value, 0)


def stack_words_from_esp(event: dict[str, Any]) -> list[int]:
    esp = event.get("registers", {}).get("esp")
    if not isinstance(esp, int):
        return []
    expected = esp
    words: list[int] = []
    for line in event.get("memory_lines", []):
        address = int(line.get("address", -1))
        if address != expected:
            if words:
                break
            continue
        line_words = [int(word) & 0xFFFFFFFF for word in line.get("words", [])]
        words.extend(line_words)
        expected += len(line_words) * 4
    return words


def find_memory_words_at(event: dict[str, Any], address: int) -> list[int]:
    for line in event.get("memory_lines", []):
        if int(line.get("address", -1)) == address:
            return [int(word) & 0xFFFFFFFF for word in line.get("words", [])]
    return []


def entry_record(event: dict[str, Any], index: int) -> dict[str, Any]:
    stack = stack_words_from_esp(event)
    ret = normalize_address("0x0")
    arg_record = 0
    x = y = level = None
    if len(stack) >= 4:
        ret = normalize_address(hex(stack[0]))
        arg_record = stack[1]
        x = stack[2]
        y = stack[3]
    if len(stack) >= 5:
        level = stack[4]
    descriptor_words = find_memory_words_at(event, arg_record) if arg_record else []
    return {
        "entry_event": index,
        "caller_return": ret,
        "caller_label": CALLER_LABELS.get(ret, ""),
        "object_record": "0x%08x" % arg_record if arg_record else "",
        "descriptor_or_payload": "0x%08x" % descriptor_words[0] if descriptor_words else "",
        "candidate": {"x": x, "y": y, "level": level},
        "entry_registers": {
            key: event.get("registers", {}).get(key)
            for key in ("eax", "ebx", "ecx", "edx", "esi", "edi", "ebp", "esp")
            if key in event.get("registers", {})
        },
    }


def outcome_record(event: dict[str, Any], index: int) -> dict[str, Any]:
    address = normalize_address(str(event.get("address", "0")))
    return {
        "outcome_event": index,
        "outcome_address": address,
        "outcome": "accept" if address == ACCEPT else "reject",
        "outcome_registers": {
            key: event.get("registers", {}).get(key)
            for key in ("eax", "ebx", "ecx", "edx", "esi", "edi", "ebp", "esp")
            if key in event.get("registers", {})
        },
    }


def summarize(ledger: dict[str, Any]) -> dict[str, Any]:
    pairs: list[dict[str, Any]] = []
    pending: dict[str, Any] | None = None
    orphan_outcomes = 0

    for index, event in enumerate(ledger.get("events", []), start=1):
        address = normalize_address(str(event.get("address", "0")))
        if address == ENTRY:
            if pending is not None:
                pairs.append({**pending, "outcome": "missing", "outcome_event": None, "outcome_address": ""})
            pending = entry_record(event, index)
            continue
        if address in {ACCEPT, REJECT}:
            if pending is None:
                orphan_outcomes += 1
                continue
            pairs.append({**pending, **outcome_record(event, index)})
            pending = None

    missing_outcomes = 0
    if pending is not None:
        missing_outcomes = 1
        pairs.append({**pending, "outcome": "missing", "outcome_event": None, "outcome_address": ""})

    outcome_counts = Counter(pair["outcome"] for pair in pairs)
    caller_counts: dict[str, Counter[str]] = {}
    for pair in pairs:
        caller = pair.get("caller_return", "")
        caller_counts.setdefault(caller, Counter())[pair["outcome"]] += 1

    unique_candidates = {
        (
            pair.get("caller_return", ""),
            pair.get("object_record", ""),
            pair.get("candidate", {}).get("x"),
            pair.get("candidate", {}).get("y"),
            pair.get("candidate", {}).get("level"),
            pair.get("outcome", ""),
        )
        for pair in pairs
    }

    return {
        "schema_id": "h3maped_49d2e0_outcome_summary_v1",
        "ledger": ledger.get("log_path", ""),
        "event_count": int(ledger.get("event_count", 0)),
        "paired_count": len([pair for pair in pairs if pair["outcome"] != "missing"]),
        "missing_outcome_count": missing_outcomes,
        "orphan_outcome_count": orphan_outcomes,
        "outcome_counts": dict(outcome_counts),
        "caller_outcome_counts": {
            caller: {"label": CALLER_LABELS.get(caller, ""), "outcomes": dict(counts)}
            for caller, counts in sorted(caller_counts.items())
        },
        "unique_candidate_outcome_count": len(unique_candidates),
        "ordered_pairs_prefix": pairs[:120],
        "invariants": {
            "has_paired_entries": bool(pairs),
            "has_accepts": outcome_counts["accept"] > 0,
            "has_rejects": outcome_counts["reject"] > 0,
            "has_secondary_member_validator_entries": any(pair.get("caller_return") == "0x0049d5a5" for pair in pairs),
            "has_selected_member_filter_entries": any(pair.get("caller_return") == "0x0049d111" for pair in pairs),
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
    status = "pass" if summary["invariants"]["has_accepts"] and summary["invariants"]["has_rejects"] else "partial"
    print(
        "RMG_H3MAPED_49D2E0_OUTCOME_SUMMARY "
        f"status={status} paired={summary['paired_count']} outcomes={summary['outcome_counts']} out={args.out}"
    )
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
