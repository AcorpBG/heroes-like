#!/usr/bin/env python3
"""Consolidate non-fallback ``0x4a54a7`` return-context recovery evidence.

The cross-seed commit-surface report intentionally named every non-fallback
return site as pending because that report only had broad before/after
snapshots. Older focused Wine/Ghidra ledgers already contain stronger evidence
for the sampled ``0x4a744a`` direct endpoint path. This verifier keeps those
truths separated: ``0x4a744a`` has a recovered sampled afterstate and
descriptor/relation contract, while the other non-fallback return sites remain
unrecovered before native RMG behavior changes.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_CROSS_SEED_COMMIT_SURFACE = Path(
    ".artifacts/rmg_recovery/medium_4a54a7_cross_seed_commit_surface_summary_20260610.json"
)
DEFAULT_DIRECT_ENDPOINT_AFTERSTATE = Path(
    ".artifacts/rmg_recovery/direct_endpoint_afterstate_dynamic_summary_20260608.json"
)
DEFAULT_DESCRIPTOR_RELATION = Path(
    ".artifacts/rmg_recovery/medium_seed10_4a54a7_descriptor_relation_summary_20260608.json"
)
DEFAULT_OUT = Path(
    ".artifacts/rmg_recovery/nonfallback_4a54a7_return_context_summary_20260610.json"
)

RECOVERED_DIRECT_ENDPOINT_RETURN = "0x004a744a"
UNRECOVERED_RETURN_SITES = {"0x004a98f0", "0x004a9c3f", "0x004aa44d"}


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def invariants_all_true(summary: dict[str, Any]) -> bool:
    invariants = summary.get("invariants", {})
    return bool(invariants) and all(value is True for value in invariants.values())


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    cross_seed = load_json(args.cross_seed_commit_surface)
    direct_endpoint = load_json(args.direct_endpoint_afterstate)
    descriptor_relation = load_json(args.descriptor_relation)

    return_site_counts = {
        str(key): int(value)
        for key, value in cross_seed.get("return_site_counts", {}).items()
        if isinstance(value, int)
    }
    direct_endpoint_returns = [
        sequence.get("commit_entry", {}).get("return_address")
        for sequence in direct_endpoint.get("direct_endpoint_sequences", [])
    ]
    descriptor_return_counts = {
        str(key): int(value)
        for key, value in descriptor_relation.get("return_address_counts", {}).items()
        if isinstance(value, int)
    }
    recovered_744a_sequence_count = sum(
        1 for value in direct_endpoint_returns if value == RECOVERED_DIRECT_ENDPOINT_RETURN
    )
    descriptor_744a_count = descriptor_return_counts.get(RECOVERED_DIRECT_ENDPOINT_RETURN, 0)
    unresolved_counts = {
        site: return_site_counts.get(site, 0)
        for site in sorted(UNRECOVERED_RETURN_SITES)
        if return_site_counts.get(site, 0) > 0
    }

    invariants = {
        "no_native_behavior_change": cross_seed.get("invariants", {}).get(
            "no_native_behavior_change"
        )
        is True
        and direct_endpoint.get("invariants", {}).get("no_native_behavior_change") is True
        and descriptor_relation.get("invariants", {}).get("native_behavior_changed") is False,
        "no_objdump_used": cross_seed.get("invariants", {}).get("no_objdump_used") is True,
        "cross_seed_nonfallback_surface_present": cross_seed.get("metrics", {}).get(
            "total_non_fallback_return_context_commit_count", 0
        )
        > 0,
        "cross_seed_counts_include_744a": return_site_counts.get(RECOVERED_DIRECT_ENDPOINT_RETURN)
        == recovered_744a_sequence_count
        and recovered_744a_sequence_count == 2,
        "direct_endpoint_744a_afterstate_recovered": direct_endpoint.get("status")
        == "direct_endpoint_4a54a7_afterstate_recovered"
        and invariants_all_true(direct_endpoint)
        and recovered_744a_sequence_count == 2,
        "descriptor_relation_744a_recovered": descriptor_relation.get("status")
        == "post_border_guard_4a54a7_descriptor_relation_counters_recovered"
        and descriptor_relation.get("invariants", {}).get("all_invocations_complete") is True
        and descriptor_relation.get("invariants", {}).get(
            "all_relation_counter_slots_match_source_owner_relation"
        )
        is True
        and descriptor_relation.get("invariants", {}).get("all_source_coordinates_match_descriptor_offsets")
        is True
        and descriptor_relation.get("invariants", {}).get("all_source_low_words_cleared")
        is True
        and descriptor_744a_count == 2,
        "unrecovered_large_return_sites_still_named": set(unresolved_counts) == UNRECOVERED_RETURN_SITES,
    }
    status = (
        "nonfallback_4a54a7_744a_sampled_contract_recovered_remaining_contexts_pending"
        if all(invariants.values())
        else "nonfallback_4a54a7_return_context_recovery_incomplete"
    )
    unresolved_commit_count = sum(unresolved_counts.values())

    return {
        "schema_id": "h3maped_nonfallback_4a54a7_return_context_summary_v1",
        "status": status,
        "scope": (
            "Existing Wine/Ghidra/Python recovery evidence for non-fallback 0x4a54a7 return "
            "contexts in current one-level land traces. This is a frontier correction, not "
            "native RMG behavior authority."
        ),
        "inputs": {
            "cross_seed_commit_surface": str(args.cross_seed_commit_surface),
            "direct_endpoint_afterstate": str(args.direct_endpoint_afterstate),
            "descriptor_relation": str(args.descriptor_relation),
        },
        "invariants": invariants,
        "metrics": {
            "native_behavior_changed": False,
            "used_objdump": False,
            "overall_goal_complete": False,
            "cross_seed_nonfallback_commit_count": cross_seed.get("metrics", {}).get(
                "total_non_fallback_return_context_commit_count"
            ),
            "sampled_744a_afterstate_sequence_count": recovered_744a_sequence_count,
            "sampled_744a_descriptor_relation_count": descriptor_744a_count,
            "unresolved_nonfallback_return_site_count": len(unresolved_counts),
            "unresolved_nonfallback_commit_count": unresolved_commit_count,
        },
        "return_contexts": {
            RECOVERED_DIRECT_ENDPOINT_RETURN: {
                "cross_seed_count": return_site_counts.get(RECOVERED_DIRECT_ENDPOINT_RETURN, 0),
                "recovery_state": "sampled_afterstate_and_descriptor_relation_contract_recovered",
                "direct_endpoint_afterstate_sequences": recovered_744a_sequence_count,
                "descriptor_relation_invocations": descriptor_744a_count,
                "evidence": [
                    str(args.direct_endpoint_afterstate),
                    str(args.descriptor_relation),
                ],
                "caution": (
                    "The count matches the cross-seed return-site count, but this artifact does "
                    "not claim pointer identity between every ledger record unless a later "
                    "same-ledger correlation proves it."
                ),
            },
            **{
                site: {
                    "cross_seed_count": count,
                    "recovery_state": "pending_cell_transition_and_projection_write_stream",
                    "evidence_needed": (
                        "Wine/Ghidra correlation from 0x4a54a7 entry through 0x4a56b6 "
                        "projection writes, target-cell afterstate, object-vector append, "
                        "and downstream relation/control consumers."
                    ),
                }
                for site, count in unresolved_counts.items()
            },
        },
        "source_backed_conclusion": (
            "The non-fallback return surface is not uniformly unknown. Existing Wine evidence "
            "recovers the sampled 0x4a744a direct endpoint contract: the 0x4a54a7 call appends "
            "the object record, places that object in the target generated-cell reference "
            "vector, clears GeneratedCell+0x20 low word, and sets the occupied +0x28 surface. "
            "The descriptor/relation trace also recovers two 0x4a744a invocations with matching "
            "descriptor source coordinates, relation counter slots, and source-cell low-word "
            "clears. The remaining large non-fallback return sites in the cross-seed surface "
            "are 0x4a98f0, 0x4a9c3f, and 0x4aa44d."
        ),
        "remaining_gap": (
            "End-to-end recovery remains incomplete. The unresolved non-fallback return sites "
            "need same-ledger cell-transition/projection-write reconciliation and downstream "
            "relation/control linkage before any native RMG behavior is changed. Broader "
            "generator+0xf5c success-path seeding, broader source-state reachability, global "
            "descriptor labels, and cleanup/uncommit state remain separate blockers."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--cross-seed-commit-surface",
        type=Path,
        default=DEFAULT_CROSS_SEED_COMMIT_SURFACE,
    )
    parser.add_argument(
        "--direct-endpoint-afterstate",
        type=Path,
        default=DEFAULT_DIRECT_ENDPOINT_AFTERSTATE,
    )
    parser.add_argument("--descriptor-relation", type=Path, default=DEFAULT_DESCRIPTOR_RELATION)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_NONFALLBACK_4A54A7_CONTEXT status={summary['status']} out={args.out}")
    return (
        0
        if summary["status"]
        == "nonfallback_4a54a7_744a_sampled_contract_recovered_remaining_contexts_pending"
        else 1
    )


if __name__ == "__main__":
    raise SystemExit(main())
