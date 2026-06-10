#!/usr/bin/env python3
"""Summarize the widened Ghidra endpoint cursor-state access scan."""

from __future__ import annotations

import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any


DEFAULT_SCAN = Path(".artifacts/rmg_recovery/cursor_endpoint_state_offset_access_scan_20260610.txt")
DEFAULT_PRIOR = Path(".artifacts/rmg_recovery/cursor_f5c_1104_access_summary_20260608.json")
DEFAULT_OUT = Path(".artifacts/rmg_recovery/endpoint_cursor_state_access_summary_20260610.json")

EXPECTED_OFFSETS = {
    "0xc8",
    "0xcc",
    "0xd8",
    "0xdc",
    "0xec4",
    "0xec8",
    "0xecc",
    "0xf58",
    "0xf5c",
    "0x10e4",
    "0x1104",
    "0x1108",
    "0x1110",
}
EXPECTED_F5C_WRITER_ENTRIES = {"004a5e73", "004adb72", "004add76"}
EXPECTED_F5C_WRITER_ADDRESSES = {
    "004a601c",
    "004a6050",
    "004adc63",
    "004adc97",
    "004add19",
    "004add4d",
    "004ade2c",
    "004ade60",
}
EXPECTED_F58_WRITER_ADDRESSES = {"0049ee6b"}
EXPECTED_1104_ENTRIES = {"0049f95a", "004a5e73", "004adb72", "004add76"}
EXPECTED_1108_ENTRIES = {"004a5e73", "004adb72", "004add76"}


