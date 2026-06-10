#!/usr/bin/env python3
"""Verify the current source-record identity frontier for H3MapEd RMG.

This is a recovery checkpoint only. It separates what is proved about the
source-handler key-to-payload chain from what is still not proved about final
object catalog/template identity.
"""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_LIVE_SOURCE_SUMMARY = ROOT / "4a8db2_4a901a_live_surface_summary_20260608.json"
DEFAULT_FIELD_SURFACE_SUMMARY = ROOT / "source_record_field_surface_summary_20260610.json"
DEFAULT_OBJECT_CATALOG = Path(
    "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-catalog-by-type.csv"
)
DEFAULT_OUT = ROOT / "source_record_identity_frontier_summary_20260610.json"

FILES = {
    "source_key_payload_mapper_0x42a83a": ROOT
    / "ghidra_53eafc_source_handler_nested_helpers_dump"
    / "target_0042a83a_FUN_0042a83a.txt",
    "source_payload_mapper_slot_0x42b62a": ROOT
    / "ghidra_53eafc_source_handler_helpers_dump"
    / "target_0042b62a_FUN_0042b62a.txt",
    "source_pair_mapper_slot_0x42b63b": ROOT
    / "ghidra_53eafc_source_handler_helpers_dump"
    / "target_0042b63b_FUN_0042b63b.txt",
    "source_first_key_slot_0x42b690": ROOT
    / "ghidra_53eafc_source_handler_helpers_dump"
    / "target_0042b690_FUN_0042b690.txt",
}

CHECKS: dict[str, list[dict[str, str]]] = {
    "source_key_payload_mapper_0x42a83a": [
        {
            "id": "reads_source_holder_record_table",
            "marker": "0042a83a: MOV ECX,dword ptr [ECX + 0xc]",
            "meaning": "The helper enters the source holder record table.",
        },
        {
            "id": "uses_stack_key_as_table_index",
            "marker": "0042a83d: MOV EAX,dword ptr [ESP + 0x4]",
            "meaning": "The helper consumes a stream key/index, not an object catalog row object.",
        },
        {
            "id": "multiplies_key_by_five_dwords",
            "marker": "0042a844: LEA EAX,[EAX + EAX*0x4]",
            "meaning": "The selected source-side record slot has five dwords.",
        },
        {
            "id": "loads_nested_payload_pointer_from_slot_0x10",
            "marker": "0042a84a: MOV EAX,dword ptr [EAX + 0x10]",
            "meaning": "The key resolves through the slot +0x10 pointer.",
        },
        {
            "id": "returns_payload_pointer_0x08",
            "marker": "0042a851: MOV EAX,dword ptr [EAX + 0x8]",
            "meaning": "The returned payload is a nested pointer at +0x08.",
        },
    ],
    "source_payload_mapper_slot_0x42b62a": [
        {
            "id": "unwraps_handler_source_pointer",
            "marker": "0042b62a: MOV ECX,dword ptr [ECX]",
            "meaning": "The vtable helper unwraps the concrete source pointer.",
        },
        {
            "id": "selects_source_subholder_0x04",
            "marker": "0042b630: ADD ECX,0x4",
            "meaning": "The vtable helper selects the source subholder used by 0x42a83a.",
        },
        {
            "id": "delegates_to_0x42a83a",
            "marker": "0042b633: CALL 0x0042a83a",
            "meaning": "The descriptor/source payload mapper is the 0x42a83a chain.",
        },
    ],
    "source_pair_mapper_slot_0x42b63b": [
        {
            "id": "copies_pair_first_dword_from_record_slot_0x08",
            "marker": "0042b64f: MOV ESI,dword ptr [ECX + EDX*0x4 + 0x8]",
            "meaning": "The pair slot copies the first dword from the same five-dword record family.",
        },
        {
            "id": "copies_pair_second_dword_from_record_slot_0x0c",
            "marker": "0042b656: MOV ECX,dword ptr [ECX + EDX*0x4 + 0xc]",
            "meaning": "The pair slot copies the second dword from the same five-dword record family.",
        },
    ],
    "source_first_key_slot_0x42b690": [
        {
            "id": "walks_to_stream_key_vector",
            "marker": "0042b692: MOV EAX,dword ptr [EAX + 0x10]",
            "meaning": "The first-key helper walks to the source stream vector.",
        },
        {
            "id": "loads_first_stream_key",
            "marker": "0042b698: MOV EAX,dword ptr [EAX]",
            "meaning": "The helper returns the first stream key.",
        },
    ],
}


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def summarize_file(key: str, path: Path) -> dict[str, Any]:
    text = read_text(path)
    checks = []
    for check in CHECKS[key]:
        checks.append({**check, "present": check["marker"] in text})
    return {
        "path": str(path),
        "exists": path.exists(),
        "check_count": len(checks),
        "present_check_count": sum(1 for check in checks if check["present"]),
        "checks": checks,
    }


