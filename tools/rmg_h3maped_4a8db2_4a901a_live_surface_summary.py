#!/usr/bin/env python3
"""Summarize live 0x4a8db2 -> 0x4a901a caller/body recovery traces.

This is recovery evidence only. The traces are allowed to end by debugger
timeout after the bounded breakpoint surface is exhausted; this parser uses
the WineDbg logs directly because no ledger is emitted on that timeout path.
"""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_SOURCE_LOG = Path(
    ".artifacts/rmg_recovery/4a8db2_source_record_surface_trace_20260608/"
    "winedbg_interactive_trace.log"
)
DEFAULT_BODY_LOG = Path(
    ".artifacts/rmg_recovery/4a901a_body_outcome_trace_20260608/"
    "winedbg_interactive_trace.log"
)
DEFAULT_STATIC_4A8DB2 = Path(
    ".artifacts/rmg_recovery/ghidra_4a8db2_pre_phase_builder_dump/"
    "target_004a8db2_FUN_004a8db2.txt"
)
DEFAULT_STATIC_4A901A = Path(
    ".artifacts/rmg_recovery/ghidra_object_projection_helper_dump/"
    "caller_004a901a_FUN_004a901a.txt"
)
DEFAULT_OUT = Path(".artifacts/rmg_recovery/4a8db2_4a901a_live_surface_summary_20260608.json")

ANSI_RE = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]")
STOP_RE = re.compile(r"Stopped on breakpoint \d+ at (0x[0-9a-fA-F]+)")
REGISTER_RE = re.compile(
    r"\b(EAX|EBX|ECX|EDX|ESI|EDI|ESP|EBP|EIP):([0-9a-fA-F]{8})"
)
MEMORY_RE = re.compile(r"0x([0-9a-fA-F]+):\s+((?:[0-9a-fA-F]{8}\s*)+)")

BODY_ADDRESSES = [
    "0x004a8ffd",
    "0x004a901a",
    "0x004a906b",
    "0x004a907b",
    "0x004a9085",
    "0x004a92bb",
    "0x004a92d5",
    "0x004a9322",
    "0x004a9325",
    "0x004a9391",
]
SOURCE_ADDRESSES = ["0x004ac769", "0x004a8dca"]
INTERNAL_MATERIALIZATION_SITES = [
    "0x004a907b",
    "0x004a92bb",
    "0x004a92d5",
    "0x004a9322",
    "0x004a9325",
]


def clean_log(text: str) -> str:
    return ANSI_RE.sub("", text.replace("\r", ""))


def hex32(value: int | None) -> str | None:
    return None if value is None else f"0x{value & 0xFFFFFFFF:08x}"


def parse_events(path: Path) -> list[dict[str, Any]]:
    text = clean_log(path.read_text(encoding="utf-8", errors="replace"))
    matches = list(STOP_RE.finditer(text))
    events: list[dict[str, Any]] = []
    for index, match in enumerate(matches):
        body_start = match.end()
        body_end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
        body = text[body_start:body_end]
        memory_lines = []
        for memory_match in MEMORY_RE.finditer(body):
            memory_lines.append(
                {
                    "address": int(memory_match.group(1), 16),
                    "words": [int(word, 16) for word in memory_match.group(2).split()],
                }
            )
        events.append(
            {
                "address": match.group(1).lower().replace("0x", "0x").rjust(10, "0"),
                "registers": {
                    register.lower(): int(value, 16) for register, value in REGISTER_RE.findall(body)
                },
                "memory_lines": memory_lines,
            }
        )
    return events


def event_counts(events: list[dict[str, Any]], addresses: list[str]) -> dict[str, int]:
    counts = Counter(event["address"] for event in events)
    return {address: counts.get(address, 0) for address in addresses}


