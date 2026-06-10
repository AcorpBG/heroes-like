#!/usr/bin/env python3
"""Classify whether recovered descriptor +0x00 words are object-catalog rows.

This is a recovery checkpoint, not a native RMG behavior change. It consumes
existing Wine/Ghidra/Python summaries and extracted H3MapEd object tables to
separate row-like descriptor samples from descriptor-local class words.
"""

from __future__ import annotations

import argparse
import csv
import json
from collections import defaultdict
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_DESCRIPTOR_SUMMARIES = [
    ROOT / "medium_seed10_4a54a7_descriptor_relation_summary_20260608.json",
    ROOT / "medium_seed10_fallback_exact_descriptor_relation_summary_20260609.json",
]
DEFAULT_OBJECT_METADATA = Path(
    "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-metadata-by-type.json"
)
DEFAULT_OBJECT_CATALOG = Path(
    "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-catalog-by-type.csv"
)
DEFAULT_OUT = ROOT / "descriptor_word_row_mode_summary_20260610.json"


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def load_catalog(path: Path) -> dict[int, dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return {
            int(row["source_row"]) - 1: row
            for row in csv.DictReader(handle)
            if row.get("source_row")
        }


def qcoord(invocation: dict[str, Any]) -> dict[str, Any] | None:
    coordinate = invocation.get("object_coordinate")
    if not isinstance(coordinate, dict):
        return None
    return {
        "x": coordinate.get("x"),
        "y": coordinate.get("y"),
        "level": coordinate.get("level"),
    }


def collect_samples(
    descriptor_paths: list[Path],
    catalog_by_zero_based_row: dict[int, dict[str, str]],
    metadata_by_type: dict[int, dict[str, Any]],
) -> list[dict[str, Any]]:
    samples: list[dict[str, Any]] = []
    for path in descriptor_paths:
        summary = load_json(path)
        for ordinal, invocation in enumerate(summary.get("invocations", [])):
            descriptor = invocation.get("descriptor", {})
            descriptor_word = descriptor.get("id_or_class_word_0x00")
            descriptor_type = descriptor.get("type_index_from_descriptor_plus_0x1c")
            if not isinstance(descriptor_word, int) or not isinstance(descriptor_type, int):
                continue

            row = catalog_by_zero_based_row.get(descriptor_word)
            row_matches_type = bool(row and int(row["type_id"]) == descriptor_type)
            metadata = metadata_by_type.get(descriptor_type)
            samples.append(
                {
                    "source_summary": str(path),
                    "ordinal": invocation.get("ordinal", ordinal),
                    "return_address": invocation.get("return_address"),
                    "object_record_pointer": invocation.get("object_record_pointer"),
                    "object_coordinate": qcoord(invocation),
                    "descriptor_pointer": descriptor.get("pointer"),
                    "descriptor_word_plus_0x00": descriptor_word,
                    "descriptor_type_plus_0x1c": descriptor_type,
                    "descriptor_type_metadata_name": metadata.get("type_name") if metadata else None,
                    "zero_based_catalog_row": (
                        {
                            "source_row": int(row["source_row"]),
                            "def_name": row["def_name"],
                            "type_id": int(row["type_id"]),
                            "type_name": row["type_name"],
                            "subtype": int(row["subtype"]),
                        }
                        if row
                        else None
                    ),
                    "row_mode_status": (
                        "zero_based_catalog_row_matches_descriptor_type"
                        if row_matches_type
                        else (
                            "zero_based_catalog_row_type_mismatch"
                            if row
                            else "zero_based_catalog_row_missing"
                        )
                    ),
                    "projection_flag_plus_0x29": descriptor.get("projection_flag_plus_0x29"),
                    "mask_width_plus_0x34": descriptor.get("mask_width_plus_0x34"),
                    "mask_height_plus_0x38": descriptor.get("mask_height_plus_0x38"),
                    "relation_counter_incremented_by_one": invocation.get(
                        "relation_counter", {}
                    ).get("counter_incremented_by_one"),
                    "source_coordinate_matches_descriptor_offsets": invocation.get(
                        "source_cell", {}
                    ).get("coordinate_matches_descriptor_offset_source"),
                }
            )
    return samples


def summarize_group(samples: list[dict[str, Any]]) -> dict[str, Any]:
    matched = [
        sample
        for sample in samples
        if sample["row_mode_status"] == "zero_based_catalog_row_matches_descriptor_type"
    ]
    mismatched = [
        sample
        for sample in samples
        if sample["row_mode_status"] == "zero_based_catalog_row_type_mismatch"
    ]
    missing = [
        sample
        for sample in samples
        if sample["row_mode_status"] == "zero_based_catalog_row_missing"
    ]
    return {
        "sample_count": len(samples),
        "row_match_count": len(matched),
        "row_mismatch_count": len(mismatched),
        "row_missing_count": len(missing),
        "descriptor_words": sorted(
            {sample["descriptor_word_plus_0x00"] for sample in samples}
        ),
        "return_addresses": sorted(
            {sample["return_address"] for sample in samples if sample.get("return_address")}
        ),
        "row_mode_classification": (
            "all_sampled_words_row_like"
            if len(matched) == len(samples)
            else (
                "no_sampled_words_row_like"
                if not matched
                else "mixed_row_like_and_class_word"
            )
        ),
        "mismatch_examples": [
            {
                "descriptor_word_plus_0x00": sample["descriptor_word_plus_0x00"],
                "descriptor_type_plus_0x1c": sample["descriptor_type_plus_0x1c"],
                "descriptor_type_metadata_name": sample["descriptor_type_metadata_name"],
                "zero_based_catalog_row": sample["zero_based_catalog_row"],
                "return_address": sample["return_address"],
                "object_coordinate": sample["object_coordinate"],
            }
            for sample in mismatched[:8]
        ],
    }


def group_by(samples: list[dict[str, Any]], *keys: str) -> dict[str, Any]:
    grouped: dict[tuple[Any, ...], list[dict[str, Any]]] = defaultdict(list)
    for sample in samples:
        grouped[tuple(sample.get(key) for key in keys)].append(sample)
    result: dict[str, Any] = {}
    for key, group in sorted(grouped.items(), key=lambda item: tuple(str(part) for part in item[0])):
        label = " | ".join(str(part) for part in key)
        result[label] = summarize_group(group)
    return result


def build_summary(args: argparse.Namespace) -> dict[str, Any]:
    catalog_by_zero_based_row = load_catalog(args.object_catalog)
    metadata = load_json(args.object_metadata)
    metadata_by_type = {int(entry["type_id"]): entry for entry in metadata["entries"]}
    samples = collect_samples(args.descriptor_summary, catalog_by_zero_based_row, metadata_by_type)

    overall = summarize_group(samples)
    by_type = group_by(samples, "descriptor_type_plus_0x1c")
    by_return_and_type = group_by(samples, "return_address", "descriptor_type_plus_0x1c")
    mismatch_samples = [
        sample
        for sample in samples
        if sample["row_mode_status"] == "zero_based_catalog_row_type_mismatch"
    ]

    invariants = {
        "samples_present": bool(samples),
        "no_native_behavior_change": True,
        "no_objdump_used": True,
        "all_row_mismatch_samples_have_relation_counter_and_coordinate_checks": all(
            sample.get("relation_counter_incremented_by_one") is True
            and sample.get("source_coordinate_matches_descriptor_offsets") is True
            for sample in mismatch_samples
        ),
        "descriptor_word_plus_0x00_not_universal_row_pointer": bool(mismatch_samples),
        "type45_descriptor_word_1145_is_not_catalog_monolith_row": any(
            sample["descriptor_type_plus_0x1c"] == 45
            and sample["descriptor_word_plus_0x00"] == 1145
            and sample["zero_based_catalog_row"]
            and sample["zero_based_catalog_row"]["type_name"] != "Monolith Two Way"
            for sample in mismatch_samples
        ),
        "type98_current_exact_samples_are_row_like": by_type.get("98", {}).get(
            "row_mode_classification"
        )
        == "all_sampled_words_row_like",
        "some_non98_samples_are_mixed_or_class_word": any(
            group.get("row_mode_classification") != "all_sampled_words_row_like"
            for key, group in by_type.items()
            if key != "98"
        ),
    }

    status = (
        "descriptor_word_row_mode_mixed_class_word_recovered"
        if all(invariants.values())
        else "descriptor_word_row_mode_incomplete"
    )

    return {
        "schema_id": "h3maped_descriptor_word_row_mode_summary_v1",
        "status": status,
        "scope": (
            "Classifies sampled descriptor +0x00 words from exact 0x4a54a7 "
            "descriptor/relation Wine summaries. This does not change native RMG "
            "behavior and does not assign final object identity from row-like matches."
        ),
        "inputs": {
            "descriptor_summaries": [str(path) for path in args.descriptor_summary],
            "object_metadata": str(args.object_metadata),
            "object_catalog": str(args.object_catalog),
        },
        "invariants": invariants,
        "metrics": {
            "sample_count": overall["sample_count"],
            "row_match_count": overall["row_match_count"],
            "row_mismatch_count": overall["row_mismatch_count"],
            "row_missing_count": overall["row_missing_count"],
            "descriptor_type_count": len(by_type),
            "native_behavior_changed": False,
            "used_objdump": False,
            "overall_goal_complete": False,
        },
        "overall_row_mode": overall,
        "by_descriptor_type": by_type,
        "by_return_address_and_descriptor_type": by_return_and_type,
        "mismatch_samples": mismatch_samples,
        "source_backed_conclusion": (
            "Descriptor +0x00 is not a universal zero-based objects.txt row pointer. "
            "In the exact sampled 0x4a54a7 descriptor/relation corpus, descriptor type "
            "98 samples are row-like against Town rows, but type 45 word 1145 maps to "
            "a Cartographer row under the same row rule while descriptor+0x1c is the "
            "Monolith Two Way lane. Additional type 53, 54, and 79 fallback samples also "
            "show row mismatches. Therefore descriptor+0x1c may be used as a recovered "
            "counter/type lane, while descriptor+0x00 must be treated as producer-context "
            "descriptor data until the responsible constructor/selector path proves a "
            "specific row relation."
        ),
        "remaining_blockers": [
            (
                "Recover the producer/constructor paths that assign descriptor +0x00 "
                "for the mismatched type 45, 53, 54, and 79 samples."
            ),
            (
                "Do not infer final object identity for descriptor commits from "
                "descriptor+0x1c labels or descriptor+0x00 numeric coincidence alone."
            ),
            (
                "Continue the broader endpoint/direct-mutation recovery blockers before "
                "any native RMG behavior port."
            ),
        ],
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--descriptor-summary",
        type=Path,
        action="append",
        default=None,
        help="Exact descriptor/relation summary JSON. Repeatable.",
    )
    parser.add_argument("--object-metadata", type=Path, default=DEFAULT_OBJECT_METADATA)
    parser.add_argument("--object-catalog", type=Path, default=DEFAULT_OBJECT_CATALOG)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    if args.descriptor_summary is None:
        args.descriptor_summary = DEFAULT_DESCRIPTOR_SUMMARIES
    summary = build_summary(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    metrics = summary["metrics"]
    print(
        "RMG_H3MAPED_DESCRIPTOR_WORD_ROW_MODE_SUMMARY "
        f"status={summary['status']} "
        f"samples={metrics['sample_count']} "
        f"row_matches={metrics['row_match_count']} "
        f"row_mismatches={metrics['row_mismatch_count']} "
        f"out={args.out}"
    )
    return 0 if summary["status"] == "descriptor_word_row_mode_mixed_class_word_recovered" else 1


if __name__ == "__main__":
    raise SystemExit(main())
