#!/usr/bin/env python3
"""Explain the pre-0x4a8260 reward-guard constructor RNG gap.

This is a focused diagnostic, not a parity gate. It checks whether the current
native flattened monster candidate table can explain the known H3MapEd/native
RNG boundary gap before 0x4a8260.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any


DEFAULT_NATIVE_SOURCE = Path("src/gdextension/src/h3maped_small_rmg.cpp")
DEFAULT_CRTRAITS = Path(
    "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-lod-extract/"
    "output/h3bitmap/raw/crtraits.txt"
)


@dataclass(frozen=True)
class MonsterCandidate:
    vector_index: int
    monster_table_index: int
    crtraits_source_row_index: int
    terrain_id: int
    tier_index: int
    ai_value: int
    low_damage: int
    high_damage: int
    name: str


def signed_int(value: Any) -> int:
    parsed = int(value)
    if parsed < 0:
        return parsed
    if parsed >= 0x80000000:
        return parsed - 0x100000000
    return parsed


def rng_next(state: int) -> tuple[int, int]:
    next_state = ((state & 0xFFFFFFFF) * 0x343FD + 0x269EC3) & 0xFFFFFFFF
    return next_state, (next_state >> 16) & 0x7FFF


def c_div(numerator: int, denominator: int) -> int:
    return int(numerator / denominator)


def parse_monster_candidates(native_source: Path, crtraits_path: Path) -> tuple[list[MonsterCandidate], list[dict[str, Any]]]:
    source = native_source.read_text(encoding="utf-8")
    marker = "static constexpr H3MapedMonsterCandidate MONSTER_CANDIDATES_0x49f9ed[] = {"
    start = source.index(marker)
    end = source.index("};", start)
    block = source[start:end]
    raw_rows = [
        tuple(map(int, match.groups()))
        for match in re.finditer(
            r"\{\s*(-?\d+),\s*(-?\d+),\s*(-?\d+),\s*(-?\d+),\s*(-?\d+),"
            r"\s*(-?\d+),\s*(-?\d+),\s*(-?\d+),\s*(-?\d+)\s*\}",
            block,
        )
    ]
    with crtraits_path.open(newline="", errors="replace") as handle:
        crtraits_rows = list(csv.reader(handle, delimiter="\t"))

    candidates: list[MonsterCandidate] = []
    ai_mismatches: list[dict[str, Any]] = []
    for raw in raw_rows:
        (
            vector_index,
            monster_table_index,
            crtraits_source_row_index,
            terrain_id,
            tier_index,
            ai_value,
            _raw_quantity,
            _quantity_bucket,
            _value,
        ) = raw
        crtraits = crtraits_rows[crtraits_source_row_index]
        crtraits_ai = int(crtraits[10])
        if crtraits_ai != ai_value:
            ai_mismatches.append(
                {
                    "vector_index": vector_index,
                    "monster_table_index": monster_table_index,
                    "crtraits_source_row_index": crtraits_source_row_index,
                    "candidate_ai_value": ai_value,
                    "crtraits_ai_value": crtraits_ai,
                    "name": crtraits[0],
                }
            )
        candidates.append(
            MonsterCandidate(
                vector_index=vector_index,
                monster_table_index=monster_table_index,
                crtraits_source_row_index=crtraits_source_row_index,
                terrain_id=terrain_id,
                tier_index=tier_index,
                ai_value=ai_value,
                low_damage=int(crtraits[17]),
                high_damage=int(crtraits[18]),
                name=crtraits[0],
            )
        )
    return candidates, ai_mismatches


def mask_allows(mask: str, terrain_id: int, *, reverse: bool, neutral_allowed: bool) -> bool:
    if terrain_id < 0:
        return neutral_allowed
    index = len(mask) - 1 - terrain_id if reverse else terrain_id
    return 0 <= index < len(mask) and mask[index] == "1"


def eligible_candidates(
    candidates: list[MonsterCandidate],
    guard_value: int,
    terrain_id: int,
    policy: str,
    record: dict[str, Any],
) -> list[MonsterCandidate]:
    eligible: list[MonsterCandidate] = []
    for candidate in candidates:
        if policy == "flattened_all_candidates":
            allowed = True
        elif policy == "runtime_terrain_or_neutral":
            allowed = candidate.terrain_id < 0 or candidate.terrain_id == terrain_id
        elif policy == "runtime_terrain_only":
            allowed = candidate.terrain_id == terrain_id
        elif policy == "selected_template_primary_mask":
            allowed = mask_allows(str(record.get("selected_template_terrain_mask_primary", "")), candidate.terrain_id, reverse=False, neutral_allowed=True)
        elif policy == "selected_template_secondary_mask":
            allowed = mask_allows(str(record.get("selected_template_terrain_mask_secondary", "")), candidate.terrain_id, reverse=False, neutral_allowed=True)
        elif policy == "selected_template_secondary_mask_reversed":
            allowed = mask_allows(str(record.get("selected_template_terrain_mask_secondary", "")), candidate.terrain_id, reverse=True, neutral_allowed=True)
        else:
            raise ValueError(f"unknown policy: {policy}")
        if not allowed:
            continue

        average_damage = (candidate.low_damage + candidate.high_damage) // 2
        if candidate.ai_value * average_damage > guard_value:
            continue
        if guard_value > candidate.ai_value * 100:
            continue
        eligible.append(candidate)
    return eligible


def constructor_rng_for_record(
    candidates: list[MonsterCandidate],
    record: dict[str, Any],
    policy: str,
) -> dict[str, Any]:
    probe = record["source_reward_guard_attach_probe_0x49cf34"]
    stamp = probe["source_selected_guard_stamp_shape_0x49d69d"]
    state_before = signed_int(stamp["diagnostic_rng_state_before_uint32"]) & 0xFFFFFFFF
    state_after, rng_value = rng_next(state_before)
    guard_value = int(record["reward_guard_scaled_value"])
    terrain_id = int(record["runtime_h3maped_terrain_id"])
    eligible = eligible_candidates(candidates, guard_value, terrain_id, policy, record)
    if not eligible:
        return {
            "constructor_success": False,
            "eligible_candidate_count": 0,
            "constructor_rng_calls": 0,
            "attach_rng_calls": 0,
            "total_rng_calls": 0,
            "first_rng_value": rng_value,
            "first_rng_state_before_uint32": state_before,
            "first_rng_state_after_uint32": state_after,
        }

    selected = eligible[rng_value % len(eligible)]
    quantity_base = c_div(guard_value + c_div(selected.ai_value, 2), selected.ai_value)
    jitter_bound = c_div(quantity_base, 4) + 1
    constructor_rng_calls = 1
    if jitter_bound > 1:
        constructor_rng_calls += 2

    return {
        "constructor_success": True,
        "eligible_candidate_count": len(eligible),
        "selected_monster_name": selected.name,
        "selected_monster_table_index": selected.monster_table_index,
        "selected_crtraits_source_row_index": selected.crtraits_source_row_index,
        "selected_ai_value": selected.ai_value,
        "selected_low_damage": selected.low_damage,
        "selected_high_damage": selected.high_damage,
        "quantity_base": quantity_base,
        "quantity_jitter_bound": jitter_bound,
        "quantity_jitter_rng_calls": 2 if jitter_bound > 1 else 0,
        "constructor_rng_calls": constructor_rng_calls,
        "attach_rng_calls": 1,
        "total_rng_calls": constructor_rng_calls + 1,
        "first_rng_value": rng_value,
        "first_rng_state_before_uint32": state_before,
        "first_rng_state_after_uint32": state_after,
    }


def summarize_policy(candidates: list[MonsterCandidate], guarded_records: list[dict[str, Any]], policy: str) -> dict[str, Any]:
    rows = [constructor_rng_for_record(candidates, record, policy) for record in guarded_records]
    success_rows = [row for row in rows if row["constructor_success"]]
    return {
        "policy": policy,
        "guarded_reward_count": len(guarded_records),
        "constructor_success_count": len(success_rows),
        "constructor_failure_count": len(guarded_records) - len(success_rows),
        "constructor_rng_calls": sum(int(row["constructor_rng_calls"]) for row in rows),
        "attach_rng_calls": sum(int(row["attach_rng_calls"]) for row in rows),
        "total_rng_calls": sum(int(row["total_rng_calls"]) for row in rows),
        "jittered_constructor_count": sum(1 for row in rows if int(row.get("quantity_jitter_rng_calls", 0)) == 2),
        "sample_records": rows[:8],
    }


def load_guarded_records(phase_snapshot: Path) -> list[dict[str, Any]]:
    snapshot = json.loads(phase_snapshot.read_text(encoding="utf-8"))
    scheduler = snapshot["h3maped_small_port"]["mines_rewards_and_object_vector"]["reward_scheduler_boundary"]
    return [
        record
        for record in scheduler["object_lookup_records"]
        if record.get("reward_requires_composite_guard") is True
    ]


def build_summary(args: argparse.Namespace) -> dict[str, Any]:
    candidates, ai_mismatches = parse_monster_candidates(args.native_source, args.crtraits)
    guarded_records = load_guarded_records(args.phase_snapshot)
    policies = [
        "flattened_all_candidates",
        "runtime_terrain_or_neutral",
        "runtime_terrain_only",
        "selected_template_primary_mask",
        "selected_template_secondary_mask",
        "selected_template_secondary_mask_reversed",
    ]
    policy_summaries = [summarize_policy(candidates, guarded_records, policy) for policy in policies]
    exact_policy_matches = [
        summary["policy"]
        for summary in policy_summaries
        if summary["total_rng_calls"] == args.expected_gap
    ]
    return {
        "schema_id": "rmg_reward_guard_constructor_gap_v1",
        "phase_snapshot": str(args.phase_snapshot),
        "native_source": str(args.native_source),
        "crtraits": str(args.crtraits),
        "expected_pre_0x4a8260_gap": args.expected_gap,
        "candidate_count": len(candidates),
        "candidate_ai_mismatch_count": len(ai_mismatches),
        "candidate_ai_mismatches": ai_mismatches,
        "guarded_reward_count": len(guarded_records),
        "policy_summaries": policy_summaries,
        "exact_policy_matches_expected_gap": exact_policy_matches,
        "conclusion": (
            "Current native flattened monster-candidate policies do not explain the "
            "known 76-call pre-0x4a8260 gap. The remaining source-backed blocker is "
            "the exact 0x4a5c07 guard-constructor descriptor input: generator "
            "+0x398/+0x39c vector contents plus descriptor +0x94/+0x95/+0x20 state "
            "at the 0x4aa354 callsite. Active RNG adoption must stay disabled until "
            "that filter is ported from recovered H3MapEd state."
        ),
        "native_behavior_changed": False,
        "is_gate": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase-snapshot", type=Path, required=True)
    parser.add_argument("--native-source", type=Path, default=DEFAULT_NATIVE_SOURCE)
    parser.add_argument("--crtraits", type=Path, default=DEFAULT_CRTRAITS)
    parser.add_argument("--expected-gap", type=int, default=76)
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()

    summary = build_summary(args)
    output = json.dumps(summary, indent=2, sort_keys=True)
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(output + "\n", encoding="utf-8")
    else:
        print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
