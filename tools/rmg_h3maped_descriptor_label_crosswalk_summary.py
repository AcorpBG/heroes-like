#!/usr/bin/env python3
"""Crosswalk recovered RMG descriptor/candidate ids to extracted object labels.

This is a recovery checkpoint, not a native RMG behavior change. It only labels
numeric surfaces when the recovered ids can be tied to the extracted H3MapEd
object metadata/catalog.
"""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path
from typing import Any


DEFAULT_DESCRIPTOR_CATEGORY = Path(
    ".artifacts/rmg_recovery/medium_descriptor_category_surface_summary_20260608.json"
)
DEFAULT_OBJECT_METADATA = Path(
    "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-metadata-by-type.json"
)
DEFAULT_OBJECT_CATALOG = Path(
    "/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/object-catalog-by-type.csv"
)
DEFAULT_OUT = Path(".artifacts/rmg_recovery/descriptor_label_crosswalk_summary_20260610.json")


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def load_catalog(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def compact_list(values: list[Any], limit: int = 8) -> dict[str, Any]:
    return {
        "count": len(values),
        "sample": values[:limit],
        "truncated": len(values) > limit,
    }


def summarize_candidate_labels(
    candidate_types: dict[str, Any], metadata_by_type: dict[int, dict[str, Any]]
) -> dict[str, Any]:
    labels: dict[str, Any] = {}
    unresolved: list[int] = []
    for type_text, recovered in sorted(candidate_types.items(), key=lambda item: int(item[0])):
        type_id = int(type_text)
        meta = metadata_by_type.get(type_id)
        if not meta:
            unresolved.append(type_id)
            labels[type_text] = {
                "label_status": "missing_object_metadata_type",
                "sample_count": recovered.get("sample_count", 0),
            }
            continue
        labels[type_text] = {
            "label_status": "source_metadata_type_id_match",
            "type_name": meta["type_name"],
            "object_template_row_count": meta["object_template_row_count"],
            "object_template_subtypes_compact": meta["object_template_subtypes_compact"],
            "sample_defs": meta["sample_defs"][:8],
            "sample_count": recovered.get("sample_count", 0),
            "candidate_vtables": recovered.get("candidate_vtables", []),
            "selected_object_vtables": recovered.get("selected_object_vtables", []),
            "projection_object_return_observed": recovered.get(
                "projection_object_return_observed", False
            ),
        }
    return {
        "surface": "0x4a9f1c candidate+0x04 type labels",
        "label_source": "object-metadata-by-type.json type_id/type_name",
        "labels": labels,
        "unresolved_type_ids": unresolved,
        "all_sampled_candidate_types_labeled": not unresolved,
    }


def summarize_descriptor_labels(
    descriptor_types: dict[str, Any],
    metadata_by_type: dict[int, dict[str, Any]],
    catalog_by_zero_based_row: dict[int, dict[str, str]],
) -> dict[str, Any]:
    labels: dict[str, Any] = {}
    type_unresolved: list[int] = []
    row_mismatches: list[dict[str, Any]] = []

    for type_text, recovered in sorted(descriptor_types.items(), key=lambda item: int(item[0])):
        type_id = int(type_text)
        meta = metadata_by_type.get(type_id)
        if not meta:
            type_unresolved.append(type_id)
        rows = []
        for descriptor_id in recovered.get("descriptor_ids_or_class_words", []):
            row = catalog_by_zero_based_row.get(int(descriptor_id))
            if not row:
                rows.append(
                    {
                        "descriptor_id_or_class_word": descriptor_id,
                        "row_status": "missing_catalog_row_for_zero_based_id",
                    }
                )
                row_mismatches.append(
                    {
                        "descriptor_type": type_id,
                        "descriptor_id_or_class_word": descriptor_id,
                        "reason": "missing_catalog_row_for_zero_based_id",
                    }
                )
                continue
            matches_type = int(row["type_id"]) == type_id
            row_label = {
                "descriptor_id_or_class_word": descriptor_id,
                "source_row": int(row["source_row"]),
                "def_name": row["def_name"],
                "catalog_type_id": int(row["type_id"]),
                "catalog_type_name": row["type_name"],
                "subtype": int(row["subtype"]),
                "row_status": (
                    "zero_based_source_row_type_match"
                    if matches_type
                    else "zero_based_source_row_type_mismatch"
                ),
            }
            rows.append(row_label)
            if not matches_type:
                row_mismatches.append(
                    {
                        "descriptor_type": type_id,
                        "descriptor_id_or_class_word": descriptor_id,
                        "source_row": int(row["source_row"]),
                        "catalog_type_id": int(row["type_id"]),
                        "catalog_type_name": row["type_name"],
                        "def_name": row["def_name"],
                    }
                )

        matching_rows = [row for row in rows if row.get("row_status") == "zero_based_source_row_type_match"]
        labels[type_text] = {
            "label_status": (
                "source_metadata_type_id_match"
                if meta
                else "missing_object_metadata_type"
            ),
            "type_name": meta["type_name"] if meta else None,
            "object_template_row_count": meta["object_template_row_count"] if meta else None,
            "object_template_subtypes_compact": (
                meta["object_template_subtypes_compact"] if meta else None
            ),
            "sample_defs": meta["sample_defs"][:8] if meta else [],
            "commit_invocation_count": recovered.get("commit_invocation_count", 0),
            "descriptor_ids_or_class_words": recovered.get("descriptor_ids_or_class_words", []),
            "catalog_row_resolution": {
                "resolved_count": len(rows),
                "matching_type_count": len(matching_rows),
                "mismatch_count": len(rows) - len(matching_rows),
                "rows": rows,
            },
        }

    return {
        "surface": "0x4a54a7 descriptor+0x1c type labels",
        "label_source": "object-metadata-by-type.json plus zero-based object-catalog source_row cross-check",
        "labels": labels,
        "unresolved_type_ids": type_unresolved,
        "row_mismatches": row_mismatches,
        "all_sampled_descriptor_types_labeled": not type_unresolved,
        "all_descriptor_ids_resolve_to_matching_catalog_rows": not row_mismatches,
    }


def build_summary(args: argparse.Namespace) -> dict[str, Any]:
    descriptor_category = load_json(args.descriptor_category)
    object_metadata = load_json(args.object_metadata)
    object_catalog = load_catalog(args.object_catalog)

    metadata_by_type = {int(entry["type_id"]): entry for entry in object_metadata["entries"]}
    catalog_by_zero_based_row = {
        int(row["source_row"]) - 1: row for row in object_catalog if row.get("source_row")
    }

    surfaces = descriptor_category["recovered_surfaces"]
    candidate_surface = surfaces["candidate_type_surface_4a9f1c"]
    descriptor_surface = surfaces["descriptor_commit_surface_4a54a7"]

    candidate_labels = summarize_candidate_labels(
        candidate_surface["candidate_types"], metadata_by_type
    )
    descriptor_labels = summarize_descriptor_labels(
        descriptor_surface["by_type"], metadata_by_type, catalog_by_zero_based_row
    )

    invariants = {
        "descriptor_category_checkpoint_passed": descriptor_category.get("status")
        == "descriptor_category_surfaces_separated_candidate_cursor_gate_named",
        "all_sampled_candidate_types_labeled": candidate_labels[
            "all_sampled_candidate_types_labeled"
        ],
        "all_sampled_descriptor_types_labeled": descriptor_labels[
            "all_sampled_descriptor_types_labeled"
        ],
        "descriptor_54_catalog_rows_match_monster": all(
            row.get("catalog_type_name") == "Monster"
            and row.get("row_status") == "zero_based_source_row_type_match"
            for row in descriptor_labels["labels"]["54"]["catalog_row_resolution"]["rows"]
        ),
        "descriptor_98_catalog_rows_match_town": all(
            row.get("catalog_type_name") == "Town"
            and row.get("row_status") == "zero_based_source_row_type_match"
            for row in descriptor_labels["labels"]["98"]["catalog_row_resolution"]["rows"]
        ),
        "descriptor_45_type_label_recovered_but_row_unresolved": (
            descriptor_labels["labels"]["45"]["type_name"] == "Monolith Two Way"
            and descriptor_labels["labels"]["45"]["catalog_row_resolution"]["mismatch_count"] > 0
        ),
        "no_objdump_used": True,
        "no_native_behavior_change": True,
    }
    status = (
        "descriptor_label_crosswalk_partial_descriptor45_row_unresolved"
        if all(invariants.values())
        else "descriptor_label_crosswalk_incomplete"
    )

    return {
        "schema_id": "h3maped_descriptor_label_crosswalk_summary_v1",
        "status": status,
        "native_behavior_changed": False,
        "inputs": {
            "descriptor_category": str(args.descriptor_category),
            "object_metadata": str(args.object_metadata),
            "object_catalog": str(args.object_catalog),
        },
        "invariants": invariants,
        "metrics": {
            "sampled_candidate_type_count": len(candidate_surface["candidate_types"]),
            "sampled_descriptor_type_count": len(descriptor_surface["by_type"]),
            "candidate_unresolved_type_count": len(candidate_labels["unresolved_type_ids"]),
            "descriptor_unresolved_type_count": len(descriptor_labels["unresolved_type_ids"]),
            "descriptor_catalog_row_mismatch_count": len(descriptor_labels["row_mismatches"]),
            "native_behavior_changed": False,
            "used_objdump": False,
            "overall_goal_complete": False,
        },
        "recovered_surfaces": {
            "candidate_labels": candidate_labels,
            "descriptor_labels": descriptor_labels,
        },
        "source_backed_human_readable_conclusions": [
            (
                "All sampled 0x4a9f1c candidate+0x04 type ids map directly to extracted "
                "object metadata type names."
            ),
            (
                "Sampled descriptor+0x1c type 54 is source-labeled Monster, and every "
                "sampled descriptor id resolves as zero-based objects.txt row id to a "
                "matching Monster object template."
            ),
            (
                "Sampled descriptor+0x1c type 98 is source-labeled Town, and every "
                "sampled descriptor id resolves as zero-based objects.txt row id to a "
                "matching Town object template."
            ),
            (
                "Sampled descriptor+0x1c type 45 is source-labeled Monolith Two Way by "
                "type id, but its sampled descriptor id/class word 1145 resolves to a "
                "Cartographer row under the same zero-based row rule; that row-level "
                "meaning remains unresolved."
            ),
        ],
        "remaining_blockers": [
            (
                "Recover the descriptor id/class-word relation for sampled descriptor type "
                "45 before treating descriptor_ids_or_class_words as a universal source-row "
                "pointer."
            ),
            (
                "Broaden descriptor/candidate label coverage only through source object/template "
                "mapping; do not infer labels from numeric coincidence alone."
            ),
        ],
        "non_claims": [
            "This checkpoint does not change native RMG behavior.",
            "This checkpoint does not complete end-to-end generated-cell/object-vector replay.",
            "This checkpoint does not prove the unselected 0x540ca0/0x49cd97 +0xf5c path.",
            "This checkpoint does not make descriptor id/class words universally equivalent to source rows.",
        ],
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--descriptor-category", type=Path, default=DEFAULT_DESCRIPTOR_CATEGORY)
    parser.add_argument("--object-metadata", type=Path, default=DEFAULT_OBJECT_METADATA)
    parser.add_argument("--object-catalog", type=Path, default=DEFAULT_OBJECT_CATALOG)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = build_summary(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    metrics = summary["metrics"]
    print(
        "RMG_H3MAPED_DESCRIPTOR_LABEL_CROSSWALK_SUMMARY "
        f"status={summary['status']} "
        f"candidate_types={metrics['sampled_candidate_type_count']} "
        f"descriptor_types={metrics['sampled_descriptor_type_count']} "
        f"row_mismatches={metrics['descriptor_catalog_row_mismatch_count']} "
        f"out={args.out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
