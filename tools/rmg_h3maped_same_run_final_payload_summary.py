#!/usr/bin/env python3
"""Summarize same-run H3MapEd final tile and object payload recovery.

This is a stitching checkpoint over one Wine ledger. It proves that the final
tile payload and generated-object payload can be replayed from the same
H3MapEd execution, but it deliberately does not claim full map writeout or
native parity until header/player/metadata payloads and ordered private-state
mutation replay are also recovered.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from rmg_h3maped_final_object_payload_replay_summary import (
    DEFAULT_CALLSTREAM,
    DEFAULT_STATIC,
    summarize as summarize_object_payload,
)
from rmg_h3maped_final_tile_payload_summary import summarize as summarize_tile_payload


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_LEDGER = (
    ROOT
    / "medium_seed10_same_run_final_tile_object_payload_20260610"
    / "winedbg_interactive_trace_ledger.json"
)
DEFAULT_OUT = ROOT / "same_run_final_payload_summary_20260610.json"
DEFAULT_TILE_OUT = ROOT / "same_run_final_tile_payload_summary_20260610.json"
DEFAULT_TILE_BYTES_OUT = ROOT / "same_run_final_tile_payload_bytes_20260610.bin"
DEFAULT_OBJECT_OUT = ROOT / "same_run_final_object_payload_replay_summary_20260610.json"
DEFAULT_OBJECT_BYTES_OUT = ROOT / "same_run_final_object_payload_replay_bytes_20260610.bin"
DEFAULT_GHIDRA_TILE_WRITER = (
    ROOT / "ghidra_writeout_spine_dump_20260610" / "target_0049b2b6_FUN_0049b2b6.txt"
)
DEFAULT_PROFILE = "H3MapEd Medium one-level no-water seed 10, human/computer down 1, computer-only down 1, monster strength weak"
FINAL_OBJECT_BOUNDARY_SITE = "0x004ad3db"
FINAL_OBJECT_SUCCESS_SITE = "0x004ad3de"
FINAL_TILE_SITE = "0x004ad251"


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def summarize(
    ledger_path: Path,
    ghidra_tile_writer: Path,
    static_path: Path,
    callstream_path: Path,
    tile_summary_out: Path,
    tile_bytes_out: Path,
    object_summary_out: Path,
    object_bytes_out: Path,
    profile: str = DEFAULT_PROFILE,
) -> dict[str, Any]:
    ledger = load_json(ledger_path)
    tile_summary, tile_payload = summarize_tile_payload(ledger_path, ghidra_tile_writer, profile)
    object_summary, object_payload = summarize_object_payload(
        ledger_path,
        static_path,
        callstream_path,
        object_bytes_out,
        profile,
    )
    tile_bytes_out.parent.mkdir(parents=True, exist_ok=True)
    tile_bytes_out.write_bytes(tile_payload)
    write_json(tile_summary_out, tile_summary)
    write_json(object_summary_out, object_summary)

    events = ledger.get("events", [])
    tile_event_count = sum(1 for event in events if event.get("address") == FINAL_TILE_SITE)
    final_object_boundary_event_count = sum(
        1 for event in events if event.get("address") == FINAL_OBJECT_BOUNDARY_SITE
    )
    final_object_success_event_count = sum(
        1 for event in events if event.get("address") == FINAL_OBJECT_SUCCESS_SITE
    )
    same_run_stitch_complete = (
        tile_summary.get("metrics", {}).get("final_tile_payload_replay_complete") is True
        and object_summary.get("metrics", {}).get("final_object_payload_replay_complete") is True
        and tile_event_count == 1
        and final_object_boundary_event_count == 1
        and final_object_success_event_count == 1
    )

    return {
        "schema_id": "h3maped_same_run_final_payload_summary_v1",
        "status": (
            "same_run_final_tile_object_payload_stitched"
            if same_run_stitch_complete
            else "same_run_final_tile_object_payload_incomplete"
        ),
        "scope": {
            "profile": profile,
            "positive_claim": (
                "same-run replay checkpoint for final generated-cell tile bytes and "
                "generated-object stream-write bytes"
            ),
            "negative_claim": (
                "does not recover header/player/metadata payloads, does not provide ordered "
                "private-state mutation replay, and does not change native RMG behavior"
            ),
        },
        "inputs": {
            "ledger": str(ledger_path),
            "ghidra_tile_writer": str(ghidra_tile_writer),
            "static_serializer_summary": str(static_path),
            "callstream_summary": str(callstream_path),
        },
        "outputs": {
            "tile_summary": str(tile_summary_out),
            "tile_payload_bytes": str(tile_bytes_out),
            "object_summary": str(object_summary_out),
            "object_payload_bytes": str(object_bytes_out),
        },
        "metrics": {
            "trace_event_count": ledger.get("event_count"),
            "final_tile_event_count": tile_event_count,
            "final_object_boundary_event_count": final_object_boundary_event_count,
            "final_object_success_event_count": final_object_success_event_count,
            "tile_cell_count": tile_summary.get("metrics", {}).get("cell_count"),
            "tile_payload_byte_count": tile_summary.get("metrics", {}).get(
                "tile_payload_byte_count"
            ),
            "tile_payload_sha256": tile_summary.get("metrics", {}).get("tile_payload_sha256"),
            "object_count": object_summary.get("metrics", {}).get("object_count"),
            "object_write_event_count": object_summary.get("metrics", {}).get("write_event_count"),
            "object_payload_byte_count": object_summary.get("metrics", {}).get(
                "payload_byte_count"
            ),
            "object_payload_sha256": object_summary.get("metrics", {}).get("payload_sha256"),
            "final_tile_payload_replay_complete": tile_summary.get("metrics", {}).get(
                "final_tile_payload_replay_complete"
            )
            is True,
            "final_object_payload_replay_complete": object_summary.get("metrics", {}).get(
                "final_object_payload_replay_complete"
            )
            is True,
            "same_run_tile_object_payload_stitching_complete": same_run_stitch_complete,
            "header_player_metadata_payload_replay_complete": False,
            "ordered_private_state_mutation_replay_complete": False,
            "full_private_payload_replay_complete": False,
            "native_behavior_changed": False,
            "used_objdump": False,
            "overall_goal_complete": False,
        },
        "remaining_gap": (
            "Same-run tile/object payload replay is only a final writeout-boundary checkpoint. "
            "The next unrecovered pieces are header/player/metadata payload sections and the "
            "ordered private-state mutation chain that produces these payloads from the RMG entrypoint."
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--ghidra-tile-writer", type=Path, default=DEFAULT_GHIDRA_TILE_WRITER)
    parser.add_argument("--static", type=Path, default=DEFAULT_STATIC)
    parser.add_argument("--callstream", type=Path, default=DEFAULT_CALLSTREAM)
    parser.add_argument("--profile", default=DEFAULT_PROFILE)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--tile-summary-out", type=Path, default=DEFAULT_TILE_OUT)
    parser.add_argument("--tile-bytes-out", type=Path, default=DEFAULT_TILE_BYTES_OUT)
    parser.add_argument("--object-summary-out", type=Path, default=DEFAULT_OBJECT_OUT)
    parser.add_argument("--object-bytes-out", type=Path, default=DEFAULT_OBJECT_BYTES_OUT)
    args = parser.parse_args()

    summary = summarize(
        args.ledger,
        args.ghidra_tile_writer,
        args.static,
        args.callstream,
        args.tile_summary_out,
        args.tile_bytes_out,
        args.object_summary_out,
        args.object_bytes_out,
        args.profile,
    )
    write_json(args.out, summary)
    print(
        "RMG_H3MAPED_SAME_RUN_FINAL_PAYLOAD "
        f"status={summary['status']} "
        f"tile_bytes={summary['metrics']['tile_payload_byte_count']} "
        f"object_bytes={summary['metrics']['object_payload_byte_count']} "
        f"objects={summary['metrics']['object_count']} "
        f"out={args.out}"
    )
    return 0 if summary["metrics"]["same_run_tile_object_payload_stitching_complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
