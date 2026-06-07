#!/usr/bin/env python3
"""Summarize live H3MapEd connection-record boundary probes.

This is a recovery checkpoint only. It documents what the latest direct
generation traces prove about the control record consumed by 0x4a7605 and what
is still unrecovered before native RMG behavior can change.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


DEFAULT_ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_OUT = DEFAULT_ROOT / "connection_record_runtime_boundary_summary.json"

DEFAULT_TRACE_DIRS = {
    "plus9_watch": DEFAULT_ROOT / "direct_generation_7605_plus9_watch_probe_fixed_ui",
    "c8_boundary": DEFAULT_ROOT / "direct_generation_c8_boundary_probe_fixed_ui",
    "c8_record_content": DEFAULT_ROOT / "direct_generation_c8_record_content_boundary_probe",
    "relation_boundary": DEFAULT_ROOT / "direct_generation_relation_record_boundary_probe",
    "argument_probe": DEFAULT_ROOT / "direct_generation_7605_argument_probe",
    "constructor_probe": DEFAULT_ROOT / "direct_generation_4b3c4e_4b3d3c_constructor_probe",
}

STOP_RE = re.compile(
    r"Stopped on (?P<kind>[A-Za-z _-]*(?:breakpoint|watchpoint))\s+"
    r"(?P<index>\d+)\s+at\s+0x(?P<address>[0-9a-fA-F]+)"
)


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""


def log_path(trace_dir: Path) -> Path:
    return trace_dir / "winedbg_interactive_trace.log"


def ledger_path(trace_dir: Path) -> Path:
    return trace_dir / "winedbg_interactive_trace_ledger.json"


def read_ledger(trace_dir: Path) -> dict[str, Any]:
    path = ledger_path(trace_dir)
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def stop_events(text: str) -> list[dict[str, Any]]:
    events: list[dict[str, Any]] = []
    for match in STOP_RE.finditer(text):
        address = "0x" + match.group("address").lower().zfill(8)
        events.append(
            {
                "kind": match.group("kind").strip().lower(),
                "index": int(match.group("index")),
                "address": address,
            }
        )
    return events


def address_counts(events: list[dict[str, Any]]) -> dict[str, int]:
    counts: dict[str, int] = {}
    for event in events:
        counts[event["address"]] = counts.get(event["address"], 0) + 1
    return counts


def has_watchpoint_stop(events: list[dict[str, Any]]) -> bool:
    return any("watchpoint" in event["kind"] for event in events)


def has_rejected_watch_command(text: str) -> bool:
    return "watch *($esi+0x9)" in text and "No type or type mismatch" in text


def trace_summary(name: str, trace_dir: Path) -> dict[str, Any]:
    text = read_text(log_path(trace_dir))
    ledger = read_ledger(trace_dir)
    events = stop_events(text)
    return {
        "name": name,
        "trace_dir": str(trace_dir),
        "log": str(log_path(trace_dir)),
        "ledger": str(ledger_path(trace_dir)),
        "log_exists": bool(text),
        "ledger_event_count": ledger.get("event_count"),
        "stop_event_count": len(events),
        "address_counts": address_counts(events),
        "watchpoint_stops": has_watchpoint_stop(events),
        "rejected_watch_command": has_rejected_watch_command(text),
    }


def summarize(trace_dirs: dict[str, Path]) -> dict[str, Any]:
    traces = {name: trace_summary(name, path) for name, path in trace_dirs.items()}

    plus9_log = read_text(log_path(trace_dirs["plus9_watch"]))
    c8_boundary_log = read_text(log_path(trace_dirs["c8_boundary"]))
    c8_record_log = read_text(log_path(trace_dirs["c8_record_content"]))
    relation_log = read_text(log_path(trace_dirs["relation_boundary"]))
    argument_log = read_text(log_path(trace_dirs["argument_probe"]))
    constructor_log = read_text(log_path(trace_dirs["constructor_probe"]))

    constructor_counts = traces["constructor_probe"]["address_counts"]
    invariants = {
        "fixed_ui_watch_trace_exists": traces["plus9_watch"]["log_exists"],
        "watch_command_rejected_not_installed": traces["plus9_watch"]["rejected_watch_command"],
        "no_plus9_watchpoint_evidence_claimed": not traces["plus9_watch"]["watchpoint_stops"],
        "c8_header_seen_at_first_boundary": "0x0031e120:" in c8_boundary_log
        or "x/8x $ecx+0xc8" in c8_boundary_log,
        "c8_record_content_seen_before_4a7605": "0x016bc080:" in c8_record_log
        or "x/24x *(int*)($ecx+0xc8)" in c8_record_log,
        "relation_vector_seen_at_first_boundary": "x/8x $ecx+0x10e4" in relation_log
        and "0x004a8c15" in relation_log,
        "consumer_argument_record_dumped": "x/64x *(int*)($esp+8)" in argument_log
        and "x/64x *(int*)($esp+4)" in argument_log,
        "constructor_copy_functions_absent_before_consumer": constructor_counts.get("0x004b3c4e", 0) == 0
        and constructor_counts.get("0x004b3c78", 0) == 0
        and constructor_counts.get("0x004b3d3c", 0) == 0
        and constructor_counts.get("0x004b3d66", 0) == 0
        and constructor_counts.get("0x004a7605", 0) >= 1,
        "no_native_behavior_change": True,
    }
    status = "partial_runtime_boundary_checkpoint" if all(invariants.values()) else "incomplete"

    return {
        "schema_id": "h3maped_connection_record_runtime_boundary_summary_v1",
        "status": status,
        "invariants": invariants,
        "traces": traces,
        "human_readable_result": [
            "The fixed UI driver now reaches the intended one-level direct random-map generation path.",
            "The prior watch command for the sampled 0x4a7605 control record byte +0x09 was rejected by winedbg, so this checkpoint must not claim watchpoint proof.",
            "The generator+0xc8 surface sampled at 0x4a8c15 is an 8-entry pointer vector header, not the 0x1c-byte record stream consumed later by 0x4a79a3.",
            "The sampled 0x4a7605 ESI control record is a separate edge/control record passed beside the source relation pointer, not the generator+0xc8 vector header itself.",
            "The byte read at +0x09 is part of the dword at edge/control-record +0x08; sibling records in the sampled contiguous block carry different +0x08 dword values such as 0x00010000.",
            "The related 0x4b3c4e and 0x4b3d3c dword-copy constructors did not fire before the sampled fallback consumer, so they are not the live producer for this direct-generation sample.",
        ],
        "next_recovery_target": (
            "Recover the owner and population path for the edge/control-record block iterated by "
            "0x4a79a3 before 0x4a7dcd/0x4a7dd0 selects a pair. The next live checkpoint should "
            "snapshot the actual 0x4a79a3 iterator records and break on the vector append or "
            "allocator that fills their +0x08 dword, rather than watching +0x09 after 0x4a7605."
        ),
        "native_behavior_changed": False,
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    trace_dirs = {name: args.root / path.name for name, path in DEFAULT_TRACE_DIRS.items()}
    summary = summarize(trace_dirs)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_CONNECTION_RECORD_RUNTIME_BOUNDARY_SUMMARY status={summary['status']} out={args.out}")
    return 0 if summary["status"] == "partial_runtime_boundary_checkpoint" else 1


if __name__ == "__main__":
    raise SystemExit(main())
