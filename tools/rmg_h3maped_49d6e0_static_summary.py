#!/usr/bin/env python3
"""Verify the H3MapEd 0x49d6e0 reward/guard wrapper bounds refresh helper."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_GHIDRA_DUMP = Path(".artifacts/rmg_recovery/ghidra_downstream_helper_dump/target_0049d6e0_FUN_0049d6e0.txt")
DEFAULT_REFS_DUMP = Path(".artifacts/rmg_recovery/ghidra_downstream_helper_dump/target_0049d6e0_references.txt")
TARGET = "0x0049d6e0"


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
        "0049d6e8: MOV ESI,ECX",
        "0049d6ea: MOV EAX,0x7d00",
        "0049d6fa: MOV EAX,0xffff8300",
        "0049d720: CALL 0x0049a1d8",
        "0049d758: MOV dword ptr [ESI + 0x18],EAX",
        "0049d773: MOV dword ptr [ESI + 0x20],EAX",
        "0049d78b: MOV dword ptr [ESI + 0x1c],EAX",
        "0049d7a3: MOV dword ptr [ESI + 0x24],EAX",
    ]
    refs_needles = [
        "from=0049d2b2",
        "from=004aa345",
        "from=004adcca",
        "from=004adacb",
    ]

    return {
        "schema_id": "h3maped_49d6e0_static_summary_v1",
        "target": TARGET,
        "instruction_source": "ghidra_export",
        "ghidra_dump": str(ghidra_dump),
        "references_dump": str(refs_dump),
        "static_contract": {
            "wrapper_register": "ECX on entry; copied to ESI",
            "wrapper_fields": {
                "+0x08": "generated-cell buffer pointer",
                "+0x0c": "wrapper grid width",
                "+0x10": "wrapper grid height",
                "+0x18": "minimum x bound over blocking/control cells",
                "+0x1c": "minimum y bound over blocking/control cells",
                "+0x20": "exclusive maximum x bound over blocking/control cells",
                "+0x24": "exclusive maximum y bound over blocking/control cells",
            },
            "initial_bounds": {
                "+0x18": "0x7d00",
                "+0x1c": "0x7d00",
                "+0x20": "0xffff8300",
                "+0x24": "0xffff8300",
            },
            "scan_order": "y outer loop over wrapper+0x10, x inner loop over wrapper+0x0c, generated-cell stride 0x30 from wrapper+0x08",
            "included_cell_condition": "include cell in bounds when 0x49a1d8(cell) is false, or bit22 is set, or bit27 is clear",
            "excluded_cell_condition": "skip bounds update only when cell is valid, bit22 is clear, and bit27 is set",
            "bounds_semantics": "min x/y are inclusive; max x/y are exclusive and written as x+1/y+1",
        },
        "known_callers": {
            "0x0049cf34": "reward/guard attach pass refresh after selected-member stamping and candidate-vector cleanup",
            "0x004aa1db": "reward/guard wrapper object seeding refresh before return",
            "0x004adb72": "reward/guard vector attachment wrapper success refresh",
            "0x004ad947": "reward/guard relation/projection caller refresh",
        },
        "invariants": {
            "ghidra_dump_shows_same_bounds_contract": contains_all(ghidra_text, ghidra_needles),
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
    print(f"RMG_H3MAPED_49D6E0_STATIC_SUMMARY status={status} out={args.out}")
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
