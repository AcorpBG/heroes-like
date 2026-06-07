#!/usr/bin/env python3
"""Summarize H3MapEd 0x49d2e0 internal branch evidence."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


ENTRY = "0x0049d2e0"
REJECT = "0x0049d3e8"
ACCEPT = "0x0049d468"

BRANCH_LABELS = {
    "0x0049d34c": "policy-plus-1-zero precheck rejects when a 0x5a2680-window wrapper cell has bit22 set",
    "0x0049d3a7": "existing bit22 control neighbor rejects when neighbor descriptor policy byte +2 is zero",
    "0x0049d3ad": "existing bit22 control neighbor rejects when neighbor descriptor policy byte +1 is zero",
    "0x0049d3e2": "non-54/9 footprint/object probe rejects when 0x49a6f9 returns true and falls through to false",
    "0x0049d408": "type 54/9 special-case footprint probe rejects when 0x49a6f9 reports collision",
    "0x0049d466": "type 54/9 special-case rejects when all eight neighbor cells are unavailable after collision pass",
}
BRANCHES = set(BRANCH_LABELS)

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
    ret = "0x00000000"
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
    }


def branch_record(event: dict[str, Any], index: int) -> dict[str, Any]:
    address = normalize_address(str(event.get("address", "0")))
    return {
        "branch_event": index,
        "branch_address": address,
        "branch_label": BRANCH_LABELS[address],
        "registers": {
            key: event.get("registers", {}).get(key)
            for key in ("eax", "ebx", "ecx", "edx", "esi", "edi", "ebp", "esp", "eip")
            if key in event.get("registers", {})
        },
    }


def outcome_record(event: dict[str, Any], index: int) -> dict[str, Any]:
    address = normalize_address(str(event.get("address", "0")))
    return {
        "outcome_event": index,
        "outcome_address": address,
        "outcome": "accept" if address == ACCEPT else "reject",
    }


def summarize(ledger: dict[str, Any]) -> dict[str, Any]:
    pairs: list[dict[str, Any]] = []
    pending: dict[str, Any] | None = None
    pending_branches: list[dict[str, Any]] = []
    orphan_outcomes = 0
    orphan_branches = 0

    for index, event in enumerate(ledger.get("events", []), start=1):
        address = normalize_address(str(event.get("address", "0")))
        if address == ENTRY:
            if pending is not None:
                pairs.append(
                    {
                        **pending,
                        "outcome": "missing",
                        "outcome_event": None,
                        "outcome_address": "",
                        "branches": pending_branches,
                        "reject_branch_address": "",
                        "reject_branch_label": "missing outcome",
                    }
                )
            pending = entry_record(event, index)
            pending_branches = []
            continue
        if address in BRANCHES:
            if pending is None:
                orphan_branches += 1
                continue
            pending_branches.append(branch_record(event, index))
            continue
        if address in {ACCEPT, REJECT}:
            if pending is None:
                orphan_outcomes += 1
                continue
            outcome = outcome_record(event, index)
            reject_branch = pending_branches[-1] if outcome["outcome"] == "reject" and pending_branches else None
            pairs.append(
                {
                    **pending,
                    **outcome,
                    "branches": pending_branches,
                    "reject_branch_address": reject_branch["branch_address"] if reject_branch else "",
                    "reject_branch_label": reject_branch["branch_label"] if reject_branch else "unclassified_no_intermediate_branch_stop",
                }
            )
            pending = None
            pending_branches = []

    missing_outcomes = 0
    if pending is not None:
        missing_outcomes = 1
        pairs.append(
            {
                **pending,
                "outcome": "missing",
                "outcome_event": None,
                "outcome_address": "",
                "branches": pending_branches,
                "reject_branch_address": "",
                "reject_branch_label": "missing outcome",
            }
        )

    outcome_counts = Counter(pair["outcome"] for pair in pairs)
    branch_event_counts = Counter(
        branch["branch_address"]
        for pair in pairs
        for branch in pair.get("branches", [])
    )
    reject_branch_counts = Counter(
        pair["reject_branch_label"]
        for pair in pairs
        if pair["outcome"] == "reject"
    )
    reject_address_counts = Counter(
        pair["reject_branch_address"] or "unclassified"
        for pair in pairs
        if pair["outcome"] == "reject"
    )
    caller_outcome_counts: dict[str, Counter[str]] = {}
    for pair in pairs:
        caller = pair.get("caller_return", "")
        caller_outcome_counts.setdefault(caller, Counter())[pair["outcome"]] += 1

    return {
        "schema_id": "h3maped_49d2e0_branch_summary_v1",
        "ledger": ledger.get("log_path", ""),
        "event_count": int(ledger.get("event_count", 0)),
        "paired_count": len([pair for pair in pairs if pair["outcome"] != "missing"]),
        "missing_outcome_count": missing_outcomes,
        "orphan_outcome_count": orphan_outcomes,
        "orphan_branch_count": orphan_branches,
        "outcome_counts": dict(outcome_counts),
        "caller_outcome_counts": {
            caller: {"label": CALLER_LABELS.get(caller, ""), "outcomes": dict(counts)}
            for caller, counts in sorted(caller_outcome_counts.items())
        },
        "branch_event_counts": {
            address: {"label": BRANCH_LABELS[address], "count": branch_event_counts[address]}
            for address in sorted(BRANCH_LABELS)
        },
        "reject_branch_address_counts": dict(reject_address_counts),
        "reject_reason_counts": dict(reject_branch_counts),
        "reject_pairs": [pair for pair in pairs if pair["outcome"] == "reject"],
        "ordered_pairs_prefix": pairs[:80],
        "static_reject_addresses": BRANCH_LABELS,
        "invariants": {
            "has_paired_entries": bool(pairs),
            "has_accepts": outcome_counts["accept"] > 0,
            "has_rejects": outcome_counts["reject"] > 0,
            "has_internal_branch_hits": sum(branch_event_counts.values()) > 0,
            "has_classified_rejects": any(
                pair["outcome"] == "reject" and pair["reject_branch_address"]
                for pair in pairs
            ),
            "keeps_unclassified_rejects_explicit": any(
                pair["outcome"] == "reject" and not pair["reject_branch_address"]
                for pair in pairs
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
    status = (
        "pass"
        if summary["invariants"]["has_accepts"]
        and summary["invariants"]["has_rejects"]
        and summary["invariants"]["has_internal_branch_hits"]
        else "partial"
    )
    print(
        "RMG_H3MAPED_49D2E0_BRANCH_SUMMARY "
        f"status={status} paired={summary['paired_count']} "
        f"outcomes={summary['outcome_counts']} reject_reasons={summary['reject_reason_counts']} out={args.out}"
    )
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
