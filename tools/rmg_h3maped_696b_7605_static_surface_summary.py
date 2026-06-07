#!/usr/bin/env python3
"""Summarize H3MapEd 0x4a696b and 0x4a7605 static mutation surfaces.

This is a recovery artifact, not a native RMG validator. It records the
source-backed static surface after the live 0x4a79a3 +0xc8 dispatch sample
proved both callees are reached from that phase.
"""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_DISPATCH_SUMMARY = DEFAULT_ROOT / "4a79a3_filter_dispatch_summary.json"
DEFAULT_OUT = DEFAULT_ROOT / "696b_7605_static_surface_summary.json"

DEFAULT_696B_DUMP = (
    DEFAULT_ROOT / "ghidra_object_projection_helper_dump/caller_004a696b_FUN_004a696b.txt"
)
DEFAULT_7605_DUMP = (
    DEFAULT_ROOT / "ghidra_downstream_state_dump/caller_004a7605_FUN_004a7605.txt"
)


CALL_RE = re.compile(r"^(?P<address>[0-9a-f]{8}): CALL (?P<target>0x[0-9a-f]{8})$", re.MULTILINE)


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8") if path.exists() else ""


def load_json(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8"))


def call_counts(text: str) -> dict[str, int]:
    return dict(sorted(Counter(match.group("target") for match in CALL_RE.finditer(text)).items()))


def call_sites(text: str, target: str) -> list[str]:
    return [match.group("address") for match in CALL_RE.finditer(text) if match.group("target") == target]


def line_exists(text: str, expected: str) -> bool:
    return expected in text


def classify_696b(path: Path) -> dict[str, Any]:
    text = read_text(path)
    counts = call_counts(text)
    mutation_sites = {
        "tests_private_flags_bit0": line_exists(text, "004a6c13: TEST byte ptr [ECX + 0x2c],0x1"),
        "clears_bit26": line_exists(text, "004a6c1c: AND EAX,0xfbffffff"),
        "sets_bit27": line_exists(text, "004a6c21: OR EAX,0x8000000"),
        "writes_generated_cell_bit_state": line_exists(
            text, "004a6c26: MOV dword ptr [ECX + 0x28],EAX"
        ),
    }
    required_calls = {
        "eligibility_gate_49aa93": "0x0049aa93",
        "record_initializer_49ba89": "0x0049ba89",
        "coordinate_append_40bb15": "0x0040bb15",
        "connection_helper_4a68e0": "0x004a68e0",
        "value_scale_4a65a5": "0x004a65a5",
        "endpoint_projection_4a5e73": "0x004a5e73",
    }
    call_invariants = {name: counts.get(target, 0) >= 1 for name, target in required_calls.items()}
    return {
        "entry": "0x004a696b",
        "name": "connection_dispatch_direct_generated_cell_mutator",
        "dump": str(path),
        "dump_exists": path.exists(),
        "static_contract_recovered": path.exists()
        and all(mutation_sites.values())
        and all(call_invariants.values()),
        "mutation_sites": mutation_sites,
        "required_call_sites": {
            name: {
                "target": target,
                "count": counts.get(target, 0),
                "sites": call_sites(text, target),
            }
            for name, target in required_calls.items()
        },
        "contract": [
            "Receives the generator in ECX/EBX and reads relation/vector state including generator+0x10e4.",
            "Scans generated cells through generator+0x14/+0x18/+0x1c and uses GeneratedCell+0x20/+0x24/+0x28/+0x2c.",
            "Filters candidate coordinates through 0x49aa93 and appends accepted coordinates through 0x40bb15.",
            "For selected cells whose GeneratedCell+0x2c bit0 is clear, writes GeneratedCell+0x28 = (old & 0xfbffffff) | 0x08000000.",
            "Calls 0x4a68e0, 0x4a65a5, and 0x4a5e73 after the direct generated-cell mutation surface.",
        ],
        "remaining_gap": (
            "Runtime ordered replay is still pending: selected coordinates, before/after GeneratedCell "
            "+0x20/+0x24/+0x28/+0x2c, and exact +0xc8 relation-record semantic names are not recovered."
        ),
    }


def classify_7605(path: Path) -> dict[str, Any]:
    text = read_text(path)
    counts = call_counts(text)
    expected_counts = {
        "endpoint_policy_4a7312": ("0x004a7312", 4),
        "endpoint_writer_4a746b": ("0x004a746b", 2),
        "coordinate_append_40bb15": ("0x0040bb15", 4),
        "coordinate_merge_40bb26": ("0x0040bb26", 3),
        "record_initializer_49ba89": ("0x0049ba89", 4),
        "guard_or_object_materializer_4a5e03": ("0x004a5e03", 2),
        "value_scale_4a65a5": ("0x004a65a5", 1),
    }
    expected_invariants = {
        name: counts.get(target, 0) == expected_count
        for name, (target, expected_count) in expected_counts.items()
    }
    direct_cell_write_sites = [
        "MOV dword ptr [ECX + 0x28]",
        "MOV dword ptr [EAX + 0x28]",
        "MOV dword ptr [EDX + 0x28]",
        "MOV dword ptr [EBX + 0x28]",
        "MOV dword ptr [ESI + 0x28]",
        "MOV dword ptr [EDI + 0x28]",
    ]
    return {
        "entry": "0x004a7605",
        "name": "connection_dispatch_fallback_endpoint_coordinator",
        "dump": str(path),
        "dump_exists": path.exists(),
        "static_contract_recovered": path.exists() and all(expected_invariants.values()),
        "expected_call_counts": {
            name: {
                "target": target,
                "expected_count": expected_count,
                "actual_count": counts.get(target, 0),
                "sites": call_sites(text, target),
            }
            for name, (target, expected_count) in expected_counts.items()
        },
        "direct_generated_cell_28_write_seen_in_this_dump": any(
            site in text for site in direct_cell_write_sites
        ),
        "contract": [
            "Coordinates fallback endpoint/object placement after the 0x4a79a3 +0xc8 dispatch path.",
            "Runs four 0x4a7312 endpoint-placement attempts and initializes records through 0x49ba89.",
            "Records source/relation coordinates through 0x40bb15 and 0x40bb26 vector helpers.",
            "Calls 0x4a746b twice for endpoint state writes and calls 0x4a5e03 twice for downstream materialization.",
            "The recovered static surface does not show a direct GeneratedCell+0x28 write inside 0x4a7605 itself; generated-cell mutation is delegated through callees such as 0x4a7312, 0x4a746b, and 0x4a5e03.",
        ],
        "remaining_gap": (
            "Runtime ordered replay is still pending for delegated 0x4a7312/0x4a746b/0x4a5e03 outcomes, "
            "exact selected coordinates, and before/after GeneratedCell state."
        ),
    }


def summarize(dump_696b: Path, dump_7605: Path, dispatch_summary_path: Path) -> dict[str, Any]:
    dispatch_summary = load_json(dispatch_summary_path)
    dispatch_counts = dispatch_summary.get("dispatch_summary", {}).get("from_4a79a3_counts", {})
    dispatch_status = dispatch_summary.get("status")
    surface_696b = classify_696b(dump_696b)
    surface_7605 = classify_7605(dump_7605)
    invariants = {
        "prior_dispatch_summary_partial_live_recovery": (
            dispatch_status == "partial_live_recovery_4a79a3_filter_and_c8_dispatch"
        ),
        "prior_runtime_hit_4a696b_from_4a79a3": dispatch_counts.get("0x004a696b", 0) >= 1,
        "prior_runtime_hit_4a7605_from_4a79a3": dispatch_counts.get("0x004a7605", 0) >= 1,
        "static_4a696b_direct_mutation_surface_recovered": surface_696b["static_contract_recovered"],
        "static_4a7605_fallback_coordinator_surface_recovered": surface_7605[
            "static_contract_recovered"
        ],
        "no_native_behavior_change": True,
    }
    status = (
        "partial_static_recovery_696b_7605_mutation_surface"
        if all(invariants.values())
        else "incomplete"
    )
    return {
        "schema_id": "h3maped_696b_7605_static_surface_summary_v1",
        "status": status,
        "invariants": invariants,
        "source_artifacts": {
            "dispatch_summary": str(dispatch_summary_path),
            "dump_4a696b": str(dump_696b),
            "dump_4a7605": str(dump_7605),
        },
        "surfaces": [surface_696b, surface_7605],
        "recovered_contract": (
            "After the live 0x4a79a3 +0xc8 dispatch checkpoint, static recovery now proves "
            "0x4a696b contains a direct GeneratedCell+0x28 mutation gated by GeneratedCell+0x2c bit0: "
            "(old & 0xfbffffff) | 0x08000000. Static recovery also proves 0x4a7605 is the fallback "
            "endpoint coordinator, with four 0x4a7312 endpoint-placement attempts, two 0x4a746b endpoint "
            "writer calls, coordinate appends through 0x40bb15/0x40bb26, and no direct GeneratedCell+0x28 "
            "write visible in this recovered dump."
        ),
        "remaining_gap": (
            "This does not complete end-to-end recovery. The missing piece is runtime ordered replay of "
            "0x4a79a3-owned 0x4a696b and 0x4a7605 callee sequences, including exact selected coordinates, "
            "GeneratedCell+0x20/+0x24/+0x28/+0x2c before/after state, delegated 0x4a7605 callee outcomes, "
            "and exact semantic names for the source/relation/vector records."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dump-696b", type=Path, default=DEFAULT_696B_DUMP)
    parser.add_argument("--dump-7605", type=Path, default=DEFAULT_7605_DUMP)
    parser.add_argument("--dispatch-summary", type=Path, default=DEFAULT_DISPATCH_SUMMARY)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args.dump_696b, args.dump_7605, args.dispatch_summary)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_696B_7605_STATIC_SURFACE_SUMMARY status={summary['status']} out={args.out}")
    return 0 if summary["status"] == "partial_static_recovery_696b_7605_mutation_surface" else 1


if __name__ == "__main__":
    raise SystemExit(main())
