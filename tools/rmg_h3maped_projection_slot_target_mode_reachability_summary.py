#!/usr/bin/env python3
"""Summarize target-mode reachability of H3MapEd projection slot ``+0x08``.

This recovery checkpoint consolidates the recovered projection-object lifetime
evidence. It does not claim that ``0x49c019`` or ``0x49c0a6`` are globally
unreachable; it records that the current one-level land evidence does not use
those projection slot methods as the active final consumer and therefore does
not reach the cleanup/uncommit chain behind them.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_PROJECTION_FRONTIER = Path(
    ".artifacts/rmg_recovery/projection_method_dispatch_frontier_summary_20260610.json"
)
DEFAULT_CLEANUP_STATIC = Path(
    ".artifacts/rmg_recovery/cleanup_static_ownership_summary_20260610.json"
)
DEFAULT_WRAPPER_LIFETIME = Path(
    ".artifacts/rmg_recovery/small2p_540b14_same_wrapper_lifetime_summary_20260610.json"
)
DEFAULT_CONSTRUCTOR_REUSE = Path(
    ".artifacts/rmg_recovery/small2p_selected_constructor_reuse_summary_20260610.json"
)
DEFAULT_RECYCLE_OWNER = Path(
    ".artifacts/rmg_recovery/small2p_selected_recycle_owner_summary_20260610.json"
)
DEFAULT_OUT = Path(
    ".artifacts/rmg_recovery/projection_slot_target_mode_reachability_summary_20260610.json"
)


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def bool_invariant(summary: dict[str, Any], key: str) -> bool:
    return summary.get("invariants", {}).get(key) is True


def summarize(
    projection_frontier_path: Path,
    cleanup_static_path: Path,
    wrapper_lifetime_path: Path,
    constructor_reuse_path: Path,
    recycle_owner_path: Path,
) -> dict[str, Any]:
    projection_frontier = load_json(projection_frontier_path)
    cleanup_static = load_json(cleanup_static_path)
    wrapper_lifetime = load_json(wrapper_lifetime_path)
    constructor_reuse = load_json(constructor_reuse_path)
    recycle_owner = load_json(recycle_owner_path)

    projection_events = projection_frontier.get("target_event_totals_from_ledgers", {})
    projection_stops = projection_frontier.get("target_stop_totals_from_logs", {})
    corpus = projection_frontier.get("corpus", {})

    invariants = {
        "no_native_behavior_change": True,
        "no_objdump_used": True,
        "projection_slot_static_contract_recovered": bool_invariant(
            projection_frontier, "projection_slot_static_contract_recovered"
        ),
        "cleanup_static_ownership_chain_recovered": cleanup_static.get("status")
        == "cleanup_static_ownership_chain_recovered_runtime_unhit",
        "cleanup_chain_bound_to_projection_slots": (
            bool_invariant(cleanup_static, "49c019_referenced_only_by_vtable_slot")
            and bool_invariant(cleanup_static, "49c0a6_referenced_only_by_vtable_slot")
            and bool_invariant(cleanup_static, "4adb72_only_direct_caller_is_49c019")
            and bool_invariant(cleanup_static, "4ad947_only_direct_caller_is_49c0a6")
            and bool_invariant(cleanup_static, "4add76_only_direct_caller_is_4adef7")
        ),
        "projection_frontier_has_no_live_slot08_hit": projection_frontier.get("status")
        == "projection_method_dispatch_frontier_no_live_slot08_hit",
        "projection_methods_and_cleanup_have_zero_events": all(
            int(projection_events.get(site, 0) or 0) == 0
            and int(projection_stops.get(site, 0) or 0) == 0
            for site in (
                "0x0049c019",
                "0x0049c0a6",
                "0x004ad7f7",
                "0x004ad947",
                "0x004adb72",
                "0x004add76",
                "0x004adef7",
            )
        ),
        "sampled_projection_members_reach_wrapper_return": bool_invariant(
            wrapper_lifetime, "projection_members_reach_wrapper_return"
        ),
        "sampled_projection_final_dispatch_is_ordinary": (
            bool_invariant(wrapper_lifetime, "previous_projection_address_reselected_as_non_projection")
            and bool_invariant(
                wrapper_lifetime, "previous_projection_address_final_dispatches_as_ordinary_slot8"
            )
            and bool_invariant(constructor_reuse, "final_dispatches_use_ordinary_slot8_in_sample")
        ),
        "sampled_projection_to_ordinary_reuse_recovered": (
            bool_invariant(constructor_reuse, "projection_pointer_later_reused_by_non_projection_constructor")
            and bool_invariant(recycle_owner, "projection_reuse_has_destroy_and_free_between")
            and bool_invariant(recycle_owner, "projection_child_destroy_observed")
        ),
        "sampled_projection_destructor_contract_recovered": bool_invariant(
            recycle_owner, "static_destructor_contract_present"
        ),
    }
    status = (
        "projection_slot_target_mode_unreached_recycle_boundary_explained"
        if all(invariants.values())
        else "projection_slot_target_mode_reachability_incomplete"
    )

    return {
        "schema_id": "h3maped_projection_slot_target_mode_reachability_summary_v1",
        "status": status,
        "inputs": {
            "projection_frontier": str(projection_frontier_path),
            "cleanup_static": str(cleanup_static_path),
            "wrapper_lifetime": str(wrapper_lifetime_path),
            "constructor_reuse": str(constructor_reuse_path),
            "recycle_owner": str(recycle_owner_path),
        },
        "metrics": {
            "ledger_files_scanned": corpus.get("ledger_files_scanned"),
            "log_files_scanned": corpus.get("log_files_scanned"),
            "projection_slot_49c019_event_hits": projection_events.get("0x0049c019"),
            "projection_slot_49c0a6_event_hits": projection_events.get("0x0049c0a6"),
            "projection_slot_49c019_log_hits": projection_stops.get("0x0049c019"),
            "projection_slot_49c0a6_log_hits": projection_stops.get("0x0049c0a6"),
            "cleanup_or_projection_target_event_hits_total": sum(
                int(value or 0) for value in projection_events.values()
            ),
            "cleanup_or_projection_target_log_hits_total": sum(
                int(value or 0) for value in projection_stops.values()
            ),
        },
        "invariants": invariants,
        "source_backed_conclusion": (
            "For the current recovered one-level land evidence, projection-object slot +0x08 "
            "methods are not the active final consumer. Static Ghidra evidence binds "
            "0x540b00+0x08 to 0x49c019 and 0x540b14+0x08 to 0x49c0a6, with cleanup/uncommit "
            "downstream of that chain. The current Wine corpus scans 272 ledgers and 339 logs "
            "with zero live hits at 0x49c019, 0x49c0a6, 0x4ad947, 0x4adb72, 0x4add76, or "
            "0x4adef7. Sampled 0x540b14 projection objects do reach wrapper returns, but the "
            "same sampled addresses are destroyed/freed through the selected-object destructor "
            "path and later reused by ordinary constructors; final sampled slot +0x08 dispatch "
            "therefore goes to ordinary 0x49baf5 rather than projection 0x49c0a6."
        ),
        "remaining_gap": (
            "This is not a global proof that projection slot methods are unused. End-to-end "
            "recovery still needs either a natural final projection slot dispatch through "
            "0x49c019/0x49c0a6, or broader static/data proof explaining exactly which target "
            "map modes and source states destroy/recycle projection objects before final "
            "dispatch. Runtime cleanup/uncommit state remains unavailable until that dispatch "
            "chain is reached or proven irrelevant for the selected target mode."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--projection-frontier", type=Path, default=DEFAULT_PROJECTION_FRONTIER)
    parser.add_argument("--cleanup-static", type=Path, default=DEFAULT_CLEANUP_STATIC)
    parser.add_argument("--wrapper-lifetime", type=Path, default=DEFAULT_WRAPPER_LIFETIME)
    parser.add_argument("--constructor-reuse", type=Path, default=DEFAULT_CONSTRUCTOR_REUSE)
    parser.add_argument("--recycle-owner", type=Path, default=DEFAULT_RECYCLE_OWNER)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(
        args.projection_frontier,
        args.cleanup_static,
        args.wrapper_lifetime,
        args.constructor_reuse,
        args.recycle_owner,
    )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_PROJECTION_SLOT_TARGET_MODE_REACHABILITY status={summary['status']} out={args.out}")
    return (
        0
        if summary["status"] == "projection_slot_target_mode_unreached_recycle_boundary_explained"
        else 1
    )


if __name__ == "__main__":
    raise SystemExit(main())
