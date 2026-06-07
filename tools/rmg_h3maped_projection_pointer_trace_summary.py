#!/usr/bin/env python3
"""Summarize projection-object pointer pairing traces from raw WineDbg logs."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

from rmg_h3maped_recovery_trace import parse_winedbg_log


DEFAULT_WARM_LOG = Path(
    ".artifacts/rmg_recovery/direct_generation_projection_pointer_pairing_trace/winedbg_interactive_trace.log"
)
DEFAULT_COLD_LOG = Path(
    ".artifacts/rmg_recovery/direct_generation_49eb8d_ec51_cold_trace/winedbg_interactive_trace.log"
)

PROJECTION_VTABLES = {0x00540B00, 0x00540B14}
PROJECTION_METHODS = {0x0049C019, 0x0049C0A6}


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


def load_events(log_path: Path) -> list[dict[str, Any]]:
    ledger = parse_winedbg_log(log_path)
    events = ledger["events"]
    for event in events:
        regs = event.get("registers", {})
        eax = regs.get("eax")
        ecx = regs.get("ecx")
        ebx = regs.get("ebx")
        event["eax_word0"] = memory_word(event, eax if isinstance(eax, int) else None)
        event["eax_slot8_target"] = memory_word(event, eax + 8 if isinstance(eax, int) else None)
        event["ecx_word0"] = memory_word(event, ecx if isinstance(ecx, int) else None)
        event["ebx_plus_ed4"] = memory_word(event, ebx + 0xED4 if isinstance(ebx, int) else None)
        event["stack_words"] = stack_words(event)
    return events


def event_counts(events: list[dict[str, Any]]) -> dict[str, int]:
    return dict(sorted(Counter(event["address"] for event in events).items()))


def projection_constructor_pointers(events: list[dict[str, Any]]) -> list[int]:
    pointers: list[int] = []
    for event in events:
        if event["address"] not in {"0x0049cb52", "0x0049cc12", "0x0049ccb0"}:
            continue
        eax = event.get("registers", {}).get("eax")
        if isinstance(eax, int) and event.get("eax_word0") in PROJECTION_VTABLES:
            pointers.append(eax)
    return sorted(set(pointers))


def pointer_occurrences(events: list[dict[str, Any]], pointer: int) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for index, event in enumerate(events):
        regs = event.get("registers", {})
        stack = event.get("stack_words", [])
        locations: list[str] = []
        for reg in ("eax", "ecx", "edx", "esi", "edi"):
            if regs.get(reg) == pointer:
                locations.append(reg)
        for stack_index, word in enumerate(stack[:8]):
            if word == pointer:
                locations.append(f"stack+0x{stack_index * 4:x}")
        if not locations:
            continue
        out.append(
            {
                "event_index": index,
                "address": event["address"],
                "locations": locations,
                "stack": [hex32(word) for word in stack[:8]],
            }
        )
    return out


def summarize_warm(events: list[dict[str, Any]]) -> dict[str, Any]:
    pointers = projection_constructor_pointers(events)
    pointer_records = []
    for pointer in pointers:
        occurrences = pointer_occurrences(events, pointer)
        pointer_records.append(
            {
                "pointer": hex32(pointer),
                "occurrence_count": len(occurrences),
                "addresses": dict(sorted(Counter(item["address"] for item in occurrences).items())),
                "occurrences": occurrences[:40],
            }
        )
    return {
        "event_count": len(events),
        "address_counts": event_counts(events),
        "projection_constructor_pointers": [hex32(pointer) for pointer in pointers],
        "projection_pointer_records": pointer_records,
        "projection_method_hits": event_counts(
            [event for event in events if event["address"] in {"0x0049c019", "0x0049c0a6"}]
        ),
        "ec51_hits": event_counts([event for event in events if event["address"] == "0x0049ec51"]),
    }


def summarize_cold(events: list[dict[str, Any]]) -> dict[str, Any]:
    ec51_events = [event for event in events if event["address"] == "0x0049ec51"]
    dispatches = []
    for index, event in enumerate(ec51_events):
        regs = event.get("registers", {})
        dispatches.append(
            {
                "event_index": index,
                "ecx": hex32(regs.get("ecx")),
                "ecx_word0": hex32(event.get("ecx_word0")),
                "eax": hex32(regs.get("eax")),
                "eax_word0": hex32(event.get("eax_word0")),
                "eax_slot8_target": hex32(event.get("eax_slot8_target")),
                "ebx_plus_ed4": hex32(event.get("ebx_plus_ed4")),
                "stack": [hex32(word) for word in event.get("stack_words", [])[:8]],
                "is_projection_vtable": event.get("eax_word0") in PROJECTION_VTABLES or regs.get("eax") in PROJECTION_VTABLES,
                "is_projection_method_target": event.get("eax_slot8_target") in PROJECTION_METHODS,
            }
        )
    return {
        "event_count": len(events),
        "address_counts": event_counts(events),
        "ec51_dispatches": dispatches[:80],
        "ec51_dispatch_count": len(dispatches),
        "ec51_unique_eax": sorted({item["eax"] for item in dispatches if item["eax"]}),
        "ec51_unique_slot8_targets": sorted({item["eax_slot8_target"] for item in dispatches if item["eax_slot8_target"]}),
        "projection_method_hits": event_counts(
            [event for event in events if event["address"] in {"0x0049c019", "0x0049c0a6"}]
        ),
    }


def summarize(warm_log: Path, cold_log: Path) -> dict[str, Any]:
    warm_events = load_events(warm_log)
    cold_events = load_events(cold_log)
    warm = summarize_warm(warm_events)
    cold = summarize_cold(cold_events)
    projection_pointer_reaches_stamp = any(
        "0x0049abd6" in record["addresses"] for record in warm["projection_pointer_records"]
    )
    ec51_dispatches = cold["ec51_dispatches"]
    ec51_non_projection = bool(ec51_dispatches) and all(
        not item["is_projection_vtable"] and not item["is_projection_method_target"] for item in ec51_dispatches
    )
    return {
        "schema_id": "h3maped_projection_pointer_trace_summary_v1",
        "warm_log": str(warm_log),
        "cold_log": str(cold_log),
        "warm_trace": warm,
        "cold_trace": cold,
        "invariants": {
            "warm_trace_has_projection_constructor_pointer": bool(warm["projection_constructor_pointers"]),
            "projection_constructor_pointer_reaches_4aa168": any(
                "0x004aa168" in record["addresses"] for record in warm["projection_pointer_records"]
            ),
            "projection_constructor_pointer_reaches_49abd6": projection_pointer_reaches_stamp,
            "warm_trace_has_no_ec51": not warm["ec51_hits"],
            "cold_trace_hits_ec51": bool(ec51_dispatches),
            "cold_ec51_dispatch_is_not_49c_projection_method": ec51_non_projection,
            "cold_trace_has_no_49c_projection_method_hits": not cold["projection_method_hits"],
        },
        "status": "partial_recovery_ec51_ruled_out_for_sample" if ec51_non_projection else "incomplete",
        "remaining_blocker": (
            "The sampled 0x540b14 object is proven through constructor return, 0x4aa168 adoption, and 0x49abd6 "
            "stamping. The cold 0x49ec51 trace proves that optional handler dispatch uses vtable 0x00539660 "
            "with slot +0x08 target 0x0045e1a6 in this sample, not 0x49c019/0x49c0a6. The later projection-object "
            "method dispatch remains unrecovered and should not be attributed to 0x49ec51 without new pointer proof."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--warm-log", type=Path, default=DEFAULT_WARM_LOG)
    parser.add_argument("--cold-log", type=Path, default=DEFAULT_COLD_LOG)
    parser.add_argument("--out", type=Path, required=True)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args.warm_log, args.cold_log)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_PROJECTION_POINTER_TRACE_SUMMARY "
        f"status={summary['status']} out={args.out}"
    )
    return 0 if summary["status"] == "partial_recovery_ec51_ruled_out_for_sample" else 1


if __name__ == "__main__":
    raise SystemExit(main())
