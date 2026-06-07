#!/usr/bin/env python3
"""Summarize a focused H3MapEd projection-object 0x4add76 consumer trace."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

from rmg_h3maped_recovery_trace import parse_winedbg_log


DEFAULT_LOG = Path(
    ".artifacts/rmg_recovery/direct_generation_projection_4add76_consumer_trace/winedbg_interactive_trace.log"
)

PROJECTION_VTABLES = {0x00540B00, 0x00540B14}
PROJECTION_METHODS = {"0x0049c019", "0x0049c0a6"}
DOWNSTREAM_CONSUMERS = {"0x004add76", "0x004adef7", "0x004adb72", "0x004ad947"}
STORAGE_SITES = {"0x004a54d1", "0x004a54ea"}
CONSTRUCTOR_RETURN_SITES = {"0x0049cb52", "0x0049cc12", "0x0049ccb0"}


def hex32(value: int | None) -> str | None:
    return None if value is None else f"0x{value & 0xFFFFFFFF:08x}"


def memory_word(event: dict[str, Any], address: int | None) -> int | None:
    if address is None:
        return None
    for line in event.get("memory_lines", []):
        base = int(line["address"])
        words = line.get("words", [])
        if base <= address < base + len(words) * 4 and (address - base) % 4 == 0:
            return int(words[(address - base) // 4]) & 0xFFFFFFFF
    return None


def stack_words(event: dict[str, Any], count: int = 8) -> list[int | None]:
    esp = event.get("registers", {}).get("esp")
    if not isinstance(esp, int):
        return []
    return [memory_word(event, esp + index * 4) for index in range(count)]


def event_counts(events: list[dict[str, Any]]) -> dict[str, int]:
    return dict(sorted(Counter(event["address"] for event in events).items()))


def load_events(log_path: Path) -> list[dict[str, Any]]:
    ledger = parse_winedbg_log(log_path)
    events = ledger["events"]
    for event in events:
        regs = event.get("registers", {})
        eax = regs.get("eax")
        event["stack_words"] = stack_words(event)
        event["eax_word0"] = memory_word(event, eax if isinstance(eax, int) else None)
    return events


def vector_snapshot(event: dict[str, Any]) -> dict[str, Any] | None:
    regs = event.get("registers", {})
    base: int | None = None
    if event["address"] == "0x004a54d1" and isinstance(regs.get("ecx"), int):
        base = int(regs["ecx"]) + 0xEC4
    elif event["address"] == "0x004a54ea" and isinstance(regs.get("esi"), int):
        base = int(regs["esi"]) + 0xEC4
    elif event["address"] in {"0x004add76", "0x004add98", "0x004addb3"} and isinstance(regs.get("ebx"), int):
        base = int(regs["ebx"]) + 0xEC4
    if base is None:
        return None
    words = [memory_word(event, base + offset * 4) for offset in range(8)]
    return {
        "base": hex32(base),
        "words": [hex32(word) for word in words],
        "begin_candidate": hex32(words[1] if len(words) > 1 else None),
        "end_candidate": hex32(words[2] if len(words) > 2 else None),
        "capacity_candidate": hex32(words[3] if len(words) > 3 else None),
    }


def summarize_projection_constructor_events(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for index, event in enumerate(events):
        if event["address"] not in CONSTRUCTOR_RETURN_SITES:
            continue
        regs = event.get("registers", {})
        eax = regs.get("eax")
        vtable = event.get("eax_word0")
        if vtable not in PROJECTION_VTABLES:
            continue
        records.append(
            {
                "event_index": index,
                "site": event["address"],
                "pointer": hex32(eax),
                "vtable": hex32(vtable),
                "stack": [hex32(word) for word in event.get("stack_words", [])[:8]],
            }
        )
    return records


def summarize_storage_events(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    for index, event in enumerate(events):
        if event["address"] not in STORAGE_SITES:
            continue
        regs = event.get("registers", {})
        pointer = regs.get("eax") if event["address"] == "0x004a54d1" else None
        vtable = event.get("eax_word0") if pointer is not None else None
        snapshot = vector_snapshot(event)
        records.append(
            {
                "event_index": index,
                "site": event["address"],
                "object_pointer": hex32(pointer if isinstance(pointer, int) else None),
                "object_vtable": hex32(vtable if isinstance(vtable, int) else None),
                "is_projection_vtable": vtable in PROJECTION_VTABLES,
                "vector_snapshot": snapshot,
            }
        )
    return records


def summarize(log_path: Path) -> dict[str, Any]:
    events = load_events(log_path)
    counts = event_counts(events)
    projection_constructor_records = summarize_projection_constructor_events(events)
    storage_records = summarize_storage_events(events)
    storage_vtable_counts = Counter(
        record["object_vtable"] for record in storage_records if record.get("object_vtable")
    )
    consumer_hits = {address: counts.get(address, 0) for address in sorted(DOWNSTREAM_CONSUMERS)}
    projection_method_hits = {address: counts.get(address, 0) for address in sorted(PROJECTION_METHODS)}
    invariants = {
        "trace_has_events": bool(events),
        "storage_callbacks_hit": bool(counts.get("0x004a54d1") and counts.get("0x004a54ea")),
        "projection_constructor_returns_sampled": bool(projection_constructor_records),
        "storage_vector_snapshots_observed": any(record.get("vector_snapshot") for record in storage_records),
        "no_4add76_or_projection_driver_hits_in_bounded_sample": not any(consumer_hits.values())
        and not any(projection_method_hits.values()),
    }
    status = "partial_recovery_4add76_nohit_storage_observed" if all(invariants.values()) else "incomplete"
    return {
        "schema_id": "h3maped_projection_4add76_trace_summary_v1",
        "log_path": str(log_path),
        "event_count": len(events),
        "address_counts": counts,
        "projection_constructor_records": projection_constructor_records,
        "storage_record_count": len(storage_records),
        "storage_vtable_counts": dict(sorted(storage_vtable_counts.items())),
        "storage_records_sample": storage_records[:40],
        "downstream_consumer_hits": consumer_hits,
        "projection_method_hits": projection_method_hits,
        "invariants": invariants,
        "status": status,
        "remaining_blocker": (
            "This bounded direct-generation trace observes sampled 0x540b14 constructor returns and many "
            "0x4a54a7 storage/stamp callbacks, but it records no 0x4add76/0x4adef7/0x4adb72/0x4ad947 "
            "consumer hits and no 0x49c019/0x49c0a6 projection-method hits. The 0x4add76 static cleanup "
            "path remains a plausible downstream consumer class, but direct-generation pointer-paired replay "
            "for the sampled projection objects is still unrecovered."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--log", type=Path, default=DEFAULT_LOG)
    parser.add_argument("--out", type=Path, required=True)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args.log)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_PROJECTION_4ADD76_TRACE_SUMMARY "
        f"status={summary['status']} events={summary['event_count']} out={args.out}"
    )
    return 0 if summary["status"] == "partial_recovery_4add76_nohit_storage_observed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