def parse_scan(path: Path) -> tuple[set[str], list[dict[str, str]]]:
    offsets: set[str] = set()
    rows: list[dict[str, str]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith(("schema_id=", "program=")):
            continue
        if stripped.startswith("offsets="):
            offsets = {part.strip().lower() for part in stripped.split("=", 1)[1].split(",")}
            continue
        parts = stripped.split("\t")
        if len(parts) < 6:
            raise ValueError(f"unrecognized scan row: {line!r}")
        row = {"address": parts[0].lower()}
        for part in parts[1:]:
            key, value = part.split("=", 1)
            row[key] = value.lower() if key in {"offset", "entry", "access"} else value
        rows.append(row)
    return offsets, rows


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def rows_for(rows: list[dict[str, str]], offset: str) -> list[dict[str, str]]:
    return [row for row in rows if row["offset"] == offset]


def entries_for(rows: list[dict[str, str]], offset: str) -> list[str]:
    return sorted({row["entry"] for row in rows_for(rows, offset)})


def access_counts(rows: list[dict[str, str]]) -> dict[str, int]:
    counts = Counter(f"{row['offset']} {row['access']}" for row in rows)
    return dict(sorted(counts.items()))


def entry_counts(rows: list[dict[str, str]]) -> dict[str, int]:
    counts = Counter(row["entry"] for row in rows)
    return dict(sorted(counts.items()))


def offset_entry_matrix(rows: list[dict[str, str]]) -> dict[str, list[str]]:
    matrix: dict[str, set[str]] = defaultdict(set)
    for row in rows:
        matrix[row["offset"]].add(row["entry"])
    return {offset: sorted(entries) for offset, entries in sorted(matrix.items())}


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    offsets, rows = parse_scan(args.scan)
    prior = load_json(args.prior)
    f5c_rows = rows_for(rows, "0xf5c")
    f5c_writers = [
        row for row in f5c_rows if row["access"] in {"write", "read_write"}
    ]
    f58_writers = [
        row for row in rows_for(rows, "0xf58") if row["access"] in {"write", "read_write"}
    ]
    f5c_writer_entries = {row["entry"] for row in f5c_writers}
    f5c_writer_addresses = {row["address"] for row in f5c_writers}
    f58_writer_addresses = {row["address"] for row in f58_writers}

    invariants = {
        "no_native_behavior_change": True,
        "no_objdump_used": True,
        "scan_offsets_match_expected": offsets == EXPECTED_OFFSETS,
        "scan_has_rows": len(rows) > 0,
        "f5c_writer_entries_match_expected": f5c_writer_entries == EXPECTED_F5C_WRITER_ENTRIES,
        "f5c_writer_addresses_match_expected": f5c_writer_addresses
        == EXPECTED_F5C_WRITER_ADDRESSES,
        "f5c_no_unknown_or_unowned_writer": all(row["entry"] != "<none>" for row in f5c_writers),
        "f58_only_direct_write_is_setup_path": f58_writer_addresses
        == EXPECTED_F58_WRITER_ADDRESSES
        and all(row["entry"] == "0049ecf2" for row in f58_writers),
        "byte_state_entries_match_endpoint_helpers": set(entries_for(rows, "0x1104"))
        == EXPECTED_1104_ENTRIES
        and set(entries_for(rows, "0x1108")) == EXPECTED_1108_ENTRIES,
        "prior_narrow_scan_f5c_writers_match_widened_scan": set(
            prior.get("cursor_f5c_writer_entries", [])
        )
        == f5c_writer_entries,
        "prior_narrow_scan_already_marked_natural_cursor_unseeded": prior.get("status")
        == "cursor_writer_surface_exhausted_natural_bg_still_unseeded",
    }
    status = (
        "endpoint_cursor_state_access_surface_recovered_f5c_writers_bounded"
        if all(invariants.values())
        else "endpoint_cursor_state_access_surface_incomplete"
    )
    return {
        "schema_id": "h3maped_endpoint_cursor_state_access_summary_v1",
        "status": status,
        "scope": (
            "Ghidra headless offset-access recovery for endpoint cursor-adjacent generator "
            "state. This widens the old +0xf5c/+0x1104 scan to nearby endpoint vectors and "
            "counters without changing native RMG behavior."
        ),
        "inputs": {
            "scan": str(args.scan),
            "prior_cursor_f5c_1104_access_summary": str(args.prior),
        },
        "invariants": invariants,
        "metrics": {
            "native_behavior_changed": False,
            "used_objdump": False,
            "overall_goal_complete": False,
            "row_count": len(rows),
            "offset_count": len(offsets),
            "f5c_row_count": len(f5c_rows),
            "f5c_writer_row_count": len(f5c_writers),
            "f58_writer_row_count": len(f58_writers),
        },
        "access_counts": access_counts(rows),
        "entry_counts": entry_counts(rows),
        "offset_entry_matrix": offset_entry_matrix(rows),
        "f5c_rows": f5c_rows,
        "f5c_writer_rows": f5c_writers,
        "f58_rows": rows_for(rows, "0xf58"),
        "byte_state_rows": {
            "0x1104": rows_for(rows, "0x1104"),
            "0x1108": rows_for(rows, "0x1108"),
        },
        "source_backed_conclusion": (
            "The widened Ghidra scan still bounds direct generator+0xf5c writes to "
            "0x4a5e73, 0x4adb72, and 0x4add76. It also shows the only direct +0xf58 "
            "write in the scanned endpoint surface is setup path 0x49ecf2 at 0x49ee6b, "
            "while +0x1104/+0x1108 byte-state accesses are confined to 0x49f95a and "
            "the endpoint/projection cleanup helpers. This strengthens the cursor-source "
            "frontier: the missing successful endpoint state is not hidden in another direct "
            "+0xf5c writer in the current Ghidra instruction surface."
        ),
        "remaining_gap": (
            "Still recover a source path that seeds generator+0xf5c outside the currently "
            "bounded writer chain, a broader supported map/source state that naturally "
            "dispatches projection cleanup before selected-object recycle, or source-backed "
            "proof that successful endpoint stamping is irrelevant for supported one-level land."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scan", type=Path, default=DEFAULT_SCAN)
    parser.add_argument("--prior", type=Path, default=DEFAULT_PRIOR)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_ENDPOINT_CURSOR_STATE_ACCESS "
        f"status={summary['status']} rows={summary['metrics']['row_count']} "
        f"f5c_writers={summary['metrics']['f5c_writer_row_count']} out={args.out}"
    )
    return 0 if summary["status"].endswith("_recovered_f5c_writers_bounded") else 1


if __name__ == "__main__":
    raise SystemExit(main())
