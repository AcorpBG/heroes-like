#!/usr/bin/env python3
"""Classify H3MapEd projection-object consumer surfaces.

This is a recovery aid, not a native RMG validator. It separates slot +0x08
surfaces that are already ruled out from the remaining candidate paths for
0x540b00/0x540b14 projection objects after constructor adoption and 0x49abd6
stamping.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


DEFAULT_PRIVATE_DUMP = Path(".artifacts/rmg_recovery/ghidra_private_state_dump")
DEFAULT_OBJECT_PROJECTION_DUMP = Path(".artifacts/rmg_recovery/ghidra_object_projection_helper_dump")
DEFAULT_CONSUMER_STAMP_SUMMARY = Path(
    ".artifacts/rmg_recovery/direct_generation_49c_consumer_stamp_trace/49c_consumer_stamp_summary.json"
)
DEFAULT_SLOT8_SUMMARY = Path(
    ".artifacts/rmg_recovery/direct_generation_4aa3e9_slot8_broad_trace/4aa3e9_slot8_summary.json"
)
DEFAULT_WRITER_SUMMARY = Path(
    ".artifacts/rmg_recovery/direct_generation_49cac2_projection_constructor_hit_trace/49c_writer_surface_summary.json"
)
DEFAULT_POINTER_TRACE_SUMMARY = Path(".artifacts/rmg_recovery/projection_pointer_trace_summary.json")


CALL_SLOT8_RE = re.compile(r"^(?P<address>[0-9a-f]{8}): CALL dword ptr \[(?P<register>[A-Z]+) \+ 0x8\]$", re.MULTILINE)


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8") if path.exists() else ""


def read_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"exists": False, "path": str(path)}
    return {"exists": True, "path": str(path), "data": json.loads(path.read_text(encoding="utf-8"))}


def has_all(text: str, needles: list[str]) -> bool:
    return all(needle in text for needle in needles)


def slot8_calls(text: str) -> list[dict[str, str]]:
    return [
        {"site": f"0x{int(match.group('address'), 16):08x}", "base_register": match.group("register")}
        for match in CALL_SLOT8_RE.finditer(text)
    ]


def classify_4a54a7(private_dump: Path) -> dict[str, Any]:
    path = private_dump / "caller_004a54a7_FUN_004a54a7.txt"
    text = read_text(path)
    needles = [
        "004a54d1: CALL 0x0049abd6",
        "004a54dd: MOV EAX,dword ptr [ESI + 0xecc]",
        "004a54e3: LEA ECX,[ESI + 0xec4]",
        "004a54ea: CALL 0x0042d8d8",
        "004a54fa: INC dword ptr [ESI + EDI*0x4 + 0x1110]",
        "004a5599: CALL 0x004ae20e",
        "004a55ac: CALL 0x0042d8d8",
    ]
    return {
        "entry": "0x004a54a7",
        "dump": str(path),
        "exists": path.exists(),
        "classification": "projection_stamp_and_generator_queue_candidate",
        "static_needles_present": has_all(text, needles),
        "evidence": {
            "direct_stamp_call": "004a54d1: CALL 0x0049abd6" in text,
            "queues_object_through_generator_ec4_ecc_vector": has_all(
                text,
                [
                    "004a54dd: MOV EAX,dword ptr [ESI + 0xecc]",
                    "004a54e3: LEA ECX,[ESI + 0xec4]",
                    "004a54ea: CALL 0x0042d8d8",
                ],
            ),
            "updates_generator_type_counter": "004a54fa: INC dword ptr [ESI + EDI*0x4 + 0x1110]" in text,
            "builds_direction_worklist": "004a5599: CALL 0x004ae20e" in text,
            "second_vector_append_surface": "004a55ac: CALL 0x0042d8d8" in text,
        },
        "recovered_contract": [
            "Called as the generator/context slot +0x04 callback from 0x4aa3e9 for selected-member records.",
            "Stamps the selected object through 0x49abd6 using the incoming coordinate triple.",
            "Appends/queues projection-related records through the generator +0xec4/+0xecc vector surface.",
            "Continues into a direction/worklist update path that mutates generated-cell +0x20 low word values.",
        ],
        "remaining_gap": (
            "The queued record shape and its later owning consumer have not yet been replayed end-to-end "
            "against the same object pointer produced by 0x49cac2/0x49cb83."
        ),
    }


def classify_49eb8d(private_dump: Path) -> dict[str, Any]:
    path = private_dump / "caller_0049eb8d_FUN_0049eb8d.txt"
    text = read_text(path)
    needles = [
        "0049eba0: MOV ESI,dword ptr [EBX + 0x20]",
        "0049eba3: MOV ECX,dword ptr [EBX + 0x14]",
        "0049ec39: CALL 0x0049a1d8",
        "0049ec42: MOV ECX,dword ptr [EBX + 0xed4]",
        "0049ec4c: MOV EAX,dword ptr [ECX]",
        "0049ec51: CALL dword ptr [EAX + 0x8]",
        "0049ec66: CALL 0x0049e700",
        "0049ecc9: CALL 0x0049a932",
    ]
    return {
        "entry": "0x0049eb8d",
        "dump": str(path),
        "exists": path.exists(),
        "classification": "generated_cell_cleanup_dispatch_candidate",
        "slot8_calls": slot8_calls(text),
        "static_needles_present": has_all(text, needles),
        "evidence": {
            "scans_generator_grid": has_all(
                text,
                [
                    "0049eba0: MOV ESI,dword ptr [EBX + 0x20]",
                    "0049eba3: MOV ECX,dword ptr [EBX + 0x14]",
                ],
            ),
            "counts_bit26_cells_before_budget": "0049ec01: MOV EAX,0x4374c" in text,
            "validity_gate_before_dispatch": "0049ec39: CALL 0x0049a1d8" in text,
            "dispatches_generator_ed4_object_slot8_when_invalid": has_all(
                text,
                [
                    "0049ec42: MOV ECX,dword ptr [EBX + 0xed4]",
                    "0049ec4c: MOV EAX,dword ptr [ECX]",
                    "0049ec51: CALL dword ptr [EAX + 0x8]",
                ],
            ),
            "alternate_selected_coordinate_worklist_path": "0049ec66: CALL 0x0049e700" in text,
            "later_occupancy_write": "0049ecc9: CALL 0x0049a932" in text,
        },
        "recovered_contract": [
            "Scans generated cells from generator +0x14/+0x18/+0x1c/+0x20.",
            "Counts bit26 cells and derives a placement/work budget from constant 0x4374c.",
            "At 0x49ec51, dispatches slot +0x08 on the object/vector pointer in generator+0xed4 when the current generated cell fails 0x49a1d8 and the pointer differs from the active vector pointer.",
            "Otherwise builds a coordinate triple and calls 0x49e700 on the normal path.",
        ],
        "remaining_gap": (
            "This static optional handler surface is not enough to identify the missing 49c projection-object "
            "method dispatch. Runtime traces must pointer-pair ECX/[ECX] and slot +0x08 targets before "
            "attributing this site to sampled 0x540b14/0x540b00 projection objects."
        ),
    }


def classify_ruled_out_surfaces(
    private_dump: Path,
    object_projection_dump: Path,
    slot8_summary: Path,
    writer_summary: Path,
) -> dict[str, Any]:
    aa3e9 = read_json(slot8_summary)
    writer = read_json(writer_summary)
    selector_path = object_projection_dump / "caller_004a9f1c_FUN_004a9f1c.txt"
    selector_text = read_text(selector_path)
    private_aa3e9_path = private_dump / "target_004aa3e9_FUN_004aa3e9.txt"
    private_aa3e9_text = read_text(private_aa3e9_path)
    return {
        "0x004aa3e9_final_wrapper_slot8": {
            "classification": "ruled_out_for_projection_object_dispatch_in_sample",
            "summary": aa3e9,
            "static_slot8_sites": slot8_calls(private_aa3e9_text),
            "reason": (
                "Focused broad trace captured final selected-member slot +0x08 callbacks as 0x49baf5 and "
                "recorded no 0x540b00/0x540b14 vtables or 0x49c019/0x49c0a6 hits."
            ),
        },
        "0x0049be93_0x0049c273_writer_helpers": {
            "classification": "ruled_out_for_sampled_generation_runtime",
            "summary": writer,
            "reason": (
                "Static shape is writer/serializer-like and sampled constructor trace instrumented both "
                "helpers with zero runtime hits."
            ),
        },
        "0x004a9f1c_candidate_selector_slot8": {
            "classification": "not_returned_projection_object_dispatch",
            "dump": str(selector_path),
            "exists": selector_path.exists(),
            "static_needles_present": has_all(
                selector_text,
                [
                    "004a9fc7: CALL dword ptr [EAX + 0x8]",
                    "004aa001: CALL dword ptr [EAX + 0x4]",
                    "004aa151: CALL dword ptr [EAX + 0x4]",
                    "004aa166: CALL dword ptr [EAX]",
                ],
            ),
            "reason": (
                "This slot +0x08 belongs to candidate descriptor vtables before selected-object creation, "
                "while the missing dispatch is on returned projection objects with vtables 0x540b00/0x540b14."
            ),
        },
    }


def summarize(
    private_dump: Path,
    object_projection_dump: Path,
    consumer_stamp_summary: Path,
    slot8_summary: Path,
    writer_summary: Path,
    pointer_trace_summary: Path,
) -> dict[str, Any]:
    consumer = read_json(consumer_stamp_summary)
    pointer_trace = read_json(pointer_trace_summary)
    ec51_ruled_out = (
        pointer_trace.get("data", {}).get("status") == "partial_recovery_ec51_ruled_out_for_sample"
        and pointer_trace.get("data", {}).get("invariants", {}).get("cold_ec51_dispatch_is_not_49c_projection_method")
    )
    surfaces = {
        "candidate_storage_0x004a54a7": classify_4a54a7(private_dump),
        "candidate_dispatch_0x0049eb8d": classify_49eb8d(private_dump),
    }
    if ec51_ruled_out:
        surfaces["candidate_dispatch_0x0049eb8d"]["classification"] = (
            "ruled_out_for_projection_object_dispatch_in_sample"
        )
        surfaces["candidate_dispatch_0x0049eb8d"]["remaining_gap"] = (
            "Cold runtime trace hit 0x49ec51, but ECX/[ECX] resolved to handler vtable 0x00539660 "
            "and slot +0x08 target 0x0045e1a6, not 0x49c019/0x49c0a6. Treat 0x49ec51 as ruled out "
            "for sampled 49c projection-method dispatch unless a future pointer-paired trace proves otherwise."
        )
    ruled_out = classify_ruled_out_surfaces(private_dump, object_projection_dump, slot8_summary, writer_summary)
    invariants = {
        "consumer_stamp_summary_exists": consumer.get("exists", False),
        "pointer_trace_summary_exists": pointer_trace.get("exists", False),
        "sampled_0x540b14_objects_reach_49abd6": bool(
            consumer.get("data", {}).get("invariants", {}).get("sampled_projection_returns_are_0x540b14")
            and consumer.get("data", {}).get("invariants", {}).get("sampled_projection_returns_reach_stamp_helper")
        ),
        "0x4a54a7_static_storage_shape_recovered": bool(
            surfaces["candidate_storage_0x004a54a7"]["exists"]
            and surfaces["candidate_storage_0x004a54a7"]["static_needles_present"]
        ),
        "0x49eb8d_static_dispatch_shape_recovered": bool(
            surfaces["candidate_dispatch_0x0049eb8d"]["exists"]
            and surfaces["candidate_dispatch_0x0049eb8d"]["static_needles_present"]
            and surfaces["candidate_dispatch_0x0049eb8d"]["slot8_calls"] == [
                {"site": "0x0049ec51", "base_register": "EAX"}
            ]
        ),
        "ruled_out_surface_summaries_present": bool(
            ruled_out["0x004aa3e9_final_wrapper_slot8"]["summary"].get("exists")
            and ruled_out["0x0049be93_0x0049c273_writer_helpers"]["summary"].get("exists")
            and ruled_out["0x004a9f1c_candidate_selector_slot8"]["exists"]
        ),
        "0x49ec51_ruled_out_for_sampled_projection_dispatch": bool(ec51_ruled_out),
    }
    status = "partial_recovery_ec51_ruled_out_for_sample" if all(invariants.values()) else "incomplete_evidence"
    return {
        "schema_id": "h3maped_projection_consumer_surface_summary_v1",
        "consumer_stamp_summary": consumer,
        "pointer_trace_summary": pointer_trace,
        "candidate_surfaces": surfaces,
        "ruled_out_surfaces": ruled_out,
        "invariants": invariants,
        "status": status,
        "remaining_blocker": {
            "name": "projection_object_0x540b14_later_method_dispatch_consumer",
            "description": (
                "The chain is recovered through constructor return, selected-object adoption, and 0x49abd6 "
                "stamp. Static Ghidra and pointer traces recover 0x4a54a7 as a generator storage/queue "
                "surface while ruling out sampled 0x49eb8d/0x49ec51 optional dispatch as the 49c projection "
                "method path. What remains unrecovered is the later consumer, if any, that dispatches "
                "0x540b14+0x08/0x540b00+0x08 into 0x49c0a6/0x49c019."
            ),
            "required_next_trace": [
                "Break on 0x49cac2/0x49cb83 constructor returns and record object pointer/vtable.",
                "Break on 0x4aa168/0x4aa22b/0x49abd6 and pair the same object pointer through stamping.",
                "Break on 0x4a54d1/0x4a54ea and capture generator+0xec4/+0xecc queue writes for the same pointer.",
                "Search/trace downstream consumers of generator +0xec4/+0xecc queued records and object-record vectors; do not assume 0x49ec51 is the projection-object dispatch without new pointer proof.",
            ],
        },
        "notes": [
            "This checkpoint deliberately does not mutate native RMG behavior.",
            "The normal 0x4aa3e9 final-wrapper slot +0x08 path is not the sampled projection-object dispatch.",
            "The writer helpers are not the sampled direct-generation runtime consumer.",
            "0x49eb8d/0x49ec51 is a recovered static optional handler surface, but sampled runtime rules it out as the 49c projection-object dispatch without new pointer-paired evidence.",
        ],
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--private-dump", type=Path, default=DEFAULT_PRIVATE_DUMP)
    parser.add_argument("--object-projection-dump", type=Path, default=DEFAULT_OBJECT_PROJECTION_DUMP)
    parser.add_argument("--consumer-stamp-summary", type=Path, default=DEFAULT_CONSUMER_STAMP_SUMMARY)
    parser.add_argument("--slot8-summary", type=Path, default=DEFAULT_SLOT8_SUMMARY)
    parser.add_argument("--writer-summary", type=Path, default=DEFAULT_WRITER_SUMMARY)
    parser.add_argument("--pointer-trace-summary", type=Path, default=DEFAULT_POINTER_TRACE_SUMMARY)
    parser.add_argument("--out", type=Path, required=True)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(
        args.private_dump,
        args.object_projection_dump,
        args.consumer_stamp_summary,
        args.slot8_summary,
        args.writer_summary,
        args.pointer_trace_summary,
    )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    status = summary["status"]
    print(
        "RMG_H3MAPED_PROJECTION_CONSUMER_SURFACE_SUMMARY "
        f"status={status} remaining={summary['remaining_blocker']['name']} out={args.out}"
    )
    return 0 if status == "partial_recovery_ec51_ruled_out_for_sample" else 1


if __name__ == "__main__":
    raise SystemExit(main())
