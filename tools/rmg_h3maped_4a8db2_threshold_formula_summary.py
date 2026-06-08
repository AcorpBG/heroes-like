#!/usr/bin/env python3
"""Summarize the recovered 0x4a8db2 -> 0x4a901a threshold formula.

This is recovery evidence only. It ties the static 0x4a8db2 weighted-callsite
formula to live Medium/Large source rows and the observed 0x4a901a value-gate
failure surface.
"""

from __future__ import annotations

import argparse
import json
import math
from collections import Counter
from pathlib import Path
from typing import Any

from rmg_h3maped_4a8db2_4a901a_live_surface_summary import parse_events
from rmg_h3maped_4a901a_weighted_rejection_summary import local_words, stack_words, word_at


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_MEDIUM_SUMMARY = ROOT / "4a8db2_4a901a_live_surface_summary_20260608.json"
DEFAULT_LARGE_SOURCE_LOG = ROOT / "4a8db2_large_source_threshold_trace_20260608" / "winedbg_interactive_trace.log"
DEFAULT_LARGE_VALUE_LEDGER = (
    ROOT / "4a901a_large_low_threshold_value_gate_trace_20260608" / "winedbg_interactive_trace_ledger.json"
)
DEFAULT_OUT = ROOT / "4a8db2_threshold_formula_summary_20260608.json"

DENSITY_FIELD_OFFSETS = [0x2C, 0x28, 0x3C, 0x38]
ACCUMULATOR_FIELD_OFFSETS = [0x24, 0x20, 0x34, 0x30]
WEIGHTED_CALLSITES = ["0x004a8ffd", "0x004a8fd6", "0x004a8fb4", "0x004a8f96"]
WEIGHTED_CALLSITE_TO_INDEX = {
    "0x004a8ffd": 0,
    "0x004a8fd6": 1,
    "0x004a8fb4": 2,
    "0x004a8f96": 3,
}


def hex32(value: int | None) -> str | None:
    return None if value is None else f"0x{value & 0xFFFFFFFF:08x}"


def threshold_from_density(total_density: int) -> int | None:
    if total_density <= 0:
        return None
    return int(math.sqrt(0x14400 / total_density))


def word(words: list[int], offset: int) -> int | None:
    index = offset // 4
    if index < 0 or index >= len(words):
        return None
    return words[index] & 0xFFFFFFFF


def source_fields(words: list[int]) -> dict[str, Any]:
    density_values = [word(words, offset) or 0 for offset in DENSITY_FIELD_OFFSETS]
    accumulator_values = [word(words, offset) or 0 for offset in ACCUMULATOR_FIELD_OFFSETS]
    total_density = sum(value for value in density_values if value > 0)
    return {
        "source_id_plus_0x00": word(words, 0x00),
        "owner_or_type_plus_0x04": word(words, 0x04),
        "relation_selector_plus_0x1c": word(words, 0x1C),
        "density_fields": {f"+0x{offset:02x}": word(words, offset) for offset in DENSITY_FIELD_OFFSETS},
        "accumulator_seed_fields": {f"+0x{offset:02x}": word(words, offset) for offset in ACCUMULATOR_FIELD_OFFSETS},
        "density_values_in_scheduler_order": density_values,
        "accumulator_seed_values_in_scheduler_order": accumulator_values,
        "total_positive_density": total_density,
        "computed_arg_0x18_threshold": threshold_from_density(total_density),
    }


def parse_medium_rows(path: Path) -> list[dict[str, Any]]:
    summary = json.loads(path.read_text(encoding="utf-8"))
    rows: list[dict[str, Any]] = []
    for record in summary.get("source_records", []):
        fields = record.get("fields_by_offset", {})
        words: list[int] = []
        for offset in range(0, 0x70, 4):
            value = fields.get(f"+0x{offset:02x}")
            words.append(int(value, 16) if value is not None else 0)
        row = source_fields(words)
        row["source_record_pointer"] = record.get("source_record_pointer")
        row["trace_event_index"] = record.get("event_index")
        rows.append(row)
    return rows


def words_at_event_pointer(event: dict[str, Any], pointer: int, word_count: int) -> list[int]:
    wanted_end = pointer + word_count * 4
    words: list[int] = []
    for line in sorted(event.get("memory_lines", []), key=lambda item: item["address"]):
        address = int(line["address"])
        if address < pointer or address >= wanted_end:
            continue
        words.extend(int(value) & 0xFFFFFFFF for value in line["words"])
    return words[:word_count]


def call_args(event: dict[str, Any]) -> dict[str, Any]:
    words = stack_words(event)
    labels = [
        "wrapper_arg_0x08",
        "arg_0x0c",
        "arg_0x10",
        "arg_0x14",
        "arg_0x18_threshold",
    ]
    return {label: hex32(words[index]) for index, label in enumerate(labels) if index < len(words)}


