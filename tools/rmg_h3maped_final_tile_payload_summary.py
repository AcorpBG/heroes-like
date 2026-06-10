#!/usr/bin/env python3
"""Decode the final H3MapEd generated-cell tile payload at writeout.

This is a payload checkpoint, not a final-map density report. It consumes a
single `0x4ad251` Wine trace where the generator object and full generated-cell
grid were dumped, then reconstructs the exact seven one-byte writes performed by
`0x49b2b6` for every generated cell.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from collections import Counter
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_LEDGER = ROOT / "medium_seed10_final_tile_payload_grid_20260610" / "winedbg_interactive_trace_ledger.json"
DEFAULT_OUT = ROOT / "final_tile_payload_summary_20260610.json"
DEFAULT_BYTES_OUT = ROOT / "final_tile_payload_bytes_20260610.bin"

EXPECTED_ADDRESS = "0x004ad251"
EXPECTED_WIDTH = 72
EXPECTED_HEIGHT = 72
EXPECTED_LEVELS = 1
CELL_STRIDE_BYTES = 0x30
CELL_DWORDS = CELL_STRIDE_BYTES // 4

STATIC_TILE_WRITER_MARKERS = [
    "0049b2c8: MOV EAX,dword ptr [EDI + 0x24]",
    "0049b2cc: SHL EAX,0x1a",
    "0049b2cf: SAR EAX,0x1a",
    "0049b2dd: MOV EAX,dword ptr [EDI + 0x24]",
    "0049b2e3: SHL EAX,0x12",
    "0049b2e6: SAR EAX,0x18",
    "0049b2f5: MOV EAX,dword ptr [EDI + 0x24]",
    "0049b2fb: SHL EAX,0xe",
    "0049b2fe: SAR EAX,0x1c",
    "0049b30d: MOV EAX,dword ptr [EDI + 0x24]",
    "0049b313: SHL EAX,0x6",
    "0049b316: SAR EAX,0x18",
    "0049b325: MOV EAX,dword ptr [EDI + 0x24]",
    "0049b32b: SHL EAX,0x2",
    "0049b32e: SAR EAX,0x1c",
    "0049b33d: MOV EAX,dword ptr [EDI + 0x28]",
    "0049b343: SHL EAX,0x18",
    "0049b346: SAR EAX,0x18",
    "0049b355: MOV EDI,dword ptr [EDI + 0x28]",
    "0049b35a: TEST EDI,0x8000",
    "0049b364: TEST EDI,0x10000",
    "0049b36e: TEST EDI,0x20000",
    "0049b378: TEST EDI,0x40000",
    "0049b382: TEST EDI,0x80000",
    "0049b38c: TEST EDI,0x100000",
    "0049b396: TEST EDI,0x200000",
    "0049b3ac: CALL dword ptr [EAX + 0x8]",
]


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def shl32(value: int, bits: int) -> int:
    return (value << bits) & 0xFFFFFFFF


def sar32(value: int, bits: int) -> int:
    value &= 0xFFFFFFFF
    if value & 0x80000000:
        value -= 0x100000000
    return (value >> bits) & 0xFFFFFFFF


def writer_byte_from_shifts(value: int, left: int, right: int) -> int:
    return sar32(shl32(value, left), right) & 0xFF


def decode_tile_bytes(cell_words: list[int]) -> list[int]:
    word_24 = cell_words[0x24 // 4]
    word_28 = cell_words[0x28 // 4]
    passability = 0
    for bit, mask in enumerate([0x8000, 0x10000, 0x20000, 0x40000, 0x80000, 0x100000, 0x200000]):
        if word_28 & mask:
            passability |= 1 << bit
    return [
        writer_byte_from_shifts(word_24, 0x1A, 0x1A),
        writer_byte_from_shifts(word_24, 0x12, 0x18),
        writer_byte_from_shifts(word_24, 0x0E, 0x1C),
        writer_byte_from_shifts(word_24, 0x06, 0x18),
        writer_byte_from_shifts(word_24, 0x02, 0x1C),
        writer_byte_from_shifts(word_28, 0x18, 0x18),
        passability,
    ]


def flatten_words(lines: list[dict[str, Any]]) -> list[int]:
    return [int(word) & 0xFFFFFFFF for line in lines for word in line.get("words", [])]


def find_grid_lines(event: dict[str, Any], grid_base: int, expected_line_count: int) -> list[dict[str, Any]]:
    lines = event.get("memory_lines", [])
    for index, line in enumerate(lines):
        if line.get("address") == grid_base:
            candidate = lines[index : index + expected_line_count]
            if len(candidate) == expected_line_count:
                return candidate
    return []


def static_marker_results(path: Path) -> dict[str, Any]:
    text = read_text(path) if path.exists() else ""
    markers = [{"marker": marker, "present": marker in text} for marker in STATIC_TILE_WRITER_MARKERS]
    return {
        "file": str(path),
        "present": path.exists(),
        "marker_count": len(markers),
        "present_marker_count": sum(1 for marker in markers if marker["present"]),
        "all_markers_present": all(marker["present"] for marker in markers),
        "markers": markers,
    }


def summarize(ledger_path: Path, ghidra_tile_writer: Path) -> tuple[dict[str, Any], bytes]:
    ledger = load_json(ledger_path)
    events = ledger.get("events", [])
    if len(events) != 1:
        raise ValueError(f"expected exactly one trace event, got {len(events)}")
    event = events[0]
    if event.get("address") != EXPECTED_ADDRESS:
        raise ValueError(f"expected {EXPECTED_ADDRESS}, got {event.get('address')}")
    registers = event.get("registers", {})
    generator = registers.get("esi")
    if not isinstance(generator, int):
        raise ValueError("0x4ad251 event did not preserve generator pointer in ESI")

    lines = event.get("memory_lines", [])
    generator_words = []
    for line in lines:
        if line.get("address") == generator:
            start = lines.index(line)
            generator_words = flatten_words(lines[start : start + 6])
            break
    if len(generator_words) < 9:
        raise ValueError("could not recover generator header words from 0x4ad251 dump")

    grid_base = generator_words[0x14 // 4]
    width = generator_words[0x18 // 4]
    height = generator_words[0x1C // 4]
    levels = generator_words[0x20 // 4]
    expected_cells = width * height * levels
    expected_grid_words = expected_cells * CELL_DWORDS
    expected_grid_lines = expected_grid_words // 4
    grid_lines = find_grid_lines(event, grid_base, expected_grid_lines)
    grid_words = flatten_words(grid_lines)

    cells: list[list[int]] = []
    for offset in range(0, len(grid_words), CELL_DWORDS):
        cells.append(grid_words[offset : offset + CELL_DWORDS])

    payload = bytearray()
    byte_counters = [Counter() for _ in range(7)]
    word_24_counter: Counter[int] = Counter()
    word_28_counter: Counter[int] = Counter()
    nonzero_passability = 0
    for cell in cells:
        tile_bytes = decode_tile_bytes(cell)
        payload.extend(tile_bytes)
        for index, value in enumerate(tile_bytes):
            byte_counters[index][value] += 1
        word_24_counter[cell[0x24 // 4]] += 1
        word_28_counter[cell[0x28 // 4]] += 1
        if tile_bytes[6]:
            nonzero_passability += 1

    marker_check = static_marker_results(ghidra_tile_writer)
    payload_complete = (
        width == EXPECTED_WIDTH
        and height == EXPECTED_HEIGHT
        and levels == EXPECTED_LEVELS
        and len(cells) == expected_cells == EXPECTED_WIDTH * EXPECTED_HEIGHT * EXPECTED_LEVELS
        and len(grid_words) == expected_grid_words
        and len(payload) == expected_cells * 7
        and marker_check["all_markers_present"]
    )

    first_samples = []
    last_samples = []
    for flat, cell in list(enumerate(cells))[:8]:
        first_samples.append(cell_sample(flat, width, height, cell))
    start = max(0, len(cells) - 8)
    for flat, cell in list(enumerate(cells))[start:]:
        last_samples.append(cell_sample(flat, width, height, cell))

    summary = {
        "schema_id": "h3maped_final_tile_payload_summary_v1",
        "status": "final_tile_payload_replay_recovered" if payload_complete else "final_tile_payload_replay_incomplete",
        "scope": {
            "profile": "H3MapEd Medium one-level no-water seed 10, human/computer down 1, computer-only down 0",
            "positive_claim": "complete final tile payload source-state replay for 0x49b2b6 over every generated cell",
            "negative_claim": "does not decode generated-object serialization payloads or claim full native RMG parity",
        },
        "inputs": {
            "ledger": str(ledger_path),
            "ghidra_tile_writer": str(ghidra_tile_writer),
        },
        "metrics": {
            "generator_pointer": generator,
            "grid_base": grid_base,
            "width": width,
            "height": height,
            "levels": levels,
            "cell_stride_bytes": CELL_STRIDE_BYTES,
            "cell_count": len(cells),
            "expected_cell_count": expected_cells,
            "grid_word_count": len(grid_words),
            "expected_grid_word_count": expected_grid_words,
            "tile_payload_bytes_per_cell": 7,
            "tile_payload_byte_count": len(payload),
            "tile_payload_sha256": hashlib.sha256(payload).hexdigest(),
            "distinct_word_24_count": len(word_24_counter),
            "distinct_word_28_count": len(word_28_counter),
            "nonzero_passability_byte_cell_count": nonzero_passability,
            "static_tile_writer_markers_complete": marker_check["all_markers_present"],
            "final_tile_payload_replay_complete": payload_complete,
            "full_private_payload_replay_complete": False,
            "generated_object_payload_replay_complete": False,
            "native_behavior_changed": False,
            "used_objdump": False,
            "overall_goal_complete": False,
        },
        "tile_byte_histograms": [
            {"byte_index": index, "distinct_values": len(counter), "counts": hex_counter(counter)}
            for index, counter in enumerate(byte_counters)
        ],
        "static_tile_writer_check": marker_check,
        "first_cells": first_samples,
        "last_cells": last_samples,
        "remaining_gap": (
            "Final tile bytes are now reconstructed for every generated cell from H3MapEd private state. "
            "Full writeout parity still requires generated-object serialization payload replay and final stream/field comparison."
        ),
    }
    return summary, bytes(payload)


def cell_sample(flat: int, width: int, height: int, cell: list[int]) -> dict[str, Any]:
    per_level = width * height
    z = flat // per_level
    rem = flat % per_level
    y = rem // width
    x = rem % width
    return {
        "flat": flat,
        "x": x,
        "y": y,
        "z": z,
        "word_20": "0x%08x" % cell[0x20 // 4],
        "word_24": "0x%08x" % cell[0x24 // 4],
        "word_28": "0x%08x" % cell[0x28 // 4],
        "word_2c": "0x%08x" % cell[0x2C // 4],
        "tile_bytes": ["0x%02x" % value for value in decode_tile_bytes(cell)],
    }


def hex_counter(counter: Counter[int]) -> dict[str, int]:
    return {("0x%02x" % key): counter[key] for key in sorted(counter)}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument(
        "--ghidra-tile-writer",
        type=Path,
        default=ROOT / "ghidra_writeout_spine_dump_20260610" / "target_0049b2b6_FUN_0049b2b6.txt",
    )
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--bytes-out", type=Path, default=DEFAULT_BYTES_OUT)
    args = parser.parse_args()

    summary, payload = summarize(args.ledger, args.ghidra_tile_writer)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.bytes_out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    args.bytes_out.write_bytes(payload)
    print(
        "RMG_H3MAPED_FINAL_TILE_PAYLOAD "
        f"status={summary['status']} "
        f"cells={summary['metrics']['cell_count']} "
        f"bytes={summary['metrics']['tile_payload_byte_count']} "
        f"sha256={summary['metrics']['tile_payload_sha256']} "
        f"out={args.out}"
    )
    return 0 if summary["metrics"]["final_tile_payload_replay_complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
