#!/usr/bin/env python3
"""Recover the H3MapEd hero catalog runtime-table boundary.

This is a recovery checkpoint only. It proves that the 0x5857d4/0x5857d8/
0x5857dc globals reached while chasing the source-catalog dynamic lookup are
hero-domain runtime tables populated from heroes.txt and HeroBios.txt.

The important boundary is negative: these tables are not the generic
objects.txt/objtmplt.txt template mapping needed to port native RMG object
identity end-to-end.
"""

from __future__ import annotations

import argparse
import json
import struct
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_H3MAPED = Path(
    ".artifacts/rmg_20seed_2p_small_h3maped_20260605/"
    "small_2p_seed_58_manual20/runtime/h3maped.exe"
)
DEFAULT_RUNTIME_DUMP_DIR = ROOT / "ghidra_source_catalog_runtime_table_targets_dump_20260610"
DEFAULT_HERO_DUMP_DIR = ROOT / "ghidra_hero_catalog_helper_dump_20260610"
DEFAULT_DELEGATE_DUMP_DIR = ROOT / "ghidra_source_catalog_delegate_dump_20260610"
DEFAULT_OUT = ROOT / "hero_catalog_runtime_table_summary_20260610.json"

GLOBAL_POINTERS = {
    "hero_instance_table_global": (0x5857D4, 0x59E6A0),
    "hero_group_table_global": (0x5857D8, 0x59F060),
    "hero_bios_pointer_table_global": (0x5857DC, 0x59F274),
}

FILE_STRINGS = {
    "hero_bios_txt": (0x5857E0, "HeroBios.txt"),
    "heroes_txt": (0x5857F0, "heroes.txt"),
}

TYPE_DESCRIPTOR_STRINGS = {
    "TGameObject": (0x57C8C8, ".?AVTGameObject@@"),
    "THero": (0x582138, ".?AVTHero@@"),
    "TRandomHero": (0x583810, ".?AVTRandomHero@@"),
    "TNonRandomHero": (0x583B58, ".?AVTNonRandomHero@@"),
}

HERO_TABLE_CONSTRUCTOR_CHECKS = [
    {"id": "constructs_hero_instance_entries_count", "marker": "0044a081: PUSH 0x9c"},
    {"id": "constructs_hero_instance_entry_stride", "marker": "0044a086: PUSH 0x10"},
    {"id": "constructs_hero_instance_table_base", "marker": "0044a088: PUSH 0x59e6a0"},
    {"id": "constructs_hero_instance_table_call", "marker": "0044a08d: CALL 0x004e5c75"},
]

HERO_GROUP_INIT_CHECKS = [
    {"id": "first_group_slot_base", "marker": "0044a0dd: MOV ECX,0x59f060"},
    {"id": "group_slot_initializer_call_first", "marker": "0044a0e8: CALL 0x0044a882"},
    {"id": "last_group_slot_base", "marker": "0044a27e: MOV ECX,0x59f258"},
    {"id": "group_slot_initializer_call_last", "marker": "0044a284: CALL 0x0044a882"},
]

HERO_GROUP_HELPER_CHECKS = [
    {"id": "slot_helper_takes_source_arg", "marker": "0044a885: MOV EAX,dword ptr [EBP + 0x8]"},
    {"id": "slot_helper_clears_flags", "marker": "0044a88b: AND dword ptr [ESI + 0x8],0x0"},
    {"id": "slot_helper_writes_source_pointer", "marker": "0044a88f: MOV dword ptr [ESI],EAX"},
    {"id": "slot_helper_writes_class_key", "marker": "0044a897: MOV dword ptr [ESI + 0x4],EAX"},
    {"id": "slot_helper_writes_key_byte_a", "marker": "0044a8a1: MOV byte ptr [ECX],AL"},
    {"id": "slot_helper_writes_key_byte_b", "marker": "0044a8a6: MOV byte ptr [ECX + 0x1],AL"},
]

