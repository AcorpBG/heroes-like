#!/usr/bin/env python3
"""Summarize the current 0x4a606b reachability frontier.

This is a recovery checkpoint, not a native RMG implementation step. It uses
Ghidra-exported static evidence plus the existing Wine trace summaries to
answer a narrow question: what is known about 0x4a606b today, and why has no
current target run entered it?
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


DEFAULT_ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_GHIDRA_DUMP = DEFAULT_ROOT / "ghidra_downstream_state_dump/target_004a606b_FUN_004a606b.txt"
DEFAULT_GHIDRA_REFS = DEFAULT_ROOT / "ghidra_downstream_state_dump/target_004a606b_references.txt"
DEFAULT_NATURAL_BG = (
    DEFAULT_ROOT / "medium_seed10_hc1_co1_border_guard_seed_pinned_summary_20260609.json"
)
DEFAULT_FORCED_BG = DEFAULT_ROOT / "forced_border_guard_route_summary_20260608.json"
DEFAULT_BORDER_GUARD_CHAIN = DEFAULT_ROOT / "border_guard_downstream_chain_summary_20260610.json"
DEFAULT_OUT = DEFAULT_ROOT / "4a606b_reachability_summary_20260610.json"

TARGET_ADDRESS = "0x004a606b"
TARGET_NEEDLES = {TARGET_ADDRESS, "0x4a606b"}
STOP_RE = re.compile(
    r"Stopped on [A-Za-z _-]*(?:breakpoint|watchpoint)\s+\d+\s+at\s+(0x[0-9a-fA-F]+)"
)


def normalize_address(value: str) -> str:
    return f"0x{int(value, 0) & 0xFFFFFFFF:08x}"


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def text_mentions_target(text: str) -> bool:
    lower = text.lower()
    return any(needle.lower() in lower for needle in TARGET_NEEDLES)


def summarize_ledger(path: Path) -> dict[str, Any] | None:
    text = read_text(path)
    if not text_mentions_target(text):
        return None
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        return None

    events = data.get("events", [])
    event_samples: list[dict[str, Any]] = []
    event_count = 0
    for index, event in enumerate(events):
        address = str(event.get("address", ""))
        if not address:
            continue
        try:
            normalized = normalize_address(address)
        except ValueError:
            continue
        if normalized != TARGET_ADDRESS:
            continue
        event_count += 1
        if len(event_samples) < 3:
            registers = event.get("registers", {})
            event_samples.append(
                {
                    "event_index": index,
                    "registers": {
                        name: f"0x{value & 0xFFFFFFFF:08x}"
                        for name, value in registers.items()
                        if isinstance(value, int)
                        and name in {"eax", "ebx", "ecx", "edx", "esi", "edi", "ebp", "esp"}
                    },
                }
            )

    breakpoint_mentions = sorted(
        normalize_address(str(value))
        for value in data.get("breakpoints", [])
        if isinstance(value, str) and normalize_address(str(value)) == TARGET_ADDRESS
    )
    address_command_mentions = sorted(
        normalize_address(str(value).split("=", 1)[0])
        for value in data.get("address_command", [])
        if isinstance(value, str)
        and "=" in value
        and normalize_address(str(value).split("=", 1)[0]) == TARGET_ADDRESS
    )
    if event_count == 0 and not breakpoint_mentions and not address_command_mentions:
        return None
    return {
        "path": str(path),
        "event_count": data.get("event_count", len(events)),
        "target_event_count": event_count,
        "target_event_samples": event_samples,
        "target_breakpoints": breakpoint_mentions,
        "target_address_commands": address_command_mentions,
        "classification": "runtime_hit" if event_count else "breakpoint_or_command_only_no_hit",
    }


def summarize_log(path: Path) -> dict[str, Any] | None:
    text = read_text(path)
    if not text_mentions_target(text):
        return None

    stop_count = 0
    for match in STOP_RE.finditer(text):
        try:
            normalized = normalize_address(match.group(1))
        except ValueError:
            continue
        if normalized == TARGET_ADDRESS:
            stop_count += 1

    break_mentions = (
        text.lower().count(f"break *{TARGET_ADDRESS}".lower())
        + text.lower().count("break *0x4a606b")
    )
    if stop_count == 0 and break_mentions == 0:
        return None
    return {
        "path": str(path),
        "target_stop_count": stop_count,
        "target_break_command_count": break_mentions,
        "classification": "runtime_hit" if stop_count else "breakpoint_only_no_hit",
    }


def corpus_summary(root: Path) -> dict[str, Any]:
    ledgers = sorted(root.rglob("*ledger.json"))
    logs = sorted(root.rglob("*.log"))
    ledger_records = [record for path in ledgers if (record := summarize_ledger(path))]
    log_records = [record for path in logs if (record := summarize_log(path))]
    runtime_ledger_records = [
        record for record in ledger_records if record["classification"] == "runtime_hit"
    ]
    runtime_log_records = [
        record for record in log_records if record["classification"] == "runtime_hit"
    ]
    return {
        "ledger_files_scanned": len(ledgers),
        "log_files_scanned": len(logs),
        "ledger_records_with_target_mentions": len(ledger_records),
        "log_records_with_target_mentions": len(log_records),
        "runtime_ledger_hit_records": len(runtime_ledger_records),
        "runtime_log_hit_records": len(runtime_log_records),
        "target_event_total_from_ledgers": sum(
            int(record["target_event_count"]) for record in ledger_records
        ),
        "target_stop_total_from_logs": sum(int(record["target_stop_count"]) for record in log_records),
        "breakpoint_only_evidence": {
            "ledger_records": [
                record["path"]
                for record in ledger_records
                if record["classification"] != "runtime_hit"
            ],
            "log_records": [
                record["path"] for record in log_records if record["classification"] != "runtime_hit"
            ],
        },
        "runtime_hit_evidence": {
            "ledger_records": runtime_ledger_records,
            "log_records": runtime_log_records,
        },
    }


def static_contract_summary(dump_text: str, refs_text: str) -> dict[str, Any]:
    needles = {
        "function_entry_present": "entry=004a606b" in dump_text,
        "calls_49aa63": "CALL 0x0049aa63" in dump_text or "CALL 0x0049aa63" in refs_text,
        "calls_49a932": "CALL 0x0049a932" in dump_text or "CALL 0x0049a932" in refs_text,
        "reads_coordinate_arg_x": "MOV ESI,dword ptr [EBP + 0x8]" in dump_text,
        "reads_coordinate_arg_y": "MOV EDI,dword ptr [EBP + 0xc]" in dump_text,
        "reads_low_nibble_arg": "MOV EAX,dword ptr [EBP + 0x14]" in dump_text,
        "object_ref_empty_gate": "[ESI + 0x4]" in dump_text and "[ESI + 0x8]" in dump_text,
        "private_flag_pack_write": "0xffffffe1" in dump_text,
        "projection_triple_copy": (
            "LEA ESI,[EAX + ECX*0x1 + 0x10]" in dump_text
            and dump_text.count("MOVSD ES:EDI,ESI") >= 3
        ),
        "only_two_direct_callers_from_4a61bc": (
            "from=004a6516" in refs_text
            and "from=004a6548" in refs_text
            and refs_text.count("instruction=CALL 0x004a606b") == 2
            and "caller=FUN_004a61bc" in refs_text
        ),
    }
    return {
        "checks": needles,
        "callers": [
            {
                "address": "0x004a6516",
                "caller": "0x004a61bc",
                "gate": "control byte [arg2+0x09] and nonnegative 0x4a5e73 return",
            },
            {
                "address": "0x004a6548",
                "caller": "0x004a61bc",
                "gate": "control byte [arg2+0x09] and nonnegative 0x4a5e73 return",
            },
        ],
        "recovered_contract": (
            "0x4a606b is a generated-cell endpoint/region stamp helper called only by "
            "0x4a61bc in the recovered refs. It receives generator in ECX, coordinate "
            "triple args on the stack, and a low-nibble source/result argument from "
            "0x4a5e73. It stamps an empty-object-ref 3x3 neighborhood through "
            "0x49aa63(true), packs bit0 plus the result nibble into GeneratedCell+0x2c, "
            "then follows the source cell projection triple and marks the projected target "
            "through 0x49a932(true)."
        ),
    }


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    dump_text = read_text(args.ghidra_dump)
    refs_text = read_text(args.ghidra_refs)
    natural_bg = load_json(args.natural_bg)
    forced_bg = load_json(args.forced_bg)
    border_guard_chain = load_json(args.border_guard_chain)
    static_contract = static_contract_summary(dump_text, refs_text)
    corpus = corpus_summary(args.root)

    natural_counts = natural_bg.get("generated_cell_mutation_hits", {})
    natural_invariants = natural_bg.get("invariants", {})
    forced_invariants = forced_bg.get("invariants", {})
    chain_invariants = border_guard_chain.get("invariants", {})
    invariants = {
        "no_native_behavior_change": (
            natural_invariants.get("native_behavior_changed") is False
            and forced_invariants.get("native_behavior_changed") is False
            and border_guard_chain.get("metrics", {}).get("native_behavior_changed") is False
        ),
        "no_objdump_used": True,
        "static_contract_recovered": all(static_contract["checks"].values()),
        "natural_seed10_reaches_branch_but_not_4a606b": (
            natural_bg.get("status")
            == "natural_border_guard_branch_reaches_5e73_but_cursor_unseeded"
            and natural_invariants.get("natural_border_guard_branch_observed") is True
            and natural_invariants.get("all_4a5e73_entries_failed_at_4a5f84") is True
            and natural_counts.get("0x4a606b") == 0
        ),
        "forced_route_reaches_precondition_but_not_4a606b": (
            forced_bg.get("status") == "forced_plus09_routes_to_4a746b_5e73_without_mutation"
            and forced_invariants.get("two_4a746b_calls_observed") is True
            and forced_invariants.get("two_4a7593_to_4a5e73_delegations_observed") is True
            and forced_invariants.get("generated_cell_mutation_not_reached") is True
        ),
        "exact_seed10_chain_recovered_before_broader_4a606b_scope": (
            border_guard_chain.get("status")
            == "exact_seed10_border_guard_downstream_chain_recovered_broader_linkage_pending"
            and chain_invariants.get("exact_fallback_final_role_recovered") is True
        ),
        "current_corpus_has_no_live_4a606b_hit": (
            corpus["target_event_total_from_ledgers"] == 0
            and corpus["target_stop_total_from_logs"] == 0
        ),
    }
    status = (
        "target_mode_4a606b_static_contract_recovered_no_live_hit"
        if all(invariants.values())
        else "target_mode_4a606b_frontier_inputs_incomplete"
    )

    return {
        "schema_id": "h3maped_4a606b_reachability_summary_v1",
        "status": status,
        "scope": (
            "Current one-level land target evidence for 0x4a606b. This is not a global "
            "unreachable proof and not authority to change native RMG behavior."
        ),
        "inputs": {
            "root": str(args.root),
            "ghidra_dump": str(args.ghidra_dump),
            "ghidra_refs": str(args.ghidra_refs),
            "natural_bg": str(args.natural_bg),
            "forced_bg": str(args.forced_bg),
            "border_guard_chain": str(args.border_guard_chain),
        },
        "invariants": invariants,
        "static_contract": static_contract,
        "runtime_corpus": corpus,
        "metrics": {
            "native_behavior_changed": False,
            "used_objdump": False,
            "overall_goal_complete": False,
            "ledger_files_scanned": corpus["ledger_files_scanned"],
            "log_files_scanned": corpus["log_files_scanned"],
            "runtime_4a606b_event_count": corpus["target_event_total_from_ledgers"],
            "runtime_4a606b_log_stop_count": corpus["target_stop_total_from_logs"],
            "breakpoint_only_ledger_record_count": len(
                corpus["breakpoint_only_evidence"]["ledger_records"]
            ),
            "breakpoint_only_log_record_count": len(corpus["breakpoint_only_evidence"]["log_records"]),
        },
        "source_backed_conclusion": (
            "0x4a606b itself is statically recovered from the Ghidra dump/reference set as the "
            "0x4a61bc connection-region generated-cell writer. The current natural seed-10 "
            "Border Guard replay and forced +0x09 replay both fail before this helper because "
            "their 0x4a5e73 precondition returns failure; the exact seed-10 branch then follows "
            "the recovered 0x4a7605 -> 0x4a5e03 fallback chain. The current corpus contains "
            "breakpoint-only mentions but no live 0x4a606b event or raw-log stop."
        ),
        "remaining_gap": (
            "Before native RMG can port or exclude this endpoint-stamping path, recover a natural "
            "successful 0x4a5e73 path that reaches 0x4a606b, or prove with broader map-mode/"
            "source-state evidence that 0x4a606b is unreachable for the supported one-level land "
            "scope. Current evidence only proves no live hit in the existing target corpus."
        ),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--ghidra-dump", type=Path, default=DEFAULT_GHIDRA_DUMP)
    parser.add_argument("--ghidra-refs", type=Path, default=DEFAULT_GHIDRA_REFS)
    parser.add_argument("--natural-bg", type=Path, default=DEFAULT_NATURAL_BG)
    parser.add_argument("--forced-bg", type=Path, default=DEFAULT_FORCED_BG)
    parser.add_argument("--border-guard-chain", type=Path, default=DEFAULT_BORDER_GUARD_CHAIN)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--pretty", action="store_true")
    args = parser.parse_args()

    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(
        json.dumps(summary, indent=2 if args.pretty else None, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(
        f"{summary['status']}: live_hits="
        f"{summary['metrics']['runtime_4a606b_event_count'] + summary['metrics']['runtime_4a606b_log_stop_count']}"
    )


if __name__ == "__main__":
    main()
