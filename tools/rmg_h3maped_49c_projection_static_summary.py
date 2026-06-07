#!/usr/bin/env python3
"""Verify the H3MapEd 0x49c* projection-object static surface."""

from __future__ import annotations

import argparse
import json
import struct
import subprocess
from pathlib import Path
from typing import Any


DEFAULT_BINARY = Path(".artifacts/rmg_h3maped_controlled_reference/small_2p_land_gui_seed_11/runtime/h3maped.exe")
DEFAULT_DUMP_DIR = Path(".artifacts/rmg_recovery/ghidra_49c019_49c0a6_wrapper_callers_dump")
DEFAULT_DRIVER_DUMP_DIR = Path(".artifacts/rmg_recovery/ghidra_4ad947_4adb72_projection_driver_dump")
DEFAULT_CONSTRUCTOR_SUMMARY = Path(
    ".artifacts/rmg_recovery/direct_generation_49cac2_projection_constructor_hit_trace/49c_projection_constructor_summary.json"
)

IMAGE_RDATA_VMA = 0x52F000
IMAGE_RDATA_FILE_OFFSET = 0x12F000


VTABLE_WORDS = {
    "0x00540b00": ["0x0049bb76", "0x0040ed06", "0x0049c019", "0x0049baf8", "0x00557700"],
    "0x00540b14": ["0x0049c049", "0x0040ed06", "0x0049c0a6", "0x0049bd81", "0x00557750"],
    "0x00540b28": ["0x0049bb76", "0x0040ed06", "0x0049baf5", "0x0049c105", "0x005577a0"],
}


FILE_NEEDLES = {
    "target_0049c019_FUN_0049c019.txt": [
        "0049c01c: MOV EAX,dword ptr [ESI + 0x20]",
        "0049c01f: MOV ECX,dword ptr [ESI + 0x1c]",
        "0049c022: LEA EAX,[EAX + EAX*0x2]",
        "0049c02c: CALL 0x004adb72",
        "0049c039: PUSH dword ptr [ESI + 0x20]",
        "0049c040: CALL 0x004adef7",
    ],
    "target_0049c0a6_FUN_0049c0a6.txt": [
        "0049c0aa: MOV ECX,dword ptr [ESI + 0x1c]",
        "0049c0ad: CALL 0x004ad947",
        "0049c0b6: AND dword ptr [ESI + 0x20],0x0",
        "0049c0be: MOV ECX,dword ptr [ESI + 0x20]",
        "0049c0c9: CALL dword ptr [EAX]",
        "0049c0cb: AND dword ptr [ESI + 0x20],0x0",
    ],
    "target_0049c0d3_FUN_0049c0d3.txt": [
        "0049c0da: CALL 0x0049ba89",
        "0049c0df: OR dword ptr [ESI + 0x1c],0xffffffff",
        "0049c0e3: OR dword ptr [ESI + 0x2c],0xffffffff",
        "0049c0e9: MOV dword ptr [ESI],0x540b28",
        "0049c0ef: MOV dword ptr [ESI + 0x20],EAX",
        "0049c0f2: MOV dword ptr [ESI + 0x28],EAX",
        "0049c0f5: MOV dword ptr [ESI + 0x30],EAX",
        "0049c0f8: MOV dword ptr [ESI + 0x24],0x6",
    ],
    "caller_0049cac2_FUN_0049cac2.txt": [
        "0049caeb: CALL 0x0049c0d3",
        "0049cb01: CALL 0x004a9e40",
        "0049cb26: CALL 0x0049ba89",
        "0049cb2e: MOV dword ptr [ESI + 0x20],EDI",
        "0049cb31: MOV dword ptr [ESI + 0x1c],EAX",
        "0049cb34: MOV dword ptr [ESI + 0x24],EBX",
        "0049cb37: MOV dword ptr [ESI],0x540b14",
        "0049cb49: MOV dword ptr [EDI + 0x2c],EDX",
        "0049cb4c: MOV dword ptr [EDI + 0x30],ECX",
    ],
    "caller_0049cb83_FUN_0049cb83.txt": [
        "0049cbae: CALL 0x0049c0d3",
        "0049cbc6: CALL 0x004a9e40",
        "0049cbeb: CALL 0x0049ba89",
        "0049cbf3: MOV dword ptr [ESI + 0x1c],EBX",
        "0049cbf6: MOV dword ptr [ESI + 0x20],EDI",
        "0049cbf9: MOV dword ptr [ESI + 0x24],EAX",
        "0049cbfc: MOV dword ptr [ESI],0x540b14",
        "0049cc0f: MOV dword ptr [EDI + 0x20],EAX",
    ],
    "caller_0049cc22_FUN_0049cc22.txt": [
        "0049cc4b: CALL 0x0049c0d3",
        "0049cc61: CALL 0x004a9e40",
        "0049cc86: CALL 0x0049ba89",
        "0049cc8e: MOV dword ptr [ESI + 0x20],EDI",
        "0049cc91: MOV dword ptr [ESI + 0x1c],EAX",
        "0049cc94: MOV dword ptr [ESI + 0x24],EBX",
        "0049cc97: MOV dword ptr [ESI],0x540b14",
        "0049cca6: MOV dword ptr [EDI + 0x24],0x6",
        "0049ccad: MOV dword ptr [EDI + 0x28],ECX",
    ],
}


DRIVER_FILE_NEEDLES = {
    "caller_0049c019_FUN_0049c019.txt": ["0049c02c: CALL 0x004adb72", "0049c040: CALL 0x004adef7"],
    "caller_0049c0a6_FUN_0049c0a6.txt": ["0049c0ad: CALL 0x004ad947"],
}


