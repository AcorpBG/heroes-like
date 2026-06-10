#!/usr/bin/env python3
"""Verify the H3MapEd 0x49d69d reward/guard member stamp helper."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_GHIDRA_DUMP = Path(".artifacts/rmg_recovery/ghidra_downstream_helper_dump/target_0049d69d_FUN_0049d69d.txt")
DEFAULT_CALLER_DUMP = Path(".artifacts/rmg_recovery/ghidra_downstream_helper_dump/caller_0049cf34_FUN_0049cf34.txt")
TARGET = "0x0049d69d"


def read_text_or_empty(path: Path) -> str:
    if not path.exists():
        return ""
    return path.read_text(encoding="utf-8")


def contains_all(text: str, needles: list[str]) -> bool:
    return all(needle in text for needle in needles)


def summarize(ghidra_dump: Path, caller_dump: Path) -> dict[str, Any]:
    ghidra_text = read_text_or_empty(ghidra_dump)
    caller_text = read_text_or_empty(caller_dump)

    ghidra_needles = [
        "0049d6ac: LEA ECX,[EBX + 0x28]",
        "0049d6af: CALL 0x0040bb26",
        "0049d6d4: CALL 0x0049abd6",
        "0049d6dd: RET 0xc",
    ]
    caller_ghidra_needles = [
        "0049d171: CALL 0x0049d69d",
    ]

    return {
        "schema_id": "h3maped_49d69d_static_summary_v1",
        "target": TARGET,
        "instruction_source": "ghidra_export",
        "ghidra_dump": str(ghidra_dump),
        "caller_dump": str(caller_dump),
        "static_contract": {
            "wrapper_register": "ECX on entry; copied to EBX",
            "stack_args": {
                "+0x08": "object/member record pointer appended to wrapper selected-member vector and passed to 0x49abd6",
                "+0x0c": "selected candidate x copied into the local 12-byte stamp coordinate",
                "+0x10": "selected candidate y copied into the local 12-byte stamp coordinate",
            },
            "mutations": [
                "calls 0x40bb26 with ECX=wrapper+0x28 and source=&arg1, appending the member pointer to the selected-member vector",
                "builds a local coordinate triple (arg2, arg3, 0)",
                "calls 0x49abd6 with ECX=wrapper, arg1=member pointer, and the local coordinate triple",
            ],
            "non_mutations": [
                "does not choose the coordinate; 0x49cf34 chooses it before this helper",
                "does not write wrapper+0x4c/+0x50/+0x48 finalization fields",
                "does not call RNG or perform candidate-vector filtering",
            ],
            "stack_cleanup": "ret 0x0c",
        },
        "caller_contract": {
            "caller": "0x0049cf34",
            "call_site": "0x0049d171",
            "argument_order": "push selected_y (ESI), push selected_x (EDI), push object/member record ([EBP+0x08]), call 0x49d69d",
        },
        "invariants": {
            "ghidra_dump_shows_same_target_calls": contains_all(ghidra_text, ghidra_needles),
            "caller_ghidra_dump_links_49cf34_to_49d69d": contains_all(caller_text, caller_ghidra_needles),
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
    parser.add_argument("--caller-dump", type=Path, default=DEFAULT_CALLER_DUMP)
    parser.add_argument("--out", type=Path, required=True)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args.ghidra_dump, args.caller_dump)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    status = "pass" if all(summary["invariants"].values()) else "partial"
    print(f"RMG_H3MAPED_49D69D_STATIC_SUMMARY status={status} out={args.out}")
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
