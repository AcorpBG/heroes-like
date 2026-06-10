#!/usr/bin/env python3
"""Summarize H3MapEd 0x49cf34 descriptor policy and cell mutations.

This is a focused recovery checkpoint. It pairs the call sites around
0x49a932 so the generated-cell before/after state is explicit, and it records
the descriptor policy inputs used by 0x49cf34. It does not change native RMG
behavior or claim full ordered private-state replay.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_LEDGER = (
    ROOT
    / "medium_seed10_49cf34_cell_mutation_replay_20260610"
    / "winedbg_interactive_trace_ledger.json"
)
DEFAULT_OUT = ROOT / "49cf34_cell_mutation_replay_summary_20260610.json"

ENTRY = "0x0049cf34"
DESCRIPTOR_POLICY_INPUT = "0x0049cf92"
DESCRIPTOR_POLICY_FLAG = "0x0049cf99"
STAMP_CALL = "0x0049d171"
AFTER_STAMP = "0x0049d176"
PRIMARY_WRITE_BEFORE = "0x0049d1ed"
PRIMARY_WRITE_AFTER = "0x0049d1f2"
NEIGHBOR_WRITE_BEFORE = "0x0049d270"
NEIGHBOR_WRITE_AFTER = "0x0049d275"
FINAL_FIELDS = "0x0049d29b"
SUCCESS = "0x0049d2be"

BIT26 = 1 << 26
BIT27 = 1 << 27


def normalize_address(value: Any) -> str:
    return "0x%08x" % int(str(value), 0)


def hex32(value: int | None) -> str | None:
    if value is None:
        return None
    return f"0x{value & 0xffffffff:08x}"


def signed32(value: int | None) -> int | None:
    if value is None:
        return None
    value &= 0xFFFFFFFF
    return value - 0x100000000 if value & 0x80000000 else value


def event_memory(event: dict[str, Any]) -> dict[int, int]:
    memory: dict[int, int] = {}
    for line in event.get("memory_lines", []):
        base = int(line.get("address", 0))
        for offset, word in enumerate(line.get("words", [])):
            memory[base + offset * 4] = int(word) & 0xFFFFFFFF
    return memory


def word(memory: dict[int, int], address: int | None) -> int | None:
    if address is None:
        return None
    value = memory.get(address)
    return int(value) if value is not None else None


def words(memory: dict[int, int], address: int | None, count: int) -> list[str]:
    if address is None:
        return []
    out: list[str] = []
    for index in range(count):
        value = word(memory, address + index * 4)
        if value is None:
            break
        out.append(hex32(value) or "0x00000000")
    return out


def stack_word(event: dict[str, Any], index: int) -> int | None:
    registers = event.get("registers", {})
    esp = registers.get("esp")
    if not isinstance(esp, int):
        return None
    return word(event_memory(event), esp + index * 4)


def cell_snapshot(event: dict[str, Any]) -> dict[str, Any]:
    registers = event.get("registers", {})
    cell = registers.get("esi")
    memory = event_memory(event)
    cell_w28 = word(memory, cell + 0x28 if isinstance(cell, int) else None)
    ebp = registers.get("ebp")
    locals_snapshot: dict[str, Any] = {}
    if isinstance(ebp, int):
        locals_snapshot = {
            "relative_x": signed32(word(memory, ebp - 0x28)),
            "relative_y": signed32(word(memory, ebp - 0x24)),
            "descriptor_class_or_type": signed32(word(memory, ebp - 0x20)),
            "probe_x": signed32(word(memory, ebp - 0x1C)),
            "probe_y": signed32(word(memory, ebp - 0x18)),
            "direction_index": signed32(word(memory, ebp - 0x0C)),
        }
    return {
        "cell": hex32(cell if isinstance(cell, int) else None),
        "cell_w28": hex32(cell_w28),
        "bit26": bool(cell_w28 & BIT26) if cell_w28 is not None else None,
        "bit27": bool(cell_w28 & BIT27) if cell_w28 is not None else None,
        "locals": locals_snapshot,
    }


def write_pair(kind: str, before_index: int, before: dict[str, Any], after: dict[str, Any]) -> dict[str, Any]:
    before_cell = cell_snapshot(before)
    after_cell = cell_snapshot(after)
    before_w28 = int(before_cell["cell_w28"], 16) if before_cell["cell_w28"] else None
    after_w28 = int(after_cell["cell_w28"], 16) if after_cell["cell_w28"] else None
    changed_mask = None
    if before_w28 is not None and after_w28 is not None:
        changed_mask = before_w28 ^ after_w28
    return {
        "kind": kind,
        "before_event": before_index,
        "after_event": before_index + 1,
        "before_address": before.get("address"),
        "after_address": after.get("address"),
        "before": before_cell,
        "after": after_cell,
        "changed_mask": hex32(changed_mask),
        "sets_bit27": (
            before_w28 is not None
            and after_w28 is not None
            and not bool(before_w28 & BIT27)
            and bool(after_w28 & BIT27)
        ),
        "leaves_bit27_set": (
            before_w28 is not None and after_w28 is not None and bool(after_w28 & BIT27)
        ),
        "clears_bit26": (
            before_w28 is not None
            and after_w28 is not None
            and bool(before_w28 & BIT26)
            and not bool(after_w28 & BIT26)
        ),
        "same_cell_pointer": before_cell["cell"] == after_cell["cell"],
    }


def descriptor_policy_pair(
    input_index: int, input_event: dict[str, Any], flag_event: dict[str, Any]
) -> dict[str, Any]:
    registers = input_event.get("registers", {})
    flag_registers = flag_event.get("registers", {})
    descriptor_class = registers.get("eax")
    flag_word = flag_registers.get("eax")
    flag = (int(flag_word) & 0xFF) if isinstance(flag_word, int) else None
    direction_probe_count = 5 + (3 if flag else 0) if flag is not None else None
    memory = event_memory(input_event)
    ebp = registers.get("ebp")
    descriptor_or_class_local = word(memory, ebp - 0x20 if isinstance(ebp, int) else None)
    return {
        "input_event": input_index,
        "flag_event": input_index + 1,
        "descriptor_class": descriptor_class,
        "descriptor_class_hex": hex32(descriptor_class if isinstance(descriptor_class, int) else None),
        "policy_table_pointer": hex32(registers.get("ecx") if isinstance(registers.get("ecx"), int) else None),
        "policy_flag": flag,
        "direction_probe_count": direction_probe_count,
        "descriptor_or_class_local": hex32(descriptor_or_class_local),
    }


def selected_member_snapshot(event: dict[str, Any]) -> dict[str, Any]:
    memory = event_memory(event)
    record = stack_word(event, 0)
    selected_x = stack_word(event, 1)
    selected_y = stack_word(event, 2)
    descriptor = word(memory, record + 0x04 if record is not None else None)
    return {
        "event": event.get("index"),
        "member_record": hex32(record),
        "selected_coordinate": {
            "x": signed32(selected_x),
            "y": signed32(selected_y),
        },
        "record_words": words(memory, record, 12),
        "descriptor_pointer": hex32(descriptor),
        "descriptor_words": words(memory, descriptor, 16),
    }


def wrapper_success_snapshot(event: dict[str, Any]) -> dict[str, Any]:
    registers = event.get("registers", {})
    wrapper = registers.get("ebx")
    memory = event_memory(event)
    return {
        "wrapper": hex32(wrapper if isinstance(wrapper, int) else None),
        "attached_flag": (
            word(memory, wrapper + 0x48 if isinstance(wrapper, int) else None) & 0xFF
            if word(memory, wrapper + 0x48 if isinstance(wrapper, int) else None) is not None
            else None
        ),
        "relative_coordinate": {
            "x": signed32(word(memory, wrapper + 0x4C if isinstance(wrapper, int) else None)),
            "y": signed32(word(memory, wrapper + 0x50 if isinstance(wrapper, int) else None)),
        },
        "candidate_vector_count": vector_count(memory, wrapper, 0x38),
        "wrapper_words": words(memory, wrapper if isinstance(wrapper, int) else None, 24),
    }


def vector_count(memory: dict[int, int], base: int | None, anchor: int) -> int | None:
    if base is None:
        return None
    begin = word(memory, base + anchor + 0x04)
    end = word(memory, base + anchor + 0x08)
    if begin is None or end is None or end < begin:
        return None
    stride = 8 if anchor == 0x38 else 4
    delta = end - begin
    if delta % stride:
        return None
    return delta // stride


def summarize(ledger: dict[str, Any]) -> dict[str, Any]:
    events = [dict(event, index=index) for index, event in enumerate(ledger.get("events", []), start=1)]
    address_counts: dict[str, int] = {}
    for event in events:
        address_counts[event.get("address", "")] = address_counts.get(event.get("address", ""), 0) + 1

    descriptor_policy_samples: list[dict[str, Any]] = []
    write_pairs: list[dict[str, Any]] = []
    selected_member: dict[str, Any] | None = None
    success_snapshot: dict[str, Any] | None = None
    final_field_snapshot: dict[str, Any] | None = None
    unpaired_writes: list[dict[str, Any]] = []
    unpaired_after_events = 0

    for index, event in enumerate(events):
        address = normalize_address(event.get("address", "0"))
        next_event = events[index + 1] if index + 1 < len(events) else None
        next_address = normalize_address(next_event.get("address", "0")) if next_event else ""

        if address == DESCRIPTOR_POLICY_INPUT:
            if next_event and next_address == DESCRIPTOR_POLICY_FLAG:
                descriptor_policy_samples.append(descriptor_policy_pair(index + 1, event, next_event))
            else:
                unpaired_writes.append({"event": index + 1, "address": address, "reason": "missing_policy_flag_event"})
        elif address == STAMP_CALL:
            selected_member = selected_member_snapshot(event)
        elif address == PRIMARY_WRITE_BEFORE:
            if next_event and next_address == PRIMARY_WRITE_AFTER:
                write_pairs.append(write_pair("primary", index + 1, event, next_event))
            else:
                unpaired_writes.append({"event": index + 1, "address": address, "reason": "missing_primary_after"})
        elif address == NEIGHBOR_WRITE_BEFORE:
            if next_event and next_address == NEIGHBOR_WRITE_AFTER:
                write_pairs.append(write_pair("neighbor", index + 1, event, next_event))
            else:
                unpaired_writes.append({"event": index + 1, "address": address, "reason": "missing_neighbor_after"})
        elif address == NEIGHBOR_WRITE_AFTER:
            previous_address = normalize_address(events[index - 1].get("address", "0")) if index else ""
            if previous_address != NEIGHBOR_WRITE_BEFORE:
                unpaired_after_events += 1
        elif address == FINAL_FIELDS:
            final_field_snapshot = wrapper_success_snapshot(event)
        elif address == SUCCESS:
            success_snapshot = wrapper_success_snapshot(event)

    primary_pairs = [pair for pair in write_pairs if pair["kind"] == "primary"]
    neighbor_pairs = [pair for pair in write_pairs if pair["kind"] == "neighbor"]
    changed_pairs = [pair for pair in write_pairs if pair["changed_mask"] not in (None, "0x00000000")]
    cells = sorted({pair["before"]["cell"] for pair in write_pairs if pair["before"]["cell"]})
    selected_coordinate = (selected_member or {}).get("selected_coordinate", {})
    success_coordinate = (success_snapshot or {}).get("relative_coordinate", {})

    invariants = {
        "hits_49cf34_entry": address_counts.get(ENTRY, 0) == 1,
        "captures_descriptor_policy_samples": len(descriptor_policy_samples) > 0,
        "captures_selected_member_stamp": selected_member is not None,
        "pairs_all_primary_writes": address_counts.get(PRIMARY_WRITE_BEFORE, 0) == len(primary_pairs),
        "pairs_all_neighbor_writes": address_counts.get(NEIGHBOR_WRITE_BEFORE, 0) == len(neighbor_pairs),
        "write_pairs_keep_same_cell_pointer": all(pair["same_cell_pointer"] for pair in write_pairs),
        "write_pairs_leave_bit27_set": bool(write_pairs)
        and all(pair["leaves_bit27_set"] for pair in write_pairs),
        "has_real_cell_state_changes": bool(changed_pairs),
        "success_fields_match_selected_coordinate": (
            selected_member is not None
            and success_snapshot is not None
            and selected_coordinate.get("x") == success_coordinate.get("x")
            and selected_coordinate.get("y") == success_coordinate.get("y")
            and success_snapshot.get("attached_flag") == 1
        ),
        "no_unpaired_write_before_events": not unpaired_writes,
    }

    return {
        "schema_id": "h3maped_49cf34_cell_mutation_summary_v1",
        "status": "49cf34_cell_mutation_replay_recovered"
        if all(invariants.values())
        else "49cf34_cell_mutation_replay_incomplete",
        "ledger": ledger.get("log_path", ""),
        "event_count": int(ledger.get("event_count", 0)),
        "breakpoints": ledger.get("breakpoints", []),
        "scope": {
            "profile": "H3MapEd Medium one-level no-water seed 10, human/computer down 1, computer-only down 0",
            "positive_claim": (
                "pairs the 0x49cf34 descriptor policy samples, selected-member stamp, "
                "and generated-cell before/after writes around 0x49a932 for one completed attach"
            ),
            "negative_claim": (
                "does not recover all callers to 0x49cf34 and does not provide complete "
                "ordered private-state replay from RMG entrypoint"
            ),
        },
        "addresses": {
            "entry": ENTRY,
            "descriptor_policy_input": DESCRIPTOR_POLICY_INPUT,
            "descriptor_policy_flag": DESCRIPTOR_POLICY_FLAG,
            "selected_member_stamp_call": STAMP_CALL,
            "after_selected_member_stamp": AFTER_STAMP,
            "primary_write_before": PRIMARY_WRITE_BEFORE,
            "primary_write_after": PRIMARY_WRITE_AFTER,
            "neighbor_write_before": NEIGHBOR_WRITE_BEFORE,
            "neighbor_write_after": NEIGHBOR_WRITE_AFTER,
            "final_fields": FINAL_FIELDS,
            "success": SUCCESS,
        },
        "metrics": {
            "descriptor_policy_sample_count": len(descriptor_policy_samples),
            "descriptor_direction_probe_counts": sorted(
                {sample["direction_probe_count"] for sample in descriptor_policy_samples}
            ),
            "primary_write_pair_count": len(primary_pairs),
            "neighbor_write_pair_count": len(neighbor_pairs),
            "unique_cell_count": len(cells),
            "changed_write_pair_count": len(changed_pairs),
            "sets_bit27_from_clear_count": sum(1 for pair in write_pairs if pair["sets_bit27"]),
            "clears_bit26_count": sum(1 for pair in write_pairs if pair["clears_bit26"]),
            "unpaired_after_event_count": unpaired_after_events,
            "ordered_private_state_mutation_replay_complete": False,
            "native_behavior_changed": False,
            "used_objdump": False,
            "overall_goal_complete": False,
        },
        "descriptor_policy_samples": descriptor_policy_samples,
        "selected_member": selected_member,
        "final_field_snapshot": final_field_snapshot,
        "success_snapshot": success_snapshot,
        "write_pairs_prefix": write_pairs[:64],
        "unique_cells": cells,
        "unpaired_writes": unpaired_writes,
        "invariants": invariants,
        "remaining_gap": (
            "0x49cf34 cell mutation mechanics are recovered for this completed attach sample. "
            "The remaining work is caller-to-generator ordered replay: how callers choose this "
            "member/descriptor sequence, how wrapper and generator vectors reach this state, and "
            "how this attaches into the full RMG entrypoint-to-writeout private-state chain."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    ledger = json.loads(args.ledger.read_text(encoding="utf-8"))
    summary = summarize(ledger)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_49CF34_CELL_MUTATION_SUMMARY "
        f"status={summary['status']} "
        f"policy_samples={summary['metrics']['descriptor_policy_sample_count']} "
        f"primary_pairs={summary['metrics']['primary_write_pair_count']} "
        f"neighbor_pairs={summary['metrics']['neighbor_write_pair_count']} "
        f"changed_pairs={summary['metrics']['changed_write_pair_count']} "
        f"out={args.out}"
    )
    return 0 if summary["status"] == "49cf34_cell_mutation_replay_recovered" else 1


if __name__ == "__main__":
    raise SystemExit(main())
