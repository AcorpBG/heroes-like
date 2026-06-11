#!/usr/bin/env python3
"""Compare recovered H3MapEd final tile bytes against native RMG writeout.

This is a native-adoption comparator, not a density gate. It consumes the
recovered H3MapEd 0x49b2b6 final generated-cell tile payload and a native phase
snapshot, then reports exact byte-lane drift. A mismatch is valid output: it
names the next source-backed native porting target instead of declaring parity.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_H3MAPED_BYTES = Path(".artifacts/rmg_recovery/same_run_final_tile_payload_bytes_20260610.bin")
DEFAULT_OUT = Path(".artifacts/rmg_native_h3maped_final_tile_payload_compare.json")
TILE_BYTE_SCHEMA = "aurelion_h3maped_small_tile_bytes_0x49b2b6_draft_v1"
LANES = [
    ("byte_0_terrain_u8", "terrain_id"),
    ("byte_1_terrain_art_u8", "terrain_art"),
    ("byte_2_river_type_u8", "river_type"),
    ("byte_3_river_art_u8", "river_art"),
    ("byte_4_road_type_u8", "road_type"),
    ("byte_5_road_art_u8", "road_art"),
    ("byte_6_flags_u8", "flags"),
]


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def walk_dicts(value: Any):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from walk_dicts(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk_dicts(child)


def find_native_tile_bytes(snapshot: dict[str, Any]) -> dict[str, Any]:
    direct = (
        snapshot.get("h3maped_small_port", {})
        .get("final_h3m_writeout", {})
        .get("tile_bytes")
    )
    if isinstance(direct, dict):
        return direct
    for candidate in walk_dicts(snapshot):
        if candidate.get("schema_id") == TILE_BYTE_SCHEMA:
            return candidate
    raise ValueError(f"native phase snapshot is missing tile byte schema {TILE_BYTE_SCHEMA}")


def as_byte(value: Any) -> int:
    return int(value) & 0xFF


def lane_values(tile_bytes: dict[str, Any], lane_key: str) -> list[int]:
    values = tile_bytes.get(lane_key)
    if not isinstance(values, list):
        raise ValueError(f"native tile byte lane {lane_key!r} is missing or not a list")
    return [as_byte(value) for value in values]


def native_interleaved_payload(tile_bytes: dict[str, Any]) -> tuple[bytes, dict[str, list[int]]]:
    lanes = {lane_key: lane_values(tile_bytes, lane_key) for lane_key, _ in LANES}
    lane_sizes = {lane_key: len(values) for lane_key, values in lanes.items()}
    if len(set(lane_sizes.values())) != 1:
        raise ValueError(f"native tile byte lanes have inconsistent sizes: {lane_sizes}")
    cell_count = next(iter(lane_sizes.values()))
    payload = bytearray()
    for cell in range(cell_count):
        for lane_key, _ in LANES:
            payload.append(lanes[lane_key][cell])
    return bytes(payload), lanes


def infer_dimensions(snapshot: dict[str, Any], cell_count: int) -> dict[str, int]:
    size = snapshot.get("config", {}).get("size", {})
    width = int(size.get("width") or size.get("source_width") or 0)
    height = int(size.get("height") or size.get("source_height") or 0)
    levels = int(size.get("level_count") or 1)
    if width <= 0 or height <= 0 or levels <= 0 or width * height * levels != cell_count:
        width = cell_count
        height = 1
        levels = 1
    return {"width": width, "height": height, "levels": levels}


def coordinate(flat: int, dimensions: dict[str, int]) -> dict[str, int]:
    width = dimensions["width"]
    height = dimensions["height"]
    level_size = width * height
    level = flat // level_size if level_size else 0
    remainder = flat % level_size if level_size else flat
    return {
        "flat": flat,
        "x": remainder % width if width else flat,
        "y": remainder // width if width else 0,
        "level": level,
    }


def top_pair_records(counter: Counter[tuple[int, int]], limit: int) -> list[dict[str, int]]:
    return [
        {"h3maped": h3, "native": native, "count": count}
        for (h3, native), count in counter.most_common(limit)
    ]


def diagnose_first_drift(lane_mismatches: dict[str, int]) -> dict[str, str]:
    if lane_mismatches.get("byte_0_terrain_u8", 0) or lane_mismatches.get("byte_1_terrain_art_u8", 0):
        return {
            "first_drift_phase": "terrain_generated_cell_word_0x24_before_0x49b2b6",
            "native_port_blocker": "native terrain/generated-cell private state diverges before final tile writer; port upstream terrain placement/private-state replay before tuning objects",
        }
    if lane_mismatches.get("byte_6_flags_u8", 0):
        return {
            "first_drift_phase": "passability_or_overlay_flags_word_0x28_before_0x49b2b6",
            "native_port_blocker": "native generated-cell word_0x28 flags diverge before final tile writer",
        }
    if lane_mismatches.get("byte_2_river_type_u8", 0) or lane_mismatches.get("byte_3_river_art_u8", 0):
        return {
            "first_drift_phase": "river_overlay_writeback_0x4b4243_to_0x49b2b6",
            "native_port_blocker": "native river overlay bytes are missing or divergent; recover/port river overlay writeback before final parity claims",
        }
    if lane_mismatches.get("byte_4_road_type_u8", 0) or lane_mismatches.get("byte_5_road_art_u8", 0):
        return {
            "first_drift_phase": "road_overlay_writeback_0x4ab37f_0x458a2f_to_0x49b2b6",
            "native_port_blocker": "native road overlay byte writeback diverges from recovered H3MapEd final payload",
        }
    return {
        "first_drift_phase": "none",
        "native_port_blocker": "no final tile byte drift detected for this payload",
    }


def build_report(args: argparse.Namespace) -> dict[str, Any]:
    h3_payload = args.h3maped_final_tile_bytes.read_bytes()
    snapshot = load_json(args.native_phase_snapshot)
    native_tile_bytes = find_native_tile_bytes(snapshot)
    native_payload, native_lanes = native_interleaved_payload(native_tile_bytes)
    if len(h3_payload) % len(LANES) != 0:
        raise ValueError(f"H3MapEd payload byte count {len(h3_payload)} is not divisible by {len(LANES)}")
    h3_cell_count = len(h3_payload) // len(LANES)
    native_cell_count = len(native_payload) // len(LANES)
    dimensions = infer_dimensions(snapshot, native_cell_count)

    lane_mismatches: Counter[str] = Counter()
    lane_pair_counters: dict[str, Counter[tuple[int, int]]] = {
        lane_key: Counter() for lane_key, _ in LANES
    }
    first_mismatches: list[dict[str, Any]] = []
    compare_len = min(len(h3_payload), len(native_payload))
    for index in range(compare_len):
        h3_byte = h3_payload[index]
        native_byte = native_payload[index]
        if h3_byte == native_byte:
            continue
        lane_index = index % len(LANES)
        flat = index // len(LANES)
        lane_key, lane_name = LANES[lane_index]
        lane_mismatches[lane_key] += 1
        lane_pair_counters[lane_key][(h3_byte, native_byte)] += 1
        if len(first_mismatches) < args.max_mismatches:
            item = coordinate(flat, dimensions)
            item.update(
                {
                    "byte_index": index,
                    "lane": lane_key,
                    "lane_name": lane_name,
                    "h3maped": h3_byte,
                    "native": native_byte,
                }
            )
            first_mismatches.append(item)

    length_delta = len(native_payload) - len(h3_payload)
    total_mismatches = sum(lane_mismatches.values()) + abs(length_delta)
    lane_reports = {}
    for lane_key, lane_name in LANES:
        values = native_lanes[lane_key]
        lane_reports[lane_key] = {
            "lane_name": lane_name,
            "mismatch_count": lane_mismatches.get(lane_key, 0),
            "native_nonzero_count": sum(1 for value in values if value != 0),
            "top_h3maped_native_pairs": top_pair_records(lane_pair_counters[lane_key], args.top_pairs),
        }

    diagnosis = diagnose_first_drift(dict(lane_mismatches))
    status = "match" if total_mismatches == 0 else "mismatch"
    return {
        "schema_id": "rmg_h3maped_final_tile_payload_compare_v1",
        "status": status,
        "scope": {
            "positive_claim": "compares recovered H3MapEd 0x49b2b6 final tile bytes against native final_h3m_writeout tile bytes",
            "negative_claim": "does not claim native RMG parity and does not compare object/header payloads",
        },
        "inputs": {
            "h3maped_final_tile_bytes": str(args.h3maped_final_tile_bytes),
            "native_phase_snapshot": str(args.native_phase_snapshot),
        },
        "metrics": {
            "h3maped_payload_byte_count": len(h3_payload),
            "native_payload_byte_count": len(native_payload),
            "h3maped_cell_count": h3_cell_count,
            "native_cell_count": native_cell_count,
            "bytes_per_cell": len(LANES),
            "length_delta_native_minus_h3maped": length_delta,
            "total_byte_mismatch_count": total_mismatches,
            "h3maped_payload_sha256": hashlib.sha256(h3_payload).hexdigest(),
            "native_payload_sha256": hashlib.sha256(native_payload).hexdigest(),
            "native_behavior_changed": False,
            "native_rmg_end_to_end_parity_complete": False,
        },
        "dimensions": dimensions,
        "diagnosis": diagnosis,
        "lane_reports": lane_reports,
        "first_mismatches": first_mismatches,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--h3maped-final-tile-bytes", type=Path, default=DEFAULT_H3MAPED_BYTES)
    parser.add_argument("--native-phase-snapshot", type=Path, required=True)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--max-mismatches", type=int, default=80)
    parser.add_argument("--top-pairs", type=int, default=12)
    args = parser.parse_args()

    report = build_report(args)
    write_json(args.out, report)
    metrics = report["metrics"]
    diagnosis = report["diagnosis"]
    print(
        "RMG_H3MAPED_FINAL_TILE_PAYLOAD_COMPARE "
        f"status={report['status']} "
        f"total_byte_mismatch_count={metrics['total_byte_mismatch_count']} "
        f"first_drift_phase={diagnosis['first_drift_phase']} "
        f"out={args.out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
