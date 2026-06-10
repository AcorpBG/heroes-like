#!/usr/bin/env python3
"""Summarize the owner chain for non-self H3MapEd cursor writers.

This checkpoint connects the recovered generator ``+0xf5c`` writer surface to
the projection-slot target-mode exclusion. It is recovery evidence only: it
does not prove global unreachable behavior and does not authorize native RMG
behavior changes.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_CURSOR_ACCESS = DEFAULT_ROOT / "cursor_f5c_1104_access_summary_20260608.json"
DEFAULT_CLEANUP_STATIC = DEFAULT_ROOT / "cleanup_static_ownership_summary_20260610.json"
DEFAULT_PROJECTION_SLOT = (
    DEFAULT_ROOT / "projection_slot_target_mode_reachability_summary_20260610.json"
)
DEFAULT_4A5E73 = DEFAULT_ROOT / "4a5e73_cursor_frontier_summary_20260610.json"
DEFAULT_OUT = DEFAULT_ROOT / "cursor_writer_owner_exclusion_summary_20260610.json"

EXPECTED_CURSOR_WRITERS = {"004a5e73", "004adb72", "004add76"}
NON_SELF_CURSOR_WRITERS = {"004adb72", "004add76"}


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def bool_invariant(summary: dict[str, Any], key: str) -> bool:
    return summary.get("invariants", {}).get(key) is True


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    cursor = load_json(args.cursor_access)
    cleanup_static = load_json(args.cleanup_static)
    projection_slot = load_json(args.projection_slot)
    four_a5e73 = load_json(args.four_a5e73)

    writer_entries = set(cursor.get("cursor_f5c_writer_entries", []))
    non_self_writer_rows = [
        row
        for row in cursor.get("cursor_f5c_writer_rows", [])
        if row.get("entry") in NON_SELF_CURSOR_WRITERS
    ]
    projection_metrics = projection_slot.get("metrics", {})

    invariants = {
        "no_native_behavior_change": (
            bool_invariant(cursor, "native_behavior_changed") is False
            and bool_invariant(cleanup_static, "no_native_behavior_change")
            and bool_invariant(projection_slot, "no_native_behavior_change")
            and bool_invariant(four_a5e73, "no_native_behavior_change")
        ),
        "no_objdump_used": (
            bool_invariant(cleanup_static, "no_objdump_used")
            and bool_invariant(projection_slot, "no_objdump_used")
            and bool_invariant(four_a5e73, "no_objdump_used")
        ),
        "cursor_writer_surface_exhausted": (
            cursor.get("status") == "cursor_writer_surface_exhausted_natural_bg_still_unseeded"
            and writer_entries == EXPECTED_CURSOR_WRITERS
            and bool_invariant(cursor, "known_cursor_writers_only")
        ),
        "non_self_cursor_writers_are_projection_chain_entries": (
            {row.get("entry") for row in non_self_writer_rows} == NON_SELF_CURSOR_WRITERS
        ),
        "4adb72_owned_only_by_49c019_projection_slot": (
            cleanup_static.get("status") == "cleanup_static_ownership_chain_recovered_runtime_unhit"
            and bool_invariant(cleanup_static, "4adb72_only_direct_caller_is_49c019")
            and bool_invariant(cleanup_static, "49c019_referenced_only_by_vtable_slot")
        ),
        "4add76_owned_only_by_4adef7_under_projection_slot_chain": (
            bool_invariant(cleanup_static, "4add76_only_direct_caller_is_4adef7")
            and bool_invariant(cleanup_static, "4adef7_direct_callers_are_49c019_and_4ad947")
            and bool_invariant(cleanup_static, "4ad947_only_direct_caller_is_49c0a6")
            and bool_invariant(cleanup_static, "49c0a6_referenced_only_by_vtable_slot")
        ),
        "projection_slot_chain_unhit_in_current_target_corpus": (
            projection_slot.get("status")
            == "projection_slot_target_mode_unreached_recycle_boundary_explained"
            and bool_invariant(projection_slot, "projection_methods_and_cleanup_have_zero_events")
            and projection_metrics.get("cleanup_or_projection_target_event_hits_total") == 0
            and projection_metrics.get("cleanup_or_projection_target_log_hits_total") == 0
        ),
        "4a5e73_self_success_path_unhit": (
            four_a5e73.get("status")
            == "target_mode_4a5e73_cursor_precondition_recovered_success_path_unhit"
            and bool_invariant(four_a5e73, "current_corpus_has_no_5e73_success_path_hit")
        ),
    }

    status = (
        "cursor_writer_owner_frontier_nonself_writers_bound_to_unhit_projection_slots"
        if all(invariants.values())
        else "cursor_writer_owner_frontier_inputs_incomplete"
    )

    return {
        "schema_id": "h3maped_cursor_writer_owner_exclusion_summary_v1",
        "status": status,
        "scope": (
            "Current one-level land target evidence for generator+0xf5c writer ownership. "
            "This narrows the cursor-source blocker; it is not a global proof that projection "
            "slot methods are unused."
        ),
        "inputs": {
            "cursor_access": str(args.cursor_access),
            "cleanup_static": str(args.cleanup_static),
            "projection_slot": str(args.projection_slot),
            "4a5e73_cursor_frontier": str(args.four_a5e73),
        },
        "invariants": invariants,
        "writer_surface": {
            "all_cursor_writer_entries": sorted(writer_entries),
            "self_cursor_writer_entry": "004a5e73",
            "non_self_cursor_writer_entries": sorted(NON_SELF_CURSOR_WRITERS),
            "non_self_cursor_writer_rows": non_self_writer_rows,
        },
        "owner_chain": {
            "004adb72": "only direct caller 0x49c019, referenced only as projection vtable 0x540b00+0x08",
            "004add76": "only direct caller 0x4adef7, reached only from 0x49c019 or 0x4ad947; 0x4ad947 is only below projection vtable 0x540b14+0x08 through 0x49c0a6",
            "current_target_runtime": (
                "current Wine corpus has zero live events/stops at 0x49c019, 0x49c0a6, "
                "0x4ad947, 0x4adb72, 0x4add76, or 0x4adef7"
            ),
        },
        "metrics": {
            "native_behavior_changed": False,
            "used_objdump": False,
            "overall_goal_complete": False,
            "non_self_cursor_writer_row_count": len(non_self_writer_rows),
            "projection_or_cleanup_event_hits_total": projection_metrics.get(
                "cleanup_or_projection_target_event_hits_total"
            ),
            "projection_or_cleanup_log_hits_total": projection_metrics.get(
                "cleanup_or_projection_target_log_hits_total"
            ),
            "runtime_5e73_entry_count": four_a5e73.get("metrics", {}).get(
                "runtime_5e73_entry_count"
            ),
            "runtime_5e73_success_path_event_count": four_a5e73.get("metrics", {}).get(
                "runtime_5e73_success_path_event_count"
            ),
        },
        "source_backed_conclusion": (
            "The direct generator+0xf5c writer surface is exhausted to 0x4a5e73, 0x4adb72, "
            "and 0x4add76. The only non-0x4a5e73 writers are not free-floating source paths: "
            "Ghidra references bind 0x4adb72 to projection slot 0x540b00+0x08 through 0x49c019, "
            "and bind 0x4add76 under 0x4adef7, whose callers are 0x49c019 and 0x4ad947; "
            "0x4ad947 is owned by projection slot 0x540b14+0x08 through 0x49c0a6. Current "
            "one-level land Wine evidence has zero live projection/cleanup slot hits, while "
            "0x4a5e73 entries still never reach the success path."
        ),
        "remaining_gap": (
            "For the current target mode, the remaining cursor-source question is no longer an "
            "unbounded search over all +0xf5c writers. It is either a yet-unrecovered source path "
            "that seeds generator+0xf5c without these non-self writers, a broader mode/source "
            "state that naturally dispatches projection slot +0x08, or a stronger source/data "
            "exclusion proving successful endpoint stamping is irrelevant for supported one-level "
            "land. Do not port native RMG behavior from this checkpoint alone."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cursor-access", type=Path, default=DEFAULT_CURSOR_ACCESS)
    parser.add_argument("--cleanup-static", type=Path, default=DEFAULT_CLEANUP_STATIC)
    parser.add_argument("--projection-slot", type=Path, default=DEFAULT_PROJECTION_SLOT)
    parser.add_argument("--four-a5e73", type=Path, default=DEFAULT_4A5E73)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_CURSOR_WRITER_OWNER_EXCLUSION "
        f"status={summary['status']} "
        f"non_self_rows={summary['metrics']['non_self_cursor_writer_row_count']} "
        f"projection_hits={summary['metrics']['projection_or_cleanup_event_hits_total']} "
        f"out={args.out}"
    )
    return (
        0
        if summary["status"]
        == "cursor_writer_owner_frontier_nonself_writers_bound_to_unhit_projection_slots"
        else 1
    )


if __name__ == "__main__":
    raise SystemExit(main())
