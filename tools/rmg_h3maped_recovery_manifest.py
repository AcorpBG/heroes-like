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
        "address": "0x499ea3",
        "name": "generated_cell_initializer_or_prefill_context",
        "status": "must_recover",
        "reason": "native model mass-prefills bit27; H3MapEd pre-0x4a4c8e has far fewer bit27 cells",
    },
    {
        "address": "0x49a932",
        "name": "generated_cell_occupied_bit_writer",
        "status": "known_helper_must_trace_all_callers",
        "writes": ["cell+0x28 bit27", "cell+0x28 bit26 when true arg"],
    },
    {
        "address": "0x49aa63",
        "name": "generated_cell_decor_candidate_writer",
        "status": "known_helper_must_trace_all_callers",
        "writes": ["cell+0x28 bit26"],
    },
    {
        "address": "0x49abd6",
        "name": "object_mask_stamp_generated_cell_mutator",
        "status": "must_recover_call_contract",
        "writes": ["cell+0x28 bit22", "cell+0x28 bit25", "cell+0x28 bit27 via 0x49a932"],
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