def parse_hex_word(value: str) -> int:
    return int(value, 16)


def load_source_record_samples(path: Path) -> list[dict[str, Any]]:
    summary = read_json(path)
    samples: list[dict[str, Any]] = []
    for record in summary.get("source_records", []):
        fields = record.get("fields_by_offset", {})
        sample = {
            "event_index": record.get("event_index"),
            "source_record_pointer": record.get("source_record_pointer"),
            "local_key_plus_0x00": parse_hex_word(fields["+0x00"]),
            "mode_or_branch_plus_0x04": parse_hex_word(fields["+0x04"]),
            "lane_plus_0x1c": parse_hex_word(fields["+0x1c"]),
            "metadata_plus_0x20": parse_hex_word(fields["+0x20"]),
            "metadata_plus_0x24": parse_hex_word(fields["+0x24"]),
            "relation_state_plus_0x28": parse_hex_word(fields["+0x28"]),
            "raw_fields_0x00_to_0x4c": {
                offset: fields[offset]
                for offset in (
                    "+0x00",
                    "+0x04",
                    "+0x08",
                    "+0x0c",
                    "+0x10",
                    "+0x14",
                    "+0x18",
                    "+0x1c",
                    "+0x20",
                    "+0x24",
                    "+0x28",
                    "+0x2c",
                    "+0x30",
                    "+0x34",
                    "+0x38",
                    "+0x3c",
                    "+0x40",
                    "+0x44",
                    "+0x48",
                    "+0x4c",
                )
                if offset in fields
            },
        }
        samples.append(sample)
    return samples


def load_catalog(path: Path) -> dict[int, dict[str, Any]]:
    rows: dict[int, dict[str, Any]] = {}
    if not path.exists():
        return rows
    with path.open("r", encoding="utf-8", newline="") as fh:
        for row in csv.DictReader(fh):
            source_row = int(row["source_row"])
            rows[source_row] = {
                "source": row["source"],
                "source_row": source_row,
                "zero_based_row": source_row - 1,
                "def_name": row["def_name"],
                "type_id": int(row["type_id"]),
                "type_name": row["type_name"],
                "subtype": int(row["subtype"]),
            }
    return rows


def summarize_catalog_interpretation(
    samples: list[dict[str, Any]], catalog_rows: dict[int, dict[str, Any]]
) -> dict[str, Any]:
    zero_based_matches = []
    one_based_matches = []
    for sample in samples:
        key = sample["local_key_plus_0x00"]
        zero_row = catalog_rows.get(key + 1)
        one_row = catalog_rows.get(key)
        zero_based_matches.append(
            {
                "local_key_plus_0x00": key,
                "catalog_rule": "source_row = local_key + 1",
                "catalog_row": zero_row,
            }
        )
        one_based_matches.append(
            {
                "local_key_plus_0x00": key,
                "catalog_rule": "source_row = local_key",
                "catalog_row": one_row,
            }
        )

    keys = [sample["local_key_plus_0x00"] for sample in samples]
    dense_zero_based = keys == list(range(len(keys)))
    one_based_has_missing = any(match["catalog_row"] is None for match in one_based_matches)
    return {
        "sampled_local_keys": keys,
        "sampled_keys_are_dense_zero_based": dense_zero_based,
        "one_based_catalog_interpretation_has_missing_key": one_based_has_missing,
        "zero_based_catalog_rows_for_context_only": zero_based_matches,
        "one_based_catalog_rows_for_context_only": one_based_matches,
        "object_catalog_identity_proven": False,
        "why_not_identity": (
            "The live +0x00 sample is a dense local stream-key sequence, while Ghidra proves "
            "0x42a83a uses that key to index five-dword source-side slots and returns a "
            "nested payload pointer. The current artifacts do not recover the producer that "
            "populates that nested payload from objects.txt/objtmplt.txt rows."
        ),
    }


