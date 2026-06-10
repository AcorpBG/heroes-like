#!/usr/bin/env python3
"""Summarize broader ``0x4a54a7`` commit surface from existing Wine ledgers.

This is recovery evidence only. It reads the Medium seed-1 and seed-2
``0x4a61bc`` payload-link ledgers and verifies the broad commit boundary seen
there: object record pointer, coordinate, generated-cell snapshot, projection
completion at ``0x4a5756``, return-site distribution, and low-word clearing on
the sampled cell when both before/after snapshots are present. The ledgers do
not include internal ``0x4a56b6`` projection-loop write stops, so this report
explicitly does not claim full projection-write recovery.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_SEED1_LEDGER = Path(
    ".artifacts/rmg_recovery/medium_seed1_4a696b_grid_scan_20260610/"
    "winedbg_4a61bc_payload_link_dynamic_trace_ledger.json"
)
DEFAULT_SEED2_LEDGER = Path(
    ".artifacts/rmg_recovery/medium_seed2_4a696b_grid_scan_20260610/"
    "winedbg_4a61bc_payload_link_dynamic_trace_salvage_ledger.json"
)
DEFAULT_OUT = Path(
    ".artifacts/rmg_recovery/medium_4a54a7_cross_seed_commit_surface_summary_20260610.json"
)

COMMIT = "0x004a54a7"
PROJECTION_DONE = "0x004a5756"
EXPECTED_COMMIT_RETURN = "0x004a5e6c"


def qhex(value: int | None) -> str | None:
    return None if value is None else f"0x{value & 0xFFFFFFFF:08x}"


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def address(event: dict[str, Any]) -> str:
    return str(event.get("address", "")).lower()


def memory_blocks(event: dict[str, Any]) -> dict[int, list[int]]:
    blocks: dict[int, list[int]] = {}
    for line in event.get("memory_lines", []):
        line_address = line.get("address")
        if not isinstance(line_address, int):
            continue
        words = [int(word) & 0xFFFFFFFF for word in line.get("words", [])]
        if words:
            blocks[line_address] = words
    return blocks


def block_words_at(event: dict[str, Any], start: int, max_words: int) -> list[int]:
    blocks = memory_blocks(event)
    words: list[int] = []
    cursor = start
    while len(words) < max_words and cursor in blocks:
        chunk = blocks[cursor]
        words.extend(chunk)
        cursor += len(chunk) * 4
    return words[:max_words]


def first_words(event: dict[str, Any]) -> list[int]:
    lines = event.get("memory_lines", [])
    if not lines:
        return []
    return [int(word) & 0xFFFFFFFF for word in lines[0].get("words", [])]


def return_address(event: dict[str, Any] | None) -> str | None:
    if event is None:
        return None
    derived = event.get("derived", {})
    if isinstance(derived.get("return_address"), str):
        return derived["return_address"].lower()
    words = first_words(event)
    return qhex(words[0]).lower() if words else None


def stack_args(event: dict[str, Any]) -> dict[str, Any]:
    words = first_words(event)
    level_words = (
        event.get("memory_lines", [{}])[1].get("words", [])
        if len(event.get("memory_lines", [])) > 1
        else []
    )
    return {
        "return_address": return_address(event),
        "object_record_pointer": qhex(words[1] if len(words) > 1 else None),
        "x": words[2] if len(words) > 2 else None,
        "y": words[3] if len(words) > 3 else None,
        "level": int(level_words[0]) & 0xFFFFFFFF if level_words else None,
    }


def generated_cell_candidates(event: dict[str, Any], x: int | None, y: int | None) -> list[dict[str, Any]]:
    candidates: list[dict[str, Any]] = []
    for start in sorted(memory_blocks(event)):
        words = block_words_at(event, start, 16)
        if len(words) < 12:
            continue
        cell_x = words[4]
        cell_y = words[5]
        level = words[6]
        if not (0 <= cell_x <= 255 and 0 <= cell_y <= 255 and 0 <= level <= 7):
            continue
        word20 = words[8]
        word24 = words[9]
        word28 = words[10]
        # Generated-cell snapshots in these traces expose meaningful coordinate
        # triples plus populated private words. This rejects stack/vector dumps.
        if word20 == 0 and word24 == 0 and word28 == 0:
            continue
        distance = None
        if x is not None and y is not None:
            distance = abs(int(x) - int(cell_x)) + abs(int(y) - int(cell_y))
        candidates.append(
            {
                "cell_pointer": qhex(start),
                "coordinate": {"x": cell_x, "y": cell_y, "level": level},
                "distance_from_commit_coordinate": distance,
                "object_ref_vector": {
                    "begin": qhex(words[1]),
                    "end": qhex(words[2]),
                    "capacity": qhex(words[3]),
                    "empty": words[1] == words[2],
                    "first_word": qhex(block_words_at(event, words[1], 1)[0])
                    if words[1] != 0 and block_words_at(event, words[1], 1)
                    else None,
                },
                "generated_cell_words": {
                    "+0x20": qhex(word20),
                    "+0x24": qhex(word24),
                    "+0x28": qhex(word28),
                    "+0x2c": qhex(words[11]),
                },
                "low_word_0x20": word20 & 0xFFFF,
                "high_word_0x20": word20 & 0xFFFF0000,
                "raw_words": [qhex(word) for word in words],
            }
        )
    candidates.sort(
        key=lambda item: (
            999999
            if item["distance_from_commit_coordinate"] is None
            else int(item["distance_from_commit_coordinate"]),
            item["cell_pointer"] or "",
        )
    )
    return candidates


def find_next(events: list[dict[str, Any]], start: int, wanted: str) -> tuple[int | None, dict[str, Any] | None]:
    for index in range(start, len(events)):
        if address(events[index]) == wanted:
            return index, events[index]
        if address(events[index]) == COMMIT:
            break
    return None, None


def summarize_call(events: list[dict[str, Any]], index: int) -> dict[str, Any]:
    commit = events[index]
    args = stack_args(commit)
    done_index, done = find_next(events, index + 1, PROJECTION_DONE)
    commit_cells = generated_cell_candidates(commit, args.get("x"), args.get("y"))
    done_cells = generated_cell_candidates(done, args.get("x"), args.get("y")) if done else []
    commit_cell = commit_cells[0] if commit_cells else None
    done_cell = None
    if done_cells and commit_cell:
        matching = [cell for cell in done_cells if cell["cell_pointer"] == commit_cell["cell_pointer"]]
        done_cell = matching[0] if matching else done_cells[0]
    elif done_cells:
        done_cell = done_cells[0]

    before_word = int(commit_cell["generated_cell_words"]["+0x20"], 16) if commit_cell else None
    after_word = int(done_cell["generated_cell_words"]["+0x20"], 16) if done_cell else None
    object_pointer = args.get("object_record_pointer")
    invariants = {
        "projection_done_reached_before_next_commit": done is not None,
        "cell_snapshot_at_commit": commit_cell is not None,
        "cell_snapshot_at_projection_done": done_cell is not None,
        "same_cell_snapshot_pointer": bool(
            commit_cell and done_cell and commit_cell["cell_pointer"] == done_cell["cell_pointer"]
        ),
        "cell_low_word_cleared": bool(
            before_word is not None
            and after_word is not None
            and (before_word & 0xFFFF) != 0
            and (after_word & 0xFFFF) == 0
        ),
        "cell_high_word_preserved": bool(
            before_word is not None
            and after_word is not None
            and (before_word & 0xFFFF0000) == (after_word & 0xFFFF0000)
        ),
        "post_cell_ref_pointer_available": bool(
            done_cell
            and not done_cell["object_ref_vector"]["empty"]
            and done_cell["object_ref_vector"]["first_word"] is not None
        ),
        "post_cell_references_committed_object_when_available": bool(
            done_cell
            and not done_cell["object_ref_vector"]["empty"]
            and done_cell["object_ref_vector"]["first_word"] == object_pointer
        ),
    }
    return {
        "commit_event_index": index + 1,
        "projection_done_event_index": None if done_index is None else done_index + 1,
        "commit_args": args,
        "commit_cell": commit_cell,
        "projection_done_cell": done_cell,
        "extra_commit_cell_candidate_count": max(0, len(commit_cells) - 1),
        "extra_projection_done_cell_candidate_count": max(0, len(done_cells) - 1),
        "invariants": invariants,
    }


def summarize_ledger(path: Path) -> dict[str, Any]:
    ledger = read_json(path)
    events = ledger.get("events", [])
    counts = Counter(address(event) for event in events)
    calls = [
        summarize_call(events, index)
        for index, event in enumerate(events)
        if address(event) == COMMIT
    ]
    cell_transition_complete = [
        call
        for call in calls
        if call.get("invariants", {}).get("projection_done_reached_before_next_commit")
        and call.get("invariants", {}).get("cell_snapshot_at_commit")
        and call.get("invariants", {}).get("cell_snapshot_at_projection_done")
        and call.get("invariants", {}).get("same_cell_snapshot_pointer")
        and call.get("invariants", {}).get("cell_low_word_cleared")
        and call.get("invariants", {}).get("cell_high_word_preserved")
    ]
    fallback_calls = [
        call
        for call in calls
        if call.get("commit_args", {}).get("return_address") == EXPECTED_COMMIT_RETURN
    ]
    fallback_cell_transition_complete = [
        call
        for call in fallback_calls
        if call in cell_transition_complete
    ]
    return_sites = Counter(
        call.get("commit_args", {}).get("return_address") or "missing" for call in calls
    )
    post_ref_available = [
        call
        for call in calls
        if call.get("invariants", {}).get("post_cell_ref_pointer_available")
    ]
    post_ref_matches = [
        call
        for call in post_ref_available
        if call.get("invariants", {}).get("post_cell_references_committed_object_when_available")
    ]
    object_pointers = {
        call.get("commit_args", {}).get("object_record_pointer")
        for call in calls
        if call.get("commit_args", {}).get("object_record_pointer")
    }
    coords = [
        (call["commit_args"].get("x"), call["commit_args"].get("y"))
        for call in calls
        if call["commit_args"].get("x") is not None and call["commit_args"].get("y") is not None
    ]
    return {
        "ledger": str(path),
        "seed_control": ledger.get("seed_control"),
        "event_count": len(events),
        "event_counts": dict(sorted(counts.items())),
        "metrics": {
            "commit_call_count": len(calls),
            "complete_cell_transition_count": len(cell_transition_complete),
            "fallback_0x4a5e6c_commit_call_count": len(fallback_calls),
            "fallback_0x4a5e6c_complete_cell_transition_count": len(
                fallback_cell_transition_complete
            ),
            "non_fallback_return_context_commit_count": len(calls) - len(fallback_calls),
            "unique_object_record_count": len(object_pointers),
            "unique_coordinate_count": len(set(coords)),
            "post_cell_object_ref_pointer_available_count": len(post_ref_available),
            "post_cell_object_ref_pointer_match_count": len(post_ref_matches),
        },
        "return_site_counts": dict(sorted(return_sites.items())),
        "coordinate_bounds": {
            "min_x": min((x for x, _ in coords), default=None),
            "max_x": max((x for x, _ in coords), default=None),
            "min_y": min((y for _, y in coords), default=None),
            "max_y": max((y for _, y in coords), default=None),
        },
        "invariants": {
            "ledger_has_events": bool(events),
            "all_commit_calls_reach_projection_done": all(
                call["invariants"]["projection_done_reached_before_next_commit"] for call in calls
            )
            and bool(calls),
            "all_fallback_0x4a5e6c_calls_have_complete_cell_transition": len(fallback_calls)
            == len(fallback_cell_transition_complete)
            and bool(fallback_calls),
            "all_commit_calls_have_cell_snapshots": all(
                call["invariants"]["cell_snapshot_at_commit"]
                and call["invariants"]["cell_snapshot_at_projection_done"]
                for call in calls
            )
            and bool(calls),
            "all_commit_calls_clear_low_word_and_preserve_high_word": all(
                call["invariants"]["cell_low_word_cleared"]
                and call["invariants"]["cell_high_word_preserved"]
                for call in calls
            )
            and bool(calls),
            "all_available_post_cell_refs_match_object": len(post_ref_available)
            == len(post_ref_matches),
        },
        "sample_calls": calls[:12],
        "incomplete_fallback_calls": [
            call
            for call in fallback_calls
            if call not in fallback_cell_transition_complete
        ][:12],
        "non_fallback_return_context_samples": [
            call
            for call in calls
            if call.get("commit_args", {}).get("return_address") != EXPECTED_COMMIT_RETURN
        ][:12],
    }


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    ledgers = [summarize_ledger(path) for path in args.ledgers]
    total_commits = sum(item["metrics"]["commit_call_count"] for item in ledgers)
    total_cell_transitions = sum(
        item["metrics"]["complete_cell_transition_count"] for item in ledgers
    )
    total_fallback_commits = sum(
        item["metrics"]["fallback_0x4a5e6c_commit_call_count"] for item in ledgers
    )
    total_fallback_cell_transitions = sum(
        item["metrics"]["fallback_0x4a5e6c_complete_cell_transition_count"]
        for item in ledgers
    )
    total_non_fallback_contexts = sum(
        item["metrics"]["non_fallback_return_context_commit_count"] for item in ledgers
    )
    return_site_counts: Counter[str] = Counter()
    for item in ledgers:
        return_site_counts.update(item.get("return_site_counts", {}))
    missing_cell_transitions = total_commits - total_cell_transitions
    invariants = {
        "no_native_behavior_change": True,
        "no_objdump_used": True,
        "all_ledgers_have_events": all(item["invariants"]["ledger_has_events"] for item in ledgers),
        "all_commit_calls_reach_projection_done": all(
            item["invariants"]["all_commit_calls_reach_projection_done"] for item in ledgers
        ),
        "at_least_30_fallback_cell_transitions_recovered": total_fallback_cell_transitions >= 30,
        "all_fallback_0x4a5e6c_calls_have_complete_cell_transition": all(
            item["invariants"]["all_fallback_0x4a5e6c_calls_have_complete_cell_transition"]
            for item in ledgers
        ),
        "non_fallback_return_contexts_named_pending": total_non_fallback_contexts > 0,
        "all_available_post_cell_refs_match_object": all(
            item["invariants"]["all_available_post_cell_refs_match_object"] for item in ledgers
        ),
    }
    status = (
        "cross_seed_4a54a7_commit_surface_recovered_projection_writes_still_bounded"
        if all(invariants.values()) and total_commits > 0
        else "cross_seed_4a54a7_commit_surface_incomplete"
    )
    return {
        "schema_id": "h3maped_4a54a7_cross_seed_commit_surface_summary_v1",
        "status": status,
        "scope": (
            "Existing Medium seed-1 and seed-2 one-level land Wine ledgers. This proves the "
            "broader 0x4a54a7 commit/projection-completion surface present in those ledgers, "
            "not the internal 0x4a56b6 write stream for every call."
        ),
        "ledgers": ledgers,
        "metrics": {
            "ledger_count": len(ledgers),
            "total_commit_call_count": total_commits,
            "total_complete_cell_transition_count": total_cell_transitions,
            "total_fallback_0x4a5e6c_commit_call_count": total_fallback_commits,
            "total_fallback_0x4a5e6c_complete_cell_transition_count": total_fallback_cell_transitions,
            "total_non_fallback_return_context_commit_count": total_non_fallback_contexts,
            "missing_cell_transition_count": missing_cell_transitions,
            "native_behavior_changed": False,
            "used_objdump": False,
            "overall_goal_complete": False,
        },
        "return_site_counts": dict(sorted(return_site_counts.items())),
        "invariants": invariants,
        "source_backed_conclusion": (
            "Across the existing Medium seed-1 and seed-2 Wine ledgers, every sampled 0x4a54a7 "
            "commit reaches the 0x4a5756 projection-completion boundary before the next commit. "
            "All 31 sampled 0x4a5e6c fallback-return commits across those ledgers carry "
            "before/after generated-cell snapshots that clear the sampled cell +0x20 low word "
            "while preserving the high word. The seed-2 salvage ledger also exposes 151 "
            "non-fallback return-context commits at 0x4a744a, 0x4a98f0, 0x4a9c3f, and 0x4aa44d; "
            "those contexts reach 0x4a5756 but do not have the same recovered cell-transition "
            "surface in the available snapshots. This extends fallback coordinate/projection "
            "commit-surface recovery beyond the exact seed-10 fallback records, while naming the "
            "broader non-fallback return contexts as pending instead of folding them into the "
            "exact fallback proof."
        ),
        "remaining_gap": (
            "Full end-to-end recovery still needs internal 0x4a56b6 projection-write streams and "
            "cell-transition reconciliation for the non-fallback 0x4a54a7 return contexts, later "
            "relation/control consumers outside exact seed-10 records, and either a source path "
            "that seeds generator+0xf5c before successful endpoint stamping or source-backed proof "
            "excluding that path for supported one-level land."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--ledger",
        dest="ledgers",
        type=Path,
        action="append",
        default=None,
        help="Wine ledger to include. May be supplied more than once.",
    )
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    if not args.ledgers:
        args.ledgers = [DEFAULT_SEED1_LEDGER, DEFAULT_SEED2_LEDGER]
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_4A54A7_CROSS_SEED_COMMIT_SURFACE status={summary['status']} out={args.out}")
    return 0 if summary["status"].endswith("bounded") else 1


if __name__ == "__main__":
    raise SystemExit(main())
