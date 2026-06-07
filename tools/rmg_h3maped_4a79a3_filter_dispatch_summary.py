#!/usr/bin/env python3
"""Summarize H3MapEd 0x4a79a3 filter and dispatch traces."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

from rmg_h3maped_recovery_trace import parse_winedbg_log


DEFAULT_FILTER_LOG = Path(
    ".artifacts/rmg_recovery/direct_generation_4a79a3_filter_call_trace/winedbg_interactive_trace.log"
)
DEFAULT_DISPATCH_LOG = Path(
    ".artifacts/rmg_recovery/direct_generation_4a79a3_c8_dispatch_trace/winedbg_interactive_trace.log"
)
DEFAULT_PAYLOAD_SUMMARY = Path(".artifacts/rmg_recovery/4a79a3_payload_trace_summary.json")
DEFAULT_OUT = Path(".artifacts/rmg_recovery/4a79a3_filter_dispatch_summary.json")


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


def stack_word(event: dict[str, Any], index: int) -> int | None:
    esp = event.get("registers", {}).get("esp")
    if not isinstance(esp, int):
        return None
    return memory_word(event, esp + index * 4)


def words_at(event: dict[str, Any], address: int | None, count: int) -> list[int | None]:
    if address is None:
        return []
    return [memory_word(event, address + offset * 4) for offset in range(count)]


def load_payload_records(path: Path) -> dict[int, dict[str, Any]]:
    if not path.exists():
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    records: dict[int, dict[str, Any]] = {}
    for record in data.get("records", []):
        pointer = record.get("record_pointer")
        if isinstance(pointer, str):
            records[int(pointer, 16)] = record
    return records


def summarize_filter_trace(filter_log: Path, payload_summary: Path) -> dict[str, Any]:
    payload_records = load_payload_records(payload_summary)
    ledger = parse_winedbg_log(filter_log)
    events = ledger["events"]
    records: list[dict[str, Any]] = []
    source_type_counts: Counter[str] = Counter()
    source_id_counts: Counter[str] = Counter()
    for index, event in enumerate(events):
        if event["address"] != "0x004a7d51":
            continue
        regs = event.get("registers", {})
        source = regs.get("eax")
        record_pointer = regs.get("edx")
        if not isinstance(source, int) or not isinstance(record_pointer, int):
            continue
        source_words = words_at(event, source, 16)
        source_type = source_words[7] if len(source_words) > 7 else None
        source_id = source_words[0] if source_words else None
        source_type_counts[hex32(source_type) or "null"] += 1
        source_id_counts[hex32(source_id) or "null"] += 1
        payload = payload_records.get(record_pointer, {})
        records.append(
            {
                "event_index": index,
                "record_pointer": hex32(record_pointer),
                "record_vtable": payload.get("record_vtable"),
                "coordinate_or_payload_words_08_10": payload.get("coordinate_or_payload_words_08_10"),
                "source_pointer": hex32(source),
                "source_id_or_type_word_00": source_id,
                "source_word_18": source_words[6] if len(source_words) > 6 else None,
                "source_type_word_1c": source_type,
                "passes_source_type_0x57_gate": source_type == 0x57,
            }
        )
    address_counts = Counter(event["address"] for event in events)
    return {
        "log_path": str(filter_log),
        "event_count": len(events),
        "address_counts": dict(sorted(address_counts.items())),
        "source_check_count": len(records),
        "source_type_word_1c_counts": dict(sorted(source_type_counts.items())),
        "source_word_00_counts": dict(sorted(source_id_counts.items())),
        "records": records,
        "records_passing_source_type_0x57": [
            record for record in records if record["passes_source_type_0x57_gate"]
        ],
        "call_sites_after_filter": {
            "0x004a7d89_push_record": address_counts.get("0x004a7d89", 0),
            "0x004a68e0": address_counts.get("0x004a68e0", 0),
        },
    }


def summarize_dispatch_trace(dispatch_log: Path) -> dict[str, Any]:
    ledger = parse_winedbg_log(dispatch_log)
    events = ledger["events"]
    address_counts = Counter(event["address"] for event in events)
    call_records: list[dict[str, Any]] = []
    for index, event in enumerate(events):
        site = event["address"]
        if site not in {"0x004a696b", "0x004a7605", "0x004a7df4", "0x004a7e21", "0x004a7e25"}:
            continue
        regs = event.get("registers", {})
        ret = stack_word(event, 0)
        from_4a79a3 = ret in {0x004A7DFF, 0x004A7E1E}
        record_pointer = regs.get("esi") if isinstance(regs.get("esi"), int) else None
        matched_pointer = regs.get("eax") if isinstance(regs.get("eax"), int) else None
        record_words = words_at(event, record_pointer, 12) if record_pointer else []
        matched_words = words_at(event, matched_pointer, 12) if matched_pointer else []
        call_records.append(
            {
                "event_index": index,
                "site": site,
                "return_address": hex32(ret),
                "from_4a79a3_dispatch": from_4a79a3,
                "record_pointer_esi": hex32(record_pointer),
                "matched_record_pointer_eax": hex32(matched_pointer),
                "record_words_sample": [hex32(word) for word in record_words],
                "matched_record_words_sample": [hex32(word) for word in matched_words],
            }
        )
    return {
        "log_path": str(dispatch_log),
        "event_count": len(events),
        "address_counts": dict(sorted(address_counts.items())),
        "call_records": call_records,
        "from_4a79a3_counts": dict(
            sorted(Counter(record["site"] for record in call_records if record["from_4a79a3_dispatch"]).items())
        ),
        "trace_limit_note": "The interactive driver timed out after useful partial dispatch hits.",
    }


def summarize(filter_log: Path, dispatch_log: Path, payload_summary: Path) -> dict[str, Any]:
    filter_summary = summarize_filter_trace(filter_log, payload_summary)
    dispatch_summary = summarize_dispatch_trace(dispatch_log)
    invariants = {
        "filter_trace_has_events": filter_summary["event_count"] > 0,
        "all_19_payload_records_reached_source_type_check": filter_summary["source_check_count"] == 19,
        "no_0xec8_records_passed_source_type_0x57_gate_in_sample": not filter_summary[
            "records_passing_source_type_0x57"
        ],
        "no_4a68e0_call_in_filter_sample": filter_summary["call_sites_after_filter"]["0x004a68e0"] == 0,
        "dispatch_trace_has_events": dispatch_summary["event_count"] > 0,
        "dispatch_trace_hit_4a696b_from_4a79a3": dispatch_summary["from_4a79a3_counts"].get(
            "0x004a696b", 0
        )
        >= 1,
        "dispatch_trace_hit_4a7605_from_4a79a3": dispatch_summary["from_4a79a3_counts"].get(
            "0x004a7605", 0
        )
        >= 1,
        "dispatch_trace_hit_pair_mark_sites": dispatch_summary["address_counts"].get("0x004a7e21", 0)
        >= 1
        and dispatch_summary["address_counts"].get("0x004a7e25", 0) >= 1,
    }
    status = "partial_live_recovery_4a79a3_filter_and_c8_dispatch" if all(invariants.values()) else "incomplete"
    return {
        "schema_id": "h3maped_4a79a3_filter_dispatch_summary_v1",
        "status": status,
        "invariants": invariants,
        "filter_summary": filter_summary,
        "dispatch_summary": dispatch_summary,
        "recovered_contract": (
            "The sampled +0xec8 object-vector records all reached the nested source-type comparison at "
            "0x4a7d51, but none had source+0x1c == 0x57, so the 0x4a68e0 call path did not execute in "
            "this sample. The later +0xc8/+0xcc dispatch path did execute one 0x4a79a3-owned "
            "0x4a696b call, fell through to 0x4a7605, then reached the paired record mark sites "
            "0x4a7e21 and 0x4a7e25."
        ),
        "remaining_gap": (
            "Recover the 0x4a696b/0x4a7605 callee-side generated-cell mutations and exact semantic names "
            "for the +0xc8 records, then connect those writes back to the 0x4a79a3 dispatch record pair."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--filter-log", type=Path, default=DEFAULT_FILTER_LOG)
    parser.add_argument("--dispatch-log", type=Path, default=DEFAULT_DISPATCH_LOG)
    parser.add_argument("--payload-summary", type=Path, default=DEFAULT_PAYLOAD_SUMMARY)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args.filter_log, args.dispatch_log, args.payload_summary)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_4A79A3_FILTER_DISPATCH_SUMMARY "
        f"status={summary['status']} out={args.out}"
    )
    return 0 if summary["status"] == "partial_live_recovery_4a79a3_filter_and_c8_dispatch" else 1


if __name__ == "__main__":
    raise SystemExit(main())
