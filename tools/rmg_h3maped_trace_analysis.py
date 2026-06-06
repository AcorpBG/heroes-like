#!/usr/bin/env python3
"""Analyze H3MapEd RMG runtime recovery ledgers.

This script summarizes source-state trace evidence. It does not compare final
maps and does not mutate native RMG behavior.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_PRE_4A4C8E = Path(".artifacts/rmg_recovery/seed58_existing_0x4a4c8e_parse/winedbg_recovery_trace_ledger.json")
DEFAULT_A85D = Path(".artifacts/rmg_recovery/seed58_interactive_49a85d_to_4a4c8e_lite/winedbg_interactive_trace_ledger.json")
DEFAULT_AA63 = Path(".artifacts/rmg_recovery/seed58_interactive_49aa63_to_4a4c8e/winedbg_interactive_trace_ledger.json")
DEFAULT_A80DC = Path(".artifacts/rmg_recovery/seed58_interactive_4a80dc_return_to_4a4c8e/winedbg_interactive_trace_ledger.json")
DEFAULT_OUT = Path(".artifacts/rmg_recovery/seed58_trace_analysis.json")


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def memory_words(event: dict[str, Any]) -> dict[int, int]:
    memory: dict[int, int] = {}
    for line in event.get("memory_lines", []):
        address = int(line["address"])
        for index, word in enumerate(line.get("words", [])):
            memory[address + index * 4] = int(word) & 0xFFFFFFFF
    return memory


def word_at(event: dict[str, Any], address: int) -> int | None:
    for line in event.get("memory_lines", []):
        words = line.get("words", [])
        base = int(line["address"])
        if base <= address < base + len(words) * 4 and (address - base) % 4 == 0:
            return int(words[(address - base) // 4]) & 0xFFFFFFFF
    return None


def signed32(value: int) -> int:
    value &= 0xFFFFFFFF
    return value - 0x100000000 if value & 0x80000000 else value


def parse_pre_4a4c8e(path: Path, cell_base: int, width: int, height: int, levels: int, stride: int) -> dict[str, Any]:
    ledger = load_json(path)
    if not ledger.get("events"):
        raise ValueError(f"ledger has no events: {path}")
    event = ledger["events"][0]
    memory = memory_words(event)
    total = width * height * levels
    bit_sets = {"bit22": set(), "bit25": set(), "bit26": set(), "bit27": set()}
    top_byte = Counter()
    missing: list[int] = []
    for flat in range(total):
        base = cell_base + flat * stride
        word = memory.get(base + 0x28)
        if word is None:
            missing.append(flat)
            continue
        top_byte[word >> 24] += 1
        for name, bit in (("bit22", 22), ("bit25", 25), ("bit26", 26), ("bit27", 27)):
            if word & (1 << bit):
                bit_sets[name].add(flat)
    return {
        "missing_cells": missing,
        "top_byte_histogram": dict(sorted(top_byte.items())),
        "bit_sets": bit_sets,
    }


def parse_a85d(path: Path) -> list[tuple[int, int, int]]:
    coords: list[tuple[int, int, int]] = []
    for event in load_json(path).get("events", []):
        if event.get("address") != "0x0049a85d":
            continue
        esp = event.get("registers", {}).get("esp")
        if not isinstance(esp, int):
            continue
        x = word_at(event, esp + 4)
        y = word_at(event, esp + 8)
        level = word_at(event, esp + 12)
        if x is None or y is None or level is None:
            continue
        coords.append((x, y, level))
    return coords


def clipped_3x3_flats(coords: list[tuple[int, int, int]], width: int, height: int) -> list[int]:
    flats: list[int] = []
    for x, y, level in coords:
        for yy in range(max(0, y - 1), min(height, y + 2)):
            for xx in range(max(0, x - 1), min(width, x + 2)):
                flats.append(((level * height) + yy) * width + xx)
    return flats


def parse_aa63(path: Path) -> list[tuple[int, int | None]]:
    calls: list[tuple[int, int | None]] = []
    for event in load_json(path).get("events", []):
        if event.get("address") != "0x0049aa63":
            continue
        esp = event.get("registers", {}).get("esp")
        arg = word_at(event, esp + 4) if isinstance(esp, int) else None
        flat = event.get("derived", {}).get("ecx_generated_cell_flat")
        if isinstance(flat, int):
            calls.append((flat, arg))
    return calls


def parse_a80dc_pairs(path: Path) -> list[dict[str, Any]]:
    pairs: list[dict[str, Any]] = []
    pending: dict[str, Any] | None = None
    for event in load_json(path).get("events", []):
        address = event.get("address")
        if address == "0x004a80dc":
            esp = event.get("registers", {}).get("esp")
            if not isinstance(esp, int):
                continue
            values = [word_at(event, esp + 4 * index) for index in range(7)]
            if any(value is None for value in values):
                continue
            pending = {
                "out_ptr": values[1],
                "start": [signed32(values[2]), signed32(values[3])],
                "target": [signed32(values[4]), signed32(values[5])],
                "level": signed32(values[6]),
            }
        elif address == "0x004a8611" and pending:
            eax = event.get("registers", {}).get("eax")
            if isinstance(eax, int):
                pending["return"] = [word_at(event, eax), word_at(event, eax + 4)]
            pairs.append(pending)
            pending = None
    return pairs


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pre-4a4c8e", type=Path, default=DEFAULT_PRE_4A4C8E)
    parser.add_argument("--a85d", type=Path, default=DEFAULT_A85D)
    parser.add_argument("--aa63", type=Path, default=DEFAULT_AA63)
    parser.add_argument("--a80dc", type=Path, default=DEFAULT_A80DC)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--cell-base", type=lambda value: int(value, 0), default=0x0188B6D4)
    parser.add_argument("--width", type=int, default=36)
    parser.add_argument("--height", type=int, default=36)
    parser.add_argument("--levels", type=int, default=1)
    parser.add_argument("--stride", type=lambda value: int(value, 0), default=0x30)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    pre = parse_pre_4a4c8e(args.pre_4a4c8e, args.cell_base, args.width, args.height, args.levels, args.stride)
    a85d_coords = parse_a85d(args.a85d)
    a85d_flats = clipped_3x3_flats(a85d_coords, args.width, args.height)
    a85d_set = set(a85d_flats)
    aa63_calls = parse_aa63(args.aa63)
    aa63_flats = {flat for flat, _arg in aa63_calls}
    a80dc_pairs = parse_a80dc_pairs(args.a80dc)

    bit_sets = pre["bit_sets"]
    result = {
        "schema_id": "h3maped_seed58_trace_analysis_v1",
        "pre_4a4c8e": {
            "missing_cells": pre["missing_cells"],
            "top_byte_histogram": pre["top_byte_histogram"],
            "bit_counts": {name: len(values) for name, values in bit_sets.items()},
        },
        "a85d": {
            "call_count": len(a85d_coords),
            "unique_center_count": len(set(a85d_coords)),
            "level_histogram": dict(sorted(Counter(level for _x, _y, level in a85d_coords).items())),
            "stamp_event_count": len(a85d_flats),
            "unique_stamp_flat_count": len(a85d_set),
            "unique_stamp_flats_intersect_bit27": len(a85d_set & bit_sets["bit27"]),
            "unique_stamp_flats_not_bit27": len(a85d_set - bit_sets["bit27"]),
            "bit27_flats_outside_a85d_stamps": len(bit_sets["bit27"] - a85d_set),
            "bit26_flats_intersect_a85d_stamps": len(bit_sets["bit26"] & a85d_set),
        },
        "aa63": {
            "call_count": len(aa63_calls),
            "unique_flat_count": len(aa63_flats),
            "arg_histogram": dict(sorted(Counter(arg for _flat, arg in aa63_calls).items())),
            "intersect_pre_4a4c8e_bit26": len(aa63_flats & bit_sets["bit26"]),
        },
        "a80dc": {
            "pair_count": len(a80dc_pairs),
            "unique_return_count": len({tuple(pair.get("return", [])) for pair in a80dc_pairs}),
            "pairs": a80dc_pairs,
        },
        "unexplained": {
            "bit27_outside_a85d_stamp_sample": sorted(bit_sets["bit27"] - a85d_set)[:80],
            "a85d_stamp_not_bit27_sample": sorted(a85d_set - bit_sets["bit27"])[:80],
        },
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_TRACE_ANALYSIS "
        f"status=pass a85d_calls={len(a85d_coords)} aa63_calls={len(aa63_calls)} "
        f"a80dc_pairs={len(a80dc_pairs)} out={args.out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
