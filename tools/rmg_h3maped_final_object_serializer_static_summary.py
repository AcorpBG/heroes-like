#!/usr/bin/env python3
"""Summarize H3MapEd final generated-object serializer bodies from Ghidra.

This is a recovery checkpoint for the object payload frontier. It consumes the
Ghidra dumps for the unique slot `+0x0c` serializer functions seen in the final
object writeout callstream and emits an explicit static write contract:

- every output-stream write call site found in each serializer body;
- the byte count pushed for that write when statically visible;
- object-record offsets read from `EDI`;
- direct helper calls such as the zero-fill helper used before fixed buffers;
- loop/nested-pointer candidates that still require dynamic byte capture.

It does not claim field-level payload replay. The next recovery step is to break
on the listed stream-write call sites, dump `(buffer, length)`, and rebuild the
exact bytes emitted by every object in the final run.
"""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_CALLSTREAM = ROOT / "final_object_callstream_summary_20260610.json"
DEFAULT_GHIDRA_DIR = ROOT / "ghidra_final_object_serializers_20260610"
DEFAULT_EXTRA_GHIDRA_DUMPS = [
    ROOT / "ghidra_selected_recycle_owner_dump_20260610" / "caller_0049c3f4_FUN_0049c3f4.txt"
]
DEFAULT_OUT = ROOT / "final_object_serializer_static_summary_20260610.json"

INSTRUCTION_RE = re.compile(r"^([0-9a-fA-F]{8}):\s+(.*)$")
TARGET_RE = re.compile(r"(?:target|caller)_([0-9a-fA-F]{8})_FUN_[0-9a-fA-F]+\.txt$")
PUSH_IMMEDIATE_RE = re.compile(r"^PUSH\s+0x([0-9a-fA-F]+)$")
CALL_DIRECT_RE = re.compile(r"^CALL\s+0x([0-9a-fA-F]+)$")
EDI_OFFSET_RE = re.compile(r"\[EDI\s+\+\s+0x([0-9a-fA-F]+)\]")
MEM_OFFSET_RE = re.compile(r"\[([A-Z]{2,3})\s+\+\s+0x([0-9a-fA-F]+)\]")
JUMP_RE = re.compile(r"^J[A-Z]+\s+0x([0-9a-fA-F]+)$")
STREAM_WRITE_TEXT = "CALL dword ptr [EAX + 0x8]"
BASE_SERIALIZER = "0x0049baf8"
ZERO_FILL_HELPER = "0x004e71c0"


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def hex32(value: int | str | None) -> str | None:
    if value is None:
        return None
    if isinstance(value, int):
        return "0x%08x" % (value & 0xFFFFFFFF)
    return "0x%08x" % int(value, 0)


def parse_instructions(path: Path) -> list[dict[str, Any]]:
    instructions: list[dict[str, Any]] = []
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        match = INSTRUCTION_RE.match(line)
        if not match:
            continue
        address = int(match.group(1), 16)
        text = match.group(2).strip()
        instructions.append({"address": address, "address_hex": hex32(address), "text": text})
    return instructions


def nearest_push_immediate(instructions: list[dict[str, Any]], index: int) -> int | None:
    for prior in reversed(instructions[max(0, index - 14) : index]):
        match = PUSH_IMMEDIATE_RE.match(prior["text"])
        if match:
            return int(match.group(1), 16)
        if prior["text"].startswith("PUSH "):
            register_value = constant_register_before(instructions, index, prior["text"].removeprefix("PUSH ").strip())
            if register_value is not None:
                return register_value
        if prior["text"].startswith("CALL "):
            break
    return None


