#!/usr/bin/env python3
"""Compare recovered H3MapEd 0x4aa9b7 handoff evidence to a native snapshot.

This is a focused diagnostic, not a parity gate. It checks whether native is
reaching the same 0x4aa9b7 -> 0x4aa3e9 handoff shape already recovered for the
seed58 H3MapEd run, without changing native RMG behavior.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from rmg_h3maped_4aa9b7_success_handoff_summary import summarize as summarize_h3maped_ledger


DEFAULT_H3MAPED_HANDOFF = Path(
    ".artifacts/rmg_recovery/small2p_seed58_4aa9b7_success_handoff_summary_20260610.json"
)
DEFAULT_H3MAPED_LEDGER = Path(
    ".artifacts/rmg_recovery/small2p_seed58_4aa9b7_success_handoff_20260610/"
    "winedbg_interactive_trace_ledger.json"
)


def get_path(payload: dict[str, Any], path: str, default: Any = None) -> Any:
    current: Any = payload
    for part in path.split("."):
        if not isinstance(current, dict) or part not in current:
            return default
        current = current[part]
    return current


def as_int(value: Any, default: int = -1) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def coord_from_mapping(payload: dict[str, Any], prefix: str = "") -> dict[str, int] | None:
    if prefix:
        x = payload.get(f"{prefix}_x")
        y = payload.get(f"{prefix}_y")
        level = payload.get(f"{prefix}_level")
    else:
        x = payload.get("x")
        y = payload.get("y")
        level = payload.get("level")
    if x is None or y is None or level is None:
        return None
    return {"x": as_int(x), "y": as_int(y), "level": as_int(level)}


def summarize_h3maped(source: dict[str, Any]) -> dict[str, Any]:
    first = source.get("first_successful_handoff") or {}
    count_check = first.get("count_check") or {}
    selected_copy = first.get("selected_copy") or {}
    before = first.get("before_4aa3e9") or {}
    selected_coordinate = before.get("selected_coordinate") or {}
    local_vector = count_check.get("local_vector") or {}
    call_sequence = source.get("call_sequence")
    if not isinstance(call_sequence, list):
        call_sequence = []
    return {
        "summary_path_schema": source.get("schema_id"),
        "call_count": as_int(source.get("call_count"), 0),
        "call_sequence": call_sequence,
        "false_completed_call_count_before_success": as_int(
            source.get("false_completed_call_count_before_success"), 0
        ),
        "successful_handoff_count": as_int(source.get("successful_handoff_count"), 0),
        "first_success_event_index": get_path(first, "entry.event_index"),
        "first_success_candidate_count": as_int(local_vector.get("count")),
        "first_success_selected_index": as_int(selected_copy.get("selected_index")),
        "first_success_selected_coordinate": {
            "x": as_int(selected_coordinate.get("x")),
            "y": as_int(selected_coordinate.get("y")),
            "level": as_int(selected_coordinate.get("level")),
        },
        "first_success_slot8_targets": [
            record.get("slot_target")
            for record in first.get("slot8_callbacks", [])
            if isinstance(record, dict)
        ],
    }


def native_attempts(phase_snapshot: dict[str, Any]) -> list[dict[str, Any]]:
    records = get_path(
        phase_snapshot,
        "h3maped_small_port.mines_rewards_and_object_vector.reward_scheduler_boundary.coordinate_placement_records",
        [],
    )
    if not isinstance(records, list):
        return []
    attempts: list[dict[str, Any]] = []
    for index, record in enumerate(records, start=1):
        if not isinstance(record, dict):
            continue
        coordinate = coord_from_mapping(record, "selected")
        success = record.get("coordinate_rng_value") is not None and coordinate is not None
        attempts.append(
            {
                "attempt_index": index,
                "status": record.get("status"),
                "retry_ordinal_0x4aab7e": record.get("retry_ordinal_0x4aab7e"),
                "candidate_count": as_int(record.get("tied_candidate_count")),
                "selected_index": as_int(record.get("selected_coordinate_index")),
                "selected_coordinate": coordinate,
                "coordinate_rng_value": record.get("coordinate_rng_value"),
                "reward_band_selected_value": record.get("reward_band_selected_value"),
                "reward_guard_scaled_value": record.get("reward_guard_scaled_value"),
                "reward_guard_status": record.get("reward_guard_status"),
                "source_final_writer_merge_bit26_mutation_count": record.get(
                    "source_final_writer_merge_bit26_mutation_count"
                ),
                "source_final_writer_merge_bit27_mutation_count": record.get(
                    "source_final_writer_merge_bit27_mutation_count"
                ),
                "success": success,
            }
        )
    return attempts


def summarize_native(phase_snapshot: dict[str, Any]) -> dict[str, Any]:
    attempts = native_attempts(phase_snapshot)
    successes = [attempt for attempt in attempts if attempt["success"]]
    first_success = successes[0] if successes else None
    false_before = 0
    for attempt in attempts:
        if attempt["success"]:
            break
        false_before += 1
    boundary = get_path(
        phase_snapshot,
        "h3maped_small_port.mines_rewards_and_object_vector.reward_scheduler_boundary",
        {},
    )
    return {
        "attempt_count": len(attempts),
        "false_attempt_count_before_first_success": false_before,
        "successful_handoff_count": len(successes),
        "first_success": first_success,
        "reward_scheduler_counters": {
            "value_preview_rng_call_count": boundary.get("value_preview_rng_call_count"),
            "object_lookup_rng_call_count": boundary.get("object_lookup_rng_call_count"),
            "secondary_lookup_rng_call_count_0x4aa1db": boundary.get(
                "secondary_lookup_rng_call_count_0x4aa1db"
            ),
            "secondary_position_rng_call_count_0x49d471": boundary.get(
                "secondary_position_rng_call_count_0x49d471"
            ),
            "coordinate_rng_call_count": boundary.get("coordinate_rng_call_count"),
            "reward_guard_surrogate_rng_call_count": boundary.get(
                "reward_guard_surrogate_rng_call_count"
            ),
        },
        "success_attempts": successes,
    }


def coordinate_equal(left: dict[str, Any] | None, right: dict[str, Any] | None) -> bool:
    if left is None and right is None:
        return True
    if not isinstance(left, dict) or not isinstance(right, dict):
        return False
    return all(as_int(left.get(key)) == as_int(right.get(key)) for key in ("x", "y", "level"))


def source_call_success(call: dict[str, Any]) -> bool:
    return bool(call.get("reached_4aa3e9"))


def native_attempt_success(attempt: dict[str, Any]) -> bool:
    return bool(attempt.get("success"))


def compare_source_native_prefix(
    source_calls: list[dict[str, Any]],
    attempts: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for index, source_call in enumerate(source_calls):
        native_attempt = attempts[index] if index < len(attempts) else None
        source_candidate_count = as_int(source_call.get("candidate_count_at_count_check"))
        source_selected_index = as_int(source_call.get("selected_index"))
        source_coordinate = source_call.get("selected_coordinate_before_4aa3e9")
        if not isinstance(source_coordinate, dict):
            source_coordinate = source_call.get("selected_coordinate_4aa3e9_entry")
        native_candidate_count = as_int(native_attempt.get("candidate_count")) if native_attempt else -1
        native_selected_index = as_int(native_attempt.get("selected_index")) if native_attempt else -1
        native_coordinate = native_attempt.get("selected_coordinate") if native_attempt else None
        rows.append(
            {
                "ordinal": index + 1,
                "source": {
                    "candidate_count": source_candidate_count,
                    "candidate_coordinates": source_call.get("candidate_coordinates_at_count_check", []),
                    "candidate_coordinates_memory_available": source_call.get(
                        "candidate_coordinates_memory_available"
                    ),
                    "selected_index": source_selected_index,
                    "selected_coordinate": source_coordinate,
                    "success": source_call_success(source_call),
                    "entry_minimum_low_word": source_call.get("entry_minimum_low_word"),
                    "entry_policy_word": source_call.get("entry_policy_word"),
                    "entry_extra_arg": source_call.get("entry_extra_arg"),
                },
                "native": None
                if native_attempt is None
                else {
                    "candidate_count": native_candidate_count,
                    "selected_index": native_selected_index,
                    "selected_coordinate": native_coordinate,
                    "success": native_attempt_success(native_attempt),
                    "status": native_attempt.get("status"),
                    "retry_ordinal_0x4aab7e": native_attempt.get("retry_ordinal_0x4aab7e"),
                    "reward_guard_scaled_value": native_attempt.get("reward_guard_scaled_value"),
                },
                "matches": {
                    "candidate_count": native_attempt is not None
                    and source_candidate_count == native_candidate_count,
                    "selected_index": native_attempt is not None
                    and source_selected_index == native_selected_index,
                    "selected_coordinate": native_attempt is not None
                    and coordinate_equal(source_coordinate, native_coordinate),
                    "success": native_attempt is not None
                    and source_call_success(source_call) == native_attempt_success(native_attempt),
                },
            }
        )
    return rows


def compare(h3maped: dict[str, Any], native: dict[str, Any]) -> dict[str, Any]:
    source_summary = summarize_h3maped(h3maped)
    native_summary = summarize_native(native)
    native_all_attempts = native_attempts(native)
    native_first = native_summary.get("first_success") or {}
    same_candidate_shape = []
    for attempt in native_summary["success_attempts"]:
        if (
            attempt["candidate_count"] == source_summary["first_success_candidate_count"]
            and attempt["selected_index"] == source_summary["first_success_selected_index"]
        ):
            same_candidate_shape.append(attempt)

    first_success_matches = {
        "false_before_success": native_summary["false_attempt_count_before_first_success"]
        == source_summary["false_completed_call_count_before_success"],
        "candidate_count": native_first.get("candidate_count")
        == source_summary["first_success_candidate_count"],
        "selected_index": native_first.get("selected_index")
        == source_summary["first_success_selected_index"],
        "selected_coordinate": coordinate_equal(
            native_first.get("selected_coordinate"),
            source_summary["first_success_selected_coordinate"],
        ),
    }
    source_calls = source_summary["call_sequence"]
    prefix_comparison = compare_source_native_prefix(source_calls, native_all_attempts)
    prefix_full_match_count = sum(1 for row in prefix_comparison if all(row["matches"].values()))
    first_prefix_divergence = next(
        (row for row in prefix_comparison if not all(row["matches"].values())),
        None,
    )
    source_positive_candidate_calls_without_coordinate_memory = [
        call
        for call in source_calls
        if as_int(call.get("candidate_count_at_count_check")) > 0
        and not call.get("candidate_coordinates_memory_available")
    ]
    return {
        "schema_id": "rmg_h3maped_4aa9b7_native_handoff_compare_v1",
        "is_gate": False,
        "native_behavior_changed": False,
        "source_scope": "seed58 recovered H3MapEd 0x4aa9b7 -> 0x4aa3e9 handoff summary",
        "native_scope": "native phase snapshot reward_scheduler_boundary.coordinate_placement_records",
        "h3maped_first_success": source_summary,
        "native_handoff_summary": {
            key: value
            for key, value in native_summary.items()
            if key != "success_attempts"
        },
        "source_native_prefix_comparison": prefix_comparison,
        "source_native_prefix_full_match_count": prefix_full_match_count,
        "source_native_first_prefix_divergence": first_prefix_divergence,
        "first_success_matches_h3maped": first_success_matches,
        "native_successes_with_same_candidate_count_and_selected_index": same_candidate_shape,
        "diagnosis": (
            "Native does not match the recovered seed58 H3MapEd 0x4aa9b7 boundary if any "
            "first_success_matches_h3maped field is false. In particular, a false-before-success "
            "mismatch means native and the recovered source callstream expose different candidate "
            "availability before route generation; do not compensate later in route adoption."
        ),
        "comparison_limitations": [
            "The recovered source trace is wrapper-specific, but native coordinate placement records do not expose the source wrapper pointer/relation, so prefix comparison is ordinal evidence, not a same-wrapper pointer join.",
            "The recovered source trace captures local vector pointers/counts and selected coordinate; candidate-vector coordinate contents are only available when the heap range was captured in the ledger memory dump.",
        ],
        "source_positive_candidate_calls_without_coordinate_memory": source_positive_candidate_calls_without_coordinate_memory,
        "remaining_source_blocker": (
            "This comparison starts at 0x4aa9b7. It still does not prove the missing upstream "
            "0x4aa354 selected reward/guard descriptor stream or source-backed 0x4a5c07/0x49cf34 "
            "constructor branch decisions."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--h3maped-handoff", type=Path, default=DEFAULT_H3MAPED_HANDOFF)
    parser.add_argument("--h3maped-ledger", type=Path, default=DEFAULT_H3MAPED_LEDGER)
    parser.add_argument("--native-phase-snapshot", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    return parser


def load_h3maped_source(summary_path: Path, ledger_path: Path) -> dict[str, Any]:
    summary = json.loads(summary_path.read_text(encoding="utf-8"))
    if isinstance(summary.get("call_sequence"), list):
        return summary
    if ledger_path.exists():
        ledger = json.loads(ledger_path.read_text(encoding="utf-8"))
        return summarize_h3maped_ledger(ledger)
    return summary


def main() -> int:
    args = build_parser().parse_args()
    h3maped = load_h3maped_source(args.h3maped_handoff, args.h3maped_ledger)
    native = json.loads(args.native_phase_snapshot.read_text(encoding="utf-8"))
    report = compare(h3maped, native)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    matches = report["first_success_matches_h3maped"]
    matched_fields = sum(1 for value in matches.values() if value)
    print(
        "RMG_H3MAPED_4AA9B7_NATIVE_HANDOFF_COMPARE "
        f"matched_fields={matched_fields}/{len(matches)} "
        f"prefix_full_matches={report['source_native_prefix_full_match_count']}/"
        f"{len(report['source_native_prefix_comparison'])} "
        f"h3_false_before={report['h3maped_first_success']['false_completed_call_count_before_success']} "
        f"native_false_before={report['native_handoff_summary']['false_attempt_count_before_first_success']} "
        f"same_candidate_shape={len(report['native_successes_with_same_candidate_count_and_selected_index'])} "
        f"out={args.out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
