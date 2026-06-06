#!/usr/bin/env python3
"""Compare H3MapEd private generated-cell state with native phase snapshots.

This tool is intentionally a private-state checkpoint comparator, not a final
map density gate. It compares the generated-cell words consumed by H3MapEd at
0x4a4c8e and the relation records consumed by 0x49b3fb when matching H3MapEd
trace material is available.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path
from typing import Any


CELL_SCHEMA = "h3maped_private_state_checkpoint_0x4a4c8e_generated_cells_v1"
RELATION_SCHEMA = "h3maped_private_state_checkpoint_0x49b3fb_relations_v1"
DWORD_LINE_RE = re.compile(r"(?:^|>)\s*(?:0x)?([0-9a-fA-F]+):\s+(.+)$")
HEX_WORD_RE = re.compile(r"\b[0-9a-fA-F]{1,8}\b")


def as_uint32(value: Any) -> int:
    return int(value) & 0xFFFFFFFF


def signed_byte(value: int) -> int:
    value &= 0xFF
    return value - 0x100 if value >= 0x80 else value


def walk_dicts(value: Any):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from walk_dicts(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk_dicts(child)


def find_checkpoint(snapshot: dict[str, Any], schema_id: str, checkpoint_id: str = "") -> dict[str, Any] | None:
    matches: list[dict[str, Any]] = []
    for candidate in walk_dicts(snapshot):
        if candidate.get("schema_id") == schema_id:
            if checkpoint_id and str(candidate.get("checkpoint_id", "")) != checkpoint_id:
                matches.append(candidate)
                continue
            return candidate
    if checkpoint_id and matches:
        available = sorted(str(candidate.get("checkpoint_id", "")) for candidate in matches)
        raise ValueError(f"Native phase snapshot is missing {schema_id} checkpoint_id={checkpoint_id!r}; available={available}")
    return None


def parse_h3maped_generated_cell_dump(path: Path, expected_cell_count: int, base_address: int | None) -> list[dict[str, Any]]:
    words: list[int] = []
    collecting = base_address is None
    for line in path.read_text(errors="replace").splitlines():
        match = DWORD_LINE_RE.search(line)
        if not match:
            continue
        address = int(match.group(1), 16)
        if base_address is not None and address == base_address:
            collecting = True
        if not collecting:
            continue
        for token in HEX_WORD_RE.findall(match.group(2)):
            words.append(int(token, 16) & 0xFFFFFFFF)

    words_per_cell = 12
    required_words = expected_cell_count * words_per_cell
    if len(words) < required_words:
        raise ValueError(
            f"H3MapEd cell dump has {len(words)} dwords, needs {required_words} "
            f"for {expected_cell_count} cells at 0x30 stride"
        )

    records: list[dict[str, Any]] = []
    for flat in range(expected_cell_count):
        base = flat * words_per_cell
        word_0x20 = words[base + 8]
        word_0x24 = words[base + 9]
        word_0x28 = words[base + 10]
        records.append(
            {
                "flat": flat,
                "word_0x20": word_0x20,
                "word_0x24": word_0x24,
                "word_0x28": word_0x28,
                "owner_byte2_signed": signed_byte(word_0x20 >> 16),
                "owner_byte3_signed": signed_byte(word_0x20 >> 24),
            }
        )
    return records


def normalize_native_cells(checkpoint: dict[str, Any]) -> dict[int, dict[str, Any]]:
    records = checkpoint.get("records", [])
    if not isinstance(records, list):
        raise ValueError("Native generated-cell checkpoint records field is not a list")
    result: dict[int, dict[str, Any]] = {}
    for record in records:
        if not isinstance(record, dict):
            continue
        flat = int(record.get("flat", -1))
        if flat < 0:
            continue
        result[flat] = {
            "flat": flat,
            "word_0x20": as_uint32(record.get("word_0x20", 0)),
            "word_0x24": as_uint32(record.get("word_0x24", 0)),
            "word_0x28": as_uint32(record.get("word_0x28", 0)),
            "owner_byte2_signed": int(record.get("owner_byte2_signed", signed_byte(as_uint32(record.get("word_0x20", 0)) >> 16))),
            "owner_byte3_signed": int(record.get("owner_byte3_signed", signed_byte(as_uint32(record.get("word_0x20", 0)) >> 24))),
            "terrain_code": int(record.get("terrain_code", -1)),
            "x": int(record.get("x", -1)),
            "y": int(record.get("y", -1)),
            "level": int(record.get("level", -1)),
        }
    return result


def string_key_histogram(counter: Counter[int]) -> dict[str, int]:
    return {str(key): count for key, count in sorted(counter.items())}


def top_counts(counter: Counter[int], limit: int = 20) -> list[dict[str, int]]:
    return [{"value": key, "count": count} for key, count in counter.most_common(limit)]


def summarize_cells(records: list[dict[str, Any]] | dict[int, dict[str, Any]]) -> dict[str, Any]:
    values = records.values() if isinstance(records, dict) else records
    owner_byte2: Counter[int] = Counter()
    owner_byte3: Counter[int] = Counter()
    terrain_bits: Counter[int] = Counter()
    art_bits: Counter[int] = Counter()
    word_0x28_top_byte: Counter[int] = Counter()
    terrain_code: Counter[int] = Counter()
    bit22 = 0
    bit25 = 0
    bit26 = 0
    bit27 = 0
    count = 0
    for record in values:
        if not isinstance(record, dict):
            continue
        count += 1
        word_0x20 = as_uint32(record.get("word_0x20", 0))
        word_0x24 = as_uint32(record.get("word_0x24", 0))
        word_0x28 = as_uint32(record.get("word_0x28", 0))
        owner_byte2[int(record.get("owner_byte2_signed", signed_byte(word_0x20 >> 16)))] += 1
        owner_byte3[int(record.get("owner_byte3_signed", signed_byte(word_0x20 >> 24)))] += 1
        terrain_bits[word_0x24 & 0x3F] += 1
        art_bits[(word_0x24 >> 6) & 0xFF] += 1
        word_0x28_top_byte[(word_0x28 >> 24) & 0xFF] += 1
        if "terrain_code" in record:
            terrain_code[int(record.get("terrain_code", -1))] += 1
        bit22 += 1 if word_0x28 & (1 << 22) else 0
        bit25 += 1 if word_0x28 & (1 << 25) else 0
        bit26 += 1 if word_0x28 & (1 << 26) else 0
        bit27 += 1 if word_0x28 & (1 << 27) else 0
    return {
        "cell_count": count,
        "word_0x28_bit22_count": bit22,
        "word_0x28_bit25_count": bit25,
        "word_0x28_bit26_count": bit26,
        "word_0x28_bit27_count": bit27,
        "owner_byte2_signed_histogram": string_key_histogram(owner_byte2),
        "owner_byte3_signed_histogram": string_key_histogram(owner_byte3),
        "word_0x24_terrain_histogram": string_key_histogram(terrain_bits),
        "word_0x24_art_histogram": string_key_histogram(art_bits),
        "word_0x28_top_byte_histogram": string_key_histogram(word_0x28_top_byte),
        "terrain_code_histogram": string_key_histogram(terrain_code),
        "top_owner_byte2_signed": top_counts(owner_byte2),
        "top_word_0x28_top_byte": top_counts(word_0x28_top_byte),
    }


def compare_cells(h3_records: list[dict[str, Any]], native_records: dict[int, dict[str, Any]], max_mismatches: int) -> dict[str, Any]:
    mismatch_counts: Counter[str] = Counter()
    mismatches: list[dict[str, Any]] = []
    for h3 in h3_records:
        flat = int(h3["flat"])
        native = native_records.get(flat)
        if native is None:
            mismatch_counts["native_record_missing"] += 1
            if len(mismatches) < max_mismatches:
                mismatches.append({"flat": flat, "fields": ["native_record_missing"], "h3maped": h3})
            continue

        fields: list[str] = []
        for field in ("word_0x20", "word_0x24", "word_0x28", "owner_byte2_signed", "owner_byte3_signed"):
            if int(h3[field]) != int(native[field]):
                mismatch_counts[f"{field}_mismatch"] += 1
                fields.append(field)
        if fields and len(mismatches) < max_mismatches:
            mismatches.append(
                {
                    "flat": flat,
                    "x": native.get("x", -1),
                    "y": native.get("y", -1),
                    "level": native.get("level", -1),
                    "fields": fields,
                    "h3maped": {field: h3.get(field) for field in fields},
                    "native": {field: native.get(field) for field in fields},
                    "native_terrain_code": native.get("terrain_code", -1),
                }
            )
    return {
        "status": "pass" if not mismatch_counts else "mismatch",
        "mismatch_counts": dict(sorted(mismatch_counts.items())),
        "first_mismatches": mismatches,
    }


def relation_key(record: dict[str, Any]) -> tuple[int, int, int]:
    return (
        int(record.get("relation_owner_key", record.get("owner_key", -1))),
        int(record.get("first_dword_zone_word_id", -1)),
        int(record.get("byte_plus_8_wide", 0)),
    )


def relation_summary(checkpoint: dict[str, Any] | None, h3_relations: Any | None) -> dict[str, Any]:
    native_records = checkpoint.get("records", []) if isinstance(checkpoint, dict) else []
    native_counter: Counter[tuple[int, int, int]] = Counter()
    owner_counts: Counter[int] = Counter()
    for record in native_records if isinstance(native_records, list) else []:
        if not isinstance(record, dict):
            continue
        native_counter[relation_key(record)] += 1
        owner_counts[int(record.get("relation_owner_key", record.get("owner_key", -1)))] += 1

    summary: dict[str, Any] = {
        "native_status": checkpoint.get("status", "missing") if isinstance(checkpoint, dict) else "missing",
        "native_record_count": sum(native_counter.values()),
        "native_owner_key_count": len(owner_counts),
        "native_top_owner_counts": [{"owner_key": key, "count": count} for key, count in owner_counts.most_common(20)],
    }
    if h3_relations is None:
        summary["status"] = "h3_relation_snapshot_missing"
        return summary
    summary["status"] = "h3_relation_compare_not_implemented_for_input_shape"
    return summary


def build_report(args: argparse.Namespace) -> dict[str, Any]:
    snapshot = json.loads(args.native_phase_snapshot.read_text())
    cell_checkpoint = find_checkpoint(snapshot, CELL_SCHEMA, args.native_checkpoint_id)
    relation_checkpoint = find_checkpoint(snapshot, RELATION_SCHEMA)
    if cell_checkpoint is None:
        raise ValueError(f"Native phase snapshot is missing {CELL_SCHEMA}")

    native_cells = normalize_native_cells(cell_checkpoint)
    expected_cell_count = int(args.expected_cell_count or cell_checkpoint.get("cell_count", len(native_cells)))
    native_summary = summarize_cells(native_cells)
    report: dict[str, Any] = {
        "schema_id": "rmg_h3maped_private_state_compare_v1",
        "native_phase_snapshot": str(args.native_phase_snapshot),
        "h3maped_cell_dump": str(args.h3maped_cell_dump) if args.h3maped_cell_dump else "",
        "expected_cell_count": expected_cell_count,
        "native_checkpoint_id": str(cell_checkpoint.get("checkpoint_id", "")),
        "native": {
            "cell_checkpoint_status": cell_checkpoint.get("status", "unknown"),
            "cell_checkpoint_id": cell_checkpoint.get("checkpoint_id", ""),
            "cell_checkpoint_anchor": cell_checkpoint.get("h3maped_entry_anchor", ""),
            "cell_count": len(native_cells),
            "generated_cell_summary": native_summary,
            "relation_checkpoint_status": relation_checkpoint.get("status", "missing") if isinstance(relation_checkpoint, dict) else "missing",
        },
    }

    if args.h3maped_cell_dump:
        base_address = int(str(args.h3maped_cell_base_address), 0) if args.h3maped_cell_base_address else None
        h3_cells = parse_h3maped_generated_cell_dump(args.h3maped_cell_dump, expected_cell_count, base_address)
        report["generated_cells"] = compare_cells(h3_cells, native_cells, args.max_mismatches)
        report["generated_cells"]["h3maped_summary"] = summarize_cells(h3_cells)
        report["generated_cells"]["native_summary"] = native_summary
    else:
        report["generated_cells"] = {
            "status": "h3_cell_dump_missing",
            "native_summary": native_summary,
        }

    h3_relations: Any | None = None
    if args.h3maped_relations_json:
        h3_relations = json.loads(args.h3maped_relations_json.read_text())
    report["relations"] = relation_summary(relation_checkpoint, h3_relations)
    report["status"] = "mismatch" if report["generated_cells"].get("status") == "mismatch" else "diagnostic"
    return report


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native-phase-snapshot", type=Path, required=True, help="Native .phase_snapshot.json with private checkpoints.")
    parser.add_argument("--native-checkpoint-id", default="", help="Optional native generated-cell checkpoint_id to compare, e.g. pre_0x4a4c8e.")
    parser.add_argument("--h3maped-cell-dump", type=Path, default=None, help="winedbg memory dump from 0x4a4c8e entry: x/15552x *(int*)($esi+0x14).")
    parser.add_argument("--h3maped-cell-base-address", default="", help="Optional hex base address for the first generated cell line; ignores earlier debugger memory dumps.")
    parser.add_argument("--h3maped-relations-json", type=Path, default=None, help="Optional parsed H3MapEd relation records, if available.")
    parser.add_argument("--expected-cell-count", type=int, default=0, help="Expected generated-cell count; defaults to native checkpoint cell_count.")
    parser.add_argument("--max-mismatches", type=int, default=50, help="Maximum mismatching cell records to include.")
    parser.add_argument("--out", type=Path, required=True, help="JSON report path.")
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        report = build_report(args)
    except Exception as exc:
        print(f"RMG_H3MAPED_PRIVATE_STATE_COMPARE status=fail error={exc}", file=sys.stderr)
        return 1

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    generated = report.get("generated_cells", {})
    print(
        "RMG_H3MAPED_PRIVATE_STATE_COMPARE status={status} generated_cells={generated_status} "
        "native_cells={native_cells} report={report_path}".format(
            status=report.get("status"),
            generated_status=generated.get("status"),
            native_cells=report.get("native", {}).get("cell_count"),
            report_path=args.out,
        )
    )
    if isinstance(generated.get("mismatch_counts"), dict):
        print(json.dumps(generated["mismatch_counts"], sort_keys=True))
    native_summary = generated.get("native_summary") if isinstance(generated, dict) else None
    h3_summary = generated.get("h3maped_summary") if isinstance(generated, dict) else None
    if isinstance(native_summary, dict):
        print(
            "native checkpoint={checkpoint} bit26={bit26} bit27={bit27} top_owner2={owner2}".format(
                checkpoint=report.get("native_checkpoint_id", ""),
                bit26=native_summary.get("word_0x28_bit26_count"),
                bit27=native_summary.get("word_0x28_bit27_count"),
                owner2=native_summary.get("top_owner_byte2_signed", [])[:5],
            )
        )
    if isinstance(h3_summary, dict):
        print(
            "h3maped bit26={bit26} bit27={bit27} top_owner2={owner2}".format(
                bit26=h3_summary.get("word_0x28_bit26_count"),
                bit27=h3_summary.get("word_0x28_bit27_count"),
                owner2=h3_summary.get("top_owner_byte2_signed", [])[:5],
            )
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
