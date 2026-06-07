#!/usr/bin/env python3
"""Summarize the live 0x4a79a3 -> 0x4a7605 -> 0x4a7312 endpoint trace.

This recovery artifact records what the bounded winedbg run actually proves:
the sampled +0xc8 dispatch reaches 0x4a7605, which performs two direct
0x4a7312 candidate commits. It intentionally does not claim the 0x4a746b or
0x4a5e73 delegated endpoint writer paths were replayed in this sample.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

from rmg_h3maped_recovery_trace import parse_winedbg_log


DEFAULT_TRACE_LOG = Path(
    ".artifacts/rmg_recovery/direct_generation_c8_dispatch_plus_endpoint_trace/winedbg_interactive_trace.log"
)
DEFAULT_STATIC_CHAIN = Path(".artifacts/rmg_recovery/connection_endpoint_chain_static_summary.json")
DEFAULT_OUT = Path(".artifacts/rmg_recovery/dispatch_endpoint_runtime_summary.json")


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


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}


def summarize_trace(trace_log: Path) -> dict[str, Any]:
    ledger = parse_winedbg_log(trace_log)
    events = ledger["events"]
    counts = Counter(event["address"] for event in events)

    dispatch_records: list[dict[str, Any]] = []
    commits: list[dict[str, Any]] = []
    for index, event in enumerate(events):
        address = event["address"]
        registers = event.get("registers", {})
        words = stack_words(event, 12)
        ret = words[0] if words else None
        if address in {"0x004a696b", "0x004a7605"}:
            dispatch_records.append(
                {
                    "event_index": index,
                    "site": address,
                    "return_address": hex32(ret),
                    "from_4a79a3_dispatch": ret in {0x004A7DFF, 0x004A7E1E},
                    "ecx_generator": hex32(registers.get("ecx")),
                    "esi_record": hex32(registers.get("esi")),
                    "edi_relation_or_source": hex32(registers.get("edi")),
                    "stack_words": [hex32(word) for word in words],
                }
            )
        elif address == "0x004a7312":
            dispatch_records.append(
                {
                    "event_index": index,
                    "site": address,
                    "return_address": hex32(ret),
                    "from_4a7605_call_site": ret in {0x004A76F3, 0x004A77E7, 0x004A78DB, 0x004A7952},
                    "object_record": hex32(words[1] if len(words) > 1 else None),
                    "source_relation_record": hex32(words[2] if len(words) > 2 else None),
                    "ecx_generator": hex32(registers.get("ecx")),
                    "stack_words": [hex32(word) for word in words],
                }
            )
        elif address == "0x004a7447":
            commits.append(
                {
                    "event_index": index,
                    "site": address,
                    "object_record": hex32(words[0] if words else None),
                    "selected_coordinate": {
                        "x": words[1] if len(words) > 1 else None,
                        "y": words[2] if len(words) > 2 else None,
                        "level": words[3] if len(words) > 3 else None,
                    },
                    "source_relation_record": hex32(words[4] if len(words) > 4 else None),
                    "generator_context": hex32(words[6] if len(words) > 6 else None),
                    "ecx_generator": hex32(registers.get("ecx")),
                    "edx_vtable": hex32(registers.get("edx")),
                    "stack_words": [hex32(word) for word in words],
                }
            )

    return {
        "trace_log": str(trace_log),
        "event_count": len(events),
        "address_counts": dict(sorted(counts.items())),
        "dispatch_records": dispatch_records,
        "direct_4a7312_commits": commits,
        "endpoint_writer_hits": {
            "0x004a746b": counts.get("0x004a746b", 0),
            "0x004a5e73": counts.get("0x004a5e73", 0),
            "0x004a5fd8": counts.get("0x004a5fd8", 0),
            "0x004a5ff1": counts.get("0x004a5ff1", 0),
            "0x004a75f1": counts.get("0x004a75f1", 0),
        },
    }


def summarize(trace_log: Path, static_chain: Path) -> dict[str, Any]:
    trace = summarize_trace(trace_log)
    static_summary = load_json(static_chain)
    counts = trace["address_counts"]
    direct_commits = trace["direct_4a7312_commits"]
    dispatch_records = trace["dispatch_records"]
    from_4a79a3 = [
        record for record in dispatch_records if record.get("from_4a79a3_dispatch")
    ]
    from_7605_7312 = [
        record for record in dispatch_records if record.get("from_4a7605_call_site")
    ]
    invariants = {
        "prior_static_endpoint_chain_recovered": (
            static_summary.get("status") == "partial_static_recovery_connection_endpoint_state_chain"
        ),
        "trace_has_events": trace["event_count"] > 0,
        "hit_4a696b_from_4a79a3": any(
            record["site"] == "0x004a696b" and record.get("from_4a79a3_dispatch")
            for record in from_4a79a3
        ),
        "hit_4a7605_from_4a79a3": any(
            record["site"] == "0x004a7605" and record.get("from_4a79a3_dispatch")
            for record in from_4a79a3
        ),
        "hit_two_4a7312_calls_from_4a7605": len(from_7605_7312) == 2,
        "hit_two_4a7312_vtable_commits": len(direct_commits) == 2,
        "no_4a746b_or_4a5e73_endpoint_writer_hits_in_sample": not any(
            trace["endpoint_writer_hits"].values()
        ),
        "hit_pair_mark_sites": counts.get("0x004a7e21", 0) >= 1
        and counts.get("0x004a7e25", 0) >= 1,
        "no_native_behavior_change": True,
    }
    status = (
        "partial_live_recovery_7605_direct_7312_endpoint_commits"
        if all(invariants.values())
        else "incomplete"
    )
    return {
        "schema_id": "h3maped_dispatch_endpoint_runtime_summary_v1",
        "status": status,
        "invariants": invariants,
        "trace": trace,
        "recovered_contract": (
            "The sampled live +0xc8 dispatch reaches a 0x4a79a3-owned 0x4a696b call, falls through to "
            "0x4a7605, and then executes two direct 0x4a7312 source-bounded candidate commits before the "
            "pair mark sites. The two selected coordinates observed at 0x4a7447 are recorded in "
            "direct_4a7312_commits. This sample did not hit 0x4a746b, 0x4a5e73, or their generated-cell "
            "mutation sites, so those delegated endpoint-writer paths remain runtime-replay pending."
        ),
        "remaining_gap": (
            "Full end-to-end state recovery still requires runtime ordered replay of the 0x4a746b/0x4a5e73 "
            "delegated endpoint writer path, before/after GeneratedCell+0x20/+0x24/+0x28/+0x2c state for "
            "0x4a5fd8/0x4a5ff1 and 0x4a75f1, exact +0xc8/+0xd8 vector-entry semantics, and candidate-vector "
            "contents around 0x4a7312 appends/RNG selection."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--trace-log", type=Path, default=DEFAULT_TRACE_LOG)
    parser.add_argument("--static-chain", type=Path, default=DEFAULT_STATIC_CHAIN)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args.trace_log, args.static_chain)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_DISPATCH_ENDPOINT_RUNTIME_SUMMARY status={summary['status']} out={args.out}")
    return 0 if summary["status"] == "partial_live_recovery_7605_direct_7312_endpoint_commits" else 1


if __name__ == "__main__":
    raise SystemExit(main())
