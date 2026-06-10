#!/usr/bin/env python3
"""Summarize H3MapEd final header/player/metadata writeout surfaces.

This is a recovery checkpoint. It records the source-backed writer surfaces
around the final map writeout without changing native RMG behavior.
"""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_GHIDRA_DIR = ROOT / "ghidra_final_header_metadata_helpers_20260610"
DEFAULT_OUT = ROOT / "final_header_metadata_static_summary_20260610.json"

CALL_RE = re.compile(r"^(?P<addr>[0-9a-f]{8}): CALL dword ptr \[(?P<reg>[A-Z]+) \+ 0x8\]$", re.MULTILINE)
PUSH_CONST_RE = re.compile(r"^(?P<addr>[0-9a-f]{8}): PUSH 0x(?P<value>[0-9a-f]+)$", re.MULTILINE)
TARGET_FILE_RE = re.compile(r"target_(?P<entry>[0-9a-f]{8})_FUN_[0-9a-f]+\.txt$")

EXCLUDED_RAW_WRITE_SITES = {
    "0x004ad3ca": "optional_ed4_object_method_single_0x7d0_argument_not_stream_buffer_length_write",
}

FUNCTION_ROLES = {
    "0x004ac857": "map_header_player_metadata_top_level_serializer",
    "0x004ad140": "metadata_distribution_helper_no_direct_stream_write",
    "0x004ad1e3": "final_tile_object_writeout_spine",
    "0x004ad3eb": "object_definition_metadata_serializer",
    "0x004aed50": "metadata_bitset_helper_no_direct_stream_write",
    "0x004aed89": "metadata_bitset_helper_serializer",
    "0x004aedf9": "metadata_bitset_helper_no_direct_stream_write",
    "0x004aee32": "metadata_bitset_helper_serializer",
    "0x004aeea1": "metadata_bitset_helper_serializer",
    "0x004aef12": "metadata_bitset_helper_no_direct_stream_write",
    "0x004aef5e": "metadata_bitset_helper_serializer",
    "0x004aefce": "metadata_bitset_helper_serializer",
    "0x004af037": "metadata_bitset_helper_serializer",
}

SOURCE_FILES = {
    "0x004ac857": "target_004ac857_FUN_004ac857.txt",
    "0x004ad140": "target_004ad140_FUN_004ad140.txt",
    "0x004ad1e3": "target_004ad1e3_FUN_004ad1e3.txt",
    "0x004ad3eb": "target_004ad3eb_FUN_004ad3eb.txt",
    "0x004aed50": "target_004aed50_FUN_004aed50.txt",
    "0x004aed89": "target_004aed89_FUN_004aed89.txt",
    "0x004aedf9": "target_004aedf9_FUN_004aedf9.txt",
    "0x004aee32": "target_004aee32_FUN_004aee32.txt",
    "0x004aeea1": "target_004aeea1_FUN_004aeea1.txt",
    "0x004aef12": "target_004aef12_FUN_004aef12.txt",
    "0x004aef5e": "target_004aef5e_FUN_004aef5e.txt",
    "0x004aefce": "target_004aefce_FUN_004aefce.txt",
    "0x004af037": "target_004af037_FUN_004af037.txt",
}


def normalize_addr(value: str | int) -> str:
    if isinstance(value, int):
        return f"0x{value:08x}"
    return f"0x{int(value, 16):08x}"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""


def target_files(ghidra_dir: Path) -> list[Path]:
    return sorted(path for path in ghidra_dir.glob("target_*_FUN_*.txt") if TARGET_FILE_RE.search(path.name))


def preceding_push_constants(text: str, call_addr: str) -> list[dict[str, Any]]:
    call_line = f"{call_addr[2:]}: CALL"
    call_index = text.find(call_line)
    if call_index < 0:
        return []
    window = text[max(0, call_index - 1800) : call_index]
    pushes = []
    for match in PUSH_CONST_RE.finditer(window):
        pushes.append(
            {
                "address": normalize_addr(match.group("addr")),
                "value": int(match.group("value"), 16),
                "value_hex": f"0x{int(match.group('value'), 16):x}",
            }
        )
    return pushes[-3:]


