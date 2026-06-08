#!/usr/bin/env python3
"""Summarize the live 0x4a901a weighted-branch rejection surface.

This is recovery evidence only. It explains why the sampled live Medium
0x4a901a calls return false before materializing a 0x540a9c object record.
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Any

from rmg_h3maped_4a8db2_4a901a_live_surface_summary import event_counts, parse_events


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_EARLY_LEDGER = ROOT / "4a901a_weighted_candidate_loop_trace_20260608" / "winedbg_interactive_trace_ledger.json"
DEFAULT_LATE_LOG = ROOT / "4a901a_weighted_candidate_late_trace_20260608" / "winedbg_interactive_trace.log"
DEFAULT_STATIC_4A901A = ROOT / "ghidra_object_projection_helper_dump" / "caller_004a901a_FUN_004a901a.txt"
DEFAULT_OUT = ROOT / "4a901a_weighted_rejection_summary_20260608.json"

LATE_ADDRESSES = [
    "0x004a8ffd",
    "0x004a901a",
    "0x004a9085",
    "0x004a9167",
    "0x004a916e",
    "0x004a9232",
    "0x004a9248",
    "0x004a9254",
    "0x004a9273",
    "0x004a9289",
    "0x004a9290",
    "0x004a92bb",
    "0x004a92d5",
    "0x004a9322",
    "0x004a9325",
    "0x004a9391",
]

EARLY_ADDRESSES = [
    "0x004a8ffd",
    "0x004a901a",
    "0x004a9085",
    "0x004a90e8",
    "0x004a90f7",
    "0x004a913f",
    "0x004a9150",
    "0x004a9167",
    "0x004a916e",
]


def hex32(value: int | None) -> str | None:
    return None if value is None else f"0x{value & 0xFFFFFFFF:08x}"


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def local_words(event: dict[str, Any], start_offset: int = -0x78) -> list[int]:
    ebp = event.get("registers", {}).get("ebp")
    if ebp is None:
        return []
    wanted = ebp + start_offset
    lines = {int(line["address"]): [int(word) & 0xFFFFFFFF for word in line["words"]] for line in event.get("memory_lines", [])}
    words: list[int] = []
    address = wanted
    while address in lines:
        chunk = lines[address]
        words.extend(chunk)
        address += len(chunk) * 4
    return words


def word_at(words: list[int], offset: int, start_offset: int = -0x78) -> int | None:
    index = (offset - start_offset) // 4
    if index < 0 or index >= len(words):
        return None
    return words[index]


def stack_words(event: dict[str, Any]) -> list[int]:
    esp = event.get("registers", {}).get("esp")
    if esp is None:
        return []
    lines = {int(line["address"]): [int(word) & 0xFFFFFFFF for word in line["words"]] for line in event.get("memory_lines", [])}
    words: list[int] = []
    address = esp
    while address in lines:
        chunk = lines[address]
        words.extend(chunk)
        address += len(chunk) * 4
    return words


def callsite_args(event: dict[str, Any]) -> dict[str, Any]:
    words = stack_words(event)
    labels = [
        "wrapper",
        "arg_0c_category",
        "arg_10_selector",
        "arg_14_enabled",
        "arg_18_required_value",
        "arg_1c_relation_index",
        "generator",
        "trailing_callsite_word",
    ]
    return {label: hex32(words[index]) for index, label in enumerate(labels) if index < len(words)}


def late_sequences(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    sequences: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    for event in events:
        address = event["address"]
        if address == "0x004a8ffd":
            if current is not None:
                sequences.append(current)
            current = {
                "sequence_index": len(sequences),
                "callsite_args": callsite_args(event),
                "visited": [],
            }
            continue
        if current is None:
            continue
        current["visited"].append(address)
        if address == "0x004a9273":
            words = local_words(event)
            current["empty_vector_gate"] = {
                "local_vector_begin_ebp_minus_0x54": hex32(word_at(words, -0x54)),
                "local_vector_end_ebp_minus_0x50": hex32(word_at(words, -0x50)),
                "local_vector_capacity_ebp_minus_0x4c": hex32(word_at(words, -0x4c)),
                "candidate_scan_min_x_ebp_minus_0x68": word_at(words, -0x68),
                "candidate_scan_min_y_ebp_minus_0x64": word_at(words, -0x64),
                "candidate_scan_max_x_ebp_minus_0x60": word_at(words, -0x60),
                "candidate_scan_max_y_ebp_minus_0x5c": word_at(words, -0x5c),
                "last_scan_x_ebp_minus_0x3c": word_at(words, -0x3c),
                "last_scan_y_ebp_minus_0x38": word_at(words, -0x38),
                "source_descriptor_x_offset_ebp_minus_0x24": word_at(words, -0x24),
                "source_descriptor_y_offset_ebp_minus_0x20": word_at(words, -0x20),
            }
        elif address == "0x004a9391":
            current["return_eax"] = hex32(event.get("registers", {}).get("eax"))
    if current is not None:
        sequences.append(current)
    for sequence in sequences:
        visited = set(sequence.get("visited", []))
        gate = sequence.get("empty_vector_gate", {})
        sequence["reaches_eligibility_helper"] = "0x004a9167" in visited
        sequence["reaches_candidate_append"] = "0x004a9248" in visited or "0x004a9254" in visited
        sequence["takes_empty_vector_false_gate"] = "0x004a9273" in visited and "0x004a9289" in visited
        sequence["local_vector_is_empty_at_gate"] = all(
            gate.get(key) == "0x00000000"
            for key in [
                "local_vector_begin_ebp_minus_0x54",
                "local_vector_end_ebp_minus_0x50",
                "local_vector_capacity_ebp_minus_0x4c",
            ]
        )
    return sequences


def early_value_gate_samples(ledger: dict[str, Any]) -> list[dict[str, Any]]:
    first_call_required_value = None
    for event in ledger.get("events", []):
        if event.get("address") == "0x004a8ffd":
            words = stack_words(event)
            if len(words) > 4:
                first_call_required_value = words[4]
            break
    samples: list[dict[str, Any]] = []
    for event in ledger.get("events", []):
        if event.get("address") != "0x004a9150":
            continue
        words = local_words(event)
        eax = int(event.get("registers", {}).get("eax", 0)) & 0xFFFFFFFF
        samples.append(
            {
                "candidate_cell_value_low16_eax": eax & 0xFFFF,
                "required_value_arg_0x18": first_call_required_value,
                "would_fail_value_floor": first_call_required_value is not None
                and (eax & 0xFFFF) < first_call_required_value,
                "candidate_x_ebp_minus_0x3c": word_at(words, -0x3C),
                "candidate_y_ebp_minus_0x38": word_at(words, -0x38),
                "projected_x_ebp_minus_0x30": word_at(words, -0x30),
                "projected_y_ebp_minus_0x2c": word_at(words, -0x2C),
                "descriptor_x_offset_ebp_minus_0x24": word_at(words, -0x24),
                "descriptor_y_offset_ebp_minus_0x20": word_at(words, -0x20),
                "owner_byte_ebp_minus_0x10": word_at(words, -0x10),
            }
        )
    return samples


def static_markers(path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""
    markers = [
        "004a913f: JNZ 0x004a9259",
        "004a9150: JL 0x004a9259",
        "004a9167: CALL 0x0049aa93",
        "004a9232: JZ 0x004a9259",
        "004a9248: CALL 0x004ae52a",
        "004a9254: CALL 0x004ae1fd",
        "004a9273: CMP dword ptr [EBP + -0x54],0x0",
        "004a9289: XOR BL,BL",
    ]
    return {
        "source_file": str(path),
        "available": path.exists(),
        "static_only_not_runtime_proof": True,
        "contains_expected_markers": all(marker in text for marker in markers) if path.exists() else False,
        "markers": markers,
    }


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    early_ledger = read_json(args.early_ledger)
    late_events = parse_events(args.late_log)
    early_counts = Counter(event.get("address") for event in early_ledger.get("events", []))
    late_counts = event_counts(late_events, LATE_ADDRESSES)
    sequences = late_sequences(late_events)
    value_samples = early_value_gate_samples(early_ledger)
    values = [sample["candidate_cell_value_low16_eax"] for sample in value_samples]
    required_values = sorted(
        {sample["required_value_arg_0x18"] for sample in value_samples if sample["required_value_arg_0x18"] is not None}
    )
    invariants = {
        "late_trace_covers_eight_4a901a_calls": late_counts.get("0x004a901a", 0) == 8,
        "late_trace_reaches_empty_vector_gate_for_every_call": late_counts.get("0x004a9273", 0)
        == late_counts.get("0x004a901a", 0),
        "late_trace_takes_false_gate_for_every_call": late_counts.get("0x004a9289", 0)
        == late_counts.get("0x004a901a", 0),
        "late_trace_never_reaches_eligibility_helper": late_counts.get("0x004a9167", 0) == 0,
        "late_trace_never_reaches_append_sites": late_counts.get("0x004a9248", 0) == 0
        and late_counts.get("0x004a9254", 0) == 0,
        "late_trace_never_materializes_record": late_counts.get("0x004a92bb", 0) == 0
        and late_counts.get("0x004a92d5", 0) == 0
        and late_counts.get("0x004a9322", 0) == 0,
        "all_late_sequences_return_false": all(sequence.get("return_eax") == "0x00000000" for sequence in sequences),
        "all_late_sequences_have_empty_local_vector_at_gate": all(
            sequence.get("local_vector_is_empty_at_gate") for sequence in sequences
        ),
        "early_value_gate_sample_reaches_value_floor": early_counts.get("0x004a9150", 0) > 0,
        "early_value_gate_sample_does_not_reach_eligibility_helper_before_cap": early_counts.get("0x004a9167", 0) == 0,
        "all_sampled_value_floor_checks_fail_required_value": bool(value_samples)
        and all(sample["would_fail_value_floor"] for sample in value_samples),
    }
    status = (
        "medium_4a901a_weighted_branch_rejects_empty_candidate_vector"
        if all(invariants.values())
        else "medium_4a901a_weighted_branch_rejection_incomplete"
    )
    return {
        "schema_id": "rmg_h3maped_4a901a_weighted_rejection_summary.v1",
        "status": status,
        "early_trace_ledger": str(args.early_ledger),
        "late_trace_log": str(args.late_log),
        "early_trace_counts": {address: early_counts.get(address, 0) for address in EARLY_ADDRESSES},
        "late_trace_counts": late_counts,
        "late_sequences": sequences,
        "early_value_gate_samples": {
            "sample_count": len(value_samples),
            "required_values_arg_0x18": required_values,
            "candidate_cell_value_low16_min": min(values) if values else None,
            "candidate_cell_value_low16_max": max(values) if values else None,
            "candidate_cell_value_low16_counts": dict(sorted(Counter(values).items())),
            "first_16_samples": value_samples[:16],
        },
        "invariants": invariants,
        "static_contract": {"0x4a901a": static_markers(args.static_4a901a)},
        "recovery_meaning": {
            "recovered": (
                "For the sampled Medium one-level land 0x4a8ffd calls, 0x4a901a enters the weighted "
                "branch but reaches the empty local-vector gate with no candidate entries, then returns false."
            ),
            "candidate_rejection_surface": (
                "The sampled early coordinate checks that reach 0x4a9150 all have cell-value low words below "
                "the required 0xcb value argument, so they take the value-floor skip before 0x49aa93 eligibility."
            ),
            "not_recovered": (
                "This still does not recover a successful 0x540a9c materialization, selected descriptor, "
                "0x4a54a7 projection, generated-cell afterstate, or generator vector delta."
            ),
            "next_required_step": (
                "Drive or identify a 0x4a901a call whose weighted candidate scan reaches 0x49aa93 and appends "
                "entries, then capture the successful materialization and projection path."
            ),
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--early-ledger", type=Path, default=DEFAULT_EARLY_LEDGER)
    parser.add_argument("--late-log", type=Path, default=DEFAULT_LATE_LOG)
    parser.add_argument("--static-4a901a", type=Path, default=DEFAULT_STATIC_4A901A)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_4A901A_WEIGHTED_REJECTION_SUMMARY status={summary['status']} out={args.out}")
    return 0 if summary["status"] == "medium_4a901a_weighted_branch_rejects_empty_candidate_vector" else 1


if __name__ == "__main__":
    raise SystemExit(main())
