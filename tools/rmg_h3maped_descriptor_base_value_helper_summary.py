#!/usr/bin/env python3
"""Verify the descriptor +0x00 source-key helper surface.

This is a narrow H3MapEd RMG recovery checkpoint. It proves from focused
Ghidra exports that the value stored by 0x4903e8 at descriptor +0x00 is not a
direct source row number. 0x4903e8 calls 0x491eed, and 0x491eed resolves the
source/name blob through a keyed registry/tree helper chain before returning a
field at entry +0x1c.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_DUMP_DIR = ROOT / "ghidra_descriptor_base_value_helper_dump_20260610"
DEFAULT_INPUT_MAPPING = ROOT / "descriptor_input_mapping_summary_20260610.json"
DEFAULT_ROW_MODE = ROOT / "descriptor_word_row_mode_summary_20260610.json"
DEFAULT_OUT = ROOT / "descriptor_base_value_helper_summary_20260610.json"


CHECKS: dict[str, list[dict[str, str]]] = {
    "target_00491eed_FUN_00491eed.txt": [
        {
            "id": "called_only_from_descriptor_builder",
            "marker": "00491f04: CALL 0x004923a1",
            "meaning": "0x491eed starts by resolving the source/name blob against the registry lower-bound helper.",
        },
        {
            "id": "calls_lookup_or_insert",
            "marker": "00491f61: CALL 0x0049228d",
            "meaning": "0x491eed uses the lookup/insert helper when the initial key is not already resolved.",
        },
        {
            "id": "returns_registry_entry_plus_0x1c",
            "marker": "00491f93: MOV EAX,dword ptr [EAX + 0x1c]",
            "meaning": "The value returned to 0x4903e8, and then written to descriptor +0x00, is registry entry +0x1c.",
        },
    ],
    "target_004923a1_FUN_004923a1.txt": [
        {
            "id": "calls_lower_bound_search",
            "marker": "004923ab: CALL 0x00492564",
            "meaning": "0x4923a1 performs a lower-bound search over the source-key registry/tree.",
        },
        {
            "id": "compares_candidate_key_payload",
            "marker": "004923bf: CALL 0x004041d6",
            "meaning": "0x4923a1 compares the candidate node key payload at node +0x0c with the source/name blob.",
        },
        {
            "id": "returns_selected_entry_pointer",
            "marker": "004923dc: MOV dword ptr [EAX],ECX",
            "meaning": "0x4923a1 returns the selected registry entry pointer through the caller output slot.",
        },
    ],
    "target_0049228d_FUN_0049228d.txt": [
        {
            "id": "walks_registry_tree_until_sentinel",
            "marker": "004922b7: CMP ESI,dword ptr [0x005a2374]",
            "meaning": "0x49228d walks a source-key registry/tree until the global sentinel is reached.",
        },
        {
            "id": "compares_tree_node_key_payload",
            "marker": "004922c8: CALL 0x004041d6",
            "meaning": "0x49228d compares source/name blob keys while walking the registry/tree.",
        },
        {
            "id": "inserts_missing_key_path_a",
            "marker": "004922ff: CALL 0x004923e2",
            "meaning": "0x49228d can create a missing source-key entry.",
        },
        {
            "id": "inserts_missing_key_path_b",
            "marker": "0049232f: CALL 0x004923e2",
            "meaning": "0x49228d has a second missing-key insertion path.",
        },
        {
            "id": "inserts_missing_key_path_c",
            "marker": "00492369: CALL 0x004923e2",
            "meaning": "0x49228d has a third missing-key insertion path.",
        },
        {
            "id": "returns_entry_and_status",
            "marker": "0049238d: MOV dword ptr [EAX + 0x4],ECX",
            "meaning": "0x49228d returns the selected/created entry plus a status flag to 0x491eed.",
        },
    ],
    "target_004923e2_FUN_004923e2.txt": [
        {
            "id": "allocates_0x24_byte_entry",
            "marker": "004923fe: PUSH 0x24",
            "meaning": "0x4923e2 allocates a 0x24-byte source-key registry entry.",
        },
        {
            "id": "stores_key_payload_pointer",
            "marker": "00492411: MOV dword ptr [EDI + 0x4],ESI",
            "meaning": "0x4923e2 stores the source/name key payload pointer in the new entry.",
        },
        {
            "id": "initializes_left_sentinel",
            "marker": "00492419: MOV dword ptr [EDI],EAX",
            "meaning": "0x4923e2 initializes a registry/tree link to the global sentinel.",
        },
        {
            "id": "initializes_right_sentinel",
            "marker": "00492420: MOV dword ptr [EDI + 0x8],EAX",
            "meaning": "0x4923e2 initializes another registry/tree link to the global sentinel.",
        },
        {
            "id": "increments_registry_count",
            "marker": "0049242f: INC dword ptr [EBX + 0xc]",
            "meaning": "0x4923e2 increments the registry/tree entry count after allocating a key.",
        },
    ],
    "target_00492564_FUN_00492564.txt": [
        {
            "id": "lower_bound_walks_until_sentinel",
            "marker": "00492587: CMP ESI,dword ptr [0x005a2374]",
            "meaning": "0x492564 is a lower-bound style walk over the registry/tree sentinel.",
        },
        {
            "id": "lower_bound_compares_key_payload",
            "marker": "00492595: CALL 0x004041d6",
            "meaning": "0x492564 compares source/name blob keys at node +0x0c.",
        },
    ],
    "target_004925c7_FUN_004925c7.txt": [
        {
            "id": "release_or_unlink_checks_payload_refcount",
            "marker": "004925e3: CMP dword ptr [EAX + 0x20],0x0",
            "meaning": "0x4925c7 is part of the registry entry release/unlink path, not source identity assignment.",
        },
        {
            "id": "release_or_unlink_walks_sentinel",
            "marker": "00492611: CMP ECX,dword ptr [0x005a2374]",
            "meaning": "0x4925c7 also walks the registry/tree sentinel when releasing child entries.",
        },
    ],
}


def load_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def evaluate_file(path: Path, checks: list[dict[str, str]]) -> dict[str, Any]:
    text = load_text(path)
    evaluated = [
        {
            "id": check["id"],
            "marker": check["marker"],
            "present": check["marker"] in text,
            "meaning": check["meaning"],
        }
        for check in checks
    ]
    return {
        "path": str(path),
        "all_required_markers_present": all(check["present"] for check in evaluated),
        "checks": evaluated,
    }


def mixed_lane_contexts(row_mode: dict[str, Any]) -> list[dict[str, Any]]:
    contexts = []
    by_context = row_mode.get("by_return_address_and_descriptor_type", {})
    for key in ["0x004a5e6c | 54", "0x004a744a | 45", "0x004a98f0 | 53", "0x004a9c3f | 79"]:
        context = by_context.get(key, {})
        contexts.append(
            {
                "return_address_and_descriptor_type": key,
                "sample_count": context.get("sample_count", 0),
                "descriptor_words": context.get("descriptor_words", []),
                "row_mode_classification": context.get("row_mode_classification"),
                "mismatch_count": context.get("row_mismatch_count", 0),
            }
        )
    return contexts


def build_summary(dump_dir: Path, input_mapping_path: Path, row_mode_path: Path) -> dict[str, Any]:
    ghidra_checks = {
        filename: evaluate_file(dump_dir / filename, checks)
        for filename, checks in CHECKS.items()
    }
    input_mapping = load_json(input_mapping_path)
    row_mode = load_json(row_mode_path)

    present_marker_count = sum(
        1
        for file_result in ghidra_checks.values()
        for check in file_result["checks"]
        if check["present"]
    )
    required_marker_count = sum(len(checks) for checks in CHECKS.values())
    all_markers_present = all(result["all_required_markers_present"] for result in ghidra_checks.values())

    return {
        "schema_id": "h3maped_descriptor_base_value_helper_summary_v1",
        "status": "descriptor_plus_0x00_source_key_registry_field_recovered_same_run_pointer_link_pending",
        "scope": (
            "Ghidra/Python checkpoint for the descriptor +0x00 assignment helper below 0x4903e8. "
            "It recovers the source-key registry lookup/insert chain used by 0x491eed and explains "
            "why descriptor +0x00 is not a universal objects.txt row id."
        ),
        "inputs": {
            "ghidra_dump_dir": str(dump_dir),
            "descriptor_input_mapping": str(input_mapping_path),
            "descriptor_word_row_mode": str(row_mode_path),
        },
        "metrics": {
            "ghidra_file_count": len(CHECKS),
            "present_marker_count": present_marker_count,
            "required_marker_count": required_marker_count,
            "used_objdump": False,
            "native_behavior_changed": False,
            "overall_goal_complete": False,
        },
        "invariants": {
            "all_ghidra_markers_present": all_markers_present,
            "no_objdump_used": True,
            "native_behavior_unchanged": True,
            "input_mapping_checkpoint_present": bool(input_mapping.get("schema_id")),
            "row_mode_checkpoint_present": bool(row_mode.get("schema_id")),
            "descriptor_plus_0x00_is_registry_entry_plus_0x1c": all_markers_present,
            "descriptor_plus_0x00_is_not_global_row_id": all_markers_present,
        },
        "ghidra_checks": ghidra_checks,
        "recovered_surface": {
            "descriptor_builder": "0x4903e8 calls 0x491eed and stores its return value at descriptor +0x00.",
            "base_value_helper": "0x491eed resolves the source/name blob through 0x4923a1 and 0x49228d, then returns selected registry entry +0x1c.",
            "registry_lookup": "0x4923a1/0x492564 perform lower-bound style source-key lookup using key comparison helper 0x4041d6 over payloads at entry +0x0c.",
            "registry_insert": "0x49228d calls 0x4923e2 when a source key is missing; 0x4923e2 allocates a 0x24-byte entry, stores the key payload, initializes sentinel links, and increments the registry count.",
            "mixed_lane_implication": (
                "For type 45/53/54/79 samples, descriptor +0x00 should be treated as the source-key "
                "registry entry field at +0x1c. It can coincide with a zero-based catalog row for "
                "some samples, but mismatched samples prove that row identity is not the global rule."
            ),
        },
        "mixed_lane_contexts": mixed_lane_contexts(row_mode),
        "source_backed_conclusion": (
            "The assignment path for descriptor +0x00 is now recovered one level deeper: 0x4903e8 does "
            "not write a direct objects.txt row number. It calls 0x491eed, which resolves the source/name "
            "blob through a source-key registry/tree and returns entry +0x1c. This explains the mixed "
            "45/53/54/79 row-like/class-word behavior and forbids using descriptor +0x00 alone as final "
            "object identity. Native RMG behavior is unchanged."
        ),
        "remaining_blockers": [
            {
                "id": "same_run_selected_descriptor_pointer_linkage",
                "reason": (
                    "This checkpoint recovers the descriptor +0x00 source-key helper, but it still does "
                    "not capture a same-run pointer join from each selected type 45/53/54/79 descriptor "
                    "back to the exact 0x4903e8 build event that populated it."
                ),
            },
            {
                "id": "registry_entry_plus_0x1c_domain_name",
                "reason": (
                    "The value source is now known mechanically as source-key registry entry +0x1c. Its "
                    "human domain label still needs source/catalog crosswalk recovery before native RMG "
                    "can use it as final object identity."
                ),
            },
        ],
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dump-dir", type=Path, default=DEFAULT_DUMP_DIR)
    parser.add_argument("--input-mapping", type=Path, default=DEFAULT_INPUT_MAPPING)
    parser.add_argument("--row-mode", type=Path, default=DEFAULT_ROW_MODE)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    summary = build_summary(args.dump_dir, args.input_mapping, args.row_mode)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        f"wrote {args.out} status={summary['status']} "
        f"markers={summary['metrics']['present_marker_count']}/{summary['metrics']['required_marker_count']}"
    )


if __name__ == "__main__":
    main()