def parse_large_source_trace(path: Path) -> dict[str, Any]:
    events = parse_events(path)
    source_rows: list[dict[str, Any]] = []
    weighted_calls: list[dict[str, Any]] = []
    current_row: dict[str, Any] | None = None
    for index, event in enumerate(events):
        address = event["address"]
        if address == "0x004a8dca":
            source_pointer = event.get("registers", {}).get("esi")
            words = words_at_event_pointer(event, source_pointer, 28) if source_pointer is not None else []
            current_row = source_fields(words)
            current_row["source_record_pointer"] = hex32(source_pointer)
            current_row["trace_event_index"] = index
            source_rows.append(current_row)
        elif address in WEIGHTED_CALLSITE_TO_INDEX:
            args = call_args(event)
            threshold = int(args["arg_0x18_threshold"], 16) if args.get("arg_0x18_threshold") else None
            call = {
                "trace_event_index": index,
                "callsite": address,
                "scheduler_index": WEIGHTED_CALLSITE_TO_INDEX[address],
                "args": args,
                "observed_arg_0x18_threshold": threshold,
                "active_source": current_row,
                "threshold_matches_source_formula": current_row is not None
                and threshold == current_row.get("computed_arg_0x18_threshold"),
            }
            weighted_calls.append(call)
    return {
        "source_rows": source_rows,
        "weighted_calls": weighted_calls,
        "weighted_call_count": len(weighted_calls),
        "all_weighted_thresholds_match_source_formula": bool(weighted_calls)
        and all(call["threshold_matches_source_formula"] for call in weighted_calls),
    }


