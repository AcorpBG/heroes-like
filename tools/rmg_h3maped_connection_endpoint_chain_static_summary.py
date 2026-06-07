#!/usr/bin/env python3
"""Summarize the H3MapEd connection endpoint state chain.

This recovery aid links the 0x4a79a3-dispatched 0x4a696b/0x4a7605 surfaces
to their downstream endpoint helpers. It records instruction-site evidence
for the cursor/vector state that must be runtime-replayed before native RMG
connection/blocker/guard behavior can be changed.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_DISPATCH_SURFACE = DEFAULT_ROOT / "696b_7605_static_surface_summary.json"
DEFAULT_OUT = DEFAULT_ROOT / "connection_endpoint_chain_static_summary.json"

DEFAULT_5E73_DUMP = DEFAULT_ROOT / "ghidra_downstream_helper_dump/target_004a5e73_FUN_004a5e73.txt"
DEFAULT_746B_DUMP = DEFAULT_ROOT / "ghidra_downstream_state_dump/target_004a746b_FUN_004a746b.txt"
DEFAULT_7312_DUMP = DEFAULT_ROOT / "ghidra_4a7312_policy_dump/target_004a7312_FUN_004a7312.txt"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8") if path.exists() else ""


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def has_line(text: str, line: str) -> bool:
    return line in text


def classify_4a5e73(path: Path) -> dict[str, Any]:
    text = read_text(path)
    evidence = {
        "reads_current_endpoint_cursor_f5c": has_line(
            text, "004a5e85: MOV EDI,dword ptr [EBX + 0xf5c]"
        ),
        "scans_d8_dc_index_vector": has_line(
            text, "004a5e8b: MOV EDX,dword ptr [EBX + 0xd8]"
        )
        and has_line(text, "004a5e9a: MOV EAX,dword ptr [EBX + 0xdc]"),
        "matches_d8_record_word_20_to_cursor": has_line(
            text, "004a5eb4: CMP dword ptr [EAX + 0x20],EDI"
        ),
        "scans_c8_cc_index_vector": has_line(
            text, "004a5ee3: MOV EDX,dword ptr [EBX + 0xc8]"
        )
        and has_line(text, "004a5ef2: MOV EAX,dword ptr [EBX + 0xcc]"),
        "matches_c8_record_word_20_to_cursor": has_line(
            text, "004a5f0c: CMP dword ptr [EAX + 0x20],EDI"
        ),
        "allocates_and_initializes_d8_record_then_calls_4a7312": has_line(
            text, "004a5f46: CALL 0x005044b1"
        )
        and has_line(text, "004a5f5a: CALL 0x0049ba89")
        and has_line(text, "004a5f6f: CALL 0x004a7312"),
        "repeat_path_allocates_c8_records": has_line(text, "004a5f98: CALL 0x005044b1")
        and has_line(text, "004a5fb1: CALL 0x0049ba89"),
        "repeat_path_computes_generated_cell": has_line(
            text, "004a5fd5: ADD ECX,dword ptr [EBX + 0x14]"
        ),
        "repeat_path_clears_cell_2c_low_five_bits": has_line(
            text, "004a5fd8: AND dword ptr [ECX + 0x2c],0xffffffe0"
        ),
        "repeat_path_sets_bit27_and_clears_bit26": has_line(
            text, "004a5fe5: AND EDX,0xfbffffff"
        )
        and has_line(text, "004a5feb: OR EDX,0x8000000")
        and has_line(text, "004a5ff1: MOV dword ptr [ECX + 0x28],EDX"),
        "repeat_path_calls_generator_vtable_slot_04": has_line(
            text, "004a6004: CALL dword ptr [EDX + 0x4]"
        ),
        "marks_byte_state_and_advances_cursor": has_line(
            text, "004a6018: MOV byte ptr [EAX + EDI*0x1],0x1"
        )
        and has_line(text, "004a601c: AND dword ptr [EBX + 0xf5c],0x0")
        and has_line(text, "004a6023: MOV ECX,dword ptr [EBX + 0x1104]")
        and has_line(text, "004a6031: MOV EAX,dword ptr [EBX + 0x1108]")
        and has_line(text, "004a6050: MOV dword ptr [EBX + 0xf5c],ECX"),
    }
    return {
        "entry": "0x004a5e73",
        "name": "endpoint_cursor_vector_projector",
        "dump": str(path),
        "dump_exists": path.exists(),
        "static_contract_recovered": path.exists() and all(evidence.values()),
        "evidence": evidence,
        "contract": [
            "Uses generator+0xf5c as the current endpoint/index cursor.",
            "Requires a matching +0xd8/+0xdc entry whose dereferenced record +0x20 equals the cursor.",
            "Then requires a matching +0xc8/+0xcc entry whose dereferenced record +0x20 equals the same cursor.",
            "Allocates a +0xd8-derived 0x1c-byte record, validates it through 0x4a7312, and aborts with -1 on validation failure.",
            "For positive repeat/count, allocates +0xc8-derived 0x1c-byte records, clears generated-cell +0x2c low five bits, sets bit27 and clears bit26 in +0x28, calls generator vtable slot +0x04, and increments x for each repeat.",
            "Marks generator+0x1104[original cursor] = 1, resets generator+0xf5c to zero, then advances it while the +0x1104 byte-state vector remains marked.",
        ],
    }


def classify_4a746b(path: Path) -> dict[str, Any]:
    text = read_text(path)
    evidence = {
        "normalizes_grid_before_endpoint_selection": has_line(text, "004a74a5: CALL 0x004a5767"),
        "derives_source_cell_and_reads_state": has_line(
            text, "004a74c3: ADD EAX,dword ptr [EBX + 0x14]"
        )
        and has_line(text, "004a74c6: MOV ECX,dword ptr [EAX + 0x20]")
        and has_line(text, "004a74c9: MOV ESI,dword ptr [EAX + 0x1c]"),
        "rejects_low_word_at_or_above_7530": has_line(text, "004a74d8: CMP ESI,0x7530"),
        "uses_projection_triple_when_low_word_positive": has_line(
            text, "004a74eb: LEA ESI,[EAX + 0x10]"
        ),
        "tests_five_local_offsets_for_owner_and_bit27": has_line(
            text, "004a7544: CMP EAX,ECX"
        )
        and has_line(text, "004a7548: MOV EAX,dword ptr [ESI + 0x28]")
        and has_line(text, "004a754e: TEST AL,0x1")
        and has_line(text, "004a7559: CMP dword ptr [EBP + -0x4],0x5"),
        "falls_back_to_y_plus_one": has_line(text, "004a7571: INC EAX"),
        "calls_4a5e73_with_selected_endpoint": has_line(text, "004a7593: CALL 0x004a5e73"),
        "stamps_five_endpoint_offsets_with_49aa63": has_line(
            text, "004a75dc: CALL 0x0049aa63"
        ),
        "packs_low_nibble_result_into_cell_2c": has_line(text, "004a759f: AND EAX,0xf")
        and has_line(text, "004a75a5: ADD EAX,EAX")
        and has_line(text, "004a75e7: AND AL,0xe1")
        and has_line(text, "004a75e9: OR EAX,dword ptr [EBP + -0x8]")
        and has_line(text, "004a75ec: OR AL,0x1")
        and has_line(text, "004a75f1: MOV dword ptr [ESI + 0x2c],EAX"),
    }
    return {
        "entry": "0x004a746b",
        "name": "endpoint_normalize_then_low_nibble_stamper",
        "dump": str(path),
        "dump_exists": path.exists(),
        "static_contract_recovered": path.exists() and all(evidence.values()),
        "evidence": evidence,
        "contract": [
            "Calls 0x4a5767 before endpoint selection.",
            "Rejects immediately when the source cell +0x1c low word is at least 0x7530.",
            "Uses the source cell projection triple when the low word is positive.",
            "Otherwise scans five local endpoint offsets for matching owner byte and bit27, with fallback to (x, y + 1, level).",
            "Calls 0x4a5e73 for the selected endpoint and, on nonnegative result, stamps five endpoint-offset cells through 0x49aa63(true).",
            "Writes cell+0x2c = (old & 0xffffffe1) | ((result & 0x0f) << 1) | 1 on stamped cells.",
        ],
    }


def classify_4a7312(path: Path) -> dict[str, Any]:
    text = read_text(path)
    evidence = {
        "reads_object_descriptor_and_source_relation": has_line(
            text, "004a7329: MOV EAX,dword ptr [EAX + 0x4]"
        )
        and has_line(text, "004a7341: MOV EBX,dword ptr [EBP + 0xc]")
        and has_line(text, "004a734a: LEA ESI,[EBX + 0x20]"),
        "reads_descriptor_dimensions": has_line(text, "004a735b: MOV ECX,dword ptr [EAX + 0x38]")
        and has_line(text, "004a735e: MOV EAX,dword ptr [EAX + 0x34]"),
        "copies_source_coordinate_triple": has_line(text, "004a7372: LEA ESI,[EBX + 0x10]"),
        "computes_candidate_cell_and_owner_byte": has_line(
            text, "004a73b2: MOV EAX,dword ptr [EAX + EDX*0x1 + 0x20]"
        )
        and has_line(text, "004a73bc: CMP EAX,dword ptr [EBP + 0xc]"),
        "filters_candidate_through_49aa93": has_line(text, "004a73d0: CALL 0x0049aa93"),
        "appends_accepted_candidate_coordinate": has_line(text, "004a73e0: CALL 0x004ae1fd"),
        "rejects_empty_candidate_vector": has_line(text, "004a7417: XOR BL,BL"),
        "selects_candidate_by_rng_mod_count": has_line(text, "004a741b: CALL 0x004e7276")
        and has_line(text, "004a7425: DIV ESI"),
        "calls_generator_vtable_slot_04_with_selected_candidate": has_line(
            text, "004a7447: CALL dword ptr [EDX + 0x4]"
        ),
        "destroys_candidate_vector": has_line(text, "004a7453: CALL 0x0042c92d"),
    }
    return {
        "entry": "0x004a7312",
        "name": "source_bounded_endpoint_candidate_picker",
        "dump": str(path),
        "dump_exists": path.exists(),
        "static_contract_recovered": path.exists() and all(evidence.values()),
        "evidence": evidence,
        "contract": [
            "Reads the object descriptor through record+0x04 and descriptor dimensions +0x34/+0x38.",
            "Copies source/relation bounds from +0x20..+0x2c and the source coordinate triple from +0x10..+0x18.",
            "Scans candidate x/y coordinates within those bounds, rejecting cells whose +0x20 owner byte does not match the source/relation id.",
            "Calls 0x49aa93 for candidate eligibility and appends accepted 12-byte coordinates through 0x4ae1fd.",
            "Rejects when the candidate vector is empty, otherwise selects one candidate by 0x4e7276 % candidate_count.",
            "Calls generator vtable slot +0x04 with the selected coordinate and object record, then destroys the candidate vector through 0x42c92d.",
        ],
    }


def summarize(dump_5e73: Path, dump_746b: Path, dump_7312: Path, dispatch_surface: Path) -> dict[str, Any]:
    dispatch = load_json(dispatch_surface)
    surface_status = dispatch.get("status")
    surfaces = [classify_4a5e73(dump_5e73), classify_4a746b(dump_746b), classify_4a7312(dump_7312)]
    invariants = {
        "prior_696b_7605_static_surface_recovered": (
            surface_status == "partial_static_recovery_696b_7605_mutation_surface"
        ),
        "endpoint_cursor_projector_surface_recovered": surfaces[0]["static_contract_recovered"],
        "endpoint_low_nibble_stamper_surface_recovered": surfaces[1]["static_contract_recovered"],
        "source_bounded_candidate_picker_surface_recovered": surfaces[2]["static_contract_recovered"],
        "no_native_behavior_change": True,
    }
    status = (
        "partial_static_recovery_connection_endpoint_state_chain"
        if all(invariants.values())
        else "incomplete"
    )
    return {
        "schema_id": "h3maped_connection_endpoint_chain_static_summary_v1",
        "status": status,
        "invariants": invariants,
        "source_artifacts": {
            "dispatch_surface": str(dispatch_surface),
            "dump_4a5e73": str(dump_5e73),
            "dump_4a746b": str(dump_746b),
            "dump_4a7312": str(dump_7312),
        },
        "surfaces": surfaces,
        "recovered_contract": (
            "The 0x4a79a3-dispatched connection path now has a checked static downstream chain: "
            "0x4a5e73 consumes generator+0xf5c plus +0xd8/+0xdc and +0xc8/+0xcc cursor-keyed vectors, "
            "projects repeated +0xc8 records into generated cells while clearing bit26 and setting bit27, "
            "then marks/advances generator+0x1104/+0x1108. 0x4a746b normalizes through 0x4a5767, selects "
            "an endpoint from source projection, five local offsets, or y+1 fallback, and packs the 0x4a5e73 "
            "low-nibble result into GeneratedCell+0x2c. 0x4a7312 selects one source-bounded candidate through "
            "0x49aa93 filtering and 0x4e7276 % candidate_count before calling generator vtable slot +0x04."
        ),
        "next_runtime_replay_targets": [
            "0x4a5e73 entry/return: capture generator+0xf5c, +0xd8/+0xdc, +0xc8/+0xcc, +0x1104/+0x1108, stack coordinate triple, repeat/count, and return value.",
            "0x4a5fd8/0x4a5ff1: capture generated-cell address plus +0x20/+0x24/+0x28/+0x2c before and after the repeat projection mutation.",
            "0x4a746b entry/0x4a7593/0x4a75f1: capture source cell, selected endpoint, five stamped offset cells, and packed low-nibble writes.",
            "0x4a7312 entry/0x4a73e0/0x4a7447: capture source/relation record fields, candidate vector contents, RNG result, selected coordinate, and generator vtable object record.",
        ],
        "remaining_gap": (
            "This is still static recovery. Full end-to-end recovery requires same-run ordered replay of the "
            "listed runtime targets and exact semantic names for the +0xd8/+0xc8 vector records, source/relation "
            "records, candidate vectors, and generated-cell before/after state."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dump-5e73", type=Path, default=DEFAULT_5E73_DUMP)
    parser.add_argument("--dump-746b", type=Path, default=DEFAULT_746B_DUMP)
    parser.add_argument("--dump-7312", type=Path, default=DEFAULT_7312_DUMP)
    parser.add_argument("--dispatch-surface", type=Path, default=DEFAULT_DISPATCH_SURFACE)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args.dump_5e73, args.dump_746b, args.dump_7312, args.dispatch_surface)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_CONNECTION_ENDPOINT_CHAIN_STATIC_SUMMARY status={summary['status']} out={args.out}")
    return 0 if summary["status"] == "partial_static_recovery_connection_endpoint_state_chain" else 1


if __name__ == "__main__":
    raise SystemExit(main())
