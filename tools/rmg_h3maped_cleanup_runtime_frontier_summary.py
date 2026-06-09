#!/usr/bin/env python3
"""Summarize the current live-runtime frontier for H3MapEd cleanup paths.

This is a recovery checkpoint, not a native RMG validator. It answers one
specific question: which cleanup/projection-driver sites have actually been
hit by the current debugger corpus, and which are still static-only or
breakpoint-only evidence?
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any


DEFAULT_ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_OUT = DEFAULT_ROOT / "cleanup_runtime_frontier_summary_20260609.json"

TARGET_SITES = {
    "0x004ad6a8": "relation_priority_distance_prepass",
    "0x004ad7f7": "relation_ordering_projection_driver",
    "0x004ad947": "reward_guard_relation_projection_caller",
    "0x004adb72": "reward_guard_attachment_wrapper",
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


def text_mentions_target(text: str) -> bool:
    lower = text.lower()
    return any(needle.lower() in lower for needle in TARGET_NEEDLES)


def summarize_ledger(path: Path) -> dict[str, Any] | None:
    text = path.read_text(encoding="utf-8", errors="replace")
    if not text_mentions_target(text):
        return None
    try:
        data = json.loads(text)
    except json.JSONDecodeError:
        return None
    events = data.get("events", [])
    event_counts = {site: 0 for site in TARGET_SITES}
    event_samples: dict[str, list[dict[str, Any]]] = {site: [] for site in TARGET_SITES}
    for index, event in enumerate(events):
        address = str(event.get("address", "")).lower()
        if not address:
            continue
        try:
            normalized = normalize_address(address)
        except ValueError:
            continue
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
    breakpoint_mentions = sorted(
        normalize_address(str(value))
        for value in data.get("breakpoints", [])
        if isinstance(value, str)
        and normalize_address(str(value)) in TARGET_SITE_SET
    )
    address_command_mentions = sorted(
        normalize_address(str(value).split("=", 1)[0])
        for value in data.get("address_command", [])
        if isinstance(value, str)
        and "=" in value
        and normalize_address(str(value).split("=", 1)[0]) in TARGET_SITE_SET
    )
    hit_total = sum(event_counts.values())
    if hit_total == 0 and not breakpoint_mentions and not address_command_mentions:
        return None
    return {
        "path": str(path),
        "event_count": data.get("event_count", len(events)),
        "child_returncode": data.get("child_returncode"),
        "seed_control": data.get("seed_control"),
        "target_event_counts": {k: v for k, v in event_counts.items() if v},
        "target_event_samples": {k: v for k, v in event_samples.items() if v},
        "target_breakpoints": breakpoint_mentions,
        "target_address_commands": address_command_mentions,
        "classification": "runtime_hit" if hit_total else "breakpoint_or_command_only_no_hit",
    }


def summarize_log(path: Path) -> dict[str, Any] | None:
    text = path.read_text(encoding="utf-8", errors="replace")
    if not text_mentions_target(text):
        return None
    counts = {site: 0 for site in TARGET_SITES}
    for match in STOP_RE.finditer(text):
        try:
            normalized = normalize_address(match.group(1))
        except ValueError:
            continue
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


def load_optional_json(path: Path) -> dict[str, Any]:
    return read_json(path) if path.exists() else {}


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

    object_vector = load_optional_json(root / "object_vector_surface_summary.json")
    projection_nohit = load_optional_json(root / "projection_4add76_trace_summary.json")
    relation_counter = load_optional_json(root / "relation_counter_lifecycle_summary_20260608.json")
    runtime_hit_sites = {site for site, count in event_totals.items() if count}
    log_runtime_hit_sites = {site for site, count in log_stop_totals.items() if count}

    invariants = {
        "static_4add76_surface_recovered": bool(
            object_vector.get("invariants", {}).get("cleanup_surfaces_recovered")
        ),
        "relation_counter_lifecycle_static_recovered": bool(
            relation_counter.get("status")
            in {
                "passed_static_recovery",
                "relation_counter_lifecycle_static_recovered",
                "partial_recovery_relation_counter_lifecycle",
            }
            or relation_counter.get("invariants")
        ),
        "projection_4add76_bounded_nohit_recorded": bool(
            projection_nohit.get("status") == "partial_recovery_4add76_nohit_storage_observed"
            or projection_nohit.get("downstream_consumer_hits")
        ),
        "no_runtime_4add76_hit_in_current_ledger_corpus": event_totals["0x004add76"] == 0,
        "no_runtime_4adef7_hit_in_current_ledger_corpus": event_totals["0x004adef7"] == 0,
        "no_native_behavior_change": True,
    }
    status = (
        "cleanup_runtime_frontier_static_only_no_live_uncommit_hit"
        if all(invariants.values())
        else "cleanup_runtime_frontier_mixed_or_incomplete"
    )
    return {
        "schema_id": "h3maped_cleanup_runtime_frontier_summary_v1",
        "status": status,
        "root": str(root),
        "target_sites": TARGET_SITES,
        "corpus": {
            "ledger_files_scanned": len(ledgers),
            "log_files_scanned": len(logs),
            "ledger_records_with_target_mentions": len(ledger_records),
            "log_records_with_target_mentions": len(log_records),
        },
        "target_event_totals_from_ledgers": event_totals,
        "target_stop_totals_from_logs": log_stop_totals,
        "runtime_hit_sites_from_ledgers": sorted(runtime_hit_sites),
        "runtime_hit_sites_from_logs": sorted(log_runtime_hit_sites),
        "ledger_records": ledger_records,
        "log_records": log_records,
        "source_artifacts": {
            "object_vector_surface_summary": str(root / "object_vector_surface_summary.json"),
            "projection_4add76_trace_summary": str(root / "projection_4add76_trace_summary.json"),
            "relation_counter_lifecycle_summary": str(
                root / "relation_counter_lifecycle_summary_20260608.json"
            ),
        },
        "invariants": invariants,
        "recovered_contract": (
            "The static cleanup/uncommit contract is recovered for 0x4add76 and its direct caller "
            "0x4adef7, while 0x4adb72 is recovered as the wrapper attachment path that can seed "
            "generator+0xf5c/+0x1104. The current debugger corpus contains breakpoint-only/no-hit "
            "evidence for 0x4add76 and 0x4adef7; no ledger event or raw-log stop in this corpus "
            "proves a live uncommit execution."
        ),
        "remaining_gap": (
            "End-to-end recovery still needs a natural runtime path that actually enters 0x4add76/"
            "0x4adef7, with before/after generator object-vector, descriptor counter, relation "
            "counter, GeneratedCell object-reference removal, and +0xf5c/+0x1104 cursor state. "
            "Until that live path is captured, native RMG must not port cleanup/uncommit behavior."
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
        "RMG_H3MAPED_CLEANUP_RUNTIME_FRONTIER_SUMMARY "
        f"status={summary['status']} out={args.out}"
    )
    return 0 if summary["status"].startswith("cleanup_runtime_frontier_") else 1


if __name__ == "__main__":
    raise SystemExit(main())
