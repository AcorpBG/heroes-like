#!/usr/bin/env python3
"""Verify the H3MapEd RMG relation-normalization static frontier.

This checkpoint is intentionally narrow. It proves the instruction-backed
surface for 0x4a5767 and its 0x49a318 propagation helper from Ghidra text
exports, while keeping runtime ordered replay and human semantic names explicit
blockers before any native RMG behavior change.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_OUT = ROOT / "relation_normalization_summary_20260610.json"

FILES = {
    "normalizer_0x4a5767": ROOT
    / "ghidra_downstream_state_dump"
    / "target_004a5767_FUN_004a5767.txt",
    "normalizer_refs_0x4a5767": ROOT
    / "ghidra_downstream_state_dump"
    / "target_004a5767_references.txt",
    "propagation_helper_0x49a318": ROOT
    / "ghidra_downstream_helper_dump"
    / "target_0049a318_FUN_0049a318.txt",
    "propagation_refs_0x49a318": ROOT
    / "ghidra_downstream_helper_dump"
    / "target_0049a318_references.txt",
}

CHECKS: dict[str, list[dict[str, str]]] = {
    "normalizer_0x4a5767": [
        {
            "id": "captures_generator_context",
            "marker": "004a576e: MOV EBX,ECX",
            "meaning": "0x4a5767 receives the generator/context pointer in ECX.",
        },
        {
            "id": "reads_generated_cell_level_count",
            "marker": "004a5772: MOV EAX,dword ptr [EBX + 0x20]",
            "meaning": "The full-grid reset uses generator +0x20 as one dimension/count.",
        },
        {
            "id": "reads_generated_cell_buffer",
            "marker": "004a5775: MOV ESI,dword ptr [EBX + 0x14]",
            "meaning": "The generated-cell buffer begins at generator +0x14.",
        },
        {
            "id": "multiplies_grid_dimensions",
            "marker": "004a5778: IMUL EAX,dword ptr [EBX + 0x1c]",
            "meaning": "The reset count is derived from generator dimensions.",
        },
        {
            "id": "multiplies_grid_width",
            "marker": "004a577c: IMUL EAX,dword ptr [EBX + 0x18]",
            "meaning": "The reset count includes the remaining grid dimension.",
        },
        {
            "id": "normalizes_cell_projection_helper",
            "marker": "004a57ab: CALL 0x004a59e2",
            "meaning": "Each generated cell is initialized through 0x4a59e2.",
        },
        {
            "id": "forces_local_gate_word",
            "marker": "004a57bf: MOV dword ptr [ESI + 0x1c],EAX",
            "meaning": "The generated-cell +0x1c projection/local dword is rewritten during reset.",
        },
        {
            "id": "reads_relation_vector_begin",
            "marker": "004a57d1: MOV EAX,dword ptr [EBX + 0x10e4]",
            "meaning": "Relation pointer vector begin is generator +0x10e4.",
        },
        {
            "id": "reads_relation_vector_end",
            "marker": "004a57df: MOV ECX,dword ptr [EBX + 0x10e8]",
            "meaning": "Relation pointer vector end is generator +0x10e8.",
        },
        {
            "id": "copies_relation_scan_bounds",
            "marker": "004a5808: LEA ESI,[EDX + 0x20]",
            "meaning": "Relation +0x20..+0x2f are copied as scan bounds.",
        },
        {
            "id": "copies_relation_coordinate_triple",
            "marker": "004a580f: LEA ESI,[EDX + 0x10]",
            "meaning": "Relation +0x10..+0x1b are copied as a 12-byte coordinate/range triple.",
        },
        {
            "id": "filters_generated_cell_owner_byte2",
            "marker": "004a585c: MOV ECX,dword ptr [EAX + 0x20]",
            "meaning": "The first relation-local scan reads generated-cell +0x20 owner/score data.",
        },
        {
            "id": "filters_generated_cell_terrain",
            "marker": "004a586a: MOV ECX,dword ptr [EAX + 0x24]",
            "meaning": "The scan checks generated-cell +0x24 terrain/type bits.",
        },
        {
            "id": "filters_object_reference_vector",
            "marker": "004a587b: MOV ECX,dword ptr [EAX + 0x4]",
            "meaning": "Object-reference vector occupancy at +0x04/+0x08 gates candidates.",
        },
        {
            "id": "filters_bit27_occupancy",
            "marker": "004a588f: MOV ECX,dword ptr [EAX + 0x28]",
            "meaning": "Generated-cell +0x28 bit27 participates in the candidate gate.",
        },
        {
            "id": "calls_occupancy_predicate",
            "marker": "004a58a5: CALL 0x0049a1d8",
            "meaning": "0x49a1d8 is part of the first relation-local acceptance gate.",
        },
        {
            "id": "sets_missing_candidate_block_bit",
            "marker": "004a58f1: CALL 0x0049a932",
            "meaning": "When no candidate is found, the shell calls 0x49a932(true) on a derived generated cell.",
        },
        {
            "id": "calls_first_projection_propagation",
            "marker": "004a590f: CALL 0x0049a318",
            "meaning": "The first propagation pass delegates to 0x49a318.",
        },
        {
            "id": "second_scan_requires_local_gate",
            "marker": "004a597b: TEST word ptr [ESI + 0x1c],0xffff",
            "meaning": "The second scan requires a nonzero generated-cell +0x1c low word.",
        },
        {
            "id": "calls_connection_object_selection",
            "marker": "004a599c: CALL 0x004a5a23",
            "meaning": "Valid occupied cells in the second scan are passed to 0x4a5a23.",
        },
        {
            "id": "calls_second_projection_propagation",
            "marker": "004a59ba: CALL 0x0049a318",
            "meaning": "The second propagation pass delegates to 0x49a318 again.",
        },
    ],
    "normalizer_refs_0x4a5767": [
        {
            "id": "called_by_candidate_adoption",
            "marker": "from=004ac7bf type=UNCONDITIONAL_CALL caller=FUN_004ac552",
            "meaning": "0x4ac552 calls the normalizer.",
        },
        {
            "id": "called_by_downstream_phase",
            "marker": "from=004a8d14 type=UNCONDITIONAL_CALL caller=FUN_004a8c15",
            "meaning": "0x4a8c15 calls the normalizer.",
        },
        {
            "id": "called_by_endpoint_writer",
            "marker": "from=004a74a5 type=UNCONDITIONAL_CALL caller=FUN_004a746b",
            "meaning": "0x4a746b calls the normalizer before endpoint selection.",
        },
    ],
    "propagation_helper_0x49a318": [
        {
            "id": "receives_grid_wrapper_context",
            "marker": "0049a32d: MOV EBX,ECX",
            "meaning": "0x49a318 receives the generated-cell grid wrapper in ECX.",
        },
        {
            "id": "reads_source_cell_owner_byte2",
            "marker": "0049a36e: MOV EAX,dword ptr [ESI + 0x20]",
            "meaning": "The helper reads the source generated-cell +0x20 owner/score dword.",
        },
        {
            "id": "seeds_coordinate_work_vector",
            "marker": "0049a37f: CALL 0x004ae20e",
            "meaning": "The input coordinate seeds a 12-byte local coordinate work vector.",
        },
        {
            "id": "appends_initial_work_coordinate",
            "marker": "0049a391: CALL 0x0042d8d8",
            "meaning": "The first work coordinate is appended to the vector.",
        },
        {
            "id": "clears_source_low_word",
            "marker": "0049a3a2: AND word ptr [ESI + 0x1c],DI",
            "meaning": "The source cell +0x1c low word is cleared.",
        },
        {
            "id": "writes_source_projection_triple",
            "marker": "0049a3a6: LEA EDI,[ESI + 0x10]",
            "meaning": "The source cell +0x10/+0x14/+0x18 projection triple is rewritten.",
        },
        {
            "id": "pops_work_coordinate",
            "marker": "0049a401: CALL 0x004ae23e",
            "meaning": "The helper pops/scans coordinates from the work vector.",
        },
        {
            "id": "erases_work_coordinate",
            "marker": "0049a410: CALL 0x004cce95",
            "meaning": "The consumed coordinate is erased from the local work vector.",
        },
        {
            "id": "reads_bit22_policy",
            "marker": "0049a439: MOV ECX,dword ptr [ESI + 0x28]",
            "meaning": "Generated-cell +0x28 bit22 controls the five/eight-direction policy.",
        },
        {
            "id": "reads_descriptor_policy_table_pointer",
            "marker": "0049a44a: MOV EDX,dword ptr [0x0057c648]",
            "meaning": "Object descriptor policy data is read from the 0x57c648 table.",
        },
        {
            "id": "uses_direction_offset_table",
            "marker": "0049a48a: LEA ECX,[EDI*0x8 + 0x5a2658]",
            "meaning": "Direction offsets come from the 0x5a2658 table.",
        },
        {
            "id": "bounds_checks_candidate_x",
            "marker": "0049a4c9: CMP EDX,ESI",
            "meaning": "Candidate x is bounds-checked against grid width.",
        },
        {
            "id": "requires_candidate_bit25",
            "marker": "0049a50d: TEST EDI,0x2000000",
            "meaning": "Candidate cells must have bit25 set.",
        },
        {
            "id": "rejects_terrain_9",
            "marker": "0049a51f: CMP ECX,0x9",
            "meaning": "Terrain/type id 9 is rejected.",
        },
        {
            "id": "applies_descriptor_policy_gate",
            "marker": "0049a54b: CMP byte ptr [ECX],0x0",
            "meaning": "Bit22 object cells apply descriptor-table policy gates.",
        },
        {
            "id": "updates_candidate_high_word",
            "marker": "0049a5b6: OR ECX,ESI",
            "meaning": "Different-owner propagation updates the high word of candidate +0x1c.",
        },
        {
            "id": "packs_direction_bits",
            "marker": "0049a5da: MOV dword ptr [EAX + 0x28],ESI",
            "meaning": "The direction ordinal is packed into generated-cell +0x28 bits.",
        },
        {
            "id": "writes_source_owner_into_candidate",
            "marker": "0049a5e2: MOV dword ptr [EAX + 0x20],ECX",
            "meaning": "The source owner byte is propagated into candidate +0x20 byte3.",
        },
        {
            "id": "checks_policy_boolean_for_zero_score",
            "marker": "0049a62d: CMP byte ptr [EBP + 0x14],0x0",
            "meaning": "The stack policy boolean participates in zero-score handling.",
        },
        {
            "id": "writes_same_owner_projection_triple",
            "marker": "0049a63a: LEA EDI,[EAX + 0x10]",
            "meaning": "Same-owner candidates receive the current coordinate in +0x10/+0x14/+0x18.",
        },
        {
            "id": "writes_same_owner_low_word",
            "marker": "0049a64f: MOV dword ptr [EAX + 0x1c],EDX",
            "meaning": "Same-owner propagation updates the low word of candidate +0x1c.",
        },
        {
            "id": "inserts_sorted_score",
            "marker": "0049a695: CALL 0x004ccecb",
            "meaning": "Propagated scores are inserted into a sorted dword vector.",
        },
        {
            "id": "inserts_followup_coordinate",
            "marker": "0049a6ad: CALL 0x00430b35",
            "meaning": "Accepted candidate coordinates are inserted back into the work vector.",
        },
    ],
    "propagation_refs_0x49a318": [
        {
            "id": "first_called_by_0x4a5767",
            "marker": "from=004a590f type=UNCONDITIONAL_CALL caller=FUN_004a5767",
            "meaning": "0x4a5767 calls 0x49a318 after the first relation-local scan.",
        },
        {
            "id": "second_called_by_0x4a5767",
            "marker": "from=004a59ba type=UNCONDITIONAL_CALL caller=FUN_004a5767",
            "meaning": "0x4a5767 calls 0x49a318 after the second relation-local scan.",
        },
        {
            "id": "also_called_by_0x4a89da",
            "marker": "from=004a8b1a type=UNCONDITIONAL_CALL caller=FUN_004a89da",
            "meaning": "0x49a318 is also used by 0x4a89da.",
        },
    ],
}


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""


def summarize_file(key: str, path: Path) -> dict[str, Any]:
    text = read_text(path)
    checks = [{**check, "present": check["marker"] in text} for check in CHECKS[key]]
    return {
        "path": str(path),
        "exists": path.exists(),
        "check_count": len(checks),
        "present_check_count": sum(1 for check in checks if check["present"]),
        "checks": checks,
    }


def summarize() -> dict[str, Any]:
    files = {key: summarize_file(key, path) for key, path in FILES.items()}
    all_checks = [check for result in files.values() for check in result["checks"]]
    missing = [check["id"] for check in all_checks if not check["present"]]
    status = (
        "relation_normalization_static_surface_recovered_runtime_replay_pending"
        if not missing
        else "incomplete"
    )

    return {
        "schema_id": "h3maped_relation_normalization_summary_v1",
        "status": status,
        "scope": (
            "Ghidra/Python checkpoint for the 0x4a5767 relation-local generated-cell "
            "normalizer and 0x49a318 owner/projection propagation helper. This proves "
            "static instruction-backed state surfaces only; runtime ordered replay and "
            "human semantic names remain blockers before native RMG behavior changes."
        ),
        "inputs": {"ghidra_files": {key: str(path) for key, path in FILES.items()}},
        "files": files,
        "recovered": [
            "0x4a5767 resets all generated cells through 0x4a59e2, forces the +0x1c projection/local gate, and writes the +0x10/+0x14/+0x18 projection triple.",
            "0x4a5767 walks the relation vector at generator+0x10e4..+0x10e8, copies relation +0x20 bounds and +0x10 coordinate/range triple, and filters generated cells by owner byte2, terrain, object-reference occupancy, bit27, and 0x49a1d8.",
            "0x4a5767 calls 0x49a932(true) when the first relation-local scan finds no candidate, then calls 0x49a318; during the second scan it calls 0x4a5a23 for valid occupied cells and calls 0x49a318 again.",
            "0x49a318 clears the source cell low +0x1c word, writes -1/-1/-1 to source +0x10/+0x14/+0x18, and maintains local coordinate and score work vectors.",
            "0x49a318 scans direction offsets from 0x5a2658 with five/eight-direction policy affected by bit22 and descriptor policy table 0x57c648.",
            "0x49a318 rejects candidates by bounds, owner word, missing bit25, terrain 9, and descriptor-table gates; accepted candidates mutate +0x1c, +0x20, +0x28, and +0x10/+0x14/+0x18 according to same-owner versus different-owner propagation.",
        ],
        "remaining_gap": (
            "Runtime ordered replay of 0x4a5767/0x49a318 remains pending, along with human "
            "semantic names for propagated scores, owner-byte roles, descriptor policy bytes, "
            "and relation-field roles. The Border Guard relation byte +0x09 is already recovered "
            "as the template connection Border Guard flag; the unresolved endpoint blocker is "
            "successful 0x4a5e73/0x4a606b cursor state or a source-backed exclusion, not that flag."
        ),
        "metrics": {
            "marker_count": len(all_checks),
            "present_marker_count": sum(1 for check in all_checks if check["present"]),
            "missing_marker_count": len(missing),
            "used_objdump": False,
            "native_behavior_changed": False,
            "overall_goal_complete": False,
        },
        "missing_markers": missing,
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize()
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    metrics = summary["metrics"]
    print(
        "RMG_H3MAPED_RELATION_NORMALIZATION "
        f"status={summary['status']} "
        f"markers={metrics['present_marker_count']}/{metrics['marker_count']} "
        f"out={args.out}"
    )
    return (
        0
        if summary["status"]
        == "relation_normalization_static_surface_recovered_runtime_replay_pending"
        else 1
    )


if __name__ == "__main__":
    raise SystemExit(main())
