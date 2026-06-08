#!/usr/bin/env python3
"""Summarize the current H3MapEd downstream recovery frontier.

This is a recovery checkpoint, not an implementation patch. It correlates the
existing projection-object, 0x4a79a3 dispatch, 0x4a696b, 0x4a7605, and
Border Guard traces so the next missing private-state target is explicit.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_CANDIDATE_CALLIND_LEDGER = Path(
    ".artifacts/rmg_recovery/"
    "direct_generation_49c_candidate_callind_trace_manual_xvfb_151/"
    "winedbg_recovery_trace_ledger.json"
)
DEFAULT_CANDIDATE_CONTRACT = Path(
    ".artifacts/rmg_recovery/medium_4a9f1c_candidate_vtable_contract_summary_20260608.json"
)
DEFAULT_PROJECTION_SURVIVAL = Path(
    ".artifacts/rmg_recovery/projection_object_survival_summary_20260608.json"
)
DEFAULT_FILTER_DISPATCH = Path(".artifacts/rmg_recovery/4a79a3_filter_dispatch_summary.json")
DEFAULT_BRANCH_4A696B = Path(".artifacts/rmg_recovery/4a696b_branch_trace_summary_20260608.json")
DEFAULT_FORCED_PLUS09 = Path(
    ".artifacts/rmg_recovery/forced_border_guard_route_summary_20260608.json"
)
DEFAULT_NATURAL_BG = Path(
    ".artifacts/rmg_recovery/medium_seed10_natural_border_guard_downstream_replay_20260608/"
    "natural_border_guard_downstream_summary.json"
)
DEFAULT_OUT = Path(".artifacts/rmg_recovery/downstream_recovery_frontier_summary_20260608.json")

PROJECTION_PRODUCING_CANDIDATE_VTABLES = {"0x00540c60", "0x00540c70", "0x00540c80", "0x00540ca0"}
PROJECTION_OBJECT_VTABLES = {"0x00540b00", "0x00540b14"}
PROJECTION_OBJECT_METHODS = {"0x0049c019", "0x0049c0a6"}


def hex32(value: int | None) -> str | None:
    return None if value is None else f"0x{value & 0xFFFFFFFF:08x}"


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def memory_words(event: dict[str, Any], address: int | None) -> list[int]:
    if address is None:
        return []
    for line in event.get("memory_lines", []):
        if int(line.get("address", -1)) == address:
            return [int(word) & 0xFFFFFFFF for word in line.get("words", [])]
    return []


def signed32(value: int | None) -> int | None:
    if value is None:
        return None
    value &= 0xFFFFFFFF
    return value - 0x100000000 if value & 0x80000000 else value


def summarize_candidate_scoring(ledger: dict[str, Any]) -> dict[str, Any]:
    vtables: Counter[str] = Counter()
    score_slots: Counter[str] = Counter()
    predicate_slots: Counter[str] = Counter()
    create_slots: Counter[str] = Counter()
    projection_producing_records: list[dict[str, Any]] = []
    accepted_score_calls = 0
    rejected_score_calls = 0

    for index, event in enumerate(ledger.get("events", [])):
        regs = event.get("registers", {})
        candidate_vtable = regs.get("eax")
        candidate = regs.get("ecx")
        vtable_words = memory_words(event, candidate_vtable)
        candidate_words = memory_words(event, candidate)
        vtable = hex32(candidate_vtable)
        if vtable:
            vtables[vtable] += 1
        if len(vtable_words) > 0:
            create_slots[hex32(vtable_words[0]) or "missing"] += 1
        if len(vtable_words) > 1:
            score_slots[hex32(vtable_words[1]) or "missing"] += 1
        if len(vtable_words) > 2:
            predicate_slots[hex32(vtable_words[2]) or "missing"] += 1

        value = signed32(candidate_words[3]) if len(candidate_words) > 3 else None
        if value is not None and value >= 0:
            accepted_score_calls += 1
        elif value == -1:
            rejected_score_calls += 1

        if vtable in PROJECTION_PRODUCING_CANDIDATE_VTABLES:
            projection_producing_records.append(
                {
                    "event_index": index,
                    "candidate_vtable": vtable,
                    "candidate_pointer": hex32(candidate),
                    "create_slot": hex32(vtable_words[0]) if len(vtable_words) > 0 else None,
                    "score_slot": hex32(vtable_words[1]) if len(vtable_words) > 1 else None,
                    "predicate_slot": hex32(vtable_words[2]) if len(vtable_words) > 2 else None,
                    "candidate_type": signed32(candidate_words[1]) if len(candidate_words) > 1 else None,
                    "candidate_value": value,
                }
            )

    return {
        "event_count": int(ledger.get("event_count", len(ledger.get("events", [])))),
        "address_counts": dict(
            sorted(Counter(event.get("address") for event in ledger.get("events", [])).items())
        ),
        "candidate_vtable_counts": dict(sorted(vtables.items())),
        "create_slot_counts": dict(sorted(create_slots.items())),
        "score_slot_counts": dict(sorted(score_slots.items())),
        "predicate_slot_counts": dict(sorted(predicate_slots.items())),
        "projection_producing_score_call_count": len(projection_producing_records),
        "projection_producing_score_vtable_counts": dict(
            sorted(Counter(record["candidate_vtable"] for record in projection_producing_records).items())
        ),
        "accepted_score_call_count": accepted_score_calls,
        "rejected_score_call_count": rejected_score_calls,
        "projection_producing_records_prefix": projection_producing_records[:20],
        "interpretation": (
            "This trace hit 0x4aa001 value scoring, not returned projection-object method dispatch. "
            "Projection-producing candidate rows are present, but their candidate predicate slot is "
            "0x49baf5; the missing 0x49c019/0x49c0a6 methods belong to returned 0x540b00/0x540b14 "
            "projection objects."
        ),
    }


def summarize_frontier(args: argparse.Namespace) -> dict[str, Any]:
    candidate_scoring = summarize_candidate_scoring(load_json(args.candidate_callind_ledger))
    candidate_contract = load_json(args.candidate_contract)
    projection_survival = load_json(args.projection_survival)
    filter_dispatch = load_json(args.filter_dispatch)
    branch_4a696b = load_json(args.branch_4a696b)
    forced_plus09 = load_json(args.forced_plus09)
    natural_bg = load_json(args.natural_bg)

    selected_object_counts = candidate_contract.get("selected_object_vtable_counts", {})
    selected_projection_count = sum(
        int(selected_object_counts.get(vtable, 0)) for vtable in PROJECTION_OBJECT_VTABLES
    )
    survival_invariants = projection_survival.get("invariants", {})
    dispatch_counts = filter_dispatch.get("dispatch_summary", {}).get("from_4a79a3_counts", {})
    branch_invariants = branch_4a696b.get("invariants", {})
    forced_invariants = forced_plus09.get("invariants", {})
    natural_invariants = natural_bg.get("invariants", {})

    invariants = {
        "candidate_scoring_has_projection_producing_rows": candidate_scoring[
            "projection_producing_score_call_count"
        ]
        > 0,
        "selected_create_has_projection_object_return": selected_projection_count > 0,
        "sampled_projection_objects_are_stamped": bool(
            survival_invariants.get("sampled_projection_objects_reach_stamp")
        ),
        "sampled_projection_objects_do_not_survive_into_4a79a3_payload": bool(
            survival_invariants.get("sampled_4a79a3_payload_has_no_projection_object_vtables")
            and survival_invariants.get("sampled_4a79a3_payload_has_no_projection_base_vtable")
        ),
        "4a79a3_dispatch_reaches_4a696b_and_4a7605": bool(
            int(dispatch_counts.get("0x004a696b", 0)) > 0
            and int(dispatch_counts.get("0x004a7605", 0)) > 0
        ),
        "sampled_4a696b_exits_before_direct_mutation": bool(
            branch_invariants.get("all_4a696b_entries_took_no_candidate_exit")
            and branch_invariants.get("no_4a696b_direct_mutation_hits")
        ),
        "forced_plus09_reaches_5e73_without_mutation": bool(
            forced_invariants.get("two_4a746b_calls_observed")
            and forced_invariants.get("two_4a7593_to_4a5e73_delegations_observed")
            and forced_invariants.get("generated_cell_mutation_not_reached")
        ),
        "natural_border_guard_reaches_5e73_without_mutation": bool(
            natural_invariants.get("all_4a5e73_entries_failed_at_4a5f84")
            and natural_invariants.get("generated_cell_mutation_not_reached")
        ),
    }

    return {
        "schema_id": "h3maped_downstream_recovery_frontier_summary_v1",
        "status": (
            "frontier_is_4a79a3_to_4a696b_4a7605_mutation_recovery"
            if all(invariants.values())
            else "incomplete_frontier_evidence"
        ),
        "native_behavior_changed": False,
        "inputs": {
            "candidate_callind_ledger": str(args.candidate_callind_ledger),
            "candidate_contract": str(args.candidate_contract),
            "projection_survival": str(args.projection_survival),
            "filter_dispatch": str(args.filter_dispatch),
            "branch_4a696b": str(args.branch_4a696b),
            "forced_plus09": str(args.forced_plus09),
            "natural_bg": str(args.natural_bg),
        },
        "candidate_scoring_surface": candidate_scoring,
        "selected_create_surface": {
            "status": candidate_contract.get("status"),
            "selected_candidate_vtable_counts": candidate_contract.get("selected_candidate_vtable_counts"),
            "selected_object_vtable_counts": selected_object_counts,
            "selected_projection_object_count": selected_projection_count,
        },
        "projection_survival_surface": {
            "status": projection_survival.get("status"),
            "invariants": survival_invariants,
            "source_backed_conclusion": projection_survival.get("source_backed_conclusion"),
        },
        "dispatch_surface": {
            "status": filter_dispatch.get("status"),
            "from_4a79a3_counts": dispatch_counts,
            "remaining_gap": filter_dispatch.get("remaining_gap"),
        },
        "branch_4a696b_surface": {
            "status": branch_4a696b.get("status"),
            "branch_counts": branch_4a696b.get("branch_counts"),
            "missed_4a696b_sites": branch_4a696b.get("missed_4a696b_sites"),
            "remaining_gap": branch_4a696b.get("remaining_gap"),
        },
        "plus09_border_guard_surface": {
            "forced_status": forced_plus09.get("status"),
            "natural_status": natural_bg.get("status"),
            "forced_recovered_contract": forced_plus09.get("recovered_contract"),
            "natural_recovered_contract": natural_bg.get("recovered_contract"),
        },
        "invariants": invariants,
        "source_backed_conclusion": (
            "The sampled evidence no longer supports chasing 0x49c019/0x49c0a6 as the live next "
            "dispatch for the target run: projection-producing candidates exist and at least one "
            "0x540b14 projection object is returned and stamped, but the later sampled 0x4a79a3 "
            "payload contains ordinary 0x540a88/0x540a9c records and no 0x540b00/0x540b14 or "
            "0x540b28 projection-base records. The currently live downstream path to recover is "
            "0x4a79a3-owned 0x4a696b/0x4a7605 callee-side mutation, with 0x49c019/0x49c0a6 kept "
            "as real static-but-unhit methods until pointer-paired runtime evidence reaches them."
        ),
        "remaining_recovery_targets_ordered": [
            (
                "Recover the object/storage transformation between stamped 0x540b14 projection "
                "objects and later ordinary 0x540a88/0x540a9c 0x4a79a3 payload records, or prove "
                "they are separate selected-create surfaces in the sampled run."
            ),
            (
                "Recover a live 0x4a696b candidate path where [EBP-0x54] is nonzero and execution "
                "reaches 0x4a6b2e/0x4a6b9b/0x4a6c13, or prove the direct mutation block is unreachable "
                "for one-level land generation."
            ),
            (
                "Recover natural 0x4a7605/0x4a746b/0x4a5e73 success state that reaches 0x4a5fd8/"
                "0x4a5ff1, or prove those mutation sites are unreachable for one-level land generation."
            ),
            (
                "Recover an actual 0x4add76 cleanup/uncommit runtime path before porting replacement "
                "or uncommit behavior."
            ),
        ],
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate-callind-ledger", type=Path, default=DEFAULT_CANDIDATE_CALLIND_LEDGER)
    parser.add_argument("--candidate-contract", type=Path, default=DEFAULT_CANDIDATE_CONTRACT)
    parser.add_argument("--projection-survival", type=Path, default=DEFAULT_PROJECTION_SURVIVAL)
    parser.add_argument("--filter-dispatch", type=Path, default=DEFAULT_FILTER_DISPATCH)
    parser.add_argument("--branch-4a696b", type=Path, default=DEFAULT_BRANCH_4A696B)
    parser.add_argument("--forced-plus09", type=Path, default=DEFAULT_FORCED_PLUS09)
    parser.add_argument("--natural-bg", type=Path, default=DEFAULT_NATURAL_BG)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize_frontier(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_DOWNSTREAM_RECOVERY_FRONTIER_SUMMARY "
        f"status={summary['status']} out={args.out}"
    )
    return 0 if summary["status"].startswith("frontier_is_") else 1


if __name__ == "__main__":
    raise SystemExit(main())