def constant_register_before(instructions: list[dict[str, Any]], index: int, register: str) -> int | None:
    """Resolve the small constant-register idioms used for stream-write sizes."""

    register = register.upper()
    if register not in {"EAX", "EBX", "ECX", "EDX", "ESI", "EDI"}:
        return None
    value: int | None = None
    for position, instruction in enumerate(instructions[:index]):
        text = instruction["text"]
        if text == f"XOR {register},{register}":
            value = 0
            continue
        mov_match = re.match(rf"^MOV {register},0x([0-9a-fA-F]+)$", text)
        if mov_match:
            value = int(mov_match.group(1), 16)
            continue
        if text == f"POP {register}" and position > 0:
            push_match = None
            for prior in reversed(instructions[max(0, position - 4) : position]):
                if prior["text"].startswith("CALL "):
                    break
                push_match = PUSH_IMMEDIATE_RE.match(prior["text"])
                if push_match:
                    break
            if push_match:
                value = int(push_match.group(1), 16)
                continue
            value = None
            continue
        if text.startswith(f"MOV {register},") or text.startswith(f"LEA {register},"):
            value = None
    return value


def nearest_buffer_push(instructions: list[dict[str, Any]], index: int) -> str | None:
    for prior in reversed(instructions[max(0, index - 8) : index]):
        text = prior["text"]
        if text.startswith("PUSH ") and not PUSH_IMMEDIATE_RE.match(text):
            return text.removeprefix("PUSH ").strip()
        if text.startswith("CALL "):
            break
    return None


def window(instructions: list[dict[str, Any]], index: int, count: int = 10) -> list[str]:
    return [f"{item['address_hex']}: {item['text']}" for item in instructions[max(0, index - count) : index]]


def offsets_in_window(instructions: list[dict[str, Any]], index: int, count: int = 12) -> list[str]:
    offsets: set[str] = set()
    for item in instructions[max(0, index - count) : index]:
        for match in EDI_OFFSET_RE.finditer(item["text"]):
            offsets.add(hex32(int(match.group(1), 16)) or "")
    return sorted(offset for offset in offsets if offset)


def helper_call_details(instructions: list[dict[str, Any]], index: int, target: str) -> dict[str, Any]:
    pushes: list[dict[str, Any]] = []
    for prior in instructions[max(0, index - 12) : index]:
        if not prior["text"].startswith("PUSH "):
            continue
        immediate = PUSH_IMMEDIATE_RE.match(prior["text"])
        pushes.append(
            {
                "address": prior["address_hex"],
                "operand": prior["text"].removeprefix("PUSH ").strip(),
                "immediate": int(immediate.group(1), 16) if immediate else None,
            }
        )
    return {
        "address": instructions[index]["address_hex"],
        "target": target,
        "recent_pushes": pushes[-4:],
        "preceding_window": window(instructions, index),
    }


