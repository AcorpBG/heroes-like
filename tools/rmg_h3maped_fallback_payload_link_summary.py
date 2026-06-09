#!/usr/bin/env python3
"""Summarize post-Border-Guard fallback object linkage to 0x4a79a3 payload.

This report parses a seed-pinned WineDbg ledger that captures:

- natural Border Guard endpoint failure sites,
- 0x4a5e03 / 0x4a5e55 object construction boundaries,
- 0x4a79a3 / 0x4a7d36 payload iteration.

It answers one narrow recovery question: do the two post-Border-Guard
0x4a7605-owned fallback objects appear in the sampled 0x4a79a3 payload loop,
or is that payload loop an earlier consumer surface for pre-fallback objects?
The report is recovery evidence only and does not mutate native RMG behavior.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_LEDGER = Path(
    ".artifacts/rmg_recovery/medium_seed10_hc1_co1_fallback_payload_link_trace_20260609/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_OUT = Path(
    ".artifacts/rmg_recovery/medium_seed10_hc1_co1_fallback_payload_link_summary_20260609.json"
)

ADDR_5E03 = "0x004a5e03"
ADDR_5E55 = "0x004a5e55"
ADDR_7D36 = "0x004a7d36"
ADDR_7D99 = "0x004a7d99"
ADDR_79A3 = "0x004a79a3"

PRE_BG_RETURN = "0x004a657d"
FALLBACK_RETURNS = {"0x004a77ad", "0x004a789a"}
LATER_RETURN = "0x004a9af6"


def hex32(value: int | None) -> str | None:
    return None if value is None else f"0x{value & 0xFFFFFFFF:08x}"


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def address(event: dict[str, Any]) -> str:
    return str(event.get("address", "")).lower()


def return_address(event: dict[str, Any]) -> str | None:
    return event.get("derived", {}).get("return_address")


def regs(event: dict[str, Any]) -> dict[str, int]:
    return event.get("registers", {})


def classify_5e03_return(ret: str | None) -> str:
    if ret == PRE_BG_RETURN:
        return "pre_border_guard_4a61bc_materialization"
    if ret in FALLBACK_RETURNS:
        return "post_border_guard_7605_fallback_materialization"
    if ret == LATER_RETURN:
        return "later_generation_path"
    return "unknown"


def collect_constructed_records(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    pending: dict[str, Any] | None = None
    for event_index, event in enumerate(events, start=1):
        event_address = address(event)
        if event_address == ADDR_5E03:
            ret = return_address(event)
            pending = {
                "entry_event_index": event_index,
                "return_address": ret,
                "caller_class": classify_5e03_return(ret),
                "entry_registers": {
                    "eax": hex32(regs(event).get("eax")),
                    "ecx": hex32(regs(event).get("ecx")),
                    "edx": hex32(regs(event).get("edx")),
                    "esp": hex32(regs(event).get("esp")),
                },
            }
            continue
        if event_address != ADDR_5E55 or pending is None:
            continue
        pointer = regs(event).get("eax")
        pending.update(
            {
                "object_event_index": event_index,
                "object_record": hex32(pointer),
                "object_record_int": pointer,
                "object_registers": {
                    "eax": hex32(regs(event).get("eax")),
                    "ecx": hex32(regs(event).get("ecx")),
                    "edx": hex32(regs(event).get("edx")),
                    "esp": hex32(regs(event).get("esp")),
                },
            }
        )
        records.append(pending)
        pending = None
    return records


def collect_payload_records(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    payload: list[dict[str, Any]] = []
    for event_index, event in enumerate(events, start=1):
        if address(event) != ADDR_7D36:
            continue
        pointer = regs(event).get("edx")
        payload.append(
            {
                "event_index": event_index,
                "payload_record": hex32(pointer),
                "payload_record_int": pointer,
                "is_null_priming_stop": pointer == 0,
            }
        )
    return payload


def summarize(ledger_path: Path) -> dict[str, Any]:
    ledger = load_json(ledger_path)
    events = ledger.get("events", [])
    counts = Counter(address(event) for event in events)
    constructed = collect_constructed_records(events)
    payload = collect_payload_records(events)

    fallback = [
        record for record in constructed
        if record["caller_class"] == "post_border_guard_7605_fallback_materialization"
    ]
    pre_bg = [
        record for record in constructed
        if record["caller_class"] == "pre_border_guard_4a61bc_materialization"
    ]
    later = [
        record for record in constructed
        if record["caller_class"] == "later_generation_path"
    ]
    payload_non_null = [
        record for record in payload
        if not record["is_null_priming_stop"]
    ]
    payload_pointers = {
        record["payload_record_int"]
        for record in payload_non_null
        if isinstance(record.get("payload_record_int"), int)
    }
    fallback_pointers = {
        record["object_record_int"]
        for record in fallback
        if isinstance(record.get("object_record_int"), int)
    }
    pre_bg_pointers = {
        record["object_record_int"]
        for record in pre_bg
        if isinstance(record.get("object_record_int"), int)
    }

    fallback_payload_matches = sorted(fallback_pointers & payload_pointers)
    pre_bg_payload_matches = sorted(pre_bg_pointers & payload_pointers)
    payload_start = min((record["event_index"] for record in payload), default=None)
    payload_end = max((record["event_index"] for record in payload), default=None)
    first_fallback_event = min((record["object_event_index"] for record in fallback), default=None)

    invariants = {
        "native_behavior_changed": False,
        "payload_loop_observed": counts.get(ADDR_79A3, 0) > 0 and bool(payload),
        "payload_count_site_observed": counts.get(ADDR_7D99, 0) > 0,
        "two_pre_border_guard_records_constructed": len(pre_bg) == 2,
        "two_post_border_guard_fallback_records_constructed": len(fallback) == 2,
        "fallback_constructed_after_payload_loop": (
            payload_end is not None
            and first_fallback_event is not None
            and first_fallback_event > payload_end
        ),
        "fallback_records_absent_from_sampled_payload": not fallback_payload_matches,
        "pre_border_guard_records_present_in_sampled_payload": len(pre_bg_payload_matches) == len(pre_bg),
    }
    recovered = (
        invariants["payload_loop_observed"]
        and invariants["payload_count_site_observed"]
        and invariants["two_pre_border_guard_records_constructed"]
        and invariants["two_post_border_guard_fallback_records_constructed"]
        and invariants["fallback_constructed_after_payload_loop"]
        and invariants["fallback_records_absent_from_sampled_payload"]
        and invariants["pre_border_guard_records_present_in_sampled_payload"]
    )
    status = (
        "fallback_records_constructed_after_payload_not_consumed_by_sampled_4a79a3"
        if recovered
        else "fallback_payload_linkage_partial"
    )
    return {
        "schema_id": "h3maped_fallback_payload_link_summary_v1",
        "status": status,
        "native_behavior_changed": False,
        "ledger": str(ledger_path),
        "seed_control": ledger.get("seed_control"),
        "child_returncode": ledger.get("child_returncode"),
        "event_count": len(events),
        "event_counts": dict(sorted(counts.items())),
        "constructed_records": [
            {key: value for key, value in record.items() if not key.endswith("_int")}
            for record in constructed
        ],
        "pre_border_guard_records": [
            {key: value for key, value in record.items() if not key.endswith("_int")}
            for record in pre_bg
        ],
        "post_border_guard_fallback_records": [
            {key: value for key, value in record.items() if not key.endswith("_int")}
            for record in fallback
        ],
        "later_generation_records": [
            {key: value for key, value in record.items() if not key.endswith("_int")}
            for record in later
        ],
        "payload_records": [
            {key: value for key, value in record.items() if not key.endswith("_int")}
            for record in payload
        ],
        "payload_window": {
            "start_event_index": payload_start,
            "end_event_index": payload_end,
            "non_null_count": len(payload_non_null),
        },
        "fallback_payload_matches": [hex32(pointer) for pointer in fallback_payload_matches],
        "pre_border_guard_payload_matches": [hex32(pointer) for pointer in pre_bg_payload_matches],
        "invariants": invariants,
        "source_backed_conclusion": (
            "In this deterministic Medium seed-10 trace, the sampled 0x4a79a3 payload loop consumes the two "
            "pre-Border-Guard 0x4a61bc materialization records, then the natural Border Guard branch fails "
            "0x4a5e73 endpoint stamping and constructs two fallback objects through 0x4a7605 -> 0x4a5e03 "
            "after the payload loop has already ended. Those fallback records are therefore not consumed by "
            "the sampled 0x4a79a3 payload loop in this pass."
        ),
        "remaining_gap": (
            "Recover later consumers for the post-Border-Guard fallback records after their 0x4a54a7 commit, "
            "or prove their role is final object-vector/cell adoption for this phase. Also continue the "
            "0x4a696b direct-mutation and 0x4add76 cleanup/uncommit recovery blockers."
        ),
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
        "RMG_H3MAPED_FALLBACK_PAYLOAD_LINK_SUMMARY "
        f"status={summary['status']} "
        f"fallback_records={len(summary['post_border_guard_fallback_records'])} "
        f"payload_non_null={summary['payload_window']['non_null_count']} "
        f"matches={len(summary['fallback_payload_matches'])} "
        f"out={args.out}"
    )
    return 0 if summary["status"].startswith("fallback_records_constructed") else 1


if __name__ == "__main__":
    raise SystemExit(main())
