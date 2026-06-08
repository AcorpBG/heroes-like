#!/usr/bin/env python3
"""Summarize the H3MapEd candidate-container adoption RNG state.

The expected ledger is a focused ``0x4ac552`` trace with breakpoints at:

- ``0x4ac597``: immediately before the selected-container ``_rand`` call.
- ``0x4e727b``: after ``_rand`` has fetched its context pointer.
- ``0x4e728d``: after ``_rand`` has written the updated seed.
- ``0x4ac59c``: after ``_rand`` returns to the selector.
- ``0x4ac5a6``: after ``DIV EDI`` leaves the selected index in ``EDX``.

This is private-state evidence only. It does not change native RMG behavior and
does not infer final map parity from the selected index alone.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_LEDGER = Path(
    ".artifacts/rmg_recovery/medium_candidate_selection_rng_state_20260608/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_OUT = Path(".artifacts/rmg_recovery/candidate_selection_rng_summary.json")

RAND_MULTIPLIER = 0x343FD
RAND_INCREMENT = 0x269EC3
RAND_MASK = 0x7FFF


def event_by_address(ledger: dict[str, Any], address: str) -> dict[str, Any]:
    normalized = address.lower()
    matches = [
        event
        for event in ledger.get("events", [])
        if str(event.get("address", "")).lower() == normalized
    ]
    if len(matches) != 1:
        raise ValueError(f"expected one event at {address}, found {len(matches)}")
    return matches[0]


def flatten_words(event: dict[str, Any], dump_address: int | None = None) -> list[int]:
    words: list[int] = []
    for line in event.get("memory_lines", []):
        if dump_address is not None and int(line.get("address", 0)) < dump_address:
            continue
        words.extend(int(word) & 0xFFFFFFFF for word in line.get("words", []))
    return words


def parse_candidate_vector_header(event: dict[str, Any]) -> dict[str, Any]:
    registers = event.get("registers", {})
    esi = int(registers.get("esi", 0))
    header_address = esi + 0x10D4
    for line in event.get("memory_lines", []):
        if int(line.get("address", 0)) != header_address:
            continue
        words = [int(word) & 0xFFFFFFFF for word in line.get("words", [])]
        if len(words) < 3:
            break
        begin, end, capacity = words[:3]
        return {
            "header_address": "0x%08x" % header_address,
            "begin": "0x%08x" % begin,
            "end": "0x%08x" % end,
            "capacity": "0x%08x" % capacity,
            "count": (end - begin) // 4 if end >= begin else -1,
        }
    raise ValueError("candidate vector header dump not found")


def rand_return_from_seed(seed: int) -> tuple[int, int]:
    updated = ((seed * RAND_MULTIPLIER) + RAND_INCREMENT) & 0xFFFFFFFF
    returned = (updated >> 16) & RAND_MASK
    return updated, returned


def summarize(ledger: dict[str, Any]) -> dict[str, Any]:
    before_call = event_by_address(ledger, "0x004ac597")
    rand_context = event_by_address(ledger, "0x004e727b")
    rand_updated = event_by_address(ledger, "0x004e728d")
    after_call = event_by_address(ledger, "0x004ac59c")
    after_div = event_by_address(ledger, "0x004ac5a6")

    context_pointer = int(rand_context.get("registers", {}).get("eax", 0))
    before_words = flatten_words(rand_context, context_pointer)
    after_words = flatten_words(rand_updated, context_pointer)
    if len(before_words) < 6 or len(after_words) < 6:
        raise ValueError("rand context dumps do not include offset +0x14")

    pre_state = before_words[5]
    observed_updated_state = after_words[5]
    expected_updated_state, expected_return = rand_return_from_seed(pre_state)
    observed_return = int(after_call.get("registers", {}).get("eax", -1)) & 0xFFFFFFFF
    divisor = int(before_call.get("registers", {}).get("edi", -1))
    observed_selected_index = int(after_div.get("registers", {}).get("edx", -1))
    expected_selected_index = expected_return % divisor if divisor > 0 else -1
    candidate_vector = parse_candidate_vector_header(after_div)

    return {
        "schema_id": "h3maped_candidate_selection_rng_summary_v1",
        "status": (
            "candidate_selection_rng_state_matched"
            if observed_updated_state == expected_updated_state
            and observed_return == expected_return
            and observed_selected_index == expected_selected_index
            and candidate_vector["count"] == divisor
            else "candidate_selection_rng_state_mismatch"
        ),
        "source_ledger": ledger.get("log_path", ""),
        "selector": {
            "entry": "0x004ac552",
            "rand_call_site": "0x004ac597",
            "post_rand_site": "0x004ac59c",
            "post_div_site": "0x004ac5a6",
            "candidate_count_divisor": divisor,
            "selected_index_edx": observed_selected_index,
            "formula": "selected_index = _rand() % candidate_count",
        },
        "candidate_vector": candidate_vector,
        "rand": {
            "function": "0x004e7276",
            "context_function": "0x004eab23",
            "context_pointer": "0x%08x" % context_pointer,
            "state_offset": "0x14",
            "pre_state": pre_state,
            "pre_state_hex": "0x%08x" % pre_state,
            "multiplier": "0x%05x" % RAND_MULTIPLIER,
            "increment": "0x%06x" % RAND_INCREMENT,
            "observed_updated_state": "0x%08x" % observed_updated_state,
            "expected_updated_state": "0x%08x" % expected_updated_state,
            "observed_return": observed_return,
            "expected_return": expected_return,
            "return_formula": "((state * 0x343fd + 0x269ec3) >> 16) & 0x7fff",
        },
        "invariants": {
            "native_behavior_changed": False,
            "candidate_count_matches_vector_header": candidate_vector["count"] == divisor,
            "updated_state_matches_lcg": observed_updated_state == expected_updated_state,
            "return_matches_lcg": observed_return == expected_return,
            "selected_index_matches_remainder": observed_selected_index
            == expected_selected_index,
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
        "RMG_H3MAPED_CANDIDATE_SELECTION_RNG_SUMMARY "
        f"status={summary['status']} "
        f"pre_state={summary['rand']['pre_state']} "
        f"rand={summary['rand']['observed_return']} "
        f"candidate_count={summary['selector']['candidate_count_divisor']} "
        f"selected_index={summary['selector']['selected_index_edx']} "
        f"out={args.out}"
    )
    return 0 if summary["status"] == "candidate_selection_rng_state_matched" else 1


if __name__ == "__main__":
    raise SystemExit(main())
