#!/usr/bin/env python3
"""Assemble the complete same-run H3MapEd final payload from recovered writes."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


HEADER_SECTIONS = (
    "map_header_and_generated_text",
    "map_description_and_victory_metadata",
    "player_slot_records",
    "metadata_helper_payload",
    "team_and_metadata_bitsets",
    "final_header_padding",
)


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def assemble(
    metadata_summary_path: Path,
    metadata_bytes_path: Path,
    tile_summary_path: Path,
    tile_bytes_path: Path,
    object_summary_path: Path,
    object_bytes_path: Path,
    profile: str,
) -> tuple[dict[str, Any], bytes]:
    metadata_summary = load_json(metadata_summary_path)
    tile_summary = load_json(tile_summary_path)
    object_summary = load_json(object_summary_path)
    section_counts = metadata_summary.get("section_byte_counts", {})
    metadata = metadata_bytes_path.read_bytes()
    tile = tile_bytes_path.read_bytes()
    objects = object_bytes_path.read_bytes()

    header_count = sum(int(section_counts.get(section, 0)) for section in HEADER_SECTIONS)
    ordered_tail_sections = (
        ("post_header_initial_zero", int(section_counts.get("post_header_initial_zero", 0))),
        ("object_definition_type_count", int(section_counts.get("object_definition_type_count", 0))),
        ("object_definition_metadata", int(section_counts.get("object_definition_metadata", 0))),
        ("generated_object_count", int(section_counts.get("generated_object_count", 0))),
        ("final_zero_sentinel", int(section_counts.get("final_zero_sentinel", 0))),
    )
    expected_metadata_count = header_count + sum(count for _, count in ordered_tail_sections)
    failures: list[str] = []
    if metadata_summary.get("status") != "final_header_player_metadata_payload_replay_recovered":
        failures.append("metadata_replay_not_complete")
    if not tile_summary.get("metrics", {}).get("final_tile_payload_replay_complete"):
        failures.append("tile_replay_not_complete")
    if not object_summary.get("metrics", {}).get("final_object_payload_replay_complete"):
        failures.append("object_replay_not_complete")
    component_summaries = (metadata_summary, tile_summary, object_summary)
    component_ledgers = {
        str(Path(str(component.get("inputs", {}).get("ledger", ""))).resolve())
        for component in component_summaries
    }
    if len(component_ledgers) != 1:
        failures.append("component_summaries_not_from_same_ledger")
    if any(component.get("scope", {}).get("profile") != profile for component in component_summaries):
        failures.append("component_profile_mismatch")
    if len(metadata) != expected_metadata_count:
        failures.append("metadata_byte_count_mismatch")
    if any(count != 4 for section, count in ordered_tail_sections if section != "object_definition_metadata"):
        failures.append("fixed_width_spine_section_not_four_bytes")
    if not tile:
        failures.append("tile_stream_empty")
    elif sha256(tile) != tile_summary.get("metrics", {}).get("tile_payload_sha256"):
        failures.append("tile_stream_hash_mismatch")
    if not objects:
        failures.append("generated_object_stream_empty")
    elif sha256(objects) != object_summary.get("metrics", {}).get("payload_sha256"):
        failures.append("generated_object_stream_hash_mismatch")

    cursor = header_count
    split: dict[str, bytes] = {"header_player_metadata": metadata[:header_count]}
    for section, count in ordered_tail_sections:
        split[section] = metadata[cursor : cursor + count]
        cursor += count
    if cursor != len(metadata):
        failures.append("metadata_split_did_not_consume_payload")

    full = b"".join(
        (
            split["header_player_metadata"],
            split["post_header_initial_zero"],
            tile,
            split["object_definition_type_count"],
            split["object_definition_metadata"],
            split["generated_object_count"],
            objects,
            split["final_zero_sentinel"],
        )
    )
    sections: list[dict[str, Any]] = []
    offset = 0
    for section_id, payload in (
        ("header_player_metadata", split["header_player_metadata"]),
        ("post_header_initial_zero", split["post_header_initial_zero"]),
        ("tile_stream", tile),
        ("object_definition_count", split["object_definition_type_count"]),
        ("object_definition_table", split["object_definition_metadata"]),
        ("generated_object_count", split["generated_object_count"]),
        ("generated_object_payload", objects),
        ("final_zero_sentinel", split["final_zero_sentinel"]),
    ):
        sections.append(
            {
                "section_id": section_id,
                "offset": offset,
                "byte_count": len(payload),
                "sha256": sha256(payload),
            }
        )
        offset += len(payload)

    complete = not failures and len(sections) == 8 and offset == len(full)
    result = {
        "schema_id": "h3maped_full_final_payload_summary_v1",
        "status": "full_final_payload_replay_recovered" if complete else "full_final_payload_replay_incomplete",
        "scope": {
            "profile": profile,
            "positive_claim": "same-run complete eight-section H3MapEd final payload replay",
            "negative_claim": "does not by itself prove native generation parity",
        },
        "inputs": {
            "metadata_summary": str(metadata_summary_path),
            "metadata_bytes": str(metadata_bytes_path),
            "tile_summary": str(tile_summary_path),
            "tile_bytes": str(tile_bytes_path),
            "object_summary": str(object_summary_path),
            "object_bytes": str(object_bytes_path),
        },
        "metrics": {
            "section_count": len(sections),
            "payload_byte_count": len(full),
            "payload_sha256": sha256(full),
            "full_final_payload_replay_complete": complete,
            "native_behavior_changed": False,
            "native_parity_complete": False,
            "overall_goal_complete": False,
        },
        "sections": sections,
        "failures": failures,
    }
    return result, full


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--metadata-summary", type=Path, required=True)
    parser.add_argument("--metadata-bytes", type=Path, required=True)
    parser.add_argument("--tile-summary", type=Path, required=True)
    parser.add_argument("--tile-bytes", type=Path, required=True)
    parser.add_argument("--object-summary", type=Path, required=True)
    parser.add_argument("--object-bytes", type=Path, required=True)
    parser.add_argument("--profile", required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--bytes-out", type=Path, required=True)
    args = parser.parse_args()

    summary, payload = assemble(
        args.metadata_summary,
        args.metadata_bytes,
        args.tile_summary,
        args.tile_bytes,
        args.object_summary,
        args.object_bytes,
        args.profile,
    )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.bytes_out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    args.bytes_out.write_bytes(payload)
    print(
        "RMG_H3MAPED_FULL_FINAL_PAYLOAD "
        f"status={summary['status']} "
        f"bytes={summary['metrics']['payload_byte_count']} "
        f"sha256={summary['metrics']['payload_sha256']} "
        f"out={args.out}"
    )
    return 0 if summary["metrics"]["full_final_payload_replay_complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
