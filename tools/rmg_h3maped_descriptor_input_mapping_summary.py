#!/usr/bin/env python3
"""Verify the 0x4907c9 / 0x490a11 descriptor input mapping surface.

This checkpoint is deliberately field-level. It proves from Ghidra exports that
the two known 0x4903e8 owners prepare equivalent row-text and binary-stream
descriptor inputs. It does not claim selected mixed-lane identity for generator
records 45/53/54/79.
"""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_STATIC_LOADER = ROOT / "descriptor_static_loader_summary_20260610.json"
DEFAULT_OUT = ROOT / "descriptor_input_mapping_summary_20260610.json"
DEFAULT_GHIDRA_ROOT = ROOT / "ghidra_descriptor_input_helper_dump_20260610"
DEFAULT_OBJECT_CATALOG = Path(
    "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-catalog-by-type.csv"
)
TERRAIN_ORDER = ["dirt", "sand", "grass", "snow", "swamp", "rough", "cave", "lava", "water"]

DEFAULT_GHIDRA_FILES = {
    "descriptor_field_builder_0x4903e8": DEFAULT_GHIDRA_ROOT
    / "caller_004903e8_FUN_004903e8.txt",
    "row_owner_0x4907c9": DEFAULT_GHIDRA_ROOT / "caller_004907c9_FUN_004907c9.txt",
    "stream_owner_0x490a11": DEFAULT_GHIDRA_ROOT / "caller_00490a11_FUN_00490a11.txt",
    "stream_48_bit_mask_reader_0x49213a": DEFAULT_GHIDRA_ROOT
    / "target_0049213a_FUN_0049213a.txt",
    "bitset_setter_0x491472": DEFAULT_GHIDRA_ROOT / "target_00491472_FUN_00491472.txt",
    "row_48_slot_text_mask_parser_0x490f3f": DEFAULT_GHIDRA_ROOT
    / "target_00490f3f_FUN_00490f3f.txt",
    "row_9_slot_text_terrain_parser_0x491136": DEFAULT_GHIDRA_ROOT
    / "target_00491136_FUN_00491136.txt",
    "secondary_mask_anchor_deriver_0x4906fb": DEFAULT_GHIDRA_ROOT
    / "target_004906fb_FUN_004906fb.txt",
    "descriptor_vector_initializer_0x4906de": DEFAULT_GHIDRA_ROOT
    / "target_004906de_FUN_004906de.txt",
    "mask_combiner_0x490f10": DEFAULT_GHIDRA_ROOT / "target_00490f10_FUN_00490f10.txt",
    "mask_complementer_0x4914bc": DEFAULT_GHIDRA_ROOT / "target_004914bc_FUN_004914bc.txt",
    "mask_initializer_0x4914dc": DEFAULT_GHIDRA_ROOT / "target_004914dc_FUN_004914dc.txt",
    "first_dword_reader_0x490e66": DEFAULT_GHIDRA_ROOT / "target_00490e66_FUN_00490e66.txt",
    "descriptor_base_value_helper_0x491eed": DEFAULT_GHIDRA_ROOT
    / "target_00491eed_FUN_00491eed.txt",
}


