#!/usr/bin/env python3
"""Emit the canonical H3MapEd RMG recovery manifest.

The manifest is intentionally about reverse-engineering state, not final map
counts. It records the binary identity, required function addresses, generated
cell layout, and checkpoint targets that must be proven before native behavior
changes are allowed.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path
from typing import Any


DEFAULT_H3MAPED = Path(".artifacts/rmg_20seed_2p_small_h3maped_20260605/small_2p_seed_58_manual20/runtime/h3maped.exe")
DEFAULT_OUT = Path(".artifacts/rmg_recovery/h3maped_recovery_manifest.json")

FUNCTIONS: list[dict[str, Any]] = [
    {
        "address": "0x499e65",
        "name": "generated_cell_constructor",
        "status": "recovered_static_ghidra",
        "writes": ["cell+0x00 byte argument", "cell+0x04/+0x08/+0x0c zero", "calls 0x499ea3"],
    },
    {
        "address": "0x49a072",
        "name": "generated_cell_grid_reset",
        "status": "recovered_static_ghidra",
        "reads": ["grid+0x08 cell buffer", "grid+0x0c width", "grid+0x10 height", "grid+0x14 level count"],
        "writes": ["calls 0x499ea3 for width*height*levels cells with stride 0x30"],
    },
    {
        "address": "0x499ea3",
        "name": "generated_cell_initializer",
        "status": "recovered_static_ghidra",
        "writes": [
            "cell+0x10 = 0xffffffff",
            "cell+0x1c = 0x7fbc7fbc",
            "cell+0x20 = 0xffff7fbc",
            "cell+0x24 = (old & 0xc0000548) | 0x00000548",
            "cell+0x28 = (old & bit24) | bit25 | bit27",
            "cell+0x2c clears bit0",
        ],
        "reason": "This is the source prefill; the bit27 reduction before 0x4a4c8e is caused by later callers of 0x49a932/0x49aa63, not by a different initializer.",
    },
    {
        "address": "0x49a1d8",
        "name": "generated_cell_validity_predicate",
        "status": "recovered_static_ghidra",
        "returns_true_when": ["cell+0x2b has bit 0x02 set", "terrain id (cell+0x24 & 0x3f) is not 9"],
    },
    {
        "address": "0x49a85d",
        "name": "generated_cell_bit27_neighborhood_stamp",
        "status": "recovered_static_ghidra",
        "writes": [
            "calls 0x49a932(true) for the center cell",
            "calls 0x49a932(true) for every cell in clipped [x-1,x+2) by [y-1,y+2) neighborhood on the same level",
        ],
        "coordinate_formula": "cell = grid+0x08 + 0x30 * (((level * grid_height) + y) * grid_width + x)",
    },
    {
        "address": "0x49a932",
        "name": "generated_cell_occupied_bit_writer",
        "status": "recovered_static_ghidra_bounded_runtime_trace_incomplete",
        "writes": ["when cell+0x2c bit0 clear: arg false clears bit27", "arg true sets bit27 then clears bit26"],
        "runtime_trace": "seed58_interactive_49a932_to_4a4c8e_lite hit the 3000-event cap without reaching 0x4a4c8e; the stream revisits cells and is not yet a complete pre-boundary replay.",
    },
    {
        "address": "0x49aa63",
        "name": "generated_cell_decor_candidate_writer",
        "status": "recovered_static_and_seed58_pre_0x4a4c8e_runtime",
        "writes": ["when cell+0x2c bit0 clear: arg false clears bit26", "arg true sets bit26 then clears bit27"],
        "runtime_trace": "seed58_interactive_49aa63_to_4a4c8e shows 490 calls, all arg true, 490 unique generated-cell flats, then 0x4a4c8e. This matches the seed-58 pre-0x4a4c8e bit26 count.",
    },
    {
        "address": "0x49a962",
        "name": "generated_cell_bit26_center_and_bit27_neighborhood_clear",
        "status": "recovered_static_ghidra_seed58_runtime_count",
        "writes": [
            "calls 0x49aa63(true) for the center cell",
            "for the clipped 3x3 neighborhood, calls 0x49a932(false) only when bit22 is clear, 0x49a1d8 is true, and terrain id is not 8",
        ],
        "coordinate_formula": "cell = grid+0x08 + 0x30 * (((level * grid_height) + y) * grid_width + x)",
    },
    {
        "address": "0x49acf6",
        "name": "generated_cell_terrain_art_and_flag_writer",
        "status": "recovered_static_ghidra",
        "writes": [
            "cell+0x24 = (old & 0xffffc000) | (terrain_arg & 0x3f) | ((arg2 & 0xff) << 6)",
            "cell+0x28 = (old & 0xfffe7fff) | (((arg3 & 1) | ((arg4 & 1) << 1)) << 15)",
        ],
        "callers": ["0x49ce64 full-grid loop after 0x49a072 reset", "0x4af463", "0x49acee local/internal path"],
    },
    {
        "address": "0x49abd6",
        "name": "object_mask_stamp_generated_cell_mutator",
        "status": "recovered_partial_runtime_call_contract",
        "writes": ["cell+0x28 bit22", "cell+0x28 bit25", "cell+0x28 bit27 via 0x49a932"],
        "runtime_trace": "seed58 combined traces show five calls before 0x4a8c15, all returning through 0x4a54d6 and followed by 0x49a932/0x49ac70 cell writes.",
    },
    {
        "address": "0x4aa3e9",
        "name": "reward_object_final_commit_and_wrapper_projection",
        "status": "must_recover",
        "writes": ["object vector", "generated cell bit state through 0x49a932/0x49aa63"],
    },
    {
        "address": "0x4a4c8e",
        "name": "land_edge_generated_cell_bit_writer_entry_checkpoint",
        "status": "checkpoint_authority",
        "reads": ["generator+0x14 generated cells", "generator+0x10e4 runtime-zone relation vectors"],
    },
    {
        "address": "0x4a80dc",
        "name": "route_line_cut_point_picker",
        "status": "recovered_static_and_seed58_runtime_pairs",
        "reads": ["grid generated-cell bit27 neighborhoods along a Bresenham-style line"],
        "returns": ["an output coordinate pair written through the caller-provided pointer"],
        "runtime_trace": "seed58_interactive_4a80dc_return_to_4a4c8e records 52 entry/return pairs before 0x4a4c8e.",
    },
    {
        "address": "0x4a8c15",
        "name": "generated_cell_post_terrain_phase_driver",
        "status": "recovered_static_and_seed58_runtime_prefix",
        "calls_in_order": ["0x4a8260", "0x4a4c8e", "per-cell scan calling 0x49a962", "0x4a4913 loop over generator+0x10e4 vector", "0x4a5767", "0x4a4fc5", "0x4a79a3"],
        "runtime_trace": "seed58_interactive_49aa63_to_4a4c8e confirms 0x4a8c15 -> 0x4a8260 -> 490 calls to 0x49aa63 -> 0x4a4c8e for the bit26 writer stream.",
    },
    {
        "address": "0x49b3fb",
        "name": "runtime_zone_relation_lookup",
        "status": "known_helper_must_keep_in_manifest",
    },
]

STRUCTS: list[dict[str, Any]] = [
    {
        "name": "H3MapEdGenerator",
        "status": "must_recover_with_xrefs_and_runtime_dumps",
        "known_fields": {
            "+0x14": "generated_cell_buffer_begin",
            "+0x18": "map_width",
            "+0x1c": "map_height",
            "+0x20": "level_count",
            "+0x10e4": "runtime_zone_relation_vector_table",
            "+0x14b0": "strategic_route_coordinate_vector_begin",
            "+0x14b4": "strategic_route_coordinate_vector_end",
            "+0x14b8": "strategic_route_coordinate_vector_capacity",
        },
    },
    {
        "name": "GeneratedCell",
        "stride_bytes": 0x30,
        "status": "must_match_per_cell_at_checkpoints",
        "known_fields": {
            "+0x20": "owner/score dword consumed by 0x4a4c8e byte2 owner",
            "+0x24": "terrain/art dword consumed by 0x4a4c8e and 0x49b2b6",
            "+0x28": "generated-cell bit-state dword",
            "+0x2c": "cell private flags; bit0 skips 0x49a932/0x49aa63 helpers",
        },
    },
]

CHECKPOINTS: list[dict[str, Any]] = [
    {"id": "after_terrain_live_feedback", "required_words": ["0x20", "0x24", "0x28", "0x2c"]},
    {"id": "after_town_castle", "required_words": ["0x20", "0x24", "0x28", "0x2c"]},
    {"id": "object_vector_entry", "required_words": ["0x20", "0x24", "0x28", "0x2c"]},
    {"id": "after_each_0x49a932_call", "required_words": ["0x28", "0x2c"], "requires_caller": True},
    {"id": "after_each_0x49aa63_call", "required_words": ["0x28", "0x2c"], "requires_caller": True},
    {"id": "after_object_vector_exit", "required_words": ["0x20", "0x24", "0x28", "0x2c"]},
    {"id": "pre_0x4a4c8e", "required_words": ["0x20", "0x24", "0x28", "0x2c"]},
]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def objdump_probe(path: Path, addresses: list[str], context_bytes: int) -> dict[str, Any]:
    result: dict[str, Any] = {"status": "not_run", "functions": {}}
    try:
        completed = subprocess.run(
            ["objdump", "-Mintel", "-D", str(path)],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=90,
        )
    except Exception as exc:
        result["status"] = "failed"
        result["error"] = str(exc)
        return result
    result["status"] = "pass" if completed.returncode == 0 else "objdump_nonzero"
    text = completed.stdout
    lines = text.splitlines()
    for address in addresses:
        needle = address.lower().replace("0x", "").lstrip("0") or "0"
        found_index = -1
        for index, line in enumerate(lines):
            if line.strip().lower().startswith(needle + ":"):
                found_index = index
                break
        if found_index < 0:
            result["functions"][address] = {"status": "missing"}
            continue
        excerpt = lines[found_index : found_index + context_bytes]
        result["functions"][address] = {"status": "found", "disassembly_excerpt": excerpt}
    return result


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--h3maped-exe", type=Path, default=DEFAULT_H3MAPED)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--objdump-context-lines", type=int, default=32)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    exe = args.h3maped_exe.resolve()
    if not exe.exists():
        raise SystemExit(f"missing h3maped.exe: {exe}")
    addresses = [str(record["address"]) for record in FUNCTIONS]
    manifest = {
        "schema_id": "h3maped_rmg_end_to_end_recovery_manifest_v1",
        "h3maped_exe": str(exe),
        "h3maped_sha256": sha256(exe),
        "recovery_policy": "no native behavior edits until trace replay matches H3MapEd private state",
        "functions": FUNCTIONS,
        "structs": STRUCTS,
        "checkpoints": CHECKPOINTS,
        "objdump_probe": objdump_probe(exe, addresses, args.objdump_context_lines),
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_RECOVERY_MANIFEST status=pass functions={len(FUNCTIONS)} out={args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
