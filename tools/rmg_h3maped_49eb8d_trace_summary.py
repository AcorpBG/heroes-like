#!/usr/bin/env python3
"""Summarize raw H3MapEd 0x49eb8d/0x49e700 winedbg trace logs.

This tool parses existing raw WineDbg text logs into a small JSON evidence file.
It does not run H3MapEd, compare final maps, or mutate native RMG behavior.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


DEFAULT_TRACE_DIR = Path(".artifacts/rmg_private_trace_seed58_20260605")
DEFAULT_BIT26_LOG = DEFAULT_TRACE_DIR / "winedbg_0x49ec01_bit26_count.log"
DEFAULT_E700_LOG = DEFAULT_TRACE_DIR / "winedbg_0x49e700_entry.log"
DEFAULT_OUT = Path(".artifacts/rmg_recovery/seed58_49eb8d_trace_summary.json")

STOP_RE = re.compile(r"Stopped on breakpoint\s+\d+\s+at\s+0x([0-9a-fA-F]+)")
REGISTER_RE = re.compile(r"\b(eax|ebx|ecx|edx|esi|edi|ebp|esp|eip):([0-9a-fA-F]{8})\b", re.IGNORECASE)
MEMORY_RE = re.compile(r"^(?:Wine-dbg>)?0x([0-9a-fA-F]+):\s+(.+)$")
HEX_WORD_RE = re.compile(r"\b[0-9a-fA-F]{1,8}\b")


def parse_raw_winedbg(path: Path) -> list[dict[str, Any]]:
    events: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    for raw_line in path.read_text(errors="replace").splitlines():
        line = raw_line.strip().replace("\r", "")
        stop = STOP_RE.search(line)
        if stop:
            current = {
                "address": "0x%08x" % int(stop.group(1), 16),
                "registers": {},
                "memory": {},
            }
            events.append(current)
            continue
        if current is None:
            continue
        for reg, value in REGISTER_RE.findall(line):
            current["registers"][reg.lower()] = int(value, 16)
        memory = MEMORY_RE.match(line)
        if memory:
            base = int(memory.group(1), 16)
            for index, word in enumerate(HEX_WORD_RE.findall(memory.group(2))):
                current["memory"][base + index * 4] = int(word, 16) & 0xFFFFFFFF
    return events


def word_at(event: dict[str, Any], address: int) -> int | None:
    value = event.get("memory", {}).get(address)
    return int(value) & 0xFFFFFFFF if isinstance(value, int) else None


def generator_dimensions(event: dict[str, Any]) -> dict[str, int | None]:
    ebx = event.get("registers", {}).get("ebx")
    if not isinstance(ebx, int):
        return {"cell_base": None, "width": None, "height": None, "levels": None}
    return {
        "cell_base": word_at(event, ebx + 0x14),
        "width": word_at(event, ebx + 0x18),
        "height": word_at(event, ebx + 0x1C),
        "levels": word_at(event, ebx + 0x20),
    }


def parse_bit26_count(path: Path) -> dict[str, Any]:
    events = parse_raw_winedbg(path)
    if not events:
        raise ValueError(f"no breakpoint events parsed from {path}")
    event = events[0]
    ebp = event.get("registers", {}).get("ebp")
    if not isinstance(ebp, int):
        raise ValueError(f"missing EBP in {path}")
    count = word_at(event, ebp - 0x8)
    if count is None:
        raise ValueError(f"missing [EBP-0x8] bit26 count in {path}")
    budget = 0x4374C // count if count else None
    return {
        "log": str(path),
        "breakpoint": event.get("address"),
        "registers": event.get("registers", {}),
        "generator": generator_dimensions(event),
        "bit26_count_local_ebp_minus_0x8": count,
        "budget_formula": "0x4374c // bit26_count",
        "computed_budget": budget,
    }


def parse_e700_entry(path: Path) -> dict[str, Any]:
    events = parse_raw_winedbg(path)
    if not events:
        raise ValueError(f"no breakpoint events parsed from {path}")
    event = events[0]
    esp = event.get("registers", {}).get("esp")
    if not isinstance(esp, int):
        raise ValueError(f"missing ESP in {path}")
    return {
        "log": str(path),
        "breakpoint": event.get("address"),
        "registers": event.get("registers", {}),
        "return_address": word_at(event, esp),
        "call_args": {
            "x": word_at(event, esp + 0x4),
            "y": word_at(event, esp + 0x8),
            "level": word_at(event, esp + 0xC),
            "budget": word_at(event, esp + 0x10),
        },
        "generator": generator_dimensions(event),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bit26-log", type=Path, default=DEFAULT_BIT26_LOG)
    parser.add_argument("--e700-log", type=Path, default=DEFAULT_E700_LOG)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    bit26 = parse_bit26_count(args.bit26_log)
    e700 = parse_e700_entry(args.e700_log)
    computed_budget = bit26["computed_budget"]
    entry_budget = e700["call_args"]["budget"]
    result = {
        "schema_id": "h3maped_49eb8d_trace_summary_v1",
        "bit26_count_breakpoint": bit26,
        "first_49e700_entry_breakpoint": e700,
        "same_run_complete_replay": False,
        "same_run_complete_replay_reason": (
            "The count and first-entry captures are separate debugger runs; use them as stack/register "
            "layout evidence, not as a complete ordered 0x49eb8d replay."
        ),
        "cross_log_budget_matches": computed_budget == entry_budget,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_49EB8D_TRACE_SUMMARY "
        f"status=pass bit26_count={bit26['bit26_count_local_ebp_minus_0x8']} "
        f"computed_budget={computed_budget} first_e700={e700['call_args']} "
        f"cross_log_budget_matches={computed_budget == entry_budget} out={args.out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
