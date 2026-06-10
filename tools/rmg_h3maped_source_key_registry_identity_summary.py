#!/usr/bin/env python3
"""Label the H3MapEd descriptor source-key registry value.

This is a recovery checkpoint only. It consumes existing Ghidra/Wine/Python
summaries and assigns a human domain label to the value returned by 0x491eed
from registry entry +0x1c, then stored by 0x4903e8 at descriptor +0x00.

The important boundary is negative as much as positive: this value is a
descriptor source selector key from the source/name registry, not a universal
objects.txt or objtmplt.txt row identity.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_BASE_HELPER = ROOT / "descriptor_base_value_helper_summary_20260610.json"
DEFAULT_BUILD_JOIN = ROOT / "descriptor_build_selected_join_summary_20260610.json"
DEFAULT_ROW_MODE = ROOT / "descriptor_word_row_mode_summary_20260610.json"
DEFAULT_SOURCE_RECORD = ROOT / "source_record_identity_frontier_summary_20260610.json"
DEFAULT_OBJECT_LOADER = ROOT / "object_table_loader_summary_20260610.json"
DEFAULT_DESCRIPTOR_INPUT = ROOT / "descriptor_input_mapping_summary_20260610.json"
DEFAULT_AUX_16_BYTE = ROOT / "aux_16_byte_record_summary_20260610.json"
DEFAULT_OUT = ROOT / "source_key_registry_identity_summary_20260610.json"

TARGET_CONTEXTS = [
    "0x004a744a | 45",
    "0x004a98f0 | 53",
    "0x004a5e6c | 54",
    "0x004a9c3f | 79",
]


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def row_mode_contexts(row_mode: dict[str, Any]) -> list[dict[str, Any]]:
    contexts = []
    by_context = row_mode.get("by_return_address_and_descriptor_type", {})
    for key in TARGET_CONTEXTS:
        context = by_context.get(key, {})
        contexts.append(
            {
                "return_address_and_descriptor_type": key,
                "sample_count": context.get("sample_count", 0),
                "descriptor_words": context.get("descriptor_words", []),
                "row_match_count": context.get("row_match_count", 0),
                "row_mismatch_count": context.get("row_mismatch_count", 0),
                "row_missing_count": context.get("row_missing_count", 0),
                "row_mode_classification": context.get("row_mode_classification"),
                "mismatch_examples": context.get("mismatch_examples", [])[:3],
            }
        )
    return contexts


def summarize(
    base_helper_path: Path,
    build_join_path: Path,
    row_mode_path: Path,
    source_record_path: Path,
    object_loader_path: Path,
    descriptor_input_path: Path,
    aux_16_byte_path: Path,
) -> dict[str, Any]:
    base_helper = read_json(base_helper_path)
    build_join = read_json(build_join_path)
    row_mode = read_json(row_mode_path)
    source_record = read_json(source_record_path)
    object_loader = read_json(object_loader_path)
    descriptor_input = read_json(descriptor_input_path)
    aux_16_byte = read_json(aux_16_byte_path)

    contexts = row_mode_contexts(row_mode)
    base_recovered = base_helper.get("invariants", {}).get(
        "descriptor_plus_0x00_is_registry_entry_plus_0x1c"
    ) is True
    join_recovered = build_join.get("status") == "same_run_selected_descriptor_pointer_join_recovered"
    row_mode_recovered = row_mode.get("status") == "descriptor_word_row_mode_mixed_class_word_recovered"
    source_frontier_recovered = (
        source_record.get("status")
        == "source_record_identity_frontier_recovered_producer_mapping_pending"
    )
    object_loader_recovered = (
        object_loader.get("status") == "object_table_loader_recovered_catalog_row_identity_surface"
    )
    descriptor_input_recovered = (
        descriptor_input.get("status")
        == "descriptor_input_mapping_terrain_fields_recovered_catalog_mapping_pending"
    )
    aux_16_byte_recovered = (
        aux_16_byte.get("status")
        == "aux_16_byte_stream_record_source_excluded_from_descriptor_fields"
    )
    has_mismatch_evidence = any(context.get("row_mismatch_count", 0) > 0 for context in contexts)
    target_join_count = build_join.get("metrics", {}).get("target_mixed_joined_descriptor_count", 0)
    target_missing_join_count = build_join.get("metrics", {}).get("target_mixed_missing_join_count", 1)

    invariants = {
        "descriptor_plus_0x00_assignment_source_recovered": base_recovered,
        "same_run_selected_descriptor_pointer_join_recovered": join_recovered,
        "mixed_lane_row_mode_recovered": row_mode_recovered,
        "object_table_loader_row_identity_surface_recovered": object_loader_recovered,
        "source_record_frontier_recovered_but_final_producer_pending": source_frontier_recovered,
        "descriptor_plus_0x14_0x18_terrain_masks_recovered": descriptor_input_recovered,
        "aux_16_byte_stream_record_source_excluded": aux_16_byte_recovered,
        "mixed_lane_has_non_row_identity_evidence": has_mismatch_evidence,
        "all_target_mixed_selected_descriptors_joined": (
            join_recovered and target_join_count > 0 and target_missing_join_count == 0
        ),
        "native_behavior_unchanged": True,
        "no_objdump_used": True,
    }
    complete = all(invariants.values())

    return {
        "schema_id": "h3maped_source_key_registry_identity_summary_v1",
        "status": (
            "source_key_registry_entry_0x1c_domain_label_recovered"
            if complete
            else "source_key_registry_entry_0x1c_domain_label_incomplete"
        ),
        "scope": (
            "Human/domain label for the 0x491eed source-key registry field at entry +0x1c. "
            "This checkpoint names the value used by descriptor +0x00 without converting it "
            "into final object identity."
        ),
        "inputs": {
            "descriptor_base_value_helper": str(base_helper_path),
            "same_run_descriptor_build_join": str(build_join_path),
            "descriptor_word_row_mode": str(row_mode_path),
            "source_record_identity_frontier": str(source_record_path),
            "object_table_loader": str(object_loader_path),
            "descriptor_input_mapping": str(descriptor_input_path),
            "aux_16_byte_stream_record_boundary": str(aux_16_byte_path),
        },
        "recovered_domain_label": {
            "0x491eed_return_value": "descriptor_source_selector_key",
            "registry_entry_plus_0x1c": "local source-key registry value for a source/name descriptor input",
            "descriptor_plus_0x00": "descriptor source selector key copied from registry entry +0x1c",
            "not_final_identity": (
                "It is not a universal objects.txt/objtmplt.txt row id, not a DEF name, "
                "and not sufficient by itself to identify selected object type/subtype semantics."
            ),
        },
        "evidence": {
            "static_assignment_chain": [
                "0x4903e8 calls 0x491eed and stores its return value at descriptor +0x00.",
                "0x491eed resolves the source/name blob through 0x4923a1 and 0x49228d.",
                "0x491eed returns dword [registry_entry + 0x1c].",
                "0x4923e2 allocates 0x24-byte registry entries for missing source/name keys.",
            ],
            "same_run_pointer_join": {
                "target_mixed_selected_descriptor_count": build_join.get("metrics", {}).get(
                    "target_mixed_selected_descriptor_count"
                ),
                "target_mixed_joined_descriptor_count": target_join_count,
                "target_mixed_missing_join_count": target_missing_join_count,
                "target_contexts": build_join.get("target_contexts", []),
            },
            "row_mode_boundary": {
                "sample_count": row_mode.get("metrics", {}).get("sample_count"),
                "row_match_count": row_mode.get("metrics", {}).get("row_match_count"),
                "row_mismatch_count": row_mode.get("metrics", {}).get("row_mismatch_count"),
                "target_contexts": contexts,
                "interpretation": (
                    "Some descriptor source selector keys are row-like in the sampled catalog, "
                    "but type 45/53/54/79 samples include contradictions. Therefore row identity "
                    "is a per-lane/source-producer question, not a global descriptor +0x00 rule."
                ),
            },
            "catalog_identity_boundary": {
                "object_loader_status": object_loader.get("status"),
                "source_record_status": source_record.get("status"),
                "why_not_final_object_identity": source_record.get("catalog_interpretation", {}).get(
                    "why_not_identity"
                ),
            },
            "closed_prior_blockers": {
                "descriptor_plus_0x14_0x18": (
                    "Recovered by descriptor input mapping as catalog terrain_mask_a and "
                    "terrain_mask_b, not unknown compact descriptor fields."
                ),
                "0x490a11_0x438937_fixed_read": (
                    "Recovered by aux 16-byte checkpoint as caller-local/source-excluded "
                    "from descriptor fields in the 0x490a11 owner frame."
                ),
            },
        },
        "invariants": invariants,
        "remaining_blockers": [
            {
                "id": "source_catalog_template_producer_mapping",
                "reason": (
                    "Recover the producer that maps parsed source-input fields, populated 0x4c "
                    "source records, and nested payload holders into exact objects.txt/objtmplt.txt "
                    "type/subtype/DEF rows. This is the next required step before native RMG can "
                    "port selected object identity end-to-end."
                ),
            },
        ],
        "metrics": {
            "target_mixed_selected_descriptor_count": build_join.get("metrics", {}).get(
                "target_mixed_selected_descriptor_count"
            ),
            "target_mixed_joined_descriptor_count": target_join_count,
            "target_mixed_missing_join_count": target_missing_join_count,
            "row_mode_sample_count": row_mode.get("metrics", {}).get("sample_count"),
            "row_mode_match_count": row_mode.get("metrics", {}).get("row_match_count"),
            "row_mode_mismatch_count": row_mode.get("metrics", {}).get("row_mismatch_count"),
            "used_objdump": False,
            "native_behavior_changed": False,
            "overall_goal_complete": False,
        },
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-helper", type=Path, default=DEFAULT_BASE_HELPER)
    parser.add_argument("--build-join", type=Path, default=DEFAULT_BUILD_JOIN)
    parser.add_argument("--row-mode", type=Path, default=DEFAULT_ROW_MODE)
    parser.add_argument("--source-record", type=Path, default=DEFAULT_SOURCE_RECORD)
    parser.add_argument("--object-loader", type=Path, default=DEFAULT_OBJECT_LOADER)
    parser.add_argument("--descriptor-input", type=Path, default=DEFAULT_DESCRIPTOR_INPUT)
    parser.add_argument("--aux-16-byte", type=Path, default=DEFAULT_AUX_16_BYTE)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(
        args.base_helper,
        args.build_join,
        args.row_mode,
        args.source_record,
        args.object_loader,
        args.descriptor_input,
        args.aux_16_byte,
    )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    metrics = summary["metrics"]
    print(
        "RMG_H3MAPED_SOURCE_KEY_REGISTRY_IDENTITY "
        f"status={summary['status']} "
        f"joined={metrics['target_mixed_joined_descriptor_count']}/"
        f"{metrics['target_mixed_selected_descriptor_count']} "
        f"row_mismatches={metrics['row_mode_mismatch_count']} "
        f"out={args.out}"
    )
    return 0 if summary["status"] == "source_key_registry_entry_0x1c_domain_label_recovered" else 1


if __name__ == "__main__":
    raise SystemExit(main())
