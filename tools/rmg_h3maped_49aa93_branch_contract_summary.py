#!/usr/bin/env python3
"""Summarize the static 0x49aa93 helper branch contract and live frontier.

The native RMG recovery currently needs the weighted 0x4a901a path after a
value-floor pass. This script makes the next missing state precise: the helper
called at 0x4a9167 has a recovered static branch contract, but the available
live caller-specific attempts do not yet capture a return to 0x4a916c or an
append/materialization path.
"""

from __future__ import annotations

import argparse
import collections
import json
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_STATIC_49AA93 = ROOT / "ghidra_49aa93_eligibility_helper_dump" / "target_0049aa93_FUN_0049aa93.txt"
DEFAULT_STATIC_4A901A = ROOT / "ghidra_object_projection_helper_dump" / "caller_004a901a_FUN_004a901a.txt"
DEFAULT_POSTGATE_SUMMARY = ROOT / "4a901a_postgate_frontier_summary_20260609.json"
DEFAULT_OUT = ROOT / "49aa93_branch_contract_summary_20260609.json"

DEFAULT_TRACE_LEDGERS = [
    ROOT
    / "4a901a_large_4p_helper_return_caller_probe_20260609_parse"
    / "winedbg_recovery_trace_ledger.json",
    ROOT
    / "4a901a_large_4p_helper_return_light_9150_20260609_parse"
    / "winedbg_recovery_trace_ledger.json",
]


