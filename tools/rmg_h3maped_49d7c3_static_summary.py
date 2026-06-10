#!/usr/bin/env python3
"""Verify the H3MapEd 0x49d7c3 reward/guard candidate-vector rebuild helper."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_GHIDRA_DUMP = Path(".artifacts/rmg_recovery/ghidra_downstream_helper_dump/target_0049d7c3_FUN_0049d7c3.txt")
DEFAULT_REFS_DUMP = Path(".artifacts/rmg_recovery/ghidra_downstream_helper_dump/target_0049d7c3_references.txt")
TARGET = "0x0049d7c3"


def read_text_or_empty(path: Path) -> str:
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8")


def contains_all(text: str, needles: list[str]) -> bool:
    return all(needle in text for needle in needles)


def summarize(ghidra_dump: Path, refs_dump: Path) -> dict[str, Any]:
    ghidra_text = read_text_or_empty(ghidra_dump)
    refs_text = read_text_or_empty(refs_dump)

    ghidra_needles = [
        "0049d7ce: MOV EAX,dword ptr [EBX + 0x3c]",
        "0049d7df: JNZ 0x0049d90f",
        "0049d818: CALL 0x0049a1d8",
        "0049d852: DEC dword ptr [EBP + -0x8]",
        "0049d868: CALL 0x0040bb15",
        "0049d87a: MOV EAX,dword ptr [ESI*0x8 + 0x5a2658]",
        "0049d8bd: CALL 0x0049a1d8",
        "0049d909: JNZ 0x0049d861",
    ]
    refs_needles = [
        "from=004aa3d4",
        "from=0049cf3f",
        "from=0049d2b9",
        "from=004adcd2",
        "from=004adad6",
    ]

    return {
        "schema_id": "h3maped_49d7c3_static_summary_v1",
        "target": TARGET,
        "instruction_source": "ghidra_export",
        "ghidra_dump": str(ghidra_dump),
        "references_dump": str(refs_dump),
        "static_contract": {
            "wrapper_register": "ECX on entry; copied to EBX",
            "candidate_vector": "wrapper+0x38 anchor with begin/end read through +0x3c/+0x40",
            "non_empty_behavior": "returns without rebuilding when the candidate-coordinate vector already has nonzero 8-byte entries",
            "seed_scan": {
                "order": "y outer, x inner over wrapper +0x10 height and +0x0c width",
                "advance_condition": "advance while the cell is bit22-clear, 0x49a1d8-valid, and bit27-set",
                "boundary_condition": "stop at the first cell that is bit22-set, invalid, or bit27-clear",
                "failure": "returns without appending if no boundary cell is found",
                "initial_contour_coordinate": "stores boundary x and boundary y-1 before the first vector append",
            },
            "contour_walk": {
                "append": "calls 0x40bb15 with ECX=wrapper+0x38 and source=&local_x to append an 8-byte coordinate",
                "direction_table": "uses 8-byte direction records at 0x5a2658/0x5a265c",
                "neighbor_probe_limit": "tries up to four direction probes before stepping",
                "probe_passable_condition": "a probed neighbor is passable when bit22-clear, 0x49a1d8-valid, and bit27-set",
                "loop_end": "continues until the contour coordinate returns to the initial x/y pair",
            },
        },
        "known_callers": {
            "0x004aa354": "reward/guard wrapper setup",
            "0x0049cf34": "reward/guard attach prepass and post-stamp refresh",
            "0x004adb72": "reward/guard vector attachment wrapper",
            "0x004ad947": "reward/guard relation/projection wrapper",
        },
        "invariants": {
            "ghidra_dump_shows_same_static_contract": contains_all(ghidra_text, ghidra_needles),
            "references_show_expected_callers": contains_all(refs_text, refs_needles),
            "no_objdump_used": True,
        },
        "metrics": {
            "used_objdump": False,
            "native_behavior_changed": False,
            "overall_goal_complete": False,
        },
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path, help="Deprecated; ignored. Use --ghidra-dump.")
    parser.add_argument("--ghidra-dump", type=Path, default=DEFAULT_GHIDRA_DUMP)
    parser.add_argument("--refs-dump", type=Path, default=DEFAULT_REFS_DUMP)
    parser.add_argument("--out", type=Path, required=True)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args.ghidra_dump, args.refs_dump)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    status = "pass" if all(summary["invariants"].values()) else "partial"
    print(f"RMG_H3MAPED_49D7C3_STATIC_SUMMARY status={status} out={args.out}")
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
