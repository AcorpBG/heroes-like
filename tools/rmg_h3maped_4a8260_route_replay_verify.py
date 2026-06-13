#!/usr/bin/env python3
"""Verify recovered H3MapEd 0x4a8260 route replay evidence.

This is a focused native-adoption helper. It does not trace H3MapEd and does
not tune native output. It consumes already recovered route-call artifacts,
replays the route container mechanics, derives the route RNG boundary for the
controlled seed-58 stream, and can compare that boundary to native phase
snapshot RNG states.
"""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ROUTE_LEDGER = ROOT / ".artifacts/rmg_recovery/seed58_piped_4a8260_route_call_sites_to_4a4c8e_full/winedbg_recovery_trace_ledger.json"
DEFAULT_TRACE_ANALYSIS = ROOT / ".artifacts/rmg_recovery/seed58_trace_analysis.json"
DEFAULT_OUT = ROOT / ".artifacts/rmg_recovery/seed58_4a8260_route_replay_verify_20260611.json"
ROUTE_SITES = {
    "0x004a8491",
    "0x004a849d",
    "0x004a84a9",
    "0x004a84b5",
    "0x004a858f",
    "0x004a863e",
    "0x004a864a",
}
SPLIT_SITE_ORDER = ["0x004a8491", "0x004a849d", "0x004a84a9", "0x004a84b5"]
REQUIRED_SOURCE_STREAM = {
    "ordered_addresses": [
        "0x004aa354",
        "0x004aa38a",
        "0x004aa38f",
        "0x004aa3a8",
        "0x004aa3b6",
        "0x0049cf34",
        "0x0049d2be",
        "0x004aa3bb",
    ],
    "required_generator_state": [
        "generator +0x398 descriptor-vector begin",
        "generator +0x39c descriptor-vector end",
        "selected descriptor +0x94/+0x95 state",
        "selected descriptor/object identity for each 0x4aa354 call",
        "per-call branch into or around 0x4a5c07/0x49cf34",
    ],
}


def s32(value: Any) -> int:
    raw = int(value) & 0xFFFFFFFF
    return raw - 0x100000000 if raw >= 0x80000000 else raw


def u32(value: Any) -> int:
    return int(value) & 0xFFFFFFFF


