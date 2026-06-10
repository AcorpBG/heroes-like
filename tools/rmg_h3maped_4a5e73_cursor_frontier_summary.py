#!/usr/bin/env python3
"""Summarize the 0x4a5e73 cursor/precondition frontier.

This checkpoint consolidates the source-state evidence around the helper that
blocks successful Border Guard endpoint stamping. It is recovery evidence only:
it names the currently missing state, and it does not authorize native RMG
behavior changes.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


DEFAULT_ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_GHIDRA_DUMP = DEFAULT_ROOT / "ghidra_downstream_helper_dump/target_004a5e73_FUN_004a5e73.txt"
DEFAULT_GHIDRA_REFS = DEFAULT_ROOT / "ghidra_downstream_helper_dump/target_004a5e73_references.txt"
DEFAULT_CURSOR_ACCESS = DEFAULT_ROOT / "cursor_f5c_1104_access_summary_20260608.json"
DEFAULT_CALLSITE = DEFAULT_ROOT / "medium_seed10_4a61bc_5e73_callsite_summary_20260608.json"
DEFAULT_NATURAL_BG = (
    DEFAULT_ROOT / "medium_seed10_hc1_co1_border_guard_seed_pinned_summary_20260609.json"
)
DEFAULT_FOLLOWTHROUGH = (
    DEFAULT_ROOT / "medium_seed10_hc1_co1_border_guard_followthrough_seed_pinned_summary_20260609.json"
)
DEFAULT_FORCED_BG = DEFAULT_ROOT / "forced_border_guard_route_summary_20260608.json"
DEFAULT_4A606B = DEFAULT_ROOT / "4a606b_reachability_summary_20260610.json"
DEFAULT_OUT = DEFAULT_ROOT / "4a5e73_cursor_frontier_summary_20260610.json"

TARGET_SITES = {
    "0x004a5e73": "endpoint_helper_entry",
    "0x004a5f84": "early_failure_return_minus_one",
    "0x004a5fd8": "success_path_clear_generated_cell_private_flags",
    "0x004a5ff1": "success_path_set_generated_cell_bit27_clear_bit26",
    "0x004a6004": "success_path_commit_callback",
    "0x004a6018": "success_path_mark_1104_byte_state",
    "0x004a6050": "success_path_advance_f5c_cursor",
    "0x004a606b": "downstream_connection_region_writer",
}
TARGET_SITE_SET = set(TARGET_SITES)
TARGET_NEEDLES = set(TARGET_SITES) | {site.replace("0x00", "0x") for site in TARGET_SITES}
STOP_RE = re.compile(
    r"Stopped on [A-Za-z _-]*(?:breakpoint|watchpoint)\s+\d+\s+at\s+(0x[0-9a-fA-F]+)"
)


def normalize_address(value: str) -> str:
    return f"0x{int(value, 0) & 0xFFFFFFFF:08x}"


def safe_normalize(value: str) -> str | None:
    try:
        return normalize_address(value)
    except ValueError:
        return None


def read_json(path: Path) -> dict[str, Any]:
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

    event_counts = {site: 0 for site in TARGET_SITES}
    event_samples: dict[str, list[dict[str, Any]]] = {site: [] for site in TARGET_SITES}
    for index, event in enumerate(data.get("events", [])):
        normalized = safe_normalize(str(event.get("address", "")))
        if normalized not in TARGET_SITE_SET:
            continue
        event_counts[normalized] += 1
        if len(event_samples[normalized]) < 2:
            registers = event.get("registers", {})
            event_samples[normalized].append(
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

    breakpoint_mentions: list[str] = []
    for value in data.get("breakpoints", []):
        if isinstance(value, str) and (normalized := safe_normalize(value)) in TARGET_SITE_SET:
            breakpoint_mentions.append(normalized)

    address_command_mentions: list[str] = []
    for value in data.get("address_command", []):
        if not isinstance(value, str) or "=" not in value:
            continue
        if (normalized := safe_normalize(value.split("=", 1)[0])) in TARGET_SITE_SET:
            address_command_mentions.append(normalized)

    hit_total = sum(event_counts.values())
    if hit_total == 0 and not breakpoint_mentions and not address_command_mentions:
        return None
    return {
        "path": str(path),
        "event_count": data.get("event_count", len(data.get("events", []))),
        "target_event_counts": {k: v for k, v in event_counts.items() if v},
        "target_event_samples": {k: v for k, v in event_samples.items() if v},
        "target_breakpoints": sorted(set(breakpoint_mentions)),
        "target_address_commands": sorted(set(address_command_mentions)),
        "classification": "runtime_hit" if hit_total else "breakpoint_or_command_only_no_hit",
    }


def summarize_log(path: Path) -> dict[str, Any] | None:
    text = read_text(path)
    if not text_mentions_target(text):
        return None
    counts = {site: 0 for site in TARGET_SITES}
    for match in STOP_RE.finditer(text):
        if (normalized := safe_normalize(match.group(1))) in counts:
            counts[normalized] += 1
    break_mentions = {
        site: text.lower().count(f"break *{site}".lower())
        + text.lower().count(f"break *{site.replace('0x00', '0x')}".lower())
        for site in TARGET_SITES
    }
    if not any(counts.values()) and not any(break_mentions.values()):
        return None
    return {
        "path": str(path),
        "target_stop_counts": {k: v for k, v in counts.items() if v},
        "target_break_command_counts": {k: v for k, v in break_mentions.items() if v},
        "classification": "runtime_hit" if any(counts.values()) else "breakpoint_only_no_hit",
    }


def corpus_summary(root: Path) -> dict[str, Any]:
    ledgers = sorted(root.rglob("*ledger.json"))
    logs = sorted(root.rglob("*.log"))
    ledger_records = [record for path in ledgers if (record := summarize_ledger(path))]
    log_records = [record for path in logs if (record := summarize_log(path))]
    event_totals = {site: 0 for site in TARGET_SITES}
    for record in ledger_records:
        for site, count in record.get("target_event_counts", {}).items():
            event_totals[site] += int(count)
    log_stop_totals = {site: 0 for site in TARGET_SITES}
    for record in log_records:
        for site, count in record.get("target_stop_counts", {}).items():
            log_stop_totals[site] += int(count)
    success_sites = {
        "0x004a5fd8",
        "0x004a5ff1",
        "0x004a6004",
        "0x004a6018",
        "0x004a6050",
        "0x004a606b",
    }
    return {
        "ledger_files_scanned": len(ledgers),
        "log_files_scanned": len(logs),
        "ledger_records_with_target_mentions": len(ledger_records),
        "log_records_with_target_mentions": len(log_records),
        "target_event_totals_from_ledgers": event_totals,
        "target_stop_totals_from_logs": log_stop_totals,
        "runtime_hit_sites_from_ledgers": sorted(site for site, count in event_totals.items() if count),
        "runtime_hit_sites_from_logs": sorted(site for site, count in log_stop_totals.items() if count),
        "success_path_event_total": sum(event_totals[site] for site in success_sites),
        "success_path_log_stop_total": sum(log_stop_totals[site] for site in success_sites),
        "breakpoint_only_evidence": {
            "ledger_records": [
                record["path"]
                for record in ledger_records
                if record.get("classification") != "runtime_hit"
            ],
            "log_records": [
                record["path"] for record in log_records if record.get("classification") != "runtime_hit"
            ],
        },
        "runtime_hit_evidence": {
            "ledger_records": [
                record for record in ledger_records if record.get("classification") == "runtime_hit"
            ][:10],
            "log_records": [
                record for record in log_records if record.get("classification") == "runtime_hit"
            ][:10],
        },
    }


def static_contract(dump_text: str, refs_text: str) -> dict[str, Any]:
    checks = {
        "entry_present": "entry=004a5e73" in dump_text,
        "six_direct_callers_recovered": refs_text.count("instruction=CALL 0x004a5e73") == 6,
        "reads_generator_f5c_at_entry": "004a5e85: MOV EDI,dword ptr [EBX + 0xf5c]" in dump_text,
        "early_failure_minus_one": "004a5f84: OR EAX,0xffffffff" in dump_text,
        "success_clears_private_flags": "004a5fd8: AND dword ptr [ECX + 0x2c],0xffffffe0" in dump_text,
        "success_sets_bit27_clears_bit26": (
            "004a5fe5: AND EDX,0xfbffffff" in dump_text
            and "004a5feb: OR EDX,0x8000000" in dump_text
            and "004a5ff1: MOV dword ptr [ECX + 0x28],EDX" in dump_text
        ),
        "success_marks_1104_byte_state": "004a6018: MOV byte ptr [EAX + EDI*0x1],0x1" in dump_text,
        "success_resets_and_advances_f5c": (
            "004a601c: AND dword ptr [EBX + 0xf5c],0x0" in dump_text
            and "004a6050: MOV dword ptr [EBX + 0xf5c],ECX" in dump_text
        ),
    }
    callers = []
    for line in refs_text.splitlines():
        if "instruction=CALL 0x004a5e73" not in line:
            continue
        parts = {}
        for item in line.strip().split():
            if "=" in item:
                key, value = item.split("=", 1)
                parts[key] = value
        callers.append(
            {
                "callsite": f"0x{parts.get('from', '')}",
                "caller": parts.get("caller"),
                "caller_entry": f"0x{parts.get('caller_entry', '')}",
            }
        )
    return {
        "checks": checks,
        "callers": callers,
        "recovered_contract": (
            "0x4a5e73 reads generator+0xf5c and scans endpoint key vectors. Failure returns -1 "
            "at 0x4a5f84 before generated-cell mutation. The success path clears GeneratedCell+0x2c "
            "low bits, sets +0x28 bit27 while clearing bit26, calls the generator commit callback, "
            "marks generator+0x1104 byte state, and resets/advances generator+0xf5c."
        ),
    }


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    dump_text = read_text(args.ghidra_dump)
    refs_text = read_text(args.ghidra_refs)
    cursor = read_json(args.cursor_access)
    callsite = read_json(args.callsite)
    natural_bg = read_json(args.natural_bg)
    followthrough = read_json(args.followthrough)
    forced_bg = read_json(args.forced_bg)
    four_a606b = read_json(args.four_a606b)
    static = static_contract(dump_text, refs_text)
    corpus = corpus_summary(args.root)

    cursor_invariants = cursor.get("invariants", {})
    callsite_invariants = callsite.get("invariants", {})
    natural_invariants = natural_bg.get("invariants", {})
    follow_invariants = followthrough.get("invariants", {})
    forced_invariants = forced_bg.get("invariants", {})
    invariants = {
        "no_native_behavior_change": (
            cursor_invariants.get("native_behavior_changed") is False
            and callsite_invariants.get("native_behavior_changed") is False
            and natural_invariants.get("native_behavior_changed") is False
            and follow_invariants.get("native_behavior_changed") is False
            and forced_invariants.get("native_behavior_changed") is False
            and four_a606b.get("metrics", {}).get("native_behavior_changed") is False
        ),
        "no_objdump_used": True,
        "static_contract_recovered": all(static["checks"].values()),
        "cursor_writer_surface_exhausted": (
            cursor.get("status") == "cursor_writer_surface_exhausted_natural_bg_still_unseeded"
            and cursor_invariants.get("known_cursor_writers_only") is True
            and cursor_invariants.get("no_4adb72_or_4add76_before_first_natural_4a5e73") is True
            and cursor_invariants.get("no_49cd9b_4adb72_or_4add76_before_first_natural_4a5e73")
            is True
        ),
        "first_natural_callsite_failure_recovered": (
            callsite.get("status") == "natural_bg_first_5e73_cursor_unseeded_against_d8_key_range"
            and callsite_invariants.get("entry_arguments_are_normal_coordinate_repeat_source_shape")
            is True
            and callsite_invariants.get("d8_record_keys_are_zero_through_seven") is True
            and callsite_invariants.get("cursor_is_stale_unseeded_value_not_d8_key") is True
        ),
        "seed10_natural_all_border_guard_5e73_calls_fail": (
            natural_bg.get("status")
            == "natural_border_guard_branch_reaches_5e73_but_cursor_unseeded"
            and natural_invariants.get("all_4a5e73_entries_failed_at_4a5f84") is True
            and follow_invariants.get("all_border_guard_4a5e73_calls_failed_at_4a5f84") is True
            and follow_invariants.get("all_border_guard_failures_used_stale_f5c") is True
        ),
        "forced_plus09_also_fails_before_success_path": (
            forced_bg.get("status") == "forced_plus09_routes_to_4a746b_5e73_without_mutation"
            and forced_invariants.get("two_4a7593_to_4a5e73_delegations_observed") is True
            and forced_invariants.get("generated_cell_mutation_not_reached") is True
        ),
        "current_corpus_has_no_5e73_success_path_hit": (
            corpus["success_path_event_total"] == 0 and corpus["success_path_log_stop_total"] == 0
        ),
        "current_4a606b_no_live_hit_depends_on_5e73_failure": (
            four_a606b.get("status") == "target_mode_4a606b_static_contract_recovered_no_live_hit"
            and four_a606b.get("invariants", {}).get("natural_seed10_reaches_branch_but_not_4a606b")
            is True
        ),
    }
    status = (
        "target_mode_4a5e73_cursor_precondition_recovered_success_path_unhit"
        if all(invariants.values())
        else "target_mode_4a5e73_cursor_frontier_inputs_incomplete"
    )
    return {
        "schema_id": "h3maped_4a5e73_cursor_frontier_summary_v1",
        "status": status,
        "scope": (
            "Current one-level land target evidence for 0x4a5e73 cursor/precondition state. "
            "This is not a global unreachable proof and not authority to change native RMG behavior."
        ),
        "inputs": {
            "root": str(args.root),
            "ghidra_dump": str(args.ghidra_dump),
            "ghidra_refs": str(args.ghidra_refs),
            "cursor_access": str(args.cursor_access),
            "callsite": str(args.callsite),
            "natural_bg": str(args.natural_bg),
            "followthrough": str(args.followthrough),
            "forced_bg": str(args.forced_bg),
            "4a606b": str(args.four_a606b),
        },
        "invariants": invariants,
        "static_contract": static,
        "runtime_corpus": corpus,
        "metrics": {
            "native_behavior_changed": False,
            "used_objdump": False,
            "overall_goal_complete": False,
            "ledger_files_scanned": corpus["ledger_files_scanned"],
            "log_files_scanned": corpus["log_files_scanned"],
            "runtime_5e73_entry_count": corpus["target_event_totals_from_ledgers"]["0x004a5e73"],
            "runtime_5e73_failure_count": corpus["target_event_totals_from_ledgers"]["0x004a5f84"],
            "runtime_5e73_success_path_event_count": corpus["success_path_event_total"],
            "runtime_5e73_success_path_log_stop_count": corpus["success_path_log_stop_total"],
        },
        "source_backed_conclusion": (
            "0x4a5e73 is statically recovered as the endpoint helper whose success path mutates "
            "GeneratedCell+0x2c/+0x28, marks generator+0x1104, and advances generator+0xf5c. "
            "The first natural seed-10 Border Guard call enters with normal coordinate/count/source "
            "arguments and scans eight active +0xd8 keys 0..7, but generator+0xf5c is still "
            "0x7a1befdf, so it returns -1 before mutation. The known direct +0xf5c writer surface "
            "is limited to 0x4a5e73, 0x4adb72, and 0x4add76, and the current pre-first-call probes "
            "show none of the latter writer paths run before the first natural failure. Current "
            "corpus scanning finds no live success-path event or stop."
        ),
        "remaining_gap": (
            "Recover the source path/precondition that seeds generator+0xf5c to an active endpoint "
            "key before successful 0x4a5e73 materialization, or prove with broader map-mode/"
            "source-state evidence that the success path is unreachable for supported one-level "
            "land. Do not replace this with native density tuning, retries, or final-map deltas."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--ghidra-dump", type=Path, default=DEFAULT_GHIDRA_DUMP)
    parser.add_argument("--ghidra-refs", type=Path, default=DEFAULT_GHIDRA_REFS)
    parser.add_argument("--cursor-access", type=Path, default=DEFAULT_CURSOR_ACCESS)
    parser.add_argument("--callsite", type=Path, default=DEFAULT_CALLSITE)
    parser.add_argument("--natural-bg", type=Path, default=DEFAULT_NATURAL_BG)
    parser.add_argument("--followthrough", type=Path, default=DEFAULT_FOLLOWTHROUGH)
    parser.add_argument("--forced-bg", type=Path, default=DEFAULT_FORCED_BG)
    parser.add_argument("--four-a606b", type=Path, default=DEFAULT_4A606B)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_4A5E73_CURSOR_FRONTIER "
        f"status={summary['status']} "
        f"entry_hits={summary['metrics']['runtime_5e73_entry_count']} "
        f"success_hits={summary['metrics']['runtime_5e73_success_path_event_count']} "
        f"out={args.out}"
    )
    return (
        0
        if summary["status"]
        == "target_mode_4a5e73_cursor_precondition_recovered_success_path_unhit"
        else 1
    )


if __name__ == "__main__":
    raise SystemExit(main())
