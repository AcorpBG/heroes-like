#!/usr/bin/env python3
"""Crosswalk descriptor +0x00 row/class-word modes to producer contexts.

This is a recovery checkpoint, not a native RMG behavior change. It consumes
existing Wine/Ghidra/Python summaries and names the producer context that owns
each sampled descriptor +0x00 mode. The goal is to keep row-like coincidences
separate from source-backed final object identity.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_DESCRIPTOR_ROW_MODE = ROOT / "descriptor_word_row_mode_summary_20260610.json"
DEFAULT_TYPE98_BRIDGE = ROOT / "descriptor_type98_bridge_summary_20260610.json"
DEFAULT_FALLBACK_RECONCILIATION = ROOT / "coordinate_projection_reconciliation_summary_20260610.json"
DEFAULT_FALLBACK_COMMIT_BOUNDARY = ROOT / "4a61bc_4a5e03_commit_boundary_summary_20260609.json"
DEFAULT_NONFALLBACK_CONTEXT = ROOT / "nonfallback_4a54a7_return_context_summary_20260610.json"
DEFAULT_NONFALLBACK_OWNER = ROOT / "nonfallback_4a54a7_return_owner_summary_20260610.json"
DEFAULT_PRE_4A8DB2 = ROOT / "pre_4a8db2_score_order_summary_20260608.json"
DEFAULT_OUT = ROOT / "descriptor_producer_context_summary_20260610.json"


CONTEXTS: dict[str, dict[str, Any]] = {
    "0x004a5e6c | 54": {
        "producer_context": "fallback_materialization_4a61bc_or_4a7605_through_4a5e03",
        "owner_functions": ["0x4a61bc", "0x4a7605", "0x4a5e03", "0x4a54a7"],
        "human_scope": (
            "Fallback/object materialization commits. Existing evidence proves 0x4a5e03 "
            "passes the constructed record and coordinate to the generator slot +0x04 "
            "callback, and the object-vector append happens inside 0x4a54a7."
        ),
        "evidence_keys": ["fallback_reconciliation", "fallback_commit_boundary"],
        "descriptor_identity_authority": "mixed_descriptor_word_mode_not_final_identity",
        "remaining_blocker": (
            "Recover the descriptor/record constructor assignment that sets descriptor+0x00 "
            "for the mixed type-54 fallback lane before using that word as a final row id."
        ),
    },
    "0x004a744a | 45": {
        "producer_context": "sampled_direct_endpoint_nonfallback_return",
        "owner_functions": ["0x4a54a7", "0x4a744a"],
        "human_scope": (
            "Sampled direct endpoint/non-fallback return-site contract. Existing evidence "
            "proves object-vector append, target generated-cell object reference, low-word "
            "clear, +0x28 occupied update, source-coordinate match, and relation-counter "
            "increment for sampled 0x4a744a invocations."
        ),
        "evidence_keys": ["fallback_reconciliation", "nonfallback_context"],
        "descriptor_identity_authority": "class_word_not_catalog_row_in_current_samples",
        "remaining_blocker": (
            "Recover the producer/constructor path that writes descriptor+0x00=1145 for "
            "descriptor type 45; the same zero-based row rule maps 1145 to Cartographer, "
            "so it cannot be treated as the Monolith Two Way catalog row."
        ),
    },
    "0x004a9586 | 98": {
        "producer_context": "pre_scheduler_projection_and_weighted_type98_commit_lane",
        "owner_functions": ["0x4a901a", "0x4a54a7", "0x4a9586"],
        "human_scope": (
            "Sampled type-98 projection/weighted lane. Exact descriptor/relation samples "
            "and weighted materialization summaries agree that descriptor+0x1c/counter "
            "index 98 is active, increments generator+0x1110[98], and returns through "
            "0x4a54a7 before 0x4a9586."
        ),
        "evidence_keys": ["type98_bridge", "pre_4a8db2"],
        "descriptor_identity_authority": "row_like_in_current_samples_but_not_global_rule",
        "remaining_blocker": (
            "Keep descriptor+0x00 as row-like only for the sampled type-98 lane. Broader "
            "producer paths are still required before generalizing row identity to other "
            "descriptor types or map modes."
        ),
    },
    "0x004a98f0 | 53": {
        "producer_context": "0x4a9641_selected_object_callback",
        "owner_functions": ["0x4a9641", "0x4a54a7", "0x4a98f0"],
        "human_scope": (
            "Mine-coordinate selected-object callback return. Ghidra names 0x4a98f0 as the "
            "post-callback continuation inside 0x4a9641, and focused Wine evidence recovers "
            "one sampled same-ledger write stream through 0x4a54a7."
        ),
        "evidence_keys": ["nonfallback_owner"],
        "descriptor_identity_authority": "mixed_descriptor_word_mode_not_final_identity",
        "remaining_blocker": (
            "Recover the descriptor+0x00 assignment path for the mixed type-53 lane; one "
            "sampled word maps to River Delta under catalog-row interpretation while "
            "descriptor+0x1c is Mine."
        ),
    },
    "0x004a9c3f | 79": {
        "producer_context": "0x4a9911_selected_object_callback",
        "owner_functions": ["0x4a9911", "0x4a54a7", "0x4a9c3f"],
        "human_scope": (
            "Mine requirement/resource selected-object callback return. Ghidra names 0x4a9c3f "
            "as the post-callback continuation inside 0x4a9911, and focused Wine evidence "
            "recovers one sampled target-return write stream through 0x4a54a7."
        ),
        "evidence_keys": ["nonfallback_owner"],
        "descriptor_identity_authority": "class_word_not_catalog_row_in_current_samples",
        "remaining_blocker": (
            "Recover the descriptor+0x00 assignment path for type-79 samples; all current "
            "sampled words map to other catalog rows under the zero-based row rule."
        ),
    },
}


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def summary_status(summary: dict[str, Any]) -> str | None:
    return summary.get("status") if isinstance(summary.get("status"), str) else None


def no_native_change(summary: dict[str, Any]) -> bool | None:
    invariants = summary.get("invariants", {})
    metrics = summary.get("metrics", {})
    if invariants.get("no_native_behavior_change") is not None:
        return invariants.get("no_native_behavior_change") is True
    if metrics.get("native_behavior_changed") is not None:
        return metrics.get("native_behavior_changed") is False
    return None


def no_objdump(summary: dict[str, Any]) -> bool | None:
    invariants = summary.get("invariants", {})
    metrics = summary.get("metrics", {})
    if invariants.get("no_objdump_used") is not None:
        return invariants.get("no_objdump_used") is True
    if metrics.get("used_objdump") is not None:
        return metrics.get("used_objdump") is False
    return None


def context_summary(
    key: str,
    row_group: dict[str, Any],
    context: dict[str, Any],
) -> dict[str, Any]:
    mismatch_examples = row_group.get("mismatch_examples", [])
    return {
        "return_address_and_descriptor_type": key,
        "producer_context": context["producer_context"],
        "owner_functions": context["owner_functions"],
        "human_scope": context["human_scope"],
        "evidence_keys": context["evidence_keys"],
        "sample_count": row_group.get("sample_count", 0),
        "row_match_count": row_group.get("row_match_count", 0),
        "row_mismatch_count": row_group.get("row_mismatch_count", 0),
        "row_missing_count": row_group.get("row_missing_count", 0),
        "descriptor_words": row_group.get("descriptor_words", []),
        "row_mode_classification": row_group.get("row_mode_classification"),
        "descriptor_identity_authority": context["descriptor_identity_authority"],
        "mismatch_examples": mismatch_examples,
        "remaining_blocker": context["remaining_blocker"],
    }


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    inputs = {
        "descriptor_row_mode": args.descriptor_row_mode,
        "type98_bridge": args.type98_bridge,
        "fallback_reconciliation": args.fallback_reconciliation,
        "fallback_commit_boundary": args.fallback_commit_boundary,
        "nonfallback_context": args.nonfallback_context,
        "nonfallback_owner": args.nonfallback_owner,
        "pre_4a8db2": args.pre_4a8db2,
    }
    summaries = {name: load_json(path) for name, path in inputs.items()}
    row_groups = summaries["descriptor_row_mode"].get(
        "by_return_address_and_descriptor_type", {}
    )

    producer_contexts: list[dict[str, Any]] = []
    for key, context in CONTEXTS.items():
        producer_contexts.append(context_summary(key, row_groups.get(key, {}), context))

    remaining_blockers = [
        {
            "id": "descriptor_plus_0x00_assignment_paths",
            "reason": (
                "Descriptor+0x00 is now classified by producer context, but the actual "
                "assignment/constructor paths that set mixed class-word values are not "
                "fully recovered. This blocks using descriptor+0x00 as final object identity "
                "outside explicitly row-like sampled lanes."
            ),
            "affected_contexts": [
                context["return_address_and_descriptor_type"]
                for context in producer_contexts
                if context["descriptor_identity_authority"]
                != "row_like_in_current_samples_but_not_global_rule"
            ],
        },
        {
            "id": "broader_descriptor_identity_scope",
            "reason": (
                "The type-98 lane is row-like in current exact samples, but mixed lanes prove "
                "the row rule is not global. Broader descriptor labels need producer-backed "
                "construction evidence, not catalog-row coincidence."
            ),
            "affected_contexts": [context["return_address_and_descriptor_type"] for context in producer_contexts],
        },
    ]

    input_statuses = {name: summary_status(summary) for name, summary in summaries.items()}
    input_invariants = {
        name: {
            "no_native_behavior_change": no_native_change(summary),
            "no_objdump_used": no_objdump(summary),
        }
        for name, summary in summaries.items()
    }
    expected_group_keys = set(CONTEXTS)
    actual_group_keys = set(row_groups)
    invariants = {
        "descriptor_row_mode_checkpoint_present": input_statuses["descriptor_row_mode"]
        == "descriptor_word_row_mode_mixed_class_word_recovered",
        "all_expected_descriptor_contexts_present": expected_group_keys <= actual_group_keys,
        "type98_bridge_present": input_statuses["type98_bridge"]
        == "descriptor_type98_weighted_and_commit_lane_recovered",
        "fallback_reconciliation_present": input_statuses["fallback_reconciliation"]
        == "coordinate_projection_exact_cross_seed_fallback_and_744a_reconciled_remaining_contexts_pending",
        "nonfallback_owner_checkpoint_present": input_statuses["nonfallback_owner"]
        == "nonfallback_4a54a7_return_owners_sampled_streams_recovered",
        "nonfallback_744a_context_present": input_statuses["nonfallback_context"]
        == "nonfallback_4a54a7_744a_sampled_contract_recovered_remaining_contexts_pending",
        "pre_4a8db2_checkpoint_present": input_statuses["pre_4a8db2"]
        == "pre_4a8db2_score_projection_order_recovered",
        "no_native_behavior_change": all(
            item["no_native_behavior_change"] is not False for item in input_invariants.values()
        ),
        "no_objdump_used": all(
            item["no_objdump_used"] is not False for item in input_invariants.values()
        ),
        "mixed_contexts_still_block_final_identity": any(
            context["row_mismatch_count"] > 0 for context in producer_contexts
        ),
    }
    status = (
        "descriptor_producer_contexts_named_assignment_paths_pending"
        if all(invariants.values())
        else "descriptor_producer_contexts_incomplete"
    )
    row_match_total = sum(int(context["row_match_count"]) for context in producer_contexts)
    row_mismatch_total = sum(int(context["row_mismatch_count"]) for context in producer_contexts)

    return {
        "schema_id": "h3maped_descriptor_producer_context_summary_v1",
        "status": status,
        "scope": (
            "Names the producer/return context for each sampled descriptor+0x00 "
            "row/class-word mode. This uses existing Wine/Ghidra/Python summaries only; "
            "it does not change native RMG behavior and does not authorize catalog-row "
            "identity from descriptor+0x00 except where producer evidence later proves it."
        ),
        "inputs": {name: str(path) for name, path in inputs.items()},
        "input_statuses": input_statuses,
        "input_invariants": input_invariants,
        "invariants": invariants,
        "metrics": {
            "producer_context_count": len(producer_contexts),
            "sample_count": sum(int(context["sample_count"]) for context in producer_contexts),
            "row_match_count": row_match_total,
            "row_mismatch_count": row_mismatch_total,
            "row_missing_count": sum(int(context["row_missing_count"]) for context in producer_contexts),
            "native_behavior_changed": False,
            "used_objdump": False,
            "overall_goal_complete": False,
        },
        "producer_contexts": producer_contexts,
        "remaining_blockers": remaining_blockers,
        "source_backed_conclusion": (
            "The sampled descriptor+0x00 surface is now separated by producer context. "
            "0x4a9586/type98 is row-like in current exact samples and is backed by the "
            "sampled weighted/type98 bridge. 0x4a744a/type45 and 0x4a9c3f/type79 are "
            "class-word-like in current samples, while 0x4a5e6c/type54 and 0x4a98f0/type53 "
            "are mixed. Therefore descriptor+0x1c remains the recovered counter/type lane, "
            "but descriptor+0x00 cannot be used as universal final object identity until "
            "the producer/constructor assignment paths for those lanes are recovered."
        ),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--descriptor-row-mode", type=Path, default=DEFAULT_DESCRIPTOR_ROW_MODE)
    parser.add_argument("--type98-bridge", type=Path, default=DEFAULT_TYPE98_BRIDGE)
    parser.add_argument("--fallback-reconciliation", type=Path, default=DEFAULT_FALLBACK_RECONCILIATION)
    parser.add_argument("--fallback-commit-boundary", type=Path, default=DEFAULT_FALLBACK_COMMIT_BOUNDARY)
    parser.add_argument("--nonfallback-context", type=Path, default=DEFAULT_NONFALLBACK_CONTEXT)
    parser.add_argument("--nonfallback-owner", type=Path, default=DEFAULT_NONFALLBACK_OWNER)
    parser.add_argument("--pre-4a8db2", type=Path, default=DEFAULT_PRE_4A8DB2)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_DESCRIPTOR_PRODUCER_CONTEXT status={status} contexts={contexts} "
        "row_matches={matches} row_mismatches={mismatches} out={out}".format(
            status=summary["status"],
            contexts=summary["metrics"]["producer_context_count"],
            matches=summary["metrics"]["row_match_count"],
            mismatches=summary["metrics"]["row_mismatch_count"],
            out=args.out,
        )
    )


if __name__ == "__main__":
    main()
