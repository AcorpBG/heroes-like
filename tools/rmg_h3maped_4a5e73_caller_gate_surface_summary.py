#!/usr/bin/env python3
"""Summarize the recovered caller-gate surface for H3MapEd 0x4a5e73."""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path
from typing import Any


ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_REFS = ROOT / "ghidra_downstream_helper_dump/target_004a5e73_references.txt"
DEFAULT_6CF2_DUMP = ROOT / "ghidra_downstream_helper_dump/caller_004a6cf2_FUN_004a6cf2.txt"
DEFAULT_CURSOR_FRONTIER = ROOT / "4a5e73_cursor_frontier_summary_20260610.json"
DEFAULT_696B_TARGET = ROOT / "4a696b_target_mode_reachability_summary_20260610.json"
DEFAULT_FORCED_BG = ROOT / "forced_border_guard_route_summary_20260608.json"
DEFAULT_NATURAL_BG = ROOT / "medium_seed10_hc1_co1_border_guard_seed_pinned_summary_20260609.json"
DEFAULT_FOLLOWTHROUGH = (
    ROOT / "medium_seed10_hc1_co1_border_guard_followthrough_seed_pinned_summary_20260609.json"
)
DEFAULT_ENDPOINT_CHAIN = ROOT / "connection_endpoint_chain_static_summary.json"
DEFAULT_OUT = ROOT / "4a5e73_caller_gate_surface_summary_20260610.json"

EXPECTED_CALLSITES = {
    "0x004a64ff": {"caller": "FUN_004a61bc", "caller_entry": "0x004a61bc"},
    "0x004a6531": {"caller": "FUN_004a61bc", "caller_entry": "0x004a61bc"},
    "0x004a6c97": {"caller": "FUN_004a696b", "caller_entry": "0x004a696b"},
    "0x004a711c": {"caller": "FUN_004a6cf2", "caller_entry": "0x004a6cf2"},
    "0x004a71f5": {"caller": "FUN_004a6cf2", "caller_entry": "0x004a6cf2"},
    "0x004a7593": {"caller": "FUN_004a746b", "caller_entry": "0x004a746b"},
}

STOP_RE = re.compile(
    r"Stopped on [A-Za-z _-]*(?:breakpoint|watchpoint)\s+\d+\s+at\s+(0x[0-9a-fA-F]+)"
)


def normalize_address(value: str) -> str:
    if value.lower().startswith("0x"):
        return f"0x{int(value, 0) & 0xFFFFFFFF:08x}"
    return f"0x{int(value, 16) & 0xFFFFFFFF:08x}"


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def parse_refs(path: Path) -> list[dict[str, str]]:
    refs: list[dict[str, str]] = []
    for line in read_text(path).splitlines():
        if "instruction=CALL 0x004a5e73" not in line:
            continue
        fields: dict[str, str] = {}
        for part in line.strip().split():
            if "=" in part:
                key, value = part.split("=", 1)
                fields[key] = value
        refs.append(
            {
                "callsite": normalize_address(fields["from"]),
                "caller": fields.get("caller", ""),
                "caller_entry": normalize_address(fields["caller_entry"]),
            }
        )
    return refs


def corpus_counts(root: Path, sites: set[str]) -> dict[str, Any]:
    ledger_counts = Counter({site: 0 for site in sites})
    log_stop_counts = Counter({site: 0 for site in sites})
    break_command_counts = Counter({site: 0 for site in sites})
    ledger_files = 0
    log_files = 0
    for path in root.rglob("*ledger.json"):
        ledger_files += 1
        try:
            data = json.loads(path.read_text(encoding="utf-8", errors="replace"))
        except json.JSONDecodeError:
            continue
        for event in data.get("events", []):
            address = str(event.get("address", ""))
            try:
                normalized = normalize_address(address)
            except ValueError:
                continue
            if normalized in sites:
                ledger_counts[normalized] += 1
    for path in root.rglob("*.log"):
        log_files += 1
        text = read_text(path)
        lower = text.lower()
        for match in STOP_RE.finditer(text):
            try:
                normalized = normalize_address(match.group(1))
            except ValueError:
                continue
            if normalized in sites:
                log_stop_counts[normalized] += 1
        for site in sites:
            short = site.replace("0x00", "0x")
            break_command_counts[site] += lower.count(f"break *{site}".lower())
            break_command_counts[site] += lower.count(f"break *{short}".lower())
    return {
        "ledger_files_scanned": ledger_files,
        "log_files_scanned": log_files,
        "ledger_event_counts": dict(sorted(ledger_counts.items())),
        "raw_log_stop_counts": dict(sorted(log_stop_counts.items())),
        "raw_log_break_command_counts": dict(sorted(break_command_counts.items())),
    }


