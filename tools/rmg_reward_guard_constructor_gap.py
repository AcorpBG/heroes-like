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
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Any


DEFAULT_NATIVE_SOURCE = Path("src/gdextension/src/h3maped_small_rmg.cpp")
DEFAULT_CRTRAITS = Path(
    "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-lod-extract/"
    "output/h3bitmap/raw/crtraits.txt"
)
DEFAULT_OBJECT_CATALOG = Path(
    "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/"
    "object-catalog-by-type.csv"
)


@dataclass(frozen=True)
class MonsterCandidate:
    vector_index: int
    monster_table_index: int
    crtraits_source_row_index: int
    terrain_id: int
    tier_index: int
    ai_value: int
    raw_quantity: int
    quantity_bucket: int
    value: int
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
                raw_quantity=_raw_quantity,
                quantity_bucket=_quantity_bucket,
                value=_value,
                low_damage=int(crtraits[17]),
                high_damage=int(crtraits[18]),
                name=crtraits[0],
            )
        )
    return candidates, ai_mismatches


def parse_type54_catalog(object_catalog: Path) -> dict[str, Any]:
    with object_catalog.open(newline="", errors="replace") as handle:
        rows = [row for row in csv.DictReader(handle) if row.get("type_id") == "54"]
    subtypes = sorted({int(row["subtype"]) for row in rows})
    missing_0_144 = [subtype for subtype in range(145) if subtype not in set(subtypes)]
    return {
        "path": str(object_catalog),
        "type54_row_count": len(rows),
        "type54_subtype_count": len(subtypes),
        "type54_subtype_min": subtypes[0] if subtypes else None,
        "type54_subtype_max": subtypes[-1] if subtypes else None,
        "type54_missing_subtypes_0_144": missing_0_144,
        "type54_subtypes": subtypes,
        "type54_terrain_mask_a_counts": dict(Counter(row.get("terrain_mask_a", "") for row in rows)),
        "type54_terrain_mask_b_counts": dict(Counter(row.get("terrain_mask_b", "") for row in rows)),
    }


def mask_allows(mask: str, terrain_id: int, *, reverse: bool, neutral_allowed: bool) -> bool:
    if terrain_id < 0:
        return neutral_allowed
    index = len(mask) - 1 - terrain_id if reverse else terrain_id
    return 0 <= index < len(mask) and mask[index] == "1"


def descriptor_memberships(
    candidates: list[MonsterCandidate],
    catalog_summary: dict[str, Any],
    explicit_subtypes: set[int] | None,
) -> dict[str, set[int] | None]:
    candidate_subtypes = {candidate.monster_table_index for candidate in candidates}
    type54_subtypes = set(int(subtype) for subtype in catalog_summary["type54_subtypes"])
    memberships: dict[str, set[int] | None] = {
        "none_no_descriptor_vector_filter": None,
        "native_candidate_descriptor_rows_0x49f9ed": candidate_subtypes,
        "catalog_type54_rows_intersect_0_117": type54_subtypes & set(range(118)),
        "catalog_type54_all_rows": type54_subtypes,
    }
    if explicit_subtypes is not None:
        memberships["explicit_descriptor_subtypes"] = explicit_subtypes
    return memberships


def parse_subtype_set(spec: str | None) -> set[int] | None:
    if spec is None or spec.strip() == "":
        return None
    values: set[int] = set()
    for part in spec.split(","):
        part = part.strip()
        if not part:
            continue
        if "-" in part:
            start_text, end_text = part.split("-", 1)
            start = int(start_text)
            end = int(end_text)
            values.update(range(start, end + 1))
        else:
            values.add(int(part))
    return values