HERO_LOADER_CHECKS = [
    {"id": "loads_heroes_txt", "marker": "0044a8c5: PUSH 0x5857f0"},
    {"id": "parses_heroes_txt_table", "marker": "0044a8cf: CALL 0x00490c4c"},
    {"id": "fills_group_table_start", "marker": "0044a8d9: MOV ECX,0x59f068"},
    {"id": "copies_group_source_pointer", "marker": "0044a8e6: MOV dword ptr [ECX],EDX"},
    {"id": "advances_group_table_stride", "marker": "0044a8e8: ADD ECX,0x1c"},
    {"id": "stops_group_table_end", "marker": "0044a8eb: CMP ECX,0x59f260"},
    {"id": "loads_hero_bios_txt", "marker": "0044a8f9: PUSH 0x5857e0"},
    {"id": "opens_hero_bios_table", "marker": "0044a905: CALL 0x004dca60"},
    {"id": "indexes_hero_instance_table", "marker": "0044a950: ADD EDI,0x59e6a0"},
    {"id": "writes_hero_instance_record_pointer", "marker": "0044a95c: MOV dword ptr [EDI + 0x4],EAX"},
]

HERO_BIOS_TABLE_CHECKS = [
    {"id": "runs_hero_catalog_loader", "marker": "0044af11: CALL 0x0044a8b5"},
    {"id": "runs_bios_post_parser", "marker": "0044af16: CALL 0x00494c27"},
    {"id": "fills_bios_pointer_table_start", "marker": "0044af20: MOV ECX,0x59f274"},
    {"id": "writes_bios_pointer", "marker": "0044af2a: MOV dword ptr [ECX],EDX"},
    {"id": "advances_bios_pointer_table", "marker": "0044af2c: ADD ECX,0x4"},
    {"id": "stops_bios_pointer_table_end", "marker": "0044af2f: CMP ECX,0x59f2e4"},
]

DYNAMIC_DELEGATE_CHECKS = [
    {
        "file": "target_004389a7_FUN_004389a7.txt",
        "checks": [
            {"id": "random_hero_dynamic_type", "marker": "004389ad: PUSH 0x583810"},
            {"id": "random_hero_base_type", "marker": "004389b2: PUSH 0x57c8c8"},
            {"id": "random_hero_dynamic_lookup", "marker": "004389be: CALL 0x004e6da2"},
            {"id": "random_hero_existing_delegate", "marker": "004389d3: CALL 0x00428439"},
            {"id": "random_hero_missing_delegate", "marker": "004389e7: CALL 0x0043920d"},
        ],
    },
    {
        "file": "caller_0043920d_FUN_0043920d.txt",
        "checks": [
            {"id": "nonrandom_hero_dynamic_type", "marker": "00439213: PUSH 0x583b58"},
            {"id": "nonrandom_hero_base_type", "marker": "00439218: PUSH 0x57c8c8"},
            {"id": "nonrandom_hero_dynamic_lookup", "marker": "00439224: CALL 0x004e6da2"},
            {"id": "nonrandom_hero_existing_delegate", "marker": "00439239: CALL 0x004284d0"},
            {"id": "nonrandom_hero_missing_delegate", "marker": "0043924d: CALL 0x0043976f"},
        ],
    },
    {
        "file": "target_004c242d_FUN_004c242d.txt",
        "checks": [
            {"id": "dynamic_payload_reads_hero_cache", "marker": "004c2440: MOV EAX,dword ptr [ESI + 0xb4]"},
            {"id": "dynamic_payload_hero_type", "marker": "004c249f: PUSH 0x582138"},
            {"id": "dynamic_payload_game_object_type", "marker": "004c24a4: PUSH 0x57c8c8"},
            {"id": "dynamic_payload_writes_hero_cache_a", "marker": "004c24bf: MOV dword ptr [ESI + 0xb4],EAX"},
            {"id": "dynamic_payload_writes_hero_cache_b", "marker": "004c24cc: MOV dword ptr [ESI + 0xb4],EBX"},
        ],
    },
]


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""


def check_markers(path: Path, checks: list[dict[str, str]]) -> list[dict[str, Any]]:
    text = read_text(path)
    return [{**check, "path": str(path), "present": check["marker"] in text} for check in checks]


