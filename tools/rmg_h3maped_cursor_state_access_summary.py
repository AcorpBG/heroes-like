#!/usr/bin/env python3
"""Summarize H3MapEd generator cursor-state offset access recovery.

This consumes the Ghidra offset-access scan for generator ``+0xf5c`` and
``+0x1104`` and cross-checks it against the focused natural Border Guard replay
where the first ``0x4a5e73`` attempt still sees an unseeded cursor.

The report is recovery evidence only. It must not be used as a native RMG
behavior change or as a final-map tuning surface.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_SCAN = Path(
    ".artifacts/rmg_recovery/cursor_f5c_1104_offset_access_scan_20260608.txt"
)
DEFAULT_DOWNSTREAM_SUMMARY = Path(
    ".artifacts/rmg_recovery/medium_seed10_natural_border_guard_downstream_replay_20260608/"
    "natural_border_guard_downstream_summary.json"
)
DEFAULT_WRITER_PROBE_LEDGER = Path(
    ".artifacts/rmg_recovery/medium_seed10_cursor_writer_before_5e73_probe_20260608/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_CALLBACK_PROBE_LEDGER = Path(
    ".artifacts/rmg_recovery/medium_seed10_cursor_callback_before_5e73_probe_20260608/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_OUT = Path(
    ".artifacts/rmg_recovery/cursor_f5c_1104_access_summary_20260608.json"
)

KNOWN_CURSOR_WRITER_ENTRIES = {"004a5e73", "004adb72", "004add76"}
KNOWN_DIRECT_1104_ENTRY = "0049f95a"
READ_ONLY_CALLBACK_ADDRESS = "0049cd9b"


def parse_scan_line(line: str) -> dict[str, str] | None:
    stripped = line.strip()
    if not stripped or stripped.startswith("schema_id=") or stripped.startswith("program="):
        return None
    if stripped.startswith("offsets="):
        return None

    parts = stripped.split("\t")
    if len(parts) < 5:
        raise ValueError(f"unrecognized scan row: {line!r}")

    row: dict[str, str] = {"address": parts[0].lower()}
    for part in parts[1:]:
        if "=" not in part:
            continue
        key, value = part.split("=", 1)
        row[key] = value
    if not {"offset", "access", "function", "entry", "instruction"} <= set(row):
        raise ValueError(f"incomplete scan row: {line!r}")
    row["entry"] = row["entry"].lower()
    return row


def parse_scan(path: Path) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        row = parse_scan_line(line)
        if row is not None:
            rows.append(row)
    return rows


def access_counter(rows: list[dict[str, str]]) -> dict[str, int]:
    counts = Counter(f"{row['offset']} {row['access']}" for row in rows)
    return dict(sorted(counts.items()))


def function_counter(rows: list[dict[str, str]]) -> dict[str, int]:
    counts = Counter(
        f"{row['entry']} {row['function']}" if row["entry"] != "<none>" else "<none>"
        for row in rows
    )
    return dict(sorted(counts.items()))


def writer_rows(rows: list[dict[str, str]]) -> list[dict[str, str]]:
    return [
        row
        for row in rows
        if row["offset"] == "0xf5c" and row["access"] in {"write", "read_write"}
    ]


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def probe_addresses(path: Path) -> list[str]:
    if not path.exists():
        return []
    probe = load_json(path)
    return [str(event.get("address", "")).lower() for event in probe.get("events", [])]


def summarize(
    scan_path: Path,
    downstream_path: Path,
    writer_probe_path: Path,
    callback_probe_path: Path,
) -> dict[str, Any]:
    rows = parse_scan(scan_path)
    writers = writer_rows(rows)
    writer_entries = sorted({row["entry"] for row in writers})
    non_writer_f5c_entries = sorted(
        {
            row["entry"]
            for row in rows
            if row["offset"] == "0xf5c" and row["access"] == "read"
        }
    )
    direct_1104_entries = sorted(
        {row["entry"] for row in rows if row["offset"] == "0x1104"}
    )
    callback_rows = [row for row in rows if row["address"] == READ_ONLY_CALLBACK_ADDRESS]

    downstream = load_json(downstream_path)
    writer_probe_addresses = probe_addresses(writer_probe_path)
    callback_probe_addresses = probe_addresses(callback_probe_path)

    downstream_invariants = downstream.get("invariants", {})
    known_writers_only = set(writer_entries) == KNOWN_CURSOR_WRITER_ENTRIES
    writer_probe_stopped_at_first_5e73_only = writer_probe_addresses == ["0x004a5e73"]
    callback_probe_stopped_at_first_5e73_only = callback_probe_addresses == [
        "0x004a5e73"
    ]
    downstream_unseeded = (
        downstream.get("status")
        == "natural_border_guard_branch_reaches_5e73_but_cursor_unseeded"
        and downstream_invariants.get("natural_border_guard_branch_observed") is True
        and downstream_invariants.get("all_4a5e73_entries_failed_at_4a5f84") is True
        and downstream_invariants.get("generated_cell_mutation_not_reached") is True
        and downstream_invariants.get("cursor_unseeded_value_observed") is True
    )
    direct_1104_has_initializer = KNOWN_DIRECT_1104_ENTRY in direct_1104_entries
    callback_is_read_only = len(callback_rows) == 1 and callback_rows[0]["access"] == "read"

    status = "cursor_writer_surface_exhausted_natural_bg_still_unseeded"
    if not (
        known_writers_only
        and writer_probe_stopped_at_first_5e73_only
        and callback_probe_stopped_at_first_5e73_only
        and downstream_unseeded
        and direct_1104_has_initializer
        and callback_is_read_only
    ):
        status = "cursor_writer_surface_evidence_incomplete"

    return {
        "schema_id": "h3maped_cursor_f5c_1104_access_summary_v1",
        "status": status,
        "source_scan": str(scan_path),
        "source_downstream_summary": str(downstream_path),
        "source_writer_probe_ledger": str(writer_probe_path),
        "source_callback_probe_ledger": str(callback_probe_path),
        "row_count": len(rows),
        "access_counts": access_counter(rows),
        "function_counts": function_counter(rows),
        "cursor_f5c_writer_rows": writers,
        "cursor_f5c_writer_entries": writer_entries,
        "cursor_f5c_read_only_entries": non_writer_f5c_entries,
        "direct_1104_offset_entries": direct_1104_entries,
        "read_only_callback": {
            "address": READ_ONLY_CALLBACK_ADDRESS,
            "observed": bool(callback_rows),
            "rows": callback_rows,
            "interpretation": (
                "tiny unlabeled read-only helper/callback adjacent to the 49c candidate "
                "vtable family; it compares generator+0xf5c to another record value and "
                "does not seed or advance the cursor"
            ),
        },
        "natural_seed10_cross_check": {
            "downstream_status": downstream.get("status"),
            "event_count": downstream.get("event_count"),
            "branch_checks_with_border_guard": downstream.get(
                "branch_checks_with_border_guard"
            ),
            "entries_4a5e73": len(downstream.get("entries_4a5e73", [])),
            "failures_4a5f84": len(downstream.get("failures_4a5f84", [])),
            "generated_cell_mutation_hits": downstream.get(
                "generated_cell_mutation_hits", {}
            ),
            "writer_probe_addresses_before_first_5e73": writer_probe_addresses,
            "callback_probe_addresses_before_first_5e73": callback_probe_addresses,
        },
        "invariants": {
            "native_behavior_changed": False,
            "known_cursor_writers_only": known_writers_only,
            "cursor_writer_entries_match_expected": writer_entries
            == sorted(KNOWN_CURSOR_WRITER_ENTRIES),
            "direct_1104_initializer_surface_seen": direct_1104_has_initializer,
            "read_only_callback_seen": callback_is_read_only,
            "no_4adb72_or_4add76_before_first_natural_4a5e73": (
                writer_probe_stopped_at_first_5e73_only
            ),
            "no_49cd9b_4adb72_or_4add76_before_first_natural_4a5e73": (
                callback_probe_stopped_at_first_5e73_only
            ),
            "natural_border_guard_reaches_4a5e73_but_cursor_unseeded": (
                downstream_unseeded
            ),
        },
        "remaining_blocker": (
            "The direct writer surface for generator+0xf5c is exhausted, but the "
            "natural seed-10 Border Guard endpoint attempt still reaches 0x4a5e73 "
            "with generator+0xf5c=0x7a1befdf. The missing recovery target is the "
            "source path/precondition that should seed or intentionally bypass "
            "+0xf5c/+0x1104 before successful Border Guard endpoint materialization; "
            "do not implement native RMG behavior from final-map deltas."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scan", type=Path, default=DEFAULT_SCAN)
    parser.add_argument("--downstream-summary", type=Path, default=DEFAULT_DOWNSTREAM_SUMMARY)
    parser.add_argument("--writer-probe-ledger", type=Path, default=DEFAULT_WRITER_PROBE_LEDGER)
    parser.add_argument(
        "--callback-probe-ledger", type=Path, default=DEFAULT_CALLBACK_PROBE_LEDGER
    )
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(
        args.scan,
        args.downstream_summary,
        args.writer_probe_ledger,
        args.callback_probe_ledger,
    )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(
        "RMG_H3MAPED_CURSOR_STATE_ACCESS_SUMMARY "
        f"status={summary['status']} "
        f"rows={summary['row_count']} "
        f"writers={','.join(summary['cursor_f5c_writer_entries'])} "
        f"entries_4a5e73={summary['natural_seed10_cross_check']['entries_4a5e73']} "
        f"out={args.out}"
    )
    return 0 if summary["status"].endswith("still_unseeded") else 1


if __name__ == "__main__":
    raise SystemExit(main())