def summarize_function(path: Path) -> dict[str, Any]:
    target_match = TARGET_RE.match(path.name)
    if not target_match:
        raise ValueError(f"unexpected serializer dump name: {path}")
    entry = hex32(int(target_match.group(1), 16))
    instructions = parse_instructions(path)

    stream_writes: list[dict[str, Any]] = []
    direct_calls: Counter[str] = Counter()
    helper_calls: list[dict[str, Any]] = []
    jumps: list[dict[str, Any]] = []
    backward_jumps: list[dict[str, Any]] = []
    edi_offsets: set[str] = set()
    memory_offsets: set[str] = set()
    nested_pointer_markers: list[str] = []

    for index, instruction in enumerate(instructions):
        text = instruction["text"]
        for match in EDI_OFFSET_RE.finditer(text):
            edi_offsets.add(hex32(int(match.group(1), 16)) or "")
        for match in MEM_OFFSET_RE.finditer(text):
            memory_offsets.add(f"{match.group(1)}+{hex32(int(match.group(2), 16))}")
        if "MOV EDI,dword ptr [EDI +" in text or "MOV ECX,dword ptr [EDI +" in text:
            nested_pointer_markers.append(f"{instruction['address_hex']}: {text}")

        call_match = CALL_DIRECT_RE.match(text)
        if call_match:
            target = hex32(int(call_match.group(1), 16)) or ""
            direct_calls[target] += 1
            if target == ZERO_FILL_HELPER:
                helper_calls.append(helper_call_details(instructions, index, target))

        jump_match = JUMP_RE.match(text)
        if jump_match:
            target = int(jump_match.group(1), 16)
            jump = {"address": instruction["address_hex"], "text": text, "target": hex32(target)}
            jumps.append(jump)
            if target < instruction["address"]:
                backward_jumps.append(jump)

        if text == STREAM_WRITE_TEXT:
            size = nearest_push_immediate(instructions, index)
            stream_writes.append(
                {
                    "address": instruction["address_hex"],
                    "size": size,
                    "buffer_operand": nearest_buffer_push(instructions, index),
                    "object_record_offsets_in_window": offsets_in_window(instructions, index),
                    "preceding_window": window(instructions, index),
                }
            )

    direct_byte_count = sum(item["size"] or 0 for item in stream_writes)
    direct_byte_count_known = all(item["size"] is not None for item in stream_writes)
    calls_base = direct_calls.get(BASE_SERIALIZER, 0) > 0
    has_loop = bool(backward_jumps)
    has_nested_pointer = bool(nested_pointer_markers)

    return {
        "entry": entry,
        "file": str(path),
        "instruction_count": len(instructions),
        "stream_write_call_count": len(stream_writes),
        "stream_write_known_byte_count": direct_byte_count if direct_byte_count_known else None,
        "stream_write_all_sizes_known": direct_byte_count_known,
        "stream_writes": stream_writes,
        "direct_calls": dict(sorted(direct_calls.items())),
        "calls_base_serializer": calls_base,
        "zero_fill_helper_calls": helper_calls,
        "object_record_edi_offsets": sorted(offset for offset in edi_offsets if offset),
        "memory_offsets_raw": sorted(memory_offsets),
        "jump_count": len(jumps),
        "backward_jump_count": len(backward_jumps),
        "backward_jumps": backward_jumps,
        "nested_pointer_candidate_count": len(nested_pointer_markers),
        "nested_pointer_markers": nested_pointer_markers[:16],
        "requires_dynamic_payload_capture": has_loop or has_nested_pointer or bool(helper_calls),
        "recovery_note": (
            "Static stream-write contract is recovered for this function. "
            "Exact object payload bytes still require dynamic capture at the listed stream-write call sites."
        ),
    }


def load_serializer_counts(callstream: dict[str, Any]) -> dict[str, int]:
    counts = callstream.get("counts_by_serializer_slot_0c", {})
    return {hex32(key) or key: int(value) for key, value in counts.items()}


