#!/usr/bin/env python3
"""Verify the exact Medium seed-10 Border Guard downstream chain.

This is a source-recovery checkpoint only. It consumes existing Wine/Ghidra/Python
summaries and proves what is recovered for the deterministic one-level land
Border Guard sequence:

- relation/control byte +0x09 is the template Border Guard flag;
- the natural +0x09 branch reaches 0x4a5e73 and fails on stale +0xf5c;
- H3MapEd falls through to two 0x4a7605 -> 0x4a5e03 materializations;
- those exact fallback records delegate to 0x4a54a7, are absent from the prior
  0x4a79a3 payload, and survive through the recovered phase tail.

It does not change native RMG behavior and does not claim global map-mode
coverage.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_CONNECTION_FIELDS = Path(".artifacts/rmg_recovery/connection_record_field_summary.json")
DEFAULT_NATURAL_BG = Path(
    ".artifacts/rmg_recovery/medium_seed10_hc1_co1_border_guard_seed_pinned_summary_20260609.json"
)
DEFAULT_BG_FOLLOWTHROUGH = Path(
    ".artifacts/rmg_recovery/medium_seed10_hc1_co1_border_guard_followthrough_seed_pinned_summary_20260609.json"
)
DEFAULT_PAYLOAD_LINK = Path(
    ".artifacts/rmg_recovery/medium_seed10_hc1_co1_fallback_payload_link_summary_20260609.json"
)
DEFAULT_4A5E03_SIDE_EFFECT = Path(
    ".artifacts/rmg_recovery/medium_seed10_4a5e03_side_effect_summary_20260608.json"
)
DEFAULT_FINAL_ROLE_FRONTIER = Path(
    ".artifacts/rmg_recovery/medium_seed10_fallback_final_role_frontier_summary_20260609.json"
)
DEFAULT_FINAL_ROLE_COMPLETION = Path(
    ".artifacts/rmg_recovery/medium_seed10_fallback_final_role_completion_summary_20260610.json"
)
DEFAULT_OUT = Path(
    ".artifacts/rmg_recovery/border_guard_downstream_chain_summary_20260610.json"
)

EXPECTED_FALLBACK_RECORDS = {"0x036260c0", "0x03626060"}


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def object_records_from_4a5e03(summary: dict[str, Any]) -> set[str]:
    records: set[str] = set()
    for sequence in summary.get("target_sequences", []):
        record = sequence.get("constructed_object_record", {}).get("object_record_pointer")
        if record:
            records.add(str(record).lower())
    return records


def object_records_from_payload_link(summary: dict[str, Any], key: str) -> set[str]:
    records: set[str] = set()
    for record in summary.get(key, []):
        pointer = record.get("object_record")
        if pointer:
            records.add(str(pointer).lower())
    return records


def object_records_from_final_frontier(summary: dict[str, Any]) -> set[str]:
    records: set[str] = set()
    for record in summary.get("records", []):
        pointer = record.get("object_record")
        if pointer:
            records.add(str(pointer).lower())
    return records


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    connection = load_json(args.connection_fields)
    natural_bg = load_json(args.natural_bg)
    bg_followthrough = load_json(args.bg_followthrough)
    payload_link = load_json(args.payload_link)
    side_effect = load_json(args.side_effect)
    final_frontier = load_json(args.final_role_frontier)
    final_completion = load_json(args.final_role_completion)

    expected_records = {record.lower() for record in EXPECTED_FALLBACK_RECORDS}
    payload_fallback_records = object_records_from_payload_link(
        payload_link, "post_border_guard_fallback_records"
    )
    payload_pre_bg_records = object_records_from_payload_link(payload_link, "pre_border_guard_records")
    side_effect_records = object_records_from_4a5e03(side_effect)
    final_records = object_records_from_final_frontier(final_frontier)

    connection_plus9 = connection.get("recovered_fields", {}).get("+0x09", {})
    natural_invariants = natural_bg.get("invariants", {})
    follow_invariants = bg_followthrough.get("invariants", {})
    payload_invariants = payload_link.get("invariants", {})
    side_invariants = side_effect.get("invariants", {})
    final_frontier_invariants = final_frontier.get("invariants", {})
    final_completion_invariants = final_completion.get("invariants", {})

    invariants = {
        "no_native_behavior_change": (
            connection.get("invariants", {}).get("no_native_behavior_change") is True
            and natural_invariants.get("native_behavior_changed") is False
            and follow_invariants.get("native_behavior_changed") is False
            and payload_link.get("native_behavior_changed") is False
            and side_invariants.get("native_behavior_changed") is False
            and final_frontier_invariants.get("native_behavior_changed") is False
            and final_completion_invariants.get("no_native_behavior_change") is True
        ),
        "no_objdump_used": final_completion_invariants.get("no_objdump_used") is True,
        "plus09_border_guard_source_recovered": (
            connection.get("status") == "recovered_connection_record_plus9_border_guard_surface"
            and connection_plus9.get("source_producer", {}).get("function") == "0x49f7c4"
            and connection_plus9.get("source_producer", {}).get("source_row_name")
            == "Border Guard"
        ),
        "natural_border_guard_branch_recovered": (
            natural_bg.get("status")
            == "natural_border_guard_branch_reaches_5e73_but_cursor_unseeded"
            and natural_invariants.get("natural_border_guard_branch_observed") is True
            and natural_invariants.get("all_4a5e73_entries_failed_at_4a5f84") is True
            and natural_invariants.get("generated_cell_mutation_not_reached") is True
        ),
        "followthrough_reaches_fallback_materialization": (
            bg_followthrough.get("status")
            == "border_guard_endpoint_failures_followed_by_7605_5e03_materialization"
            and follow_invariants.get("three_natural_border_guard_endpoint_pairs_observed") is True
            and follow_invariants.get("six_4a5e73_calls_observed") is True
            and follow_invariants.get("post_border_guard_7605_4a5e03_calls_observed") is True
        ),
        "payload_ordering_recovered": (
            payload_link.get("status")
            == "fallback_records_constructed_after_payload_not_consumed_by_sampled_4a79a3"
            and payload_invariants.get("pre_border_guard_records_present_in_sampled_payload") is True
            and payload_invariants.get("fallback_records_absent_from_sampled_payload") is True
            and payload_invariants.get("fallback_constructed_after_payload_loop") is True
        ),
        "fallback_record_identity_matches_across_payload_and_4a5e03": (
            payload_fallback_records == expected_records
            and side_effect_records == expected_records
        ),
        "fallback_4a5e03_delegates_to_4a54a7": (
            side_effect.get("status")
            == "post_border_guard_4a5e03_delegates_to_4a54a7_commit_replay_pending"
            and side_invariants.get("two_post_border_guard_7605_4a5e03_calls_observed") is True
            and side_invariants.get("object_record_pointer_passed_to_vtable_commit") is True
            and side_invariants.get("entry_coordinate_passed_to_vtable_commit") is True
            and side_invariants.get("vtable_slot_plus_0x04_resolves_to_0x4a54a7") is True
        ),
        "exact_fallback_final_role_recovered": (
            final_frontier.get("status")
            == "fallback_final_role_frontier_exact_projection_descriptor_relation_49eb8d_recovered_downstream_missing"
            and final_completion.get("status")
            == "fallback_final_role_phase_tail_recovered_for_exact_seed10_records"
            and final_records == expected_records
            and final_frontier_invariants.get("exact_state_chain_recovered_for_all_fallback_records")
            is True
            and final_frontier_invariants.get("exact_projection_write_stream_recovered_for_all_fallback_records")
            is True
            and final_frontier_invariants.get("fallback_records_survive_to_49eb8d_object_vector")
            is True
            and final_completion_invariants.get("post_49eb8d_4ac552_phase_tail_recovered") is True
            and final_completion_invariants.get("first_49e700_mutation_write_set_recovered") is True
        ),
    }

    status = (
        "exact_seed10_border_guard_downstream_chain_recovered_broader_linkage_pending"
        if all(invariants.values())
        else "border_guard_downstream_chain_inputs_incomplete"
    )

    return {
        "schema_id": "h3maped_border_guard_downstream_chain_summary_v1",
        "status": status,
        "scope": (
            "Exact deterministic Medium seed-10 one-level/no-water Border Guard downstream chain. "
            "This is not global RMG parity and not authority to edit native behavior."
        ),
        "inputs": {
            "connection_fields": str(args.connection_fields),
            "natural_bg": str(args.natural_bg),
            "bg_followthrough": str(args.bg_followthrough),
            "payload_link": str(args.payload_link),
            "side_effect": str(args.side_effect),
            "final_role_frontier": str(args.final_role_frontier),
            "final_role_completion": str(args.final_role_completion),
        },
        "invariants": invariants,
        "metrics": {
            "native_behavior_changed": False,
            "used_objdump": False,
            "overall_goal_complete": False,
            "expected_fallback_record_count": len(expected_records),
            "payload_fallback_record_count": len(payload_fallback_records),
            "side_effect_record_count": len(side_effect_records),
            "final_record_count": len(final_records),
            "pre_border_guard_payload_record_count": len(payload_pre_bg_records),
        },
        "exact_chain": [
            {
                "step": "plus09_source",
                "result": (
                    "relation/control byte +0x09 is the template connection Border Guard "
                    "flag produced by 0x49f7c4 from source row +0x140"
                ),
            },
            {
                "step": "natural_branch",
                "result": (
                    "clean seed-10 Medium run naturally reaches three Border Guard endpoint "
                    "pairs; all six 0x4a5e73 calls fail at 0x4a5f84 on stale generator+0xf5c"
                ),
            },
            {
                "step": "fallback_materialization",
                "result": (
                    "after the endpoint misses, two 0x4a7605 -> 0x4a5e03 fallback records "
                    "are constructed: 0x036260c0 and 0x03626060"
                ),
            },
            {
                "step": "payload_order",
                "result": (
                    "the sampled 0x4a79a3 payload consumes the two pre-Border-Guard records; "
                    "the two fallback records are constructed after that payload loop and are "
                    "absent from the sampled payload"
                ),
            },
            {
                "step": "commit_and_tail",
                "result": (
                    "the two fallback records delegate to 0x4a54a7, have exact descriptor/"
                    "relation/projection write streams, survive through 0x49eb8d, and reach "
                    "the recovered 0x4ac552 phase tail"
                ),
            },
        ],
        "recovered_record_sets": {
            "expected_fallback_records": sorted(expected_records),
            "payload_link_fallback_records": sorted(payload_fallback_records),
            "side_effect_records": sorted(side_effect_records),
            "final_role_records": sorted(final_records),
            "pre_border_guard_payload_records": sorted(payload_pre_bg_records),
        },
        "source_backed_conclusion": (
            "For exact Medium seed-10 one-level/no-water generation, the natural Border Guard "
            "+0x09 path is no longer blocked at an unknown producer or unknown immediate "
            "fallthrough. It is recovered through stale-cursor 0x4a5e73 misses, fallback "
            "0x4a7605 -> 0x4a5e03 object construction, 0x4a54a7 commit/projection state, "
            "object-vector survival, first 0x49e700 mutation set, and the 0x4ac552 phase tail "
            "for records 0x036260c0 and 0x03626060."
        ),
        "remaining_gap": (
            "This closes the sampled seed-10 Border Guard downstream chain only. Remaining "
            "work before native RMG behavior changes: broaden relation/control linkage beyond "
            "these exact records, use the recovered 0x4a606b static/current-corpus frontier to "
            "find a natural successful endpoint-stamping path or source-backed exclusion for "
            "supported one-level land, name global descriptor/object families, continue "
            "0x4a696b reachability outside the current target evidence, and recover cleanup/"
            "uncommit runtime state if reached."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--connection-fields", type=Path, default=DEFAULT_CONNECTION_FIELDS)
    parser.add_argument("--natural-bg", type=Path, default=DEFAULT_NATURAL_BG)
    parser.add_argument("--bg-followthrough", type=Path, default=DEFAULT_BG_FOLLOWTHROUGH)
    parser.add_argument("--payload-link", type=Path, default=DEFAULT_PAYLOAD_LINK)
    parser.add_argument("--side-effect", type=Path, default=DEFAULT_4A5E03_SIDE_EFFECT)
    parser.add_argument("--final-role-frontier", type=Path, default=DEFAULT_FINAL_ROLE_FRONTIER)
    parser.add_argument("--final-role-completion", type=Path, default=DEFAULT_FINAL_ROLE_COMPLETION)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_BORDER_GUARD_DOWNSTREAM_CHAIN status={summary['status']} out={args.out}")
    return (
        0
        if summary["status"]
        == "exact_seed10_border_guard_downstream_chain_recovered_broader_linkage_pending"
        else 1
    )


if __name__ == "__main__":
    raise SystemExit(main())