def run_objdump(binary: Path, start: str, stop: str) -> str:
    completed = subprocess.run(
        ["objdump", "-Mintel", "-d", f"--start-address={start}", f"--stop-address={stop}", str(binary)],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return completed.stdout


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8") if path.exists() else ""


def contains_all(text: str, needles: list[str]) -> bool:
    return all(needle in text for needle in needles)


def normalize_word(value: int) -> str:
    return f"0x{value:08x}"


def vtable_file_offset(virtual_address: int) -> int:
    return IMAGE_RDATA_FILE_OFFSET + (virtual_address - IMAGE_RDATA_VMA)


def read_vtables(binary: Path) -> dict[str, list[str]]:
    data = binary.read_bytes()
    out: dict[str, list[str]] = {}
    for address, expected in VTABLE_WORDS.items():
        offset = vtable_file_offset(int(address, 16))
        size = len(expected) * 4
        words = struct.unpack("<" + "I" * len(expected), data[offset : offset + size])
        out[address] = [normalize_word(word) for word in words]
    return out


def file_checks(base: Path, checks: dict[str, list[str]]) -> dict[str, bool]:
    return {name: contains_all(read_text(base / name), needles) for name, needles in checks.items()}


def summarize(binary: Path, dump_dir: Path, driver_dump_dir: Path, constructor_summary_path: Path) -> dict[str, Any]:
    vtables = read_vtables(binary)
    static_file_checks = file_checks(dump_dir, FILE_NEEDLES)
    driver_file_checks = file_checks(driver_dump_dir, DRIVER_FILE_NEEDLES)

    constructor_summary: dict[str, Any] = {}
    if constructor_summary_path.exists():
        constructor_summary = json.loads(constructor_summary_path.read_text(encoding="utf-8"))

    method_objdump = {
        "0x0049c019": run_objdump(binary, "0x49c019", "0x49c049"),
        "0x0049c0a6": run_objdump(binary, "0x49c0a6", "0x49c0d3"),
    }

    return {
        "schema_id": "h3maped_49c_projection_static_summary_v1",
        "binary": str(binary),
        "ghidra_dump_dir": str(dump_dir),
        "driver_dump_dir": str(driver_dump_dir),
        "constructor_summary": str(constructor_summary_path),
        "vtable_words": vtables,
        "static_contract": {
            "vtable_0x540b00": {
                "slot_0x08": "0x0049c019",
                "method": "attempts reward/guard vector attachment through 0x4adb72, then fallback replacement through 0x4adef7",
            },
            "vtable_0x540b14": {
                "installed_by": ["0x0049cac2", "0x0049cb83", "0x0049cc22"],
                "slot_0x08": "0x0049c0a6",
                "method": "calls relation/projection wrapper 0x4ad947 and clears/destroys object+0x20 as needed",
            },
            "vtable_0x540b28": {
                "installed_by": ["0x0049c0d3 base initializer"],
                "slot_0x08": "0x0049baf5",
            },
            "projection_object_fields": {
                "+0x1c": "generator/context pointer for 0x49c019 and 0x49c0a6 downstream calls",
                "+0x20": "owned/copied object record pointer; also used as value source by 0x49c019 and cleared by 0x49c0a6",
                "+0x24": "source descriptor or payload pointer copied by constructors",
                "+0x28": "constructor-specific secondary scalar initialized by base/constructor C",
                "+0x2c/+0x30": "constructor A copies source +0x14/+0x18 into the base object record",
            },
        },
        "method_objdump": method_objdump,
        "constructor_trace_counts": {
            "event_count": constructor_summary.get("constructor_event_count"),
            "constructor_counts": constructor_summary.get("constructor_counts"),
            "paired_constructor_initializer_count": constructor_summary.get("paired_constructor_initializer_count"),
            "wrapper_execution_event_count": constructor_summary.get("wrapper_execution_event_count"),
        },
        "invariants": {
            "vtable_bytes_match_expected_layout": vtables == VTABLE_WORDS,
            "static_dump_files_match_expected_constructor_and_method_surface": all(static_file_checks.values()),
            "driver_dump_confirms_direct_downstream_calls": all(driver_file_checks.values()),
            "constructor_summary_passed_pairing": bool(
                constructor_summary.get("invariants", {}).get("constructors_pair_with_base_initializer")
                and constructor_summary.get("invariants", {}).get("initializer_returns_match_constructor_sites")
            ),
            "wrapper_nohit_summary_still_zero": constructor_summary.get("wrapper_execution_event_count") == 0,
        },
        "file_check_results": {
            "static": static_file_checks,
            "driver": driver_file_checks,
        },
        "notes": [
            "This is a static/lifecycle checkpoint, not ordered wrapper-method execution replay.",
            "0x49c019 is in the adjacent 0x540b00 table; 0x49c0a6 is slot +0x08 of constructor-installed vtable 0x540b14.",
            "The next runtime target should drive or identify a callind path that dispatches 0x540b00+0x08 or 0x540b14+0x08, not just direct breakpoints on 0x4adb72/0x4ad947.",
        ],
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--binary", type=Path, default=DEFAULT_BINARY)
    parser.add_argument("--dump-dir", type=Path, default=DEFAULT_DUMP_DIR)
    parser.add_argument("--driver-dump-dir", type=Path, default=DEFAULT_DRIVER_DUMP_DIR)
    parser.add_argument("--constructor-summary", type=Path, default=DEFAULT_CONSTRUCTOR_SUMMARY)
    parser.add_argument("--out", type=Path, required=True)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args.binary, args.dump_dir, args.driver_dump_dir, args.constructor_summary)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    status = "pass" if all(summary["invariants"].values()) else "partial"
    print(f"RMG_H3MAPED_49C_PROJECTION_STATIC_SUMMARY status={status} out={args.out}")
    return 0 if status == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
