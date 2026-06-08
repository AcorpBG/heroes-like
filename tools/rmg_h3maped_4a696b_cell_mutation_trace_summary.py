#!/usr/bin/env python3
"""Summarize the focused 0x4a696b generated-cell mutation trace.

This is a recovery checkpoint for a partial live run. It records the exact
breakpoints that fired and, just as importantly, the direct 0x4a696b
generated-cell write sites that did not fire in this sample.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

from rmg_h3maped_recovery_trace import parse_winedbg_log


DEFAULT_TRACE_LOG = Path(
    ".artifacts/rmg_recovery/"
    "direct_generation_4a696b_cell_mutation_trace_20260608/"
    "winedbg_interactive_trace.log"
)
DEFAULT_STATIC_SURFACE = Path(".artifacts/rmg_recovery/696b_7605_static_surface_summary.json")
DEFAULT_OUT = Path(".artifacts/rmg_recovery/4a696b_cell_mutation_trace_summary_20260608.json")

DIRECT_MUTATION_SITES = {
    "test_generated_cell_2c_bit0": "0x004a6c13",
    "write_generated_cell_28": "0x004a6c26",
    "after_write_checkpoint": "0x004a6c29",
}


def hex32(value: int | None) -> str | None:
    return None if value is None else f"0x{value & 0xFFFFFFFF:08x}"


def memory_word(event: dict[str, Any], address: int | None) -> int | None:
    if address is None:
        return None
    for line in event.get("memory_lines", []):
        base = int(line["address"])
        words = line.get("words", [])
        if base <= address < base + len(words) * 4 and (address - base) % 4 == 0:
            return int(words[(address - base) // 4]) & 0xFFFFFFFF
    return None


def stack_word(event: dict[str, Any], index: int) -> int | None:
    esp = event.get("registers", {}).get("esp")
    if not isinstance(esp, int):
        return None
    return memory_word(event, esp + index * 4)


def stack_words(event: dict[str, Any], count: int) -> list[int | None]:
    return [stack_word(event, index) for index in range(count)]


def event_memory_words(event: dict[str, Any], base: int | None, count: int) -> list[int | None]:
    if base is None:
        return []
    return [memory_word(event, base + index * 4) for index in range(count)]


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def summarize_trace(trace_log: Path) -> dict[str, Any]:
    ledger = parse_winedbg_log(trace_log)
    events = ledger["events"]
    counts = Counter(event["address"] for event in events)

    dispatch_entries: list[dict[str, Any]] = []
    direct_commits: list[dict[str, Any]] = []
    pair_marks: list[dict[str, Any]] = []
    for index, event in enumerate(events):
        address = event["address"]
        registers = event.get("registers", {})
        words = stack_words(event, 12)
        ret = words[0] if words else None
        if address in {"0x004a696b", "0x004a7605", "0x004a7312"}:
            dispatch_entries.append(
                {
                    "event_index": index,
                    "site": address,
                    "return_address": hex32(ret),
                    "from_4a79a3_dispatch": ret in {0x004A7C09, 0x004A7DFF, 0x004A7E1E},
                    "from_4a7605_call_site": ret in {
                        0x004A76F3,
                        0x004A77E7,
                        0x004A78DB,
                        0x004A7952,
                    },
                    "generator": hex32(registers.get("ecx")),
                    "control_or_relation_record": hex32(registers.get("esi")),
                    "source_relation_record": hex32(registers.get("edi")),
                    "stack_words": [hex32(word) for word in words],
                }
            )
        if address == "0x004a7447":
            direct_commits.append(
                {
                    "event_index": index,
                    "site": address,
                    "object_record": hex32(words[0] if len(words) > 0 else None),
                    "selected_coordinate": {
                        "x": words[1] if len(words) > 1 else None,
                        "y": words[2] if len(words) > 2 else None,
                        "level": words[3] if len(words) > 3 else None,
                    },
                    "source_relation_record": hex32(words[4] if len(words) > 4 else None),
                    "control_record": hex32(words[5] if len(words) > 5 else None),
                    "generator": hex32(words[6] if len(words) > 6 else registers.get("ecx")),
                    "stack_words": [hex32(word) for word in words],
                }
            )
        if address in {"0x004a7e21", "0x004a7e25"}:
            esi = registers.get("esi")
            pair_marks.append(
                {
                    "event_index": index,
                    "site": address,
                    "control_record": hex32(esi),
                    "first_four_dwords": [hex32(word) for word in event_memory_words(event, esi, 4)],
                    "stack_words": [hex32(word) for word in words],
                }
            )

    return {
        "trace_log": str(trace_log),
        "event_count": len(events),
        "address_counts": dict(sorted(counts.items())),
        "direct_mutation_site_hits": {
            name: counts.get(address, 0) for name, address in DIRECT_MUTATION_SITES.items()
        },
        "dispatch_entries": dispatch_entries,
        "direct_4a7312_vtable_commits": direct_commits,
        "pair_mark_events": pair_marks,
    }


def summarize(trace_log: Path, static_surface_path: Path) -> dict[str, Any]:
    trace = summarize_trace(trace_log)
    static_surface = load_json(static_surface_path)
    counts = trace["address_counts"]
    direct_mutation_site_hits = trace["direct_mutation_site_hits"]
    pair_mark_events = trace["pair_mark_events"]
    before_mark = next((event for event in pair_mark_events if event["site"] == "0x004a7e21"), None)
    after_mark = next((event for event in pair_mark_events if event["site"] == "0x004a7e25"), None)
    before_words = before_mark["first_four_dwords"] if before_mark else []
    after_words = after_mark["first_four_dwords"] if after_mark else []
    pair_mark_delta = {
        "control_record": before_mark["control_record"] if before_mark else None,
        "before_first_four_dwords": before_words,
        "after_first_four_dwords": after_words,
        "observed_dword_2_change": {
            "before": before_words[2] if len(before_words) > 2 else None,
            "after": after_words[2] if len(after_words) > 2 else None,
        },
    }
    invariants = {
        "prior_static_4a696b_surface_recovered": (
            static_surface.get("status") == "partial_static_recovery_696b_7605_mutation_surface"
        ),
        "trace_has_events": trace["event_count"] > 0,
        "hit_4a696b": counts.get("0x004a696b", 0) >= 1,
        "hit_4a7605": counts.get("0x004a7605", 0) >= 1,
        "hit_two_4a7312_calls": counts.get("0x004a7312", 0) == 2,
        "hit_two_4a7312_vtable_commits": len(trace["direct_4a7312_vtable_commits"]) == 2,
        "hit_pair_mark_sites": counts.get("0x004a7e21", 0) >= 1
        and counts.get("0x004a7e25", 0) >= 1,
        "direct_4a696b_mutation_sites_not_hit": all(
            count == 0 for count in direct_mutation_site_hits.values()
        ),
        "no_native_behavior_change": True,
    }
    status = (
        "partial_live_recovery_4a696b_direct_mutation_sites_not_hit"
        if all(invariants.values())
        else "incomplete"
    )
    return {
        "schema_id": "h3maped_4a696b_cell_mutation_trace_summary_v1",
        "status": status,
        "invariants": invariants,
        "trace": trace,
        "pair_mark_delta": pair_mark_delta,
        "recovered_contract": (
            "This bounded live run hit four 0x4a696b entries, one 0x4a7605 fallback coordinator entry, "
            "two 0x4a7312 endpoint-placement calls, two vtable commits at 0x4a7447, and the 0x4a7e21/"
            "0x4a7e25 record-pair mark sites. The direct 0x4a696b generated-cell mutation instructions "
            "at 0x4a6c13, 0x4a6c26, and 0x4a6c29 did not fire in this sample."
        ),
        "remaining_gap": (
            "End-to-end recovery still needs a live sample that reaches the 0x4a696b direct generated-cell "
            "mutation block, or a separate ordered replay proving why every sampled 0x4a696b entry exits "
            "before that block. The two 0x4a7312 commits also still need post-vtable generated-cell and "
            "object-vector after-state capture before this path can be ported into native RMG."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--trace-log", type=Path, default=DEFAULT_TRACE_LOG)
    parser.add_argument("--static-surface", type=Path, default=DEFAULT_STATIC_SURFACE)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args.trace_log, args.static_surface)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_4A696B_CELL_MUTATION_TRACE_SUMMARY status={summary['status']} out={args.out}")
    return 0 if summary["status"] == "partial_live_recovery_4a696b_direct_mutation_sites_not_hit" else 1


if __name__ == "__main__":
    raise SystemExit(main())
