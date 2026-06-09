#!/usr/bin/env python3
"""Summarize sampled H3MapEd ``0x4a696b`` argument and branch frontier state.

This is a recovery artifact, not a native RMG validator.  It turns debugger
ledger snapshots into the human-readable records that ``0x4a696b`` consumes:
source scan bounds, control bytes, and the observed branch frontier.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_LEDGER = Path(
    ".artifacts/rmg_recovery/medium_seed10_4a696b_arg_surface_trace_20260609/"
    "winedbg_4a61bc_payload_link_dynamic_trace_ledger.json"
)
DEFAULT_OUT = Path(
    ".artifacts/rmg_recovery/medium_seed10_4a696b_arg_surface_summary_20260609.json"
)

ENTRY = "0x004a696b"
SAME_LEVEL_PASS = "0x004a69c2"
SOURCE_RELATION_MATCH_CHECKPOINT = "0x004a6a81"
TERRAIN_CHECKPOINT = "0x004a6a8f"
HELPER_49AA93_RETURN_TEST = "0x004a6ac8"
HELPER_4A6795_RETURN_TEST = "0x004a6ade"
CANDIDATE_APPEND = "0x004a6ae2"
SCAN_DONE = "0x004a6b10"
NO_CANDIDATE_EXIT = "0x004a6b27"
CANDIDATE_PATH = "0x004a6b2e"
VTABLE_COMMIT = "0x004a6b9b"
DIRECT_MUTATION_TEST = "0x004a6c13"
DIRECT_MUTATION_AFTER = "0x004a6c2c"
FALSE_RETURN_PREP = "0x004a6cd3"
RETURN_SITE = "0x004a6ce1"

TRACKED = [
    ENTRY,
    SAME_LEVEL_PASS,
    SOURCE_RELATION_MATCH_CHECKPOINT,
    TERRAIN_CHECKPOINT,
    HELPER_49AA93_RETURN_TEST,
    HELPER_4A6795_RETURN_TEST,
    CANDIDATE_APPEND,
    SCAN_DONE,
    NO_CANDIDATE_EXIT,
    CANDIDATE_PATH,
    VTABLE_COMMIT,
    DIRECT_MUTATION_TEST,
    DIRECT_MUTATION_AFTER,
    FALSE_RETURN_PREP,
    RETURN_SITE,
]


def qhex(value: int | None) -> str | None:
    return None if value is None else f"0x{value & 0xFFFFFFFF:08x}"


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def event_address(event: dict[str, Any]) -> str:
    return str(event.get("address", "")).lower()


def memory_word(memory_lines: list[dict[str, Any]], address: int) -> int | None:
    for line in memory_lines:
        base = line.get("address")
        words = line.get("words", [])
        if not isinstance(base, int):
            continue
        if base <= address < base + len(words) * 4 and (address - base) % 4 == 0:
            index = (address - base) // 4
            value = words[index]
            return int(value) & 0xFFFFFFFF if isinstance(value, int) else None
    return None


def memory_byte(memory_lines: list[dict[str, Any]], address: int) -> int | None:
    word = memory_word(memory_lines, address & ~3)
    if word is None:
        return None
    return (word >> ((address & 3) * 8)) & 0xFF


def signed32(value: int | None) -> int | None:
    if value is None:
        return None
    value &= 0xFFFFFFFF
    return value - 0x100000000 if value & 0x80000000 else value


def read_triplet(memory_lines: list[dict[str, Any]], base: int) -> dict[str, int | None]:
    return {
        "x": signed32(memory_word(memory_lines, base)),
        "y": signed32(memory_word(memory_lines, base + 4)),
        "level": signed32(memory_word(memory_lines, base + 8)),
    }


def parse_source_record(memory_lines: list[dict[str, Any]], pointer: int | None) -> dict[str, Any]:
    if pointer is None:
        return {"pointer": None, "captured": False}
    x_min = signed32(memory_word(memory_lines, pointer + 0x20))
    y_min = signed32(memory_word(memory_lines, pointer + 0x24))
    x_max = signed32(memory_word(memory_lines, pointer + 0x28))
    y_max = signed32(memory_word(memory_lines, pointer + 0x2C))
    scan_area = None
    if None not in {x_min, y_min, x_max, y_max}:
        scan_area = max(0, int(x_max) - int(x_min)) * max(0, int(y_max) - int(y_min))
    return {
        "pointer": qhex(pointer),
        "captured": memory_word(memory_lines, pointer) is not None,
        "leading_pointer": qhex(memory_word(memory_lines, pointer)),
        "initial_words": [qhex(memory_word(memory_lines, pointer + offset)) for offset in range(0, 0x10, 4)],
        "coordinate_at_0x10": read_triplet(memory_lines, pointer + 0x10),
        "scan_bounds_exclusive": {
            "x_min": x_min,
            "y_min": y_min,
            "x_max": x_max,
            "y_max": y_max,
            "area": scan_area,
        },
        "tail_words_0x30": [
            qhex(memory_word(memory_lines, pointer + offset)) for offset in range(0x30, 0x50, 4)
        ],
    }


def parse_control_record(memory_lines: list[dict[str, Any]], pointer: int | None) -> dict[str, Any]:
    if pointer is None:
        return {"pointer": None, "captured": False}
    return {
        "pointer": qhex(pointer),
        "captured": memory_word(memory_lines, pointer) is not None,
        "leading_pointer": qhex(memory_word(memory_lines, pointer)),
        "word_0x04": qhex(memory_word(memory_lines, pointer + 0x04)),
        "control_bytes_0x08_to_0x0b": {
            f"+0x{offset:02x}": memory_byte(memory_lines, pointer + offset)
            for offset in range(0x08, 0x0C)
        },
        "coordinate_at_0x10": read_triplet(memory_lines, pointer + 0x10),
        "words_0x20_to_0x3c": [
            qhex(memory_word(memory_lines, pointer + offset)) for offset in range(0x20, 0x40, 4)
        ],
    }


def grouped_calls(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    calls: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    for index, event in enumerate(events):
        address = event_address(event)
        if address == ENTRY:
            if current is not None:
                calls.append(current)
            registers = event.get("registers", {})
            memory_lines = event.get("memory_lines", [])
            esp = registers.get("esp")
            arg1 = memory_word(memory_lines, int(esp) + 4) if isinstance(esp, int) else None
            arg2 = memory_word(memory_lines, int(esp) + 8) if isinstance(esp, int) else None
            current = {
                "entry_event_index": index,
                "return_address": event.get("derived", {}).get("return_address"),
                "entry_registers": {
                    name: qhex(value) for name, value in registers.items() if name in {"ecx", "edx", "esi", "esp", "ebp"}
                },
                "stack_args": {
                    "source_record_arg1": qhex(arg1),
                    "control_record_arg2": qhex(arg2),
                },
                "source_record": parse_source_record(memory_lines, arg1),
                "control_record": parse_control_record(memory_lines, arg2),
                "sites": [],
            }
        if current is not None and address in TRACKED:
            current["sites"].append(address)
            if address == RETURN_SITE:
                calls.append(current)
                current = None
    if current is not None:
        calls.append(current)
    for call in calls:
        sites = set(call["sites"])
        if DIRECT_MUTATION_TEST in sites:
            classification = "reached_direct_mutation_block"
        elif CANDIDATE_PATH in sites:
            classification = "reached_candidate_path_without_direct_mutation"
        elif SCAN_DONE in sites and NO_CANDIDATE_EXIT in sites and SOURCE_RELATION_MATCH_CHECKPOINT not in sites:
            classification = "nonempty_scan_no_source_relation_match"
        elif SCAN_DONE in sites and NO_CANDIDATE_EXIT in sites:
            classification = "scan_done_no_candidate_after_source_relation_progress"
        else:
            classification = "incomplete"
        call["classification"] = classification
        call["branch_frontier"] = {
            "same_level_passed": SAME_LEVEL_PASS in sites,
            "source_relation_match_checkpoint_hit": SOURCE_RELATION_MATCH_CHECKPOINT in sites,
            "helper_49aa93_reached": HELPER_49AA93_RETURN_TEST in sites,
            "helper_4a6795_reached": HELPER_4A6795_RETURN_TEST in sites,
            "candidate_append_reached": CANDIDATE_APPEND in sites,
            "candidate_path_reached": CANDIDATE_PATH in sites,
            "direct_mutation_reached": DIRECT_MUTATION_TEST in sites,
            "returned": RETURN_SITE in sites,
        }
    return calls


def summarize(ledger_path: Path) -> dict[str, Any]:
    ledger = load_json(ledger_path)
    events = ledger.get("events", [])
    calls = grouped_calls(events)
    address_counts = Counter(event_address(event) for event in events)
    classifications = Counter(call["classification"] for call in calls)

    calls_with_arg_dumps = [
        call
        for call in calls
        if call.get("source_record", {}).get("captured")
        and call.get("control_record", {}).get("captured")
    ]
    nonempty_scans = [
        call
        for call in calls_with_arg_dumps
        if (call.get("source_record", {}).get("scan_bounds_exclusive", {}).get("area") or 0) > 0
    ]
    invariants = {
        "ledger_has_events": len(events) > 0,
        "sampled_4a696b_calls": len(calls) > 0,
        "all_sampled_calls_have_source_and_control_arg_dumps": len(calls_with_arg_dumps) == len(calls),
        "all_arg_dumped_calls_have_nonempty_scan_bounds": len(nonempty_scans) == len(calls_with_arg_dumps),
        "all_sampled_calls_pass_same_level_gate": all(call["branch_frontier"]["same_level_passed"] for call in calls),
        "no_sampled_call_reaches_source_relation_match_checkpoint": address_counts.get(SOURCE_RELATION_MATCH_CHECKPOINT, 0) == 0,
        "no_sampled_call_reaches_candidate_append": address_counts.get(CANDIDATE_APPEND, 0) == 0,
        "no_sampled_call_reaches_direct_mutation": address_counts.get(DIRECT_MUTATION_TEST, 0) == 0,
        "no_native_behavior_change": True,
    }
    status = (
        "partial_recovery_4a696b_arg_surface_owner_match_frontier"
        if all(value for key, value in invariants.items() if key != "no_native_behavior_change")
        else "incomplete"
    )
    return {
        "schema_id": "h3maped_4a696b_arg_surface_summary_v1",
        "status": status,
        "ledger": str(ledger_path),
        "seed_control": ledger.get("seed_control"),
        "event_count": ledger.get("event_count", len(events)),
        "address_counts": {key: address_counts.get(key, 0) for key in TRACKED if address_counts.get(key, 0)},
        "call_classifications": dict(sorted(classifications.items())),
        "metrics": {
            "sampled_4a696b_calls": len(calls),
            "calls_with_arg_dumps": len(calls_with_arg_dumps),
            "nonempty_scan_calls": len(nonempty_scans),
            "source_relation_match_hits": address_counts.get(SOURCE_RELATION_MATCH_CHECKPOINT, 0),
            "candidate_append_hits": address_counts.get(CANDIDATE_APPEND, 0),
            "direct_mutation_hits": address_counts.get(DIRECT_MUTATION_TEST, 0),
        },
        "invariants": invariants,
        "static_branch_chain": [
            "0x4a69b3/0x4a69c2 first gates on same-level relation coordinates.",
            "0x4a6a27..0x4a6b05 scans arg1 +0x20/+0x24/+0x28/+0x2c as exclusive x/y bounds.",
            "0x4a6a63 and 0x4a6a6f compare GeneratedCell+0x20 owner/relation bytes against the two source relation ids.",
            "0x4a6a81 is reached only after both owner/relation byte comparisons pass.",
            "0x4a6ae2 appends candidates only after source/relation match, terrain, 0x49aa93, and 0x4a6795 pass.",
            "0x4a6c13 is the direct GeneratedCell+0x28 mutation block and is only reachable from the non-empty candidate path.",
        ],
        "calls": calls,
        "source_backed_conclusion": (
            "In this sampled Medium seed-10 argument-surface replay, every sampled 0x4a696b call "
            "has captured arg1 source scan bounds and arg2 control records, each scan rectangle is "
            "non-empty, and every call reaches scan completion/no-candidate exit without ever hitting "
            "0x4a6a81. Because 0x4a6a81 is after the two GeneratedCell+0x20 owner/relation byte "
            "comparisons, the sampled failure frontier is specifically no scanned generated cell "
            "matching both source relation bytes, before terrain/helper/candidate/direct-mutation logic."
        ),
        "remaining_gap": (
            "This narrows the sampled branch frontier but does not prove global unreachability. "
            "End-to-end recovery still needs either a natural sample that reaches 0x4a6a81, or a "
            "stronger static/data proof that the owner/relation byte match cannot occur for target "
            "one-level land generation. Cleanup/uncommit 0x4add76/0x4adef7 remains unrecovered."
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    summary = summarize(args.ledger)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_4A696B_ARG_SURFACE_SUMMARY status={summary['status']} out={args.out}")
    return 0 if summary["status"].startswith("partial_recovery_") else 1


if __name__ == "__main__":
    raise SystemExit(main())
