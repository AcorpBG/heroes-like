#!/usr/bin/env python3
"""Summarize final generated-object serialization callstream from H3MapEd.

This consumes a Wine trace over the two `0x4ad1e3` generated-object serializer
call sites. It records every object record pointer, object vtable, slot `+0x0c`
serializer target, coordinate triple, and sampled descriptor-wrapper words.
It does not claim field-level payload decoding of each serializer body.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_LEDGER = (
    ROOT
    / "medium_seed10_final_object_payload_callstream_20260610"
    / "winedbg_interactive_trace_ledger.json"
)
DEFAULT_OUT = ROOT / "final_object_callstream_summary_20260610.json"
DEFAULT_PROFILE = "H3MapEd Medium one-level no-water seed 10, human/computer down 1, computer-only down 0"

FIRST_PASS_SITE = "0x004ad36f"
SECOND_PASS_SITE = "0x004ad3b1"
FINAL_SITE = "0x004ad3de"
SERIALIZER_SITES = {FIRST_PASS_SITE, SECOND_PASS_SITE}


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def words_at_address(event: dict[str, Any], address: int | None, count: int) -> list[int]:
    if address is None:
        return []
    lines = event.get("memory_lines", [])
    for start, line in enumerate(lines):
        if int(line.get("address", -1)) != int(address):
            continue
        words: list[int] = []
        expected_address = int(address)
        for candidate in lines[start:]:
            if int(candidate.get("address", -1)) != expected_address:
                break
            candidate_words = [int(word) & 0xFFFFFFFF for word in candidate.get("words", [])]
            words.extend(candidate_words)
            expected_address += len(candidate_words) * 4
            if len(words) >= count:
                return words[:count]
        return words[:count]
    return []


def words_at_event_lines(event: dict[str, Any], start: int, line_count: int) -> list[int]:
    words: list[int] = []
    for line in event.get("memory_lines", [])[start : start + line_count]:
        words.extend(int(word) & 0xFFFFFFFF for word in line.get("words", []))
    return words


def record_words(event: dict[str, Any]) -> list[int]:
    words = words_at_address(event, event.get("registers", {}).get("ecx"), 8)
    return words if words else words_at_event_lines(event, 2, 2)


def vtable_words(event: dict[str, Any]) -> list[int]:
    record = record_words(event)
    words = words_at_address(event, record[0] if record else None, 8)
    return words if words else words_at_event_lines(event, 4, 2)


def descriptor_wrapper_words(event: dict[str, Any]) -> list[int]:
    record = record_words(event)
    words = words_at_address(event, record[1] if len(record) > 1 else None, 24)
    return words if words else words_at_event_lines(event, 6, 6)


def hex32(value: int | None) -> str | None:
    if value is None:
        return None
    return "0x%08x" % (int(value) & 0xFFFFFFFF)


def parse_serializer_event(event: dict[str, Any]) -> dict[str, Any]:
    rec = record_words(event)
    vt = vtable_words(event)
    wrapper = descriptor_wrapper_words(event)
    address = event["address"]
    pass_name = "first_flagged_pass" if address == FIRST_PASS_SITE else "second_unflagged_pass"
    slot_0c = vt[3] if len(vt) > 3 else None
    return {
        "site": address,
        "pass": pass_name,
        "loop_index": event.get("registers", {}).get("edi"),
        "object_record": event.get("registers", {}).get("ecx"),
        "object_vtable": rec[0] if len(rec) > 0 else None,
        "descriptor_wrapper": rec[1] if len(rec) > 1 else None,
        "x": rec[2] if len(rec) > 2 else None,
        "y": rec[3] if len(rec) > 3 else None,
        "z": rec[4] if len(rec) > 4 else None,
        "record_words": rec,
        "vtable_words": vt,
        "serializer_slot_0c": slot_0c,
        "descriptor_wrapper_words": wrapper,
    }


def counter_to_hex(counter: Counter[int]) -> dict[str, int]:
    return {hex32(key) or "null": counter[key] for key in sorted(counter)}


def summarize(ledger_path: Path, profile: str = DEFAULT_PROFILE) -> dict[str, Any]:
    ledger = load_json(ledger_path)
    serializer_events = [event for event in ledger.get("events", []) if event.get("address") in SERIALIZER_SITES]
    final_events = [event for event in ledger.get("events", []) if event.get("address") == FINAL_SITE]
    parsed = [parse_serializer_event(event) for event in serializer_events]

    by_site = Counter(item["site"] for item in parsed)
    by_vtable = Counter(int(item["object_vtable"]) for item in parsed if item["object_vtable"] is not None)
    by_slot = Counter(int(item["serializer_slot_0c"]) for item in parsed if item["serializer_slot_0c"] is not None)
    by_vtable_slot: dict[str, dict[str, Any]] = {}
    grouped: dict[tuple[int, int], list[dict[str, Any]]] = defaultdict(list)
    for item in parsed:
        if item["object_vtable"] is None or item["serializer_slot_0c"] is None:
            continue
        grouped[(int(item["object_vtable"]), int(item["serializer_slot_0c"]))].append(item)
    for (vtable, slot), items in sorted(grouped.items()):
        by_vtable_slot[f"{hex32(vtable)}->{hex32(slot)}"] = {
            "object_vtable": hex32(vtable),
            "serializer_slot_0c": hex32(slot),
            "count": len(items),
            "first_pass_count": sum(1 for item in items if item["site"] == FIRST_PASS_SITE),
            "second_pass_count": sum(1 for item in items if item["site"] == SECOND_PASS_SITE),
            "first_samples": [sample_event(item) for item in items[:3]],
        }

    unique_records = {item["object_record"] for item in parsed if item["object_record"] is not None}
    unique_coords = {
        (item["x"], item["y"], item["z"])
        for item in parsed
        if item["x"] is not None and item["y"] is not None and item["z"] is not None
    }
    final_event = final_events[-1] if final_events else {}
    final_registers = final_event.get("registers", {})
    callstream_complete = (
        bool(parsed)
        and len(final_events) == 1
        and final_registers.get("eax") == 4
        and final_registers.get("edi") == len(parsed)
        and all(item["serializer_slot_0c"] is not None for item in parsed)
    )

    return {
        "schema_id": "h3maped_final_object_callstream_summary_v1",
        "status": "final_object_callstream_recovered_payload_bodies_pending"
        if callstream_complete
        else "final_object_callstream_incomplete",
        "scope": {
            "profile": profile,
            "positive_claim": "same-run generated-object serialization callstream through both 0x4ad1e3 passes",
            "negative_claim": "does not decode every serializer function into field-level output bytes",
        },
        "inputs": {"ledger": str(ledger_path)},
        "metrics": {
            "trace_event_count": ledger.get("event_count"),
            "serializer_event_count": len(parsed),
            "first_pass_event_count": by_site.get(FIRST_PASS_SITE, 0),
            "second_pass_event_count": by_site.get(SECOND_PASS_SITE, 0),
            "final_success_event_count": len(final_events),
            "final_eax_before_success_test": final_registers.get("eax"),
            "final_edi_serialized_count": final_registers.get("edi"),
            "unique_object_record_count": len(unique_records),
            "unique_coordinate_count": len(unique_coords),
            "unique_object_vtable_count": len(by_vtable),
            "unique_serializer_slot_0c_count": len(by_slot),
            "final_object_callstream_replay_complete": callstream_complete,
            "generated_object_payload_replay_complete": False,
            "full_private_payload_replay_complete": False,
            "native_behavior_changed": False,
            "used_objdump": False,
            "overall_goal_complete": False,
        },
        "counts_by_object_vtable": counter_to_hex(by_vtable),
        "counts_by_serializer_slot_0c": counter_to_hex(by_slot),
        "counts_by_vtable_and_slot": by_vtable_slot,
        "first_events": [sample_event(item) for item in parsed[:8]],
        "last_events": [sample_event(item) for item in parsed[-8:]],
        "remaining_gap": (
            "The generated-object serialization order and dispatch targets are now recovered for this run. "
            "The remaining object payload blocker is field-level decoding of the unique slot +0x0c serializer functions."
        ),
    }


def sample_event(item: dict[str, Any]) -> dict[str, Any]:
    wrapper = item.get("descriptor_wrapper_words") or []
    return {
        "site": item["site"],
        "pass": item["pass"],
        "loop_index": item["loop_index"],
        "object_record": hex32(item["object_record"]),
        "object_vtable": hex32(item["object_vtable"]),
        "serializer_slot_0c": hex32(item["serializer_slot_0c"]),
        "descriptor_wrapper": hex32(item["descriptor_wrapper"]),
        "x": item["x"],
        "y": item["y"],
        "z": item["z"],
        "descriptor_wrapper_first_words": [hex32(word) for word in wrapper[:8]],
        "record_words": [hex32(word) for word in (item.get("record_words") or [])],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--profile", default=DEFAULT_PROFILE)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    summary = summarize(args.ledger, args.profile)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_FINAL_OBJECT_CALLSTREAM "
        f"status={summary['status']} "
        f"events={summary['metrics']['serializer_event_count']} "
        f"vtables={summary['metrics']['unique_object_vtable_count']} "
        f"serializers={summary['metrics']['unique_serializer_slot_0c_count']} "
        f"out={args.out}"
    )
    return 0 if summary["metrics"]["final_object_callstream_replay_complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