def pe_sections(binary: bytes) -> tuple[int, list[dict[str, int]]]:
    if binary[:2] != b"MZ":
        raise ValueError("not a PE executable")
    pe_offset = struct.unpack_from("<I", binary, 0x3C)[0]
    if binary[pe_offset : pe_offset + 4] != b"PE\0\0":
        raise ValueError("missing PE signature")
    coff = pe_offset + 4
    section_count = struct.unpack_from("<H", binary, coff + 2)[0]
    optional_size = struct.unpack_from("<H", binary, coff + 16)[0]
    optional = coff + 20
    magic = struct.unpack_from("<H", binary, optional)[0]
    if magic != 0x10B:
        raise ValueError(f"unsupported PE magic 0x{magic:x}")
    image_base = struct.unpack_from("<I", binary, optional + 28)[0]
    section_offset = optional + optional_size
    sections: list[dict[str, int]] = []
    for index in range(section_count):
        base = section_offset + index * 40
        virtual_size, virtual_address, raw_size, raw_pointer = struct.unpack_from("<IIII", binary, base + 8)
        sections.append(
            {
                "virtual_address": virtual_address,
                "virtual_size": virtual_size,
                "raw_size": raw_size,
                "raw_pointer": raw_pointer,
            }
        )
    return image_base, sections


def va_to_offset(va: int, image_base: int, sections: list[dict[str, int]]) -> int:
    rva = va - image_base
    for section in sections:
        start = section["virtual_address"]
        size = max(section["virtual_size"], section["raw_size"])
        if start <= rva < start + size:
            return section["raw_pointer"] + (rva - start)
    raise ValueError(f"VA 0x{va:08x} does not map to a PE section")


def read_u32(binary: bytes, offset: int) -> int:
    return struct.unpack_from("<I", binary, offset)[0]


def read_c_string(binary: bytes, offset: int) -> str:
    end = binary.find(b"\0", offset)
    if end == -1:
        raise ValueError(f"unterminated string at file offset 0x{offset:x}")
    return binary[offset:end].decode("ascii", errors="replace")


def verify_binary(h3maped: Path) -> dict[str, Any]:
    binary = h3maped.read_bytes()
    image_base, sections = pe_sections(binary)

    pointers: dict[str, Any] = {}
    for key, (va, expected) in GLOBAL_POINTERS.items():
        offset = va_to_offset(va, image_base, sections)
        actual = read_u32(binary, offset)
        pointers[key] = {
            "va": f"0x{va:08x}",
            "file_offset": f"0x{offset:08x}",
            "expected": f"0x{expected:08x}",
            "actual": f"0x{actual:08x}",
            "matches": actual == expected,
        }

    file_strings: dict[str, Any] = {}
    for key, (va, expected) in FILE_STRINGS.items():
        offset = va_to_offset(va, image_base, sections)
        actual = read_c_string(binary, offset)
        file_strings[key] = {
            "va": f"0x{va:08x}",
            "file_offset": f"0x{offset:08x}",
            "expected": expected,
            "actual": actual,
            "matches": actual == expected,
        }

    type_descriptors: dict[str, Any] = {}
    for key, (va, expected) in TYPE_DESCRIPTOR_STRINGS.items():
        offset = va_to_offset(va, image_base, sections)
        actual = read_c_string(binary, offset + 8)
        type_descriptors[key] = {
            "va": f"0x{va:08x}",
            "file_offset": f"0x{offset:08x}",
            "expected": expected,
            "actual": actual,
            "matches": actual == expected,
        }

    return {
        "path": str(h3maped),
        "image_base": f"0x{image_base:08x}",
        "global_pointers": pointers,
        "file_strings": file_strings,
        "type_descriptors": type_descriptors,
        "all_pointers_match": all(item["matches"] for item in pointers.values()),
        "all_file_strings_match": all(item["matches"] for item in file_strings.values()),
        "all_type_descriptors_match": all(item["matches"] for item in type_descriptors.values()),
    }


