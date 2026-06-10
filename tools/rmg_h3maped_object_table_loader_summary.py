#!/usr/bin/env python3
"""Verify the H3MapEd RMG object table loader surface.

This checkpoint recovers the base objects.txt loader and row-field consumers
used to bucket object wrappers. It does not claim final selected object identity
for every later source-handler lane.
"""

from __future__ import annotations

import argparse
import csv
import json
import struct
from collections import Counter
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_H3MAPED = Path(
    ".artifacts/rmg_20seed_2p_small_h3maped_20260605/"
    "small_2p_seed_58_manual20/runtime/h3maped.exe"
)
DEFAULT_DUMP_DIR = ROOT / "ghidra_object_table_loader_dump_20260610"
DEFAULT_CATALOG = Path(
    "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/"
    "object-catalog-by-type.csv"
)
DEFAULT_OBJNAMES = Path(
    "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-lod-extract/"
    "output/h3bitmap/raw/objnames.txt"
)
DEFAULT_OUT = ROOT / "object_table_loader_summary_20260610.json"

STRING_VAS = {
    "objects_txt": (0x58D27C, "objects.txt"),
    "rand_trn_txt": (0x58E43C, "rand_trn.txt"),
    "objtmplt_txt": (0x583A6C, "objtmplt.txt"),
    "objnames_txt": (0x57C6D4, "objnames.txt"),
}

LOADER_CHECKS = [
    {"id": "loads_objects_txt", "marker": "0049da1a: PUSH 0x58d27c"},
    {"id": "parses_objects_table", "marker": "0049da22: CALL 0x00490c4c"},
    {"id": "uses_0x4c_row_stride", "marker": "0049da3a: PUSH 0x4c"},
    {"id": "reads_row_type_id_at_1c", "marker": "0049da54: MOV EDI,dword ptr [EBX + EAX*0x1 + 0x1c]"},
    {"id": "type_guard_0xde", "marker": "0049da5a: CMP EDI,0xde"},
    {"id": "type_guard_0xa5", "marker": "0049da67: CMP EDI,0xa5"},
    {"id": "special_type_0x2d", "marker": "0049da74: CMP EDI,0x2d"},
    {"id": "special_type_0x2b", "marker": "0049da79: CMP EDI,0x2b"},
    {"id": "special_type_0x2c", "marker": "0049da7e: CMP EDI,0x2c"},
    {"id": "reads_row_subtype_at_20", "marker": "0049da83: CMP dword ptr [EBX + EAX*0x1 + 0x20],0x3"},
    {"id": "type_bound_0xe8", "marker": "0049da8e: MOV EAX,0xe8"},
    {"id": "compares_type_to_bound", "marker": "0049da93: CMP EDI,EAX"},
    {"id": "allocates_wrapper", "marker": "0049da98: CALL 0x005044b1"},
    {"id": "initializes_wrapper", "marker": "0049dab2: CALL 0x0049db76"},
    {"id": "reads_object_metadata_table", "marker": "0049dabe: MOV EAX,[0x0057c648]"},
    {"id": "reads_metadata_bucket_index", "marker": "0049daca: MOV EAX,dword ptr [EDI + EAX*0x1 + 0x8]"},
    {"id": "appends_wrapper_to_bucket", "marker": "0049dad5: CALL 0x0040bb26"},
    {"id": "advances_next_source_row", "marker": "0049dadd: ADD EBX,0x4c"},
    {"id": "loads_rand_trn_after_objects", "marker": "0049db4c: CALL 0x0049dc9e"},
]

RAND_TRN_CHECKS = [
    {"id": "loads_rand_trn_txt", "marker": "0049dcb7: PUSH 0x58e43c"},
    {"id": "calls_rand_trn_parser", "marker": "0049dcbf: CALL 0x004dccc0"},
    {"id": "uses_type_bound_0xe8", "marker": "0049e0dd: CMP dword ptr [EBP + -0x24],0xe8"},
]

OWNER_CHECKS = [
    {"id": "owner_calls_object_loader", "marker": "0049d9d5: CALL 0x0049da08"},
]

PARSER_CHECKS = [
    {"id": "parser_uses_0x4c_stride", "marker": "00490cd3: IMUL ESI,ESI,0x4c"},
]

