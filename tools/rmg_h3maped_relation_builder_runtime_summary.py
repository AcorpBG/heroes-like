#!/usr/bin/env python3
"""Summarize the live H3MapEd relation-builder checkpoint.

This is a recovery checkpoint only. It records which builder chain executes
before the sampled 0x4a8c15 phase boundary and what remains unrecovered before
native RMG behavior can change.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_TRACE = DEFAULT_ROOT / "direct_generation_4a93a2_relation_build_trace"
DEFAULT_DUMP = DEFAULT_ROOT / "ghidra_4a54a7_relation_vslot4_dump" / "target_004a54a7_FUN_004a54a7.txt"
DEFAULT_OUT = DEFAULT_ROOT / "relation_builder_runtime_summary.json"


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace") if path.exists() else ""


def hex32(value: int | str | None) -> str | None:
    if value is None:
        return None
    if isinstance(value, str):
        return f"0x{int(value, 0) & 0xFFFFFFFF:08x}"
    return f"0x{value & 0xFFFFFFFF:08x}"


def memory_words(event: dict[str, Any], address: int | None, count: int) -> list[int | None]:
    if address is None:
        return []
    result: list[int | None] = []
    for offset in range(count):
        target = address + offset * 4
        found: int | None = None
        for line in event.get("memory_lines", []):
            base = int(line["address"])
            words = line.get("words", [])
            if base <= target < base + len(words) * 4 and (target - base) % 4 == 0:
                found = int(words[(target - base) // 4]) & 0xFFFFFFFF
                break
        result.append(found)
    return result


def stack_args(event: dict[str, Any], count: int) -> list[str | None]:
    esp = event.get("registers", {}).get("esp")
    words = memory_words(event, esp, count)
    return [hex32(word) if word is not None else None for word in words]


def summarize_relation_calls(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    calls: list[dict[str, Any]] = []
    for event in events:
        if event.get("address") != "0x004a93a2":
            continue
        regs = event.get("registers", {})
        calls.append(
            {
                "return_address": hex32(event.get("derived", {}).get("return_address")),
                "generator_or_relation_ecx": hex32(regs.get("ecx")),
                "source_record_arg": stack_args(event, 5)[1],
                "route_or_mode_arg": stack_args(event, 5)[2],
                "index_arg": stack_args(event, 5)[3],
                "enabled_arg": stack_args(event, 5)[4],
            }
        )
    return calls


def vslot_targets(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    targets: list[dict[str, Any]] = []
    for event in events:
        if event.get("address") != "0x004a9583":
            continue
        regs = event.get("registers", {})
        edx = regs.get("edx")
        words = memory_words(event, edx, 2)
        targets.append(
            {
                "relation_vtable": hex32(edx if isinstance(edx, int) else None),
                "slot0": hex32(words[0] if len(words) > 0 else None),
                "slot4": hex32(words[1] if len(words) > 1 else None),
            }
        )
    return targets


def summarize(trace_dir: Path, dump_path: Path) -> dict[str, Any]:
    ledger = read_json(trace_dir / "winedbg_interactive_trace_ledger.json")
    events = ledger.get("events", [])
    counts = Counter(event.get("address") for event in events)
    dump_text = read_text(dump_path)
    relation_calls = summarize_relation_calls(events)
    targets = vslot_targets(events)
    unique_vslot4 = sorted({target["slot4"] for target in targets if target["slot4"]})

    invariants = {
        "trace_has_expected_event_count": ledger.get("event_count") == 41,
        "builder_entry_hit_eight_times": counts.get("0x004a8d2c", 0) == 8,
        "append_builder_hit_eight_times": counts.get("0x004a93a2", 0) == 8,
        "relation_vslot4_hit_eight_times": counts.get("0x004a9583", 0) == 8,
        "source_flag_write_hit_eight_times": counts.get("0x004a95a4", 0) == 8,
        "source_route_state_write_hit_eight_times": counts.get("0x004a95e6", 0) == 8,
        "phase_boundary_hit_once": counts.get("0x004a8c15", 0) == 1,
        "relation_vslot4_resolves_to_4a54a7": unique_vslot4 == ["0x004a54a7"],
        "static_vslot4_uses_generator_object_vector": "004a54dd: MOV EAX,dword ptr [ESI + 0xecc]" in dump_text
        and "004a54e3: LEA ECX,[ESI + 0xec4]" in dump_text
        and "004a54fa: INC dword ptr [ESI + EDI*0x4 + 0x1110]" in dump_text,
        "static_vslot4_mutates_candidate_bitfield": "004a56b6: MOV dword ptr [EAX + 0x20],ESI" in dump_text,
    }
    status = "partial_live_relation_builder_checkpoint" if all(invariants.values()) else "incomplete"
    return {
        "schema_id": "h3maped_relation_builder_runtime_summary_v1",
        "status": status,
        "trace_dir": str(trace_dir),
        "dump_path": str(dump_path),
        "event_count": ledger.get("event_count"),
        "address_counts": dict(sorted((key, value) for key, value in counts.items() if key)),
        "invariants": invariants,
        "relation_calls": relation_calls,
        "relation_vslot4_targets": targets,
        "recovered_contract": [
            "The sampled direct-generation run executes eight 0x4a8d2c relation-builder calls before 0x4a8c15.",
            "Each sampled 0x4a8d2c call reaches 0x4a93a2, then relation vtable slot +0x04 at 0x4a9583.",
            "The sampled vtable slot +0x04 resolves to 0x4a54a7 for vtable 0x00540cbc.",
            "0x4a93a2 then reaches writes at 0x4a95a4 and 0x4a95e6, which mark/mutate source record fields +0x3c and +0x28.",
            "0x4a54a7 is a source/relation projection helper over generator object-vector state around +0xec4/+0xecc/+0x1110 and static candidate bitfield writes, not the final native RMG rule to change.",
        ],
        "remaining_gap": (
            "This checkpoint still does not recover the owner/population path for the later relation-object "
            "+0xc8/+0xcc 0x1c-byte record stream, nor the semantic producer of edge/control-record +0x08/+0x09. "
            "Native RMG behavior must remain unchanged until that producer and ordered generated-cell before/after "
            "replay are recovered."
        ),
        "native_behavior_changed": False,
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--trace-dir", type=Path, default=DEFAULT_TRACE)
    parser.add_argument("--dump", type=Path, default=DEFAULT_DUMP)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args.trace_dir, args.dump)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_RELATION_BUILDER_RUNTIME_SUMMARY status={summary['status']} out={args.out}")
    return 0 if summary["status"] == "partial_live_relation_builder_checkpoint" else 1


if __name__ == "__main__":
    raise SystemExit(main())
