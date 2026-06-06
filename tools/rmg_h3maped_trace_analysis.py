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
DEFAULT_A962 = Path(".artifacts/rmg_recovery/seed58_interactive_49a962_to_4a4c8e_lite/winedbg_interactive_trace_ledger.json")
DEFAULT_ABD6_BODY = Path(".artifacts/rmg_recovery/seed58_interactive_49abd6_body_cells_to_4a8c15/winedbg_interactive_trace_ledger.json")
DEFAULT_ROUTE_CALLS = Path(".artifacts/rmg_recovery/seed58_piped_4a8260_route_call_sites_to_4a4c8e_full/winedbg_recovery_trace_ledger.json")
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
    valid_flats: set[int] = set()
    terrain_by_flat: dict[int, int] = {}
    top_byte = Counter()
    missing: list[int] = []
    for flat in range(total):
        base = cell_base + flat * stride
        word = memory.get(base + 0x28)
        terrain_word = memory.get(base + 0x24)
        if word is None:
            missing.append(flat)
            continue
        terrain = (terrain_word or 0) & 0x3F
        terrain_by_flat[flat] = terrain
        if (word >> 24) & 0x02 and terrain != 9:
            valid_flats.add(flat)
        top_byte[word >> 24] += 1
        for name, bit in (("bit22", 22), ("bit25", 25), ("bit26", 26), ("bit27", 27)):
            if word & (1 << bit):
                bit_sets[name].add(flat)
    return {
        "missing_cells": missing,
        "top_byte_histogram": dict(sorted(top_byte.items())),
        "bit_sets": bit_sets,
        "valid_flats": valid_flats,
        "terrain_by_flat": terrain_by_flat,
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


def parse_coordinate_entries(path: Path, address: str) -> list[tuple[int, int, int]]:
    coords: list[tuple[int, int, int]] = []
    normalized = normalize_address(address)
    for event in load_json(path).get("events", []):
        if normalize_address(event.get("address", "0")) != normalized:
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


def parse_generated_cell_call_site(path: Path, address: str) -> list[int]:
    flats: list[int] = []
    normalized = normalize_address(address)
    for event in load_json(path).get("events", []):
        if normalize_address(event.get("address", "0")) != normalized:
            continue
        flat = event.get("derived", {}).get("ecx_generated_cell_flat")
        if isinstance(flat, int):
            flats.append(flat)
    return flats


def parse_route_call_sites(path: Path) -> dict[str, Any]:
    insert_sites = {"0x004a8491", "0x004a849d", "0x004a84a9", "0x004a84b5", "0x004a863e", "0x004a864a"}
    insertions: list[dict[str, Any]] = []
    stamp_coords: list[tuple[int, int, int]] = []
    event_addresses: list[str] = []
    for index, event in enumerate(load_json(path).get("events", [])):
        address = event.get("address")
        if not isinstance(address, str):
            continue
        event_addresses.append(address)
        esp = event.get("registers", {}).get("esp")
        if not isinstance(esp, int):
            continue
        if address in insert_sites:
            pointer = word_at(event, esp)
            coord: list[int | None] = [None, None]
            if isinstance(pointer, int):
                coord = [word_at(event, pointer), word_at(event, pointer + 4)]
            insertions.append({"event_index": index, "call_site": address, "pointer": pointer, "coord": coord})
        elif address == "0x004a858f":
            x = word_at(event, esp)
            y = word_at(event, esp + 4)
            level = word_at(event, esp + 8)
            if x is not None and y is not None and level is not None:
                stamp_coords.append((x, y, level))
    return {
        "event_addresses": event_addresses,
        "insertions": insertions,
        "stamp_coords": stamp_coords,
    }


def normalize_address(value: str) -> str:
    return "0x%08x" % int(value, 0)


def replay_a962_clears(
    coords: list[tuple[int, int, int]],
    width: int,
    height: int,
    total_cells: int,
    bit22_flats: set[int],
    valid_flats: set[int],
    terrain_by_flat: dict[int, int],
) -> dict[str, Any]:
    center_flats = {((level * height) + y) * width + x for x, y, level in coords}
    clear_flats = set(center_flats)
    neighbor_candidates: set[int] = set()
    skipped_bit22: set[int] = set()
    skipped_invalid: set[int] = set()
    skipped_terrain8: set[int] = set()
    for x, y, level in coords:
        for yy in range(max(0, y - 1), min(height, y + 2)):
            for xx in range(max(0, x - 1), min(width, x + 2)):
                flat = ((level * height) + yy) * width + xx
                neighbor_candidates.add(flat)
                if flat in bit22_flats:
                    skipped_bit22.add(flat)
                    continue
                if flat not in valid_flats:
                    skipped_invalid.add(flat)
                    continue
                if terrain_by_flat.get(flat) == 8:
                    skipped_terrain8.add(flat)
                    continue
                clear_flats.add(flat)
    remaining_bit27 = set(range(total_cells)) - clear_flats
    return {
        "center_flats": center_flats,
        "neighbor_candidates": neighbor_candidates,
        "clear_flats": clear_flats,
        "remaining_bit27": remaining_bit27,
        "skipped_bit22": skipped_bit22,
        "skipped_invalid": skipped_invalid,
        "skipped_terrain8": skipped_terrain8,
    }


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
            if "return" in pending:
                start_x, start_y = pending["start"]
                return_x, return_y = pending["return"]
                if return_x is not None and return_y is not None:
                    pending["return_start_distance_squared"] = (return_x - start_x) ** 2 + (return_y - start_y) ** 2
            pairs.append(pending)
            pending = None
    return pairs


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pre-4a4c8e", type=Path, default=DEFAULT_PRE_4A4C8E)
    parser.add_argument("--a85d", type=Path, default=DEFAULT_A85D)
    parser.add_argument("--aa63", type=Path, default=DEFAULT_AA63)
    parser.add_argument("--a80dc", type=Path, default=DEFAULT_A80DC)
    parser.add_argument("--a962", type=Path, default=DEFAULT_A962)
    parser.add_argument("--abd6-body", type=Path, default=DEFAULT_ABD6_BODY)
    parser.add_argument("--route-calls", type=Path, default=DEFAULT_ROUTE_CALLS)
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
    a962_coords = parse_coordinate_entries(args.a962, "0x49a962")
    abd6_body_flats = parse_generated_cell_call_site(args.abd6_body, "0x49ac6b")
    route_calls = parse_route_call_sites(args.route_calls)

    bit_sets = pre["bit_sets"]
    total_cells = args.width * args.height * args.levels
    a962_replay = replay_a962_clears(
        a962_coords,
        args.width,
        args.height,
        total_cells,
        bit_sets["bit22"],
        pre["valid_flats"],
        pre["terrain_by_flat"],
    )
    bit27_outside_a85d = bit_sets["bit27"] - a85d_set
    route_insertions = route_calls["insertions"]
    route_stamp_coords = route_calls["stamp_coords"]
    route_call_counts = Counter(route_calls["event_addresses"])
    far_a80dc_pairs = [
        pair for pair in a80dc_pairs if int(pair.get("return_start_distance_squared", -1)) >= 25
    ]
    route_far_insertions = [
        insertion for insertion in route_insertions if insertion["call_site"] in {"0x004a863e", "0x004a864a"}
    ]
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
        "a962": {
            "call_count": len(a962_coords),
            "unique_center_count": len(set(a962_coords)),
            "level_histogram": dict(sorted(Counter(level for _x, _y, level in a962_coords).items())),
            "center_flat_count": len(a962_replay["center_flats"]),
            "neighbor_candidate_count": len(a962_replay["neighbor_candidates"]),
            "clear_flat_count": len(a962_replay["clear_flats"]),
            "replayed_remaining_bit27_count": len(a962_replay["remaining_bit27"]),
            "replayed_remaining_bit27_matches_pre_4a4c8e": a962_replay["remaining_bit27"] == bit_sets["bit27"],
            "skipped_bit22_count": len(a962_replay["skipped_bit22"]),
            "skipped_invalid_count": len(a962_replay["skipped_invalid"]),
            "skipped_terrain8_count": len(a962_replay["skipped_terrain8"]),
            "bit27_outside_a85d_due_to_bit22_skip": len(bit27_outside_a85d & a962_replay["skipped_bit22"]),
            "bit27_outside_a85d_due_to_invalid_skip": len(bit27_outside_a85d & a962_replay["skipped_invalid"]),
            "bit27_outside_a85d_due_to_terrain8_skip": len(bit27_outside_a85d & a962_replay["skipped_terrain8"]),
            "bit27_outside_a85d_not_in_a962_remaining": len(bit27_outside_a85d - a962_replay["remaining_bit27"]),
        },
        "abd6_body": {
            "call_site": "0x49ac6b",
            "body_write_count": len(abd6_body_flats),
            "unique_body_flat_count": len(set(abd6_body_flats)),
            "body_flats": abd6_body_flats,
            "body_flats_intersect_pre_4a4c8e_bit22": len(set(abd6_body_flats) & bit_sets["bit22"]),
            "body_flats_intersect_pre_4a4c8e_bit27": len(set(abd6_body_flats) & bit_sets["bit27"]),
        },
        "a80dc": {
            "pair_count": len(a80dc_pairs),
            "unique_return_count": len({tuple(pair.get("return", [])) for pair in a80dc_pairs}),
            "return_start_distance_squared_gte_25_count": len(far_a80dc_pairs),
            "pairs": a80dc_pairs,
        },
        "route_call_sites": {
            "ledger": str(args.route_calls),
            "event_count": len(route_calls["event_addresses"]),
            "call_site_counts": dict(sorted(route_call_counts.items())),
            "first_4a4c8e_index": route_calls["event_addresses"].index("0x004a4c8e") if "0x004a4c8e" in route_calls["event_addresses"] else None,
            "insert_call_count": len(route_insertions),
            "unique_insert_coord_count": len({tuple(insertion["coord"]) for insertion in route_insertions}),
            "insert_call_counts_by_site": dict(sorted(Counter(insertion["call_site"] for insertion in route_insertions).items())),
            "far_cut_insert_call_count": len(route_far_insertions),
            "far_cut_insert_pair_count": len(route_far_insertions) // 2,
            "far_cut_insert_pairs_match_a80dc_distance_gate": len(route_far_insertions) // 2 == len(far_a80dc_pairs),
            "stamp_call_count": len(route_stamp_coords),
            "unique_stamp_coord_count": len(set(route_stamp_coords)),
            "stamp_coords_match_a85d_trace_order": route_stamp_coords == a85d_coords,
            "stamp_coords_match_a85d_trace_multiset": Counter(route_stamp_coords) == Counter(a85d_coords),
            "first_insertions": route_insertions[:24],
            "last_insertions": route_insertions[-24:],
        },
        "samples": {
            "bit27_outside_a85d_stamp_sample": sorted(bit27_outside_a85d)[:80],
            "a85d_stamp_not_bit27_sample": sorted(a85d_set - bit_sets["bit27"])[:80],
        },
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_TRACE_ANALYSIS "
        f"status=pass a85d_calls={len(a85d_coords)} aa63_calls={len(aa63_calls)} "
        f"a962_calls={len(a962_coords)} a80dc_pairs={len(a80dc_pairs)} route_events={len(route_calls['event_addresses'])} "
        f"a962_replay_matches={a962_replay['remaining_bit27'] == bit_sets['bit27']} out={args.out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
