#!/usr/bin/env python3
"""Replay H3MapEd final header/player/metadata bytes from a Wine trace."""

from __future__ import annotations

import argparse
import hashlib
import json
from collections import Counter
from pathlib import Path
from typing import Any

from rmg_h3maped_final_header_metadata_static_summary import summarize as summarize_static


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_LEDGER = (
    ROOT
    / "medium_seed10_final_header_metadata_payload_20260610"
    / "winedbg_interactive_trace_ledger.json"
)
DEFAULT_GHIDRA_DIR = ROOT / "ghidra_final_header_metadata_helpers_20260610"
DEFAULT_OUT = ROOT / "final_header_metadata_payload_summary_20260610.json"
DEFAULT_BYTES_OUT = ROOT / "final_header_metadata_payload_bytes_20260610.bin"

PROFILE = "H3MapEd Medium one-level no-water seed 10, human/computer down 1, computer-only down 0"


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def word_list_to_little_endian_bytes(words: list[int]) -> bytes:
    out = bytearray()
    for word in words:
        out.extend((int(word) & 0xFFFFFFFF).to_bytes(4, "little"))
    return bytes(out)


def flatten_words(lines: list[dict[str, Any]]) -> list[int]:
    return [int(word) & 0xFFFFFFFF for line in lines for word in line.get("words", [])]


def stack_words(event: dict[str, Any]) -> list[int]:
    lines = event.get("memory_lines", [])
    if not lines:
        return []
    words: list[int] = []
    # `x/8x $esp` is always emitted first. It may be one or two lines depending
    # on winedbg formatting; collect up to eight stack dwords before buffer dumps.
    first_address = lines[0].get("address")
    for line in lines:
        address = line.get("address")
        if not isinstance(first_address, int) or not isinstance(address, int):
            break
        if address < first_address or address > first_address + 0x40:
            break
        words.extend(int(word) & 0xFFFFFFFF for word in line.get("words", []))
        if len(words) >= 8:
            break
    return words


def buffer_words(event: dict[str, Any], buffer_pointer: int, stack_line_count_hint: int = 1) -> list[int]:
    lines = event.get("memory_lines", [])[stack_line_count_hint:]
    collected: list[int] = []
    expected_address = buffer_pointer
    started = False
    for line in lines:
        address = line.get("address")
        words = line.get("words", [])
        if not isinstance(address, int) or not words:
            continue
        if not started:
            if address != buffer_pointer:
                continue
            started = True
        elif address != expected_address:
            break
        collected.extend(int(word) & 0xFFFFFFFF for word in words)
        expected_address = address + (len(words) * 4)
    return collected


def infer_stack_line_count(event: dict[str, Any]) -> int:
    words_seen = 0
    for index, line in enumerate(event.get("memory_lines", [])):
        words_seen += len(line.get("words", []))
        if words_seen >= 8:
            return index + 1
    return 1


def section_for_site(site: dict[str, Any]) -> str:
    address = site["address"]
    function = site["function_entry"]
    if function == "0x004ac857":
        if address <= "0x004ac92b":
            return "map_header_and_generated_text"
        if address <= "0x004aca94":
            return "map_description_and_victory_metadata"
        if address <= "0x004ace60":
            return "player_slot_records"
        if address <= "0x004ad019":
            return "team_and_metadata_bitsets"
        return "final_header_padding"
    if function == "0x004ad1e3":
        if address == "0x004ad206":
            return "post_header_initial_zero"
        if address == "0x004ad29f":
            return "object_definition_type_count"
        if address == "0x004ad330":
            return "generated_object_count"
        if address == "0x004ad3db":
            return "final_zero_sentinel"
        return "final_writeout_spine"
    if function == "0x004ad3eb":
        return "object_definition_metadata"
    return "metadata_helper_payload"