def memory_words_from_lines(lines: list[dict[str, Any]], preferred_base_prefix: str | None = None) -> tuple[int | None, list[int]]:
    selected: list[dict[str, Any]] = []
    for line in lines:
        address = int(line["address"])
        if preferred_base_prefix == "heap" and not (0x01000000 <= address < 0x10000000):
            continue
        if selected and address != int(selected[-1]["address"]) + len(selected[-1]["words"]) * 4:
            break
        selected.append(line)
    if not selected:
        return None, []
    words: list[int] = []
    for line in selected:
        words.extend(int(word) & 0xFFFFFFFF for word in line["words"])
    return int(selected[0]["address"]), words


def source_record_summary(event_index: int, event: dict[str, Any]) -> dict[str, Any]:
    heap_lines = [
        line for line in event["memory_lines"] if 0x01000000 <= int(line["address"]) < 0x10000000
    ]
    base, words = memory_words_from_lines(heap_lines)
    fields_by_offset = {f"+0x{index * 4:02x}": hex32(word) for index, word in enumerate(words)}
    return {
        "event_index": event_index,
        "source_record_pointer": hex32(base),
        "word_count": len(words),
        "key_fields": {
            "+0x00": words[0] if len(words) > 0 else None,
            "+0x04": words[1] if len(words) > 1 else None,
            "+0x1c": words[7] if len(words) > 7 else None,
            "+0x20": words[8] if len(words) > 8 else None,
            "+0x24": words[9] if len(words) > 9 else None,
            "+0x28": words[10] if len(words) > 10 else None,
            "+0x2c": words[11] if len(words) > 11 else None,
            "+0x30": words[12] if len(words) > 12 else None,
            "+0x34": words[13] if len(words) > 13 else None,
            "+0x38": words[14] if len(words) > 14 else None,
            "+0x3c": words[15] if len(words) > 15 else None,
            "+0x40": words[16] if len(words) > 16 else None,
        },
        "fields_by_offset": fields_by_offset,
    }


def stack_summary(event_index: int, event: dict[str, Any]) -> dict[str, Any]:
    stack_lines = [
        line for line in event["memory_lines"] if int(line["address"]) < 0x01000000
    ]
    base, words = memory_words_from_lines(stack_lines)
    return {
        "event_index": event_index,
        "address": event["address"],
        "stack_pointer": hex32(base),
        "registers": {key: hex32(value) for key, value in event["registers"].items()},
        "stack_words": [hex32(word) for word in words],
    }


