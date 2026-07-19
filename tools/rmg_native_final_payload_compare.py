#!/usr/bin/env python3
"""Compare native assembled final payload sections against recovered H3MapEd bytes.

This is a source-backed checkpoint for the no-Godot native RMG workflow. It
does not tune counts or density. It compares the complete native eight-section
0x4ad1e3 payload and also reports focused tile/generated-object diagnostics.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


DEFAULT_TILE_BYTES = Path(".artifacts/rmg_recovery/medium_seed10_setup1_hc1_co1_overlay_type_art_clear_final_grid_20260710b/final_tile_payload_bytes.bin")
DEFAULT_OBJECT_BYTES = Path(".artifacts/rmg_recovery/same_run_hc1_co1_final_object_payload_replay_bytes_20260709.bin")


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def first_mismatch(left: bytes, right: bytes) -> int | None:
    for index, (left_byte, right_byte) in enumerate(zip(left, right)):
        if left_byte != right_byte:
            return index
    if len(left) != len(right):
        return min(len(left), len(right))
    return None


def section_map(snapshot: dict[str, Any]) -> dict[str, dict[str, Any]]:
    sections = (
        snapshot.get("native_h3maped_workflow", {})
        .get("final_payload_writeout_0x4ad1e3", {})
        .get("sections", [])
    )
    if not isinstance(sections, list) or not sections:
        raise ValueError("native snapshot is missing native_h3maped_workflow.final_payload_writeout_0x4ad1e3.sections")
    mapped: dict[str, dict[str, Any]] = {}
    for section in sections:
        if not isinstance(section, dict):
            continue
        section_id = str(section.get("section_id", ""))
        if section_id:
            mapped[section_id] = section
    return mapped


def section_bytes(payload: bytes, sections: dict[str, dict[str, Any]], section_id: str) -> tuple[bytes, dict[str, int | str]]:
    if section_id not in sections:
        raise ValueError(f"native final payload is missing section {section_id!r}")
    section = sections[section_id]
    offset = int(section.get("offset", -1))
    byte_count = int(section.get("byte_count", -1))
    if offset < 0 or byte_count < 0 or offset + byte_count > len(payload):
        raise ValueError(
            f"native final payload section {section_id!r} has invalid offset/count "
            f"offset={offset} byte_count={byte_count} payload_bytes={len(payload)}"
        )
    metadata: dict[str, int | str] = {
        "section_id": section_id,
        "h3maped_anchor": str(section.get("h3maped_anchor", "")),
        "offset": offset,
        "byte_count": byte_count,
    }
    return payload[offset : offset + byte_count], metadata


def compare_blob(native: bytes, expected: bytes, section: dict[str, int | str]) -> dict[str, Any]:
    mismatch = first_mismatch(native, expected)
    result: dict[str, Any] = {
        "match": mismatch is None,
        "native_byte_count": len(native),
        "expected_byte_count": len(expected),
        "byte_count_delta_native_minus_expected": len(native) - len(expected),
        "native_sha256": sha256(native),
        "expected_sha256": sha256(expected),
        "section": section,
    }
    if mismatch is not None:
        result["first_mismatch_offset"] = mismatch
        if mismatch < len(native):
            result["native_byte"] = native[mismatch]
        if mismatch < len(expected):
            result["expected_byte"] = expected[mismatch]
    return result


def le32(value: int) -> bytes:
    return int(value).to_bytes(4, byteorder="little", signed=False)


def native_paths(args: argparse.Namespace) -> tuple[Path, Path]:
    if args.native_phase_snapshot and args.native_final_payload:
        return args.native_phase_snapshot, args.native_final_payload
    if not args.native_output_dir or not args.case_id:
        raise ValueError("provide either --native-phase-snapshot/--native-final-payload or --native-output-dir/--case-id")
    return (
        args.native_output_dir / f"{args.case_id}.phase_snapshot.json",
        args.native_output_dir / f"{args.case_id}.final_payload.bin",
    )


def build_report(args: argparse.Namespace) -> dict[str, Any]:
    native_snapshot_path, native_payload_path = native_paths(args)
    snapshot = load_json(native_snapshot_path)
    payload = native_payload_path.read_bytes()
    sections = section_map(snapshot)
    expected_tile = args.h3maped_tile_bytes.read_bytes()
    expected_object = args.h3maped_object_payload_bytes.read_bytes()
    expected_full = args.h3maped_full_payload_bytes.read_bytes()
    native_tile, tile_section = section_bytes(payload, sections, "tile_stream")
    native_object_count, object_count_section = section_bytes(payload, sections, "generated_object_count")
    native_object, object_section = section_bytes(payload, sections, "generated_object_payload")
    tile = compare_blob(native_tile, expected_tile, tile_section)
    workflow = snapshot.get("native_h3maped_workflow", {})
    final_payload = workflow.get("final_payload_writeout_0x4ad1e3", {})
    authority_object_count = int(final_payload.get("same_run_generated_object_count_authority_value", 0))
    generated_object_count = compare_blob(native_object_count, le32(authority_object_count), object_count_section)
    generated_object_payload = compare_blob(native_object, expected_object, object_section)
    full_payload = compare_blob(
        payload,
        expected_full,
        {
            "section_id": "complete_final_payload",
            "h3maped_anchor": "0x4ac857..0x4ad3db",
            "offset": 0,
            "byte_count": len(payload),
        },
    )
    authority_scope_blocker = str(final_payload.get("same_run_h3maped_authority_scope_blocker", ""))
    authority_scope_matches = bool(final_payload.get("same_run_h3maped_authority_scope_matches", False))
    match = bool(authority_scope_matches and full_payload["match"])
    if authority_scope_blocker:
        blocker = authority_scope_blocker
    elif not authority_scope_matches:
        blocker = "same_run_payload_authority_scope_mismatch"
    elif not bool(full_payload["match"]):
        blocker = "native_full_final_payload_mismatch_against_same_run_0x4ac857_0x4ad3db_stream"
    elif not bool(tile["match"]):
        blocker = "native_final_tile_stream_mismatch_against_same_run_0x49b2b6_payload"
    elif not bool(generated_object_count["match"]):
        blocker = "native_generated_object_count_mismatch_against_same_run_0x4ad330_count"
    elif not bool(generated_object_payload["match"]):
        blocker = "native_generated_object_payload_mismatch_against_same_run_0x4ad1e3_payload"
    else:
        blocker = ""
    return {
        "schema_id": "rmg_native_final_payload_compare_v2",
        "status": "matched" if match else "blocked",
        "blocker": blocker,
        "scope": {
            "positive_claim": "compares the complete native assembled eight-section payload against recovered same-run H3MapEd bytes",
            "negative_claim": "does not tune generation output or substitute final-map deltas for source behavior",
        },
        "inputs": {
            "native_phase_snapshot": str(native_snapshot_path),
            "native_final_payload": str(native_payload_path),
            "h3maped_tile_bytes": str(args.h3maped_tile_bytes),
            "h3maped_object_payload_bytes": str(args.h3maped_object_payload_bytes),
            "h3maped_full_payload_bytes": str(args.h3maped_full_payload_bytes),
        },
        "native_payload": {
            "byte_count": len(payload),
            "sha256": sha256(payload),
            "section_count": len(sections),
            "final_payload_same_run_compare_complete": bool(final_payload.get("same_run_h3maped_compare_complete", False)),
            "same_run_authority_scope_matches": authority_scope_matches,
            "same_run_authority_scope_blocker": authority_scope_blocker,
        },
        "tile_stream": tile,
        "generated_object_count": generated_object_count,
        "generated_object_payload": generated_object_payload,
        "full_payload": full_payload,
        "native_rmg_end_to_end_parity_complete": match,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native-output-dir", type=Path)
    parser.add_argument("--case-id")
    parser.add_argument("--native-phase-snapshot", type=Path)
    parser.add_argument("--native-final-payload", type=Path)
    parser.add_argument("--h3maped-tile-bytes", type=Path, default=DEFAULT_TILE_BYTES)
    parser.add_argument("--h3maped-object-payload-bytes", type=Path, default=DEFAULT_OBJECT_BYTES)
    parser.add_argument("--h3maped-full-payload-bytes", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--expect-mismatch", action="store_true")
    args = parser.parse_args()

    report = build_report(args)
    write_json(args.out, report)
    tile = report["tile_stream"]
    object_count = report["generated_object_count"]
    objects = report["generated_object_payload"]
    full = report["full_payload"]
    print(
        "RMG_NATIVE_FINAL_PAYLOAD_COMPARE "
        f"status={report['status']} "
        f"blocker={report['blocker']} "
        f"tile_match={str(tile['match']).lower()} "
        f"object_count_match={str(object_count['match']).lower()} "
        f"object_match={str(objects['match']).lower()} "
        f"full_match={str(full['match']).lower()} "
        f"tile_native_bytes={tile['native_byte_count']} "
        f"object_count_native_bytes={object_count['native_byte_count']} "
        f"object_native_bytes={objects['native_byte_count']} "
        f"out={args.out}"
    )
    matched = report["status"] == "matched"
    if args.expect_mismatch:
        return 1 if matched else 0
    return 0 if matched else 1


if __name__ == "__main__":
    raise SystemExit(main())
