#!/usr/bin/env python3
"""Summarize the selected-projection to ordinary-payload recovery frontier.

This is a recovery checkpoint only. It records the source-backed phase split
between selected-create projection objects and the later ordinary records that
0x4a79a3 consumes, then names the remaining state that must be recovered before
native RMG behavior can change.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_SAME_RUN_LINK = ROOT / "same_run_projection_payload_link_summary_20260608.json"
DEFAULT_RELATION_BUILDER = ROOT / "relation_builder_runtime_summary.json"
DEFAULT_PAYLOAD = ROOT / "4a79a3_payload_trace_summary.json"
DEFAULT_TIGHT_PAYLOAD = (
    ROOT / "same_run_projection_payload_tight_trace_20260608" / "4a79a3_payload_summary.json"
)
DEFAULT_OUT = ROOT / "projection_materialization_frontier_summary_20260608.json"

STATIC_FILES = {
    "4a79a3_refs": ROOT / "ghidra_private_state_expanded_dump" / "target_004a79a3_references.txt",
    "4a8c15_refs": ROOT / "ghidra_private_state_expanded_dump" / "target_004a8c15_references.txt",
    "4a8c15_body": ROOT / "ghidra_private_state_expanded_dump" / "target_004a8c15_FUN_004a8c15.txt",
    "4ac552_body": ROOT / "ghidra_private_state_expanded_dump" / "caller_004ac552_FUN_004ac552.txt",
    "4adfe1_body": ROOT / "ghidra_candidate_selection_rng_20260608" / "caller_004adfe1_FUN_004adfe1.txt",
    "4a9f1c_refs": ROOT
    / "ghidra_4a9f1c_reward_guard_object_selector_dump"
    / "target_004a9f1c_references.txt",
    "4aa1db_refs": ROOT / "ghidra_private_state_expanded_dump" / "target_004aa1db_references.txt",
    "4adef7_refs": ROOT
    / "ghidra_4ad947_4adb72_projection_driver_dump"
    / "target_004adef7_references.txt",
    "4a5c07_body": ROOT / "ghidra_object_projection_helper_dump" / "caller_004a5c07_FUN_004a5c07.txt",
    "4a901a_body": ROOT / "ghidra_object_projection_helper_dump" / "caller_004a901a_FUN_004a901a.txt",
    "4a93a2_body": ROOT / "ghidra_object_projection_helper_dump" / "caller_004a93a2_FUN_004a93a2.txt",
}

REFERENCE_RE = re.compile(
    r"from=(?P<from>[0-9a-fA-F]{8}).*caller=(?P<caller>\S+) "
    r"caller_entry=(?P<entry>[0-9a-fA-F]{8}).*instruction=(?P<instruction>.+)$"
)


def read_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""


def parse_references_to(text: str) -> list[dict[str, str]]:
    references: list[dict[str, str]] = []
    in_references_to = False
    for line in text.splitlines():
        if line.startswith("references_to:"):
            in_references_to = True
            continue
        if line.startswith("references_from_target_function:"):
            in_references_to = False
            continue
        if not in_references_to:
            continue
        match = REFERENCE_RE.search(line.strip())
        if match:
            references.append(match.groupdict())
    return references


def contains_all(text: str, needles: list[str]) -> bool:
    return all(needle in text for needle in needles)


def vtable_counts(summary: dict[str, Any]) -> dict[str, int]:
    counts = summary.get("record_vtable_counts", {})
    return {str(key): int(value) for key, value in counts.items()}


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    same_run = read_json(args.same_run_link)
    relation_builder = read_json(args.relation_builder)
    payload = read_json(args.payload)
    tight_payload = read_json(args.tight_payload)
    static_text = {name: read_text(path) for name, path in STATIC_FILES.items()}

    refs = {
        "4a79a3": parse_references_to(static_text["4a79a3_refs"]),
        "4a8c15": parse_references_to(static_text["4a8c15_refs"]),
        "4a9f1c": parse_references_to(static_text["4a9f1c_refs"]),
        "4aa1db": parse_references_to(static_text["4aa1db_refs"]),
        "4adef7": parse_references_to(static_text["4adef7_refs"]),
    }

    ordinary_vtables = {"0x00540a88", "0x00540a9c"}
    payload_vtables = set(vtable_counts(payload))
    tight_payload_vtables = set(vtable_counts(tight_payload))

    invariants = {
        "same_run_link_summary_is_current_gap": same_run.get("status")
        == "same_run_link_not_proven_yet",
        "same_run_broad_has_selected_projection_return": bool(
            same_run.get("invariants", {}).get("broad_trace_has_selected_projection_return")
        ),
        "same_run_payloads_have_no_projection_records": bool(
            same_run.get("invariants", {}).get("all_payload_summaries_contain_no_projection_records")
        ),
        "4a79a3_has_single_static_caller_4a8c15": refs["4a79a3"]
        == [
            {
                "from": "004a8d22",
                "caller": "FUN_004a8c15",
                "entry": "004a8c15",
                "instruction": "CALL 0x004a79a3",
            }
        ],
        "4a8c15_has_single_static_caller_4ac552": refs["4a8c15"]
        == [
            {
                "from": "004ac773",
                "caller": "FUN_004ac552",
                "entry": "004ac552",
                "instruction": "CALL 0x004a8c15",
            }
        ],
        "4adfe1_builds_candidate_container_before_4ac552": contains_all(
            static_text["4adfe1_body"],
            ["004ae047: CALL 0x0049ecf2", "004ae07d: CALL 0x004ac552"],
        ),
        "4ac552_calls_4a8c15_after_prephase_setup": contains_all(
            static_text["4ac552_body"],
            ["004ac769: CALL 0x004a8db2", "004ac773: CALL 0x004a8c15"],
        ),
        "4a8c15_orders_scan_materialization_before_payload": contains_all(
            static_text["4a8c15_refs"],
            [
                "at=004a8c20 type=UNCONDITIONAL_CALL to=004a8260",
                "at=004a8c27 type=UNCONDITIONAL_CALL to=004a4c8e",
                "at=004a8d0a type=UNCONDITIONAL_CALL to=004a4913",
                "at=004a8d14 type=UNCONDITIONAL_CALL to=004a5767",
                "at=004a8d1b type=UNCONDITIONAL_CALL to=004a4fc5",
                "at=004a8d22 type=UNCONDITIONAL_CALL to=004a79a3",
            ],
        ),
        "selected_create_selector_has_separate_driver_refs": refs["4a9f1c"]
        == [
            {
                "from": "004aa226",
                "caller": "FUN_004aa1db",
                "entry": "004aa1db",
                "instruction": "CALL 0x004a9f1c",
            },
            {
                "from": "004aa2f8",
                "caller": "FUN_004aa1db",
                "entry": "004aa1db",
                "instruction": "CALL 0x004a9f1c",
            },
            {
                "from": "004adf65",
                "caller": "FUN_004adef7",
                "entry": "004adef7",
                "instruction": "CALL 0x004a9f1c",
            },
        ],
        "selected_create_path_stamps_generated_cells": contains_all(
            static_text["4aa1db_refs"],
            [
                "at=004aa226 type=UNCONDITIONAL_CALL to=004a9f1c",
                "at=004aa27e type=UNCONDITIONAL_CALL to=0049abd6",
                "at=004aa2f8 type=UNCONDITIONAL_CALL to=004a9f1c",
            ],
        ),
        "ordinary_record_constructors_are_identified": contains_all(
            static_text["4a5c07_body"],
            ["004a5dd1: CALL 0x0049ba89", "004a5dd9: MOV dword ptr [ESI],0x540a88"],
        )
        and contains_all(
            static_text["4a901a_body"],
            ["004a92bb: CALL 0x0049ba89", "004a92c3: MOV dword ptr [ESI],0x540a9c"],
        )
        and contains_all(
            static_text["4a93a2_body"],
            ["004a951c: CALL 0x0049ba89", "004a9524: MOV dword ptr [ESI],0x540a9c"],
        ),
        "payload_trace_contains_only_ordinary_records": bool(payload_vtables)
        and payload_vtables <= ordinary_vtables,
        "tight_payload_trace_contains_only_ordinary_records": bool(tight_payload_vtables)
        and tight_payload_vtables <= ordinary_vtables,
        "relation_builder_checkpoint_is_valid": relation_builder.get("status")
        == "partial_live_relation_builder_checkpoint",
    }

    status = (
        "projection_materialization_frontier_recovered"
        if all(invariants.values())
        else "projection_materialization_frontier_incomplete"
    )

    return {
        "schema_id": "h3maped_projection_materialization_frontier_summary_v1",
        "status": status,
        "native_behavior_changed": False,
        "inputs": {
            "same_run_link": str(args.same_run_link),
            "relation_builder": str(args.relation_builder),
            "payload": str(args.payload),
            "tight_payload": str(args.tight_payload),
            "static_files": {name: str(path) for name, path in STATIC_FILES.items()},
        },
        "invariants": invariants,
        "static_call_graph": {
            "ordinary_payload_phase": [
                "0x4adfe1 calls 0x49ecf2, then 0x4ac552",
                "0x4ac552 calls 0x4a8db2, then 0x4a8c15",
                "0x4a8c15 scans/materializes grid/vector state via 0x4a4913, 0x4a5767, 0x4a4fc5, then calls 0x4a79a3",
                "0x4a79a3 consumes ordinary 0x540a88/0x540a9c records in sampled payload traces",
            ],
            "selected_projection_phase": [
                "0x4aa1db and 0x4adef7 call 0x4a9f1c to select/create projection objects",
                "0x4aa1db stamps selected coordinates through 0x49abd6",
                "same-run broad trace observed selected 0x540b14 returns before later 0x4a79a3 entry",
            ],
        },
        "ordinary_record_producer_frontier": [
            {
                "function": "0x4a5c07",
                "vtable_write": "0x4a5dd9 -> 0x540a88",
                "known_call_context": "called by 0x4aa354 in the recovered reward/guard chain",
                "missing_state": "ordered inputs and generated-cell/vector before/after mutations feeding later 0x4a79a3 records",
            },
            {
                "function": "0x4a901a",
                "vtable_write": "0x4a92c3 -> 0x540a9c",
                "known_call_context": "connection record builder path",
                "missing_state": "exact source fields and append destination for payload record materialization",
            },
            {
                "function": "0x4a93a2",
                "vtable_write": "0x4a9524 -> 0x540a9c",
                "known_call_context": "live relation-builder checkpoint reaches this path before 0x4a8c15",
                "missing_state": "owner/population path and relation-object +0xc8/+0xcc record stream semantics",
            },
            {
                "function": "0x4a4913 / 0x4a5767 / 0x4a4fc5",
                "vtable_write": None,
                "known_call_context": "0x4a8c15 materialization sequence immediately before 0x4a79a3",
                "missing_state": "ordered generated-cell and object-vector deltas after selected projection stamps and before payload consumption",
            },
        ],
        "source_backed_conclusion": (
            "Direct pointer survival from sampled selected 0x540b14 projection-object returns into the "
            "0x4a79a3 payload loop is not supported by the recovered static call graph or sampled "
            "payload traces. The current source-backed frontier is the materialization phase that turns "
            "selected/stamped generated-cell and relation-vector state into ordinary 0x540a88/0x540a9c "
            "records before 0x4a79a3 consumes them."
        ),
        "remaining_recovery_target": (
            "Recover ordered pre/post private state for ordinary record producers 0x4a5c07, 0x4a901a, "
            "0x4a93a2 and the 0x4a8c15 materialization calls 0x4a4913/0x4a5767/0x4a4fc5. The required "
            "evidence is generated-cell/vector before/after snapshots that show how selected 0x540b14 "
            "projection stamps become ordinary 0x540a88/0x540a9c payload records, or prove a fully "
            "separate selected-create surface for one-level land generation. Native behavior remains "
            "blocked until that state chain is recovered."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--same-run-link", type=Path, default=DEFAULT_SAME_RUN_LINK)
    parser.add_argument("--relation-builder", type=Path, default=DEFAULT_RELATION_BUILDER)
    parser.add_argument("--payload", type=Path, default=DEFAULT_PAYLOAD)
    parser.add_argument("--tight-payload", type=Path, default=DEFAULT_TIGHT_PAYLOAD)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_PROJECTION_MATERIALIZATION_FRONTIER_SUMMARY "
        f"status={summary['status']} out={args.out}"
    )
    return 0 if summary["status"] == "projection_materialization_frontier_recovered" else 1


if __name__ == "__main__":
    raise SystemExit(main())