def parse_value_gate_ledger(path: Path) -> dict[str, Any]:
    ledger = json.loads(path.read_text(encoding="utf-8"))
    events = ledger.get("events", [])
    counts = Counter(event.get("address") for event in events)
    current_threshold: int | None = None
    current_callsite: str | None = None
    samples: list[dict[str, Any]] = []
    gates: list[dict[str, Any]] = []
    for index, event in enumerate(events):
        address = event.get("address")
        if address in WEIGHTED_CALLSITE_TO_INDEX:
            words = stack_words(event)
            current_callsite = address
            current_threshold = words[4] if len(words) > 4 else None
        elif address == "0x004a9150":
            words = local_words(event)
            eax = int(event.get("registers", {}).get("eax", 0)) & 0xFFFFFFFF
            low16 = eax & 0xFFFF
            samples.append(
                {
                    "trace_event_index": index,
                    "callsite": current_callsite,
                    "required_threshold": current_threshold,
                    "candidate_cell_value_low16": low16,
                    "candidate_owner_byte": word_at(words, -0x10),
                    "candidate_x": word_at(words, -0x3C),
                    "candidate_y": word_at(words, -0x38),
                    "passes_value_floor": current_threshold is not None and low16 >= current_threshold,
                }
            )
        elif address == "0x004a9273":
            words = local_words(event)
            gates.append(
                {
                    "trace_event_index": index,
                    "callsite": current_callsite,
                    "required_threshold": current_threshold,
                    "local_vector_begin": hex32(word_at(words, -0x54)),
                    "local_vector_end": hex32(word_at(words, -0x50)),
                    "local_vector_capacity": hex32(word_at(words, -0x4C)),
                }
            )
    lows = [sample["candidate_cell_value_low16"] for sample in samples]
    return {
        "trace_ledger": str(path),
        "event_count": ledger.get("event_count"),
        "counts": {
            address: counts.get(address, 0)
            for address in [
                "0x004a8f96",
                "0x004a8ffd",
                "0x004a9150",
                "0x004a9167",
                "0x004a9248",
                "0x004a9254",
                "0x004a9273",
                "0x004a9289",
                "0x004a9290",
                "0x004a92bb",
                "0x004a9322",
                "0x004a9391",
            ]
        },
        "sample_count": len(samples),
        "required_threshold_counts": dict(sorted(Counter(sample["required_threshold"] for sample in samples).items())),
        "candidate_cell_value_low16_min": min(lows) if lows else None,
        "candidate_cell_value_low16_max": max(lows) if lows else None,
        "candidate_cell_value_low16_counts": dict(sorted(Counter(lows).items())),
        "passing_value_floor_count": sum(1 for sample in samples if sample["passes_value_floor"]),
        "all_sampled_value_floor_checks_fail": bool(samples)
        and all(not sample["passes_value_floor"] for sample in samples),
        "empty_vector_gate_count": sum(
            1
            for gate in gates
            if gate["local_vector_begin"] == "0x00000000"
            and gate["local_vector_end"] == "0x00000000"
            and gate["local_vector_capacity"] == "0x00000000"
        ),
        "gate_count": len(gates),
        "first_16_samples": samples[:16],
    }


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    medium_rows = parse_medium_rows(args.medium_summary)
    large = parse_large_source_trace(args.large_source_log)
    value_gate = parse_value_gate_ledger(args.large_value_ledger)
    active_medium_rows = [row for row in medium_rows if row["total_positive_density"] > 0]
    medium_thresholds = sorted({row["computed_arg_0x18_threshold"] for row in active_medium_rows})
    large_thresholds = sorted(
        {call["observed_arg_0x18_threshold"] for call in large["weighted_calls"] if call["observed_arg_0x18_threshold"] is not None}
    )
    invariants = {
        "medium_active_rows_compute_threshold_203": medium_thresholds == [203],
        "large_weighted_call_thresholds_match_source_formula": large["all_weighted_thresholds_match_source_formula"],
        "large_observed_thresholds_include_79_and_83": large_thresholds == [79, 83],
        "large_low_threshold_value_gate_never_reaches_eligibility": value_gate["counts"]["0x004a9167"] == 0,
        "large_low_threshold_value_gate_never_appends_or_materializes": value_gate["counts"]["0x004a9248"] == 0
        and value_gate["counts"]["0x004a9254"] == 0
        and value_gate["counts"]["0x004a9290"] == 0
        and value_gate["counts"]["0x004a92bb"] == 0
        and value_gate["counts"]["0x004a9322"] == 0,
        "large_low_threshold_value_samples_all_fail": value_gate["all_sampled_value_floor_checks_fail"],
    }
    status = (
        "4a8db2_threshold_formula_recovered_value_gate_still_fails"
        if all(invariants.values())
        else "4a8db2_threshold_formula_summary_incomplete"
    )
    return {
        "schema_id": "rmg_h3maped_4a8db2_threshold_formula_summary.v1",
        "status": status,
        "native_behavior_changed": False,
        "static_formula": {
            "source": "objdump/Ghidra-backed 0x4a8db2 instruction stream",
            "density_fields_in_scheduler_order": ["+0x2c", "+0x28", "+0x3c", "+0x38"],
            "accumulator_seed_fields_in_scheduler_order": ["+0x24", "+0x20", "+0x34", "+0x30"],
            "weighted_callsites_by_scheduler_index": {
                "0": "0x004a8ffd",
                "1": "0x004a8fd6",
                "2": "0x004a8fb4",
                "3": "0x004a8f96",
            },
            "formula": "arg_0x18_threshold = floor(sqrt(0x14400 / sum_positive(source[+0x2c], source[+0x28], source[+0x3c], source[+0x38])))",
        },
        "medium_source_rows": {
            "trace_summary": str(args.medium_summary),
            "active_thresholds": medium_thresholds,
            "active_rows": active_medium_rows,
        },
        "large_source_trace": {
            "trace_log": str(args.large_source_log),
            "observed_thresholds": large_thresholds,
            "source_rows": large["source_rows"],
            "weighted_calls": large["weighted_calls"],
            "all_weighted_thresholds_match_source_formula": large["all_weighted_thresholds_match_source_formula"],
        },
        "large_low_threshold_value_gate": value_gate,
        "invariants": invariants,
        "recovery_meaning": {
            "recovered": (
                "0x4a8db2 computes the weighted 0x4a901a value-floor threshold from source density "
                "fields +0x2c/+0x28/+0x3c/+0x38 using floor(sqrt(0x14400 / positive_density_sum)). "
                "Live Medium rows with total density 2 compute threshold 203; live Large rows with "
                "totals 12 and 13 compute thresholds 83 and 79."
            ),
            "still_failing": (
                "A Large low-threshold value-gate trace with required threshold 83 sampled 496 owner-matching "
                "candidate cells, but their GeneratedCell+0x20 low words were only 0..40. No sampled cell "
                "reached 0x49aa93 eligibility, append, allocation, constructor, or projection."
            ),
            "next_required_step": (
                "Recover the pre-0x4a8db2 phase that raises or preserves GeneratedCell+0x20 low-word scores "
                "for owner-matching cells, then capture a 0x4a901a scan that reaches 0x49aa93 and appends candidates."
            ),
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--medium-summary", type=Path, default=DEFAULT_MEDIUM_SUMMARY)
    parser.add_argument("--large-source-log", type=Path, default=DEFAULT_LARGE_SOURCE_LOG)
    parser.add_argument("--large-value-ledger", type=Path, default=DEFAULT_LARGE_VALUE_LEDGER)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_4A8DB2_THRESHOLD_FORMULA_SUMMARY status={summary['status']} out={args.out}")
    return 0 if summary["status"] == "4a8db2_threshold_formula_recovered_value_gate_still_fails" else 1


if __name__ == "__main__":
    raise SystemExit(main())