def summarize(ledger_path: Path, ghidra_dir: Path, profile: str = PROFILE) -> tuple[dict[str, Any], bytes]:
    ledger = load_json(ledger_path)
    static = summarize_static(ghidra_dir)
    raw_sites = {site["address"]: site for site in static["raw_stream_write_sites"]}
    required_addresses = set(raw_sites)

    events = [event for event in ledger.get("events", []) if event.get("address") in required_addresses]
    events_by_address = Counter(event.get("address") for event in events)
    unhit_possible_addresses = sorted(required_addresses - set(events_by_address))
    unexpected_addresses = sorted(
        {
            event.get("address")
            for event in ledger.get("events", [])
            if event.get("address") and event.get("address") not in required_addresses
        }
    )

    payload = bytearray()
    decoded_events: list[dict[str, Any]] = []
    malformed_events: list[dict[str, Any]] = []
    truncated_events: list[dict[str, Any]] = []
    section_counts: Counter[str] = Counter()
    section_bytes: Counter[str] = Counter()

    for index, event in enumerate(events):
        address = event["address"]
        site = raw_sites[address]
        stack = stack_words(event)
        if len(stack) < 2:
            malformed_events.append({"event_index": index, "address": address, "reason": "missing_stack_buffer_length"})
            continue
        buffer_pointer = stack[0]
        length = stack[1]
        stack_line_count = infer_stack_line_count(event)
        words = buffer_words(event, buffer_pointer, stack_line_count)
        raw_bytes = word_list_to_little_endian_bytes(words)
        recovered = raw_bytes[:length]
        truncated = len(raw_bytes) < length
        section = section_for_site(site)

        if truncated:
            truncated_events.append(
                {
                    "event_index": index,
                    "address": address,
                    "buffer_pointer": f"0x{buffer_pointer:08x}",
                    "requested_length": length,
                    "captured_byte_count": len(raw_bytes),
                    "section": section,
                }
            )
        payload.extend(recovered)
        section_counts[section] += 1
        section_bytes[section] += len(recovered)

        decoded_events.append(
            {
                "event_index": index,
                "address": address,
                "function_entry": site["function_entry"],
                "function_role": site["function_role"],
                "section": section,
                "buffer_pointer": f"0x{buffer_pointer:08x}",
                "requested_length": length,
                "captured_byte_count": min(length, len(raw_bytes)),
                "truncated": truncated,
                "sha256": hashlib.sha256(recovered).hexdigest(),
                "first_bytes_hex": recovered[:32].hex(),
            }
        )

    final_sentinel_hit = events_by_address.get("0x004ad3db", 0) == 1
    observed_path_complete = (
        static["status"] == "final_header_player_metadata_static_contract_recovered"
        and bool(events)
        and final_sentinel_hit
        and not malformed_events
        and not truncated_events
    )

    summary = {
        "schema_id": "h3maped_final_header_metadata_payload_summary_v1",
        "status": (
            "final_header_player_metadata_payload_replay_recovered"
            if observed_path_complete
            else "final_header_player_metadata_payload_replay_incomplete"
        ),
        "scope": {
            "profile": profile,
            "positive_claim": "same-run byte replay for raw final header/player/static metadata stream writes around 0x4ac857, 0x4ad1e3, 0x4ad3eb, and their direct metadata helpers",
            "negative_claim": "does not replay tile bytes, generated-object vtable payloads, or claim native RMG parity",
        },
        "inputs": {
            "ledger": str(ledger_path),
            "ghidra_dir": str(ghidra_dir),
        },
        "metrics": {
            "ledger_event_count": ledger.get("event_count"),
            "required_raw_stream_write_site_count": len(raw_sites),
            "required_raw_stream_write_sites_hit": len(events_by_address),
            "decoded_event_count": len(decoded_events),
            "payload_byte_count": len(payload),
            "payload_sha256": hashlib.sha256(payload).hexdigest(),
            "unhit_possible_address_count": len(unhit_possible_addresses),
            "malformed_event_count": len(malformed_events),
            "truncated_event_count": len(truncated_events),
            "unexpected_trace_address_count": len(unexpected_addresses),
            "final_sentinel_hit": final_sentinel_hit,
            "header_player_metadata_observed_path_payload_replay_complete": observed_path_complete,
            "header_player_metadata_payload_replay_complete": observed_path_complete,
            "native_behavior_changed": False,
            "used_objdump": False,
            "full_private_payload_replay_complete": False,
            "overall_goal_complete": False,
        },
        "events_by_address": dict(sorted(events_by_address.items())),
        "section_event_counts": dict(sorted(section_counts.items())),
        "section_byte_counts": dict(sorted(section_bytes.items())),
        "unhit_possible_addresses": unhit_possible_addresses,
        "unexpected_trace_addresses": unexpected_addresses,
        "malformed_events": malformed_events,
        "truncated_events": truncated_events,
        "static_contract": static,
        "decoded_events": decoded_events,
        "remaining_gap": (
            "Header/player/static metadata raw stream writes are replayed when complete. "
            "Full writeout parity still also requires the already separate tile/generated-object payloads "
            "and ordered private-state mutation replay."
        ),
    }
    return summary, bytes(payload)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ledger", type=Path, default=DEFAULT_LEDGER)
    parser.add_argument("--ghidra-dir", type=Path, default=DEFAULT_GHIDRA_DIR)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--bytes-out", type=Path, default=DEFAULT_BYTES_OUT)
    parser.add_argument("--profile", default=PROFILE)
    args = parser.parse_args()

    summary, payload = summarize(args.ledger, args.ghidra_dir, args.profile)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.bytes_out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    args.bytes_out.write_bytes(payload)
    print(
        "RMG_H3MAPED_FINAL_HEADER_METADATA_PAYLOAD "
        f"status={summary['status']} "
        f"events={summary['metrics']['decoded_event_count']} "
        f"bytes={summary['metrics']['payload_byte_count']} "
        f"sha256={summary['metrics']['payload_sha256']} "
        f"out={args.out}"
    )
    return 0 if summary["metrics"]["header_player_metadata_payload_replay_complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