REFERENCE_CHECKS = [
    {
        "id": "parser_called_from_object_loader",
        "marker": "from=0049da22 type=UNCONDITIONAL_CALL caller=FUN_0049da08",
    },
    {
        "id": "loader_called_from_owner",
        "marker": "from=0049d9d5 type=UNCONDITIONAL_CALL caller=FUN_0049d914",
    },
]


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""


def check_markers(path: Path, checks: list[dict[str, str]]) -> list[dict[str, Any]]:
    text = read_text(path)
    return [{**check, "present": check["marker"] in text} for check in checks]


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


def read_c_string(binary: bytes, offset: int) -> str:
    end = binary.find(b"\0", offset)
    if end == -1:
        raise ValueError(f"unterminated string at file offset 0x{offset:x}")
    return binary[offset:end].decode("ascii", errors="replace")


def verify_binary_strings(h3maped: Path) -> dict[str, Any]:
    binary = h3maped.read_bytes()
    image_base, sections = pe_sections(binary)
    strings: dict[str, Any] = {}
    for key, (va, expected) in STRING_VAS.items():
        offset = va_to_offset(va, image_base, sections)
        actual = read_c_string(binary, offset)
        strings[key] = {
            "va": f"0x{va:08x}",
            "file_offset": f"0x{offset:08x}",
            "expected": expected,
            "actual": actual,
            "matches": actual == expected,
        }
    return {
        "path": str(h3maped),
        "image_base": f"0x{image_base:08x}",
        "strings": strings,
        "all_strings_match": all(item["matches"] for item in strings.values()),
    }


def summarize_catalog(catalog: Path, objnames: Path) -> dict[str, Any]:
    rows: list[dict[str, str]] = []
    with catalog.open("r", encoding="utf-8", newline="") as handle:
        rows = list(csv.DictReader(handle))
    source_counts = Counter(row["source"] for row in rows)
    type_ids = [int(row["type_id"]) for row in rows if row.get("type_id")]
    subtypes = [int(row["subtype"]) for row in rows if row.get("subtype")]
    type_names = sorted({(int(row["type_id"]), row["type_name"]) for row in rows if row.get("type_id")})
    objname_lines = objnames.read_text(encoding="utf-8", errors="replace").splitlines()
    sample_rows = [
        {
            "source": row["source"],
            "source_row": int(row["source_row"]),
            "def_name": row["def_name"],
            "type_id": int(row["type_id"]),
            "type_name": row["type_name"],
            "subtype": int(row["subtype"]),
            "group": int(row["group"]),
            "pass_count": int(row["pass_count"]),
            "action_count": int(row["action_count"]),
        }
        for row in rows[:5]
    ]
    return {
        "path": str(catalog),
        "objnames_path": str(objnames),
        "row_count": len(rows),
        "source_counts": dict(sorted(source_counts.items())),
        "min_type_id": min(type_ids),
        "max_type_id": max(type_ids),
        "distinct_type_count": len({type_id for type_id in type_ids}),
        "distinct_type_name_count": len(type_names),
        "objnames_line_count": len(objname_lines),
        "min_subtype": min(subtypes),
        "max_subtype": max(subtypes),
        "expected_rows_match": len(rows) == 1328
        and source_counts.get("objects.txt") == 1326
        and source_counts.get("objtmplt.txt") == 2,
        "type_bound_matches_loader": max(type_ids) < 0xE8 and len(objname_lines) == 0xE8,
        "sample_rows": sample_rows,
    }


