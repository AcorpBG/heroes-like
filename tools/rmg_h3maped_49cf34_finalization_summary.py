#!/usr/bin/env python3
"""Summarize live H3MapEd 0x49cf34 reward/guard finalization traces."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ENTRY = "0x0049cf34"
AFTER_STAMP = "0x0049d176"
PRIMARY_BIT27_WRITE = "0x0049d1ed"
NEIGHBOR_BIT27_WRITE = "0x0049d270"
FINALIZE_WRITES = "0x0049d29b"
CANDIDATE_CLEANUP_CALL = "0x0049d2ab"
AFTER_CANDIDATE_CLEANUP = "0x0049d2b0"
AFTER_BOUNDS_REFRESH = "0x0049d2b7"
SUCCESS = "0x0049d2be"


def normalize_address(value: Any) -> str:
    return "0x%08x" % int(str(value), 0)


def event_memory(event: dict[str, Any]) -> dict[int, int]:
    memory: dict[int, int] = {}
    for line in event.get("memory_lines", []):
        base = int(line.get("address", 0))
        for offset, word in enumerate(line.get("words", [])):
            memory[base + offset * 4] = int(word) & 0xFFFFFFFF
    return memory


def word(memory: dict[int, int], address: int) -> int | None:
    value = memory.get(address)
    return int(value) if value is not None else None


def signed32(value: int | None) -> int | None:
    if value is None:
        return None
    value &= 0xFFFFFFFF
    return value - 0x100000000 if value & 0x80000000 else value


def hex32(value: int | None) -> str:
    return "0x%08x" % value if value is not None else ""


def vector8(memory: dict[int, int], wrapper: int, anchor: int) -> dict[str, Any]:
    begin = word(memory, wrapper + anchor + 0x04)
    end = word(memory, wrapper + anchor + 0x08)
    capacity = word(memory, wrapper + anchor + 0x0C)
    count = None
    if begin is not None and end is not None and end >= begin and (end - begin) % 8 == 0:
        count = (end - begin) // 8
    return {"begin": hex32(begin), "end": hex32(end), "capacity": hex32(capacity), "count": count}


def selected_member_vector(memory: dict[int, int], wrapper: int) -> dict[str, Any]:
    begin = word(memory, wrapper + 0x2C)
    end = word(memory, wrapper + 0x30)
    capacity = word(memory, wrapper + 0x34)
    count = None
    if begin is not None and end is not None and end >= begin and (end - begin) % 4 == 0:
        count = (end - begin) // 4
    return {"begin": hex32(begin), "end": hex32(end), "capacity": hex32(capacity), "count": count}


def wrapper_snapshot(event: dict[str, Any], wrapper_register: str = "ebx") -> dict[str, Any]:
    registers = event.get("registers", {})
    wrapper = int(registers.get(wrapper_register, registers.get("ecx", 0)))
    memory = event_memory(event)
    return {
        "wrapper": hex32(wrapper),
        "bounds": {
            "min_x": signed32(word(memory, wrapper + 0x18)),
            "min_y": signed32(word(memory, wrapper + 0x1C)),
            "max_x": signed32(word(memory, wrapper + 0x20)),
            "max_y": signed32(word(memory, wrapper + 0x24)),
        },
        "selected_members": selected_member_vector(memory, wrapper),
        "candidate_coordinates": vector8(memory, wrapper, 0x38),
        "attached_flag": (word(memory, wrapper + 0x48) or 0) & 0xFF if word(memory, wrapper + 0x48) is not None else None,
        "relative_coordinate": {
            "x": signed32(word(memory, wrapper + 0x4C)),
            "y": signed32(word(memory, wrapper + 0x50)),
        },
    }


def local_snapshot(event: dict[str, Any]) -> dict[str, Any]:
    registers = event.get("registers", {})
    ebp = int(registers.get("ebp", 0))
    memory = event_memory(event)
    return {
        "relative_x_local": signed32(word(memory, ebp - 0x28)),
        "relative_y_local": signed32(word(memory, ebp - 0x24)),
        "descriptor_type_or_class": signed32(word(memory, ebp - 0x20)),
        "probe_x_local": signed32(word(memory, ebp - 0x1C)),
        "probe_y_local": signed32(word(memory, ebp - 0x18)),
        "neighbor_loop_count_or_flag": signed32(word(memory, ebp - 0x10)),
        "direction_index": signed32(word(memory, ebp - 0x0C)),
    }


def bit27_write_snapshot(index: int, event: dict[str, Any]) -> dict[str, Any]:
    registers = event.get("registers", {})
    cell = int(registers.get("esi", 0))
    memory = event_memory(event)
    return {
        "event_index": index,
        "cell": hex32(cell),
        "cell_w28_before": hex32(word(memory, cell + 0x28)),
        "locals": local_snapshot(event),
    }


def summarize(ledger: dict[str, Any]) -> dict[str, Any]:
    calls: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    orphan_events: list[dict[str, Any]] = []

    for index, event in enumerate(ledger.get("events", []), start=1):
        address = normalize_address(event.get("address", "0"))
        if address == ENTRY:
            if current is not None:
                calls.append(current)
            current = {
                "entry_event_index": index,
                "entry": wrapper_snapshot(event, "ecx"),
                "after_stamp": None,
                "primary_bit27_writes": [],
                "neighbor_bit27_writes": [],
                "before_final_field_writes": None,
                "before_candidate_cleanup": None,
                "after_candidate_cleanup": None,
                "after_bounds_refresh": None,
                "success": None,
                "complete": False,
            }
        elif current is None:
            orphan_events.append({"event_index": index, "address": address})
        elif address == AFTER_STAMP:
            current["after_stamp"] = {"event_index": index, "wrapper": wrapper_snapshot(event), "locals": local_snapshot(event)}
        elif address == PRIMARY_BIT27_WRITE:
            current["primary_bit27_writes"].append(bit27_write_snapshot(index, event))
        elif address == NEIGHBOR_BIT27_WRITE:
            current["neighbor_bit27_writes"].append(bit27_write_snapshot(index, event))
        elif address == FINALIZE_WRITES:
            current["before_final_field_writes"] = {
                "event_index": index,
                "wrapper": wrapper_snapshot(event),
                "locals": local_snapshot(event),
            }
        elif address == CANDIDATE_CLEANUP_CALL:
            current["before_candidate_cleanup"] = {
                "event_index": index,
                "wrapper": wrapper_snapshot(event),
                "locals": local_snapshot(event),
            }
        elif address == AFTER_CANDIDATE_CLEANUP:
            current["after_candidate_cleanup"] = {
                "event_index": index,
                "wrapper": wrapper_snapshot(event),
                "locals": local_snapshot(event),
            }
        elif address == AFTER_BOUNDS_REFRESH:
            current["after_bounds_refresh"] = {
                "event_index": index,
                "wrapper": wrapper_snapshot(event),
                "locals": local_snapshot(event),
            }
        elif address == SUCCESS:
            current["success"] = {"event_index": index, "wrapper": wrapper_snapshot(event), "locals": local_snapshot(event)}
            current["complete"] = True
            calls.append(current)
            current = None

    if current is not None:
        calls.append(current)

    completed = [call for call in calls if call.get("complete")]
    cleanup_mismatches: list[dict[str, Any]] = []
    finalization_mismatches: list[dict[str, Any]] = []
    for call_index, call in enumerate(completed, start=1):
        before_cleanup = call.get("before_candidate_cleanup", {}).get("wrapper", {}).get("candidate_coordinates", {})
        after_cleanup = call.get("after_candidate_cleanup", {}).get("wrapper", {}).get("candidate_coordinates", {})
        if before_cleanup.get("count") in (None, 0) or after_cleanup.get("count") != 0:
            cleanup_mismatches.append({"call_index": call_index, "before": before_cleanup, "after": after_cleanup})
        before_final = call.get("before_final_field_writes", {})
        after_final = call.get("before_candidate_cleanup", {})
        locals_before = before_final.get("locals", {})
        wrapper_after = after_final.get("wrapper", {})
        if (
            wrapper_after.get("attached_flag") != 1
            or wrapper_after.get("relative_coordinate", {}).get("x") != locals_before.get("relative_x_local")
            or wrapper_after.get("relative_coordinate", {}).get("y") != locals_before.get("relative_y_local")
        ):
            finalization_mismatches.append(
                {
                    "call_index": call_index,
                    "locals_before_final_write": locals_before,
                    "wrapper_after_final_write": wrapper_after,
                }
            )

    return {
        "schema_id": "h3maped_49cf34_finalization_summary_v1",
        "ledger": ledger.get("log_path", ""),
        "event_count": int(ledger.get("event_count", 0)),
        "breakpoints": ledger.get("breakpoints", []),
        "addresses": {
            "entry": ENTRY,
            "after_49d69d_stamp": AFTER_STAMP,
            "primary_bit27_write_call_site": PRIMARY_BIT27_WRITE,
            "neighbor_bit27_write_call_site": NEIGHBOR_BIT27_WRITE,
            "final_field_write_start": FINALIZE_WRITES,
            "candidate_cleanup_call": CANDIDATE_CLEANUP_CALL,
            "after_candidate_cleanup": AFTER_CANDIDATE_CLEANUP,
            "after_bounds_refresh": AFTER_BOUNDS_REFRESH,
            "success": SUCCESS,
        },
        "call_count": len(calls),
        "completed_call_count": len(completed),
        "incomplete_call_count": len(calls) - len(completed),
        "primary_bit27_write_total": sum(len(call.get("primary_bit27_writes", [])) for call in calls),
        "neighbor_bit27_write_total": sum(len(call.get("neighbor_bit27_writes", [])) for call in calls),
        "orphan_event_count": len(orphan_events),
        "cleanup_mismatches": cleanup_mismatches,
        "finalization_mismatches": finalization_mismatches,
        "first_completed_call": completed[0] if completed else None,
        "calls": calls,
        "invariants": {
            "hits_49cf34_entry": len(calls) > 0,
            "has_completed_success_call": len(completed) > 0,
            "captures_post_stamp_bit27_writes": any(
                call.get("primary_bit27_writes") or call.get("neighbor_bit27_writes") for call in completed
            ),
            "final_fields_match_relative_locals": not finalization_mismatches,
            "candidate_vector_clears_before_refresh": not cleanup_mismatches,
            "candidate_vector_rebuilt_by_success": all(
                (call.get("success", {}).get("wrapper", {}).get("candidate_coordinates", {}).get("count") or 0) > 0
                for call in completed
            ),
            "no_orphan_events": not orphan_events,
        },
        "notes": [
            "0x49d29b is before wrapper+0x4c/+0x50/+0x48 writes; 0x49d2ab observes those writes before candidate-vector cleanup.",
            "0x49d2b0 is after 0x4ae2d0 candidate-vector cleanup; 0x49d2b7 is after 0x49d6e0 bounds refresh; 0x49d2be is after 0x49d7c3 candidate-vector rebuild and just before MOV AL,1.",
            "The trace was manually cut after useful evidence; an incomplete final call is acceptable and reported separately.",
        ],
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    ledger = json.loads(args.ledger.read_text(encoding="utf-8"))
    summary = summarize(ledger)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    status = "pass" if all(summary["invariants"].values()) else "partial"
    print(
        "RMG_H3MAPED_49CF34_FINALIZATION_SUMMARY "
        f"status={status} calls={summary['call_count']} completed={summary['completed_call_count']} "
        f"primary_writes={summary['primary_bit27_write_total']} "
        f"neighbor_writes={summary['neighbor_bit27_write_total']} out={args.out}"
    )
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