def marker_groups(runtime_dump_dir: Path, hero_dump_dir: Path, delegate_dump_dir: Path) -> dict[str, Any]:
    groups: dict[str, Any] = {
        "hero_table_constructor": check_markers(
            runtime_dump_dir / "caller_0044a077_FUN_0044a077.txt", HERO_TABLE_CONSTRUCTOR_CHECKS
        ),
        "hero_group_init": check_markers(
            hero_dump_dir / "caller_0044a0db_FUN_0044a0db.txt", HERO_GROUP_INIT_CHECKS
        ),
        "hero_group_slot_helper": check_markers(
            hero_dump_dir / "target_0044a882_FUN_0044a882.txt", HERO_GROUP_HELPER_CHECKS
        ),
        "hero_catalog_loader": check_markers(
            hero_dump_dir / "caller_0044a8b5_FUN_0044a8b5.txt", HERO_LOADER_CHECKS
        ),
        "hero_bios_pointer_table": check_markers(
            runtime_dump_dir / "caller_0044af11_FUN_0044af11.txt", HERO_BIOS_TABLE_CHECKS
        ),
    }
    groups["dynamic_lookup_hero_domain"] = []
    for group in DYNAMIC_DELEGATE_CHECKS:
        groups["dynamic_lookup_hero_domain"].extend(
            check_markers(delegate_dump_dir / group["file"], group["checks"])
        )
    return groups


def marker_counts(groups: dict[str, list[dict[str, Any]]]) -> dict[str, int]:
    checks = [check for checks in groups.values() for check in checks]
    present = [check for check in checks if check["present"]]
    return {
        "marker_count": len(checks),
        "present_marker_count": len(present),
        "missing_marker_count": len(checks) - len(present),
    }


