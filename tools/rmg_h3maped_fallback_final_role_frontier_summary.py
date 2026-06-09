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
    ".artifacts/rmg_recovery/medium_seed10_4a54a7_descriptor_relation_summary_20260608.json"
)
DEFAULT_PROJECTION_WRITES = Path(
    ".artifacts/rmg_recovery/medium_seed10_4a54a7_projection_write_summary_20260608.json"
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


def fallback_record_summary(
    pointer: str,
    fallback: dict[str, Any],
    state_chain: dict[str, Any] | None,
    afterstate: dict[str, Any] | None,
    descriptor_relation: dict[str, Any] | None,
    projection_write_pointers: set[str],
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
                afterstate.get("target_cell_ref_vector_contains_object")
                if afterstate
                else None
            ),
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
        )
        for pointer, fallback in sorted(fallback_records.items())
    ]

    exact_projection_missing = [
        record["object_record"]
        for record in records
        if not record["exact_evidence"]["exact_projection_write_stream_recovered"]
    ]
    non_exact_projection_targets = [
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
        "exact_coordinates_match_for_all_fallback_records": all(
            record["coordinates"]["all_exact_coordinates_match"] for record in records
        ),
        "exact_commit_frontier_recovered_for_all_fallback_records": all(
            record["exact_evidence"]["state_chain_recovered"]
            and record["exact_evidence"]["afterstate_recovered"]
            and record["coordinates"]["all_exact_coordinates_match"]
            for record in records
        ),
        "exact_projection_write_stream_missing_for_fallback_records": bool(exact_projection_missing),
        "older_projection_targets_are_not_exact_fallback_records": not (
            set(fallback_records) & projection_pointers
        ),
    }

    status = (
        "fallback_final_role_frontier_exact_commit_recovered_descriptor_relation_and_later_consumer_missing"
        if all(
            invariants[key]
            for key in (
                "two_fallback_records_identified",
                "fallback_records_constructed_after_payload",
                "fallback_records_absent_from_sampled_payload",
                "exact_state_chain_recovered_for_all_fallback_records",
                "exact_afterstate_recovered_for_all_fallback_records",
                "exact_coordinates_match_for_all_fallback_records",
                "exact_commit_frontier_recovered_for_all_fallback_records",
                "older_projection_targets_are_not_exact_fallback_records",
            )
        )
        and invariants["exact_projection_write_stream_missing_for_fallback_records"]
        else "fallback_final_role_frontier_partial"
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
        },
        "records": records,
        "non_exact_projection_write_targets": non_exact_projection_targets,
        "invariants": invariants,
        "source_backed_conclusion": (
            "For the two exact deterministic Medium seed-10 post-Border-Guard fallback records, construction, "
            "immediate 0x4a5c07 state chain, and 0x4a54a7 object-vector/cell adoption are recovered. "
            "The sampled 0x4a79a3 payload pass is earlier and does not consume these records. "
            "The older projection-write streams are useful 0x4a54a7 write-set evidence, but they are not exact evidence "
            "for these two fallback records because their object pointers/coordinates differ and those traces have no "
            "seed-control metadata."
        ),
        "remaining_gap": (
            "The exact fallback records still need descriptor/relation-counter replay, either a later-consumer trace "
            "after their 0x4a54a7 commit or a static phase-order proof that committed object-vector/cell adoption is "
            "their terminal role for this phase. If exact per-record projection-loop parity is required, capture a clean "
            "seed-pinned projection-write stream for 0x036260c0 and 0x03626060 specifically. Continue the 0x4a696b "
            "direct-mutation and 0x4add76 cleanup runtime blockers before any native RMG behavior port."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fallback-payload", type=Path, default=DEFAULT_FALLBACK_PAYLOAD)
    parser.add_argument("--state-chain", type=Path, default=DEFAULT_STATE_CHAIN)
    parser.add_argument("--afterstate", type=Path, default=DEFAULT_AFTERSTATE)
    parser.add_argument("--descriptor-relation", type=Path, default=DEFAULT_DESCRIPTOR_RELATION)
    parser.add_argument("--projection-writes", type=Path, default=DEFAULT_PROJECTION_WRITES)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_FALLBACK_FINAL_ROLE_FRONTIER_SUMMARY status={summary['status']} out={args.out}")
    return 0 if summary["status"].startswith("fallback_final_role_frontier_exact_commit_recovered") else 1


if __name__ == "__main__":
    raise SystemExit(main())
