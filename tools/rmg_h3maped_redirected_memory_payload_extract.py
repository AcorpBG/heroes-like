#!/usr/bin/env python3
"""Extract the uncompressed H3 payload from a redirected H3MapEd final write."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


FINAL_WRITER_ADDRESS = 0x004AD3DE
REDIRECT_ADDRESS = 0x004AD1E3
MEMORY_STREAM_VTABLE = 0x005398E0
MAX_CAPTURE_BYTES = 16 * 1024 * 1024
GZIP_PRELUDE = bytes.fromhex("1f8b080000000000000b")
H3_AB_VERSION = (0x1C).to_bytes(4, "little")
REDIRECT_COMMAND = (
    "0x004ad1e3=set *(int*)(*(int*)($esp+4)+4) = "
    "*(int*)(*(int*)(*(int*)($esp+4)+4)+0x38)"
)
AUTHORITY_SECTION_ORDER = (
    "header_player_metadata",
    "post_header_initial_zero",
    "tile_stream",
    "object_definition_count",
    "object_definition_table",
    "generated_object_count",
    "generated_object_payload",
    "final_zero_sentinel",
)


def parse_address(value: Any) -> int:
    if isinstance(value, int):
        return value
    return int(str(value), 0)


def load_ledger(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError("ledger root must be an object")
    return value


def build_memory_maps(
    memory_lines: list[dict[str, Any]],
) -> tuple[dict[int, int], dict[int, int], list[str]]:
    words: dict[int, int] = {}
    byte_values: dict[int, int] = {}
    failures: list[str] = []
    for line in memory_lines:
        line_address = parse_address(line["address"])
        for index, raw_word in enumerate(line.get("words", [])):
            address = line_address + index * 4
            word = int(raw_word)
            if not 0 <= word <= 0xFFFFFFFF:
                failures.append("memory_word_out_of_range")
                continue
            previous_word = words.get(address)
            if previous_word is not None and previous_word != word:
                failures.append("conflicting_overlapping_memory_words")
            words[address] = word
            for byte_index, byte_value in enumerate(word.to_bytes(4, "little")):
                byte_address = address + byte_index
                previous_byte = byte_values.get(byte_address)
                if previous_byte is not None and previous_byte != byte_value:
                    failures.append("conflicting_overlapping_memory_bytes")
                byte_values[byte_address] = byte_value
    return words, byte_values, sorted(set(failures))


def find_memory_stream_candidates(words: dict[int, int]) -> list[int]:
    candidates: list[int] = []
    for address, word in words.items():
        if word != MEMORY_STREAM_VTABLE:
            continue
        base = words.get(address + 0x04)
        end = words.get(address + 0x18)
        if base is None or end is None:
            continue
        if words.get(address + 0x08) != base or words.get(address + 0x14) != base:
            continue
        if words.get(address + 0x0C) != address + 0x04:
            continue
        if words.get(address + 0x10) != address + 0x08:
            continue
        if words.get(address + 0x1C) != address + 0x14:
            continue
        if end < base:
            continue
        candidates.append(address)
    return sorted(candidates)


def extract(ledger_path: Path) -> tuple[dict[str, Any], bytes]:
    ledger = load_ledger(ledger_path)
    failures: list[str] = []
    breakpoints = {parse_address(value) for value in ledger.get("breakpoints", [])}
    if not {REDIRECT_ADDRESS, FINAL_WRITER_ADDRESS}.issubset(breakpoints):
        failures.append("required_breakpoints_missing")
    if parse_address(ledger.get("stop_after", 0)) != FINAL_WRITER_ADDRESS:
        failures.append("final_writer_not_stop_address")
    if REDIRECT_COMMAND not in ledger.get("address_command", []):
        failures.append("exact_memory_stream_redirection_not_proven")

    events = ledger.get("events", [])
    final_event = events[-1] if events else {}
    if parse_address(final_event.get("address", 0)) != FINAL_WRITER_ADDRESS:
        failures.append("final_event_not_final_writer_return")
    registers = final_event.get("registers", {})
    if registers.get("eax") != 4:
        failures.append("final_writer_did_not_report_success")

    words, byte_values, memory_failures = build_memory_maps(
        final_event.get("memory_lines", [])
    )
    failures.extend(memory_failures)
    candidates = find_memory_stream_candidates(words)
    if len(candidates) != 1:
        failures.append("memory_stream_object_not_unique")

    stream_object = candidates[0] if len(candidates) == 1 else None
    base = words.get(stream_object + 0x04) if stream_object is not None else None
    end = words.get(stream_object + 0x18) if stream_object is not None else None
    capture = b""
    payload = b""
    if base is not None and end is not None:
        capture_length = end - base
        if capture_length <= len(GZIP_PRELUDE) or capture_length > MAX_CAPTURE_BYTES:
            failures.append("memory_stream_capture_length_invalid")
        else:
            missing = [address for address in range(base, end) if address not in byte_values]
            if missing:
                failures.append("memory_stream_capture_has_gaps")
            else:
                capture = bytes(byte_values[address] for address in range(base, end))
                if not capture.startswith(GZIP_PRELUDE):
                    failures.append("recovered_gzip_prelude_mismatch")
                else:
                    payload = capture[len(GZIP_PRELUDE) :]
                    if not payload.startswith(H3_AB_VERSION):
                        failures.append("h3_payload_version_mismatch")
    else:
        failures.append("memory_stream_bounds_missing")

    failures = sorted(set(failures))
    complete = not failures
    summary = {
        "schema_id": "h3maped_redirected_memory_payload_extract_v1",
        "status": (
            "redirected_h3maped_final_payload_extracted"
            if complete
            else "redirected_h3maped_final_payload_incomplete"
        ),
        "scope": {
            "positive_claim": (
                "complete uncompressed final-writer payload extracted from the recovered "
                "H3MapEd growable memory stream"
            ),
            "negative_claim": (
                "does not prove deterministic source-run identity or native generation parity"
            ),
        },
        "inputs": {"ledger": str(ledger_path)},
        "metrics": {
            "capture_byte_count": len(capture),
            "capture_sha256": hashlib.sha256(capture).hexdigest() if capture else None,
            "gzip_prelude_byte_count": len(GZIP_PRELUDE) if capture else 0,
            "payload_byte_count": len(payload),
            "payload_sha256": hashlib.sha256(payload).hexdigest() if payload else None,
            "final_edi": registers.get("edi"),
            "extraction_complete": complete,
            "native_behavior_changed": False,
            "native_parity_complete": False,
            "overall_goal_complete": False,
        },
        "recovered_state": {
            "memory_stream_vtable": f"0x{MEMORY_STREAM_VTABLE:08x}",
            "memory_stream_object": f"0x{stream_object:08x}" if stream_object is not None else None,
            "capture_base": f"0x{base:08x}" if base is not None else None,
            "capture_end": f"0x{end:08x}" if end is not None else None,
            "candidate_count": len(candidates),
            "gzip_prelude_hex": GZIP_PRELUDE.hex() if capture else None,
        },
        "failures": failures,
    }
    return summary, payload


def build_authority_slices(
    payload: bytes,
    section_layout_path: Path,
    ledger_path: Path,
    profile: str,
) -> tuple[dict[str, Any], bytes, bytes]:
    layout = json.loads(section_layout_path.read_text(encoding="utf-8"))
    raw_sections = layout.get("sections", [])
    if not isinstance(raw_sections, list):
        raise ValueError("section layout sections must be a list")
    sections = {str(section.get("section_id", "")): section for section in raw_sections}
    if tuple(section.get("section_id") for section in raw_sections) != AUTHORITY_SECTION_ORDER:
        raise ValueError("section layout does not contain the recovered eight-section write order")

    cursor = 0
    payloads: dict[str, bytes] = {}
    for section_id in AUTHORITY_SECTION_ORDER:
        section = sections[section_id]
        offset = int(section.get("offset", -1))
        byte_count = int(section.get("byte_count", -1))
        if offset != cursor or byte_count < 0 or offset + byte_count > len(payload):
            raise ValueError(f"invalid or non-contiguous section layout for {section_id}")
        payloads[section_id] = payload[offset : offset + byte_count]
        cursor += byte_count
    if cursor != len(payload):
        raise ValueError("section layout does not consume the recovered full payload")

    generated_object_count_bytes = payloads["generated_object_count"]
    if len(generated_object_count_bytes) != 4:
        raise ValueError("generated object count section is not four bytes")
    object_count = int.from_bytes(generated_object_count_bytes, "little")
    tile = payloads["tile_stream"]
    objects = payloads["generated_object_payload"]
    summary = {
        "schema_id": "h3maped_same_run_final_payload_summary_v1",
        "status": "same_run_final_tile_object_payload_stitched",
        "scope": {
            "profile": profile,
            "positive_claim": "tile and generated-object authority slices from the recovered complete final-writer payload",
            "negative_claim": "does not by itself prove native generation parity",
        },
        "inputs": {
            "ledger": str(ledger_path),
            "section_layout": str(section_layout_path),
        },
        "metrics": {
            "tile_payload_byte_count": len(tile),
            "tile_payload_sha256": hashlib.sha256(tile).hexdigest(),
            "object_count": object_count,
            "object_payload_byte_count": len(objects),
            "object_payload_sha256": hashlib.sha256(objects).hexdigest(),
            "same_run_tile_object_payload_stitching_complete": True,
            "native_behavior_changed": False,
            "native_parity_complete": False,
            "overall_goal_complete": False,
        },
    }
    return summary, tile, objects


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, required=True)
    parser.add_argument("--bytes-out", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--section-layout", type=Path)
    parser.add_argument("--profile")
    parser.add_argument("--authority-summary-out", type=Path)
    parser.add_argument("--tile-bytes-out", type=Path)
    parser.add_argument("--object-bytes-out", type=Path)
    args = parser.parse_args()

    authority_args = (
        args.section_layout,
        args.profile,
        args.authority_summary_out,
        args.tile_bytes_out,
        args.object_bytes_out,
    )
    if any(value is not None for value in authority_args) and not all(
        value is not None for value in authority_args
    ):
        parser.error(
            "--section-layout, --profile, --authority-summary-out, --tile-bytes-out, and --object-bytes-out must be provided together"
        )

    summary, payload = extract(args.ledger)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    if summary["metrics"]["extraction_complete"]:
        args.bytes_out.parent.mkdir(parents=True, exist_ok=True)
        args.bytes_out.write_bytes(payload)
        if args.section_layout is not None:
            authority_summary, tile_payload, object_payload = build_authority_slices(
                payload,
                args.section_layout,
                args.ledger,
                args.profile,
            )
            args.authority_summary_out.parent.mkdir(parents=True, exist_ok=True)
            args.tile_bytes_out.parent.mkdir(parents=True, exist_ok=True)
            args.object_bytes_out.parent.mkdir(parents=True, exist_ok=True)
            args.authority_summary_out.write_text(
                json.dumps(authority_summary, indent=2, sort_keys=True) + "\n",
                encoding="utf-8",
            )
            args.tile_bytes_out.write_bytes(tile_payload)
            args.object_bytes_out.write_bytes(object_payload)
    elif args.bytes_out.exists():
        args.bytes_out.unlink()
    print(
        "RMG_H3MAPED_REDIRECTED_MEMORY_PAYLOAD "
        f"status={summary['status']} "
        f"bytes={summary['metrics']['payload_byte_count']} "
        f"sha256={summary['metrics']['payload_sha256']} "
        f"out={args.out}"
    )
    return 0 if summary["metrics"]["extraction_complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