def summarize(
    callstream_path: Path,
    ghidra_dir: Path,
    extra_ghidra_dumps: list[Path] | None = None,
) -> dict[str, Any]:
    callstream = load_json(callstream_path)
    serializer_counts = load_serializer_counts(callstream)
    functions: dict[str, dict[str, Any]] = {}
    dump_paths = list(ghidra_dir.glob("target_*_FUN_*.txt"))
    dump_paths.extend(extra_ghidra_dumps or [])
    for path in sorted(set(dump_paths)):
        summary = summarize_function(path)
        entry = summary["entry"]
        summary["final_callstream_count"] = serializer_counts.get(entry, 0)
        functions[entry] = summary

    missing_static = sorted(set(serializer_counts) - set(functions))
    unused_static = sorted(set(functions) - set(serializer_counts))
    stream_write_breakpoints = [
        write["address"]
        for entry in sorted(functions)
        for write in functions[entry]["stream_writes"]
    ]
    total_serialized_objects = sum(serializer_counts.values())
    total_stream_write_sites = sum(function["stream_write_call_count"] for function in functions.values())
    weighted_minimum_writes_per_run = sum(
        functions[entry]["stream_write_call_count"] * serializer_counts.get(entry, 0)
        for entry in functions
    )
    weighted_direct_byte_minimum_per_run = sum(
        (functions[entry]["stream_write_known_byte_count"] or 0) * serializer_counts.get(entry, 0)
        for entry in functions
    )

    static_complete = bool(functions) and not missing_static and all(
        function["stream_write_all_sizes_known"] for function in functions.values()
    )

    return {
        "schema_id": "h3maped_final_object_serializer_static_summary_v1",
        "status": (
            "final_object_serializer_static_contract_recovered_payload_bytes_pending"
            if static_complete
            else "final_object_serializer_static_contract_incomplete"
        ),
        "scope": {
            "profile": callstream.get("scope", {}).get("profile"),
            "positive_claim": "static output-stream write contract for every serializer target seen in the final object callstream",
            "negative_claim": "does not yet replay final object payload bytes or prove native object-payload parity",
        },
        "inputs": {
            "callstream_summary": str(callstream_path),
            "ghidra_serializer_dir": str(ghidra_dir),
            "extra_ghidra_dumps": [str(path) for path in (extra_ghidra_dumps or [])],
        },
        "metrics": {
            "serializer_function_count": len(functions),
            "serializer_slot_count_from_callstream": len(serializer_counts),
            "serializer_static_contract_complete": static_complete,
            "stream_write_call_site_count": total_stream_write_sites,
            "stream_write_breakpoint_count": len(stream_write_breakpoints),
            "total_serialized_object_count_from_callstream": total_serialized_objects,
            "weighted_minimum_stream_write_events_in_run": weighted_minimum_writes_per_run,
            "weighted_direct_stream_write_bytes_excluding_indirect_helper_semantics": weighted_direct_byte_minimum_per_run,
            "functions_with_backward_jumps": sum(1 for function in functions.values() if function["backward_jump_count"]),
            "functions_with_nested_pointer_candidates": sum(
                1 for function in functions.values() if function["nested_pointer_candidate_count"]
            ),
            "functions_with_zero_fill_helper_calls": sum(1 for function in functions.values() if function["zero_fill_helper_calls"]),
            "missing_static_serializer_dumps": missing_static,
            "static_dumps_not_seen_in_callstream": unused_static,
            "final_object_callstream_replay_complete": callstream.get("metrics", {}).get(
                "final_object_callstream_replay_complete", False
            ),
            "generated_object_payload_replay_complete": False,
            "full_private_payload_replay_complete": False,
            "native_behavior_changed": False,
            "used_objdump": False,
            "overall_goal_complete": False,
        },
        "serializer_counts_from_final_callstream": serializer_counts,
        "stream_write_breakpoints": stream_write_breakpoints,
        "functions": functions,
        "remaining_gap": (
            "The serializer dispatch set and static stream-write contracts are now recovered. "
            "The remaining blocker for 100% final object payload replay is dynamic capture or full field decode "
            "of the bytes emitted at the listed stream-write call sites, especially serializers with loops or nested pointers."
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--callstream", type=Path, default=DEFAULT_CALLSTREAM)
    parser.add_argument("--ghidra-dir", type=Path, default=DEFAULT_GHIDRA_DIR)
    parser.add_argument(
        "--extra-ghidra-dump",
        action="append",
        type=Path,
        default=list(DEFAULT_EXTRA_GHIDRA_DUMPS),
        help="Additional recovered serializer dump outside --ghidra-dir. May be repeated.",
    )
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    summary = summarize(args.callstream, args.ghidra_dir, args.extra_ghidra_dump)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_FINAL_OBJECT_SERIALIZER_STATIC "
        f"status={summary['status']} "
        f"serializers={summary['metrics']['serializer_function_count']} "
        f"stream_write_sites={summary['metrics']['stream_write_call_site_count']} "
        f"weighted_write_events={summary['metrics']['weighted_minimum_stream_write_events_in_run']} "
        f"out={args.out}"
    )
    return 0 if summary["metrics"]["serializer_static_contract_complete"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