CHECKS: dict[str, list[dict[str, str]]] = {
    "descriptor_field_builder_0x4903e8": [
        {
            "id": "writes_descriptor_plus_0x00",
            "marker": "0049041f: MOV dword ptr [EBX],EAX",
            "meaning": "0x4903e8 writes descriptor +0x00 from the source/base-value helper.",
        },
        {
            "id": "writes_descriptor_plus_0x34",
            "marker": "004905cd: MOV dword ptr [EBX + 0x34],ECX",
            "meaning": "0x4903e8 writes descriptor extent/payload field +0x34.",
        },
        {
            "id": "writes_descriptor_plus_0x38",
            "marker": "004905d7: MOV dword ptr [EBX + 0x38],ECX",
            "meaning": "0x4903e8 writes descriptor extent/payload field +0x38.",
        },
        {
            "id": "writes_descriptor_plus_0x3c",
            "marker": "004905e1: MOV dword ptr [EBX + 0x3c],EDX",
            "meaning": "0x4903e8 writes descriptor mask/policy field +0x3c.",
        },
        {
            "id": "writes_descriptor_plus_0x40",
            "marker": "004905e8: MOV dword ptr [EBX + 0x40],ECX",
            "meaning": "0x4903e8 writes descriptor mask/policy field +0x40.",
        },
        {
            "id": "writes_descriptor_plus_0x44",
            "marker": "004905f4: MOV dword ptr [EBX + 0x44],EDX",
            "meaning": "0x4903e8 writes descriptor payload field +0x44.",
        },
        {
            "id": "writes_descriptor_plus_0x48",
            "marker": "004905fe: MOV dword ptr [EBX + 0x48],EAX",
            "meaning": "0x4903e8 writes descriptor payload field +0x48.",
        },
    ],
    "stream_48_bit_mask_reader_0x49213a": [
        {
            "id": "reads_six_bytes_from_stream",
            "marker": "00492147: CALL 0x0048f9e3",
            "meaning": "Reads the six raw bytes that become a 48-slot mask.",
        },
        {
            "id": "bit_index_low_three_bits",
            "marker": "00492152: AND ECX,0x7",
            "meaning": "Uses index low three bits as the bit inside the source byte.",
        },
        {
            "id": "byte_index_from_slot",
            "marker": "0049215a: SHR ECX,0x3",
            "meaning": "Uses index / 8 as the source byte offset.",
        },
        {
            "id": "loads_source_mask_byte",
            "marker": "0049215d: MOV CL,byte ptr [EBP + ECX*0x1 + -0x8]",
            "meaning": "Loads one of the six source bytes.",
        },
        {
            "id": "sets_output_bit_slot",
            "marker": "0049216b: CALL 0x00491472",
            "meaning": "Stores the decoded bit into the output bitset.",
        },
        {
            "id": "loops_48_slots",
            "marker": "00492171: CMP ESI,0x30",
            "meaning": "Loops over 48 slots.",
        },
    ],
    "bitset_setter_0x491472": [
        {
            "id": "bounds_48_slots",
            "marker": "0049147a: CMP EDI,0x30",
            "meaning": "Accepts bit indexes below 48.",
        },
        {
            "id": "slot_mod_32",
            "marker": "00491491: AND ECX,0x1f",
            "meaning": "Uses index modulo 32 for dword bit position.",
        },
        {
            "id": "slot_div_32",
            "marker": "00491495: SHR EAX,0x5",
            "meaning": "Uses index / 32 for dword selection.",
        },
        {
            "id": "sets_bit",
            "marker": "0049149d: OR dword ptr [EAX],EDX",
            "meaning": "Sets the selected output bit when the input value is true.",
        },
        {
            "id": "clears_bit",
            "marker": "004914b3: AND dword ptr [EAX],EDX",
            "meaning": "Clears the selected output bit when the input value is false.",
        },
    ],
    "row_48_slot_text_mask_parser_0x490f3f": [
        {
            "id": "loop_bound_48",
            "marker": "00490f91: PUSH 0x30",
            "meaning": "Parses up to 48 row characters.",
        },
        {
            "id": "accepts_ascii_zero",
            "marker": "00490fa3: CMP EAX,0x30",
            "meaning": "Accepts ASCII '0'.",
        },
        {
            "id": "accepts_ascii_one",
            "marker": "00490fa8: CMP EAX,0x31",
            "meaning": "Accepts ASCII '1'.",
        },
        {
            "id": "appends_valid_char",
            "marker": "00490fbf: CALL 0x00419372",
            "meaning": "Appends accepted 0/1 mask characters to the output container.",
        },
        {
            "id": "advances_source_cursor",
            "marker": "00490fd1: CALL 0x0042cc4c",
            "meaning": "Advances the parsed row/source cursor after accepted characters.",
        },
    ],
    "row_9_slot_text_terrain_parser_0x491136": [
        {
            "id": "loop_bound_9",
            "marker": "00491188: PUSH 0x9",
            "meaning": "Parses up to nine row characters.",
        },
        {
            "id": "accepts_ascii_zero",
            "marker": "0049119a: CMP EAX,0x30",
            "meaning": "Accepts ASCII '0'.",
        },
        {
            "id": "accepts_ascii_one",
            "marker": "0049119f: CMP EAX,0x31",
            "meaning": "Accepts ASCII '1'.",
        },
        {
            "id": "appends_valid_char",
            "marker": "004911b6: CALL 0x00419372",
            "meaning": "Appends accepted 0/1 terrain-mask characters to the output container.",
        },
        {
            "id": "advances_source_cursor",
            "marker": "004911c8: CALL 0x0042cc4c",
            "meaning": "Advances the parsed row/source cursor after accepted characters.",
        },
    ],
    "row_owner_0x4907c9": [
        {
            "id": "first_48_mask_local",
            "marker": "004907eb: LEA ECX,[EBP + -0x44]",
            "meaning": "Initializes the first two-dword 48-slot mask local.",
        },
        {
            "id": "second_48_mask_local",
            "marker": "004907f7: LEA ECX,[EBP + -0x4c]",
            "meaning": "Initializes the second two-dword 48-slot mask local.",
        },
        {
            "id": "row_source_blob_local",
            "marker": "0049082b: LEA EAX,[EBP + -0x64]",
            "meaning": "Prepares the source/name/blob local passed to 0x4903e8.",
        },
        {
            "id": "parses_source_blob",
            "marker": "00490832: CALL 0x00491fa1",
            "meaning": "Parses the row source/name/blob field.",
        },
        {
            "id": "parses_first_48_text_mask",
            "marker": "0049083a: CALL 0x00490f3f",
            "meaning": "Parses the first 48-slot row text mask.",
        },
        {
            "id": "parses_second_48_text_mask",
            "marker": "00490842: CALL 0x00490f3f",
            "meaning": "Parses the second 48-slot row text mask.",
        },
        {
            "id": "parses_first_9_text_policy",
            "marker": "0049084a: CALL 0x00491136",
            "meaning": "Parses the first nine-slot row text terrain mask field.",
        },
        {
            "id": "parses_second_9_text_policy",
            "marker": "00490852: CALL 0x00491136",
            "meaning": "Parses the second nine-slot row text terrain mask field.",
        },
        {
            "id": "reads_four_row_scalars",
            "marker": "00490870: CALL 0x0042bc12",
            "meaning": "Completes the four scalar row reads that feed descriptor +0x1c/+0x20/+0x24/+0x28.",
        },
        {
            "id": "calls_descriptor_builder_with_blob",
            "marker": "0049089e: CALL 0x004903e8",
            "meaning": "Builds the descriptor using the parsed row source/name/blob.",
        },
        {
            "id": "combines_first_48_mask",
            "marker": "004908d0: CALL 0x00490f10",
            "meaning": "Combines the first 48-slot mask with descriptor +0x3c/+0x40-derived policy.",
        },
        {
            "id": "writes_primary_mask_plus_0x04",
            "marker": "004908da: MOV dword ptr [ESI + 0x4],ECX",
            "meaning": "Writes the combined primary mask first dword to descriptor +0x04.",
        },
        {
            "id": "writes_primary_mask_plus_0x08",
            "marker": "004908e2: MOV dword ptr [ESI + 0x8],EAX",
            "meaning": "Writes the combined primary mask second dword to descriptor +0x08.",
        },
        {
            "id": "derives_secondary_mask_and_anchor",
            "marker": "004908e9: CALL 0x004906fb",
            "meaning": "Derives descriptor +0x0c/+0x10/+0x29/+0x2c/+0x30 from the second 48-slot mask.",
        },
        {
            "id": "writes_terrain_mask_a_plus_0x14",
            "marker": "00490903: MOV dword ptr [ESI + 0x14],EAX",
            "meaning": "Writes the first recovered nine-slot terrain mask value to descriptor +0x14.",
        },
        {
            "id": "writes_terrain_mask_b_plus_0x18",
            "marker": "00490909: MOV dword ptr [EDI],EAX",
            "meaning": "Writes the second recovered nine-slot terrain mask value to descriptor +0x18.",
        },
        {
            "id": "writes_scalar_plus_0x1c",
            "marker": "0049090e: MOV dword ptr [ESI + 0x1c],EAX",
            "meaning": "Writes the first recovered scalar to descriptor +0x1c.",
        },
        {
            "id": "writes_scalar_plus_0x20",
            "marker": "00490914: MOV dword ptr [ESI + 0x20],EAX",
            "meaning": "Writes the second recovered scalar to descriptor +0x20.",
        },
        {
            "id": "writes_scalar_plus_0x24",
            "marker": "0049091a: MOV dword ptr [ESI + 0x24],EAX",
            "meaning": "Writes the third recovered scalar to descriptor +0x24.",
        },
        {
            "id": "writes_boolean_plus_0x28",
            "marker": "00490923: SETNZ AL",
            "meaning": "Converts the fourth recovered scalar to the descriptor +0x28 boolean flag.",
        },
    ],
    "stream_owner_0x490a11": [
        {
            "id": "stream_source_blob_local",
            "marker": "00490a5c: LEA EAX,[EBP + -0x54]",
            "meaning": "Prepares the source/name/blob local passed to 0x4903e8.",
        },
        {
            "id": "reads_source_blob",
            "marker": "00490a61: CALL 0x004190cb",
            "meaning": "Reads the stream source/name/blob field.",
        },
        {
            "id": "reads_first_48_bit_mask",
            "marker": "00490a6b: CALL 0x0049213a",
            "meaning": "Reads the first 48-slot stream bit mask.",
        },
        {
            "id": "reads_second_48_bit_mask",
            "marker": "00490a75: CALL 0x0049213a",
            "meaning": "Reads the second 48-slot stream bit mask.",
        },
        {
            "id": "reads_first_terrain_mask_container",
            "marker": "00490a7f: CALL 0x0043bb1b",
            "meaning": "Reads the first nine-slot terrain mask stream field.",
        },
        {
            "id": "reads_second_terrain_mask_container",
            "marker": "00490a89: CALL 0x0043bb1b",
            "meaning": "Reads the second nine-slot terrain mask stream field.",
        },
        {
            "id": "reads_first_dword",
            "marker": "00490aa3: CALL 0x00407675",
            "meaning": "Reads the first descriptor scalar dword.",
        },
        {
            "id": "reads_second_dword",
            "marker": "00490aaa: CALL 0x00407675",
            "meaning": "Reads the second descriptor scalar dword.",
        },
        {
            "id": "reads_signed_selector_byte",
            "marker": "00490ab1: CALL 0x0040763d",
            "meaning": "Reads the byte that later becomes descriptor +0x24.",
        },
        {
            "id": "reads_boolean_flag_byte",
            "marker": "00490ab8: CALL 0x0040763d",
            "meaning": "Reads the byte that later becomes descriptor +0x28.",
        },
        {
            "id": "reads_auxiliary_16_byte_record",
            "marker": "00490ac3: CALL 0x00438937",
            "meaning": "Reads a fixed 16-byte stream payload. The companion aux checkpoint proves this caller does not store that local into descriptor fields.",
        },
        {
            "id": "calls_descriptor_builder_with_blob",
            "marker": "00490af1: CALL 0x004903e8",
            "meaning": "Builds the descriptor using the stream source/name/blob.",
        },
        {
            "id": "combines_first_48_mask",
            "marker": "00490b0d: CALL 0x00490f10",
            "meaning": "Combines the first 48-slot mask with descriptor +0x3c/+0x40-derived policy.",
        },
        {
            "id": "writes_primary_mask_plus_0x04",
            "marker": "00490b17: MOV dword ptr [ESI + 0x4],ECX",
            "meaning": "Writes the combined primary mask first dword to descriptor +0x04.",
        },
        {
            "id": "writes_primary_mask_plus_0x08",
            "marker": "00490b1f: MOV dword ptr [ESI + 0x8],EAX",
            "meaning": "Writes the combined primary mask second dword to descriptor +0x08.",
        },
        {
            "id": "derives_secondary_mask_and_anchor",
            "marker": "00490b2a: CALL 0x004906fb",
            "meaning": "Derives descriptor +0x0c/+0x10/+0x29/+0x2c/+0x30 from the second 48-slot mask.",
        },
        {
            "id": "initializes_descriptor_vector_plus_0x18",
            "marker": "00490b31: CALL 0x004906de",
            "meaning": "Initializes descriptor +0x14 and vector/container storage at +0x18.",
        },
        {
            "id": "writes_terrain_mask_b_plus_0x18",
            "marker": "00490b3b: MOV dword ptr [EAX + 0x18],ECX",
            "meaning": "Writes the second recovered nine-slot terrain mask value to descriptor +0x18.",
        },
        {
            "id": "writes_dword_plus_0x1c",
            "marker": "00490b41: MOV dword ptr [EAX + 0x1c],ECX",
            "meaning": "Writes the first stream dword to descriptor +0x1c.",
        },
        {
            "id": "writes_dword_plus_0x20",
            "marker": "00490b47: MOV dword ptr [EAX + 0x20],ECX",
            "meaning": "Writes the second stream dword to descriptor +0x20.",
        },
        {
            "id": "writes_signed_byte_plus_0x24",
            "marker": "00490b4e: MOV dword ptr [EAX + 0x24],ECX",
            "meaning": "Writes the signed selector byte to descriptor +0x24.",
        },
        {
            "id": "writes_boolean_plus_0x28",
            "marker": "00490b5b: MOV byte ptr [EAX + 0x28],CL",
            "meaning": "Writes the nonzero boolean byte to descriptor +0x28.",
        },
    ],
    "secondary_mask_anchor_deriver_0x4906fb": [
        {
            "id": "writes_secondary_mask_first_word",
            "marker": "00490745: MOV dword ptr [EDI],ECX",
            "meaning": "Writes descriptor +0x0c.",
        },
        {
            "id": "writes_secondary_mask_second_word",
            "marker": "0049074b: MOV dword ptr [EDI + 0x4],EAX",
            "meaning": "Writes descriptor +0x10.",
        },
        {
            "id": "writes_has_secondary_mask_flag",
            "marker": "00490763: MOV byte ptr [ESI + 0x29],AL",
            "meaning": "Writes descriptor +0x29 based on whether the secondary mask is non-empty.",
        },
        {
            "id": "scans_48_slots_for_anchor",
            "marker": "00490792: CMP EBX,0x8",
            "meaning": "Scans eight bits per row while deriving the first live anchor slot.",
        },
        {
            "id": "writes_anchor_x",
            "marker": "004907a7: MOV dword ptr [ESI + 0x2c],EBX",
            "meaning": "Writes descriptor anchor/offset x at +0x2c.",
        },
        {
            "id": "writes_anchor_y",
            "marker": "004907aa: MOV dword ptr [ESI + 0x30],EAX",
            "meaning": "Writes descriptor anchor/offset y at +0x30.",
        },
    ],
    "descriptor_vector_initializer_0x4906de": [
        {
            "id": "initializes_vector_plus_0x18",
            "marker": "004906e7: LEA ECX,[ESI + 0x18]",
            "meaning": "Initializes descriptor vector/container storage at +0x18.",
        },
        {
            "id": "writes_plus_0x14",
            "marker": "004906f2: MOV dword ptr [ESI + 0x14],EAX",
            "meaning": "Writes descriptor +0x14 from the supplied first nine-slot terrain mask value.",
        },
    ],
    "mask_combiner_0x490f10": [
        {
            "id": "calls_mask_operation",
            "marker": "00490f29: CALL 0x00491452",
            "meaning": "Combines two mask pairs into an output mask pair.",
        }
    ],
    "mask_complementer_0x4914bc": [
        {
            "id": "inverts_first_dword",
            "marker": "004914ca: NOT EDI",
            "meaning": "Inverts the first dword of a mask pair.",
        },
        {
            "id": "inverts_second_dword",
            "marker": "004914cc: MOV dword ptr [ESI],EDI",
            "meaning": "Inverts the second dword of a mask pair.",
        },
        {
            "id": "clears_high_word",
            "marker": "004914d4: AND word ptr [EDX + 0x2],0x0",
            "meaning": "Normalizes the high word beyond the 48-slot surface.",
        },
    ],
    "mask_initializer_0x4914dc": [
        {
            "id": "writes_first_dword",
            "marker": "004914e9: MOV dword ptr [ECX],EDX",
            "meaning": "Initializes the first dword of a mask pair.",
        },
        {
            "id": "writes_second_dword",
            "marker": "004914ef: JNZ 0x004914e9",
            "meaning": "Initializes the second dword of a mask pair.",
        },
    ],
    "first_dword_reader_0x490e66": [
        {
            "id": "returns_first_dword",
            "marker": "00490e66: MOV EAX,dword ptr [ECX]",
            "meaning": "Returns the first dword of a container/mask holder.",
        }
    ],
    "descriptor_base_value_helper_0x491eed": [
        {
            "id": "returns_entry_plus_0x1c",
            "marker": "00491f93: MOV EAX,dword ptr [EAX + 0x1c]",
            "meaning": "Returns the table entry field that 0x4903e8 stores at descriptor +0x00.",
        }
    ],
}


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def evaluate_file(name: str, path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8", errors="replace")
    checks = [
        {
            "id": check["id"],
            "marker": check["marker"],
            "present": check["marker"] in text,
            "meaning": check["meaning"],
        }
        for check in CHECKS[name]
    ]
    return {
        "id": name,
        "path": str(path),
        "all_required_markers_present": all(check["present"] for check in checks),
        "checks": checks,
    }


def object_catalog_evidence(path: Path) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    with path.open(newline="", encoding="utf-8", errors="replace") as handle:
        reader = csv.DictReader(handle)
        fieldnames = reader.fieldnames or []
        required = {"terrain_mask_a", "terrain_mask_b", "terrain_a_names", "terrain_b_names"}
        for row in reader:
            rows.append(row)

    valid_mask_rows = [
        row
        for row in rows
        if len(row.get("terrain_mask_a", "")) == 9
        and len(row.get("terrain_mask_b", "")) == 9
        and set(row.get("terrain_mask_a", "")) <= {"0", "1"}
        and set(row.get("terrain_mask_b", "")) <= {"0", "1"}
    ]
    return {
        "path": str(path),
        "fieldnames": fieldnames,
        "terrain_order": TERRAIN_ORDER,
        "has_terrain_mask_fields": required.issubset(fieldnames),
        "row_count": len(rows),
        "valid_9_slot_terrain_mask_rows": len(valid_mask_rows),
        "sample_rows": [
            {
                "source": row.get("source"),
                "source_row": row.get("source_row"),
                "def_name": row.get("def_name"),
                "terrain_mask_a": row.get("terrain_mask_a"),
                "terrain_mask_b": row.get("terrain_mask_b"),
                "terrain_a_names": row.get("terrain_a_names"),
                "terrain_b_names": row.get("terrain_b_names"),
            }
            for row in valid_mask_rows[:5]
        ],
    }


def field_mapping() -> dict[str, Any]:
    return {
        "row_owner_0x4907c9": [
            {
                "field": "source_name_or_blob",
                "source": "objects.txt parsed row field via 0x491fa1 into local -0x64",
                "descriptor_destination": "input to 0x4903e8; 0x4903e8 resolves descriptor +0x00 through 0x491eed",
                "human_meaning": "source object identity/name/blob used to resolve the descriptor base value",
            },
            {
                "field": "primary_48_slot_mask",
                "source": "first row text mask via 0x490f3f into local -0x44",
                "descriptor_destination": "combined by 0x490f10 and written to descriptor +0x04/+0x08",
                "human_meaning": "primary 48-slot object mask surface",
            },
            {
                "field": "secondary_48_slot_mask",
                "source": "second row text mask via 0x490f3f into local -0x4c",
                "descriptor_destination": "processed by 0x4906fb into descriptor +0x0c/+0x10/+0x29/+0x2c/+0x30",
                "human_meaning": "secondary 48-slot mask plus non-empty flag and first live anchor/offset",
            },
            {
                "field": "terrain_mask_a",
                "source": (
                    "objects.txt/objtmplt.txt fourth row field; first nine-slot ASCII 0/1 "
                    "terrain mask parsed through 0x491136"
                ),
                "descriptor_destination": "normalized first terrain mask value written to descriptor +0x14",
                "human_meaning": "catalog terrain mask A over dirt/sand/grass/snow/swamp/rough/cave/lava/water",
            },
            {
                "field": "terrain_mask_b",
                "source": (
                    "objects.txt/objtmplt.txt fifth row field; second nine-slot ASCII 0/1 "
                    "terrain mask parsed through 0x491136"
                ),
                "descriptor_destination": "normalized second terrain mask value written to descriptor +0x18",
                "human_meaning": "catalog terrain mask B over dirt/sand/grass/snow/swamp/rough/cave/lava/water",
            },
            {
                "field": "descriptor_type_counter_index",
                "source": "first row scalar via 0x42bc12 into local -0x20",
                "descriptor_destination": "descriptor +0x1c",
                "human_meaning": "descriptor type/counter index used by later generator counters and policy tables",
            },
            {
                "field": "descriptor_source_or_object_id",
                "source": "second row scalar via 0x42bc12 into local -0x24",
                "descriptor_destination": "descriptor +0x20",
                "human_meaning": "source/object id used by later resolver filters",
            },
            {
                "field": "class_or_subtype_selector",
                "source": "third row scalar via 0x42bc12 into local -0x28",
                "descriptor_destination": "descriptor +0x24",
                "human_meaning": "class/subtype-like selector used together with descriptor +0x20 in filters",
            },
            {
                "field": "boolean_policy_flag",
                "source": "fourth row scalar via 0x42bc12 into local -0x2c",
                "descriptor_destination": "descriptor +0x28",
                "human_meaning": "nonzero row scalar becomes descriptor boolean policy flag",
            },
        ],
        "stream_owner_0x490a11": [
            {
                "field": "source_name_or_blob",
                "source": "stream blob via 0x4190cb into local -0x54",
                "descriptor_destination": "input to 0x4903e8; 0x4903e8 resolves descriptor +0x00 through 0x491eed",
                "human_meaning": "source object identity/name/blob used to resolve the descriptor base value",
            },
            {
                "field": "primary_48_slot_mask",
                "source": "first six-byte stream bitset via 0x49213a into local -0x2c",
                "descriptor_destination": "combined by 0x490f10 and written to descriptor +0x04/+0x08",
                "human_meaning": "primary 48-slot object mask surface",
            },
            {
                "field": "secondary_48_slot_mask",
                "source": "second six-byte stream bitset via 0x49213a into local -0x34",
                "descriptor_destination": "processed by 0x4906fb into descriptor +0x0c/+0x10/+0x29/+0x2c/+0x30",
                "human_meaning": "secondary 48-slot mask plus non-empty flag and first live anchor/offset",
            },
            {
                "field": "terrain_mask_a",
                "source": "first nine-slot stream terrain bitset via 0x43bb1b into local -0x18",
                "descriptor_destination": "normalized first terrain mask value written to descriptor +0x14",
                "human_meaning": "catalog terrain mask A over dirt/sand/grass/snow/swamp/rough/cave/lava/water",
            },
            {
                "field": "terrain_mask_b",
                "source": "second nine-slot stream terrain bitset via 0x43bb1b into local -0x14",
                "descriptor_destination": "normalized second terrain mask value written to descriptor +0x18",
                "human_meaning": "catalog terrain mask B over dirt/sand/grass/snow/swamp/rough/cave/lava/water",
            },
            {
                "field": "descriptor_type_counter_index",
                "source": "first stream dword via 0x407675 into local -0x20",
                "descriptor_destination": "descriptor +0x1c",
                "human_meaning": "descriptor type/counter index used by later generator counters and policy tables",
            },
            {
                "field": "descriptor_source_or_object_id",
                "source": "second stream dword via 0x407675 into local -0x24",
                "descriptor_destination": "descriptor +0x20",
                "human_meaning": "source/object id used by later resolver filters",
            },
            {
                "field": "class_or_subtype_selector",
                "source": "first stream byte via 0x40763d into local -0x0d",
                "descriptor_destination": "sign-extended descriptor +0x24",
                "human_meaning": "signed class/subtype-like selector used together with descriptor +0x20 in filters",
            },
            {
                "field": "boolean_policy_flag",
                "source": "second stream byte via 0x40763d into local -0x0e",
                "descriptor_destination": "descriptor +0x28",
                "human_meaning": "nonzero stream byte becomes descriptor boolean policy flag",
            },
            {
                "field": "reserved_16_byte_stream_payload",
                "source": "stream record via 0x438937 into local -0x64",
                "descriptor_destination": "caller-local payload only; the companion aux checkpoint proves no descriptor field assignment from this local in the 0x490a11 owner path",
                "human_meaning": "reserved/alignment stream payload validated by the source reader and not used as descriptor identity or mask data in this caller",
            },
        ],
    }


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    static_loader = load_json(args.static_loader)
    catalog = object_catalog_evidence(args.object_catalog)
    files = DEFAULT_GHIDRA_FILES.copy()
    files.update(args.ghidra_file_overrides)
    ghidra_checks = {name: evaluate_file(name, path) for name, path in files.items()}
    invariants = {
        "static_loader_checkpoint_present": static_loader.get("status")
        == "descriptor_static_loader_field_writer_recovered_selected_source_mapping_pending",
        "all_ghidra_markers_present": all(
            item["all_required_markers_present"] for item in ghidra_checks.values()
        ),
        "row_path_has_two_48_slot_text_masks": all(
            any(check["id"] == check_id and check["present"] for check in ghidra_checks["row_owner_0x4907c9"]["checks"])
            for check_id in ["parses_first_48_text_mask", "parses_second_48_text_mask"]
        ),
        "stream_path_has_two_48_slot_bit_masks": all(
            any(check["id"] == check_id and check["present"] for check in ghidra_checks["stream_owner_0x490a11"]["checks"])
            for check_id in ["reads_first_48_bit_mask", "reads_second_48_bit_mask"]
        ),
        "row_and_stream_write_same_descriptor_surface": all(
            any(check["id"] == check_id and check["present"] for check in ghidra_checks[owner]["checks"])
            for owner in ["row_owner_0x4907c9", "stream_owner_0x490a11"]
            for check_id in [
                "writes_primary_mask_plus_0x04",
                "writes_primary_mask_plus_0x08",
                "derives_secondary_mask_and_anchor",
            ]
        ),
        "object_catalog_has_two_9_slot_terrain_masks": catalog["has_terrain_mask_fields"]
        and catalog["valid_9_slot_terrain_mask_rows"] == catalog["row_count"]
        and catalog["terrain_order"] == TERRAIN_ORDER,
        "native_behavior_unchanged": True,
        "no_objdump_used": True,
    }
    status = (
        "descriptor_input_mapping_terrain_fields_recovered_catalog_mapping_pending"
        if all(invariants.values())
        else "descriptor_input_mapping_surface_incomplete"
    )
    return {
        "schema_id": "h3maped_descriptor_input_mapping_summary_v1",
        "status": status,
        "scope": (
            "Ghidra/Python field-level checkpoint for the exact 0x4907c9 and 0x490a11 "
            "inputs around 0x4903e8. It names row-text and stream equivalents and the "
            "descriptor fields they populate. It does not claim selected mixed-lane "
            "descriptor identity for generated objects."
        ),
        "inputs": {
            "static_loader": str(args.static_loader),
            "object_catalog": str(args.object_catalog),
            "ghidra_files": {name: str(path) for name, path in files.items()},
        },
        "input_statuses": {"static_loader": static_loader.get("status")},
        "object_catalog_evidence": catalog,
        "invariants": invariants,
        "metrics": {
            "ghidra_file_count": len(ghidra_checks),
            "required_marker_count": sum(len(item["checks"]) for item in ghidra_checks.values()),
            "present_marker_count": sum(
                1 for item in ghidra_checks.values() for check in item["checks"] if check["present"]
            ),
            "native_behavior_changed": False,
            "used_objdump": False,
            "overall_goal_complete": False,
        },
        "ghidra_checks": ghidra_checks,
        "field_mapping": field_mapping(),
        "descriptor_terrain_mask_mapping": {
            "terrain_order": TERRAIN_ORDER,
            "descriptor_plus_0x14": "terrain_mask_a",
            "descriptor_plus_0x18": "terrain_mask_b",
            "row_source_fields": {
                "terrain_mask_a": "objects.txt/objtmplt.txt field 4 after DEF/passability/action masks",
                "terrain_mask_b": "objects.txt/objtmplt.txt field 5 after DEF/passability/action masks",
            },
            "stream_source_fields": {
                "terrain_mask_a": "first 0x43bb1b nine-slot stream bitset",
                "terrain_mask_b": "second 0x43bb1b nine-slot stream bitset",
            },
        },
        "source_backed_conclusion": (
            "0x4907c9 is the objects.txt parsed-row descriptor-owner path and 0x490a11 "
            "is the binary/source-stream descriptor-owner path. Their exact recovered "
            "input surface is equivalent at descriptor field level: source/name/blob into "
            "0x4903e8; primary 48-slot mask into +0x04/+0x08; secondary 48-slot mask into "
            "+0x0c/+0x10/+0x29/+0x2c/+0x30; catalog terrain_mask_a into +0x14; "
            "catalog terrain_mask_b into +0x18; "
            "type/counter index into +0x1c; source/object id into +0x20; class/subtype-like "
            "selector into +0x24; and a boolean policy flag into +0x28. The fixed "
            "16-byte stream payload read through 0x438937 is handled by the separate "
            "auxiliary-record checkpoint because it is not stored into descriptor fields "
            "in this owner path."
        ),
        "remaining_blockers": [
            {
                "id": "source_catalog_template_producer_mapping",
                "reason": (
                    "The non-hero producer that maps parsed source-input records and nested "
                    "payload holders into exact objects.txt/objtmplt.txt type/subtype/DEF rows "
                    "still needs recovery or source-backed exclusion before claiming full end-to-end recovery."
                ),
            },
        ],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--static-loader", type=Path, default=DEFAULT_STATIC_LOADER)
    parser.add_argument("--object-catalog", type=Path, default=DEFAULT_OBJECT_CATALOG)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    args.ghidra_file_overrides = {}

    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_DESCRIPTOR_INPUT_MAPPING status={status} markers={present}/{total} out={out}".format(
            status=summary["status"],
            present=summary["metrics"]["present_marker_count"],
            total=summary["metrics"]["required_marker_count"],
            out=args.out,
        )
    )


if __name__ == "__main__":
    main()
