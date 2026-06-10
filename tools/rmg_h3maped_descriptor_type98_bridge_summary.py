#!/usr/bin/env python3
"""Bridge sampled descriptor type 98 across weighted and commit surfaces.

This is a narrow recovery checkpoint. It proves that sampled weighted
0x4a901a materializations and sampled 0x4a54a7 descriptor/relation commits
share descriptor/counter lane 98, while deliberately avoiding a final
human-readable object-kind name for that numeric type.

It uses existing Wine/Ghidra/Python summaries only. It does not change native
RMG behavior and does not use objdump.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_DESCRIPTOR_SURFACE = ROOT / "medium_descriptor_category_surface_summary_20260608.json"
DEFAULT_WEIGHTED = ROOT / "weighted_4a901a_materialization_summary_20260609.json"
DEFAULT_EXACT_DESCRIPTOR = ROOT / "medium_seed10_4a54a7_descriptor_relation_summary_20260608.json"
DEFAULT_OUT = ROOT / "descriptor_type98_bridge_summary_20260610.json"


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def qhex(value: int | None) -> str | None:
    return None if value is None else f"0x{value:08x}"


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    descriptor_surface = load_json(args.descriptor_surface)
    weighted = load_json(args.weighted)
    exact_descriptor = load_json(args.exact_descriptor)

    commit_surface = descriptor_surface.get("recovered_surfaces", {}).get(
        "descriptor_commit_surface_4a54a7", {}
    )
    type98_commit = commit_surface.get("by_type", {}).get("98", {})
    weighted_dispatches = weighted.get("all_return_vector_counter_trace", {}).get("dispatches", [])
    weighted_conditions = weighted.get("conditions", {})
    exact_invocations = [
        invocation
        for invocation in exact_descriptor.get("invocations", [])
        if invocation.get("descriptor", {}).get("type_index_from_descriptor_plus_0x1c") == 98
    ]

    weighted_lane_deltas = []
    for dispatch in weighted_dispatches:
        before = dispatch.get("counter98_before")
        after = dispatch.get("counter98_after")
        weighted_lane_deltas.append(
            {
                "dispatch_event_index": dispatch.get("dispatch_event_index"),
                "record_pointer": qhex(dispatch.get("record_pointer")),
                "coordinate": {
                    "x": dispatch.get("x"),
                    "y": dispatch.get("y"),
                    "level": dispatch.get("z"),
                },
                "vector_count_before": dispatch.get("vector_count_before"),
                "vector_count_after": dispatch.get("vector_count_after"),
                "counter98_before": before,
                "counter98_after": after,
                "counter98_delta": None if before is None or after is None else after - before,
                "return_captured": dispatch.get("return_captured"),
                "caller_after_captured": dispatch.get("caller_after_captured"),
            }
        )

    exact_type98_samples = []
    for invocation in exact_invocations:
        descriptor = invocation.get("descriptor", {})
        relation = invocation.get("relation_counter", {})
        exact_type98_samples.append(
            {
                "object_record_pointer": invocation.get("object_record_pointer"),
                "object_coordinate": invocation.get("object_coordinate"),
                "descriptor_pointer": descriptor.get("pointer"),
                "descriptor_id_or_class_word": descriptor.get("id_or_class_word_0x00"),
                "descriptor_type": descriptor.get("type_index_from_descriptor_plus_0x1c"),
                "projection_flag_plus_0x29": descriptor.get("projection_flag_plus_0x29"),
                "projection_offset_x_plus_0x2c": descriptor.get("projection_offset_x_plus_0x2c"),
                "projection_offset_y_plus_0x30": descriptor.get("projection_offset_y_plus_0x30"),
                "mask_width_plus_0x34": descriptor.get("mask_width_plus_0x34"),
                "mask_height_plus_0x38": descriptor.get("mask_height_plus_0x38"),
                "source_owner_byte_from_cell_plus_0x20_byte2": relation.get(
                    "source_owner_byte_from_cell_plus_0x20_byte2"
                ),
                "relation_counter_incremented_by_one": relation.get("counter_incremented_by_one"),
                "source_coordinate_matches_descriptor_offsets": invocation.get("source_cell", {}).get(
                    "coordinate_matches_descriptor_offset_source"
                ),
            }
        )

    invariants = {
        "no_native_behavior_change": descriptor_surface.get("native_behavior_changed") is False
        and weighted.get("status") == "weighted_sampled_materializations_return_vector_counter_recovered"
        and exact_descriptor.get("native_behavior_changed") is False,
        "no_objdump_used": True,
        "descriptor_surface_has_type98_commit_lane": bool(type98_commit)
        and type98_commit.get("commit_invocation_count", 0) >= 1,
        "type98_commit_lane_has_projection_flag_and_offsets": type98_commit.get(
            "projection_flag_values"
        )
        == [1]
        and type98_commit.get("projection_offsets_x_y") == [[2, 0]]
        and type98_commit.get("mask_dimensions_w_h") == [[6, 6]],
        "type98_exact_invocations_increment_relation_counters": bool(exact_type98_samples)
        and all(sample["relation_counter_incremented_by_one"] for sample in exact_type98_samples),
        "type98_exact_invocations_match_descriptor_offsets": bool(exact_type98_samples)
        and all(
            sample["source_coordinate_matches_descriptor_offsets"]
            for sample in exact_type98_samples
        ),
        "weighted_materializations_all_increment_counter98": len(weighted_lane_deltas) == 3
        and all(delta.get("counter98_delta") == 1 for delta in weighted_lane_deltas),
        "weighted_materializations_all_return_and_reach_caller": len(weighted_lane_deltas) == 3
        and all(delta.get("return_captured") for delta in weighted_lane_deltas)
        and all(delta.get("caller_after_captured") for delta in weighted_lane_deltas),
        "weighted_summary_conditions_cover_vector_counter_state": weighted_conditions.get(
            "all_sampled_weighted_return_vector_counter_recovered"
        )
        is True
        and weighted_conditions.get("weighted_descriptor_counter_increment_recovered") is True,
    }

    status = (
        "descriptor_type98_weighted_and_commit_lane_recovered"
        if all(invariants.values())
        else "descriptor_type98_bridge_incomplete"
    )

    return {
        "schema_id": "h3maped_descriptor_type98_bridge_summary_v1",
        "status": status,
        "scope": (
            "Sampled descriptor/counter lane 98 only. This bridges weighted 0x4a901a "
            "materialization counter deltas with sampled 0x4a54a7 descriptor/relation "
            "commit mechanics; it does not assign a final object-kind name."
        ),
        "inputs": {
            "descriptor_surface": str(args.descriptor_surface),
            "weighted": str(args.weighted),
            "exact_descriptor": str(args.exact_descriptor),
        },
        "type98_commit_lane": type98_commit,
        "weighted_counter98_dispatches": weighted_lane_deltas,
        "exact_type98_descriptor_relation_samples": exact_type98_samples,
        "invariants": invariants,
        "metrics": {
            "type98_commit_invocation_count": type98_commit.get("commit_invocation_count"),
            "type98_exact_invocation_count": len(exact_type98_samples),
            "weighted_counter98_dispatch_count": len(weighted_lane_deltas),
            "weighted_counter98_total_delta": sum(
                delta.get("counter98_delta") or 0 for delta in weighted_lane_deltas
            ),
            "native_behavior_changed": False,
            "overall_goal_complete": False,
            "used_objdump": False,
        },
        "source_backed_conclusion": (
            "Descriptor/counter index 98 is now recovered as a sampled shared projection "
            "commit lane: exact 0x4a54a7 descriptor/relation invocations use descriptor+0x1c "
            "value 98 with projection flag +0x29, source offsets +0x2c/+0x30 = (2,0), "
            "6x6 masks, and relation counter increments; all three sampled weighted "
            "0x4a901a materializations also return through 0x4a54a7 and increment "
            "generator+0x1110[98] by one while appending one object record."
        ),
        "remaining_gap": (
            "This does not give type 98 a final human object-kind label, does not recover "
            "all descriptor/candidate numeric types globally, and does not recover the "
            "second/third weighted generated-cell score-write sets. Native RMG must not "
            "translate descriptor type 98 into a gameplay category until source object/template "
            "mapping proves the label."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--descriptor-surface", type=Path, default=DEFAULT_DESCRIPTOR_SURFACE)
    parser.add_argument("--weighted", type=Path, default=DEFAULT_WEIGHTED)
    parser.add_argument("--exact-descriptor", type=Path, default=DEFAULT_EXACT_DESCRIPTOR)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_DESCRIPTOR_TYPE98_BRIDGE "
        f"status={summary['status']} "
        f"weighted_dispatches={summary['metrics']['weighted_counter98_dispatch_count']} "
        f"exact_invocations={summary['metrics']['type98_exact_invocation_count']} "
        f"out={args.out}"
    )
    return 0 if summary["status"] == "descriptor_type98_weighted_and_commit_lane_recovered" else 1


if __name__ == "__main__":
    raise SystemExit(main())
