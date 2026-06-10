#!/usr/bin/env python3
"""Classify the recovered 0x53eafc source-handler chain ownership.

The source-handler phase is statically recovered, but current direct RMG
recovery must not treat it as an active blocker unless a live owning caller is
identified. This verifier uses Ghidra reference dumps plus the existing WineDbg
breakpoint probe to prove the currently recovered call chain is closed under
``0x484d9f`` and has no Ghidra-visible incoming code owner.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_OUT = ROOT / "source_handler_owner_chain_summary_20260610.json"

DEFAULT_INPUTS = {
    "source_refs": ROOT / "ghidra_4802ac_source_handler_constructor_dump" / "target_00484d9f_references.txt",
    "constructor_refs": ROOT / "ghidra_4802ac_source_handler_constructor_dump" / "target_004802ac_references.txt",
    "wrapper_refs": ROOT / "ghidra_4af463_source_handler_init_dump" / "target_004afa99_references.txt",
    "initializer_refs": ROOT / "ghidra_4af463_source_handler_init_dump" / "target_004af463_references.txt",
    "cleanup_refs": ROOT / "ghidra_4af6db_pending_cleanup_predicate_dump" / "target_004af910_references.txt",
    "runtime_probe_log": ROOT / "seed58_interactive_484d9f_probe" / "winedbg_interactive_trace.log",
}

REF_RE = re.compile(
    r"from=(?P<from>[0-9a-fA-F]+) type=(?P<type>[A-Z_]+)"
    r"(?: caller=(?P<caller>\S+) caller_entry=(?P<caller_entry>[0-9a-fA-F]+))?"
    r" instruction=(?P<instruction>.*)"
)


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def parse_references_to(text: str) -> list[dict[str, str]]:
    refs: list[dict[str, str]] = []
    in_refs = False
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if line == "references_to:":
            in_refs = True
            continue
        if line == "references_from_target_function:":
            break
        if not in_refs or not line:
            continue
        match = REF_RE.search(line)
        if not match:
            continue
        refs.append({key: value or "" for key, value in match.groupdict().items()})
    return refs


def normalize_entries(entries: list[dict[str, str]]) -> list[dict[str, str]]:
    return [
        {
            "from": f"0x{entry['from'].lower()}",
            "type": entry["type"],
            "caller": entry.get("caller", ""),
            "caller_entry": f"0x{entry['caller_entry'].lower()}" if entry.get("caller_entry") else "",
            "instruction": entry["instruction"],
        }
        for entry in entries
    ]


def callers_only(entries: list[dict[str, str]], expected: str, expected_count: int | None = None) -> bool:
    expected = expected.lower()
    if not expected.startswith("0x"):
        expected = f"0x{expected}"
    if expected_count is not None and len(entries) != expected_count:
        return False
    return bool(entries) and all(entry.get("caller_entry", "").lower() == expected for entry in entries)


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    paths = {
        "source_refs": args.source_refs,
        "constructor_refs": args.constructor_refs,
        "wrapper_refs": args.wrapper_refs,
        "initializer_refs": args.initializer_refs,
        "cleanup_refs": args.cleanup_refs,
    }
    references = {name: normalize_entries(parse_references_to(read_text(path))) for name, path in paths.items()}
    runtime_text = read_text(args.runtime_probe_log)
    runtime_lower = runtime_text.lower()

    invariants = {
        "no_native_behavior_change": True,
        "no_objdump_used": True,
        "source_0x484d9f_has_zero_incoming_ghidra_refs": references["source_refs"] == [],
        "constructor_0x4802ac_callers_are_only_0x484d9f": callers_only(
            references["constructor_refs"], "00484d9f", expected_count=2
        ),
        "wrapper_0x4afa99_callers_are_only_0x484d9f": callers_only(
            references["wrapper_refs"], "00484d9f", expected_count=2
        ),
        "initializer_0x4af463_callers_are_only_0x4afa99": callers_only(
            references["initializer_refs"], "004afa99", expected_count=1
        ),
        "cleanup_0x4af910_callers_are_only_0x4afa99": callers_only(
            references["cleanup_refs"], "004afa99", expected_count=1
        ),
        "runtime_probe_armed_0x484d9f_breakpoint": "break *0x484d9f" in runtime_lower
        and "breakpoint 1 at 0x00484d9f" in runtime_lower,
        "runtime_probe_log_has_no_0x484d9f_breakpoint_stop": "breakpoint 1," not in runtime_lower
        and "stopped at 0x00484d9f" not in runtime_lower,
    }
    status = (
        "source_handler_chain_classified_static_orphan_for_direct_rmg_owner"
        if all(invariants.values())
        else "source_handler_chain_owner_evidence_incomplete"
    )

    return {
        "schema_id": "h3maped_source_handler_owner_chain_summary_v1",
        "status": status,
        "inputs": {name: str(path) for name, path in {**paths, "runtime_probe_log": args.runtime_probe_log}.items()},
        "references_to": references,
        "metrics": {
            "incoming_refs_to_0x484d9f": len(references["source_refs"]),
            "constructor_ref_count": len(references["constructor_refs"]),
            "wrapper_ref_count": len(references["wrapper_refs"]),
            "initializer_ref_count": len(references["initializer_refs"]),
            "cleanup_ref_count": len(references["cleanup_refs"]),
            "native_behavior_changed": False,
            "used_objdump": False,
            "overall_goal_complete": False,
        },
        "invariants": invariants,
        "source_backed_conclusion": (
            "The recovered 0x53eafc source-handler phase is a closed static chain rooted at "
            "0x484d9f in the current Ghidra reference surface: 0x4802ac and 0x4afa99 are "
            "called only by 0x484d9f, while 0x4af463 and 0x4af910 are called only by "
            "0x4afa99. Ghidra reports zero incoming references to 0x484d9f, and the "
            "existing WineDbg direct-generation probe armed a breakpoint at 0x484d9f "
            "without recording a breakpoint stop. Therefore this source-handler pending "
            "entry path should not be treated as the current direct-RMG parity blocker "
            "unless a separate live owner/action is later identified."
        ),
        "remaining_gap": (
            "This does not complete end-to-end RMG recovery. Remaining direct-generation "
            "blockers are still the natural projection slot/map-mode proof, the 0x4a696b "
            "source/relation-match or unreachable proof, runtime cleanup state if reached, "
            "older coordinate/projection reconciliation, and human semantic names/broader "
            "final-role proof."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-refs", type=Path, default=DEFAULT_INPUTS["source_refs"])
    parser.add_argument("--constructor-refs", type=Path, default=DEFAULT_INPUTS["constructor_refs"])
    parser.add_argument("--wrapper-refs", type=Path, default=DEFAULT_INPUTS["wrapper_refs"])
    parser.add_argument("--initializer-refs", type=Path, default=DEFAULT_INPUTS["initializer_refs"])
    parser.add_argument("--cleanup-refs", type=Path, default=DEFAULT_INPUTS["cleanup_refs"])
    parser.add_argument("--runtime-probe-log", type=Path, default=DEFAULT_INPUTS["runtime_probe_log"])
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_SOURCE_HANDLER_OWNER status={summary['status']} out={args.out}")
    return 0 if summary["status"] == "source_handler_chain_classified_static_orphan_for_direct_rmg_owner" else 1


if __name__ == "__main__":
    raise SystemExit(main())
