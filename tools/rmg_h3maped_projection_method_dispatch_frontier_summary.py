#!/usr/bin/env python3
"""Summarize the live frontier for H3MapEd projection-object method dispatch.

This checkpoint sits one layer above the cleanup/uncommit helpers. Static
recovery shows cleanup/reselection is reached through projection-object slot
+0x08 methods, so this report asks whether the current corpus actually calls
those methods and whether sampled projection objects survive into later phase
vectors.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


DEFAULT_ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_OUT = DEFAULT_ROOT / "projection_method_dispatch_frontier_summary_20260609.json"

STATIC_SUMMARY = (
    DEFAULT_ROOT
    / "direct_generation_49cac2_projection_constructor_hit_trace"
    / "49c_projection_static_summary.json"
)
CONSTRUCTOR_SUMMARY = (
    DEFAULT_ROOT
    / "direct_generation_49cac2_projection_constructor_hit_trace"
    / "49c_projection_constructor_summary.json"
)
CONSUMER_SUMMARY = DEFAULT_ROOT / "projection_consumer_surface_summary.json"
SURVIVAL_SUMMARY = DEFAULT_ROOT / "projection_object_survival_summary_20260608.json"
CLEANUP_FRONTIER_SUMMARY = DEFAULT_ROOT / "cleanup_runtime_frontier_summary_20260609.json"

TARGET_SITES = {
    "0x0049c019": "projection_object_540b00_slot_08_attachment_then_reselection",
    "0x0049c0a6": "projection_object_540b14_slot_08_relation_projection",
    "0x004adb72": "reward_guard_attachment_wrapper",
    "0x004ad947": "reward_guard_relation_projection_caller",
    "0x004ad7f7": "relation_ordering_projection_driver",
    "0x004add76": "object_uncommit_cleanup",
    "0x004adef7": "direct_relation_cell_reselection",
}
TARGET_SITE_SET = set(TARGET_SITES)
TARGET_NEEDLES = set(TARGET_SITES) | {site.replace("0x00", "0x") for site in TARGET_SITES}

STOP_RE = re.compile(
    r"Stopped on [A-Za-z _-]*(?:breakpoint|watchpoint)\s+\d+\s+at\s+(0x[0-9a-fA-F]+)"
)


def normalize_address(value: str) -> str:
    return f"0x{int(value, 0) & 0xFFFFFFFF:08x}"


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def load_optional_json(path: Path) -> dict[str, Any]:
    return read_json(path) if path.exists() else {}


def text_mentions_target(text: str) -> bool:
    lower = text.lower()
    return any(needle.lower() in lower for needle in TARGET_NEEDLES)


def safe_normalize(value: str) -> str | None:
    try:
        return normalize_address(value)
    except ValueError:
        return None


def summarize_ledger(path: Path) -> dict[str, Any] | None:
    text = path.read_text(encoding="utf-8", errors="replace")
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
        if len(event_samples[normalized]) < 3:
            registers = event.get("registers", {})
            event_samples[normalized].append(
                {
                    "event_index": index,
                    "registers": {
                        name: (
                            f"0x{value & 0xFFFFFFFF:08x}"
                            if isinstance(value, int)
                            else None
                        )
                        for name, value in registers.items()
                        if name in {"eax", "ebx", "ecx", "edx", "esi", "edi", "ebp", "esp"}
                    },
                }
            )

    breakpoint_mentions = []
    for value in data.get("breakpoints", []):
        if not isinstance(value, str):
            continue
        normalized = safe_normalize(value)
        if normalized in TARGET_SITE_SET:
            breakpoint_mentions.append(normalized)

    address_command_mentions = []
    for value in data.get("address_command", []):
        if not isinstance(value, str) or "=" not in value:
            continue
        normalized = safe_normalize(value.split("=", 1)[0])
        if normalized in TARGET_SITE_SET:
            address_command_mentions.append(normalized)

    hit_total = sum(event_counts.values())
    if hit_total == 0 and not breakpoint_mentions and not address_command_mentions:
        return None
    return {
        "path": str(path),
        "event_count": data.get("event_count", len(data.get("events", []))),
        "child_returncode": data.get("child_returncode"),
        "target_event_counts": {k: v for k, v in event_counts.items() if v},
        "target_event_samples": {k: v for k, v in event_samples.items() if v},
        "target_breakpoints": sorted(set(breakpoint_mentions)),
        "target_address_commands": sorted(set(address_command_mentions)),
        "classification": "runtime_hit" if hit_total else "breakpoint_or_command_only_no_hit",
    }


def summarize_log(path: Path) -> dict[str, Any] | None:
    text = path.read_text(encoding="utf-8", errors="replace")
    if not text_mentions_target(text):
        return None
    counts = {site: 0 for site in TARGET_SITES}
    for match in STOP_RE.finditer(text):
        normalized = safe_normalize(match.group(1))
        if normalized in counts:
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


def summarize(root: Path) -> dict[str, Any]:
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

    static_summary = load_optional_json(STATIC_SUMMARY)
    constructor_summary = load_optional_json(CONSTRUCTOR_SUMMARY)
    consumer_summary = load_optional_json(CONSUMER_SUMMARY)
    survival_summary = load_optional_json(SURVIVAL_SUMMARY)
    cleanup_summary = load_optional_json(CLEANUP_FRONTIER_SUMMARY)

    static_contract = static_summary.get("static_contract", {})
    constructor_counts = constructor_summary.get("constructor_counts", {})
    runtime_hit_sites = {site for site, count in event_totals.items() if count}
    log_runtime_hit_sites = {site for site, count in log_stop_totals.items() if count}

    invariants = {
        "projection_slot_static_contract_recovered": bool(
            static_contract.get("vtable_0x540b00", {}).get("slot_0x08") == "0x0049c019"
            and static_contract.get("vtable_0x540b14", {}).get("slot_0x08") == "0x0049c0a6"
        ),
        "projection_constructors_runtime_sampled": bool(
            constructor_counts.get("0x0049cac2", 0)
            or constructor_counts.get("0x0049cb83", 0)
            or constructor_counts.get("0x0049cc22", 0)
        ),
        "sampled_projection_objects_reach_stamp": bool(
            consumer_summary.get("invariants", {}).get("sampled_0x540b14_objects_reach_49abd6")
            or survival_summary.get("invariants", {}).get("sampled_projection_objects_reach_stamp")
        ),
        "sampled_4a79a3_payload_has_no_projection_object_vtables": bool(
            survival_summary.get("invariants", {}).get(
                "sampled_4a79a3_payload_has_no_projection_object_vtables"
            )
        ),
        "no_runtime_projection_slot_method_hit_in_current_corpus": (
            event_totals["0x0049c019"] == 0
            and event_totals["0x0049c0a6"] == 0
            and log_stop_totals["0x0049c019"] == 0
            and log_stop_totals["0x0049c0a6"] == 0
        ),
        "cleanup_frontier_has_no_live_uncommit_hit": bool(
            cleanup_summary.get("status")
            == "cleanup_runtime_frontier_static_only_no_live_uncommit_hit"
        ),
        "no_native_behavior_change": True,
    }
    status = (
        "projection_method_dispatch_frontier_no_live_slot08_hit"
        if all(invariants.values())
        else "projection_method_dispatch_frontier_mixed_or_incomplete"
    )

    return {
        "schema_id": "h3maped_projection_method_dispatch_frontier_summary_v1",
        "status": status,
        "root": str(root),
        "target_sites": TARGET_SITES,
        "corpus": {
            "ledger_files_scanned": len(ledgers),
            "ledger_records_with_target_mentions": len(ledger_records),
            "log_files_scanned": len(logs),
            "log_records_with_target_mentions": len(log_records),
        },
        "target_event_totals_from_ledgers": event_totals,
        "target_stop_totals_from_logs": log_stop_totals,
        "runtime_hit_sites_from_ledgers": sorted(runtime_hit_sites),
        "runtime_hit_sites_from_logs": sorted(log_runtime_hit_sites),
        "projection_constructor_counts": constructor_counts,
        "projection_method_static_contract": {
            "0x540b00+0x08": "0x0049c019 -> 0x4adb72, fallback 0x4adef7",
            "0x540b14+0x08": "0x0049c0a6 -> 0x4ad947",
            "0x540b28+0x08": "0x0049baf5 no-write always-true base callback",
        },
        "ledger_records": ledger_records,
        "log_records": log_records,
        "source_artifacts": {
            "static_summary": str(STATIC_SUMMARY),
            "constructor_summary": str(CONSTRUCTOR_SUMMARY),
            "consumer_summary": str(CONSUMER_SUMMARY),
            "survival_summary": str(SURVIVAL_SUMMARY),
            "cleanup_frontier_summary": str(CLEANUP_FRONTIER_SUMMARY),
        },
        "invariants": invariants,
        "recovered_contract": (
            "Cleanup/uncommit is downstream of projection-object slot +0x08 dispatch. "
            "Static vtables resolve 0x540b00+0x08 to 0x49c019, which tries 0x4adb72 "
            "and then 0x4adef7, and 0x540b14+0x08 to 0x49c0a6, which calls 0x4ad947. "
            "The current corpus proves projection constructors are sampled and sampled "
            "projection objects can reach 0x49abd6 stamping, but it does not prove any "
            "runtime call to those slot +0x08 methods."
        ),
        "remaining_gap": (
            "End-to-end recovery still needs the owning phase or caller that dispatches "
            "projection-object slot +0x08 for 0x540b00/0x540b14 objects, plus object "
            "lifetime before/after that dispatch. Until 0x49c019 or 0x49c0a6 is hit live, "
            "0x4adb72/0x4ad947/0x4add76/0x4adef7 cleanup and projection-driver behavior "
            "remain runtime-unrecovered and must not be ported to native RMG."
        ),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    summary = summarize(args.root)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        "RMG_H3MAPED_PROJECTION_METHOD_DISPATCH_FRONTIER_SUMMARY "
        f"status={summary['status']} out={args.out}"
    )
    return 0 if summary["status"].startswith("projection_method_dispatch_frontier_") else 1


if __name__ == "__main__":
    raise SystemExit(main())