def trunc_div(numerator: int, denominator: int) -> int:
    if denominator <= 0:
        raise ValueError(f"expected positive denominator, got {denominator}")
    return (abs(numerator) // denominator) * (-1 if numerator < 0 else 1)


def half_sum(a: int, b: int) -> int:
    # 0x4a8406/0x4a8418: lea sum+1, cdq, sub sign, sar 1.
    return trunc_div(a + b + 1, 2)


def distance_4cc5ad(dx: int, dy: int) -> int:
    return int(math.sqrt(dx * dx + dy * dy))


def h3maped_next(state: int) -> tuple[int, int]:
    state = (state * 0x343FD + 0x269EC3) & 0xFFFFFFFF
    return state, (state >> 16) & 0x7FFF


def coord_from_event(event: dict[str, Any]) -> tuple[int, int] | None:
    address = str(event.get("address", ""))
    lines = event.get("memory_lines") if isinstance(event.get("memory_lines"), list) else []
    if address == "0x004a858f":
        # The piped route-call ledger captures stack args directly here:
        # x, y, level, ...
        if not lines:
            return None
        words = lines[0].get("words", [])
        if len(words) < 2:
            return None
        return (s32(words[0]), s32(words[1]))

    if not lines:
        return None
    first_words = lines[0].get("words", [])
    if not first_words:
        return None
    source_ptr = u32(first_words[0])
    for line in lines:
        if int(line.get("address", -1)) != source_ptr:
            continue
        words = line.get("words", [])
        if len(words) >= 2:
            return (s32(words[0]), s32(words[1]))
    return None


def load_route_events(route_ledger: Path) -> list[tuple[str, tuple[int, int]]]:
    ledger = json.loads(route_ledger.read_text(encoding="utf-8"))
    events = ledger.get("events", [])
    route_events: list[tuple[str, tuple[int, int]]] = []
    for event in events:
        if not isinstance(event, dict):
            continue
        address = str(event.get("address", ""))
        if address not in ROUTE_SITES:
            continue
        coord = coord_from_event(event)
        if coord is None:
            raise ValueError(f"could not parse coordinate for route event {address}")
        route_events.append((address, coord))
    return route_events


def group_route_events(route_events: list[tuple[str, tuple[int, int]]]) -> tuple[
    list[tuple[tuple[int, int], tuple[int, int], tuple[int, int], tuple[int, int]]],
    list[tuple[int, int]],
    list[tuple[tuple[int, int], tuple[int, int]]],
]:
    splits: list[tuple[tuple[int, int], tuple[int, int], tuple[int, int], tuple[int, int]]] = []
    stamps: list[tuple[int, int]] = []
    far_pairs: list[tuple[tuple[int, int], tuple[int, int]]] = []
    index = 0
    while index < len(route_events):
        address, coord = route_events[index]
        if address == "0x004a858f":
            stamps.append(coord)
            index += 1
            continue
        if address == "0x004a863e":
            if index + 1 >= len(route_events) or route_events[index + 1][0] != "0x004a864a":
                raise ValueError(f"malformed far-cut insertion pair at route event {index}")
            far_pairs.append((coord, route_events[index + 1][1]))
            index += 2
            continue
        if address == "0x004a8491":
            chunk = route_events[index : index + 4]
            if [item[0] for item in chunk] != SPLIT_SITE_ORDER:
                raise ValueError(f"malformed split insertion group at route event {index}: {chunk}")
            splits.append((chunk[0][1], chunk[1][1], chunk[2][1], chunk[3][1]))
            index += 4
            continue
        raise ValueError(f"unexpected route event {index}: {route_events[index]}")
    return splits, stamps, far_pairs


def replay_route(
    splits: list[tuple[tuple[int, int], tuple[int, int], tuple[int, int], tuple[int, int]]],
    stamps: list[tuple[int, int]],
    far_pairs: list[tuple[tuple[int, int], tuple[int, int]]],
    a80dc_pairs: list[dict[str, Any]],
    width: int,
    height: int,
) -> dict[str, Any]:
    if not splits:
        raise ValueError("route split stream is empty")
    pending = [splits[0][3], splits[0][0]]
    secondary: list[tuple[tuple[int, int], tuple[int, int]]] = []
    split_index = 0
    stamp_index = 0
    a80dc_index = 0
    far_index = 0
    silent_oob_terminal_count = 0
    errors: list[dict[str, Any]] = []

    while True:
        while len(pending) >= 2:
            p1 = pending.pop()
            p2 = pending.pop()
            midpoint = (half_sum(p1[0], p2[0]), half_sum(p1[1], p2[1]))
            if midpoint == p1 or midpoint == p2:
                # 0x8562 calls 0x49a85d only if the second popped coordinate is
                # in bounds. Off-map terminal points are silently discarded.
                expected = p2
                if 0 <= expected[0] < width and 0 <= expected[1] < height:
                    if stamp_index >= len(stamps) or stamps[stamp_index] != expected:
                        errors.append(
                            {
                                "kind": "stamp_mismatch",
                                "stamp_index": stamp_index,
                                "expected": list(expected),
                                "actual": list(stamps[stamp_index]) if stamp_index < len(stamps) else None,
                                "p1": list(p1),
                                "p2": list(p2),
                            }
                        )
                        break
                    stamp_index += 1
                else:
                    silent_oob_terminal_count += 1
                continue

            if split_index >= len(splits):
                errors.append({"kind": "missing_split", "split_index": split_index})
                break
            observed = splits[split_index]
            if observed[0] != p1 or observed[3] != p2:
                errors.append(
                    {
                        "kind": "split_endpoint_mismatch",
                        "split_index": split_index,
                        "expected_p1": list(p1),
                        "expected_p2": list(p2),
                        "actual": [list(item) for item in observed],
                    }
                )
                break

            mid = observed[1]
            dx = p1[0] - p2[0]
            dyneg = p2[1] - p1[1]
            distance = distance_4cc5ad(dx, dyneg)
            if distance >= 8 and 0 <= mid[0] < width and 0 <= mid[1] < height:
                secondary.append((mid, (mid[0] + dyneg, mid[1] + dx)))
                secondary.append((mid, (mid[0] - dyneg, mid[1] - dx)))
            pending.extend([p1, mid, mid, p2])
            split_index += 1

        if errors:
            break
        if not secondary:
            break
        if a80dc_index >= len(a80dc_pairs):
            errors.append({"kind": "missing_4a80dc_pair", "a80dc_index": a80dc_index})
            break

        start, target = secondary.pop(0)
        pair = a80dc_pairs[a80dc_index]
        if tuple(pair.get("start", [])) != start or tuple(pair.get("target", [])) != target:
            errors.append(
                {
                    "kind": "4a80dc_pair_mismatch",
                    "a80dc_index": a80dc_index,
                    "expected_start": list(start),
                    "expected_target": list(target),
                    "actual": pair,
                }
            )
            break
        returned = tuple(pair.get("return", []))
        distance_squared = (int(returned[0]) - start[0]) ** 2 + (int(returned[1]) - start[1]) ** 2
        if distance_squared >= 25:
            expected_far = (returned, start)
            if far_index >= len(far_pairs) or far_pairs[far_index] != expected_far:
                errors.append(
                    {
                        "kind": "far_cut_mismatch",
                        "far_index": far_index,
                        "expected": [list(expected_far[0]), list(expected_far[1])],
                        "actual": [list(item) for item in far_pairs[far_index]] if far_index < len(far_pairs) else None,
                    }
                )
                break
            pending.extend([returned, start])
            far_index += 1
        a80dc_index += 1

    return {
        "status": "pass" if not errors else "mismatch",
        "split_replayed_count": split_index,
        "split_total": len(splits),
        "stamp_replayed_count": stamp_index,
        "stamp_total": len(stamps),
        "a80dc_replayed_count": a80dc_index,
        "a80dc_total": len(a80dc_pairs),
        "far_cut_replayed_count": far_index,
        "far_cut_total": len(far_pairs),
        "silent_oob_terminal_count": silent_oob_terminal_count,
        "pending_remaining": len(pending),
        "secondary_remaining": len(secondary),
        "errors": errors,
    }


def route_rng_constraints(
    splits: list[tuple[tuple[int, int], tuple[int, int], tuple[int, int], tuple[int, int]]],
) -> tuple[list[tuple[int, set[int]]], dict[str, Any]]:
    constraints: list[tuple[int, set[int]]] = [(4, {0})]
    unique_count = 0
    ambiguous_count = 0
    no_rng_split_count = 0
    for p1, mid, mid2, p2 in splits:
        if mid != mid2:
            raise ValueError(f"split midpoint mismatch: {p1}, {mid}, {mid2}, {p2}")
        dx = p1[0] - p2[0]
        dyneg = p2[1] - p1[1]
        distance = distance_4cc5ad(dx, dyneg)
        if distance <= 1:
            no_rng_split_count += 1
            continue
        base = (half_sum(p1[0], p2[0]), half_sum(p1[1], p2[1]))
        half = trunc_div(distance, 2)
        remainders: set[int] = set()
        for remainder in range(distance):
            offset = remainder - half
            candidate = (
                base[0] + trunc_div(offset * dyneg, distance),
                base[1] + trunc_div(offset * dx, distance),
            )
            if candidate == mid:
                remainders.add(remainder)
        if not remainders:
            raise ValueError(f"no RNG remainder can produce midpoint {mid} from {p1}->{p2}")
        if len(remainders) == 1:
            unique_count += 1
        else:
            ambiguous_count += 1
        constraints.append((distance, remainders))
    return constraints, {
        "rng_call_count": len(constraints),
        "unique_remainder_count": unique_count,
        "ambiguous_remainder_count": ambiguous_count,
        "no_rng_split_count": no_rng_split_count,
    }


def find_rng_offsets(seed: int, constraints: list[tuple[int, set[int]]], max_offset: int) -> list[dict[str, Any]]:
    state = seed & 0xFFFFFFFF
    states: list[int] = []
    values: list[int] = []
    for _ in range(max_offset + len(constraints) + 8):
        state, value = h3maped_next(state)
        states.append(state)
        values.append(value)

    hits: list[dict[str, Any]] = []
    for offset in range(max_offset):
        ok = True
        for index, (modulus, allowed) in enumerate(constraints):
            if values[offset + index] % modulus not in allowed:
                ok = False
                break
        if ok:
            entry_state = seed & 0xFFFFFFFF if offset == 0 else states[offset - 1]
            hits.append(
                {
                    "offset": offset,
                    "entry_state_before_selector_uint32": entry_state,
                    "selector_value": values[offset],
                    "first_values": values[offset : offset + 12],
                }
            )
    return hits


def find_native_rng_states(snapshot: dict[str, Any]) -> dict[str, int]:
    port = snapshot.get("h3maped_small_port", {})
    candidates = {
        "town_object_rng_after_0x4a93a2_uint32": (
            port.get("town_castle_phase", {})
            .get("direct_stamping_projection", {})
            .get("object_rng_state_after_0x4a93a2_uint32")
        ),
        "mine_object_rng_before_0x4a9911_uint32": (
            port.get("mines_rewards_and_object_vector", {})
            .get("mine_requirements_boundary", {})
            .get("object_rng_state_before_0x4a9911_uint32")
        ),
        "mine_object_rng_after_0x4a9911_0x4a9641_uint32": (
            port.get("mines_rewards_and_object_vector", {})
            .get("mine_requirements_boundary", {})
            .get("object_rng_state_after_0x4a9911_0x4a9641_uint32")
        ),
        "reward_preview_rng_after_0x4aa354_uint32": (
            port.get("mines_rewards_and_object_vector", {})
            .get("reward_scheduler_boundary", {})
            .get("preview_rng_state_after_0x4aa354_uint32")
        ),
        "route_container_0x4a8260_rng_state_before_uint32": (
            port.get("generated_cell_decoration_bit_state", {})
            .get("route_container_0x4a8260_rng_state_before_uint32")
        ),
        "connection_dispatch_rng_before_uint32": (
            port.get("connections_blockers_guards", {})
            .get("dispatch_summary", {})
            .get("rng_state_before_connection_dispatch_uint32")
        ),
        "connection_dispatch_rng_after_uint32": (
            port.get("connections_blockers_guards", {})
            .get("dispatch_summary", {})
            .get("rng_state_after_connection_dispatch_uint32")
        ),
        "decorative_filler_rng_before_0x49e700_uint32": (
            port.get("decorative_obstacle_filler", {})
            .get("rng_state_before_0x49e700_uint32")
        ),
    }
    result: dict[str, int] = {}
    for key, value in candidates.items():
        if value is None:
            continue
        result[key] = u32(value)
    return result


def find_native_route_counts(snapshot: dict[str, Any]) -> dict[str, int | bool | str]:
    phase = (
        snapshot.get("h3maped_small_port", {})
        .get("generated_cell_decoration_bit_state", {})
    )
    if not isinstance(phase, dict) or not phase:
        phase = snapshot.get("plain_cpp_0x4a8260_route_boundary_contract_summary", {})
    if not isinstance(phase, dict):
        phase = {}
    keys = [
        "route_container_0x4a8260_object_vector_scan_status",
        "route_container_0x4a8260_scan_source",
        "route_container_0x4a8260_scan_cell_count",
        "route_container_0x4a8260_object_vector_empty_count",
        "route_container_0x4a8260_object_vector_nonempty_count",
        "route_container_0x4a8260_bit26_set_count",
        "route_container_0x4a8260_bit26_clear_count",
        "route_container_0x4a8260_bit27_set_count",
        "route_container_0x4a8260_pre_scan_bit26_count",
        "route_container_0x4a8260_pre_scan_bit27_count",
        "route_container_0x4a8260_post_scan_bit26_count",
        "route_container_0x4a8260_post_scan_bit27_count",
        "route_container_0x4a8260_route_list_replay_status",
        "route_container_0x4a8260_rng_boundary_exact",
        "route_container_0x4a8260_active_adoption",
        "object_vector_prerequisite_available",
        "native_object_vector_order_materialized",
        "same_run_descriptor_state_complete",
        "generated_cell_mutation_replay_complete",
        "route_container_0x4a8260_orientation_rng_call_count",
        "route_container_0x4a8260_split_rng_call_count",
        "route_container_0x4a8260_split_count",
        "route_container_0x4a8260_stamp_call_count",
        "route_container_0x4a8260_far_cut_count",
        "route_container_0x4a8260_a80dc_call_count",
        "route_container_0x4a8260_final_sweep_0x49a962_call_count",
        "final_decor_candidate_bit_26_count",
        "final_occupied_blocked_bit_27_count",
    ]
    result: dict[str, int | bool | str] = {}
    for key in keys:
        value = phase.get(key)
        if isinstance(value, bool):
            result[key] = value
        elif isinstance(value, int):
            result[key] = value
        elif isinstance(value, str):
            result[key] = value
    return result


def state_offsets_from_seed(seed: int, states: dict[str, int], max_offset: int) -> dict[str, int | None]:
    wanted = set(states.values())
    current = seed & 0xFFFFFFFF
    offsets: dict[int, int] = {}
    for offset in range(max_offset + 1):
        if current in wanted and current not in offsets:
            offsets[current] = offset
        current, _ = h3maped_next(current)
    return {name: offsets.get(state) for name, state in states.items()}


def build_native_adoption_gate(
    native_states: dict[str, int],
    native_offsets: dict[str, int | None],
    native_counts: dict[str, int | bool | str],
    route_entry_state: int | None,
    route_entry_offset: int | None,
    native_has_matching_route_entry_state: bool,
    route_event_counts: dict[str, int],
) -> dict[str, Any]:
    native_route_offset = native_offsets.get("route_container_0x4a8260_rng_state_before_uint32")
    offset_gap = None
    if native_route_offset is not None and route_entry_offset is not None:
        offset_gap = route_entry_offset - native_route_offset

    event_count_matches = {
        "split": native_counts.get("route_container_0x4a8260_split_count") == route_event_counts["split_count"],
        "stamp": native_counts.get("route_container_0x4a8260_stamp_call_count") == route_event_counts["stamp_count"],
        "a80dc": native_counts.get("route_container_0x4a8260_a80dc_call_count") == route_event_counts["a80dc_pair_count"],
        "far_cut": native_counts.get("route_container_0x4a8260_far_cut_count") == route_event_counts["far_cut_pair_count"],
    }
    route_events_match = all(event_count_matches.values())
    native_phase_claims_exact = native_counts.get("route_container_0x4a8260_rng_boundary_exact") is True
    native_active_adoption = native_counts.get("route_container_0x4a8260_active_adoption") is True
    native_object_vector_prerequisite_available = native_counts.get("object_vector_prerequisite_available") is True
    native_object_vector_ready = native_counts.get("native_object_vector_order_materialized") is True
    native_descriptor_state_complete = native_counts.get("same_run_descriptor_state_complete") is True
    native_generated_cell_mutation_replay_complete = native_counts.get("generated_cell_mutation_replay_complete") is True
    native_adoption_allowed = (
        route_entry_state is not None
        and route_entry_offset is not None
        and native_has_matching_route_entry_state
        and route_events_match
        and native_phase_claims_exact
        and native_active_adoption
        and native_object_vector_prerequisite_available
        and native_object_vector_ready
        and native_descriptor_state_complete
        and native_generated_cell_mutation_replay_complete
    )

    denial_reasons: list[str] = []
    if route_entry_state is None or route_entry_offset is None:
        denial_reasons.append("h3maped_route_entry_state_not_unique")
    if not native_has_matching_route_entry_state:
        denial_reasons.append("native_route_entry_rng_state_does_not_match_h3maped")
    if not route_events_match:
        denial_reasons.append("native_route_event_counts_do_not_match_h3maped")
    if not native_phase_claims_exact:
        denial_reasons.append("native_phase_does_not_claim_exact_0x4a8260_rng_boundary")
    if not native_active_adoption:
        denial_reasons.append("native_route_adoption_is_disabled")
    if not native_object_vector_prerequisite_available:
        denial_reasons.append("object_vector_prerequisite_contract_missing")
    if not native_object_vector_ready:
        denial_reasons.append("native_object_vector_order_not_materialized")
    if not native_descriptor_state_complete:
        denial_reasons.append("same_run_descriptor_state_incomplete")
    if not native_generated_cell_mutation_replay_complete:
        denial_reasons.append("generated_cell_mutation_replay_incomplete")

    return {
        "native_adoption_allowed": native_adoption_allowed,
        "native_adoption_status": "allowed" if native_adoption_allowed else "denied",
        "denial_reasons": denial_reasons,
        "h3maped_route_entry_offset_from_seed": route_entry_offset,
        "native_route_entry_offset_from_seed": native_route_offset,
        "route_entry_offset_gap": offset_gap,
        "h3maped_route_entry_state_uint32": route_entry_state,
        "native_route_entry_state_uint32": native_states.get("route_container_0x4a8260_rng_state_before_uint32"),
        "route_event_count_matches": event_count_matches,
        "route_events_match_h3maped": route_events_match,
        "object_vector_prerequisite_available": native_object_vector_prerequisite_available,
        "native_object_vector_order_materialized": native_object_vector_ready,
        "same_run_descriptor_state_complete": native_descriptor_state_complete,
        "generated_cell_mutation_replay_complete": native_generated_cell_mutation_replay_complete,
        "required_source_stream_before_enabling_adoption": REQUIRED_SOURCE_STREAM,
        "source_backed_native_rule_available": native_adoption_allowed,
        "native_behavior_changed": False,
    }


def build_report(args: argparse.Namespace) -> dict[str, Any]:
    route_events = load_route_events(args.route_ledger)
    splits, stamps, far_pairs = group_route_events(route_events)
    trace = json.loads(args.trace_analysis.read_text(encoding="utf-8"))
    a80dc_pairs = trace.get("a80dc", {}).get("pairs", [])
    if not isinstance(a80dc_pairs, list):
        raise ValueError("trace analysis is missing a80dc.pairs")

    replay = replay_route(splits, stamps, far_pairs, a80dc_pairs, args.width, args.height)
    constraints, constraint_summary = route_rng_constraints(splits)
    rng_hits = find_rng_offsets(args.seed, constraints, args.max_rng_offset)

    report: dict[str, Any] = {
        "schema_id": "rmg_h3maped_4a8260_route_replay_verify_v1",
        "status": "pass" if replay["status"] == "pass" and len(rng_hits) == 1 else "mismatch",
        "inputs": {
            "route_ledger": str(args.route_ledger),
            "trace_analysis": str(args.trace_analysis),
            "seed": args.seed,
            "width": args.width,
            "height": args.height,
        },
        "route_event_counts": {
            "route_event_count": len(route_events),
            "split_count": len(splits),
            "stamp_count": len(stamps),
            "far_cut_pair_count": len(far_pairs),
            "a80dc_pair_count": len(a80dc_pairs),
        },
        "route_replay": replay,
        "rng_constraints": constraint_summary,
        "rng_offset_hits": rng_hits,
        "source_adoption_result": {
            "route_mechanics_replay_complete": replay["status"] == "pass",
            "route_rng_entry_state_unique": len(rng_hits) == 1,
            "native_behavior_changed": False,
        },
    }

    if args.native_phase_snapshot:
        snapshot = json.loads(args.native_phase_snapshot.read_text(encoding="utf-8"))
        native_states = find_native_rng_states(snapshot)
        native_offsets = state_offsets_from_seed(args.seed, native_states, args.max_rng_offset)
        native_counts = find_native_route_counts(snapshot)
        route_entry_state = rng_hits[0]["entry_state_before_selector_uint32"] if len(rng_hits) == 1 else None
        report["native_rng_boundary_compare"] = {
            "native_phase_snapshot": str(args.native_phase_snapshot),
            "native_candidate_states": native_states,
            "native_candidate_offsets_from_seed": native_offsets,
            "h3maped_route_entry_state_uint32": route_entry_state,
            "h3maped_route_entry_offset_from_seed": rng_hits[0]["offset"] if len(rng_hits) == 1 else None,
            "native_has_matching_route_entry_state": route_entry_state in native_states.values() if route_entry_state is not None else False,
        }
        report["native_route_event_compare"] = {
            "native_phase_snapshot": str(args.native_phase_snapshot),
            "native_route_counts": native_counts,
            "h3maped_route_counts": report["route_event_counts"],
            "split_count_matches_h3maped": native_counts.get("route_container_0x4a8260_split_count") == len(splits),
            "stamp_count_matches_h3maped": native_counts.get("route_container_0x4a8260_stamp_call_count") == len(stamps),
            "a80dc_count_matches_h3maped": native_counts.get("route_container_0x4a8260_a80dc_call_count") == len(a80dc_pairs),
            "far_cut_count_matches_h3maped": native_counts.get("route_container_0x4a8260_far_cut_count") == len(far_pairs),
        }
        adoption_gate = build_native_adoption_gate(
            native_states=native_states,
            native_offsets=native_offsets,
            native_counts=native_counts,
            route_entry_state=route_entry_state,
            route_entry_offset=rng_hits[0]["offset"] if len(rng_hits) == 1 else None,
            native_has_matching_route_entry_state=report["native_rng_boundary_compare"]["native_has_matching_route_entry_state"],
            route_event_counts=report["route_event_counts"],
        )
        report["native_route_adoption_gate"] = adoption_gate
        report["source_adoption_result"].update(
            {
                "native_adoption_allowed": adoption_gate["native_adoption_allowed"],
                "native_adoption_status": adoption_gate["native_adoption_status"],
                "native_route_entry_offset_from_seed": adoption_gate["native_route_entry_offset_from_seed"],
                "h3maped_route_entry_offset_from_seed": adoption_gate["h3maped_route_entry_offset_from_seed"],
                "route_entry_offset_gap": adoption_gate["route_entry_offset_gap"],
                "denial_reasons": adoption_gate["denial_reasons"],
            }
        )
    return report


def write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--route-ledger", type=Path, default=DEFAULT_ROUTE_LEDGER)
    parser.add_argument("--trace-analysis", type=Path, default=DEFAULT_TRACE_ANALYSIS)
    parser.add_argument("--native-phase-snapshot", type=Path, default=None)
    parser.add_argument("--seed", type=int, default=58)
    parser.add_argument("--width", type=int, default=36)
    parser.add_argument("--height", type=int, default=36)
    parser.add_argument("--max-rng-offset", type=int, default=20000)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    report = build_report(args)
    write_json(args.out, report)
    replay = report["route_replay"]
    hits = report["rng_offset_hits"]
    native = report.get("native_rng_boundary_compare", {})
    adoption_gate = report.get("native_route_adoption_gate", {})
    print(
        "RMG_H3MAPED_4A8260_ROUTE_REPLAY_VERIFY "
        f"status={report['status']} "
        f"splits={replay['split_replayed_count']}/{replay['split_total']} "
        f"stamps={replay['stamp_replayed_count']}/{replay['stamp_total']} "
        f"a80dc={replay['a80dc_replayed_count']}/{replay['a80dc_total']} "
        f"rng_hits={len(hits)} "
        f"route_offset={hits[0]['offset'] if len(hits) == 1 else 'unknown'} "
        f"native_match={native.get('native_has_matching_route_entry_state', '')} "
        f"native_adoption={adoption_gate.get('native_adoption_status', 'not_checked')} "
        f"offset_gap={adoption_gate.get('route_entry_offset_gap', '')} "
        f"out={args.out}"
    )
    return 0 if report["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