def summarize(ghidra_dir: Path) -> dict[str, Any]:
    raw_sites: list[dict[str, Any]] = []
    excluded_sites: list[dict[str, Any]] = []
    missing_files: list[str] = []

    for entry, file_name in SOURCE_FILES.items():
        path = ghidra_dir / file_name
        if not path.exists():
            missing_files.append(str(path))
            continue
        text = read_text(path)
        for match in CALL_RE.finditer(text):
            address = normalize_addr(match.group("addr"))
            site = {
                "address": address,
                "function_entry": entry,
                "function_role": FUNCTION_ROLES.get(entry, "unknown_final_writeout_helper"),
                "file": str(path),
                "call_register": match.group("reg").lower(),
                "preceding_push_constants": preceding_push_constants(text, address),
                "raw_stream_buffer_length_shape": address not in EXCLUDED_RAW_WRITE_SITES,
            }
            if address in EXCLUDED_RAW_WRITE_SITES:
                site["exclusion_reason"] = EXCLUDED_RAW_WRITE_SITES[address]
                excluded_sites.append(site)
            else:
                raw_sites.append(site)

    by_function = Counter(site["function_entry"] for site in raw_sites)
    raw_breakpoints = [site["address"] for site in raw_sites]
    excluded_breakpoints = [site["address"] for site in excluded_sites]
    all_expected_files_present = not missing_files
    raw_sites_present = len(raw_sites) > 0

    return {
        "schema_id": "h3maped_final_header_metadata_static_summary_v1",
        "status": (
            "final_header_player_metadata_static_contract_recovered"
            if all_expected_files_present and raw_sites_present
            else "final_header_player_metadata_static_contract_incomplete"
        ),
        "scope": {
            "profile": "H3MapEd final writeout serializers around 0x4ac857, 0x4ad1e3, and 0x4ad3eb",
            "positive_claim": "Ghidra-backed list of raw stream write call sites for header/player/static metadata replay",
            "negative_claim": "does not claim native RMG behavior parity and excludes non-stream optional object method calls",
        },
        "inputs": {
            "ghidra_dir": str(ghidra_dir),
        },
        "metrics": {
            "source_function_count": len(SOURCE_FILES),
            "source_files_present": len(SOURCE_FILES) - len(missing_files),
            "raw_stream_write_site_count": len(raw_sites),
            "excluded_non_raw_call_site_count": len(excluded_sites),
            "required_trace_breakpoint_count": len(raw_breakpoints),
            "native_behavior_changed": False,
            "used_objdump": False,
            "header_player_metadata_payload_replay_complete": False,
            "full_private_payload_replay_complete": False,
            "overall_goal_complete": False,
        },
        "raw_stream_write_sites_by_function": dict(sorted(by_function.items())),
        "raw_stream_write_sites": raw_sites,
        "excluded_non_raw_call_sites": excluded_sites,
        "required_trace_breakpoints": raw_breakpoints,
        "excluded_trace_breakpoints": excluded_breakpoints,
        "missing_files": missing_files,
        "remaining_gap": (
            "Static write sites are source-backed. Dynamic same-run byte replay is required before claiming "
            "header/player/metadata payload recovery."
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ghidra-dir", type=Path, default=DEFAULT_GHIDRA_DIR)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    summary = summarize(args.ghidra_dir)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_FINAL_HEADER_METADATA_STATIC "
        f"status={summary['status']} "
        f"raw_sites={summary['metrics']['raw_stream_write_site_count']} "
        f"excluded={summary['metrics']['excluded_non_raw_call_site_count']} "
        f"out={args.out}"
    )
    return 0 if summary["status"].endswith("_recovered") else 1


if __name__ == "__main__":
    raise SystemExit(main())
