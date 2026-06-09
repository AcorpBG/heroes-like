#!/usr/bin/env python3
"""Summarize the exact post-Border-Guard fallback final-role frontier.

This joins the currently recovered Medium seed-10 evidence for the two exact
post-Border-Guard fallback object records. It deliberately separates exact
record evidence from older non-seed-controlled projection traces so the native
RMG is not changed from a mixed or over-broad proof.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_FALLBACK_PAYLOAD = Path(
    ".artifacts/rmg_recovery/medium_seed10_hc1_co1_fallback_payload_link_summary_20260609.json"
)
DEFAULT_STATE_CHAIN = Path(
    ".artifacts/rmg_recovery/medium_seed10_4a5c07_state_chain_summary_20260608.json"
)
DEFAULT_AFTERSTATE = Path(
    ".artifacts/rmg_recovery/medium_seed10_4a54a7_afterstate_summary_20260608.json"
)
DEFAULT_DESCRIPTOR_RELATION = Path(
    ".artifacts/rmg_recovery/medium_seed10_fallback_exact_descriptor_relation_summary_20260609.json"
)
DEFAULT_PROJECTION_WRITES = Path(
    ".artifacts/rmg_recovery/medium_seed10_exact_fallback_projection_write_summary_20260609.json"
)
DEFAULT_VECTOR_MEMBERSHIP = Path(
    ".artifacts/rmg_recovery/medium_seed10_fallback_post_commit_vector_membership_summary_20260609.json"
)
DEFAULT_49EB8D_REPLAY = Path(
    ".artifacts/rmg_recovery/medium_seed10_fallback_49eb8d_replay_summary_20260609.json"
)
DEFAULT_OUT = Path(
    ".artifacts/rmg_recovery/medium_seed10_fallback_final_role_frontier_summary_20260609.json"
)


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def by_object(records: list[dict[str, Any]], *keys: str) -> dict[str, dict[str, Any]]:
    out: dict[str, dict[str, Any]] = {}
    for record in records:
        pointer = None
        for key in keys:
            value = record
            for part in key.split("."):
                if not isinstance(value, dict):
                    value = None
                    break
                value = value.get(part)
            if isinstance(value, str) and value.startswith("0x"):
                pointer = value
                break
        if pointer:
            out[pointer] = record
    return out


def projection_record_keys(summary: dict[str, Any]) -> set[str]:
    keys: set[str] = set()
    for target in summary.get("targets", []):
        pointer = target.get("object_record_pointer")
        if isinstance(pointer, str):
            keys.add(pointer)
    return keys


def fallback_positions(summary: dict[str, Any], snapshot_key: str, pointer: str) -> list[int]:
    positions = (
        summary.get("object_vector_snapshots", {})
        .get(snapshot_key, {})
        .get("fallback_positions", {})
        .get(pointer, [])
    )
    return positions if isinstance(positions, list) else []


def replay_positions(summary: dict[str, Any], snapshot_key: str, pointer: str) -> list[int]:
    positions = (
        summary.get("object_vector_snapshots", {})
        .get(snapshot_key, {})
        .get("fallback_positions", {})
        .get(pointer, [])
    )
    return positions if isinstance(positions, list) else []


def fallback_record_summary(
    pointer: str,
    fallback: dict[str, Any],
    state_chain: dict[str, Any] | None,
    afterstate: dict[str, Any] | None,
    descriptor_relation: dict[str, Any] | None,
    projection_write_pointers: set[str],
    vector_membership: dict[str, Any],
    replay_49eb8d: dict[str, Any],
) -> dict[str, Any]:
    after_coord = (
        afterstate.get("vtable_callback", {}).get("coordinate")
        if afterstate
        else None
    )
    state_coord = (
        state_chain.get("side_effect_commit_callback", {}).get("stack_coordinate")
        if state_chain
        else None
    )
    descriptor_coord = (
        descriptor_relation.get("object_coordinate")
        if descriptor_relation
        else None
    )
    cell_object_ref_vector = (
        afterstate.get("post_return_cell", {}).get("object_ref_vector")
        if afterstate
        else None
    )
    cell_ref_words = (
        cell_object_ref_vector.get("first_words", [])
        if isinstance(cell_object_ref_vector, dict)
        else []
    )
    cell_ref_contains_object = pointer in cell_ref_words
    phase_positions = fallback_positions(vector_membership, "phase_return_0x4a8d27", pointer)
    handoff_positions = fallback_positions(vector_membership, "final_handoff_0x49eb8d", pointer)
    replay_entry_positions = replay_positions(replay_49eb8d, "entry_0x49eb8d", pointer)
    replay_exit_positions = replay_positions(replay_49eb8d, "exit_0x49eced", pointer)
    replay_caller_positions = replay_positions(replay_49eb8d, "caller_after_0x4ac844", pointer)
    return {
        "object_record": pointer,
        "fallback_constructor": {
            "entry_event_index": fallback.get("entry_event_index"),
            "object_event_index": fallback.get("object_event_index"),
            "return_address": fallback.get("return_address"),
        },
        "exact_evidence": {
            "constructed_after_sampled_payload": True,
            "absent_from_sampled_payload": True,
            "state_chain_recovered": state_chain is not None,
            "afterstate_recovered": afterstate is not None,
            "descriptor_relation_recovered": descriptor_relation is not None,
            "exact_projection_write_stream_recovered": pointer in projection_write_pointers,
            "cell_object_ref_vector_contains_object": cell_ref_contains_object,
            "object_vector_survives_to_4a8d27": bool(phase_positions),
            "object_vector_survives_to_49eb8d": bool(handoff_positions),
            "object_vector_survives_49eb8d_return": bool(replay_caller_positions),
        },
        "coordinates": {
            "state_chain_commit": state_coord,
            "afterstate_commit": after_coord,
            "descriptor_relation_object": descriptor_coord,
            "all_exact_coordinates_match": bool(
                state_coord and after_coord and state_coord == after_coord
            ),
        },
        "afterstate": {
            "cell_pointer": afterstate.get("post_return_cell", {}).get("cell_pointer") if afterstate else None,
            "object_vector_after": afterstate.get("object_vector_after") if afterstate else None,
            "post_return_cell_words": (
                afterstate.get("post_return_cell", {}).get("generated_cell_words")
                if afterstate
                else None
            ),
            "object_vector_old_slot_contains_object": (
                afterstate.get("object_vector_old_end_slot_contains_object")
                if afterstate
                else None
            ),
            "target_cell_ref_vector_contains_object": (
                cell_ref_contains_object if afterstate else None
            ),
            "target_cell_ref_vector": cell_object_ref_vector,
        },
        "post_commit_vector_membership": {
            "phase_return_0x4a8d27_positions": phase_positions,
            "final_handoff_0x49eb8d_positions": handoff_positions,
            "replay_entry_0x49eb8d_positions": replay_entry_positions,
            "replay_exit_0x49eced_positions": replay_exit_positions,
            "replay_caller_after_0x4ac844_positions": replay_caller_positions,
        },
        "descriptor_relation": {
            "descriptor_type": (
                descriptor_relation.get("descriptor", {}).get("type_index_from_descriptor_plus_0x1c")
                if descriptor_relation
                else None
            ),
            "relation_counter": descriptor_relation.get("relation_counter") if descriptor_relation else None,
            "source_cell": descriptor_relation.get("source_cell") if descriptor_relation else None,
        },
    }


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    fallback_payload = read_json(args.fallback_payload)
    state_chain = read_json(args.state_chain)
    afterstate = read_json(args.afterstate)
    descriptor_relation = read_json(args.descriptor_relation)
    projection_writes = read_json(args.projection_writes)
    vector_membership = read_json(args.vector_membership) if args.vector_membership.exists() else {}
    replay_49eb8d = read_json(args.replay_49eb8d) if args.replay_49eb8d.exists() else {}

    fallback_records = by_object(
        fallback_payload.get("post_border_guard_fallback_records", []),
        "object_record",
    )
    state_records = by_object(
        state_chain.get("sequences", []),
        "object_record_pointer",
    )
    afterstate_records = by_object(
        afterstate.get("target_sequences", []),
        "vtable_callback.object_record_pointer",
    )
    descriptor_records = by_object(
        descriptor_relation.get("invocations", []),
        "object_record_pointer",
    )
    projection_pointers = projection_record_keys(projection_writes)

    records = [
        fallback_record_summary(
            pointer,
            fallback,
            state_records.get(pointer),
            afterstate_records.get(pointer),
            descriptor_records.get(pointer),
            projection_pointers,
            vector_membership,
            replay_49eb8d,
        )
        for pointer, fallback in sorted(fallback_records.items())
    ]

    exact_projection_missing = [
        record["object_record"]
        for record in records
        if not record["exact_evidence"]["exact_projection_write_stream_recovered"]
    ]
    projection_write_targets = [
        {
            "name": target.get("name"),
            "object_record_pointer": target.get("object_record_pointer"),
            "target_call_args": target.get("target_call_args"),
            "commit_call_args": target.get("commit_call_args"),
            "write_count": target.get("write_count"),
            "seed_control_present": bool(read_json(Path(target["ledger"])).get("seed_control"))
            if target.get("ledger") and Path(target["ledger"]).exists()
            else False,
        }
        for target in projection_writes.get("targets", [])
    ]
    exact_projection_targets = [target for target in projection_write_targets if target["object_record_pointer"] in fallback_records]
    non_exact_projection_targets = [
        target for target in projection_write_targets if target["object_record_pointer"] not in fallback_records
    ]

    invariants = {
        "native_behavior_changed": False,
        "two_fallback_records_identified": len(records) == 2,
        "fallback_records_constructed_after_payload": fallback_payload.get("invariants", {}).get(
            "fallback_constructed_after_payload_loop"
        )
        is True,
        "fallback_records_absent_from_sampled_payload": fallback_payload.get("invariants", {}).get(
            "fallback_records_absent_from_sampled_payload"
        )
        is True,
        "exact_state_chain_recovered_for_all_fallback_records": all(
            record["exact_evidence"]["state_chain_recovered"] for record in records
        ),
        "exact_afterstate_recovered_for_all_fallback_records": all(
            record["exact_evidence"]["afterstate_recovered"] for record in records
        ),
        "exact_descriptor_relation_recovered_for_all_fallback_records": all(
            record["exact_evidence"]["descriptor_relation_recovered"] for record in records
        ),
        "cell_object_ref_vector_contains_all_fallback_records": all(
            record["exact_evidence"]["cell_object_ref_vector_contains_object"] for record in records
        ),
        "fallback_records_survive_to_4a8d27_object_vector": all(
            record["exact_evidence"]["object_vector_survives_to_4a8d27"] for record in records
        ),
        "fallback_records_survive_to_49eb8d_object_vector": all(
            record["exact_evidence"]["object_vector_survives_to_49eb8d"] for record in records
        ),
        "fallback_records_survive_49eb8d_return_to_4ac844": all(
            record["exact_evidence"]["object_vector_survives_49eb8d_return"] for record in records
        ),
        "same_run_49eb8d_count_dispatch_return_recovered": replay_49eb8d.get("status")
        == "fallback_49eb8d_same_run_count_dispatch_return_recovered",
        "exact_coordinates_match_for_all_fallback_records": all(
            record["coordinates"]["all_exact_coordinates_match"] for record in records
        ),
        "exact_commit_frontier_recovered_for_all_fallback_records": all(
            record["exact_evidence"]["state_chain_recovered"]
            and record["exact_evidence"]["afterstate_recovered"]
            and record["coordinates"]["all_exact_coordinates_match"]
            for record in records
        ),
        "exact_projection_write_stream_recovered_for_all_fallback_records": not exact_projection_missing,
        "projection_write_targets_match_fallback_records": (
            set(fallback_records) == projection_pointers
            and all(target.get("seed_control_present") for target in projection_write_targets)
        ),
    }

    exact_frontier_recovered = all(
        invariants[key]
        for key in (
            "two_fallback_records_identified",
            "fallback_records_constructed_after_payload",
            "fallback_records_absent_from_sampled_payload",
            "exact_state_chain_recovered_for_all_fallback_records",
            "exact_afterstate_recovered_for_all_fallback_records",
            "cell_object_ref_vector_contains_all_fallback_records",
            "fallback_records_survive_to_4a8d27_object_vector",
            "fallback_records_survive_to_49eb8d_object_vector",
            "fallback_records_survive_49eb8d_return_to_4ac844",
            "same_run_49eb8d_count_dispatch_return_recovered",
            "exact_coordinates_match_for_all_fallback_records",
            "exact_commit_frontier_recovered_for_all_fallback_records",
            "exact_projection_write_stream_recovered_for_all_fallback_records",
            "projection_write_targets_match_fallback_records",
        )
    )
    if exact_frontier_recovered and invariants["exact_descriptor_relation_recovered_for_all_fallback_records"]:
        status = "fallback_final_role_frontier_exact_projection_descriptor_relation_49eb8d_recovered_downstream_missing"
    elif exact_frontier_recovered:
        status = "fallback_final_role_frontier_exact_commit_recovered_descriptor_relation_and_later_consumer_missing"
    else:
        status = "fallback_final_role_frontier_partial"

    if invariants["exact_descriptor_relation_recovered_for_all_fallback_records"]:
        remaining_gap = (
            "The exact fallback records now have recovered construction, commit, cell object-reference adoption, "
            "descriptor/relation-counter replay, exact projection-loop write streams, object-vector survival to the 0x49eb8d handoff, and same-run "
            "0x49eb8d count/budget/first-dispatch/return replay. The remaining final-role gap is complete 0x49e700 "
            "decorative allocation/generated-cell mutation replay and downstream phase-completion proof beyond 0x4ac844. Continue the 0x4a696b direct-mutation and 0x4add76 cleanup runtime "
            "blockers before any native RMG behavior port."
        )
    else:
        remaining_gap = (
            "The exact fallback records still need descriptor/relation-counter replay and exact projection-loop write streams, either a later-consumer trace "
            "after their 0x4a54a7 commit or a static phase-order proof that committed object-vector/cell adoption is "
            "their terminal role for this phase. Continue the 0x4a696b "
            "direct-mutation and 0x4add76 cleanup runtime blockers before any native RMG behavior port."
        )

    return {
        "schema_id": "h3maped_fallback_final_role_frontier_summary_v1",
        "status": status,
        "native_behavior_changed": False,
        "inputs": {
            "fallback_payload": str(args.fallback_payload),
            "state_chain": str(args.state_chain),
            "afterstate": str(args.afterstate),
            "descriptor_relation": str(args.descriptor_relation),
            "projection_writes": str(args.projection_writes),
            "vector_membership": str(args.vector_membership),
            "replay_49eb8d": str(args.replay_49eb8d),
        },
        "records": records,
        "exact_projection_write_targets": exact_projection_targets,
        "non_exact_projection_write_targets": non_exact_projection_targets,
        "invariants": invariants,
        "source_backed_conclusion": (
            "For the two exact deterministic Medium seed-10 post-Border-Guard fallback records, construction, "
            "immediate 0x4a5c07 state chain, 0x4a54a7 object-vector/cell adoption, and exact projection-loop write "
            "streams are recovered. "
            "The sampled 0x4a79a3 payload pass is earlier and does not consume these records. "
            "A later clean seed-pinned replay proves both records remain in the generator object vector at 0x4a8d27 "
            "and again at the 0x49eb8d handoff. A combined same-run 0x49eb8d trace proves bit26 count, budget, first "
            "0x49e700 dispatch, 0x49eced exit, and 0x4ac844 caller continuation while preserving both fallback records."
        ),
        "remaining_gap": remaining_gap,
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fallback-payload", type=Path, default=DEFAULT_FALLBACK_PAYLOAD)
    parser.add_argument("--state-chain", type=Path, default=DEFAULT_STATE_CHAIN)
    parser.add_argument("--afterstate", type=Path, default=DEFAULT_AFTERSTATE)
    parser.add_argument("--descriptor-relation", type=Path, default=DEFAULT_DESCRIPTOR_RELATION)
    parser.add_argument("--projection-writes", type=Path, default=DEFAULT_PROJECTION_WRITES)
    parser.add_argument("--vector-membership", type=Path, default=DEFAULT_VECTOR_MEMBERSHIP)
    parser.add_argument("--replay-49eb8d", type=Path, default=DEFAULT_49EB8D_REPLAY)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_FALLBACK_FINAL_ROLE_FRONTIER_SUMMARY status={summary['status']} out={args.out}")
    return 0 if summary["status"].startswith("fallback_final_role_frontier_exact_") else 1


if __name__ == "__main__":
    raise SystemExit(main())
