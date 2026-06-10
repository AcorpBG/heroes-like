#!/usr/bin/env python3
"""Summarize the recovered H3MapEd RMG entry-to-writeout spine.

This checkpoint is deliberately narrow. It proves same-run ordering from the
random-map UI entry through the final map writeout boundary, and it records the
remaining payload replay gap instead of treating a boundary trace as full native
parity.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_BOUNDARY_LEDGER = (
    ROOT
    / "medium_seed10_entry_to_complete_writeout_boundaries_20260610"
    / "winedbg_interactive_trace_ledger.json"
)
DEFAULT_FIRST_TILE_LEDGER = (
    ROOT / "medium_seed10_entry_to_writeout_spine_20260610" / "winedbg_interactive_trace_ledger.json"
)
DEFAULT_GHIDRA_DIR = ROOT / "ghidra_writeout_spine_dump_20260610"
DEFAULT_OUT = ROOT / "ordered_writeout_spine_summary_20260610.json"

EXPECTED_BOUNDARY_SEQUENCE = [
    "0x004602c1",
    "0x004adfe1",
    "0x0049ecf2",
    "0x0049f0cd",
    "0x004ac552",
    "0x004ae082",
    "0x004ad1e3",
    "0x004ad251",
    "0x004ad309",
    "0x004ad333",
    "0x004ad375",
    "0x004ad3b7",
    "0x004ad3de",
    "0x004ae09a",
]

EXPECTED_FIRST_TILE_SEQUENCE = [
    "0x004602c1",
    "0x004adfe1",
    "0x0049ecf2",
    "0x0049f0cd",
    "0x004ac552",
    "0x004ad1e3",
    "0x0049b2b6",
]

def ghidra_check_specs(ghidra_dir: Path) -> dict[str, dict[str, Any]]:
    return {
        "adfe1_calls_ac552_then_ad1e3": {
            "file": ROOT
            / "ghidra_candidate_container_producer_49ecf2_dump_20260607"
            / "caller_004adfe1_FUN_004adfe1.txt",
            "markers": [
                "004ae07d: CALL 0x004ac552",
                "004ae095: CALL 0x004ad1e3",
            ],
        },
        "ad1e3_cell_write_loop": {
            "file": ghidra_dir / "target_004ad1e3_FUN_004ad1e3.txt",
            "markers": [
                "004ad1ef: MOV ESI,ECX",
                "004ad1f2: CALL 0x004ac857",
                "004ad22c: CALL 0x0049b2b6",
                "004ad231: ADD dword ptr [EBP + 0x8],0x30",
                "004ad239: JL 0x004ad228",
                "004ad244: JL 0x004ad221",
                "004ad24f: JL 0x004ad217",
            ],
        },
        "ad1e3_object_writeout": {
            "file": ghidra_dir / "target_004ad1e3_FUN_004ad1e3.txt",
            "markers": [
                "004ad309: MOV EAX,dword ptr [ESI + 0xec8]",
                "004ad318: MOV ECX,dword ptr [ESI + 0xecc]",
                "004ad330: CALL dword ptr [EAX + 0x8]",
                "004ad36f: CALL dword ptr [EAX + 0xc]",
                "004ad3b1: CALL dword ptr [EAX + 0xc]",
                "004ad3de: CMP EAX,0x4",
                "004ad3e4: SETZ AL",
            ],
        },
        "tile_writer_reads_generated_cell_words": {
            "file": ghidra_dir / "target_0049b2b6_FUN_0049b2b6.txt",
            "markers": [
                "0049b2bd: MOV ESI,dword ptr [EBP + 0x8]",
                "0049b2c8: MOV EAX,dword ptr [EDI + 0x24]",
                "0049b33d: MOV EAX,dword ptr [EDI + 0x28]",
                "0049b3ac: CALL dword ptr [EAX + 0x8]",
            ],
        },
        "object_list_writer_static_helper": {
            "file": ghidra_dir / "target_004ad3eb_FUN_004ad3eb.txt",
            "markers": [
                "004ad3eb: PUSH EBP",
                "004ad411: CALL dword ptr [EAX + 0x8]",
                "004ad42d: CALL dword ptr [EDX + 0x8]",
            ],
        },
    }


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def event_sequence(ledger: dict[str, Any]) -> list[str]:
    return [event.get("address", "") for event in ledger.get("events", [])]


def event_by_address(ledger: dict[str, Any], address: str) -> dict[str, Any] | None:
    for event in ledger.get("events", []):
        if event.get("address") == address:
            return event
    return None


def last_memory_words(event: dict[str, Any] | None) -> list[int]:
    if not event:
        return []
    lines = event.get("memory_lines", [])
    return [word for line in lines for word in line.get("words", [])]


def object_vector_count(event: dict[str, Any] | None) -> int | None:
    # Address-command dump at 0x4ad309/0x4ad333/0x4ad3b7 appends
    # `x/8x $esi+0xec8`; the final two memory lines are:
    # begin, end, capacity, ...
    if not event:
        return None
    lines = event.get("memory_lines", [])
    if len(lines) < 4:
        return None
    words = lines[-2].get("words", [])
    if len(words) < 2:
        return None
    begin, end = words[0], words[1]
    if end < begin:
        return None
    return (end - begin) // 4


def checks_for_ghidra(ghidra_dir: Path) -> dict[str, Any]:
    checks: dict[str, Any] = {}
    for name, spec in ghidra_check_specs(ghidra_dir).items():
        path = spec["file"]
        text = read_text(path) if path.exists() else ""
        marker_results = [{"marker": marker, "present": marker in text} for marker in spec["markers"]]
        checks[name] = {
            "file": str(path),
            "present": path.exists(),
            "marker_count": len(marker_results),
            "present_marker_count": sum(1 for item in marker_results if item["present"]),
            "all_markers_present": all(item["present"] for item in marker_results),
            "markers": marker_results,
        }
    return checks


def summarize(boundary_ledger: Path, first_tile_ledger: Path, ghidra_dir: Path) -> dict[str, Any]:
    boundary = load_json(boundary_ledger)
    first_tile = load_json(first_tile_ledger)
    boundary_sequence = event_sequence(boundary)
    first_tile_sequence = event_sequence(first_tile)
    ghidra_checks = checks_for_ghidra(ghidra_dir)

    ad1e3 = event_by_address(boundary, "0x004ad1e3")
    first_tile_writer = event_by_address(first_tile, "0x0049b2b6")
    ad251 = event_by_address(boundary, "0x004ad251")
    ad309 = event_by_address(boundary, "0x004ad309")
    ad333 = event_by_address(boundary, "0x004ad333")
    ad375 = event_by_address(boundary, "0x004ad375")
    ad3b7 = event_by_address(boundary, "0x004ad3b7")
    ad3de = event_by_address(boundary, "0x004ad3de")
    ae09a = event_by_address(boundary, "0x004ae09a")

    generator_at_ad1e3 = ad1e3.get("registers", {}).get("ecx") if ad1e3 else None
    generator_at_tile_writer = first_tile_writer.get("registers", {}).get("esi") if first_tile_writer else None
    object_count_at_count_write = object_vector_count(ad309)
    object_count_at_first_pass = ad375.get("registers", {}).get("edi") if ad375 else None
    object_count_at_second_pass = ad3b7.get("registers", {}).get("edi") if ad3b7 else None

    metrics = {
        "boundary_event_count": boundary.get("event_count"),
        "first_tile_event_count": first_tile.get("event_count"),
        "boundary_sequence_matches_expected": boundary_sequence == EXPECTED_BOUNDARY_SEQUENCE,
        "first_tile_sequence_matches_expected": first_tile_sequence == EXPECTED_FIRST_TILE_SEQUENCE,
        "ad1e3_generator_pointer": generator_at_ad1e3,
        "first_49b2b6_generator_pointer": generator_at_tile_writer,
        "first_49b2b6_returns_to": (first_tile_writer or {}).get("derived", {}).get("return_address"),
        "tile_loop_boundary_inner_index": (ad251 or {}).get("registers", {}).get("edi"),
        "generated_object_vector_count": object_count_at_count_write,
        "generated_object_first_pass_completed_index": object_count_at_first_pass,
        "generated_object_second_pass_completed_index": object_count_at_second_pass,
        "ad3de_eax_before_success_test": (ad3de or {}).get("registers", {}).get("eax"),
        "ad3de_edx_before_success_test": (ad3de or {}).get("registers", {}).get("edx"),
        "ae09a_eax_return_value": (ae09a or {}).get("registers", {}).get("eax"),
        "native_behavior_changed": False,
        "used_objdump": False,
        "ordered_writeout_boundary_replay_complete": False,
        "full_private_payload_replay_complete": False,
        "overall_goal_complete": False,
    }

    boundary_ok = (
        metrics["boundary_sequence_matches_expected"]
        and metrics["first_tile_sequence_matches_expected"]
        and generator_at_ad1e3 == generator_at_tile_writer
        and metrics["first_49b2b6_returns_to"] == "0x004ad231"
        and object_count_at_count_write == object_count_at_first_pass == object_count_at_second_pass
        and metrics["ad3de_eax_before_success_test"] == 4
        and metrics["ae09a_eax_return_value"] == 1
        and all(item["all_markers_present"] for item in ghidra_checks.values())
    )
    metrics["ordered_writeout_boundary_replay_complete"] = boundary_ok

    status = (
        "entry_to_final_writeout_boundary_replay_recovered_payload_replay_pending"
        if boundary_ok
        else "entry_to_final_writeout_boundary_replay_incomplete"
    )

    return {
        "schema_id": "h3maped_ordered_writeout_spine_summary_v1",
        "status": status,
        "scope": {
            "profile": "H3MapEd Medium one-level no-water seed 10, human/computer down 1, computer-only down 0",
            "positive_claim": "same-run ordered boundary spine from RMG entrypoint through 0x4ad1e3 final map writeout return",
            "negative_claim": "does not claim full per-cell byte payload parity or full per-object serialized payload replay",
        },
        "inputs": {
            "boundary_ledger": str(boundary_ledger),
            "first_tile_ledger": str(first_tile_ledger),
            "ghidra_dir": str(ghidra_dir),
        },
        "expected_boundary_sequence": EXPECTED_BOUNDARY_SEQUENCE,
        "actual_boundary_sequence": boundary_sequence,
        "expected_first_tile_sequence": EXPECTED_FIRST_TILE_SEQUENCE,
        "actual_first_tile_sequence": first_tile_sequence,
        "ghidra_checks": ghidra_checks,
        "metrics": metrics,
        "recovered_ordered_spine": [
            "0x4602c1 random-map UI entry calls 0x4adfe1",
            "0x4adfe1 builds candidate/source state through 0x49ecf2 -> 0x49f0cd",
            "0x4adfe1 calls 0x4ac552 and returns to 0x4ae082 with success",
            "0x4adfe1 then calls 0x4ad1e3 and returns to 0x4ae09a with EAX=1",
            "0x4ad1e3 copies ECX into ESI as the generator pointer and calls 0x4ac857",
            "0x4ad1e3 loops generated cells at stride 0x30 and calls 0x49b2b6; first 0x49b2b6 returns to 0x4ad231",
            "0x4ad1e3 reaches 0x4ad251 after the cell-write loop",
            "0x4ad1e3 reads generator+0xec8/+0xecc at 0x4ad309/0x4ad318 and writes generated object count",
            "0x4ad1e3 serializes static object lists through 0x4ad3eb",
            "0x4ad1e3 serializes generated objects in two passes split by the 0x57c648[type*16+0x0c] flag",
            "0x4ad1e3 reaches 0x4ad3de with EAX=4 and returns success to 0x4ae09a",
        ],
        "remaining_gap": (
            "The ordered writeout boundary is recovered for this clean seed-pinned Medium profile, but the full "
            "private-state replay is still not complete: the checkpoint does not dump every 0x49b2b6 tile byte, "
            "does not compare the final serialized object payloads field-by-field, and does not recover the broader "
            "unreplayed mutation semantics still listed in docs/h3maped-rmg-private-state-recovery.md."
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--boundary-ledger", type=Path, default=DEFAULT_BOUNDARY_LEDGER)
    parser.add_argument("--first-tile-ledger", type=Path, default=DEFAULT_FIRST_TILE_LEDGER)
    parser.add_argument("--ghidra-dir", type=Path, default=DEFAULT_GHIDRA_DIR)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    summary = summarize(args.boundary_ledger, args.first_tile_ledger, args.ghidra_dir)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_ORDERED_WRITEOUT_SPINE "
        f"status={summary['status']} "
        f"boundary_complete={summary['metrics']['ordered_writeout_boundary_replay_complete']} "
        f"object_count={summary['metrics']['generated_object_vector_count']} "
        f"out={args.out}"
    )
    return 0 if summary["metrics"]["ordered_writeout_boundary_replay_complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
