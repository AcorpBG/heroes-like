#!/usr/bin/env python3
"""Summarize the selected-candidate cursor-gate frontier for H3MapEd RMG.

This is recovery evidence only. It uses the recovered 0x4a9f1c candidate
vtable contracts plus the current endpoint cursor-source frontier to separate
sampled +0xf58-gated projection selection from the still-unselected +0xf5c
candidate path.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_CANDIDATE = Path(
    ".artifacts/rmg_recovery/medium_4a9f1c_candidate_vtable_contract_summary_20260608.json"
)
DEFAULT_CURSOR_SOURCE = Path(
    ".artifacts/rmg_recovery/cursor_source_frontier_summary_20260610.json"
)
DEFAULT_OUT = Path(
    ".artifacts/rmg_recovery/candidate_cursor_gate_frontier_summary_20260610.json"
)

F58_GATED_SCORERS = {"0x0049ca8b", "0x0049cb60"}
F5C_GATED_SCORERS = {"0x0049cd97"}
SIMPLE_VALUE_SCORERS = {"0x0049c54d"}


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def classify_gate(record: dict[str, Any]) -> str:
    scorer = str(record.get("candidate_score_function"))
    if scorer in F58_GATED_SCORERS:
        return "generator+0xf58_and_0x10b4_gate"
    if scorer in F5C_GATED_SCORERS:
        return "generator+0xf5c_gate"
    if scorer in SIMPLE_VALUE_SCORERS:
        return "ungated_value_field"
    return "unknown"


def summarize(candidate_path: Path, cursor_source_path: Path) -> dict[str, Any]:
    candidate = load_json(candidate_path)
    cursor_source = load_json(cursor_source_path)
    records = list(candidate.get("selected_records", []))
    contracts = candidate.get("recovered_contract", {}).get("selected_vtable_contracts", {})

    selected_by_gate: dict[str, list[dict[str, Any]]] = {
        "generator+0xf58_and_0x10b4_gate": [],
        "generator+0xf5c_gate": [],
        "ungated_value_field": [],
        "unknown": [],
    }
    for record in records:
        gate = classify_gate(record)
        selected_by_gate.setdefault(gate, []).append(
            {
                "cycle_index": record.get("cycle_index"),
                "candidate_vtable": record.get("candidate_vtable"),
                "candidate_type": record.get("candidate_type"),
                "candidate_score_function": record.get("candidate_score_function"),
                "candidate_create_function": record.get("candidate_create_function"),
                "selected_object_vtable": record.get("selected_object_vtable"),
            }
        )

    contract_by_gate: dict[str, list[dict[str, Any]]] = {
        "generator+0xf58_and_0x10b4_gate": [],
        "generator+0xf5c_gate": [],
        "ungated_value_field": [],
        "unknown": [],
    }
    for vtable, contract in sorted(contracts.items()):
        gate = "unknown"
        scorer = str(contract.get("score"))
        if scorer in F58_GATED_SCORERS:
            gate = "generator+0xf58_and_0x10b4_gate"
        elif scorer in F5C_GATED_SCORERS:
            gate = "generator+0xf5c_gate"
        elif scorer in SIMPLE_VALUE_SCORERS:
            gate = "ungated_value_field"
        contract_by_gate.setdefault(gate, []).append(
            {
                "candidate_vtable": vtable,
                "candidate_score_function": contract.get("score"),
                "candidate_create_function": contract.get("create"),
                "returned_object_vtable": contract.get("returned_object_vtable"),
                "score_contract": contract.get("score_contract"),
            }
        )

    candidate_invariants = candidate.get("invariants", {})
    cursor_invariants = cursor_source.get("invariants", {})
    invariants = {
        "candidate_contracts_passed": candidate.get("status")
        == "passed_selected_candidate_vtable_contracts",
        "candidate_contracts_no_objdump": candidate_invariants.get("no_objdump_used") is True
        or candidate.get("metrics", {}).get("used_objdump") is False,
        "cursor_source_frontier_passed": cursor_source.get("status")
        == "cursor_source_frontier_setup_and_writer_surface_recovered_success_path_still_unrecovered",
        "cursor_source_no_objdump": cursor_invariants.get("no_objdump_used") is True,
        "selected_trace_has_f58_gated_projection": bool(
            selected_by_gate["generator+0xf58_and_0x10b4_gate"]
        ),
        "selected_trace_has_no_f5c_gated_candidate": not selected_by_gate["generator+0xf5c_gate"],
        "contract_surface_contains_f5c_gated_candidate": bool(
            contract_by_gate["generator+0xf5c_gate"]
        ),
        "f5c_gated_contract_is_adjacent_projection_540ca0": [
            row["candidate_vtable"] for row in contract_by_gate["generator+0xf5c_gate"]
        ]
        == ["0x00540ca0"],
        "no_native_behavior_change": True,
        "no_objdump_used": True,
    }
    status = (
        "candidate_cursor_gate_frontier_selected_path_f58_only_f5c_candidate_unselected"
        if all(invariants.values())
        else "candidate_cursor_gate_frontier_inputs_incomplete"
    )

    return {
        "schema_id": "h3maped_candidate_cursor_gate_frontier_summary_v1",
        "status": status,
        "scope": (
            "Current selected-candidate cursor-gate evidence for one-level land RMG. "
            "This does not prove global unreachability for the +0xf5c-gated candidate."
        ),
        "inputs": {
            "candidate_vtable_contract": str(candidate_path),
            "cursor_source_frontier": str(cursor_source_path),
        },
        "invariants": invariants,
        "metrics": {
            "native_behavior_changed": False,
            "overall_goal_complete": False,
            "used_objdump": False,
            "selected_create_return_cycles": len(records),
            "selected_f58_gated_candidate_count": len(
                selected_by_gate["generator+0xf58_and_0x10b4_gate"]
            ),
            "selected_f5c_gated_candidate_count": len(
                selected_by_gate["generator+0xf5c_gate"]
            ),
            "selected_ungated_value_candidate_count": len(selected_by_gate["ungated_value_field"]),
            "contract_f58_gated_candidate_count": len(
                contract_by_gate["generator+0xf58_and_0x10b4_gate"]
            ),
            "contract_f5c_gated_candidate_count": len(
                contract_by_gate["generator+0xf5c_gate"]
            ),
        },
        "contract_by_gate": contract_by_gate,
        "selected_records_by_gate": selected_by_gate,
        "human_readable_conclusion": (
            "The sampled selected-create path includes one projection selection, but it is the "
            "0x540c60/0x49ca8b path gated by generator+0xf58 and generator+0x10b4. "
            "The only recovered candidate scorer that directly requires generator+0xf5c is "
            "0x540ca0/0x49cd97, which is present in the static candidate contract table but is "
            "not selected in the current 17 selected-create returns. This means the sampled "
            "selected-candidate evidence does not seed or consume generator+0xf5c."
        ),
        "remaining_gap": (
            "Recover a natural selected-create run that chooses the 0x540ca0/0x49cd97 "
            "generator+0xf5c-gated candidate, or prove with broader map-mode/source-state data "
            "that supported one-level land generation cannot select that candidate before "
            "endpoint stamping. Until then, this frontier narrows the blocker but does not "
            "justify native RMG behavior changes."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate", type=Path, default=DEFAULT_CANDIDATE)
    parser.add_argument("--cursor-source", type=Path, default=DEFAULT_CURSOR_SOURCE)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args.candidate, args.cursor_source)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_CANDIDATE_CURSOR_GATE_FRONTIER "
        f"status={summary['status']} "
        f"selected_f58={summary['metrics']['selected_f58_gated_candidate_count']} "
        f"selected_f5c={summary['metrics']['selected_f5c_gated_candidate_count']} "
        f"out={args.out}"
    )
    return (
        0
        if summary["status"]
        == "candidate_cursor_gate_frontier_selected_path_f58_only_f5c_candidate_unselected"
        else 1
    )


if __name__ == "__main__":
    raise SystemExit(main())
