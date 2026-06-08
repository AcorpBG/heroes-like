#!/usr/bin/env python3
"""Compare same-run projection selection and 0x4a79a3 payload evidence.

This is a recovery checkpoint, not a native RMG behavior change. It prevents
overclaiming the current traces by separating two evidence surfaces:

- selected-create returns at 0x4aa168, including projection-object vtables;
- later object-vector payload records consumed by 0x4a79a3/0x4a7d36.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_BROAD_LEDGER = Path(
    ".artifacts/rmg_recovery/same_run_projection_to_4a79a3_trace_20260608/"
    "partial_winedbg_interactive_trace_ledger.json"
)
DEFAULT_LITE_LEDGER = Path(
    ".artifacts/rmg_recovery/same_run_projection_to_4a79a3_trace_lite_20260608/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_LITE_PAYLOAD = Path(
    ".artifacts/rmg_recovery/same_run_projection_to_4a79a3_trace_lite_20260608/"
    "4a79a3_payload_summary.json"
)
DEFAULT_TIGHT_LEDGER = Path(
    ".artifacts/rmg_recovery/same_run_projection_payload_tight_trace_20260608/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_TIGHT_PAYLOAD = Path(
    ".artifacts/rmg_recovery/same_run_projection_payload_tight_trace_20260608/"
    "4a79a3_payload_summary.json"
)
DEFAULT_OUT = Path(
    ".artifacts/rmg_recovery/same_run_projection_payload_link_summary_20260608.json"
)

SELECTED_RETURN_SITE = "0x004aa168"
STAMP_SITE = "0x0049abd6"
INITIAL_CONSUMER_SITE = "0x004aa27e"
PAYLOAD_ENTRY_SITE = "0x004a79a3"
PAYLOAD_RECORD_SITE = "0x004a7d36"
PAYLOAD_COUNT_SITE = "0x004a7d99"

PROJECTION_OBJECT_VTABLES = {"0x00540b00", "0x00540b14"}
PROJECTION_BASE_VTABLE = "0x00540b28"
ORDINARY_PAYLOAD_VTABLES = {"0x00540a88", "0x00540a9c"}


def hex32(value: int | None) -> str | None:
    return None if value is None else f"0x{value & 0xFFFFFFFF:08x}"


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def memory_words(event: dict[str, Any], address: int | None) -> list[int]:
    if address is None:
        return []
    for line in event.get("memory_lines", []):
        if int(line.get("address", -1)) == address:
            return [int(word) & 0xFFFFFFFF for word in line.get("words", [])]
    return []


def pointer_record(event_index: int, event: dict[str, Any], register: str) -> dict[str, Any]:
    regs = event.get("registers", {})
    pointer = regs.get(register)
    words = memory_words(event, pointer if isinstance(pointer, int) else None)
    vtable = words[0] if words else None
    descriptor = words[1] if len(words) > 1 else None
    return {
        "event_index": event_index,
        "site": event.get("address"),
        "register": register,
        "pointer": hex32(pointer if isinstance(pointer, int) else None),
        "vtable": hex32(vtable),
        "descriptor_pointer": hex32(descriptor),
        "words_prefix": [hex32(word) for word in words[:8]],
    }


def summarize_ledger(path: Path) -> dict[str, Any]:
    ledger = load_json(path)
    events = ledger.get("events", [])
    address_counts = Counter(event.get("address") for event in events)

    selected_records: list[dict[str, Any]] = []
    stamp_records: list[dict[str, Any]] = []
    consumer_records: list[dict[str, Any]] = []
    payload_entry_records: list[dict[str, Any]] = []
    payload_record_records: list[dict[str, Any]] = []

    for event_index, event in enumerate(events):
        address = event.get("address")
        if address == SELECTED_RETURN_SITE:
            selected_records.append(pointer_record(event_index, event, "eax"))
        elif address == STAMP_SITE:
            stamp_records.append(pointer_record(event_index, event, "eax"))
        elif address == INITIAL_CONSUMER_SITE:
            consumer_records.append(pointer_record(event_index, event, "eax"))
        elif address == PAYLOAD_ENTRY_SITE:
            payload_entry_records.append(pointer_record(event_index, event, "ecx"))
        elif address == PAYLOAD_RECORD_SITE:
            payload_record_records.append(pointer_record(event_index, event, "edx"))

    selected_vtables = Counter(record["vtable"] or "missing" for record in selected_records)
    stamp_vtables = Counter(record["vtable"] or "missing" for record in stamp_records)
    consumer_vtables = Counter(record["vtable"] or "missing" for record in consumer_records)
    payload_record_vtables = Counter(record["vtable"] or "missing" for record in payload_record_records)

    selected_projection_records = [
        record for record in selected_records if record["vtable"] in PROJECTION_OBJECT_VTABLES
    ]
    payload_projection_records = [
        record
        for record in payload_record_records
        if record["vtable"] in PROJECTION_OBJECT_VTABLES or record["vtable"] == PROJECTION_BASE_VTABLE
    ]

    return {
        "path": str(path),
        "event_count": int(ledger.get("event_count", len(events))),
        "address_counts": dict(sorted(address_counts.items())),
        "selected_return_count": len(selected_records),
        "selected_return_vtable_counts": dict(sorted(selected_vtables.items())),
        "selected_projection_return_count": len(selected_projection_records),
        "selected_projection_returns_prefix": selected_projection_records[:12],
        "stamp_count": len(stamp_records),
        "stamp_vtable_counts": dict(sorted(stamp_vtables.items())),
        "initial_consumer_count": len(consumer_records),
        "initial_consumer_vtable_counts": dict(sorted(consumer_vtables.items())),
        "payload_entry_count": len(payload_entry_records),
        "payload_entry_records": payload_entry_records,
        "payload_record_count": len(payload_record_records),
        "payload_record_vtable_counts": dict(sorted(payload_record_vtables.items())),
        "payload_projection_record_count": len(payload_projection_records),
        "payload_projection_records_prefix": payload_projection_records[:12],
        "payload_count_checkpoint_count": int(address_counts.get(PAYLOAD_COUNT_SITE, 0)),
    }


def payload_summary(path: Path) -> dict[str, Any]:
    payload = load_json(path)
    payload_vtables = set(payload.get("record_vtable_counts", {}).keys())
    projection_vtables = sorted(
        vtable
        for vtable in payload_vtables
        if vtable in PROJECTION_OBJECT_VTABLES or vtable == PROJECTION_BASE_VTABLE
    )
    return {
        "path": str(path),
        "status": payload.get("status"),
        "record_count": payload.get("record_count"),
        "record_vtable_counts": payload.get("record_vtable_counts"),
        "shifted_count_at_0x4a7d99": payload.get("shifted_count_at_0x4a7d99"),
        "projection_vtables_present": projection_vtables,
        "contains_only_ordinary_records": bool(payload_vtables)
        and payload_vtables <= ORDINARY_PAYLOAD_VTABLES,
    }


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    broad = summarize_ledger(args.broad_ledger)
    lite = summarize_ledger(args.lite_ledger)
    lite_payload = payload_summary(args.lite_payload)
    tight = summarize_ledger(args.tight_ledger) if args.tight_ledger.exists() else None
    tight_payload = payload_summary(args.tight_payload) if args.tight_payload.exists() else None

    payload_traces = [lite_payload]
    if tight_payload is not None:
        payload_traces.append(tight_payload)

    invariants = {
        "broad_trace_has_selected_projection_return": broad["selected_projection_return_count"] > 0,
        "broad_trace_reaches_4a79a3_entry": broad["payload_entry_count"] > 0,
        "broad_trace_lacks_payload_record_loop": broad["payload_record_count"] == 0
        and broad["payload_count_checkpoint_count"] == 0,
        "lite_trace_has_payload_record_loop": lite["payload_record_count"] > 0
        and lite["payload_count_checkpoint_count"] > 0,
        "lite_trace_lacks_selected_return_surface": lite["selected_return_count"] == 0,
        "lite_payload_summary_is_valid": lite_payload["status"]
        == "partial_live_recovery_4a79a3_object_record_payload",
        "lite_payload_contains_only_ordinary_records": lite_payload["contains_only_ordinary_records"],
        "lite_payload_contains_no_projection_records": not lite_payload["projection_vtables_present"],
        "tight_trace_if_present_has_payload_record_loop": tight is None
        or (tight["payload_record_count"] > 0 and tight["payload_count_checkpoint_count"] > 0),
        "tight_trace_if_present_lacks_selected_return_surface": tight is None
        or tight["selected_return_count"] == 0,
        "all_payload_summaries_contain_no_projection_records": all(
            not payload["projection_vtables_present"] for payload in payload_traces
        ),
    }

    link_proven = (
        broad["selected_projection_return_count"] > 0
        and broad["payload_record_count"] > 0
        and broad["payload_projection_record_count"] > 0
    )
    status = "same_run_link_proven" if link_proven else "same_run_link_not_proven_yet"

    return {
        "schema_id": "h3maped_same_run_projection_payload_link_summary_v1",
        "status": status,
        "native_behavior_changed": False,
        "inputs": {
            "broad_ledger": str(args.broad_ledger),
            "lite_ledger": str(args.lite_ledger),
            "lite_payload": str(args.lite_payload),
        },
        "broad_same_run_trace": broad,
        "lite_same_run_trace": lite,
        "lite_payload_summary": lite_payload,
        "tight_same_run_trace": tight,
        "tight_payload_summary": tight_payload,
        "invariants": invariants,
        "source_backed_conclusion": (
            "Current same-run evidence is still split. The broad trace proves selected-create "
            "returns include 0x540b14 projection objects and reaches 0x4a79a3 entry, but it "
            "does not reach the 0x4a7d36/0x4a7d99 payload loop. The payload traces prove the "
            "0x4a79a3 payload loop contains ordinary 0x540a88/0x540a9c records, but they have "
            "no selected-return surface. Therefore the projection-to-payload transformation, "
            "or separate selected-create surface proof, is not recovered yet."
        ),
        "remaining_recovery_target": (
            "Capture one pointer-paired run that includes a 0x540b14 selected return/stamp and "
            "the later 0x4a7d36/0x4a7d99 payload records, or recover static phase ordering that "
            "proves the projection selected-create surface and the 0x4a79a3 payload are separate "
            "surfaces for one-level land generation."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--broad-ledger", type=Path, default=DEFAULT_BROAD_LEDGER)
    parser.add_argument("--lite-ledger", type=Path, default=DEFAULT_LITE_LEDGER)
    parser.add_argument("--lite-payload", type=Path, default=DEFAULT_LITE_PAYLOAD)
    parser.add_argument("--tight-ledger", type=Path, default=DEFAULT_TIGHT_LEDGER)
    parser.add_argument("--tight-payload", type=Path, default=DEFAULT_TIGHT_PAYLOAD)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_SAME_RUN_PROJECTION_PAYLOAD_LINK_SUMMARY "
        f"status={summary['status']} out={args.out}"
    )
    return 0 if summary["status"] == "same_run_link_not_proven_yet" else 1


if __name__ == "__main__":
    raise SystemExit(main())
