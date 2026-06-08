#!/usr/bin/env python3
"""Summarize whether sampled 49c projection objects survive into later vectors.

The 49c projection-object constructors produce records with vtables 0x540b00 or
0x540b14. Existing traces prove sampled 0x540b14 records return through
0x4a9f1c and are stamped, but no sampled trace hits their slot +0x08 methods.

This report cross-checks that evidence against the later 0x4a79a3 live
object-vector payload. It is a recovery checkpoint only; it does not change
native RMG behavior.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_CONSTRUCTOR_RETURN = Path(
    ".artifacts/rmg_recovery/direct_generation_49c_constructor_return_trace/"
    "49c_constructor_return_summary.json"
)
DEFAULT_CONSUMER_STAMP = Path(
    ".artifacts/rmg_recovery/direct_generation_49c_consumer_stamp_trace/"
    "49c_consumer_stamp_summary.json"
)
DEFAULT_POINTER_TRACE = Path(".artifacts/rmg_recovery/projection_pointer_trace_summary.json")
DEFAULT_ADD76_TRACE = Path(".artifacts/rmg_recovery/projection_4add76_trace_summary.json")
DEFAULT_4A79A3_PAYLOAD = Path(".artifacts/rmg_recovery/4a79a3_payload_trace_summary.json")
DEFAULT_4A79A3_FILTER_DISPATCH = Path(
    ".artifacts/rmg_recovery/4a79a3_filter_dispatch_summary.json"
)
DEFAULT_OUT = Path(
    ".artifacts/rmg_recovery/projection_object_survival_summary_20260608.json"
)

PROJECTION_OBJECT_VTABLES = {"0x00540b00", "0x00540b14"}
PROJECTION_BASE_VTABLES = {"0x00540b28"}


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def counter_dict(counter: Counter[Any]) -> dict[str, int]:
    return {str(key): counter[key] for key in sorted(counter, key=lambda item: str(item))}


def summarize_constructor_and_stamp(
    constructor_return: dict[str, Any],
    consumer_stamp: dict[str, Any],
    pointer_trace: dict[str, Any],
    add76_trace: dict[str, Any],
) -> dict[str, Any]:
    return {
        "surface": "49c projection-object selected-create and stamp",
        "constructor_return_status": {
            "projection_constructor_pre_returns_hit": constructor_return.get("invariants", {}).get(
                "projection_constructor_pre_returns_hit"
            ),
            "selected_return_matches_constructor_return_pointer": constructor_return.get(
                "invariants", {}
            ).get("selected_return_matches_constructor_return_pointer"),
            "sampled_projection_returns_are_0x540b14": constructor_return.get(
                "invariants", {}
            ).get("sampled_projection_returns_are_0x540b14"),
            "adjacent_0x540b00_constructor_hit": not constructor_return.get(
                "invariants", {}
            ).get("adjacent_0x540b00_constructor_not_hit_in_this_sample", False),
        },
        "stamp_status": {
            "sampled_projection_returns_enter_initial_consumer": consumer_stamp.get(
                "invariants", {}
            ).get("sampled_projection_returns_enter_initial_consumer"),
            "sampled_projection_returns_reach_stamp_helper": consumer_stamp.get(
                "invariants", {}
            ).get("sampled_projection_returns_reach_stamp_helper"),
            "sampled_projection_returns_do_not_enter_secondary_validator": consumer_stamp.get(
                "invariants", {}
            ).get("sampled_projection_returns_do_not_enter_secondary_validator"),
        },
        "ruled_out_runtime_surfaces": {
            "0x49ec51_optional_handler_is_not_49c_projection_method": pointer_trace.get(
                "invariants", {}
            ).get("cold_ec51_dispatch_is_not_49c_projection_method"),
            "bounded_trace_has_no_4add76_or_projection_driver_hits": add76_trace.get(
                "invariants", {}
            ).get("no_4add76_or_projection_driver_hits_in_bounded_sample"),
            "bounded_trace_has_storage_callbacks": add76_trace.get("invariants", {}).get(
                "storage_callbacks_hit"
            ),
        },
        "known_non_claim": (
            "The static vtable methods 0x540b00+0x08 -> 0x49c019 and "
            "0x540b14+0x08 -> 0x49c0a6 are real, but sampled generation traces have "
            "not hit those method dispatches."
        ),
    }


def summarize_4a79a3_payload(payload: dict[str, Any]) -> dict[str, Any]:
    records = payload.get("records", [])
    record_vtables = Counter(record.get("record_vtable") for record in records)
    descriptor_types = Counter()
    descriptor_ids = Counter()
    projection_records = []
    base_records = []
    for record in records:
        vtable = record.get("record_vtable")
        if vtable in PROJECTION_OBJECT_VTABLES:
            projection_records.append(record)
        if vtable in PROJECTION_BASE_VTABLES:
            base_records.append(record)
        descriptor_words = record.get("descriptor_words") or []
        if len(descriptor_words) > 7:
            descriptor_types[descriptor_words[7]] += 1
        if descriptor_words:
            descriptor_ids[descriptor_words[0]] += 1

    return {
        "surface": "0x4a79a3 live generator object-vector payload",
        "status": payload.get("status"),
        "record_count": payload.get("record_count"),
        "record_vtable_counts": payload.get("record_vtable_counts"),
        "observed_record_vtable_counts_recomputed": counter_dict(record_vtables),
        "descriptor_type_word_counts_from_sample": counter_dict(descriptor_types),
        "descriptor_source_pointer_counts": payload.get("descriptor_source_pointer_counts"),
        "projection_object_records_in_payload": len(projection_records),
        "projection_base_records_in_payload": len(base_records),
        "contains_0x540b00_or_0x540b14_records": bool(projection_records),
        "contains_0x540b28_base_records": bool(base_records),
        "vector_entries_match_record_pointers": payload.get("invariants", {}).get(
            "vector_entries_match_record_pointers"
        ),
        "record_count_matches_shifted_count": payload.get("invariants", {}).get(
            "record_count_matches_shifted_count"
        ),
        "interpretation": (
            "The sampled 0x4a79a3 +0xec8/+0xecc payload contains ordinary committed "
            "object records with vtables 0x540a88 and 0x540a9c. It does not contain "
            "the sampled 49c projection-object vtables 0x540b00/0x540b14 or their "
            "0x540b28 base records."
        ),
    }


def summarize_4a79a3_dispatch(filter_dispatch: dict[str, Any]) -> dict[str, Any]:
    dispatch = filter_dispatch.get("dispatch_summary", {})
    filter_summary = filter_dispatch.get("filter_summary", {})
    from_4a79a3_counts = dispatch.get("from_4a79a3_counts", {})
    source_types = Counter()
    for record in filter_summary.get("records", []):
        source_types[record.get("source_type_word_1c")] += 1
    return {
        "surface": "0x4a79a3 downstream dispatch",
        "status": filter_dispatch.get("status"),
        "filter_source_type_counts": counter_dict(source_types),
        "source_type_0x57_records_passed": sum(
            1 for record in filter_summary.get("records", []) if record.get("passes_source_type_0x57_gate")
        ),
        "from_4a79a3_counts": from_4a79a3_counts,
        "hit_0x4a696b_from_4a79a3": int(from_4a79a3_counts.get("0x004a696b", 0)) > 0,
        "hit_0x4a7605_from_4a79a3": int(from_4a79a3_counts.get("0x004a7605", 0)) > 0,
        "paired_record_mark_sites_hit": bool(
            filter_dispatch.get("invariants", {}).get("dispatch_trace_hit_pair_mark_sites")
        ),
        "remaining_gap": filter_dispatch.get("remaining_gap"),
    }


def build_summary(args: argparse.Namespace) -> dict[str, Any]:
    constructor_return = load_json(args.constructor_return)
    consumer_stamp = load_json(args.consumer_stamp)
    pointer_trace = load_json(args.pointer_trace)
    add76_trace = load_json(args.add76_trace)
    payload = load_json(args.payload_4a79a3)
    filter_dispatch = load_json(args.filter_dispatch_4a79a3)

    projection_stamp_surface = summarize_constructor_and_stamp(
        constructor_return, consumer_stamp, pointer_trace, add76_trace
    )
    payload_surface = summarize_4a79a3_payload(payload)
    dispatch_surface = summarize_4a79a3_dispatch(filter_dispatch)

    invariants = {
        "sampled_projection_objects_reach_stamp": bool(
            projection_stamp_surface["stamp_status"][
                "sampled_projection_returns_reach_stamp_helper"
            ]
        ),
        "sampled_4a79a3_payload_has_no_projection_object_vtables": not payload_surface[
            "contains_0x540b00_or_0x540b14_records"
        ],
        "sampled_4a79a3_payload_has_no_projection_base_vtable": not payload_surface[
            "contains_0x540b28_base_records"
        ],
        "sampled_4a79a3_payload_records_are_pointer_matched": bool(
            payload_surface["vector_entries_match_record_pointers"]
        ),
        "sampled_4a79a3_dispatch_reaches_live_connection_helpers": bool(
            dispatch_surface["hit_0x4a696b_from_4a79a3"]
            and dispatch_surface["hit_0x4a7605_from_4a79a3"]
        ),
        "0x49ec51_and_bounded_4add76_are_ruled_out_for_sample": bool(
            projection_stamp_surface["ruled_out_runtime_surfaces"][
                "0x49ec51_optional_handler_is_not_49c_projection_method"
            ]
            and projection_stamp_surface["ruled_out_runtime_surfaces"][
                "bounded_trace_has_no_4add76_or_projection_driver_hits"
            ]
        ),
    }

    return {
        "schema_id": "h3maped_projection_object_survival_summary_v1",
        "status": (
            "projection_objects_do_not_survive_into_sampled_4a79a3_vector"
            if all(invariants.values())
            else "incomplete_projection_survival_evidence"
        ),
        "native_behavior_changed": False,
        "inputs": {
            "constructor_return": str(args.constructor_return),
            "consumer_stamp": str(args.consumer_stamp),
            "pointer_trace": str(args.pointer_trace),
            "add76_trace": str(args.add76_trace),
            "payload_4a79a3": str(args.payload_4a79a3),
            "filter_dispatch_4a79a3": str(args.filter_dispatch_4a79a3),
        },
        "surfaces": {
            "projection_selected_create_and_stamp": projection_stamp_surface,
            "object_vector_payload_4a79a3": payload_surface,
            "downstream_dispatch_4a79a3": dispatch_surface,
        },
        "invariants": invariants,
        "source_backed_conclusion": (
            "In the sampled live traces, 49c projection objects are selected and stamped, "
            "but the later 0x4a79a3 generator object-vector payload does not contain "
            "0x540b00/0x540b14 projection objects or 0x540b28 bases. The live downstream "
            "state to recover for this sample is therefore the 0x4a79a3 dispatch into "
            "0x4a696b/0x4a7605 and their generated-cell mutations, not a guessed 49c "
            "projection-method dispatch."
        ),
        "remaining_blockers": [
            (
                "Recover 0x4a696b/0x4a7605 callee-side generated-cell mutations and "
                "record-pair semantics from the 0x4a79a3 dispatch sample."
            ),
            (
                "Keep 0x540b00/0x540b14 slot +0x08 methods as real but unhit static "
                "paths until a pointer-paired runtime trace reaches 0x49c019/0x49c0a6."
            ),
            (
                "Recover a generation path that actually hits 0x4add76 cleanup/uncommit "
                "before porting replacement/uncommit behavior."
            ),
        ],
        "explicit_non_claims": [
            "This report does not change native RMG behavior.",
            "This report does not prove 0x540b00/0x540b14 methods are unused globally.",
            "This report does not complete 0x4a79a3, 0x4a696b, or 0x4a7605 generated-cell mutation recovery.",
            "This report does not justify final-map density tuning.",
        ],
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--constructor-return", type=Path, default=DEFAULT_CONSTRUCTOR_RETURN)
    parser.add_argument("--consumer-stamp", type=Path, default=DEFAULT_CONSUMER_STAMP)
    parser.add_argument("--pointer-trace", type=Path, default=DEFAULT_POINTER_TRACE)
    parser.add_argument("--add76-trace", type=Path, default=DEFAULT_ADD76_TRACE)
    parser.add_argument("--payload-4a79a3", type=Path, default=DEFAULT_4A79A3_PAYLOAD)
    parser.add_argument("--filter-dispatch-4a79a3", type=Path, default=DEFAULT_4A79A3_FILTER_DISPATCH)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = build_summary(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    payload = summary["surfaces"]["object_vector_payload_4a79a3"]
    dispatch = summary["surfaces"]["downstream_dispatch_4a79a3"]
    print(
        "RMG_H3MAPED_PROJECTION_OBJECT_SURVIVAL_SUMMARY "
        f"status={summary['status']} "
        f"payload_records={payload['record_count']} "
        f"projection_payload_records={payload['projection_object_records_in_payload']} "
        f"dispatch_4a696b={dispatch['from_4a79a3_counts'].get('0x004a696b', 0)} "
        f"dispatch_4a7605={dispatch['from_4a79a3_counts'].get('0x004a7605', 0)} "
        f"out={args.out}"
    )
    return 0 if summary["status"].startswith("projection_objects_do_not_survive") else 1


if __name__ == "__main__":
    raise SystemExit(main())
