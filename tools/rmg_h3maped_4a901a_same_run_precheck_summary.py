#!/usr/bin/env python3
"""Summarize the same-run 0x4a901a success/precheck trace.

This is recovery evidence only. It parses a deliberately partial WineDbg log
that reaches pre-scheduler 0x4a54a7 projection commits, the first 0x4a8db2
scheduler boundary, one successful 0x4a901a return, and the next weighted
0x4a901a candidate scan through the owner/selector and value-floor checks.
It does not change native RMG behavior.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

from rmg_h3maped_recovery_trace import parse_winedbg_log


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_LOG = (
    ROOT
    / "4a54a7_to_4a901a_same_run_value_trace_20260609"
    / "winedbg_interactive_trace.log"
)
DEFAULT_OUT = ROOT / "4a901a_same_run_precheck_summary_20260609.json"

ADDRESSES = [
    "0x004a54a7",
    "0x004a5756",
    "0x004a8db2",
    "0x004a8f96",
    "0x004a8ffd",
    "0x004a901a",
    "0x004a9085",
    "0x004a913f",
    "0x004a9150",
    "0x004a9167",
    "0x004a9248",
    "0x004a9254",
    "0x004a9273",
    "0x004a9289",
    "0x004a9391",
]


def hex32(value: int | None) -> str | None:
    return None if value is None else f"0x{value & 0xFFFFFFFF:08x}"


def line_words_at(event: dict[str, Any], address: int) -> list[int]:
    for line in event.get("memory_lines", []):
        if int(line.get("address", -1)) == address:
            return [int(word) & 0xFFFFFFFF for word in line.get("words", [])]
    return []


def stack_words(event: dict[str, Any]) -> list[int]:
    esp = event.get("registers", {}).get("esp")
    if esp is None:
        return []
    lines = {
        int(line["address"]): [int(word) & 0xFFFFFFFF for word in line.get("words", [])]
        for line in event.get("memory_lines", [])
    }
    words: list[int] = []
    address = int(esp)
    while address in lines:
        chunk = lines[address]
        words.extend(chunk)
        address += len(chunk) * 4
    return words


def local_words(event: dict[str, Any], start_offset: int = -0x78) -> list[int]:
    ebp = event.get("registers", {}).get("ebp")
    if ebp is None:
        return []
    lines = {
        int(line["address"]): [int(word) & 0xFFFFFFFF for word in line.get("words", [])]
        for line in event.get("memory_lines", [])
    }
    words: list[int] = []
    address = int(ebp) + start_offset
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


def signed32(value: int | None) -> int | None:
    if value is None:
        return None
    value &= 0xFFFFFFFF
    return value - 0x100000000 if value & 0x80000000 else value


def call_args_4a901a(event: dict[str, Any]) -> dict[str, Any]:
    words = stack_words(event)
    labels = [
        "return_address",
        "source_wrapper",
        "arg_0c_category_or_x",
        "arg_10_selector_or_y",
        "arg_14_enabled_or_level",
        "arg_18_required_value",
        "arg_1c_relation_index",
        "generator",
        "trailing_callsite_word",
    ]
    return {label: hex32(words[index]) for index, label in enumerate(labels) if index < len(words)}


def commit_summary(event: dict[str, Any], ordinal: int) -> dict[str, Any]:
    words = stack_words(event)
    return {
        "ordinal": ordinal,
        "return_address": hex32(words[0] if len(words) > 0 else None),
        "object_record": hex32(words[1] if len(words) > 1 else None),
        "x": words[2] if len(words) > 2 else None,
        "y": words[3] if len(words) > 3 else None,
        "level": words[4] if len(words) > 4 else None,
        "generator_ecx": hex32(event.get("registers", {}).get("ecx")),
    }


def projection_done_summary(event: dict[str, Any], ordinal: int) -> dict[str, Any]:
    return {
        "ordinal": ordinal,
        "return_address": event.get("derived", {}).get("return_address"),
        "eax": hex32(event.get("registers", {}).get("eax")),
    }


def sequence_summary(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    sequences: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    for ordinal, event in enumerate(events, start=1):
        address = event.get("address")
        if address == "0x004a901a":
            if current is not None:
                sequences.append(current)
            current = {
                "sequence_index": len(sequences),
                "entry_ordinal": ordinal,
                "entry_args": call_args_4a901a(event),
                "visited": [],
            }
            continue
        if current is None:
            continue
        current["visited"].append(address)
        if address == "0x004a9085":
            current["weighted_branch_ordinal"] = ordinal
        elif address == "0x004a9391":
            current["return_ordinal"] = ordinal
            current["return_eax"] = hex32(event.get("registers", {}).get("eax"))
            sequences.append(current)
            current = None
    if current is not None:
        current["partial_sequence"] = True
        sequences.append(current)
    for sequence in sequences:
        visited = set(sequence.get("visited", []))
        sequence["reaches_weighted_body"] = "0x004a9085" in visited
        sequence["reaches_eligibility_helper"] = "0x004a9167" in visited
        sequence["reaches_append_sites"] = "0x004a9248" in visited or "0x004a9254" in visited
        sequence["reaches_empty_vector_gate"] = "0x004a9273" in visited
        sequence["returns_true"] = sequence.get("return_eax") == "0x00000001"
    return sequences


def candidate_sample(event: dict[str, Any], required_value: int | None, next_address: str | None) -> dict[str, Any]:
    words = local_words(event)
    eax = int(event.get("registers", {}).get("eax", 0)) & 0xFFFFFFFF
    edx = signed32(event.get("registers", {}).get("edx"))
    required_owner = signed32(word_at(words, -0x10))
    owner_matches = edx == required_owner
    return {
        "address": event.get("address"),
        "next_breakpoint_address": next_address,
        "candidate_cell_word_eax": hex32(eax),
        "candidate_score_low16": eax & 0xFFFF,
        "candidate_owner_from_cell_high_byte_edx": edx,
        "required_owner_ebp_minus_0x10": required_owner,
        "owner_selector_matches": owner_matches,
        "reaches_value_floor_next": next_address == "0x004a9150",
        "required_value_arg_0x18": required_value,
        "would_fail_value_floor": required_value is not None and (eax & 0xFFFF) < required_value,
        "scan_min_x_ebp_minus_0x68": word_at(words, -0x68),
        "scan_min_y_ebp_minus_0x64": word_at(words, -0x64),
        "scan_max_x_ebp_minus_0x60": word_at(words, -0x60),
        "scan_max_y_ebp_minus_0x5c": word_at(words, -0x5c),
        "candidate_x_ebp_minus_0x3c": word_at(words, -0x3C),
        "candidate_y_ebp_minus_0x38": word_at(words, -0x38),
        "projected_x_ebp_minus_0x30": word_at(words, -0x30),
        "projected_y_ebp_minus_0x2c": word_at(words, -0x2C),
        "descriptor_x_offset_ebp_minus_0x24": word_at(words, -0x24),
        "descriptor_y_offset_ebp_minus_0x20": word_at(words, -0x20),
    }


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    ledger = parse_winedbg_log(args.log)
    events = ledger.get("events", [])
    counts = Counter(event.get("address") for event in events)
    first_scheduler_ordinal = next(
        (ordinal for ordinal, event in enumerate(events, start=1) if event.get("address") == "0x004a8db2"),
        None,
    )
    commits = [
        commit_summary(event, ordinal)
        for ordinal, event in enumerate(events, start=1)
        if event.get("address") == "0x004a54a7"
    ]
    projection_done = [
        projection_done_summary(event, ordinal)
        for ordinal, event in enumerate(events, start=1)
        if event.get("address") == "0x004a5756"
    ]
    commits_before_scheduler = [
        commit for commit in commits if first_scheduler_ordinal is not None and commit["ordinal"] < first_scheduler_ordinal
    ]
    projection_done_before_scheduler = [
        done for done in projection_done if first_scheduler_ordinal is not None and done["ordinal"] < first_scheduler_ordinal
    ]
    sequences = sequence_summary(events)
    active_required_value = None
    for sequence in sequences:
        if sequence.get("reaches_weighted_body"):
            value = sequence.get("entry_args", {}).get("arg_18_required_value")
            active_required_value = int(value, 16) if value else None
            break
    samples: list[dict[str, Any]] = []
    for index, event in enumerate(events):
        if event.get("address") not in {"0x004a913f", "0x004a9150"}:
            continue
        next_address = events[index + 1].get("address") if index + 1 < len(events) else None
        samples.append(candidate_sample(event, active_required_value, next_address))
    owner_samples = [sample for sample in samples if sample["address"] == "0x004a913f"]
    value_samples = [sample for sample in samples if sample["address"] == "0x004a9150"]
    value_lows = [sample["candidate_score_low16"] for sample in value_samples]
    owner_lows = [sample["candidate_score_low16"] for sample in owner_samples]
    invariants = {
        "native_behavior_changed": False,
        "trace_is_partial": True,
        "same_run_reaches_pre_scheduler_projection_commits": bool(commits_before_scheduler),
        "pre_scheduler_projection_done_pairs_match_commits": len(commits_before_scheduler)
        == len(projection_done_before_scheduler),
        "first_4a901a_sequence_returns_true": bool(sequences) and sequences[0].get("returns_true") is True,
        "first_4a901a_success_does_not_enter_weighted_body": bool(sequences)
        and sequences[0].get("reaches_weighted_body") is False,
        "second_4a901a_sequence_enters_weighted_body": len(sequences) > 1
        and sequences[1].get("reaches_weighted_body") is True,
        "weighted_samples_reach_owner_precheck": bool(owner_samples),
        "weighted_samples_reach_value_floor": bool(value_samples),
        "owner_precheck_pass_to_value_floor_count_matches_value_floor_count": sum(
            1 for sample in owner_samples if sample["reaches_value_floor_next"]
        )
        == len(value_samples),
        "no_weighted_eligibility_or_append_seen_in_partial_trace": counts.get("0x004a9167", 0) == 0
        and counts.get("0x004a9248", 0) == 0
        and counts.get("0x004a9254", 0) == 0,
        "all_sampled_value_floor_checks_fail_required_value": bool(value_samples)
        and all(sample["would_fail_value_floor"] for sample in value_samples),
    }
    proof_invariants = {key: value for key, value in invariants.items() if key != "native_behavior_changed"}
    status = (
        "same_run_4a901a_direct_success_then_weighted_value_floor_rejection"
        if all(proof_invariants.values()) and invariants["native_behavior_changed"] is False
        else "same_run_4a901a_precheck_trace_incomplete"
    )
    return {
        "schema_id": "h3maped_4a901a_same_run_precheck_summary.v1",
        "status": status,
        "native_behavior_changed": False,
        "trace_log": str(args.log),
        "event_count": len(events),
        "address_counts": {address: counts.get(address, 0) for address in ADDRESSES},
        "first_4a8db2_ordinal": first_scheduler_ordinal,
        "pre_scheduler_projection_commits": {
            "count": len(commits_before_scheduler),
            "projection_done_count": len(projection_done_before_scheduler),
            "first": commits_before_scheduler[:4],
            "last": commits_before_scheduler[-3:],
        },
        "all_4a54a7_commits_in_partial_trace": {
            "count": len(commits),
            "projection_done_count": len(projection_done),
        },
        "4a901a_sequences": sequences,
        "weighted_candidate_samples": {
            "required_value_arg_0x18": active_required_value,
            "owner_precheck_count": len(owner_samples),
            "owner_precheck_match_count": sum(1 for sample in owner_samples if sample["owner_selector_matches"]),
            "owner_precheck_mismatch_count": sum(
                1 for sample in owner_samples if not sample["owner_selector_matches"]
            ),
            "value_floor_count": len(value_samples),
            "owner_precheck_low16_min": min(owner_lows) if owner_lows else None,
            "owner_precheck_low16_max": max(owner_lows) if owner_lows else None,
            "value_floor_low16_min": min(value_lows) if value_lows else None,
            "value_floor_low16_max": max(value_lows) if value_lows else None,
            "value_floor_low16_counts": dict(sorted(Counter(value_lows).items())),
            "first_owner_precheck_samples": owner_samples[:12],
            "first_value_floor_samples": value_samples[:12],
        },
        "invariants": invariants,
        "recovery_meaning": {
            "recovered": (
                "In one Large no-water generation run, H3MapEd completes sampled 0x4a54a7 "
                "projection commits before the first 0x4a8db2 scheduler entry, then reaches "
                "a 0x4a901a call that returns true without entering the weighted body, followed "
                "by a second 0x4a901a call that enters the weighted body."
            ),
            "weighted_rejection_surface": (
                "The weighted scan reaches 0x4a913f owner/selector checks and 0x4a9150 value-floor "
                "checks. Every sampled value-floor candidate remains below the 0x53 required value, "
                "so the trace still does not reach 0x49aa93 eligibility or append sites."
            ),
            "direct_success_note": (
                "The first successful 0x4a901a path was not instrumented with 0x4a907b/0x4a93a2 "
                "breakpoints in this partial trace. Static recovery says the non-weighted path "
                "delegates through 0x4a93a2, but this summary does not claim a recovered "
                "0x540a9c weighted materialization."
            ),
            "remaining_blocker": (
                "Recover a weighted 0x4a901a scan whose owner-matching cells pass the value floor, "
                "then capture 0x49aa93 eligibility, candidate append through 0x4ae52a/0x4ae1fd, "
                "selected descriptor, constructed 0x540a9c record, 0x4a54a7 projection dispatch, "
                "generated-cell before/after state, and generator vector deltas."
            ),
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log", type=Path, default=DEFAULT_LOG)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_4A901A_SAME_RUN_PRECHECK_SUMMARY status={summary['status']} out={args.out}")
    return 0 if summary["status"] == "same_run_4a901a_direct_success_then_weighted_value_floor_rejection" else 1


if __name__ == "__main__":
    raise SystemExit(main())