def static_6cf2_surface(path: Path) -> dict[str, Any]:
    text = read_text(path)
    checks = {
        "function_present": "entry=004a6cf2" in text,
        "first_endpoint_gate_reads_record_plus_09": "004a7100: CMP byte ptr [ESI + 0x9],0x0" in text,
        "first_5e73_callsite_present": "004a711c: CALL 0x004a5e73" in text,
        "second_5e73_callsite_present": "004a71f5: CALL 0x004a5e73" in text,
        "stamps_generated_cell_bit27_before_first_endpoint": (
            "004a70bf: TEST byte ptr [EAX + 0x2c],0x1" in text
            and "004a70c8: AND EDX,0xfbffffff" in text
            and "004a70ce: OR EDX,ECX" in text
            and "004a70d0: MOV dword ptr [EAX + 0x28],EDX" in text
        ),
        "packs_endpoint_result_into_cell_2c_after_second_endpoint": (
            "004a71f5: CALL 0x004a5e73" in text
            and "004a71fa: MOV ESI,EAX" in text
            and "004a71fe: JL 0x004a72bd" in text
            and "004a71d7: AND AL,0xe1" in text
            and "004a71dd: OR ESI,0x1" in text
            and "004a71e0: MOV dword ptr [ECX + 0x2c],ESI" in text
        ),
    }
    return {
        "dump": str(path),
        "checks": checks,
        "static_contract_recovered": all(checks.values()),
        "human_contract": (
            "0x4a6cf2 has two static endpoint-helper calls. The first is behind compact "
            "record byte +0x09 and follows generated-cell bit27 stamping; the second passes "
            "a local coordinate triple into 0x4a5e73 and only uses the return when it is "
            "nonnegative, packing the low-nibble result into GeneratedCell+0x2c."
        ),
    }


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    refs = parse_refs(args.refs)
    sites = set(EXPECTED_CALLSITES)
    counts = corpus_counts(args.root, sites)
    static_6cf2 = static_6cf2_surface(args.dump_6cf2)
    cursor = load_json(args.cursor_frontier)
    target_696b = load_json(args.target_696b)
    forced = load_json(args.forced_bg)
    natural = load_json(args.natural_bg)
    follow = load_json(args.followthrough)
    endpoint_chain = load_json(args.endpoint_chain)

    ref_map = {record["callsite"]: record for record in refs}
    ledger_counts = counts["ledger_event_counts"]
    log_counts = counts["raw_log_stop_counts"]
    inactive_sites = ["0x004a6c97", "0x004a711c", "0x004a71f5"]
    invariants = {
        "no_native_behavior_change": True,
        "no_objdump_used": True,
        "six_static_callers_recovered": ref_map == {
            site: {"callsite": site, **expected} for site, expected in EXPECTED_CALLSITES.items()
        },
        "endpoint_static_chain_recovered": endpoint_chain.get("status")
        == "partial_static_recovery_connection_endpoint_state_chain",
        "cursor_frontier_success_path_unhit": cursor.get("status")
        == "target_mode_4a5e73_cursor_precondition_recovered_success_path_unhit",
        "4a61bc_live_calls_fail_on_stale_cursor": (
            natural.get("status") == "natural_border_guard_branch_reaches_5e73_but_cursor_unseeded"
            and follow.get("status") == "border_guard_endpoint_failures_followed_by_7605_5e03_materialization"
            and natural.get("invariants", {}).get("all_4a5e73_entries_failed_at_4a5f84") is True
            and follow.get("invariants", {}).get("all_border_guard_failures_used_stale_f5c") is True
        ),
        "4a696b_target_mode_blocked_before_endpoint_callsite": target_696b.get("status")
        == "target_mode_4a696b_direct_mutation_unreached_pair_gate_explained",
        "4a6cf2_static_endpoint_gate_surface_recovered": static_6cf2["static_contract_recovered"],
        "4a6cf2_callers_unhit_in_current_corpus": all(
            ledger_counts[site] == 0 and log_counts[site] == 0 for site in ["0x004a711c", "0x004a71f5"]
        ),
        "4a746b_forced_route_hits_endpoint_but_fails_before_mutation": (
            forced.get("status") == "forced_plus09_routes_to_4a746b_5e73_without_mutation"
            and forced.get("invariants", {}).get("two_4a7593_to_4a5e73_delegations_observed") is True
            and forced.get("invariants", {}).get("generated_cell_mutation_not_reached") is True
        ),
        "inactive_current_corpus_callsite_family_has_no_runtime_hits": all(
            ledger_counts[site] == 0 and log_counts[site] == 0 for site in inactive_sites
        ),
    }
    status = (
        "4a5e73_all_caller_gate_surface_recovered_current_scope_success_path_still_unrecovered"
        if all(invariants.values())
        else "4a5e73_caller_gate_surface_incomplete"
    )

    caller_surface = [
        {
            "callsite": "0x004a64ff",
            "caller": "0x004a61bc",
            "gate_summary": "natural Border Guard endpoint pair, first direction; live current corpus reaches it and fails in 0x4a5e73 on stale generator+0xf5c",
        },
        {
            "callsite": "0x004a6531",
            "caller": "0x004a61bc",
            "gate_summary": "natural Border Guard endpoint pair, second direction; live current corpus reaches it and fails in 0x4a5e73 on stale generator+0xf5c",
        },
        {
            "callsite": "0x004a6c97",
            "caller": "0x004a696b",
            "gate_summary": "direct mutation branch; current target-mode corpus stops before it at GeneratedCell+0x20 owner/relation byte-pair gate",
        },
        {
            "callsite": "0x004a711c",
            "caller": "0x004a6cf2",
            "gate_summary": "optional endpoint branch gated by compact record +0x09 after generated-cell bit27 stamping; no current-corpus runtime hit",
        },
        {
            "callsite": "0x004a71f5",
            "caller": "0x004a6cf2",
            "gate_summary": "second optional endpoint branch that packs nonnegative 0x4a5e73 result into GeneratedCell+0x2c; no current-corpus runtime hit",
        },
        {
            "callsite": "0x004a7593",
            "caller": "0x004a746b",
            "gate_summary": "endpoint-normalize/stamp helper; forced +0x09 route reaches it twice, both 0x4a5e73 calls fail before mutation",
        },
    ]
    for surface in caller_surface:
        site = surface["callsite"]
        surface["runtime_ledger_events"] = ledger_counts[site]
        surface["runtime_raw_log_stops"] = log_counts[site]

    return {
        "schema_id": "h3maped_4a5e73_caller_gate_surface_summary_v1",
        "status": status,
        "scope": (
            "Current-source caller-gate surface for every static call into 0x4a5e73. "
            "This is recovery evidence only and does not authorize native RMG behavior changes."
        ),
        "inputs": {
            "root": str(args.root),
            "refs": str(args.refs),
            "dump_6cf2": str(args.dump_6cf2),
            "cursor_frontier": str(args.cursor_frontier),
            "target_696b": str(args.target_696b),
            "forced_bg": str(args.forced_bg),
            "natural_bg": str(args.natural_bg),
            "followthrough": str(args.followthrough),
            "endpoint_chain": str(args.endpoint_chain),
        },
        "invariants": invariants,
        "metrics": {
            "native_behavior_changed": False,
            "used_objdump": False,
            "overall_goal_complete": False,
            "static_4a5e73_callsite_count": len(refs),
            "current_corpus_4a61bc_callsite_events": ledger_counts["0x004a64ff"]
            + ledger_counts["0x004a6531"],
            "current_corpus_4a746b_callsite_events": ledger_counts["0x004a7593"],
            "current_corpus_inactive_family_callsite_events": sum(
                ledger_counts[site] for site in inactive_sites
            ),
        },
        "static_call_references": refs,
        "corpus_callsite_counts": counts,
        "static_4a6cf2_surface": static_6cf2,
        "caller_surface": caller_surface,
        "source_backed_conclusion": (
            "All six static callers of 0x4a5e73 are now grouped by gate. The live current corpus "
            "reaches only the 0x4a61bc natural Border Guard callsites and the forced 0x4a746b route; "
            "all observed entries still fail before 0x4a5e73 mutation. The 0x4a696b callsite is "
            "blocked earlier by the recovered owner/relation byte-pair gate, and both 0x4a6cf2 "
            "endpoint callsites are static-only in the current corpus. The remaining endpoint gap "
            "is therefore not an unclassified caller family; it is either a broader source/mode that "
            "makes one of these gates live and seeds generator+0xf5c, or a source-backed exclusion "
            "for successful endpoint stamping in supported one-level land."
        ),
        "remaining_gap": (
            "Still recover a natural successful 0x4a5e73 entry, or prove with broader map-mode/"
            "source-state evidence that no supported one-level land source can make these caller "
            "gates reach a seeded generator+0xf5c success path. Do not port or compensate native "
            "RMG behavior from this negative current-corpus evidence alone."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--refs", type=Path, default=DEFAULT_REFS)
    parser.add_argument("--dump-6cf2", type=Path, default=DEFAULT_6CF2_DUMP)
    parser.add_argument("--cursor-frontier", type=Path, default=DEFAULT_CURSOR_FRONTIER)
    parser.add_argument("--target-696b", type=Path, default=DEFAULT_696B_TARGET)
    parser.add_argument("--forced-bg", type=Path, default=DEFAULT_FORCED_BG)
    parser.add_argument("--natural-bg", type=Path, default=DEFAULT_NATURAL_BG)
    parser.add_argument("--followthrough", type=Path, default=DEFAULT_FOLLOWTHROUGH)
    parser.add_argument("--endpoint-chain", type=Path, default=DEFAULT_ENDPOINT_CHAIN)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_4A5E73_CALLER_GATE_SURFACE "
        f"status={summary['status']} callsites={summary['metrics']['static_4a5e73_callsite_count']} "
        f"inactive_hits={summary['metrics']['current_corpus_inactive_family_callsite_events']} "
        f"out={args.out}"
    )
    return (
        0
        if summary["status"]
        == "4a5e73_all_caller_gate_surface_recovered_current_scope_success_path_still_unrecovered"
        else 1
    )


if __name__ == "__main__":
    raise SystemExit(main())