def summarize(
    h3maped: Path,
    runtime_dump_dir: Path,
    hero_dump_dir: Path,
    delegate_dump_dir: Path,
) -> dict[str, Any]:
    binary = verify_binary(h3maped)
    groups = marker_groups(runtime_dump_dir, hero_dump_dir, delegate_dump_dir)
    counts = marker_counts(groups)

    hero_instance_count = 0x9C
    hero_instance_stride = 0x10
    hero_group_first = 0x59F060
    hero_group_loader_first = 0x59F068
    hero_group_end = 0x59F260
    hero_group_stride = 0x1C
    hero_group_initializer_count = ((0x59F258 - hero_group_first) // hero_group_stride) + 1
    hero_group_loader_copy_count = (hero_group_end - hero_group_loader_first) // hero_group_stride
    hero_bios_first = 0x59F274
    hero_bios_end = 0x59F2E4
    hero_bios_pointer_count = (hero_bios_end - hero_bios_first) // 4

    invariants = {
        "global_0x5857d4_points_to_hero_instance_table": binary["global_pointers"][
            "hero_instance_table_global"
        ]["matches"],
        "global_0x5857d8_points_to_hero_group_table": binary["global_pointers"][
            "hero_group_table_global"
        ]["matches"],
        "global_0x5857dc_points_to_hero_bios_pointer_table": binary["global_pointers"][
            "hero_bios_pointer_table_global"
        ]["matches"],
        "heroes_txt_literal_verified": binary["file_strings"]["heroes_txt"]["matches"],
        "hero_bios_txt_literal_verified": binary["file_strings"]["hero_bios_txt"]["matches"],
        "hero_type_descriptors_verified": binary["all_type_descriptors_match"],
        "hero_instance_table_constructor_verified": all(
            check["present"] for check in groups["hero_table_constructor"]
        ),
        "hero_group_table_initializer_verified": all(check["present"] for check in groups["hero_group_init"]),
        "hero_group_slot_helper_verified": all(check["present"] for check in groups["hero_group_slot_helper"]),
        "hero_catalog_loader_verified": all(check["present"] for check in groups["hero_catalog_loader"]),
        "hero_bios_pointer_table_loader_verified": all(
            check["present"] for check in groups["hero_bios_pointer_table"]
        ),
        "dynamic_lookup_branch_is_hero_domain": all(
            check["present"] for check in groups["dynamic_lookup_hero_domain"]
        ),
        "native_behavior_unchanged": True,
        "no_objdump_used": True,
    }
    complete = all(invariants.values())

    return {
        "schema_id": "h3maped_hero_catalog_runtime_table_summary_v1",
        "status": (
            "hero_catalog_runtime_tables_recovered_object_template_mapping_still_pending"
            if complete
            else "hero_catalog_runtime_tables_incomplete"
        ),
        "scope": (
            "Source-backed domain label for 0x5857d4/0x5857d8/0x5857dc and the "
            "dynamic lookup branch that reaches TRandomHero/TNonRandomHero. This is a "
            "hero catalog boundary, not native RMG object-template identity."
        ),
        "inputs": {
            "h3maped_exe": str(h3maped),
            "runtime_dump_dir": str(runtime_dump_dir),
            "hero_dump_dir": str(hero_dump_dir),
            "delegate_dump_dir": str(delegate_dump_dir),
        },
        "binary_evidence": binary,
        "recovered_tables": {
            "0x5857d4": {
                "points_to": "0x59e6a0",
                "domain_label": "hero_instance_runtime_table",
                "entry_count": hero_instance_count,
                "entry_stride_bytes": hero_instance_stride,
                "constructor": "0x44a077",
                "loader": "0x44a8b5",
                "source_file": "heroes.txt",
            },
            "0x5857d8": {
                "points_to": "0x59f060",
                "domain_label": "hero_group_runtime_table",
                "initializer_entry_count": hero_group_initializer_count,
                "loader_copy_entry_count": hero_group_loader_copy_count,
                "entry_stride_bytes": hero_group_stride,
                "slot_initializer": "0x44a882",
                "initializer": "0x44a0db",
                "loader": "0x44a8b5",
                "source_file": "heroes.txt",
            },
            "0x5857dc": {
                "points_to": "0x59f274",
                "domain_label": "hero_bios_pointer_table",
                "entry_count": hero_bios_pointer_count,
                "entry_stride_bytes": 4,
                "loader": "0x44af11",
                "source_file": "HeroBios.txt",
            },
        },
        "dynamic_lookup_boundary": {
            "0x4389a7": (
                "TRandomHero dynamic lookup under TGameObject; delegates to existing "
                "0x428439 or missing-path 0x43920d."
            ),
            "0x43920d": (
                "TNonRandomHero dynamic lookup under TGameObject; delegates to existing "
                "0x4284d0 or missing-path 0x43976f."
            ),
            "0x4c242d": (
                "THero/TGameObject dynamic payload cache at +0xb4. This confirms the "
                "branch is hero-domain cache/adoption, not generic object template identity."
            ),
            "not_object_template_mapping": (
                "The branch names hero class RTTI and hero text tables. It must not be "
                "used as the objects.txt/objtmplt.txt type/subtype/DEF producer mapping."
            ),
        },
        "marker_groups": groups,
        "invariants": invariants,
        "remaining_blockers": [
            {
                "id": "source_catalog_template_producer_mapping",
                "reason": (
                    "Recover the non-hero producer that maps parsed source-input fields, "
                    "populated 0x4c source records, and nested source payload holders into "
                    "exact objects.txt/objtmplt.txt type/subtype/DEF rows."
                ),
            },
        ],
        "metrics": {
            **counts,
            "hero_instance_table_entry_count": hero_instance_count,
            "hero_instance_table_stride_bytes": hero_instance_stride,
            "hero_group_table_initializer_entry_count": hero_group_initializer_count,
            "hero_group_table_loader_copy_entry_count": hero_group_loader_copy_count,
            "hero_group_table_stride_bytes": hero_group_stride,
            "hero_bios_pointer_table_entry_count": hero_bios_pointer_count,
            "used_objdump": False,
            "native_behavior_changed": False,
            "overall_goal_complete": False,
        },
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--h3maped-exe", type=Path, default=DEFAULT_H3MAPED)
    parser.add_argument("--runtime-dump-dir", type=Path, default=DEFAULT_RUNTIME_DUMP_DIR)
    parser.add_argument("--hero-dump-dir", type=Path, default=DEFAULT_HERO_DUMP_DIR)
    parser.add_argument("--delegate-dump-dir", type=Path, default=DEFAULT_DELEGATE_DUMP_DIR)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args.h3maped_exe, args.runtime_dump_dir, args.hero_dump_dir, args.delegate_dump_dir)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    metrics = summary["metrics"]
    print(
        "RMG_H3MAPED_HERO_CATALOG_RUNTIME_TABLE "
        f"status={summary['status']} "
        f"markers={metrics['present_marker_count']}/{metrics['marker_count']} "
        f"hero_instances={metrics['hero_instance_table_entry_count']} "
        f"hero_groups={metrics['hero_group_table_initializer_entry_count']} "
        f"out={args.out}"
    )
    return (
        0
        if summary["status"] == "hero_catalog_runtime_tables_recovered_object_template_mapping_still_pending"
        else 1
    )


if __name__ == "__main__":
    raise SystemExit(main())
