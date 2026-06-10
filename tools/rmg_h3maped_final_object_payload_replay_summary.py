#!/usr/bin/env python3
"""Replay final H3MapEd generated-object payload bytes from stream-write stops.

The input trace must break at the recovered generated-object stream-write call
sites before each indirect call executes. At those call sites, the stack shape
is:

    [ESP + 0x00] = buffer pointer
    [ESP + 0x04] = write length

The trace driver also dumps `x/8x *(int*)$esp`, so this script converts those
little-endian dwords back to bytes and slices by the recovered write length.

This is object-payload replay only. It does not claim full H3M writeout replay
unless paired with the tile-payload checkpoint.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from collections import Counter
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_LEDGER = (
    ROOT
    / "medium_seed10_final_object_stream_write_dwords_20260610"
    / "winedbg_interactive_trace_ledger.json"
)
DEFAULT_STATIC = ROOT / "final_object_serializer_static_summary_20260610.json"
DEFAULT_CALLSTREAM = ROOT / "final_object_callstream_summary_20260610.json"
DEFAULT_OUT = ROOT / "final_object_payload_replay_summary_20260610.json"
DEFAULT_BYTES_OUT = ROOT / "final_object_payload_replay_bytes_20260610.bin"

BASE_FIRST_WRITE = "0x0049bb14"
FINAL_SITE = "0x004ad3de"


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def hex32(value: int | None) -> str | None:
    if value is None:
        return None
    return "0x%08x" % (value & 0xFFFFFFFF)


def line_words(event: dict[str, Any], start: int, count: int) -> list[int]:
    words: list[int] = []
    for line in event.get("memory_lines", [])[start : start + count]:
        words.extend(int(word) & 0xFFFFFFFF for word in line.get("words", []))
    return words


def dwords_to_little_bytes(words: list[int]) -> bytes:
    out = bytearray()
    for word in words:
        out.extend(int(word & 0xFFFFFFFF).to_bytes(4, "little"))
    return bytes(out)


def static_write_sizes(static: dict[str, Any]) -> dict[str, int]:
    sizes: dict[str, int] = {}
    for function in static.get("functions", {}).values():
        for write in function.get("stream_writes", []):
            address = write.get("address")
            size = write.get("size")
            if address and size is not None:
                sizes[address] = int(size)
    return sizes


def callsite_to_function(static: dict[str, Any]) -> dict[str, str]:
    mapping: dict[str, str] = {}
    for entry, function in static.get("functions", {}).items():
        for write in function.get("stream_writes", []):
            address = write.get("address")
            if address:
                mapping[address] = entry
    return mapping


def parse_write_event(event: dict[str, Any], expected_sizes: dict[str, int]) -> dict[str, Any]:
    address = event.get("address")
    stack_words = line_words(event, 0, 2)
    buffer_words = line_words(event, 2, 2)
    buffer_pointer = stack_words[0] if len(stack_words) > 0 else None
    length = stack_words[1] if len(stack_words) > 1 else None
    buffer_base = None
    memory_lines = event.get("memory_lines", [])
    if len(memory_lines) > 2:
        buffer_base = memory_lines[2].get("address")
    raw_bytes = dwords_to_little_bytes(buffer_words)
    payload = raw_bytes[: int(length or 0)]
    expected_size = expected_sizes.get(address)
    return {
        "address": address,
        "buffer_pointer": buffer_pointer,
        "buffer_dump_base": buffer_base,
        "length": length,
        "expected_size": expected_size,
        "size_matches_static": expected_size == length,
        "payload": payload,
        "registers": event.get("registers", {}),
    }


def summarize(
    ledger_path: Path,
    static_path: Path,
    callstream_path: Path,
    bytes_out: Path,
) -> tuple[dict[str, Any], bytes]:
    ledger = load_json(ledger_path)
    static = load_json(static_path)
    callstream = load_json(callstream_path)
    expected_sizes = static_write_sizes(static)
    site_to_function = callsite_to_function(static)
    write_sites = set(expected_sizes)

    write_events = [
        event for event in ledger.get("events", []) if event.get("address") in write_sites
    ]
    final_events = [event for event in ledger.get("events", []) if event.get("address") == FINAL_SITE]
    parsed = [parse_write_event(event, expected_sizes) for event in write_events]

    objects: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    stream = bytearray()
    counts_by_site: Counter[str] = Counter()
    bytes_by_site: Counter[str] = Counter()
    counts_by_function: Counter[str] = Counter()
    size_mismatches: list[dict[str, Any]] = []
    bad_buffer_dumps: list[dict[str, Any]] = []
    missing_lengths: list[dict[str, Any]] = []

    for index, event in enumerate(parsed):
        address = event["address"]
        payload = event["payload"]
        if address == BASE_FIRST_WRITE:
            if current is not None:
                objects.append(current)
            current = {
                "object_index": len(objects),
                "first_event_index": index,
                "write_count": 0,
                "byte_count": 0,
                "sha256": None,
                "events": [],
                "_payload": bytearray(),
            }
        if current is None:
            current = {
                "object_index": len(objects),
                "first_event_index": index,
                "write_count": 0,
                "byte_count": 0,
                "sha256": None,
                "events": [],
                "_payload": bytearray(),
                "warning": "stream did not start at base first write",
            }
        stream.extend(payload)
        current["_payload"].extend(payload)
        current["write_count"] += 1
        current["byte_count"] += len(payload)
        current["events"].append(
            {
                "event_index": index,
                "address": address,
                "function": site_to_function.get(address),
                "length": event["length"],
                "payload_hex": payload.hex(),
            }
        )
        counts_by_site[address] += 1
        bytes_by_site[address] += len(payload)
        if site_to_function.get(address):
            counts_by_function[site_to_function[address]] += 1
        if not event["size_matches_static"]:
            size_mismatches.append(
                {
                    "event_index": index,
                    "address": address,
                    "length": event["length"],
                    "expected_size": event["expected_size"],
                }
            )
        if event["length"] is None:
            missing_lengths.append({"event_index": index, "address": address})
        if event["buffer_pointer"] != event["buffer_dump_base"]:
            bad_buffer_dumps.append(
                {
                    "event_index": index,
                    "address": address,
                    "buffer_pointer": hex32(event["buffer_pointer"]),
                    "buffer_dump_base": hex32(event["buffer_dump_base"]),
                }
            )
    if current is not None:
        objects.append(current)

    object_summaries: list[dict[str, Any]] = []
    for obj in objects:
        payload = bytes(obj.pop("_payload"))
        obj["sha256"] = hashlib.sha256(payload).hexdigest()
        object_summaries.append(obj)

    payload_bytes = bytes(stream)
    bytes_out.parent.mkdir(parents=True, exist_ok=True)
    bytes_out.write_bytes(payload_bytes)

    expected_object_count = callstream.get("metrics", {}).get("serializer_event_count")
    expected_weighted_writes = static.get("metrics", {}).get("weighted_minimum_stream_write_events_in_run")
    matches_prior_callstream = (
        len(objects) == expected_object_count
        and len(parsed) == expected_weighted_writes
    )
    replay_complete = (
        bool(parsed)
        and len(final_events) == 1
        and len(bad_buffer_dumps) == 0
        and len(missing_lengths) == 0
        and len(objects) > 0
        and all(obj.get("events", [{}])[0].get("address") == BASE_FIRST_WRITE for obj in object_summaries)
    )

    summary = {
        "schema_id": "h3maped_final_object_payload_replay_summary_v1",
        "status": "final_object_payload_replay_recovered" if replay_complete else "final_object_payload_replay_incomplete",
        "scope": {
            "profile": callstream.get("scope", {}).get("profile"),
            "positive_claim": "final generated-object payload byte replay from recovered stream-write call sites",
            "negative_claim": "does not include terrain/tile payload bytes and does not mutate native RMG",
        },
        "inputs": {
            "ledger": str(ledger_path),
            "static_serializer_summary": str(static_path),
            "callstream_summary": str(callstream_path),
        },
        "outputs": {"payload_bytes": str(bytes_out)},
        "metrics": {
            "trace_event_count": ledger.get("event_count"),
            "write_event_count": len(parsed),
            "expected_write_event_count": expected_weighted_writes,
            "final_success_event_count": len(final_events),
            "object_count": len(objects),
            "prior_callstream_expected_object_count": expected_object_count,
            "payload_byte_count": len(payload_bytes),
            "payload_sha256": hashlib.sha256(payload_bytes).hexdigest(),
            "unique_write_site_count": len(counts_by_site),
            "expected_write_site_count": len(write_sites),
            "size_mismatch_count": len(size_mismatches),
            "bad_buffer_dump_count": len(bad_buffer_dumps),
            "missing_length_count": len(missing_lengths),
            "matches_prior_callstream_counts": matches_prior_callstream,
            "final_object_payload_replay_complete": replay_complete,
            "generated_object_payload_replay_complete": replay_complete,
            "full_private_payload_replay_complete": False,
            "native_behavior_changed": False,
            "used_objdump": False,
            "overall_goal_complete": False,
        },
        "counts_by_write_site": dict(sorted(counts_by_site.items())),
        "bytes_by_write_site": dict(sorted(bytes_by_site.items())),
        "counts_by_serializer_function": dict(sorted(counts_by_function.items())),
        "first_objects": object_summaries[:5],
        "last_objects": object_summaries[-5:],
        "size_mismatches": size_mismatches[:32],
        "bad_buffer_dumps": bad_buffer_dumps[:32],
        "missing_lengths": missing_lengths[:32],
        "remaining_gap": (
            "Object payload bytes are recovered only if final_object_payload_replay_complete is true. "
            "Full end-to-end recovery still also requires same-run stitching of tile payload, object payload, "
            "header/player/metadata sections, and native private-state phase parity before native RMG edits."
        ),
    }
    return summary, payload_bytes


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--static", type=Path, default=DEFAULT_STATIC)
    parser.add_argument("--callstream", type=Path, default=DEFAULT_CALLSTREAM)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--bytes-out", type=Path, default=DEFAULT_BYTES_OUT)
    args = parser.parse_args()

    summary, _ = summarize(args.ledger, args.static, args.callstream, args.bytes_out)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_FINAL_OBJECT_PAYLOAD_REPLAY "
        f"status={summary['status']} "
        f"objects={summary['metrics']['object_count']} "
        f"writes={summary['metrics']['write_event_count']} "
        f"bytes={summary['metrics']['payload_byte_count']} "
        f"sha256={summary['metrics']['payload_sha256']} "
        f"out={args.out}"
    )
    return 0 if summary["metrics"]["final_object_payload_replay_complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
