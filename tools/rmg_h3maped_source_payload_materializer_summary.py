#!/usr/bin/env python3
"""Verify the source-payload materializer/accessor frontier for H3MapEd RMG.

This checkpoint is deliberately narrow: it proves the refcounted nested payload
access/materialization layer around the source-handler key lookup chain, while
leaving final source catalog and object-template identity as an explicit blocker.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_IDENTITY_SUMMARY = ROOT / "source_record_identity_frontier_summary_20260610.json"
DEFAULT_OUT = ROOT / "source_payload_materializer_summary_20260610.json"

PRIMARY_DUMP = ROOT / "ghidra_source_record_producer_candidate_dump_20260610"
TAIL_DUMP = ROOT / "ghidra_source_record_producer_candidate_tail_dump_20260610"

FILES = {
    "payload_accessor_0x42a73a": TAIL_DUMP / "target_0042a73a_FUN_0042a73a.txt",
    "payload_materializer_0x42a75a": PRIMARY_DUMP / "target_0042a75a_FUN_0042a75a.txt",
    "tagged_record_init_0x4370f4": TAIL_DUMP / "caller_004370f4_FUN_004370f4.txt",
    "tagged_record_destroy_0x42bfe6": TAIL_DUMP / "target_0042bfe6_FUN_0042bfe6.txt",
    "payload_release_0x42a600": TAIL_DUMP / "target_0042a600_FUN_0042a600.txt",
    "five_dword_slot_presence_0x42a48c": TAIL_DUMP / "target_0042a48c_FUN_0042a48c.txt",
    "six_axis_tile_lookup_0x42a4d0": PRIMARY_DUMP / "target_0042a4d0_FUN_0042a4d0.txt",
    "dword_vector_copy_0x42bde9": PRIMARY_DUMP / "target_0042bde9_FUN_0042bde9.txt",
    "materializer_reference_0x42a75a": PRIMARY_DUMP / "target_0042a75a_references.txt",
}

CHECKS: dict[str, list[dict[str, str]]] = {
    "payload_accessor_0x42a73a": [
        {
            "id": "reads_source_object_payload_holder",
            "marker": "0042a73d: MOV EAX,dword ptr [ESI + 0x10]",
            "meaning": "The accessor reads the source object payload holder at +0x10.",
        },
        {
            "id": "checks_payload_refcount",
            "marker": "0042a744: CMP dword ptr [EAX],0x1",
            "meaning": "The accessor treats dword +0x00 as a refcount/share count.",
        },
        {
            "id": "materializes_shared_payload",
            "marker": "0042a749: CALL 0x0042a75a",
            "meaning": "Shared payloads are materialized through 0x42a75a before returning.",
        },
        {
            "id": "returns_payload_pointer_0x08",
            "marker": "0042a752: MOV EAX,dword ptr [EAX + 0x8]",
            "meaning": "The accessor returns the nested payload pointer at holder +0x08.",
        },
    ],
    "payload_materializer_0x42a75a": [
        {
            "id": "reads_current_payload_holder",
            "marker": "0042a76d: MOV EAX,dword ptr [ESI + 0x10]",
            "meaning": "The materializer starts from the same source object +0x10 holder.",
        },
        {
            "id": "calls_payload_vtable_clone_slot",
            "marker": "0042a776: CALL dword ptr [EAX + 0x8]",
            "meaning": "The nested payload is cloned/materialized through virtual slot +0x08.",
        },
        {
            "id": "allocates_twelve_byte_tagged_record",
            "marker": "0042a7a5: PUSH 0xc",
            "meaning": "The replacement holder/tagged record allocation is 12 bytes.",
        },
        {
            "id": "uses_process_allocator",
            "marker": "0042a7a7: CALL 0x005044b1",
            "meaning": "The 12-byte replacement record is allocated through the process allocator.",
        },
        {
            "id": "initializes_tagged_record",
            "marker": "0042a7d0: CALL 0x004370f4",
            "meaning": "The replacement is initialized through the 0x4370f4 tagged-record helper.",
        },
        {
            "id": "decrements_old_holder_refcount",
            "marker": "0042a80a: DEC dword ptr [ECX]",
            "meaning": "The previous holder refcount is decremented after replacement.",
        },
        {
            "id": "stores_replacement_payload_holder",
            "marker": "0042a80f: MOV dword ptr [ESI + 0x10],EAX",
            "meaning": "The materialized holder is written back to source object +0x10.",
        },
        {
            "id": "destroys_temporary_holder",
            "marker": "0042a812: CALL 0x0042bfe6",
            "meaning": "Temporary holder state is cleaned through 0x42bfe6.",
        },
    ],
    "tagged_record_init_0x4370f4": [
        {
            "id": "reads_tag_byte_argument",
            "marker": "004370f4: MOV AL,byte ptr [ESP + 0x4]",
            "meaning": "The initializer consumes a one-byte tag/flag argument.",
        },
        {
            "id": "sets_refcount_one",
            "marker": "00437104: MOV dword ptr [ESI],0x1",
            "meaning": "The initialized record starts with refcount/count 1.",
        },
        {
            "id": "stores_tag_byte",
            "marker": "0043710a: MOV byte ptr [ESI + 0x4],AL",
            "meaning": "The tag/flag byte is stored at record +0x04.",
        },
        {
            "id": "stores_payload_pointer",
            "marker": "00437111: MOV dword ptr [ESI + 0x8],EAX",
            "meaning": "The payload pointer is stored at record +0x08.",
        },
        {
            "id": "destroys_stack_temp_holder",
            "marker": "00437114: CALL 0x0042bfe6",
            "meaning": "The temporary holder argument is destroyed after adoption.",
        },
    ],
    "tagged_record_destroy_0x42bfe6": [
        {
            "id": "checks_holder_flag_byte",
            "marker": "0042bfe6: CMP byte ptr [ECX],0x0",
            "meaning": "The destroy helper is gated by a holder flag byte.",
        },
        {
            "id": "loads_held_object_pointer",
            "marker": "0042bfeb: MOV ECX,dword ptr [ECX + 0x4]",
            "meaning": "When flagged, the held object pointer is at +0x04.",
        },
        {
            "id": "passes_destroy_true",
            "marker": "0042bff4: PUSH 0x1",
            "meaning": "The helper passes true to the held object's vtable destructor.",
        },
        {
            "id": "calls_held_object_destructor",
            "marker": "0042bff6: CALL dword ptr [EAX]",
            "meaning": "The held object is destroyed through vtable slot +0x00.",
        },
    ],
    "payload_release_0x42a600": [
        {
            "id": "reads_payload_holder",
            "marker": "0042a600: MOV EAX,dword ptr [ECX + 0x10]",
            "meaning": "The release helper reads the source object +0x10 holder.",
        },
        {
            "id": "decrements_refcount",
            "marker": "0042a608: DEC dword ptr [EAX]",
            "meaning": "The helper decrements the payload holder refcount.",
        },
        {
            "id": "destroys_when_zero",
            "marker": "0042a618: CALL 0x00436cd1",
            "meaning": "Zero-refcount holders are destroyed through 0x436cd1.",
        },
        {
            "id": "frees_when_zero",
            "marker": "0042a61e: CALL 0x005044da",
            "meaning": "Zero-refcount holders are freed after destruction.",
        },
    ],
    "five_dword_slot_presence_0x42a48c": [
        {
            "id": "enters_five_dword_slot_table",
            "marker": "0042a48c: MOV ECX,dword ptr [ECX + 0xc]",
            "meaning": "The helper enters the same table family used by key lookup.",
        },
        {
            "id": "divides_byte_span_by_twenty",
            "marker": "0042a49c: PUSH 0x14",
            "meaning": "The slot count is derived using a 20-byte/five-dword stride.",
        },
        {
            "id": "indexes_five_dword_slot",
            "marker": "0042a4ae: LEA EAX,[EDX + EDX*0x4]",
            "meaning": "The selected index is multiplied by five dwords.",
        },
        {
            "id": "loads_slot_payload_holder",
            "marker": "0042a4b4: MOV EAX,dword ptr [EAX + 0x10]",
            "meaning": "Slot +0x10 is the nested payload holder pointer.",
        },
        {
            "id": "loads_payload_pointer",
            "marker": "0042a4bb: MOV EAX,dword ptr [EAX + 0x8]",
            "meaning": "The nested payload pointer is at holder +0x08.",
        },
    ],
    "six_axis_tile_lookup_0x42a4d0": [
        {
            "id": "uses_six_cell_axis",
            "marker": "0042a4d7: PUSH 0x6",
            "meaning": "The helper splits coordinates into 6-cell chunk axes.",
        },
        {
            "id": "uses_grid_width",
            "marker": "0042a4ee: IMUL ESI,dword ptr [ECX]",
            "meaning": "Chunk addressing uses the grid width stored at the table base.",
        },
        {
            "id": "loads_chunk_pointer_table",
            "marker": "0042a4f3: MOV ECX,dword ptr [ECX + 0x8]",
            "meaning": "Chunk pointers are loaded from table +0x08.",
        },
        {
            "id": "selects_chunk_pointer",
            "marker": "0042a502: MOV ECX,dword ptr [ECX + ESI*0x4]",
            "meaning": "The helper selects a chunk pointer by computed chunk index.",
        },
        {
            "id": "returns_12_byte_tile_record",
            "marker": "0042a515: LEA EAX,[ECX + EAX*0x4 + 0x4]",
            "meaning": "The return is a per-tile record pointer inside the chunk.",
        },
    ],
    "dword_vector_copy_0x42bde9": [
        {
            "id": "reads_vector_end",
            "marker": "0042bdec: MOV EDX,dword ptr [ECX + 0x8]",
            "meaning": "The copy helper reads vector end/current limit at +0x08.",
        },
        {
            "id": "copies_dwords",
            "marker": "0042be00: MOV dword ptr [EAX],EDI",
            "meaning": "The helper copies dwords from the input span to the output span.",
        },
        {
            "id": "advances_destination",
            "marker": "0042be02: ADD EAX,0x4",
            "meaning": "The destination advances by one dword per iteration.",
        },
        {
            "id": "updates_vector_end",
            "marker": "0042be0d: MOV dword ptr [ECX + 0x8],EAX",
            "meaning": "The vector end/current pointer is updated after copy.",
        },
    ],
    "materializer_reference_0x42a75a": [
        {
            "id": "materializer_owned_by_accessor",
            "marker": "from=0042a749 type=UNCONDITIONAL_CALL caller=FUN_0042a73a",
            "meaning": "The focused dump shows 0x42a75a is reached from the 0x42a73a shared-payload branch.",
        },
    ],
}


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def summarize_file(key: str, path: Path) -> dict[str, Any]:
    text = read_text(path)
    checks = [{**check, "present": check["marker"] in text} for check in CHECKS[key]]
    return {
        "path": str(path),
        "exists": path.exists(),
        "check_count": len(checks),
        "present_check_count": sum(1 for check in checks if check["present"]),
        "checks": checks,
    }


def summarize(identity_summary_path: Path) -> dict[str, Any]:
    files = {key: summarize_file(key, path) for key, path in FILES.items()}
    all_checks = [check for result in files.values() for check in result["checks"]]
    missing = [check["id"] for check in all_checks if not check["present"]]

    identity_summary = read_json(identity_summary_path)
    identity_ready = (
        identity_summary.get("status")
        == "source_record_identity_frontier_recovered_producer_mapping_pending"
    )

    status = (
        "source_payload_materializer_recovered_catalog_mapping_pending"
        if not missing and identity_ready
        else "incomplete"
    )

    return {
        "schema_id": "h3maped_source_payload_materializer_summary_v1",
        "status": status,
        "scope": (
            "Ghidra/Python checkpoint for the refcounted source-payload "
            "access/materialization layer below source-handler key lookup. This does not "
            "recover final source catalog identity and does not authorize native RMG behavior changes."
        ),
        "inputs": {
            "identity_summary": str(identity_summary_path),
            "ghidra_files": {key: str(path) for key, path in FILES.items()},
        },
        "files": files,
        "identity_frontier_ready": identity_ready,
        "recovered": [
            "0x42a73a reads source object +0x10, materializes shared payloads through 0x42a75a, and returns holder +0x08.",
            "0x42a75a clones/materializes the nested payload through virtual slot +0x08, allocates a 12-byte holder, initializes it through 0x4370f4, decrements the old holder refcount, and stores the replacement at source object +0x10.",
            "0x4370f4 initializes a 12-byte tagged holder as refcount/count 1, byte tag at +0x04, payload pointer at +0x08, then destroys the temporary holder argument through 0x42bfe6.",
            "0x42bfe6 destroys flagged temporary holders by dispatching vtable slot +0x00 on the held object pointer at +0x04 with true.",
            "0x42a600 releases source object +0x10 holders by decrementing refcount and destroying/freeing through 0x436cd1/0x5044da when the count reaches zero.",
            "0x42a48c is another 20-byte/five-dword slot helper that reaches the same slot +0x10 -> holder +0x08 nested-payload shape.",
            "0x42a4d0 remains a 6-cell-axis chunked tile-record lookup helper, not a source catalog identity producer.",
            "0x42bde9 is a generic dword vector copy/end-pointer helper, not a source catalog identity producer.",
        ],
        "remaining_gap": (
            "Recover the producer and human mapping that populate these nested payloads from "
            "source-input records and connect them to objects.txt/objtmplt.txt type/subtype/DEF "
            "rows. This checkpoint proves payload holder lifecycle and accessor mechanics only."
        ),
        "metrics": {
            "marker_count": len(all_checks),
            "present_marker_count": sum(1 for check in all_checks if check["present"]),
            "missing_marker_count": len(missing),
            "identity_frontier_ready": identity_ready,
            "used_objdump": False,
            "native_behavior_changed": False,
            "overall_goal_complete": False,
        },
        "missing_markers": missing,
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--identity-summary", type=Path, default=DEFAULT_IDENTITY_SUMMARY)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args.identity_summary)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    metrics = summary["metrics"]
    print(
        "RMG_H3MAPED_SOURCE_PAYLOAD_MATERIALIZER "
        f"status={summary['status']} "
        f"markers={metrics['present_marker_count']}/{metrics['marker_count']} "
        f"out={args.out}"
    )
    return (
        0
        if summary["status"]
        == "source_payload_materializer_recovered_catalog_mapping_pending"
        else 1
    )


if __name__ == "__main__":
    raise SystemExit(main())