def group_body_sequences(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    sequences: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    for index, event in enumerate(events):
        address = event["address"]
        if address == "0x004a8ffd":
            if current is not None:
                sequences.append(current)
            current = {
                "sequence_index": len(sequences),
                "call_site": "0x004a8ffd",
                "call_site_stack": stack_summary(index, event),
                "visited": [],
            }
        elif current is None:
            continue
        elif address in BODY_ADDRESSES:
            current["visited"].append(address)
            current.setdefault("events", []).append(stack_summary(index, event))
            if address == "0x004a901a":
                current["entry_stack"] = stack_summary(index, event)
            elif address == "0x004a906b":
                current["post_initial_gate"] = stack_summary(index, event)
            elif address == "0x004a9085":
                current["weighted_path_entry"] = stack_summary(index, event)
            elif address == "0x004a9391":
                current["return_surface"] = stack_summary(index, event)
    if current is not None:
        sequences.append(current)
    for sequence in sequences:
        visited = sequence.get("visited", [])
        sequence["reaches_direct_4a93a2_delegate"] = "0x004a907b" in visited
        sequence["reaches_weighted_body"] = "0x004a9085" in visited
        sequence["reaches_record_constructor"] = "0x004a92bb" in visited
        sequence["reaches_record_ready"] = "0x004a92d5" in visited
        sequence["reaches_projection_dispatch"] = "0x004a9322" in visited or "0x004a9325" in visited
        sequence["return_eax"] = sequence.get("return_surface", {}).get("registers", {}).get("eax")
    return sequences


def static_contract(path: Path, markers: list[str]) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""
    return {
        "source_file": str(path),
        "available": path.exists(),
        "static_only_not_runtime_proof": True,
        "contains_expected_markers": all(marker in text for marker in markers) if path.exists() else False,
    }


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    source_events = parse_events(args.source_log)
    body_events = parse_events(args.body_log)
    source_records = [
        source_record_summary(index, event)
        for index, event in enumerate(source_events)
        if event["address"] == "0x004a8dca"
    ]
    body_sequences = group_body_sequences(body_events)
    body_counts = event_counts(body_events, BODY_ADDRESSES)
    source_counts = event_counts(source_events, SOURCE_ADDRESSES + INTERNAL_MATERIALIZATION_SITES)
    invariants = {
        "source_trace_reaches_4a8db2_body": source_counts.get("0x004a8dca", 0) >= 1,
        "body_trace_reaches_4a901a": body_counts.get("0x004a901a", 0) >= 1,
        "body_trace_only_observed_4a8ffd_callsite": body_counts.get("0x004a8ffd", 0)
        == body_counts.get("0x004a901a", 0),
        "all_observed_calls_enter_weighted_body": all(
            sequence.get("reaches_weighted_body") for sequence in body_sequences
        ),
        "no_observed_call_delegates_to_4a93a2": body_counts.get("0x004a907b", 0) == 0,
        "no_observed_call_reaches_record_materialization": all(
            body_counts.get(address, 0) == 0
            for address in ["0x004a92bb", "0x004a92d5", "0x004a9322", "0x004a9325"]
        ),
        "all_observed_calls_return_false": all(
            sequence.get("return_eax") == "0x00000000" for sequence in body_sequences
        ),
    }
    status = (
        "medium_4a8db2_reaches_4a901a_weighted_path_no_materialization"
        if all(invariants.values())
        else "medium_4a8db2_4a901a_live_surface_incomplete"
    )
    return {
        "schema_id": "rmg_h3maped_4a8db2_4a901a_live_surface_summary.v1",
        "status": status,
        "source_trace_log": str(args.source_log),
        "body_trace_log": str(args.body_log),
        "source_trace_counts": source_counts,
        "body_trace_counts": body_counts,
        "source_records": source_records,
        "body_sequences": body_sequences,
        "invariants": invariants,
        "static_contract": {
            "0x4a8db2": static_contract(
                args.static_4a8db2,
                ["004a8df7", "004a8e26", "004a8e55", "004a8e83", "004a8f96", "004a8ffd"],
            ),
            "0x4a901a": static_contract(
                args.static_4a901a,
                ["004a9085", "004a92bb", "004a92d5", "004a9322", "004a9391"],
            ),
        },
        "recovery_meaning": {
            "recovered": "A live Medium one-level land run reaches 0x4a8db2 and then reaches 0x4a901a from the 0x4a8ffd weighted-category call site.",
            "not_recovered": "The sampled calls do not recover a successful 0x4a901a materialization because none reaches 0x49ba89/0x4a92bb, the 0x540a9c ready site, or the 0x4a54a7 projection dispatch.",
            "next_required_step": "Recover why the weighted local-vector body returns false in these calls, then capture a successful 0x4a901a call with candidate-vector contents, selected descriptor, constructed 0x540a9c record, 0x4a54a7 projection, generated-cell before/after, and generator vector deltas.",
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-log", type=Path, default=DEFAULT_SOURCE_LOG)
    parser.add_argument("--body-log", type=Path, default=DEFAULT_BODY_LOG)
    parser.add_argument("--static-4a8db2", type=Path, default=DEFAULT_STATIC_4A8DB2)
    parser.add_argument("--static-4a901a", type=Path, default=DEFAULT_STATIC_4A901A)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_4A8DB2_4A901A_LIVE_SURFACE_SUMMARY status={summary['status']} out={args.out}")
    return 0 if summary["status"] == "medium_4a8db2_reaches_4a901a_weighted_path_no_materialization" else 1


if __name__ == "__main__":
    raise SystemExit(main())
