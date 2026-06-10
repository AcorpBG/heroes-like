#!/usr/bin/env python3
"""Summarize same-run H3MapEd final tile, object, and metadata payload replay.

This is a final-writeout stitching checkpoint over one Wine ledger. It proves
the sampled H3MapEd run can replay all known final writeout payload surfaces
together, but it deliberately does not claim ordered private-state mutation
parity or native RMG behavior parity.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

from rmg_h3maped_final_header_metadata_payload_summary import (
    summarize as summarize_header_payload,
)
from rmg_h3maped_final_object_payload_replay_summary import (
    DEFAULT_CALLSTREAM,
    DEFAULT_STATIC,
    summarize as summarize_object_payload,
)
from rmg_h3maped_final_tile_payload_summary import summarize as summarize_tile_payload


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_LEDGER = (
    ROOT
    / "medium_seed10_same_run_full_writeout_payload_20260610"
    / "winedbg_interactive_trace_ledger.json"
)
DEFAULT_OUT = ROOT / "same_run_full_writeout_payload_summary_20260610.json"
DEFAULT_TILE_OUT = ROOT / "same_run_full_writeout_tile_payload_summary_20260610.json"
DEFAULT_TILE_BYTES_OUT = ROOT / "same_run_full_writeout_tile_payload_bytes_20260610.bin"
DEFAULT_OBJECT_OUT = ROOT / "same_run_full_writeout_object_payload_summary_20260610.json"
DEFAULT_OBJECT_BYTES_OUT = ROOT / "same_run_full_writeout_object_payload_bytes_20260610.bin"
DEFAULT_HEADER_OUT = ROOT / "same_run_full_writeout_header_metadata_payload_summary_20260610.json"
DEFAULT_HEADER_BYTES_OUT = (
    ROOT / "same_run_full_writeout_header_metadata_payload_bytes_20260610.bin"
)
DEFAULT_GHIDRA_TILE_WRITER = (
    ROOT / "ghidra_writeout_spine_dump_20260610" / "target_0049b2b6_FUN_0049b2b6.txt"
)
DEFAULT_GHIDRA_HEADER_DIR = ROOT / "ghidra_final_header_metadata_helpers_20260610"

FINAL_TILE_SITE = "0x004ad251"
FINAL_HEADER_SENTINEL_SITE = "0x004ad3db"
FINAL_OBJECT_SUCCESS_SITE = "0x004ad3de"


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def sha256_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def summarize(
    ledger_path: Path,
    ghidra_tile_writer: Path,
    static_path: Path,
    callstream_path: Path,
    ghidra_header_dir: Path,
    tile_summary_out: Path,
    tile_bytes_out: Path,
    object_summary_out: Path,
    object_bytes_out: Path,
    header_summary_out: Path,
    header_bytes_out: Path,
) -> dict[str, Any]:
    ledger = load_json(ledger_path)
    events = ledger.get("events", [])

    tile_summary, tile_payload = summarize_tile_payload(ledger_path, ghidra_tile_writer)
    object_summary, object_payload = summarize_object_payload(
        ledger_path,
        static_path,
        callstream_path,
        object_bytes_out,
    )
    header_summary, header_payload = summarize_header_payload(ledger_path, ghidra_header_dir)

    tile_bytes_out.parent.mkdir(parents=True, exist_ok=True)
    object_bytes_out.parent.mkdir(parents=True, exist_ok=True)
    header_bytes_out.parent.mkdir(parents=True, exist_ok=True)
    tile_bytes_out.write_bytes(tile_payload)
    object_bytes_out.write_bytes(object_payload)
    header_bytes_out.write_bytes(header_payload)
    write_json(tile_summary_out, tile_summary)
    write_json(object_summary_out, object_summary)
    write_json(header_summary_out, header_summary)

    tile_event_count = sum(1 for event in events if event.get("address") == FINAL_TILE_SITE)
    header_sentinel_count = sum(
        1 for event in events if event.get("address") == FINAL_HEADER_SENTINEL_SITE
    )
    object_success_count = sum(
        1 for event in events if event.get("address") == FINAL_OBJECT_SUCCESS_SITE
    )

    tile_complete = (
        tile_summary.get("metrics", {}).get("final_tile_payload_replay_complete") is True
    )
    object_complete = (
        object_summary.get("metrics", {}).get("final_object_payload_replay_complete") is True
    )
    header_complete = (
        header_summary.get("metrics", {}).get("header_player_metadata_payload_replay_complete")
        is True
    )
    stitch_complete = (
        tile_complete
        and object_complete
        and header_complete
        and tile_event_count == 1
        and header_sentinel_count == 1
        and object_success_count == 1
    )

    return {
        "schema_id": "h3maped_same_run_full_writeout_payload_summary_v1",
        "status": (
            "same_run_full_writeout_payload_stitched"
            if stitch_complete
            else "same_run_full_writeout_payload_incomplete"
        ),
        "scope": {
            "profile": "H3MapEd Medium one-level no-water seed 10, human/computer down 1, computer-only down 0",
            "positive_claim": (
                "same-run replay checkpoint for final generated-cell tile bytes, generated-object "
                "stream-write bytes, and header/player/static metadata stream-write bytes"
            ),
            "negative_claim": (
                "does not provide ordered private-state mutation replay and does not change native RMG behavior"
            ),
        },
        "inputs": {
            "ledger": str(ledger_path),
            "ghidra_tile_writer": str(ghidra_tile_writer),
            "object_static_serializer_summary": str(static_path),
            "object_callstream_summary": str(callstream_path),
            "ghidra_header_metadata_dir": str(ghidra_header_dir),
        },
        "outputs": {
            "tile_summary": str(tile_summary_out),
            "tile_payload_bytes": str(tile_bytes_out),
            "object_summary": str(object_summary_out),
            "object_payload_bytes": str(object_bytes_out),
            "header_summary": str(header_summary_out),
            "header_payload_bytes": str(header_bytes_out),
        },
        "metrics": {
            "trace_event_count": ledger.get("event_count"),
            "final_tile_event_count": tile_event_count,
            "final_header_sentinel_event_count": header_sentinel_count,
            "final_object_success_event_count": object_success_count,
            "tile_payload_replay_complete": tile_complete,
            "tile_payload_cell_count": tile_summary.get("metrics", {}).get("cell_count"),
            "tile_payload_byte_count": tile_summary.get("metrics", {}).get(
                "tile_payload_byte_count"
            ),
            "tile_payload_sha256": sha256_bytes(tile_payload),
            "object_payload_replay_complete": object_complete,
            "object_payload_object_count": object_summary.get("metrics", {}).get("object_count"),
            "object_payload_write_event_count": object_summary.get("metrics", {}).get(
                "write_event_count"
            ),
            "object_payload_byte_count": object_summary.get("metrics", {}).get(
                "payload_byte_count"
            ),
            "object_payload_sha256": sha256_bytes(object_payload),
            "header_player_metadata_payload_replay_complete": header_complete,
            "header_player_metadata_decoded_event_count": header_summary.get("metrics", {}).get(
                "decoded_event_count"
            ),
            "header_player_metadata_payload_byte_count": header_summary.get("metrics", {}).get(
                "payload_byte_count"
            ),
            "header_player_metadata_payload_sha256": sha256_bytes(header_payload),
            "same_run_full_writeout_payload_stitching_complete": stitch_complete,
            "ordered_private_state_mutation_replay_complete": False,
            "full_private_payload_replay_complete": False,
            "native_behavior_changed": False,
            "used_objdump": False,
            "overall_goal_complete": False,
        },
        "remaining_gap": (
            "Same-run full writeout payload stitching is only a final serialization checkpoint. "
            "The remaining unrecovered work is the ordered private-state mutation chain that produces "
            "the final tile/object/header/player/metadata payloads from the RMG entrypoint."
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--ghidra-tile-writer", type=Path, default=DEFAULT_GHIDRA_TILE_WRITER)
    parser.add_argument("--static", type=Path, default=DEFAULT_STATIC)
    parser.add_argument("--callstream", type=Path, default=DEFAULT_CALLSTREAM)
    parser.add_argument("--ghidra-header-dir", type=Path, default=DEFAULT_GHIDRA_HEADER_DIR)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--tile-summary-out", type=Path, default=DEFAULT_TILE_OUT)
    parser.add_argument("--tile-bytes-out", type=Path, default=DEFAULT_TILE_BYTES_OUT)
    parser.add_argument("--object-summary-out", type=Path, default=DEFAULT_OBJECT_OUT)
    parser.add_argument("--object-bytes-out", type=Path, default=DEFAULT_OBJECT_BYTES_OUT)
    parser.add_argument("--header-summary-out", type=Path, default=DEFAULT_HEADER_OUT)
    parser.add_argument("--header-bytes-out", type=Path, default=DEFAULT_HEADER_BYTES_OUT)
    args = parser.parse_args()

    summary = summarize(
        args.ledger,
        args.ghidra_tile_writer,
        args.static,
        args.callstream,
        args.ghidra_header_dir,
        args.tile_summary_out,
        args.tile_bytes_out,
        args.object_summary_out,
        args.object_bytes_out,
        args.header_summary_out,
        args.header_bytes_out,
    )
    write_json(args.out, summary)
    print(
        "RMG_H3MAPED_SAME_RUN_FULL_WRITEOUT_PAYLOAD "
        f"status={summary['status']} "
        f"tile_bytes={summary['metrics']['tile_payload_byte_count']} "
        f"object_bytes={summary['metrics']['object_payload_byte_count']} "
        f"header_bytes={summary['metrics']['header_player_metadata_payload_byte_count']} "
        f"out={args.out}"
    )
    return 0 if summary["metrics"]["same_run_full_writeout_payload_stitching_complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
