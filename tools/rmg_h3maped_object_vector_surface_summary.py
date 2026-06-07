#!/usr/bin/env python3
"""Classify H3MapEd generator object-vector surfaces.

This is a recovery aid, not a native RMG validator. It records source-backed
static evidence for the generator object-record vector around +0xec4/+0xec8/
+0xecc and names the remaining ordered-replay gap explicitly.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_OUT = Path(".artifacts/rmg_recovery/object_vector_surface_summary.json")
DEFAULT_ROOT = Path(".artifacts/rmg_recovery")


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8") if path.exists() else ""


def has_all(text: str, needles: list[str]) -> bool:
    return all(needle in text for needle in needles)


def classify_4a54a7(root: Path) -> dict[str, Any]:
    path = root / "ghidra_object_commit_projection_vector_dump/target_004a54a7_FUN_004a54a7.txt"
    text = read_text(path)
    evidence = {
        "stamps_object_footprint": "004a54d1: CALL 0x0049abd6" in text,
        "reads_generator_object_vector_end": "004a54dd: MOV EAX,dword ptr [ESI + 0xecc]" in text,
        "uses_generator_object_vector_anchor": "004a54e3: LEA ECX,[ESI + 0xec4]" in text,
        "appends_object_vector_record": "004a54ea: CALL 0x0042d8d8" in text,
        "increments_descriptor_type_counter": "004a54fa: INC dword ptr [ESI + EDI*0x4 + 0x1110]" in text,
    }
    return {
        "entry": "0x004a54a7",
        "name": "object_footprint_commit_and_local_owner_projection",
        "classification": "object_vector_producer_append",
        "dump": str(path),
        "dump_exists": path.exists(),
        "static_contract_recovered": all(evidence.values()),
        "evidence": evidence,
        "contract": [
            "Receives generator/context in ecx and an object record plus candidate coordinate triple on the stack.",
            "Commits the object footprint through 0x49abd6.",
            "Appends a record to the generator object-record vector anchored at +0xec4, with begin/end observed at +0xec8/+0xecc.",
            "Updates generator+0x1110 descriptor-type counters and then may run a local GeneratedCell+0x20 low-word projection path.",
        ],
        "remaining_gap": "Needs same-run ordered replay of the appended record payload and its later consumer.",
    }


def classify_4add76(root: Path) -> dict[str, Any]:
    path = root / "ghidra_object_commit_projection_vector_dump/caller_004add76_FUN_004add76.txt"
    text = read_text(path)
    evidence = {
        "reads_generator_object_vector_begin": "004add90: MOV EAX,dword ptr [EBX + 0xec8]" in text,
        "reads_generator_object_vector_end": "004add98: MOV ESI,dword ptr [EBX + 0xecc]" in text,
        "compares_vector_entry_to_record": "004adda5: CMP dword ptr [EAX],EDX" in text,
        "uses_generator_object_vector_anchor": "004addb3: LEA ECX,[EBX + 0xec4]" in text,
        "erases_matching_vector_entry": "004addb9: CALL 0x004cce95" in text,
        "decrements_descriptor_type_counter": "004addc4: DEC dword ptr [EBX + ECX*0x4 + 0x1110]" in text,
    }
    return {
        "entry": "0x004add76",
        "name": "object_vector_uncommit_cleanup",
        "classification": "object_vector_cleanup_erase_consumer",
        "dump": str(path),
        "dump_exists": path.exists(),
        "static_contract_recovered": all(evidence.values()),
        "evidence": evidence,
        "contract": [
            "Scans generator object-record vector entries from +0xec8 to +0xecc.",
            "Finds an entry whose first dword matches the object record argument.",
            "Erases the matching entry through 0x4cce95 on the +0xec4 vector anchor.",
            "Decrements the matching descriptor-type counter at generator+0x1110.",
        ],
        "runtime_status": (
            "Bounded direct-generation trace .artifacts/rmg_recovery/projection_4add76_trace_summary.json "
            "recorded zero hits at 0x4add76/0x4adef7 for the sampled span."
        ),
        "remaining_gap": "Vector erase edge behavior remains same-run replay-pending.",
    }


def classify_4af910(root: Path) -> dict[str, Any]:
    path = root / "ghidra_499ee8_cell_reference_removal_dump/caller_004af910_FUN_004af910.txt"
    text = read_text(path)
    evidence = {
        "reads_generator_object_vector_end": "004af987: MOV ECX,dword ptr [EBX + 0xecc]" in text,
        "reads_generator_object_vector_begin": "004af98d: MOV EAX,dword ptr [EBX + 0xec8]" in text,
        "compares_vector_entry_to_record": "004af997: CMP dword ptr [EAX],EDI" in text,
        "uses_generator_object_vector_anchor": "004af9a5: LEA ECX,[EBX + 0xec4]" in text,
        "erases_matching_vector_entry": "004af9ab: CALL 0x004cce95" in text,
        "reads_source_handler": "004af9b0: MOV ECX,dword ptr [EBX + 0xed8]" in text,
        "calls_decor_budget_pass": "004afa8f: CALL 0x0049eb8d" in text,
    }
    return {
        "entry": "0x004af910",
        "name": "pending_object_cleanup_flush_then_decor_budget_pass",
        "classification": "pending_cleanup_object_vector_erase_then_phase_handoff",
        "dump": str(path),
        "dump_exists": path.exists(),
        "static_contract_recovered": all(evidence.values()),
        "evidence": evidence,
        "contract": [
            "Optionally walks pending entries and removes accepted object records from the generator object-record vector.",
            "Uses the same +0xec4/+0xec8/+0xecc object-vector surface as 0x4a54a7 and 0x4add76.",
            "Calls the source handler at generator+0xed8 and erases pending entries at +0xeec/+0xef0/+0xef4.",
            "Hands off to 0x49eb8d after cleanup.",
        ],
        "remaining_gap": "Needs a live owning caller/action and same-run replay of pending-entry order.",
    }


def classify_4a79a3(root: Path) -> dict[str, Any]:
    path = root / "ghidra_coord12_candidate_vector_helper_dump/caller_004a79a3_FUN_004a79a3.txt"
    text = read_text(path)
    evidence = {
        "reads_generator_object_vector_begin": "004a7d2c: MOV EAX,dword ptr [EBX + 0xec8]" in text,
        "branches_on_empty_vector": "004a7d34: JZ 0x004a7d99" in text,
        "reads_generator_object_vector_end": "004a7d36: MOV EDX,dword ptr [EBX + 0xecc]" in text,
        "computes_dword_record_count": has_all(
            text,
            [
                "004a7d3c: SUB EDX,EAX",
                "004a7d3e: SAR EDX,0x2",
            ],
        ),
        "calls_lookup_helper": "004a7dec: CALL 0x0049b3fb" in text,
    }
    return {
        "entry": "0x004a79a3",
        "name": "connection_postprocess_object_vector_consumer",
        "classification": "phase_consumer_object_vector_count_and_lookup",
        "dump": str(path),
        "dump_exists": path.exists(),
        "static_contract_recovered": all(evidence.values()),
        "evidence": evidence,
        "contract": [
            "Called by 0x4a8c15 after 0x4a4c8e, source scans, relation projection, and 0x4a4fc5.",
            "Reads generator object-vector begin/end from +0xec8/+0xecc.",
            "Computes a dword-entry count as (end - begin) / 4 before later post-processing.",
            "Uses 0x49b3fb lookup surfaces while building connection/blocker/guard post-processing state.",
        ],
        "remaining_gap": (
            "This is the next live replay candidate: capture the vector count and surrounding generated-cell "
            "state in the same run to connect producer/cleanup state to connection post-processing."
        ),
    }


def summarize(root: Path) -> dict[str, Any]:
    surfaces = [
        classify_4a54a7(root),
        classify_4add76(root),
        classify_4af910(root),
        classify_4a79a3(root),
    ]
    invariants = {
        "producer_surface_recovered": surfaces[0]["static_contract_recovered"],
        "cleanup_surfaces_recovered": surfaces[1]["static_contract_recovered"] and surfaces[2]["static_contract_recovered"],
        "phase_consumer_surface_recovered": surfaces[3]["static_contract_recovered"],
        "no_native_behavior_change": True,
    }
    return {
        "schema_id": "h3maped_object_vector_surface_summary_v1",
        "status": "partial_recovery_object_vector_surface_static_classified"
        if all(invariants.values())
        else "incomplete",
        "root": str(root),
        "invariants": invariants,
        "surfaces": surfaces,
        "current_ordered_replay_gap": (
            "Static source-backed contracts now classify object-vector append, cleanup/erase, pending cleanup, "
            "and post-phase count consumption. The missing recovery is same-run ordered replay of the +0xec4/"
            "+0xec8/+0xecc object-vector payload through 0x4a79a3 and the later GeneratedCell mutation phases."
        ),
        "next_trace_target": {
            "primary": "0x004a79a3",
            "supporting_sites": ["0x004a7d2c", "0x004a7d36", "0x004af910", "0x0049eb8d"],
            "reason": (
                "0x4add76 was a bounded no-hit cleanup candidate, while 0x4a79a3 consumes the accumulated "
                "object-vector state after earlier phases and is in the 0x4a8c15 ordered phase chain."
            ),
        },
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args.root)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_OBJECT_VECTOR_SURFACE_SUMMARY "
        f"status={summary['status']} out={args.out}"
    )
    return 0 if summary["status"] == "partial_recovery_object_vector_surface_static_classified" else 1


if __name__ == "__main__":
    raise SystemExit(main())