def summarize(
    live_source_summary_path: Path,
    field_surface_summary_path: Path,
    object_catalog_path: Path,
) -> dict[str, Any]:
    files = {key: summarize_file(key, path) for key, path in FILES.items()}
    all_checks = [check for result in files.values() for check in result["checks"]]
    missing = [check["id"] for check in all_checks if not check["present"]]

    source_samples = load_source_record_samples(live_source_summary_path)
    catalog_rows = load_catalog(object_catalog_path)
    catalog_interpretation = summarize_catalog_interpretation(source_samples, catalog_rows)
    field_surface_summary = read_json(field_surface_summary_path)

    field_surface_ready = (
        field_surface_summary.get("status")
        == "source_record_field_surface_recovered_identity_mapping_pending"
    )
    sample_keys_ready = bool(source_samples) and catalog_interpretation[
        "sampled_keys_are_dense_zero_based"
    ]
    status = (
        "source_record_identity_frontier_recovered_producer_mapping_pending"
        if not missing and field_surface_ready and sample_keys_ready
        else "incomplete"
    )

    return {
        "schema_id": "h3maped_source_record_identity_frontier_summary_v1",
        "status": status,
        "scope": (
            "Ghidra/Wine/Python checkpoint for source-handler stream keys and copied "
            "0x4c source records. This names the remaining producer mapping blocker and "
            "does not authorize native RMG behavior changes."
        ),
        "inputs": {
            "live_source_summary": str(live_source_summary_path),
            "field_surface_summary": str(field_surface_summary_path),
            "object_catalog": str(object_catalog_path),
            "ghidra_files": {key: str(path) for key, path in FILES.items()},
        },
        "files": files,
        "field_surface_ready": field_surface_ready,
        "source_record_samples": source_samples,
        "catalog_interpretation": catalog_interpretation,
        "recovered": [
            "0x42b690 returns stream keys from the selected source stream vector.",
            "0x42b62a unwraps the concrete source pointer and delegates stream-key payload lookup to 0x42a83a.",
            "0x42a83a maps a stream key into a five-dword source-side record slot, then returns the nested pointer at slot +0x10 -> +0x08.",
            "0x42b63b copies the two-dword pair at the same five-dword record slot +0x08/+0x0c.",
            "The sampled copied source-record +0x00 values are a dense local key sequence, not recovered final object identities.",
        ],
        "remaining_gap": (
            "Recover the exact source catalog/template producer that populates the nested "
            "payload pointer returned by 0x42a83a and connects copied 0x4c source records "
            "to objects.txt/objtmplt.txt type/subtype/DEF rows. Until that producer is "
            "recovered, source-record +0x00 and descriptor +0x00 cannot be used as universal "
            "final object identity."
        ),
        "metrics": {
            "marker_count": len(all_checks),
            "present_marker_count": sum(1 for check in all_checks if check["present"]),
            "missing_marker_count": len(missing),
            "source_record_sample_count": len(source_samples),
            "catalog_row_count": len(catalog_rows),
            "used_objdump": False,
            "native_behavior_changed": False,
            "overall_goal_complete": False,
        },
        "missing_markers": missing,
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--live-source-summary", type=Path, default=DEFAULT_LIVE_SOURCE_SUMMARY)
    parser.add_argument("--field-surface-summary", type=Path, default=DEFAULT_FIELD_SURFACE_SUMMARY)
    parser.add_argument("--object-catalog", type=Path, default=DEFAULT_OBJECT_CATALOG)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args.live_source_summary, args.field_surface_summary, args.object_catalog)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    metrics = summary["metrics"]
    print(
        "RMG_H3MAPED_SOURCE_RECORD_IDENTITY_FRONTIER "
        f"status={summary['status']} "
        f"markers={metrics['present_marker_count']}/{metrics['marker_count']} "
        f"samples={metrics['source_record_sample_count']} "
        f"out={args.out}"
    )
    return (
        0
        if summary["status"]
        == "source_record_identity_frontier_recovered_producer_mapping_pending"
        else 1
    )


if __name__ == "__main__":
    raise SystemExit(main())
