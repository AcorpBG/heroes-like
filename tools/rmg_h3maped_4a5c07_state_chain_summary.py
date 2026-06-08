#!/usr/bin/env python3
"""Summarize the sampled 0x4a5c07 -> 0x4a54a7 state chain.

This is recovery evidence only. It joins the existing natural Medium seed-10
``0x4a7605 -> 0x4a5e03`` constructor trace with the matching ``0x4a54a7``
after-state trace, proving that sampled ``0x4a5c07`` records are ordinary
``0x540a88`` records that are stamped into the generator object vector and
target GeneratedCell through the vtable ``+0x04`` commit path.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_SIDE_EFFECT = Path(
    ".artifacts/rmg_recovery/medium_seed10_4a5e03_side_effect_summary_20260608.json"
)
DEFAULT_AFTERSTATE = Path(
    ".artifacts/rmg_recovery/medium_seed10_4a54a7_afterstate_summary_20260608.json"
)
DEFAULT_STATIC_4A5C07 = Path(
    ".artifacts/rmg_recovery/ghidra_object_projection_helper_dump/"
    "caller_004a5c07_FUN_004a5c07.txt"
)
DEFAULT_OUT = Path(".artifacts/rmg_recovery/medium_seed10_4a5c07_state_chain_summary_20260608.json")


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""


def int_from_hex(value: str | None) -> int | None:
    if value is None:
        return None
    return int(value, 16)


def has_static_4a5c07_contract(text: str) -> bool:
    return all(
        needle in text
        for needle in (
            "004a5dd1: CALL 0x0049ba89",
            "004a5dd9: MOV dword ptr [ESI],0x540a88",
            "004a5ddf: MOV dword ptr [ESI + 0x20],EAX",
            "004a5de2: MOV dword ptr [ESI + 0x24],0x3",
            "004a5de9: MOV dword ptr [ESI + 0x1c],EDI",
        )
    )


def sequence_key(sequence: dict[str, Any]) -> str:
    return str(sequence.get("sequence_name", ""))


def by_sequence(summary: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {
        sequence_key(sequence): sequence
        for sequence in summary.get("target_sequences", [])
        if sequence_key(sequence)
    }


def vector_end_advanced(after_sequence: dict[str, Any]) -> bool:
    before = after_sequence.get("commit_entry", {}).get("generator_object_vector_before", {})
    after = after_sequence.get("append_return", {}).get("generator_object_vector_after", {})
    if not before.get("end") or not after.get("end"):
        return False
    return int_from_hex(after["end"]) == (int_from_hex(before["end"]) or 0) + 4


def old_slot_contains_object(after_sequence: dict[str, Any], object_pointer: str | None) -> bool:
    words = after_sequence.get("append_return", {}).get("old_end_slot", {}).get("words", [])
    return bool(object_pointer and words and words[0] == object_pointer)


def cell_ref_contains_object(after_sequence: dict[str, Any], object_pointer: str | None) -> bool:
    words = after_sequence.get("post_return_cell", {}).get("object_ref_vector", {}).get("first_words", [])
    return bool(object_pointer and words and words[0] == object_pointer)


def low_word_cleared(side_sequence: dict[str, Any], after_sequence: dict[str, Any]) -> bool:
    before = side_sequence.get("pre_commit_cell", {}).get("generated_cell_words", {}).get("+0x20")
    after = after_sequence.get("post_return_cell", {}).get("generated_cell_words", {}).get("+0x20")
    if before is None or after is None:
        return False
    return (int(before, 16) & 0xFFFF) != 0 and (int(after, 16) & 0xFFFF) == 0


def bit22_set_or_preserved(side_sequence: dict[str, Any], after_sequence: dict[str, Any]) -> bool:
    before = side_sequence.get("pre_commit_cell", {}).get("generated_cell_words", {}).get("+0x28")
    after = after_sequence.get("post_return_cell", {}).get("generated_cell_words", {}).get("+0x28")
    if before is None or after is None:
        return False
    return (int(after, 16) & 0x00400000) != 0 and int(after, 16) != int(before, 16)


def build_sequence(side_sequence: dict[str, Any], after_sequence: dict[str, Any]) -> dict[str, Any]:
    object_record = side_sequence.get("constructed_object_record", {})
    object_pointer = object_record.get("object_record_pointer")
    commit_stack = after_sequence.get("commit_entry", {}).get("stack", {})
    side_commit = side_sequence.get("vtable_commit_callback", {})
    return {
        "sequence_name": sequence_key(side_sequence),
        "constructor_event_index": object_record.get("event_index"),
        "commit_entry_event_index": after_sequence.get("commit_entry_event_index"),
        "object_record_pointer": object_pointer,
        "constructed_object_record": object_record,
        "constructor_vtable_is_540a88": object_record.get("vtable") == "0x00540a88",
        "constructor_coordinates_unset": object_record.get("raw_words", [])[2:5]
        == ["0xffffffff", "0xffffffff", "0xffffffff"],
        "constructor_field_1c_matches_afterstate_record": object_record.get("word_plus_0x1c"),
        "side_effect_commit_callback": side_commit,
        "afterstate_commit_stack": commit_stack,
        "commit_callback_reuses_constructed_object": object_pointer
        == side_commit.get("stack_object_record_pointer")
        == commit_stack.get("object_record_pointer"),
        "commit_coordinates_match": side_commit.get("stack_coordinate") == commit_stack.get("coordinate"),
        "pre_commit_cell": side_sequence.get("pre_commit_cell"),
        "post_return_cell": after_sequence.get("post_return_cell"),
        "object_vector_before": after_sequence.get("commit_entry", {}).get("generator_object_vector_before"),
        "object_vector_after": after_sequence.get("append_return", {}).get("generator_object_vector_after"),
        "object_vector_end_advances_one_dword": vector_end_advanced(after_sequence),
        "object_vector_old_end_slot_contains_object": old_slot_contains_object(after_sequence, object_pointer),
        "target_cell_ref_vector_contains_object": cell_ref_contains_object(after_sequence, object_pointer),
        "target_cell_plus_0x20_low_word_cleared": low_word_cleared(side_sequence, after_sequence),
        "target_cell_plus_0x28_bit22_set": bit22_set_or_preserved(side_sequence, after_sequence),
    }


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    side_effect = read_json(args.side_effect)
    afterstate = read_json(args.afterstate)
    static_text = read_text(args.static_4a5c07)

    side_by_sequence = by_sequence(side_effect)
    after_by_sequence = by_sequence(afterstate)
    shared_names = sorted(set(side_by_sequence) & set(after_by_sequence))
    sequences = [
        build_sequence(side_by_sequence[name], after_by_sequence[name])
        for name in shared_names
    ]

    sequence_invariants = {
        "all_constructor_vtables_are_540a88": all(
            sequence["constructor_vtable_is_540a88"] for sequence in sequences
        ),
        "all_constructor_coordinates_start_unset": all(
            sequence["constructor_coordinates_unset"] for sequence in sequences
        ),
        "all_commit_callbacks_reuse_constructed_object": all(
            sequence["commit_callback_reuses_constructed_object"] for sequence in sequences
        ),
        "all_commit_coordinates_match": all(sequence["commit_coordinates_match"] for sequence in sequences),
        "all_object_vector_ends_advance_one_dword": all(
            sequence["object_vector_end_advances_one_dword"] for sequence in sequences
        ),
        "all_object_vector_old_slots_contain_object": all(
            sequence["object_vector_old_end_slot_contains_object"] for sequence in sequences
        ),
        "all_target_cell_refs_contain_object": all(
            sequence["target_cell_ref_vector_contains_object"] for sequence in sequences
        ),
        "all_target_cell_plus_0x20_low_words_cleared": all(
            sequence["target_cell_plus_0x20_low_word_cleared"] for sequence in sequences
        ),
        "all_target_cell_plus_0x28_bit22_set": all(
            sequence["target_cell_plus_0x28_bit22_set"] for sequence in sequences
        ),
    }
    invariants = {
        "native_behavior_changed": False,
        "side_effect_summary_available": side_effect.get("status")
        == "post_border_guard_4a5e03_delegates_to_4a54a7_commit_replay_pending",
        "afterstate_summary_available": afterstate.get("status")
        == "post_border_guard_4a54a7_object_vector_and_cell_afterstate_recovered",
        "two_shared_target_sequences": len(shared_names) == 2,
        "static_4a5c07_constructor_contract_present": has_static_4a5c07_contract(static_text),
        **sequence_invariants,
    }
    completion_invariants = {
        key: value for key, value in invariants.items() if key != "native_behavior_changed"
    }
    status = (
        "post_border_guard_4a5c07_to_4a54a7_state_chain_recovered"
        if all(completion_invariants.values())
        else "post_border_guard_4a5c07_state_chain_incomplete"
    )
    return {
        "schema_id": "h3maped_4a5c07_state_chain_summary_v1",
        "status": status,
        "native_behavior_changed": False,
        "inputs": {
            "side_effect": str(args.side_effect),
            "afterstate": str(args.afterstate),
            "static_4a5c07": str(args.static_4a5c07),
        },
        "invariants": invariants,
        "sequence_count": len(sequences),
        "sequences": sequences,
        "recovered_contract": {
            "0x4a5c07": (
                "Constructs ordinary 0x540a88 records through 0x49ba89, leaves coordinate words unset, "
                "writes quantity/monster value at +0x20, object type field +0x24=3, and serial +0x1c."
            ),
            "0x4a5e03": (
                "When the target cell object-ref vector is empty, passes the constructed object and original "
                "x/y/level coordinate to generator vtable slot +0x04."
            ),
            "0x4a54a7": (
                "Stamps the same 0x540a88 object into the generator object vector and the target cell object-ref "
                "vector, clears GeneratedCell+0x20 low word, and sets GeneratedCell+0x28 bit22 in the sampled path."
            ),
        },
        "remaining_recovery_gaps": [
            "Recover full 0x4a54a7 projection-loop write set and descriptor +0x29/+0x2c/+0x30 semantic names.",
            "Recover how sampled 0x4a5c07/0x540a88 state links into later relation/control records and phase consumers beyond the immediate commit.",
            "Recover analogous 0x4a901a/0x540a9c producer path and generated-cell/vector before/after deltas.",
            "Continue 0x4a696b nonzero candidate/direct mutation recovery.",
            "Recover natural 0x4a7605/0x4a746b/0x4a5e73 success/mutation path.",
            "Recover actual 0x4add76 cleanup/uncommit runtime path.",
        ],
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--side-effect", type=Path, default=DEFAULT_SIDE_EFFECT)
    parser.add_argument("--afterstate", type=Path, default=DEFAULT_AFTERSTATE)
    parser.add_argument("--static-4a5c07", type=Path, default=DEFAULT_STATIC_4A5C07)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_4A5C07_STATE_CHAIN_SUMMARY status={summary['status']} out={args.out}")
    return 0 if summary["status"] == "post_border_guard_4a5c07_to_4a54a7_state_chain_recovered" else 1


if __name__ == "__main__":
    raise SystemExit(main())