def eligible_candidates(
    candidates: list[MonsterCandidate],
    guard_value: int,
    terrain_id: int,
    terrain_policy: str,
    descriptor_subtypes: set[int] | None,
    record: dict[str, Any],
) -> list[MonsterCandidate]:
    eligible: list[MonsterCandidate] = []
    for candidate in candidates:
        if descriptor_subtypes is not None and candidate.monster_table_index not in descriptor_subtypes:
            continue

        if terrain_policy == "flattened_all_candidates":
            allowed = True
        elif terrain_policy == "runtime_terrain_or_neutral":
            allowed = candidate.terrain_id < 0 or candidate.terrain_id == terrain_id
        elif terrain_policy == "runtime_terrain_only":
            allowed = candidate.terrain_id == terrain_id
        elif terrain_policy == "selected_template_primary_mask":
            allowed = mask_allows(str(record.get("selected_template_terrain_mask_primary", "")), candidate.terrain_id, reverse=False, neutral_allowed=True)
        elif terrain_policy == "selected_template_primary_mask_neutral0":
            allowed = mask_allows(str(record.get("selected_template_terrain_mask_primary", "")), candidate.terrain_id, reverse=False, neutral_allowed=False)
        elif terrain_policy == "selected_template_secondary_mask":
            allowed = mask_allows(str(record.get("selected_template_terrain_mask_secondary", "")), candidate.terrain_id, reverse=False, neutral_allowed=True)
        elif terrain_policy == "selected_template_secondary_mask_neutral0":
            allowed = mask_allows(str(record.get("selected_template_terrain_mask_secondary", "")), candidate.terrain_id, reverse=False, neutral_allowed=False)
        elif terrain_policy == "selected_template_secondary_mask_reversed":
            allowed = mask_allows(str(record.get("selected_template_terrain_mask_secondary", "")), candidate.terrain_id, reverse=True, neutral_allowed=True)
        elif terrain_policy == "selected_template_secondary_mask_reversed_neutral0":
            allowed = mask_allows(str(record.get("selected_template_terrain_mask_secondary", "")), candidate.terrain_id, reverse=True, neutral_allowed=False)
        else:
            raise ValueError(f"unknown terrain policy: {terrain_policy}")
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
    terrain_policy: str,
    descriptor_subtypes: set[int] | None,
) -> dict[str, Any]:
    probe = record["source_reward_guard_attach_probe_0x49cf34"]
    stamp = probe.get("source_selected_guard_stamp_shape_0x49d69d", {})
    if "diagnostic_rng_state_before_uint32" not in stamp:
        return {
            "constructor_success": False,
            "diagnostic_rng_available": False,
            "diagnostic_rng_unavailable_reason": stamp.get(
                "exactness_blocker",
                "source_selected_guard_stamp_shape_0x49d69d lacks diagnostic_rng_state_before_uint32",
            ),
            "eligible_candidate_count": 0,
            "constructor_rng_calls": 0,
            "attach_rng_calls": 0,
            "total_rng_calls": 0,
        }

    state_before = signed_int(stamp["diagnostic_rng_state_before_uint32"]) & 0xFFFFFFFF
    state_after, rng_value = rng_next(state_before)
    guard_value = int(record["reward_guard_scaled_value"])
    terrain_id = int(record["runtime_h3maped_terrain_id"])
    eligible = eligible_candidates(candidates, guard_value, terrain_id, terrain_policy, descriptor_subtypes, record)
    if not eligible:
        return {
            "constructor_success": False,
            "diagnostic_rng_available": True,
            "eligible_candidate_count": 0,
            "constructor_rng_calls": 0,
            "attach_rng_calls": 0,
            "total_rng_calls": 0,
            "first_rng_value": rng_value,
            "first_rng_state_before_uint32": state_before,
            "first_rng_state_after_uint32": state_after,
        }

    selected = eligible[rng_value % len(eligible)]
    non_jitter_eligible_count = 0
    for candidate in eligible:
        candidate_quantity_base = c_div(guard_value + c_div(candidate.ai_value, 2), candidate.ai_value)
        candidate_jitter_bound = c_div(candidate_quantity_base, 4) + 1
        if candidate_jitter_bound <= 1:
            non_jitter_eligible_count += 1
    quantity_base = c_div(guard_value + c_div(selected.ai_value, 2), selected.ai_value)
    jitter_bound = c_div(quantity_base, 4) + 1
    constructor_rng_calls = 1
    if jitter_bound > 1:
        constructor_rng_calls += 2

    return {
        "constructor_success": True,
        "diagnostic_rng_available": True,
        "eligible_candidate_count": len(eligible),
        "selected_monster_name": selected.name,
        "selected_monster_table_index": selected.monster_table_index,
        "selected_candidate_vector_index": selected.vector_index,
        "selected_crtraits_source_row_index": selected.crtraits_source_row_index,
        "selected_ai_value": selected.ai_value,
        "selected_low_damage": selected.low_damage,
        "selected_high_damage": selected.high_damage,
        "eligible_non_jitter_candidate_count": non_jitter_eligible_count,
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


def summarize_policy(
    candidates: list[MonsterCandidate],
    guarded_records: list[dict[str, Any]],
    terrain_policy: str,
    membership_policy: str,
    descriptor_subtypes: set[int] | None,
) -> dict[str, Any]:
    rows = [
        constructor_rng_for_record(candidates, record, terrain_policy, descriptor_subtypes)
        for record in guarded_records
    ]
    success_rows = [row for row in rows if row["constructor_success"]]
    diagnostic_unavailable_rows = [row for row in rows if not row.get("diagnostic_rng_available", True)]
    return {
        "policy": f"{membership_policy}::{terrain_policy}",
        "membership_policy": membership_policy,
        "terrain_policy": terrain_policy,
        "descriptor_subtype_count": None if descriptor_subtypes is None else len(descriptor_subtypes),
        "descriptor_subtype_sample": None if descriptor_subtypes is None else sorted(descriptor_subtypes)[:24],
        "guarded_reward_count": len(guarded_records),
        "constructor_success_count": len(success_rows),
        "constructor_failure_count": len(guarded_records) - len(success_rows),
        "diagnostic_rng_unavailable_count": len(diagnostic_unavailable_rows),
        "constructor_rng_calls": sum(int(row["constructor_rng_calls"]) for row in rows),
        "attach_rng_calls": sum(int(row["attach_rng_calls"]) for row in rows),
        "total_rng_calls": sum(int(row["total_rng_calls"]) for row in rows),
        "jittered_constructor_count": sum(1 for row in rows if int(row.get("quantity_jitter_rng_calls", 0)) == 2),
        "non_jitter_selected_count": sum(1 for row in rows if row["constructor_success"] and int(row.get("quantity_jitter_rng_calls", 0)) == 0),
        "eligible_non_jitter_candidate_total": sum(int(row.get("eligible_non_jitter_candidate_count", 0)) for row in rows),
        "sample_records": rows[:8],
        "diagnostic_rng_unavailable_sample": diagnostic_unavailable_rows[:8],
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
    catalog_summary = parse_type54_catalog(args.object_catalog)
    guarded_records = load_guarded_records(args.phase_snapshot)
    terrain_policies = [
        "flattened_all_candidates",
        "runtime_terrain_or_neutral",
        "runtime_terrain_only",
        "selected_template_primary_mask",
        "selected_template_primary_mask_neutral0",
        "selected_template_secondary_mask",
        "selected_template_secondary_mask_neutral0",
        "selected_template_secondary_mask_reversed",
        "selected_template_secondary_mask_reversed_neutral0",
    ]
    memberships = descriptor_memberships(candidates, catalog_summary, parse_subtype_set(args.descriptor_subtypes))
    policy_summaries = [
        summarize_policy(candidates, guarded_records, terrain_policy, membership_policy, descriptor_subtypes)
        for membership_policy, descriptor_subtypes in memberships.items()
        for terrain_policy in terrain_policies
    ]
    exact_policy_matches = [
        summary["policy"]
        for summary in policy_summaries
        if summary["total_rng_calls"] == args.expected_gap
    ]
    scheduler = json.loads(args.phase_snapshot.read_text(encoding="utf-8"))["h3maped_small_port"]["mines_rewards_and_object_vector"]["reward_scheduler_boundary"]
    positive_guard_record_count = len(guarded_records)
    native_guard_coordinate_records = scheduler.get("reward_guard_coordinate_record_count")
    active_guard_attach_rng_calls = scheduler.get("reward_guard_attach_rng_call_count_0x49cf34")
    return {
        "schema_id": "rmg_reward_guard_constructor_gap_v1",
        "phase_snapshot": str(args.phase_snapshot),
        "native_source": str(args.native_source),
        "crtraits": str(args.crtraits),
        "expected_pre_0x4a8260_gap": args.expected_gap,
        "expected_gap_comparison_scope_warning": (
            "The expected gap is the same-run H3MapEd/native route-entry RNG offset. "
            "The guarded records in this native phase snapshot are native-selected "
            "0x4aa354 records after drift has already occurred. They are valid for "
            "rejecting broad native surrogate policies, but they are not authoritative "
            "proof of the H3MapEd same-run constructor count unless the live H3MapEd "
            "0x4aa354 selected descriptor/object stream is joined to these records."
        ),
        "candidate_count": len(candidates),
        "candidate_table_contract": {
            "source_function": "0x4a5c07",
            "candidate_table": "0x581298",
            "single_level_scan": "table rows 117 down to 0 when generator +0x08 < 1",
            "descriptor_vector": "generator +0x398/+0x39c maps descriptor +0x20 subtype to descriptor-vector index",
            "terrain_mask": "selected reward/member descriptor +0x94/+0x95 creates a 10-byte local terrain mask; catalog 9-slot masks are only a proxy until that live field is serialized",
            "rng_calls": "one RNG for eligible row selection; two more only when floor(round(guard_value / ai_value) / 4) + 1 is greater than 1; one later RNG for 0x49cf34 attach selection when candidate coordinates survive",
        },
        "candidate_ai_mismatch_count": len(ai_mismatches),
        "candidate_ai_mismatches": ai_mismatches,
        "object_catalog_type54_summary": {
            key: value
            for key, value in catalog_summary.items()
            if key != "type54_subtypes"
        },
        "descriptor_membership_summaries": {
            policy: {
                "subtype_count": None if subtypes is None else len(subtypes),
                "subtype_min": None if not subtypes else min(subtypes),
                "subtype_max": None if not subtypes else max(subtypes),
                "subtype_sample": None if subtypes is None else sorted(subtypes)[:32],
                "missing_candidate_rows": None
                if subtypes is None
                else sorted({candidate.monster_table_index for candidate in candidates} - subtypes),
            }
            for policy, subtypes in memberships.items()
        },
        "guarded_reward_count": len(guarded_records),
        "native_reward_scheduler_guard_counters": {
            "object_lookup_count": scheduler.get("object_lookup_count"),
            "guarded_object_lookup_record_count": len(guarded_records),
            "reward_guard_attach_source_invocation_count_0x49cf34": scheduler.get("reward_guard_attach_source_invocation_count_0x49cf34"),
            "reward_guard_attach_source_skipped_count_0x49cf34": scheduler.get("reward_guard_attach_source_skipped_count_0x49cf34"),
            "reward_guard_attach_rng_call_count_0x49cf34": scheduler.get("reward_guard_attach_rng_call_count_0x49cf34"),
            "reward_guard_placement_attempt_count": scheduler.get("reward_guard_placement_attempt_count"),
            "reward_guard_coordinate_record_count": scheduler.get("reward_guard_coordinate_record_count"),
        },
        "policy_summaries": policy_summaries,
        "exact_policy_matches_expected_gap": exact_policy_matches,
        "conclusion": (
            "The recovered 0x4a5c07 constructor shape is now modeled explicitly, "
            "including the descriptor-vector subtype filter, the ten-slot descriptor "
            "terrain-mask proxy variants, source selection order, and the exact "
            "quantity-jitter RNG condition. The modeled native-selected guarded "
            f"records still do not make the same-run {args.expected_gap}-call route-entry gap directly "
            "actionable, because the input record set is already native-drifted: "
            f"{positive_guard_record_count} positive native lookup records exist, but only "
            f"{native_guard_coordinate_records} native surrogate guard-coordinate records are "
            f"materialized and {active_guard_attach_rng_calls} active 0x49cf34 RNG calls are "
            "consumed. The remaining source-backed blocker is therefore the live "
            "0x4aa354 H3MapEd callsite stream itself: selected reward descriptor, "
            "generator +0x398/+0x39c vector contents, selected descriptor "
            "+0x94/+0x95/+0x20 state, and whether that same-run selected record "
            "actually enters 0x4a5c07/0x49cf34. Active RNG adoption must stay disabled "
            "until that live stream is available or a recovered replay artifact provides "
            "the exact same data."
        ),
        "native_behavior_changed": False,
        "is_gate": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--phase-snapshot", type=Path, required=True)
    parser.add_argument("--native-source", type=Path, default=DEFAULT_NATIVE_SOURCE)
    parser.add_argument("--crtraits", type=Path, default=DEFAULT_CRTRAITS)
    parser.add_argument("--object-catalog", type=Path, default=DEFAULT_OBJECT_CATALOG)
    parser.add_argument("--descriptor-subtypes", help="Optional explicit descriptor +0x20 subtype set, e.g. '0-117,132'.")
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
