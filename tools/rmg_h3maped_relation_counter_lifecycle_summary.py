#!/usr/bin/env python3
"""Summarize H3MapEd descriptor-type counter lifecycle recovery.

This is recovery evidence only. It checks focused Ghidra instruction dumps for
the source-backed counter lifecycle around object projection:

* ``0x49ecf2`` initializes the live generator counter table and seeds static
  per-type limit tables.
* ``0x4a54a7`` increments the generator and relation-local counters when an
  object is committed.
* ``0x4a9f1c`` rejects candidate object types once either counter reaches its
  limit table entry.
* ``0x4add76`` decrements the same counters when an object record is uncommitted.

The script intentionally does not claim runtime ordered replay for the cleanup
or selector paths. Native RMG behavior must not be changed from this report
alone.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_OUT = Path(".artifacts/rmg_recovery/relation_counter_lifecycle_summary_20260608.json")
DEFAULT_INIT_DUMP = Path(".artifacts/rmg_recovery/ghidra_4af463_source_handler_init_dump/caller_0049ecf2_FUN_0049ecf2.txt")
DEFAULT_COMMIT_DUMP = Path(".artifacts/rmg_recovery/ghidra_4a54a7_relation_vslot4_dump/target_004a54a7_FUN_004a54a7.txt")
DEFAULT_SELECTOR_DUMP = Path(
    ".artifacts/rmg_recovery/ghidra_4a9f1c_reward_guard_object_selector_dump/target_004a9f1c_FUN_004a9f1c.txt"
)
DEFAULT_CLEANUP_DUMP = Path(".artifacts/rmg_recovery/ghidra_4ad947_4adb72_projection_driver_dump/target_004add76_FUN_004add76.txt")


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""


def has_all(text: str, needles: list[str]) -> bool:
    return all(needle in text for needle in needles)


def evidence(path: Path, checks: dict[str, list[str]]) -> dict[str, Any]:
    text = read_text(path)
    return {
        "path": str(path),
        "exists": path.exists(),
        "checks": {
            name: {
                "passed": has_all(text, needles),
                "needles": needles,
            }
            for name, needles in checks.items()
        },
    }


def summarize(init_dump: Path, commit_dump: Path, selector_dump: Path, cleanup_dump: Path) -> dict[str, Any]:
    init = evidence(
        init_dump,
        {
            "zeros_generator_type_counter_table": [
                "0049ee88: PUSH 0x3a0",
                "0049ee8d: LEA EAX,[ESI + 0x1110]",
                "0049ee95: CALL 0x004e71c0",
            ],
            "fills_relation_local_limit_table_0x5a2a8c": [
                "0049eee8: MOV EDI,0x5a2a8c",
                "0049eeed: STOSD.REP ES:EDI",
                "0049ef24: MOV dword ptr [ECX*0x4 + 0x5a2a8c],EDX",
            ],
            "fills_global_limit_table_0x5a26e4": [
                "0049eef4: MOV EDI,0x5a26e4",
                "0049eef9: STOSD.REP ES:EDI",
                "0049ef06: MOV dword ptr [ECX*0x4 + 0x5a26e4],EDX",
            ],
        },
    )
    commit = evidence(
        commit_dump,
        {
            "increments_generator_type_counter": [
                "004a54f7: MOV EDI,dword ptr [EAX + 0x1c]",
                "004a54fa: INC dword ptr [ESI + EDI*0x4 + 0x1110]",
            ],
            "increments_relation_local_counter": [
                "004a557f: MOV EDX,dword ptr [ECX + EDI*0x4 + 0x44]",
                "004a5583: LEA ECX,[ECX + EDI*0x4 + 0x44]",
                "004a5587: INC EDX",
                "004a5588: MOV dword ptr [ECX],EDX",
            ],
        },
    )
    selector = evidence(
        selector_dump,
        {
            "checks_global_counter_against_global_limit": [
                "004a9fd5: MOV EDX,dword ptr [EBX + ESI*0x4 + 0x1110]",
                "004a9fe1: CMP EDX,dword ptr [EAX + 0x5a26e4]",
                "004a9fe7: JGE 0x004aa0ef",
            ],
            "checks_relation_local_counter_against_relation_limit": [
                "004a9fed: MOV EDX,dword ptr [EDI + ESI*0x4 + 0x44]",
                "004a9ff1: CMP EDX,dword ptr [EAX + 0x5a2a8c]",
                "004a9ff7: JGE 0x004aa0ef",
            ],
        },
    )
    cleanup = evidence(
        cleanup_dump,
        {
            "decrements_generator_type_counter": [
                "004addc1: MOV ECX,dword ptr [EAX + 0x1c]",
                "004addc4: DEC dword ptr [EBX + ECX*0x4 + 0x1110]",
            ],
            "recomputes_descriptor_offset_source_cell": [
                "004addcb: MOV EDX,dword ptr [EAX + 0x2c]",
                "004addce: MOV ESI,dword ptr [EAX + 0x30]",
                "004addf9: MOV EAX,dword ptr [EAX + EDX*0x1 + 0x20]",
            ],
            "decrements_relation_local_counter": [
                "004ade05: MOV EDX,dword ptr [EBX + 0x10e4]",
                "004ade0b: MOV EAX,dword ptr [EDX + EAX*0x4]",
                "004ade0e: DEC dword ptr [EAX + ECX*0x4 + 0x44]",
            ],
        },
    )
    surfaces = {
        "init_0x0049ecf2": init,
        "commit_0x004a54a7": commit,
        "selector_0x004a9f1c": selector,
        "cleanup_0x004add76": cleanup,
    }
    missing = [
        f"{surface}.{check}"
        for surface, data in surfaces.items()
        for check, result in data["checks"].items()
        if not result["passed"]
    ]
    return {
        "status": "passed_static_recovery" if not missing else "failed_missing_static_needles",
        "native_behavior_changed": False,
        "scope": "static source-backed descriptor-type counter lifecycle evidence",
        "surfaces": surfaces,
        "recovered_contract": [
            "0x49ecf2 clears generator+0x1110 over 0x3a0 bytes and seeds two descriptor-type limit tables.",
            "0x4a54a7 increments generator+0x1110[descriptor+0x1c] and relation+0x44[descriptor+0x1c] on projection-enabled commits.",
            "0x4a9f1c rejects candidate descriptor types when generator usage reaches 0x5a26e4[type] or relation-local usage reaches 0x5a2a8c[type].",
            "0x4add76 decrements the same generator and relation-local counters while uncommitting an object record.",
        ],
        "explicit_non_claims": [
            "This report is not same-run ordered replay of 0x4a9f1c or 0x4add76.",
            "This report does not recover descriptor type names or candidate vtable contracts.",
            "This report does not justify native RMG density scalars, new gates, retries, or final-map delta tuning.",
        ],
        "remaining_blockers": [
            "Run or recover ordered replay for 0x4a9f1c candidate acceptance/rejection against live counter values.",
            "Run or recover ordered replay for 0x4add76 cleanup in a generation path that actually hits it.",
            "Name descriptor type indices and candidate vtable contracts from source-backed data before native parity changes.",
        ],
        "missing_checks": missing,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--init-dump", type=Path, default=DEFAULT_INIT_DUMP)
    parser.add_argument("--commit-dump", type=Path, default=DEFAULT_COMMIT_DUMP)
    parser.add_argument("--selector-dump", type=Path, default=DEFAULT_SELECTOR_DUMP)
    parser.add_argument("--cleanup-dump", type=Path, default=DEFAULT_CLEANUP_DUMP)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    summary = summarize(args.init_dump, args.commit_dump, args.selector_dump, args.cleanup_dump)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_RELATION_COUNTER_LIFECYCLE_SUMMARY status={summary['status']} out={args.out}")
    if summary["missing_checks"]:
        for missing in summary["missing_checks"]:
            print(f"missing={missing}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
