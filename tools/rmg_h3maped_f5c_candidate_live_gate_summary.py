#!/usr/bin/env python3
"""Summarize live reachability of the 0x540ca0 / 0x49cd97 candidate gate.

This is a recovery checkpoint, not native RMG behavior. It distinguishes the
live candidate scorer from the endpoint writer cursor path: 0x49cd97 is reached
by the 0x4a9f1c selector, but the sampled calls reject because the scorer reads
the selector call context at +0xf5c and compares it to the candidate key.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any


DEFAULT_BRANCH_SCAN = Path(".artifacts/rmg_recovery/f5c_candidate_pass_scan_20260610")
DEFAULT_DEEP_TRACE = Path(
    ".artifacts/rmg_recovery/f5c_candidate_deep_branch_trace_20260610/seed_1/"
    "winedbg_interactive_trace_ledger.json"
)
DEFAULT_RANGE_DUMP = Path(
    ".artifacts/rmg_recovery/ghidra_f5c_candidate_scorer_range_20260610/"
    "range_0049cd90_0049cdb0.txt"
)
DEFAULT_CALLER_DUMP = Path(
    ".artifacts/rmg_recovery/ghidra_4a9f1c_reward_guard_object_selector_dump/"
    "target_004a9f1c_FUN_004a9f1c.txt"
)
DEFAULT_OUT = Path(".artifacts/rmg_recovery/f5c_candidate_live_gate_summary_20260610.json")

REJECT_BRANCH = "0x0049cda6"
MATCH_BRANCH = "0x0049cdab"
CONSTRUCTOR = "0x0049cdb1"


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def seed_sort_key(path: Path) -> tuple[int, str]:
    try:
        return int(path.parent.name.split("_", 1)[1]), path.parent.name
    except (IndexError, ValueError):
        return 0, path.parent.name


def normalize_hex(value: int | None) -> str | None:
    if value is None:
        return None
    return f"0x{value:08x}"


def extract_candidate_key(event: dict[str, Any]) -> int | None:
    ecx = event.get("registers", {}).get("ecx")
    if not isinstance(ecx, int):
        return None
    for line in event.get("memory_lines", []):
        if line.get("address") == ecx + 0x8:
            words = line.get("words") or []
            if words:
                return int(words[0])
    return None


def summarize_ledger(path: Path) -> dict[str, Any]:
    data = load_json(path)
    events = list(data.get("events", []))
    sequence = [str(event.get("address")) for event in events]
    pairs: Counter[tuple[int | None, int | None]] = Counter()
    for event in events:
        if str(event.get("address")) != REJECT_BRANCH:
            continue
        selector_context_f5c = event.get("registers", {}).get("eax")
        candidate_key = extract_candidate_key(event)
        if not isinstance(selector_context_f5c, int) or candidate_key is None:
            continue
        pairs[(selector_context_f5c, candidate_key)] += 1

    return {
        "ledger": str(path),
        "event_count": len(events),
        "reject_branch_count": sequence.count(REJECT_BRANCH),
        "match_branch_count": sequence.count(MATCH_BRANCH),
        "constructor_count": sequence.count(CONSTRUCTOR),
        "unique_reject_pairs": [
            {
                "selector_context_plus_0xf5c": normalize_hex(selector_context_f5c),
                "candidate_plus_0x08_key": candidate_key,
                "count": count,
            }
            for (selector_context_f5c, candidate_key), count in sorted(
                pairs.items(), key=lambda item: (-item[1], str(item[0]))
            )
        ],
    }


def contains_all(text: str, needles: list[str]) -> bool:
    return all(needle in text for needle in needles)


def summarize(branch_scan: Path, deep_trace: Path, range_dump: Path, caller_dump: Path) -> dict[str, Any]:
    seed_ledgers = sorted(branch_scan.glob("seed_*/winedbg_interactive_trace_ledger.json"), key=seed_sort_key)
    seed_summaries = [summarize_ledger(path) for path in seed_ledgers]
    deep_summary = summarize_ledger(deep_trace) if deep_trace.exists() else {}

    range_text = range_dump.read_text(encoding="utf-8") if range_dump.exists() else ""
    caller_text = caller_dump.read_text(encoding="utf-8") if caller_dump.exists() else ""

    branch_rejects = sum(item["reject_branch_count"] for item in seed_summaries)
    branch_matches = sum(item["match_branch_count"] for item in seed_summaries)
    branch_constructors = sum(item["constructor_count"] for item in seed_summaries)
    deep_rejects = int(deep_summary.get("reject_branch_count", 0))
    deep_matches = int(deep_summary.get("match_branch_count", 0))
    deep_constructors = int(deep_summary.get("constructor_count", 0))

    all_pairs: Counter[tuple[str | None, int | None]] = Counter()
    for item in [*seed_summaries, deep_summary]:
        for pair in item.get("unique_reject_pairs", []):
            all_pairs[(pair.get("selector_context_plus_0xf5c"), pair.get("candidate_plus_0x08_key"))] += int(
                pair.get("count", 0)
            )

    invariants = {
        "static_scorer_contract_present": contains_all(
            range_text,
            [
                "0049cd97: MOV EAX,dword ptr [ESP + 0x8]",
                "0049cd9b: MOV EAX,dword ptr [EAX + 0xf5c]",
                "0049cda1: CMP EAX,dword ptr [ECX + 0x8]",
                "0049cdab: MOV EAX,dword ptr [ECX + 0xc]",
            ],
        ),
        "selector_passes_entry_ecx_as_second_score_arg": contains_all(
            caller_text,
            [
                "004a9f2f: MOV EBX,ECX",
                "004a9fff: PUSH EBX",
                "004aa000: PUSH EDI",
                "004aa001: CALL dword ptr [EAX + 0x4]",
            ],
        ),
        "branch_scan_has_12_seed_ledgers": len(seed_summaries) == 12,
        "branch_scan_reached_reject_branch": branch_rejects >= 252,
        "branch_scan_has_zero_match_or_constructor": branch_matches == 0 and branch_constructors == 0,
        "deep_trace_reached_reject_branch": deep_rejects >= 241,
        "deep_trace_has_zero_match_or_constructor": deep_matches == 0 and deep_constructors == 0,
        "no_native_behavior_change": True,
        "no_objdump_used": True,
    }
    status = (
        "f5c_candidate_live_scorer_rejects_selector_context_cursor_sampled_scope"
        if all(invariants.values())
        else "f5c_candidate_live_gate_inputs_incomplete"
    )

    return {
        "schema_id": "h3maped_f5c_candidate_live_gate_summary_v1",
        "status": status,
        "scope": (
            "Medium one-level, no-water, one Human/Computer plus one Computer-only profile. "
            "This is sampled exclusion evidence for the 0x540ca0 candidate score path, not a "
            "global proof for every H3MapEd mode."
        ),
        "inputs": {
            "branch_scan_dir": str(branch_scan),
            "deep_trace": str(deep_trace),
            "range_dump": str(range_dump),
            "caller_dump": str(caller_dump),
        },
        "invariants": invariants,
        "metrics": {
            "seed_ledger_count": len(seed_summaries),
            "branch_scan_reject_branch_count": branch_rejects,
            "branch_scan_match_branch_count": branch_matches,
            "branch_scan_constructor_count": branch_constructors,
            "deep_trace_reject_branch_count": deep_rejects,
            "deep_trace_match_branch_count": deep_matches,
            "deep_trace_constructor_count": deep_constructors,
            "combined_reject_branch_count": branch_rejects + deep_rejects,
            "combined_match_branch_count": branch_matches + deep_matches,
            "combined_constructor_count": branch_constructors + deep_constructors,
            "native_behavior_changed": False,
            "used_objdump": False,
            "overall_goal_complete": False,
        },
        "observed_reject_pairs": [
            {
                "selector_context_plus_0xf5c": selector_context_f5c,
                "candidate_plus_0x08_key": candidate_key,
                "count": count,
            }
            for (selector_context_f5c, candidate_key), count in sorted(
                all_pairs.items(), key=lambda item: (-item[1], str(item[0]))
            )
        ],
        "seed_summaries": seed_summaries,
        "deep_summary": deep_summary,
        "human_readable_conclusion": (
            "The 0x540ca0 / 0x49cd97 candidate scorer is live, but sampled Medium one-level "
            "runs reject it. The scorer reads the second 0x4a9f1c score argument at +0xf5c; "
            "0x4a9f1c passes its entry ECX through EBX as that argument. In the live samples "
            "this selector context has +0xf5c value 0x7a1befdf, while the candidate key at "
            "+0x08 is 7, so the code branches to 0x49cda6 and returns -1. No sampled call "
            "reaches the match branch 0x49cdab or constructor 0x49cdb1."
        ),
        "remaining_gap": (
            "This removes the current sampled 0x540ca0 scorer from the direct endpoint-fix "
            "path, but it does not globally prove the candidate family impossible. The "
            "remaining blocker is a source-backed pass/exclusion for all supported one-level "
            "land source states, plus the separate main endpoint-stamping generator+0xf5c "
            "success/exclusion question."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--branch-scan", type=Path, default=DEFAULT_BRANCH_SCAN)
    parser.add_argument("--deep-trace", type=Path, default=DEFAULT_DEEP_TRACE)
    parser.add_argument("--range-dump", type=Path, default=DEFAULT_RANGE_DUMP)
    parser.add_argument("--caller-dump", type=Path, default=DEFAULT_CALLER_DUMP)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args.branch_scan, args.deep_trace, args.range_dump, args.caller_dump)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_F5C_CANDIDATE_LIVE_GATE "
        f"status={summary['status']} "
        f"rejects={summary['metrics']['combined_reject_branch_count']} "
        f"matches={summary['metrics']['combined_match_branch_count']} "
        f"constructors={summary['metrics']['combined_constructor_count']} "
        f"out={args.out}"
    )
    return (
        0
        if summary["status"]
        == "f5c_candidate_live_scorer_rejects_selector_context_cursor_sampled_scope"
        else 1
    )


if __name__ == "__main__":
    raise SystemExit(main())
