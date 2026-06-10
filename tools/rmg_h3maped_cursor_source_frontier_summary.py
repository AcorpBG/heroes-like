#!/usr/bin/env python3
"""Consolidate the H3MapEd endpoint cursor source frontier.

This is a recovery checkpoint, not a native RMG implementation input. It joins
the Wine runtime lifetime trace, the Ghidra-derived direct access scan, the
0x4a5e73 current-corpus frontier, and the cursor-writer owner exclusion so the
remaining generator+0xf5c blocker is stated in one place.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_LIFETIME = Path(".artifacts/rmg_recovery/medium_cursor_lifetime_summary_20260608.json")
DEFAULT_ACCESS = Path(".artifacts/rmg_recovery/cursor_f5c_1104_access_summary_20260608.json")
DEFAULT_4A5E73 = Path(".artifacts/rmg_recovery/4a5e73_cursor_frontier_summary_20260610.json")
DEFAULT_CURSOR_OWNER = Path(
    ".artifacts/rmg_recovery/cursor_writer_owner_exclusion_summary_20260610.json"
)
DEFAULT_ENDPOINT_ACCESS = Path(
    ".artifacts/rmg_recovery/endpoint_cursor_state_access_summary_20260610.json"
)
DEFAULT_PROJECTION_SLOT_TARGET = Path(
    ".artifacts/rmg_recovery/projection_slot_target_mode_reachability_summary_20260610.json"
)
DEFAULT_4A606B = Path(".artifacts/rmg_recovery/4a606b_reachability_summary_20260610.json")
DEFAULT_OUT = Path(".artifacts/rmg_recovery/cursor_source_frontier_summary_20260610.json")

EXPECTED_WRITERS = ["004a5e73", "004adb72", "004add76"]


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def all_true(mapping: dict[str, Any], keys: list[str]) -> bool:
    return all(mapping.get(key) is True for key in keys)


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    lifetime = load_json(args.lifetime)
    access = load_json(args.access)
    four_a5e73 = load_json(args.four_a5e73)
    cursor_owner = load_json(args.cursor_owner)
    endpoint_access = load_json(args.endpoint_access)
    projection_slot_target = load_json(args.projection_slot_target)
    four_a606b = load_json(args.four_a606b)

    lifetime_invariants = lifetime.get("invariants", {})
    access_invariants = access.get("invariants", {})
    four_a5e73_invariants = four_a5e73.get("invariants", {})
    cursor_owner_invariants = cursor_owner.get("invariants", {})
    endpoint_access_invariants = endpoint_access.get("invariants", {})
    projection_slot_invariants = projection_slot_target.get("invariants", {})
    four_a606b_invariants = four_a606b.get("invariants", {})

    first_4a61bc = lifetime.get("setup_snapshots", {}).get("at_first_0x4a61bc", {})
    first_failure = lifetime.get("natural_border_guard_first_failure", {})
    writer_entries = access.get("cursor_f5c_writer_entries", [])

    invariants = {
        "no_native_behavior_change": (
            lifetime_invariants.get("native_behavior_changed") is False
            and access_invariants.get("native_behavior_changed") is False
            and four_a5e73_invariants.get("no_native_behavior_change") is True
            and cursor_owner_invariants.get("no_native_behavior_change") is True
            and endpoint_access_invariants.get("no_native_behavior_change") is True
            and four_a606b_invariants.get("no_native_behavior_change") is True
        ),
        "no_objdump_used": True,
        "setup_initializes_f58_not_f5c": (
            lifetime.get("status") == "cursor_lifetime_f58_zero_f5c_unseeded"
            and all_true(
                lifetime_invariants,
                [
                    "static_setup_writes_f58_not_f5c",
                    "f58_is_zero_after_49ee6b_through_first_relation_pass",
                    "f5c_remains_stale_through_setup_and_first_relation_pass",
                ],
            )
        ),
        "byte_state_vector_initialized_without_f5c_seed": lifetime_invariants.get(
            "49f95a_allocates_byte_state_without_changing_f5c"
        )
        is True,
        "first_border_guard_failure_uses_stale_non_key_cursor": (
            lifetime_invariants.get("natural_border_guard_failure_uses_same_stale_f5c")
            is True
            and lifetime_invariants.get("natural_border_guard_d8_keys_are_compact_zero_to_seven")
            is True
            and lifetime_invariants.get("stale_f5c_is_not_an_active_endpoint_key") is True
        ),
        "direct_f5c_writer_surface_exhausted": (
            access.get("status") == "cursor_writer_surface_exhausted_natural_bg_still_unseeded"
            and writer_entries == EXPECTED_WRITERS
            and access_invariants.get("known_cursor_writers_only") is True
            and access_invariants.get("cursor_writer_entries_match_expected") is True
            and access_invariants.get("direct_1104_initializer_surface_seen") is True
        ),
        "widened_ghidra_endpoint_access_confirms_f5c_writer_surface": (
            endpoint_access.get("status")
            == "endpoint_cursor_state_access_surface_recovered_f5c_writers_bounded"
            and endpoint_access_invariants.get("f5c_writer_entries_match_expected") is True
            and endpoint_access_invariants.get("prior_narrow_scan_f5c_writers_match_widened_scan")
            is True
            and endpoint_access_invariants.get("f58_only_direct_write_is_setup_path") is True
            and endpoint_access_invariants.get("byte_state_entries_match_endpoint_helpers") is True
        ),
        "current_4a5e73_success_path_unhit": (
            four_a5e73.get("status")
            == "target_mode_4a5e73_cursor_precondition_recovered_success_path_unhit"
            and four_a5e73_invariants.get("static_contract_recovered") is True
            and four_a5e73_invariants.get("current_corpus_has_no_5e73_success_path_hit") is True
        ),
        "non_self_f5c_writers_bound_to_unhit_projection_chain": (
            cursor_owner.get("status")
            == "cursor_writer_owner_frontier_nonself_writers_bound_to_unhit_projection_slots"
            and cursor_owner_invariants.get("non_self_cursor_writers_are_projection_chain_entries")
            is True
            and cursor_owner_invariants.get("projection_slot_chain_unhit_in_current_target_corpus")
            is True
        ),
        "sampled_projection_slot_recycle_boundary_recovered": (
            projection_slot_target.get("status")
            == "projection_slot_target_mode_unreached_recycle_boundary_explained"
            and projection_slot_invariants.get("projection_slot_static_contract_recovered") is True
            and projection_slot_invariants.get("projection_methods_and_cleanup_have_zero_events")
            is True
            and projection_slot_invariants.get("sampled_projection_to_ordinary_reuse_recovered")
            is True
            and projection_slot_invariants.get("sampled_projection_destructor_contract_recovered")
            is True
        ),
        "current_4a606b_no_live_hit_depends_on_4a5e73_failure": (
            four_a606b.get("status") == "target_mode_4a606b_static_contract_recovered_no_live_hit"
            and four_a606b_invariants.get("current_corpus_has_no_live_4a606b_hit") is True
            and four_a606b_invariants.get("natural_seed10_reaches_branch_but_not_4a606b") is True
        ),
    }

    status = (
        "cursor_source_frontier_setup_and_writer_surface_recovered_success_path_still_unrecovered"
        if all(invariants.values())
        else "cursor_source_frontier_inputs_incomplete"
    )

    return {
        "schema_id": "h3maped_cursor_source_frontier_summary_v1",
        "status": status,
        "scope": (
            "Current one-level land recovery frontier for generator+0xf5c endpoint cursor source. "
            "This records proven setup/writer facts and intentionally does not claim global "
            "endpoint-stamping recovery."
        ),
        "inputs": {
            "cursor_lifetime": str(args.lifetime),
            "cursor_f5c_1104_access": str(args.access),
            "4a5e73_cursor_frontier": str(args.four_a5e73),
            "cursor_writer_owner_frontier": str(args.cursor_owner),
            "endpoint_cursor_state_access": str(args.endpoint_access),
            "projection_slot_target_mode": str(args.projection_slot_target),
            "4a606b_reachability": str(args.four_a606b),
        },
        "invariants": invariants,
        "metrics": {
            "native_behavior_changed": False,
            "used_objdump": False,
            "overall_goal_complete": False,
            "direct_f5c_writer_entry_count": len(writer_entries),
            "widened_endpoint_access_row_count": endpoint_access.get("metrics", {}).get(
                "row_count"
            ),
            "widened_endpoint_f5c_writer_row_count": endpoint_access.get("metrics", {}).get(
                "f5c_writer_row_count"
            ),
            "runtime_5e73_entry_count": four_a5e73.get("metrics", {}).get(
                "runtime_5e73_entry_count"
            ),
            "runtime_5e73_success_path_event_count": four_a5e73.get("metrics", {}).get(
                "runtime_5e73_success_path_event_count"
            ),
            "runtime_4a606b_event_count": four_a606b.get("metrics", {}).get(
                "runtime_4a606b_event_count"
            ),
            "projection_or_cleanup_target_event_hits_total": projection_slot_target.get(
                "metrics", {}
            ).get("cleanup_or_projection_target_event_hits_total"),
            "projection_or_cleanup_target_log_hits_total": projection_slot_target.get(
                "metrics", {}
            ).get("cleanup_or_projection_target_log_hits_total"),
        },
        "proven_cursor_state": {
            "generator_at_first_4a61bc": first_4a61bc.get("generator"),
            "f58_at_first_4a61bc": first_4a61bc.get("f58_words", [None])[0],
            "f5c_at_first_4a61bc": first_4a61bc.get("f58_words", [None, None])[1],
            "state_1104_begin_at_first_4a61bc": first_4a61bc.get("state_1104_begin"),
            "state_1108_end_at_first_4a61bc": first_4a61bc.get("state_1108_end"),
            "first_border_guard_callsite": first_failure.get("callsite"),
            "first_border_guard_cursor": first_failure.get("cursor_plus_f5c"),
            "first_border_guard_active_d8_keys": first_failure.get("d8_keys_plus_20"),
            "widened_ghidra_f5c_writer_entries": endpoint_access.get(
                "offset_entry_matrix", {}
            ).get("0xf5c"),
        },
        "direct_cursor_writer_surface": {
            "writer_entries": writer_entries,
            "non_self_writers": ["004adb72", "004add76"],
            "owner_frontier": (
                "0x4adb72 and 0x4add76 are owned by projection/cleanup slot chains that have "
                "zero live dispatch in the current one-level land corpus."
            ),
            "selected_projection_recycle_boundary": (
                "Sampled 0x540b14 projection objects are destroyed through selected-object "
                "slot0 destructors, freed, and later reused by ordinary constructors before "
                "final slot +0x08 dispatch."
            ),
        },
        "current_human_readable_conclusion": (
            "The setup path seen in the current Medium seed-10 trace creates the endpoint "
            "byte-state vector and zeroes generator+0xf58, but it does not seed "
            "generator+0xf5c. The first natural Border Guard endpoint attempt therefore enters "
            "0x4a5e73 with stale cursor 0x7a1befdf while the active endpoint keys are 0..7. "
            "The direct +0xf5c writer surface is bounded to 0x4a5e73 plus two non-self writers "
            "owned by currently unhit projection/cleanup slot paths, and the widened Ghidra "
            "endpoint-state access scan found no additional direct +0xf5c writer. The sampled projection "
            "objects for that chain are destroyed/freed/reused before final dispatch in the "
            "recovered one-level path, so this is not an unknown mutator anymore. The current "
            "corpus still has no successful 0x4a5e73 mutation and no live 0x4a606b "
            "endpoint-region write."
        ),
        "remaining_gap": (
            "Recover either a source path that seeds generator+0xf5c outside the currently "
            "excluded non-self writer chain before successful endpoint stamping, a broader "
            "supported map/source state that naturally dispatches the projection/cleanup slot "
            "chain before selected-object recycle, or source-backed proof that successful "
            "0x4a5e73/0x4a606b endpoint stamping is irrelevant for supported one-level land. "
            "Do not port, tune, density-scale, or brute-force native RMG behavior from this "
            "checkpoint."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lifetime", type=Path, default=DEFAULT_LIFETIME)
    parser.add_argument("--access", type=Path, default=DEFAULT_ACCESS)
    parser.add_argument("--four-a5e73", type=Path, default=DEFAULT_4A5E73)
    parser.add_argument("--cursor-owner", type=Path, default=DEFAULT_CURSOR_OWNER)
    parser.add_argument("--endpoint-access", type=Path, default=DEFAULT_ENDPOINT_ACCESS)
    parser.add_argument("--projection-slot-target", type=Path, default=DEFAULT_PROJECTION_SLOT_TARGET)
    parser.add_argument("--four-a606b", type=Path, default=DEFAULT_4A606B)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_CURSOR_SOURCE_FRONTIER status={summary['status']} out={args.out}")
    return (
        0
        if summary["status"]
        == "cursor_source_frontier_setup_and_writer_surface_recovered_success_path_still_unrecovered"
        else 1
    )


if __name__ == "__main__":
    raise SystemExit(main())
