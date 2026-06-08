#!/usr/bin/env python3
"""Summarize ``0x4a54a7`` descriptor and relation-counter runtime state.

This is recovery evidence only. It parses focused WineDbg ledgers that stop on
the descriptor-read and relation-counter write sites inside ``0x4a54a7``. The
summary proves sampled descriptor fields and counter mutation invariants; it
does not change native RMG behavior.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_LEDGER = Path(
    ".artifacts/rmg_recovery/medium_seed10_4a54a7_descriptor_relation_nomod_trace_20260608/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_AFTERSTATE_LEDGER = Path(
    ".artifacts/rmg_recovery/medium_seed10_4a54a7_afterstate_trace2_20260608/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_PROJECTION_FIRST_LEDGER = Path(
    ".artifacts/rmg_recovery/medium_seed10_4a54a7_projection_first_target_20260608/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_PROJECTION_SECOND_LEDGER = Path(
    ".artifacts/rmg_recovery/medium_seed10_4a54a7_projection_second_target_20260608/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_DUMP = Path(".artifacts/rmg_recovery/ghidra_4a54a7_relation_vslot4_dump/target_004a54a7_FUN_004a54a7.txt")
DEFAULT_OUT = Path(".artifacts/rmg_recovery/medium_seed10_4a54a7_descriptor_relation_summary_20260608.json")

ADDRESS_ENTRY = "0x004a54a7"
ADDRESS_DESCRIPTOR = "0x004a5501"
ADDRESS_RELATION_WRITE = "0x004a5588"
ADDRESS_SOURCE_PRE_CLEAR = "0x004a558a"
ADDRESS_SOURCE_AFTER_CLEAR = "0x004a558f"
ADDRESS_RETURN = "0x004a5756"


def hex32(value: int | None) -> str | None:
    if value is None:
        return None
    return "0x%08x" % (int(value) & 0xFFFFFFFF)


def signed32(value: int | None) -> int | None:
    if value is None:
        return None
    value &= 0xFFFFFFFF
    return value - 0x100000000 if value & 0x80000000 else value


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""


def event_memory(event: dict[str, Any]) -> dict[int, int]:
    memory: dict[int, int] = {}
    for line in event.get("memory_lines", []):
        address = int(line.get("address", 0))
        for index, word in enumerate(line.get("words", [])):
            memory[address + index * 4] = int(word) & 0xFFFFFFFF
    return memory


def word(memory: dict[int, int], address: int | None) -> int | None:
    if address is None:
        return None
    return memory.get(address)


def words_at(event: dict[str, Any], address: int | None, count: int) -> list[int | None]:
    memory = event_memory(event)
    return [word(memory, None if address is None else address + index * 4) for index in range(count)]


def stack_words(event: dict[str, Any], count: int) -> list[int | None]:
    return words_at(event, event.get("registers", {}).get("esp"), count)


def byte_at_word(value: int | None, byte_index: int) -> int | None:
    if value is None:
        return None
    return (int(value) >> (byte_index * 8)) & 0xFF


def normalize_address(value: str | None) -> str | None:
    if not value:
        return None
    return "0x%08x" % int(value, 0)


def group_invocations(events: list[dict[str, Any]]) -> list[list[dict[str, Any]]]:
    groups: list[list[dict[str, Any]]] = []
    current: list[dict[str, Any]] = []
    for event in events:
        address = str(event.get("address", "")).lower()
        if address == ADDRESS_ENTRY:
            if current:
                groups.append(current)
            current = [event]
        elif current:
            current.append(event)
            if address == ADDRESS_RETURN:
                groups.append(current)
                current = []
    if current:
        groups.append(current)
    return groups


def first_by_address(group: list[dict[str, Any]], address: str) -> dict[str, Any] | None:
    for event in group:
        if str(event.get("address", "")).lower() == address:
            return event
    return None


def generated_cell_coordinate(cell_pointer: int | None, generator_words: list[int | None]) -> dict[str, int | None]:
    if cell_pointer is None or len(generator_words) < 8:
        return {"flat": None, "x": None, "y": None, "level": None}
    base = generator_words[5]
    width = generator_words[6]
    height = generator_words[7]
    if base is None or width in (None, 0) or height in (None, 0):
        return {"flat": None, "x": None, "y": None, "level": None}
    delta = int(cell_pointer) - int(base)
    if delta < 0 or delta % 0x30 != 0:
        return {"flat": None, "x": None, "y": None, "level": None}
    flat = delta // 0x30
    area = int(width) * int(height)
    return {"flat": flat, "x": flat % int(width), "y": (flat // int(width)) % int(height), "level": flat // area}


def parse_descriptor(event: dict[str, Any] | None) -> dict[str, Any]:
    if event is None:
        return {}
    descriptor = int(event.get("registers", {}).get("eax", 0))
    words = words_at(event, descriptor, 24)
    word_0x28 = words[10] if len(words) > 10 else None
    return {
        "pointer": hex32(descriptor),
        "raw_words": [hex32(value) for value in words],
        "id_or_class_word_0x00": words[0],
        "type_index_from_register_edi": event.get("registers", {}).get("edi"),
        "type_index_from_descriptor_plus_0x1c": words[7] if len(words) > 7 else None,
        "projection_flag_plus_0x29": byte_at_word(word_0x28, 1),
        "raw_word_plus_0x28": hex32(word_0x28),
        "projection_offset_x_plus_0x2c": signed32(words[11] if len(words) > 11 else None),
        "projection_offset_y_plus_0x30": signed32(words[12] if len(words) > 12 else None),
        "mask_width_plus_0x34": signed32(words[13] if len(words) > 13 else None),
        "mask_height_plus_0x38": signed32(words[14] if len(words) > 14 else None),
    }


def parse_invocation(index: int, group: list[dict[str, Any]]) -> dict[str, Any]:
    entry = first_by_address(group, ADDRESS_ENTRY)
    descriptor_event = first_by_address(group, ADDRESS_DESCRIPTOR)
    relation_before = first_by_address(group, ADDRESS_RELATION_WRITE)
    relation_after = first_by_address(group, ADDRESS_SOURCE_PRE_CLEAR)
    source_after_clear = first_by_address(group, ADDRESS_SOURCE_AFTER_CLEAR)
    exit_event = first_by_address(group, ADDRESS_RETURN)

    entry_stack = stack_words(entry, 5) if entry else []
    descriptor = parse_descriptor(descriptor_event)
    generator_pointer = descriptor_event.get("registers", {}).get("esi") if descriptor_event else None
    generator_words = words_at(descriptor_event, generator_pointer, 12) if descriptor_event else []
    type_index = descriptor.get("type_index_from_register_edi")
    object_x = signed32(entry_stack[2] if len(entry_stack) > 2 else None)
    object_y = signed32(entry_stack[3] if len(entry_stack) > 3 else None)
    object_level = signed32(entry_stack[4] if len(entry_stack) > 4 else None)
    offset_x = descriptor.get("projection_offset_x_plus_0x2c")
    offset_y = descriptor.get("projection_offset_y_plus_0x30")
    expected_source = {
        "x": None if object_x is None or offset_x is None else object_x - offset_x,
        "y": None if object_y is None or offset_y is None else object_y - offset_y,
        "level": object_level,
    }

    relation_summary: dict[str, Any] = {}
    source_cell_summary: dict[str, Any] = {}
    if relation_before and descriptor_event:
        before_memory = event_memory(relation_before)
        after_memory = event_memory(relation_after) if relation_after else {}
        cleared_memory = event_memory(source_after_clear) if source_after_clear else {}
        cell_pointer = int(relation_before.get("registers", {}).get("eax", 0))
        counter_address = int(relation_before.get("registers", {}).get("ecx", 0))
        old_counter = word(before_memory, counter_address)
        after_counter = word(after_memory, counter_address)
        new_counter_register = relation_before.get("registers", {}).get("edx")
        source_word_before = word(before_memory, cell_pointer + 0x20)
        source_word_at_558a = word(after_memory, cell_pointer + 0x20)
        source_word_after_clear = word(cleared_memory, cell_pointer + 0x20)
        owner_byte = byte_at_word(source_word_before, 2)
        signed_owner = None if owner_byte is None else owner_byte - 0x100 if owner_byte >= 0x80 else owner_byte
        relation_pointer = None
        if type_index is not None:
            relation_pointer = counter_address - 0x44 - int(type_index) * 4
        relation_vector_pointer = relation_before.get("registers", {}).get("esi")
        relation_vector_words = words_at(relation_before, relation_vector_pointer, 16)
        vector_relation = None
        if signed_owner is not None and signed_owner >= 0 and signed_owner < len(relation_vector_words):
            vector_relation = relation_vector_words[signed_owner]
        source_coord = generated_cell_coordinate(cell_pointer, generator_words)
        relation_summary = {
            "counter_address": hex32(counter_address),
            "relation_pointer_from_counter_address": hex32(relation_pointer),
            "relation_vector_pointer": hex32(relation_vector_pointer),
            "relation_pointer_from_source_owner_vector": hex32(vector_relation),
            "source_owner_byte_from_cell_plus_0x20_byte2": signed_owner,
            "old_relation_type_counter": old_counter,
            "new_relation_type_counter_register_edx": new_counter_register,
            "new_relation_type_counter_after_write": after_counter,
            "counter_incremented_by_one": (
                old_counter is not None
                and new_counter_register is not None
                and after_counter == new_counter_register
                and int(new_counter_register) == int(old_counter) + 1
            ),
            "counter_address_matches_source_owner_relation_type_slot": relation_pointer == vector_relation,
        }
        source_cell_summary = {
            "pointer": hex32(cell_pointer),
            "coordinate": source_coord,
            "expected_coordinate_from_descriptor_offsets": expected_source,
            "coordinate_matches_descriptor_offset_source": (
                source_coord.get("x") == expected_source.get("x")
                and source_coord.get("y") == expected_source.get("y")
                and source_coord.get("level") == expected_source.get("level")
            ),
            "plus_0x20_before_relation_write": hex32(source_word_before),
            "plus_0x20_at_0x558a_before_clear": hex32(source_word_at_558a),
            "plus_0x20_after_0x558a_clear": hex32(source_word_after_clear),
            "low_word_cleared_by_0x558a": (
                source_word_before is not None
                and source_word_after_clear is not None
                and (source_word_before & 0xFFFF0000) == (source_word_after_clear & 0xFFFF0000)
                and (source_word_after_clear & 0xFFFF) == 0
            ),
        }

    return {
        "ordinal": index,
        "complete": all([entry, descriptor_event, relation_before, relation_after, source_after_clear, exit_event]),
        "return_address": normalize_address(entry.get("derived", {}).get("return_address")) if entry else None,
        "object_record_pointer": hex32(entry_stack[1] if len(entry_stack) > 1 else None),
        "object_coordinate": {"x": object_x, "y": object_y, "level": object_level},
        "generator_pointer": hex32(generator_pointer),
        "generator_layout": {
            "raw_words": [hex32(value) for value in generator_words],
            "generated_cell_base": hex32(generator_words[5] if len(generator_words) > 5 else None),
            "width": generator_words[6] if len(generator_words) > 6 else None,
            "height": generator_words[7] if len(generator_words) > 7 else None,
            "levels": generator_words[8] if len(generator_words) > 8 else None,
        },
        "descriptor": descriptor,
        "relation_counter": relation_summary,
        "source_cell": source_cell_summary,
    }


def callsite_events(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []
    events = read_json(path).get("events", [])
    result: list[dict[str, Any]] = []
    for event in events:
        address = str(event.get("address", "")).lower()
        if address not in {"0x004a77a8", "0x004a7895", "0x004a5e03", ADDRESS_ENTRY}:
            continue
        stack = stack_words(event, 5)
        result.append(
            {
                "event_index": events.index(event),
                "address": address,
                "return_address": normalize_address(event.get("derived", {}).get("return_address")),
                "stack_words": [hex32(value) for value in stack],
                "arg0_or_object": hex32(stack[1] if address in {"0x004a5e03", ADDRESS_ENTRY} else stack[0] if stack else None),
                "x": signed32(stack[2] if address in {"0x004a5e03", ADDRESS_ENTRY} else stack[1] if len(stack) > 1 else None),
                "y": signed32(stack[3] if address in {"0x004a5e03", ADDRESS_ENTRY} else stack[2] if len(stack) > 2 else None),
                "level": signed32(stack[4] if address in {"0x004a5e03", ADDRESS_ENTRY} else stack[3] if len(stack) > 3 else None),
            }
        )
    return result


def summarize(
    ledger_path: Path,
    afterstate_path: Path,
    projection_first_path: Path,
    projection_second_path: Path,
    dump_path: Path,
) -> dict[str, Any]:
    ledger = read_json(ledger_path)
    invocations = [parse_invocation(index + 1, group) for index, group in enumerate(group_invocations(ledger.get("events", [])))]
    descriptor_types = Counter(str(item.get("descriptor", {}).get("type_index_from_register_edi")) for item in invocations)
    return_addresses = Counter(str(item.get("return_address")) for item in invocations)
    complete_invocations = [item for item in invocations if item.get("complete")]
    dump_text = read_text(dump_path)
    invariants = {
        "native_behavior_changed": False,
        "trace_reached_second_target_return_0x4a789a": any(
            str(event.get("address", "")).lower() == "0x004a789a" for event in ledger.get("events", [])
        ),
        "all_invocations_complete": len(complete_invocations) == len(invocations) and bool(invocations),
        "all_descriptor_type_registers_match_descriptor_plus_0x1c": all(
            item.get("descriptor", {}).get("type_index_from_register_edi")
            == item.get("descriptor", {}).get("type_index_from_descriptor_plus_0x1c")
            for item in complete_invocations
        ),
        "all_descriptor_projection_flags_nonzero": all(
            item.get("descriptor", {}).get("projection_flag_plus_0x29") not in (None, 0)
            for item in complete_invocations
        ),
        "all_source_coordinates_match_descriptor_offsets": all(
            item.get("source_cell", {}).get("coordinate_matches_descriptor_offset_source") for item in complete_invocations
        ),
        "all_relation_counters_increment_by_one": all(
            item.get("relation_counter", {}).get("counter_incremented_by_one") for item in complete_invocations
        ),
        "all_relation_counter_slots_match_source_owner_relation": all(
            item.get("relation_counter", {}).get("counter_address_matches_source_owner_relation_type_slot")
            for item in complete_invocations
        ),
        "all_source_low_words_cleared": all(
            item.get("source_cell", {}).get("low_word_cleared_by_0x558a") for item in complete_invocations
        ),
        "static_dump_contains_descriptor_and_relation_counter_sequence": all(
            needle in dump_text
            for needle in [
                "004a54f7: MOV EDI,dword ptr [EAX + 0x1c]",
                "004a54fa: INC dword ptr [ESI + EDI*0x4 + 0x1110]",
                "004a5501: MOV CL,byte ptr [EAX + 0x29]",
                "004a550c: MOV EDX,dword ptr [EAX + 0x2c]",
                "004a550f: MOV EAX,dword ptr [EAX + 0x30]",
                "004a5576: MOV ESI,dword ptr [ESI + 0x10e4]",
                "004a557f: MOV EDX,dword ptr [ECX + EDI*0x4 + 0x44]",
                "004a5588: MOV dword ptr [ECX],EDX",
                "004a558a: AND word ptr [EAX + 0x20],0x0",
            ]
        ),
    }
    recovered = (
        invariants["native_behavior_changed"] is False
        and all(value for key, value in invariants.items() if key != "native_behavior_changed")
    )
    status = (
        "post_border_guard_4a54a7_descriptor_relation_counters_recovered"
        if recovered
        else "post_border_guard_4a54a7_descriptor_relation_counters_incomplete"
    )
    return {
        "schema_id": "h3maped_4a54a7_descriptor_relation_summary_v1",
        "status": status,
        "native_behavior_changed": False,
        "ledger": str(ledger_path),
        "static_dump": str(dump_path),
        "event_count": ledger.get("event_count"),
        "invocation_count": len(invocations),
        "descriptor_type_counts": dict(sorted(descriptor_types.items())),
        "return_address_counts": dict(sorted(return_addresses.items())),
        "invocations": invocations,
        "coordinate_reconciliation": {
            "afterstate_trace_callsite_events": callsite_events(afterstate_path),
            "projection_first_trace_callsite_events": callsite_events(projection_first_path),
            "projection_second_trace_callsite_events": callsite_events(projection_second_path),
            "finding": (
                "The first focused projection stream is not the same target-cell after-state invocation: it starts at "
                "an earlier 0x4a77a8 call with arg0=0x1388, while the after-state target later uses arg0=0x2422. "
                "The second projection stream and the newer descriptor traces agree on the sampled 0x4a7895 target "
                "(67,60,0), while the older after-state trace records (39,31,0); that remaining setup/state difference "
                "is not papered over and remains a bounded reconciliation gap."
            ),
        },
        "invariants": invariants,
        "remaining_blocker": (
            "Descriptor +0x29/+0x2c/+0x30 and relation-counter mechanics are recovered for the sampled trace: +0x29 gates "
            "projection, +0x2c/+0x30 are the x/y source-cell offsets subtracted from object coordinates, and relation+0x44 "
            "+ descriptor_type*4 is a per-relation descriptor-type occupancy counter selected from GeneratedCell+0x20 byte2. "
            "Full end-to-end recovery still needs downstream relation/control consumers and reconciliation of the older "
            "after-state trace's second target coordinates before native RMG behavior changes."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--afterstate-ledger", type=Path, default=DEFAULT_AFTERSTATE_LEDGER)
    parser.add_argument("--projection-first-ledger", type=Path, default=DEFAULT_PROJECTION_FIRST_LEDGER)
    parser.add_argument("--projection-second-ledger", type=Path, default=DEFAULT_PROJECTION_SECOND_LEDGER)
    parser.add_argument("--dump", type=Path, default=DEFAULT_DUMP)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args.ledger, args.afterstate_ledger, args.projection_first_ledger, args.projection_second_ledger, args.dump)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_4A54A7_DESCRIPTOR_RELATION_SUMMARY status={summary['status']} out={args.out}")
    return 0 if summary["status"].endswith("recovered") else 1


if __name__ == "__main__":
    raise SystemExit(main())
