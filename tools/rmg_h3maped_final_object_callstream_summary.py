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

FIRST_PASS_SITE = "0x004ad36f"
SECOND_PASS_SITE = "0x004ad3b1"
FINAL_SITE = "0x004ad3de"
SERIALIZER_SITES = {FIRST_PASS_SITE, SECOND_PASS_SITE}


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def words_at_event_line(event: dict[str, Any], index: int) -> list[int]:
    lines = event.get("memory_lines", [])
    if len(lines) <= index:
        return []
    return [int(word) & 0xFFFFFFFF for word in lines[index].get("words", [])]


def record_words(event: dict[str, Any]) -> list[int]:
    # After the mandatory stack dump, address-command dumps `x/8x $ecx`.
    return words_at_event_line(event, 2) + words_at_event_line(event, 3)


def vtable_words(event: dict[str, Any]) -> list[int]:
    # The next address-command dumps `x/8x *(int*)$ecx`.
    return words_at_event_line(event, 4) + words_at_event_line(event, 5)


def descriptor_wrapper_words(event: dict[str, Any]) -> list[int]:
    # The final address-command dumps `x/24x *(int*)($ecx+0x4)`.
    words: list[int] = []
    for index in range(6, 12):
        words.extend(words_at_event_line(event, index))
    return words


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


def summarize(ledger_path: Path) -> dict[str, Any]:
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
            "profile": "H3MapEd Medium one-level no-water seed 10, human/computer down 1, computer-only down 0",
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
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    summary = summarize(args.ledger)
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
