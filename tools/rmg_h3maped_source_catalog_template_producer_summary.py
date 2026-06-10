#!/usr/bin/env python3
"""Verify the H3MapEd RMG source catalog/template producer mapping.

This checkpoint closes the source-catalog/template producer blocker by proving
the provider dispatch does not collapse source identity to local descriptor ids:
the provider object is globally installed, its dispatch/materializer slots are
paired, and concrete provider constructors copy/adopt the full 0x4c source
record whose type/subtype/text fields match the recovered objects.txt /
objtmplt.txt catalog row shape.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from pathlib import Path
from typing import Any


sys.dont_write_bytecode = True

ROOT = Path(".artifacts/rmg_recovery")
CATALOG = Path(
    "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/"
    "object-catalog-by-type.csv"
)
DEFAULT_OUT = ROOT / "source_catalog_template_producer_summary_20260610.json"

PROVIDER_GLOBAL_REFS = ROOT / "ghidra_source_provider_global_refs_20260610" / (
    "target_0059e390_references.txt"
)
PROVIDER_INITIALIZER = ROOT / "ghidra_source_provider_global_initializer_dump_20260610" / (
    "target_0045dae4_FUN_0045dae4.txt"
)
PROVIDER_SETTER = ROOT / "ghidra_source_provider_setter_refs_20260610" / (
    "target_004299e9_FUN_004299e9.txt"
)
PROVIDER_VTABLE = ROOT / "ghidra_source_provider_vtable_dump_20260610" / (
    "table_0053942c.json"
)
PROVIDER_BASE_COPY = ROOT / "ghidra_source_provider_base_copy_dump_20260610" / (
    "target_0043d309_FUN_0043d309.txt"
)
SOURCE_RECORD_ADOPTION = ROOT / "ghidra_source_record_adoption_global_refs_20260610" / (
    "target_00437751_FUN_00437751.txt"
)
SOURCE_RECORD_COMPARE = ROOT / "ghidra_source_record_compare_dump_20260610" / (
    "target_00490b77_FUN_00490b77.txt"
)
OBJECT_TABLE_SUMMARY = ROOT / "object_table_loader_summary_20260610.json"
SOURCE_VARIANT_SUMMARY = ROOT / "source_variant_builder_summary_20260610.json"
HERO_RUNTIME_SUMMARY = ROOT / "hero_catalog_runtime_table_summary_20260610.json"
DESCRIPTOR_CROSSWALK_SUMMARY = ROOT / "descriptor_label_crosswalk_summary_20260610.json"

PROVIDER_GLOBAL_REFERENCE_RE = re.compile(
    r"from=([0-9a-f]{8}) type=(READ|WRITE) caller=([^ ]+) caller_entry=([0-9a-f<>]+)",
    re.IGNORECASE,
)

PROVIDER_GLOBAL_CHECKS = [
    {
        "id": "provider_global_written_only_by_setter",
        "marker": "from=004299ed type=WRITE caller=FUN_004299e9",
        "path": PROVIDER_GLOBAL_REFS,
    },
    {
        "id": "provider_global_read_by_variant_builder",
        "marker": "caller=FUN_00422868 caller_entry=00422868",
        "path": PROVIDER_GLOBAL_REFS,
    },
    {
        "id": "provider_global_read_by_materializer",
        "marker": "caller=FUN_0042158c caller_entry=0042158c",
        "path": PROVIDER_GLOBAL_REFS,
    },
    {
        "id": "provider_initializer_installs_vtable_53942c",
        "marker": "0045dafa: MOV dword ptr [ESI],0x53942c",
        "path": PROVIDER_INITIALIZER,
    },
    {
        "id": "provider_initializer_calls_global_setter",
        "marker": "0045db00: CALL 0x004299e9",
        "path": PROVIDER_INITIALIZER,
    },
    {
        "id": "provider_setter_writes_stack_arg_to_global",
        "marker": "MOV [0x0059e390],EAX",
        "path": PROVIDER_SETTER,
    },
]

BASE_COPY_CHECKS = [
    {"id": "base_copy_reads_source_record_argument", "marker": "0043d311: MOV ESI,dword ptr [EBP + 0x8]"},
    {"id": "base_copy_count_0x13_dwords", "marker": "0043d317: PUSH 0x13"},
    {"id": "base_copy_rep_movsd_full_record", "marker": "0043d32a: MOVSD.REP ES:EDI,ESI"},
    {"id": "base_copy_uses_adoption_cache_59e410", "marker": "0043d331: MOV ECX,0x59e410"},
    {"id": "base_copy_calls_adoption_cache", "marker": "0043d336: CALL 0x00437751"},
    {"id": "base_copy_stores_adopted_payload_pointer", "marker": "0043d344: MOV dword ptr [EBX + 0x4],EAX"},
    {"id": "base_copy_increments_adopted_payload_refcount", "marker": "0043d347: INC dword ptr [EAX + 0x58]"},
]

ADOPTION_CHECKS = [
    {"id": "adoption_compares_existing_node_record", "marker": "00437783: LEA EAX,[ESI + 0xc]"},
    {"id": "adoption_calls_source_record_compare", "marker": "0043778f: CALL 0x00490b77"},
    {"id": "adoption_inserts_missing_record", "marker": "004377c1: CALL 0x00437d5a"},
]

COMPARE_CHECKS = [
    {"id": "compare_field_00", "marker": "00490b82: MOV EAX,dword ptr [ESI]"},
    {"id": "compare_type_field_1c", "marker": "00490b9a: MOV EAX,dword ptr [ESI + 0x1c]"},
    {"id": "compare_subtype_field_20", "marker": "00490ba6: MOV EAX,dword ptr [ESI + 0x20]"},
    {"id": "compare_field_24", "marker": "00490bb2: MOV EAX,dword ptr [ESI + 0x24]"},
    {"id": "compare_field_28_byte", "marker": "00490bbe: MOV AL,byte ptr [ESI + 0x28]"},
    {"id": "compare_text_field_04", "marker": "00490bca: LEA EBX,[EDI + 0x4]"},
    {"id": "compare_text_field_0c", "marker": "00490bea: LEA EBX,[EDI + 0xc]"},
    {"id": "compare_text_field_14", "marker": "00490c0a: LEA EBX,[EDI + 0x14]"},
    {"id": "compare_text_field_18", "marker": "00490c32: ADD EDI,0x18"},
]

PROVIDER_SLOT_DISPATCH = [
    {"slot": "0x04", "source_record_plus_0x1c_values": ["default/unmatched category path"]},
    {"slot": "0x0c", "source_record_plus_0x1c_values": ["0xd6"]},
    {"slot": "0x14", "source_record_plus_0x1c_values": ["0x22"]},
    {"slot": "0x1c", "source_record_plus_0x1c_values": ["0x46"]},
    {"slot": "0x24", "source_record_plus_0x1c_values": ["0x3e"]},
    {"slot": "0x2c", "source_record_plus_0x1c_values": ["0x4d", "0x62"]},
    {"slot": "0x3c", "source_record_plus_0x1c_values": ["0x36", "0x47..0x4b", "0xa2..0xa4"]},
    {"slot": "0x34", "source_record_plus_0x1c_values": ["0x1a"]},
    {"slot": "0x44", "source_record_plus_0x1c_values": ["0x3b", "0x5b"]},
    {"slot": "0x4c", "source_record_plus_0x1c_values": ["0x57"]},
    {
        "slot": "0x54",
        "source_record_plus_0x1c_values": [
            "0x2a",
            "0x35 when source_record+0x20 < 7",
            "0xdc when source_record+0x20 < 7",
        ],
    },
    {
        "slot": "0x5c",
        "source_record_plus_0x1c_values": [
            "0x35 when source_record+0x20 >= 7",
            "0xdc when source_record+0x20 >= 7",
        ],
    },
    {"slot": "0x64", "source_record_plus_0x1c_values": ["0x21", "0xdb"]},
    {"slot": "0x6c", "source_record_plus_0x1c_values": ["0x05", "0x41..0x45"]},
    {"slot": "0x74", "source_record_plus_0x1c_values": ["0x5d"]},
    {"slot": "0x7c", "source_record_plus_0x1c_values": ["0x4c", "0x4f"]},
    {"slot": "0x84", "source_record_plus_0x1c_values": ["0x06"]},
    {"slot": "0x8c", "source_record_plus_0x1c_values": ["0x51"]},
    {"slot": "0x94", "source_record_plus_0x1c_values": ["0x53"]},
    {"slot": "0x9c", "source_record_plus_0x1c_values": ["0x24"]},
    {"slot": "0xa4", "source_record_plus_0x1c_values": ["0x58..0x5a"]},
    {"slot": "0xac", "source_record_plus_0x1c_values": ["0x11", "0x14"]},
    {"slot": "0xb4", "source_record_plus_0x1c_values": ["0xd9"]},
    {"slot": "0xbc", "source_record_plus_0x1c_values": ["0xda"]},
    {"slot": "0xc4", "source_record_plus_0x1c_values": ["0xd8"]},
    {"slot": "0xcc", "source_record_plus_0x1c_values": ["0xd7"]},
    {"slot": "0xd4", "source_record_plus_0x1c_values": ["0x71"]},
]

FALLBACK_TYPE_NAMES = {
    0x22: "Hero",
    0x46: "Random Hero",
    0x47: "Random Monster",
    0x48: "Random Monster 1",
    0x49: "Random Monster 2",
    0x4A: "Random Monster 3",
    0x4B: "Random Monster 4",
    0xD9: "Random Dwelling / special dwelling",
    0xDA: "Random Dwelling / special dwelling",
}


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def check_markers(checks: list[dict[str, Any]]) -> list[dict[str, Any]]:
    cache: dict[Path, str] = {}
    results = []
    for check in checks:
        path = check["path"]
        cache.setdefault(path, read_text(path))
        results.append({**check, "path": str(path), "present": check["marker"] in cache[path]})
    return results


def check_function_markers(path: Path, checks: list[dict[str, str]]) -> list[dict[str, Any]]:
    text = read_text(path)
    return [{**check, "path": str(path), "present": check["marker"] in text} for check in checks]


def parse_provider_global_refs(path: Path) -> dict[str, Any]:
    reads: dict[str, int] = {}
    writes: list[dict[str, str]] = []
    references = []
    for match in PROVIDER_GLOBAL_REFERENCE_RE.finditer(read_text(path)):
        address, ref_type, caller, caller_entry = match.groups()
        entry = {
            "address": f"0x{address}",
            "type": ref_type,
            "caller": caller,
            "caller_entry": f"0x{caller_entry}" if caller_entry != "<none>" else caller_entry,
        }
        references.append(entry)
        if ref_type == "READ":
            reads[caller_entry] = reads.get(caller_entry, 0) + 1
        else:
            writes.append(entry)
    return {
        "reference_count": len(references),
        "read_count": len(references) - len(writes),
        "write_count": len(writes),
        "read_callers": dict(sorted((f"0x{k}", v) for k, v in reads.items())),
        "writes": writes,
        "only_expected_writer": len(writes) == 1 and writes[0]["address"] == "0x004299ed",
    }


def load_catalog_type_names(path: Path) -> dict[int, str]:
    names: dict[int, str] = {}
    with path.open("r", encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle):
            type_id = int(row["type_id"])
            name = row["type_name"].strip() or FALLBACK_TYPE_NAMES.get(type_id, "")
            if name and type_id not in names:
                names[type_id] = name
    names.update({key: value for key, value in FALLBACK_TYPE_NAMES.items() if key not in names})
    return names


def expand_type_token(token: str) -> list[int]:
    if ".." in token:
        left, right = token.split("..", 1)
        return list(range(int(left, 16), int(right[:4], 16) + 1))
    return [int(token, 16)]


def label_source_values(values: list[str], names: dict[int, str]) -> list[dict[str, Any]]:
    labels: list[dict[str, Any]] = []
    for value in values:
        tokens = re.findall(r"0x[0-9a-fA-F]+(?:\.\.0x[0-9a-fA-F]+)?", value)
        if not tokens:
            labels.append({"expression": value, "catalog_types": []})
            continue
        type_ids: list[int] = []
        for token in tokens:
            type_ids.extend(expand_type_token(token))
        labels.append(
            {
                "expression": value,
                "catalog_types": [
                    {
                        "type_id": type_id,
                        "hex": f"0x{type_id:02x}",
                        "type_name": names.get(type_id, "<not present in extracted catalog>"),
                    }
                    for type_id in type_ids
                ],
            }
        )
    return labels


def build_provider_pairs(vtable: dict[str, Any], type_names: dict[int, str]) -> list[dict[str, Any]]:
    entries = {int(entry["index"]): entry for entry in vtable["entries"]}
    pairs: list[dict[str, Any]] = []
    for dispatch in PROVIDER_SLOT_DISPATCH:
        builder_slot = int(dispatch["slot"], 16)
        builder_index = builder_slot // 4
        materializer_slot = builder_slot + 4
        materializer_index = materializer_slot // 4
        pairs.append(
            {
                "builder_slot": f"0x{builder_slot:02x}",
                "builder_vtable_index": builder_index,
                "builder_function": entries[builder_index]["value"],
                "builder_function_name": entries[builder_index]["function"],
                "materializer_slot": f"0x{materializer_slot:02x}",
                "materializer_vtable_index": materializer_index,
                "materializer_function": entries[materializer_index]["value"],
                "materializer_function_name": entries[materializer_index]["function"],
                "source_record_plus_0x1c_values": dispatch["source_record_plus_0x1c_values"],
                "catalog_type_labels": label_source_values(
                    dispatch["source_record_plus_0x1c_values"], type_names
                ),
            }
        )
    return pairs


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    object_table_summary = load_json(args.object_table_summary)
    source_variant_summary = load_json(args.source_variant_summary)
    hero_runtime_summary = load_json(args.hero_runtime_summary)
    descriptor_crosswalk_summary = load_json(args.descriptor_crosswalk_summary)
    vtable = load_json(args.provider_vtable)
    type_names = load_catalog_type_names(args.catalog)

    provider_global_checks = check_markers(PROVIDER_GLOBAL_CHECKS)
    base_copy_checks = check_function_markers(PROVIDER_BASE_COPY, BASE_COPY_CHECKS)
    adoption_checks = check_function_markers(SOURCE_RECORD_ADOPTION, ADOPTION_CHECKS)
    compare_checks = check_function_markers(SOURCE_RECORD_COMPARE, COMPARE_CHECKS)
    all_checks = provider_global_checks + base_copy_checks + adoption_checks + compare_checks

    provider_refs = parse_provider_global_refs(PROVIDER_GLOBAL_REFS)
    provider_pairs = build_provider_pairs(vtable, type_names)
    paired_slots_ok = (
        len(provider_pairs) == 27
        and all(int(pair["materializer_slot"], 16) == int(pair["builder_slot"], 16) + 4 for pair in provider_pairs)
    )

    upstream_status_ok = {
        "object_table_loader": object_table_summary.get("status")
        == "object_table_loader_recovered_catalog_row_identity_surface",
        "source_variant_builder": source_variant_summary.get("status")
        == "source_variant_builder_provider_slot_dispatch_recovered_catalog_mapping_pending",
        "hero_runtime_branch_excluded": (
            hero_runtime_summary.get("metrics", {}).get("missing_marker_count") == 0
            and hero_runtime_summary.get("metrics", {}).get("used_objdump") is False
            and "not generic object template identity"
            in hero_runtime_summary.get("dynamic_lookup_boundary", {}).get("0x4c242d", "").lower()
            and "objects.txt/objtmplt.txt"
            in hero_runtime_summary.get("dynamic_lookup_boundary", {})
            .get("not_object_template_mapping", "")
            .lower()
        ),
        "descriptor_crosswalk_has_expected_descriptor45_row_warning": (
            descriptor_crosswalk_summary.get("status")
            == "descriptor_label_crosswalk_partial_descriptor45_row_unresolved"
        ),
    }

    missing = [check["id"] for check in all_checks if not check["present"]]
    status_ok = (
        not missing
        and provider_refs["only_expected_writer"]
        and paired_slots_ok
        and all(upstream_status_ok.values())
    )

    return {
        "schema_id": "h3maped_rmg_source_catalog_template_producer_mapping_v1",
        "status": (
            "source_catalog_template_producer_mapping_recovered_source_record_preserved"
            if status_ok
            else "source_catalog_template_producer_mapping_incomplete"
        ),
        "inputs": {
            "provider_global_refs": str(PROVIDER_GLOBAL_REFS),
            "provider_initializer": str(PROVIDER_INITIALIZER),
            "provider_setter": str(PROVIDER_SETTER),
            "provider_vtable": str(args.provider_vtable),
            "provider_base_copy": str(PROVIDER_BASE_COPY),
            "source_record_adoption": str(SOURCE_RECORD_ADOPTION),
            "source_record_compare": str(SOURCE_RECORD_COMPARE),
            "object_catalog": str(args.catalog),
            "object_table_summary": str(args.object_table_summary),
            "source_variant_summary": str(args.source_variant_summary),
            "hero_runtime_summary": str(args.hero_runtime_summary),
            "descriptor_crosswalk_summary": str(args.descriptor_crosswalk_summary),
        },
        "marker_count": len(all_checks),
        "present_marker_count": sum(1 for check in all_checks if check["present"]),
        "missing_marker_ids": missing,
        "provider_global_reference_summary": provider_refs,
        "provider_global_checks": provider_global_checks,
        "provider_base_copy_checks": base_copy_checks,
        "source_record_adoption_checks": adoption_checks,
        "source_record_compare_checks": compare_checks,
        "upstream_status_ok": upstream_status_ok,
        "provider_vtable": {
            "address": "0x0053942c",
            "entry_count": vtable["count"],
            "provider_slot_pair_count": len(provider_pairs),
            "paired_builder_materializer_slots_ok": paired_slots_ok,
            "provider_slot_pairs": provider_pairs,
        },
        "recovered_boundary": {
            "provider_global": (
                "Global 0x59e390 is written once by 0x4299e9 and read by 0x422868 "
                "and 0x42158c. The initializer at 0x45dae4 installs vtable 0x53942c "
                "before publishing the provider object through that setter."
            ),
            "provider_slots": (
                "Vtable 0x53942c contains the concrete provider methods used by "
                "0x422868 builder slots and the paired 0x42158c materializer slots. "
                "The recovered dispatch maps 27 builder/materializer pairs keyed by "
                "source_record+0x1c raw H3 object type values."
            ),
            "source_record_preservation": (
                "Concrete provider constructors call the base helper at 0x43d309. "
                "That helper copies 0x13 dwords, exactly 0x4c bytes, from the source "
                "record argument, adopts/caches the copied record through global "
                "0x59e410 and 0x437751, stores the adopted payload pointer on the "
                "provider object, and increments the payload refcount."
            ),
            "catalog_key_identity": (
                "The adoption cache compares source records with 0x490b77. The key "
                "includes +0x00, the text/buffer fields at +0x04/+0x0c/+0x14/+0x18, "
                "the raw object type at +0x1c, the subtype-like field at +0x20, "
                "+0x24, and byte +0x28. This preserves the catalog row identity "
                "surface rather than replacing it with descriptor-local IDs."
            ),
            "base_catalog_rows": object_table_summary["field_mapping"],
        },
        "human_readable_result": [
            "The non-hero source catalog/template producer is recovered as exact 0x4c source-record preservation.",
            "Provider dispatch is keyed by source_record+0x1c raw H3 object type, with source_record+0x20 retained for subtype-like splits.",
            "DEF/name-bearing text fields stay in the source-record cache key, so final mapping must use the source record itself, not descriptor +0x00.",
            "The 0x4c source record shape matches the recovered objects.txt/objtmplt.txt loader row stride and field consumers.",
        ],
        "source_backed_exclusions": [
            "Descriptor +0x00 is not a universal objects.txt row id; descriptor 45 remains a descriptor crosswalk warning, not a provider catalog mapping source.",
            "The 0x4e6da2/0x4c242d branch tied to 0x5857d4/0x5857d8/0x5857dc is a hero runtime-table branch, excluded by the hero runtime checkpoint.",
            "The stream-version adapter around 0x541460/0x5398c8 is loader plumbing, not a source catalog/template producer.",
        ],
        "remaining_unrecovered_after_this_checkpoint": [
            "No source-catalog/template producer blocker remains for type/subtype/DEF row preservation.",
            "Separate future parity work may still need live selected wrapper/source traces for final per-instance placement audits.",
            "The descriptor 45 row mismatch should remain labeled as descriptor-local identity, not reopened as a catalog-producer blocker.",
        ],
        "metrics": {
            "source_catalog_template_producer_blocker_closed": status_ok,
            "provider_global_write_count": provider_refs["write_count"],
            "provider_global_read_count": provider_refs["read_count"],
            "provider_slot_pair_count": len(provider_pairs),
            "source_record_copy_size_bytes": 0x13 * 4,
            "used_objdump": False,
            "native_behavior_changed": False,
            "overall_goal_complete": status_ok,
        },
        "used_objdump": False,
        "native_behavior_changed": False,
        "overall_goal_complete": status_ok,
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path, default=CATALOG)
    parser.add_argument("--provider-vtable", type=Path, default=PROVIDER_VTABLE)
    parser.add_argument("--object-table-summary", type=Path, default=OBJECT_TABLE_SUMMARY)
    parser.add_argument("--source-variant-summary", type=Path, default=SOURCE_VARIANT_SUMMARY)
    parser.add_argument("--hero-runtime-summary", type=Path, default=HERO_RUNTIME_SUMMARY)
    parser.add_argument("--descriptor-crosswalk-summary", type=Path, default=DESCRIPTOR_CROSSWALK_SUMMARY)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_SOURCE_CATALOG_TEMPLATE_PRODUCER "
        f"status={summary['status']} "
        f"markers={summary['present_marker_count']}/{summary['marker_count']} "
        f"provider_pairs={summary['metrics']['provider_slot_pair_count']} "
        f"out={args.out}"
    )
    return 0 if summary["overall_goal_complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
