#!/usr/bin/env python3
"""Report native final-writeout authority against recovered H3MapEd streams.

This is not a parity gate. It records whether native final-writeout evidence is
sourced from recovered final payload streams, and names the earlier checkpoints
that still block byte/object parity.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_OBJECT_SUMMARY = Path(".artifacts/rmg_recovery/same_run_final_object_payload_replay_summary_20260610.json")


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def native_final_writeout(snapshot: dict[str, Any]) -> dict[str, Any]:
    final = snapshot.get("h3maped_small_port", {}).get("final_h3m_writeout", {})
    if not isinstance(final, dict):
        return {}
    return final


def build_report(args: argparse.Namespace) -> dict[str, Any]:
    snapshot = load_json(args.native_phase_snapshot)
    tile_compare = load_json(args.tile_compare)
    object_summary = load_json(args.h3maped_object_summary)
    final = native_final_writeout(snapshot)
    final_tile_schema = final.get("tile_bytes", {}).get("schema_id", "")
    tile_diagnosis = tile_compare.get("diagnosis", {})
    tile_metrics = tile_compare.get("metrics", {})
    object_metrics = object_summary.get("metrics", {})
    native_package_object_count = int(final.get("package_object_count", 0) or 0)
    recovered_object_count = int(object_metrics.get("object_count", 0) or 0)
    native_has_final_object_stream = bool(final.get("final_object_payload_bytes_available", False))

    blockers: list[str] = []
    first_tile_drift = str(tile_diagnosis.get("first_drift_phase", ""))
    if tile_compare.get("status") != "match":
        if first_tile_drift == "terrain_generated_cell_word_0x24_before_0x49b2b6":
            blockers.append("native-rmg-private-generated-cell-grid-alignment-10184")
        elif first_tile_drift:
            blockers.append(first_tile_drift)
        else:
            blockers.append("native-vs-h3maped-final-tile-payload-compare")
    if not native_has_final_object_stream:
        blockers.append("native-rmg-reward-object-identity-alignment-10184")
        blockers.append("native-rmg-connection-blocker-guard-payload-alignment-10184")
        blockers.append("native-rmg-decorative-scoring-vector-replay-alignment-10184")

    unique_blockers = list(dict.fromkeys(blockers))
    authority_aligned = (
        final_tile_schema == "aurelion_h3maped_small_tile_bytes_0x49b2b6_draft_v1"
        and tile_compare.get("scope", {}).get("positive_claim", "").startswith("compares recovered H3MapEd 0x49b2b6")
        and object_metrics.get("final_object_payload_replay_complete") is True
        and not bool(final.get("native_rmg_end_to_end_parity_complete", True))
    )
    status = "authority_aligned_pending_prior_checkpoints" if authority_aligned else "authority_incomplete"
    if authority_aligned and not unique_blockers:
        status = "authority_aligned_no_known_writeout_blockers"

    return {
        "schema_id": "rmg_h3maped_final_writeout_authority_report_v1",
        "status": status,
        "scope": {
            "positive_claim": "uses recovered H3MapEd final tile/object payload streams as writeout authority",
            "negative_claim": "does not claim native final payload parity while upstream checkpoints still mismatch",
        },
        "inputs": {
            "native_phase_snapshot": str(args.native_phase_snapshot),
            "tile_compare": str(args.tile_compare),
            "h3maped_object_summary": str(args.h3maped_object_summary),
        },
        "native_final_writeout": {
            "status": final.get("status", ""),
            "tile_schema_id": final_tile_schema,
            "package_object_count": native_package_object_count,
            "native_has_final_object_stream": native_has_final_object_stream,
            "native_rmg_end_to_end_parity_complete": bool(final.get("native_rmg_end_to_end_parity_complete", False)),
            "runtime_generation_allowed": bool(final.get("runtime_generation_allowed", False)),
            "public_runtime_authoritative": bool(final.get("public_runtime_authoritative", False)),
        },
        "h3maped_recovered_final_streams": {
            "tile_payload_byte_count": int(tile_metrics.get("h3maped_payload_byte_count", 0) or 0),
            "tile_payload_sha256": tile_metrics.get("h3maped_payload_sha256", ""),
            "object_payload_replay_complete": bool(object_metrics.get("final_object_payload_replay_complete", False)),
            "object_count": recovered_object_count,
            "object_payload_byte_count": int(object_metrics.get("payload_byte_count", 0) or 0),
            "object_payload_sha256": object_metrics.get("payload_sha256", ""),
        },
        "tile_compare": {
            "status": tile_compare.get("status", ""),
            "total_byte_mismatch_count": int(tile_metrics.get("total_byte_mismatch_count", 0) or 0),
            "first_drift_phase": first_tile_drift,
            "native_port_blocker": tile_diagnosis.get("native_port_blocker", ""),
        },
        "object_compare": {
            "status": "blocked_native_final_object_stream_not_materialized" if not native_has_final_object_stream else "available",
            "native_package_object_count_is_not_final_object_payload": True,
            "native_package_object_count": native_package_object_count,
            "h3maped_recovered_object_count": recovered_object_count,
        },
        "authority_aligned": authority_aligned,
        "remaining_alignment_blockers": unique_blockers,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--native-phase-snapshot", type=Path, required=True)
    parser.add_argument("--tile-compare", type=Path, required=True)
    parser.add_argument("--h3maped-object-summary", type=Path, default=DEFAULT_OBJECT_SUMMARY)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    report = build_report(args)
    write_json(args.out, report)
    print(
        "RMG_H3MAPED_FINAL_WRITEOUT_AUTHORITY_REPORT "
        f"status={report['status']} "
        f"tile_status={report['tile_compare']['status']} "
        f"object_status={report['object_compare']['status']} "
        f"out={args.out}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
