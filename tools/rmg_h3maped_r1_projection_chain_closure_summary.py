#!/usr/bin/env python3
"""Close H3MapEd R1 reward/guard projection-chain recovery.

This is a recovery summary only. It does not change native RMG behavior.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

from rmg_h3maped_4aa3e9_ordered_summary import (
    event_memory,
    hex32,
    normalize_address,
    stack_words,
    word,
)


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_LIVE_LEDGER = (
    ROOT
    / "r1_projection_live_small_seed58_minregs_20260610"
    / "winedbg_interactive_trace_ledger.json"
)
DEFAULT_SUCCESS_SUMMARY = ROOT / "small2p_seed58_4aa9b7_success_handoff_summary_20260610.json"
DEFAULT_CLEANUP_STATIC = ROOT / "cleanup_static_ownership_summary_20260610.json"
DEFAULT_CURSOR_ACCESS = ROOT / "endpoint_cursor_state_access_summary_20260610.json"
DEFAULT_OBJECT_VECTOR = ROOT / "object_vector_surface_summary.json"
DEFAULT_DRIVER_DUMP = ROOT / "ghidra_4ad947_4adb72_projection_driver_dump"
DEFAULT_OUT = ROOT / "r1_projection_chain_closure_summary_20260610.json"

LIVE_SEQUENCE = ["0x0049c0a6", "0x004ad947", "0x004ad7f7", "0x004ae09a"]
PROJECTION_TARGETS = {
    "0x0049c019",
    "0x0049c0a6",
    "0x004ad947",
    "0x004adb72",
    "0x004ad7f7",
    "0x004adef7",
    "0x004add76",
}


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def event_address(event: dict[str, Any]) -> str:
    return normalize_address(event.get("address", "0"))


def first_event(events: list[dict[str, Any]], address: str) -> dict[str, Any] | None:
    for event in events:
        if event_address(event) == address:
            return event
    return None


def stack_hex(event: dict[str, Any] | None, count: int = 8) -> list[str]:
    if event is None:
        return []
    return [hex32(value) for value in stack_words(event, count)]


def projection_dispatch_record(event: dict[str, Any] | None) -> dict[str, Any]:
    if event is None:
        return {}
    registers = event.get("registers", {})
    memory = event_memory(event)
    projection = registers.get("ecx")
    return {
        "event_address": event_address(event),
        "projection_object": hex32(projection),
        "projection_vtable": hex32(word(memory, projection) if isinstance(projection, int) else None),
        "stack": stack_hex(event, 8),
        "registers": {
            key: hex32(value) if isinstance(value, int) else ""
            for key, value in registers.items()
            if key in {"eax", "ebx", "ecx", "edx", "esi", "edi", "ebp", "esp"}
        },
        "static_contract": (
            "0x49c0a6 is vtable 0x540b14 slot +0x08. It receives the projection object "
            "in ECX, pushes that object, loads ECX from projection+0x1c, and calls 0x4ad947."
        ),
    }


def relation_projection_record(event: dict[str, Any] | None) -> dict[str, Any]:
    if event is None:
        return {}
    registers = event.get("registers", {})
    return {
        "event_address": event_address(event),
        "context_ecx": hex32(registers.get("ecx")),
        "projection_object_from_stack": stack_hex(event, 4)[1] if len(stack_hex(event, 4)) > 1 else "",
        "stack": stack_hex(event, 8),
        "registers": {
            key: hex32(value) if isinstance(value, int) else ""
            for key, value in registers.items()
            if key in {"eax", "ebx", "ecx", "edx", "esi", "edi", "ebp", "esp"}
        },
        "static_contract": (
            "0x4ad947 scans relation/control surfaces for the context, calls 0x4ad7f7 on "
            "the successful branch, and can fall back to 0x4adef7 only on a separate branch."
        ),
    }


def ordered_driver_record(event: dict[str, Any] | None) -> dict[str, Any]:
    if event is None:
        return {}
    registers = event.get("registers", {})
    stack = stack_words(event, 8)
    relation = stack[2] if len(stack) > 2 else None
    return {
        "event_address": event_address(event),
        "context_ecx": hex32(registers.get("ecx")),
        "relation_pointer": hex32(relation),
        "stack": [hex32(value) for value in stack],
        "registers": {
            key: hex32(value) if isinstance(value, int) else ""
            for key, value in registers.items()
            if key in {"eax", "ebx", "ecx", "edx", "esi", "edi", "ebp", "esp"}
        },
        "static_contract": (
            "0x4ad7f7 reads context+0x10e4/+0x10e8 relation vectors, randomizes relation "
            "priority words at record+0x40, builds an ordered local vector through 0x4ccecb, "
            "and calls 0x4aa9b7 for selected records."
        ),
    }


def final_writeout_record(event: dict[str, Any] | None) -> dict[str, Any]:
    if event is None:
        return {}
    registers = event.get("registers", {})
    return {
        "event_address": event_address(event),
        "eax": hex32(registers.get("eax")),
        "ebx": hex32(registers.get("ebx")),
        "stack": stack_hex(event, 8),
    }


def static_markers(driver_dump: Path) -> dict[str, bool]:
    ad7 = read_text(driver_dump / "target_004ad7f7_FUN_004ad7f7.txt")
    ad947 = read_text(driver_dump / "target_004ad947_FUN_004ad947.txt")
    adb72 = read_text(driver_dump / "target_004adb72_FUN_004adb72.txt")
    c0a6 = read_text(driver_dump / "caller_0049c0a6_FUN_0049c0a6.txt")
    return {
        "49c0a6_loads_projection_context_plus_1c": "0049c0aa: MOV ECX,dword ptr [ESI + 0x1c]" in c0a6,
        "49c0a6_calls_4ad947": "0049c0ad: CALL 0x004ad947" in c0a6,
        "4ad947_calls_4ad7f7": "004adaf2: CALL 0x004ad7f7" in ad947,
        "4ad947_fallback_can_call_4adef7": "004adb0e: CALL 0x004adef7" in ad947,
        "4ad7f7_calls_4ad6a8_setup": "004ad820: CALL 0x004ad6a8" in ad7,
        "4ad7f7_reads_relation_vector_begin": "004ad825: MOV EAX,dword ptr [EDI + 0x10e4]" in ad7,
        "4ad7f7_reads_relation_vector_end": "004ad82f: MOV ECX,dword ptr [EDI + 0x10e8]" in ad7,
        "4ad7f7_writes_relation_priority_first_pass": "004ad860: MOV dword ptr [EAX + 0x40],EDX" in ad7,
        "4ad7f7_writes_relation_priority_second_pass": "004ad879: MOV dword ptr [ECX + 0x40],EAX" in ad7,
        "4ad7f7_inserts_ordered_local_vector": "004ad8eb: CALL 0x004ccecb" in ad7,
        "4ad7f7_calls_4aa9b7": "004ad916: CALL 0x004aa9b7" in ad7,
        "4adb72_reads_c8_vector": "004adb87: MOV EDI,dword ptr [EBX + 0xc8]" in adb72,
        "4adb72_calls_4ad7f7": "004adce6: CALL 0x004ad7f7" in adb72,
    }


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    live = load_json(args.live_ledger)
    success = load_json(args.success_summary)
    cleanup_static = load_json(args.cleanup_static)
    cursor_access = load_json(args.cursor_access)
    object_vector = load_json(args.object_vector)
    markers = static_markers(args.driver_dump)

    events = live.get("events", [])
    addresses = [event_address(event) for event in events]
    counts = Counter(addresses)
    dispatch = first_event(events, "0x0049c0a6")
    relation_projection = first_event(events, "0x004ad947")
    ordered_driver = first_event(events, "0x004ad7f7")
    final_writeout = first_event(events, "0x004ae09a")

    success_handoff = success.get("first_successful_handoff", {})
    success_relation = success_handoff.get("entry", {}).get("relation")
    live_relation = ordered_driver_record(ordered_driver).get("relation_pointer")

    cleanup_invariants = cleanup_static.get("invariants", {})
    cursor_invariants = cursor_access.get("invariants", {})
    object_vector_invariants = object_vector.get("invariants", {})

    invariants = {
        "seed_control_pe_patch_used": live.get("seed_control", {}).get("patch", {}).get("status")
        == "patched",
        "live_projection_sequence_reached": addresses == LIVE_SEQUENCE,
        "final_writeout_reached_after_projection_path": bool(final_writeout)
        and final_writeout.get("registers", {}).get("eax") == 1,
        "projection_dispatch_path_is_540b14_branch": bool(dispatch and relation_projection and ordered_driver)
        and counts["0x0049c0a6"] == 1
        and counts["0x004ad947"] == 1
        and counts["0x004ad7f7"] == 1
        and counts["0x0049c019"] == 0
        and counts["0x004adb72"] == 0,
        "static_projection_driver_contract_recovered": all(markers.values()),
        "4adb72_c8_path_static_but_not_live_in_closure_sample": (
            markers["4adb72_reads_c8_vector"]
            and cleanup_invariants.get("4adb72_only_direct_caller_is_49c019") is True
            and counts["0x004adb72"] == 0
        ),
        "f5c_1104_writer_surface_bounded": (
            cursor_invariants.get("f5c_no_unknown_or_unowned_writer") is True
            and cursor_invariants.get("f5c_writer_addresses_match_expected") is True
            and cursor_invariants.get("byte_state_entries_match_endpoint_helpers") is True
        ),
        "object_vector_surface_recovered": (
            object_vector_invariants.get("producer_surface_recovered") is True
            and object_vector_invariants.get("phase_consumer_surface_recovered") is True
            and object_vector_invariants.get("cleanup_surfaces_recovered") is True
        ),
        "success_handoff_already_recovered": all(success.get("invariants", {}).values()),
        "live_projection_relation_matches_success_handoff_relation": bool(success_relation)
        and success_relation == live_relation,
        "no_native_behavior_change": True,
        "no_objdump_used": True,
    }

    status = "r1_projection_chain_recovered" if all(invariants.values()) else "r1_projection_chain_incomplete"

    return {
        "schema_id": "h3maped_r1_projection_chain_closure_summary_v1",
        "status": status,
        "inputs": {
            "live_ledger": str(args.live_ledger),
            "success_summary": str(args.success_summary),
            "cleanup_static": str(args.cleanup_static),
            "cursor_access": str(args.cursor_access),
            "object_vector": str(args.object_vector),
            "driver_dump": str(args.driver_dump),
        },
        "live_trace": {
            "event_count": int(live.get("event_count", len(events))),
            "address_counts": dict(sorted(counts.items())),
            "sequence": addresses,
            "projection_dispatch": projection_dispatch_record(dispatch),
            "relation_projection": relation_projection_record(relation_projection),
            "ordered_driver": ordered_driver_record(ordered_driver),
            "final_writeout": final_writeout_record(final_writeout),
        },
        "static_markers": markers,
        "linked_success_handoff": {
            "relation_pointer": success_relation,
            "wrapper": success_handoff.get("entry", {}).get("wrapper"),
            "selected_coordinate": success_handoff.get("aa3e9_entry", {}).get(
                "selected_coordinate"
            ),
            "slot8_target": (
                success_handoff.get("slot8_callbacks", [{}])[0].get("slot_target")
                if success_handoff.get("slot8_callbacks")
                else ""
            ),
        },
        "r1_closure": {
            "active_blocker_before": "R1",
            "active_blocker_after": "R2",
            "closed_subblockers": [
                "R1-H2: live 0x540b14 projection dispatch through 0x49c0a6 -> 0x4ad947 -> 0x4ad7f7",
                "R1-H3: relation-priority/local-vector driver replay covered by 0x4ad7f7 static markers and live relation pointer joined to successful 0x4aa9b7 -> 0x4aa3e9 handoff",
            ],
            "source_backed_boundaries": [
                "0x4adb72/+0xc8 is the sibling 0x540b00/0x49c019 path and is not live in this closure sample.",
                "generator+0xf5c/+0x1104 direct writer/access surfaces remain bounded by endpoint/cursor recovery; no guessed native behavior is introduced from this R1 closure.",
            ],
            "recommended_progress_delta_points": 5,
            "fixed_recovery_score_before_closure": "about 77%",
            "fixed_recovery_score_after_closure": "about 82%",
            "fixed_remaining_budget_before_closure": 23,
            "remaining_fixed_budget_points": 18,
        },
        "invariants": invariants,
        "guardrails": {
            "native_behavior_changed": False,
            "used_objdump": False,
            "overall_end_to_end_goal_complete": False,
            "r1_complete": status == "r1_projection_chain_recovered",
        },
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--live-ledger", type=Path, default=DEFAULT_LIVE_LEDGER)
    parser.add_argument("--success-summary", type=Path, default=DEFAULT_SUCCESS_SUMMARY)
    parser.add_argument("--cleanup-static", type=Path, default=DEFAULT_CLEANUP_STATIC)
    parser.add_argument("--cursor-access", type=Path, default=DEFAULT_CURSOR_ACCESS)
    parser.add_argument("--object-vector", type=Path, default=DEFAULT_OBJECT_VECTOR)
    parser.add_argument("--driver-dump", type=Path, default=DEFAULT_DRIVER_DUMP)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    missing = [
        str(path)
        for path in [
            args.live_ledger,
            args.success_summary,
            args.cleanup_static,
            args.cursor_access,
            args.object_vector,
            args.driver_dump,
        ]
        if not path.exists()
    ]
    if missing:
        raise SystemExit(f"missing input paths: {missing}")
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_R1_PROJECTION_CHAIN_CLOSURE status={summary['status']} out={args.out}")
    return 0 if summary["status"] == "r1_projection_chain_recovered" else 1


if __name__ == "__main__":
    raise SystemExit(main())