def load_json(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def has_line(text: str, line: str) -> bool:
    return line in text


def marker_set(text: str, markers: list[str]) -> dict[str, bool]:
    return {marker: has_line(text, marker) for marker in markers}


def event_counts(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"path": str(path), "exists": False, "counts": {}, "event_count": 0}
    data = load_json(path)
    events = data.get("events", [])
    counts = dict(collections.Counter(event.get("address") for event in events))
    value_samples = [
        event.get("registers", {}).get("eax") & 0xFFFF
        for event in events
        if event.get("address") == "0x004a9150" and isinstance(event.get("registers", {}).get("eax"), int)
    ]
    return {
        "path": str(path),
        "exists": True,
        "event_count": len(events),
        "counts": counts,
        "value_floor_sample_count": len(value_samples),
        "value_floor_low_word_min": min(value_samples) if value_samples else None,
        "value_floor_low_word_max": max(value_samples) if value_samples else None,
        "reaches_helper_callsite": counts.get("0x004a9167", 0) > 0,
        "reaches_helper_return": counts.get("0x004a916c", 0) > 0,
        "reaches_helper_accept_continuation": counts.get("0x004a9174", 0) > 0,
        "reaches_append_or_materialization": any(
            counts.get(address, 0) > 0
            for address in (
                "0x004a9248",
                "0x004a9254",
                "0x004a9290",
                "0x004a92bb",
                "0x004a92d5",
                "0x004a9322",
            )
        ),
    }


def build_summary(args: argparse.Namespace) -> dict[str, Any]:
    static_49aa93 = args.static_49aa93.read_text(encoding="utf-8", errors="replace")
    static_4a901a = args.static_4a901a.read_text(encoding="utf-8", errors="replace")
    postgate = load_json(args.postgate_summary) if args.postgate_summary.exists() else {}

    helper_markers = marker_set(
        static_49aa93,
        [
            "0049aabf: CALL 0x0049a6f9",
            "0049aac6: JZ 0x0049aacf",
            "0049aac8: XOR AL,AL",
            "0049aad5: CALL 0x0049b76d",
            "0049aae4: CMP byte ptr [EAX + 0x2],0x0",
            "0049aaea: CMP byte ptr [EAX + 0x1],0x0",
            "0049ab14: CALL 0x0049a09c",
            "0049ab1b: JZ 0x0049aac8",
            "0049ab1d: CMP byte ptr [EBX + 0x29],0x0",
            "0049ab23: MOV AL,0x1",
            "0049ab40: JGE 0x0049aac8",
            "0049ab59: CALL 0x0049a1d8",
            "0049ab60: JZ 0x0049aac8",
            "0049ab72: JS 0x0049aac8",
            "0049ab81: JNZ 0x0049aac8",
            "0049ab8d: TEST AL,0x1",
            "0049abac: JZ 0x0049aac8",
            "0049abc3: CMP dword ptr [EDX + 0xc],0x8",
            "0049abcc: SETZ AL",
            "0049abd3: RET 0x14",
        ],
    )
    caller_markers = marker_set(
        static_4a901a,
        [
            "004a9167: CALL 0x0049aa93",
            "004a916c: TEST AL,AL",
            "004a916e: JZ 0x004a9259",
            "004a9174: MOV ECX,dword ptr [EBP + -0x2c]",
            "004a9248: CALL 0x004ae52a",
            "004a9254: CALL 0x004ae1fd",
            "004a9273: CMP dword ptr [EBP + -0x54],0x0",
            "004a9287: JNZ 0x004a9290",
            "004a92bb: CALL 0x0049ba89",
            "004a9322: CALL dword ptr [EDX + 0x4]",
        ],
    )
    traces = [event_counts(path) for path in args.trace_ledgers]
    conditions = {
        "static_helper_branch_contract_recovered": all(helper_markers.values()),
        "static_4a901a_post_helper_contract_recovered": all(caller_markers.values()),
        "postgate_summary_proves_value_floor_pass_to_helper": postgate.get("conditions", {}).get(
            "value_floor_pass_reaches_helper_callsite"
        )
        is True,
        "new_live_attempts_do_not_capture_helper_return": traces
        and all(not trace.get("reaches_helper_return") for trace in traces if trace.get("exists")),
        "new_live_attempts_do_not_capture_append_or_materialization": traces
        and all(not trace.get("reaches_append_or_materialization") for trace in traces if trace.get("exists")),
    }
    status = (
        "49aa93_static_branch_contract_recovered_runtime_return_still_missing"
        if all(conditions.values())
        else "49aa93_branch_contract_incomplete"
    )
    return {
        "schema_id": "rmg_h3maped_49aa93_branch_contract_summary.v1",
        "status": status,
        "inputs": {
            "static_49aa93": str(args.static_49aa93),
            "static_4a901a": str(args.static_4a901a),
            "postgate_summary": str(args.postgate_summary),
            "trace_ledgers": [str(path) for path in args.trace_ledgers],
        },
        "conditions": conditions,
        "helper_static_markers": helper_markers,
        "caller_static_markers": caller_markers,
        "live_attempts": traces,
        "recovered_contract": {
            "arguments": {
                "ecx": "generated-cell grid wrapper",
                "stack_0x08": "object record or descriptor wrapper",
                "stack_0x0c_0x10_0x14": "candidate x/y/level triple",
                "stack_0x18": "source/relation record",
            },
            "false_paths": [
                "0x49a6f9 footprint/object acceptance reports rejection, then 0x49aac8 returns AL=0.",
                "0x49a09c contour/grid validation returns false, then 0x49ab1b branches to 0x49aac8.",
                "Projection-enabled descriptor path rejects out-of-bounds source cell, invalid cell, owner/relation mismatch, occupied-cell policy, or terrain-policy mismatch.",
            ],
            "true_paths": [
                "If descriptor byte +0x29 is clear and 0x49a09c succeeds, 0x49ab23 returns AL=1.",
                "If descriptor byte +0x29 is set, the offset-adjusted source cell must pass validity, owner/relation, occupancy-policy, and relation terrain-8 equality; 0x49abcc sets AL from the final terrain/relation comparison.",
            ],
            "post_helper_4a901a_flow": [
                "0x4a916c tests AL and false returns to the scan increment at 0x4a9259.",
                "True continues at 0x4a9174 into local scan-bound adjustment.",
                "0x4a9248/0x4a9254 append accepted coordinates into the local candidate vector.",
                "0x4a9273 requires the vector begin pointer to be nonzero before allocation/materialization can proceed.",
            ],
        },
        "not_recovered": [
            "No current live attempt captures the 0x4a9167 call returning at 0x4a916c.",
            "No current live attempt captures the 0x4a9174 accept continuation, 0x4a9248/0x4a9254 append, or 0x4a9290+ materialization path.",
            "The exact runtime values that make 0x49aa93 return true for a weighted 0x4a901a candidate remain uncaptured.",
        ],
        "next_required_step": (
            "Capture a value-floor passing 0x4a901a candidate through 0x4a9167 -> 0x4a916c. "
            "At 0x4a916c, record AL plus object descriptor +0x29/+0x2c/+0x30, policy bytes from "
            "0x57c648[(type << 4)+1/+2], 0x49a09c result, and offset-adjusted source-cell "
            "GeneratedCell+0x20/+0x24/+0x28. Then continue to 0x4a9248/0x4a9254 and "
            "0x4a9290/0x4a92bb/0x4a9322 for materialization deltas."
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--static-49aa93", type=Path, default=DEFAULT_STATIC_49AA93)
    parser.add_argument("--static-4a901a", type=Path, default=DEFAULT_STATIC_4A901A)
    parser.add_argument("--postgate-summary", type=Path, default=DEFAULT_POSTGATE_SUMMARY)
    parser.add_argument("--trace-ledger", dest="trace_ledgers", action="append", type=Path)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    if args.trace_ledgers is None:
        args.trace_ledgers = DEFAULT_TRACE_LEDGERS

    summary = build_summary(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_49AA93_BRANCH_CONTRACT status={summary['status']} out={args.out}")
    return (
        0
        if summary["status"] == "49aa93_static_branch_contract_recovered_runtime_return_still_missing"
        else 1
    )


if __name__ == "__main__":
    raise SystemExit(main())