def summarize(h3maped: Path, dump_dir: Path, catalog: Path, objnames: Path) -> dict[str, Any]:
    loader_checks = check_markers(dump_dir / "target_0049da08_FUN_0049da08.txt", LOADER_CHECKS)
    rand_trn_checks = check_markers(dump_dir / "target_0049dc9e_FUN_0049dc9e.txt", RAND_TRN_CHECKS)
    owner_checks = check_markers(dump_dir / "target_0049d914_FUN_0049d914.txt", OWNER_CHECKS)
    parser_checks = check_markers(dump_dir / "target_00490c4c_FUN_00490c4c.txt", PARSER_CHECKS)
    reference_checks = (
        check_markers(dump_dir / "target_00490c4c_references.txt", [REFERENCE_CHECKS[0]])
        + check_markers(dump_dir / "target_0049da08_references.txt", [REFERENCE_CHECKS[1]])
    )

    binary_strings = verify_binary_strings(h3maped)
    catalog_summary = summarize_catalog(catalog, objnames)

    all_marker_checks = loader_checks + rand_trn_checks + owner_checks + parser_checks + reference_checks
    missing_markers = [check["id"] for check in all_marker_checks if not check["present"]]
    recovered = (
        not missing_markers
        and binary_strings["all_strings_match"]
        and catalog_summary["expected_rows_match"]
        and catalog_summary["type_bound_matches_loader"]
    )
    return {
        "schema_id": "h3maped_rmg_object_table_loader_summary_v1",
        "status": (
            "object_table_loader_recovered_catalog_row_identity_surface"
            if recovered
            else "object_table_loader_surface_incomplete"
        ),
        "scope": (
            "Base H3MapEd object catalog loader surface. This recovers how objects.txt rows "
            "are parsed, type/subtype fields are consumed, wrappers are bucketed, and rand_trn "
            "is loaded separately. It does not recover every later source-handler selected "
            "object identity or nested payload variant."
        ),
        "inputs": {
            "h3maped": str(h3maped),
            "ghidra_dump_dir": str(dump_dir),
            "catalog_csv": str(catalog),
            "objnames_txt": str(objnames),
        },
        "binary_string_checks": binary_strings,
        "catalog_summary": catalog_summary,
        "marker_count": len(all_marker_checks),
        "present_marker_count": sum(1 for check in all_marker_checks if check["present"]),
        "missing_marker_ids": missing_markers,
        "loader_checks": loader_checks,
        "rand_trn_checks": rand_trn_checks,
        "owner_checks": owner_checks,
        "parser_checks": parser_checks,
        "reference_checks": reference_checks,
        "recovered_boundary": {
            "0x49da08": (
                "Loads objects.txt through the generic 0x490c4c table parser, walks parsed "
                "0x4c rows, reads row +0x1c as object type id, uses row +0x20 as subtype in "
                "special type guards, bounds type ids by 0xe8, allocates and initializes "
                "0xe8-byte wrappers through 0x49db76, looks up object metadata through "
                "0x57c648[type].+0x08, appends wrappers to the selected bucket, advances by "
                "0x4c per row, then loads rand_trn.txt through 0x49dc9e."
            ),
            "0x490c4c": "Generic table parser used by 0x49da08; recovered marker confirms 0x4c row stride.",
            "0x49dc9e": (
                "Separate rand_trn.txt loader. It shares object-type bounds but is a terrain/"
                "decorative preference surface, not the base object catalog producer."
            ),
            "catalog_artifact": (
                "Existing extracted catalog has 1326 objects.txt rows plus 2 objtmplt.txt rows, "
                "with type ids below the 0xe8 object-name bound verified against objnames.txt."
            ),
        },
        "field_mapping": {
            "objects_txt_row_stride": "0x4c",
            "row_plus_0x1c": "object type id consumed by 0x49da08 and bounded by 0xe8",
            "row_plus_0x20": "subtype-like field used by special type guards and matching extracted catalog subtype",
            "wrapper_plus_0x00": "backing copied 0x4c source row pointer, initialized by 0x49db76 per descriptor-source checkpoint",
            "metadata_0x57c648_type_plus_0x08": "bucket index used to choose wrapper bucket",
        },
        "remaining_unrecovered": [
            "Live selected wrapper/source evidence for mixed descriptor lanes 45, 53, 54, and 79.",
            "Nested source-handler payload variants that pick among object catalog rows after the base table is loaded.",
            "Natural successful endpoint-stamping path or source-backed exclusion for one-level land.",
            "Human category/provider-slot names for later variant and filter builders.",
        ],
        "native_behavior_changed": False,
        "used_objdump": False,
        "overall_goal_complete": False,
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--h3maped", type=Path, default=DEFAULT_H3MAPED)
    parser.add_argument("--dump-dir", type=Path, default=DEFAULT_DUMP_DIR)
    parser.add_argument("--catalog", type=Path, default=DEFAULT_CATALOG)
    parser.add_argument("--objnames", type=Path, default=DEFAULT_OBJNAMES)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args.h3maped, args.dump_dir, args.catalog, args.objnames)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_OBJECT_TABLE_LOADER "
        f"status={summary['status']} "
        f"markers={summary['present_marker_count']}/{summary['marker_count']} "
        f"rows={summary['catalog_summary']['row_count']} "
        f"out={args.out}"
    )
    return (
        0
        if summary["status"] == "object_table_loader_recovered_catalog_row_identity_surface"
        else 1
    )


if __name__ == "__main__":
    raise SystemExit(main())
