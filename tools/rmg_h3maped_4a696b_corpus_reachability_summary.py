#!/usr/bin/env python3
"""Summarize corpus-wide ``0x4a696b`` direct-mutation reachability evidence.

This is a report-only recovery checkpoint. It scans the existing WineDbg JSON
ledgers and raw logs for the static ``0x4a696b`` branch sites, then cross-checks
Ghidra reference text for the recovered direct call sites. It does not claim a
global unreachable proof and does not change native RMG behavior.
"""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path
from typing import Any

from rmg_h3maped_recovery_trace import parse_winedbg_log


DEFAULT_ARTIFACT_ROOT = Path(".artifacts/rmg_recovery")
DEFAULT_OUT = Path(".artifacts/rmg_recovery/4a696b_corpus_reachability_summary_20260609.json")

SITES = {
    "entry": "0x004a696b",
    "same_level_pass": "0x004a69c2",
    "source_relation_match": "0x004a6a81",
    "terrain_reject_checkpoint": "0x004a6a8f",
    "helper_49aa93_return_test": "0x004a6ac8",
    "helper_4a6795_return_test": "0x004a6ade",
    "candidate_append": "0x004a6ae2",
    "scan_done": "0x004a6b10",
    "no_candidate_exit": "0x004a6b27",
    "candidate_path": "0x004a6b2e",
    "vtable_commit": "0x004a6b9b",
    "direct_mutation_test": "0x004a6c13",
    "direct_mutation_after": "0x004a6c2c",
    "false_return_prep": "0x004a6cd3",
    "return": "0x004a6ce1",
}

DEEP_SITES = {
    "source_relation_match",
    "helper_49aa93_return_test",
    "helper_4a6795_return_test",
    "candidate_append",
    "candidate_path",
    "vtable_commit",
    "direct_mutation_test",
    "direct_mutation_after",
}

CALL_REF_RE = re.compile(
    r"(?:at|from)=(?P<site>[0-9a-fA-F]{8}).*?(?:to=004a696b|instruction=CALL 0x004a696b)"
)


def event_address(event: dict[str, Any]) -> str:
    return str(event.get("address", "")).lower()


def read_json(path: Path) -> dict[str, Any] | None:
    try:
        data = json.loads(path.read_text(encoding="utf-8", errors="replace"))
    except Exception:
        return None
    return data if isinstance(data, dict) else None


def address_counts(events: list[dict[str, Any]]) -> Counter[str]:
    return Counter(event_address(event) for event in events if isinstance(event, dict))


def site_counts(counts: Counter[str]) -> dict[str, int]:
    return {name: counts.get(address, 0) for name, address in SITES.items()}


def has_any_site(counts_by_name: dict[str, int]) -> bool:
    return any(counts_by_name.values())


def has_deep_site(counts_by_name: dict[str, int]) -> bool:
    return any(counts_by_name.get(name, 0) for name in DEEP_SITES)


def summarize_ledgers(root: Path) -> tuple[list[dict[str, Any]], Counter[str], list[dict[str, Any]]]:
    records: list[dict[str, Any]] = []
    deep_records: list[dict[str, Any]] = []
    aggregate: Counter[str] = Counter()
    for path in sorted(root.rglob("*ledger.json")):
        data = read_json(path)
        if not data:
            continue
        events = data.get("events", [])
        if not isinstance(events, list):
            continue
        counts = site_counts(address_counts(events))
        if not has_any_site(counts):
            continue
        record = {
            "path": str(path),
            "event_count": data.get("event_count", len(events)),
            "site_counts": counts,
            "has_deep_site": has_deep_site(counts),
        }
        records.append(record)
        aggregate.update(counts)
        if record["has_deep_site"]:
            deep_records.append(record)
    return records, aggregate, deep_records


def summarize_raw_logs(root: Path) -> tuple[list[dict[str, Any]], Counter[str], list[dict[str, Any]]]:
    records: list[dict[str, Any]] = []
    deep_records: list[dict[str, Any]] = []
    aggregate: Counter[str] = Counter()
    for path in sorted(root.rglob("*.log")):
        ledger = parse_winedbg_log(path)
        events = ledger.get("events", [])
        counts = site_counts(address_counts(events))
        if not has_any_site(counts):
            continue
        record = {
            "path": str(path),
            "event_count": ledger.get("event_count", len(events)),
            "site_counts": counts,
            "has_deep_site": has_deep_site(counts),
        }
        records.append(record)
        aggregate.update(counts)
        if record["has_deep_site"]:
            deep_records.append(record)
    return records, aggregate, deep_records


def static_call_refs(root: Path) -> dict[str, Any]:
    refs: Counter[str] = Counter()
    files: list[str] = []
    for path in sorted(root.glob("ghidra*/**/*.txt")):
        text = path.read_text(encoding="utf-8", errors="replace")
        matches = CALL_REF_RE.findall(text)
        if not matches:
            continue
        files.append(str(path))
        refs.update(site.lower() for site in matches)
    return {
        "files_with_refs": files,
        "direct_call_sites": dict(sorted(refs.items())),
    }


def compact_records(records: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [
        {
            "path": record["path"],
            "site_counts": {key: value for key, value in record["site_counts"].items() if value},
            "event_count": record["event_count"],
        }
        for record in records
    ]


def summarize(args: argparse.Namespace) -> dict[str, Any]:
    ledger_records, ledger_aggregate, ledger_deep = summarize_ledgers(args.artifact_root)
    raw_records, raw_aggregate, raw_deep = summarize_raw_logs(args.artifact_root)
    static_refs = static_call_refs(args.artifact_root)
    combined = Counter()
    combined.update(ledger_aggregate)
    combined.update(raw_aggregate)

    direct_call_sites = set(static_refs["direct_call_sites"])
    expected_call_sites = {"004a7c04", "004a7dfa"}
    invariants = {
        "native_behavior_changed": False,
        "ledger_corpus_has_4a696b_entries": ledger_aggregate.get("entry", 0) > 0,
        "raw_log_corpus_has_4a696b_entries": raw_aggregate.get("entry", 0) > 0,
        "no_ledger_source_relation_or_deeper_hits": not ledger_deep,
        "no_raw_log_source_relation_or_deeper_hits": not raw_deep,
        "no_combined_source_relation_match_hits": combined.get("source_relation_match", 0) == 0,
        "no_combined_candidate_append_hits": combined.get("candidate_append", 0) == 0,
        "no_combined_candidate_path_hits": combined.get("candidate_path", 0) == 0,
        "no_combined_direct_mutation_hits": combined.get("direct_mutation_test", 0) == 0
        and combined.get("direct_mutation_after", 0) == 0,
        "static_direct_call_refs_only_from_4a79a3_sites": direct_call_sites
        and direct_call_sites <= expected_call_sites,
    }
    status = (
        "4a696b_corpus_no_source_match_or_direct_mutation_hits"
        if all(value for key, value in invariants.items() if key != "native_behavior_changed")
        else "4a696b_corpus_reachability_partial"
    )
    return {
        "schema_id": "h3maped_4a696b_corpus_reachability_summary_v1",
        "status": status,
        "native_behavior_changed": False,
        "inputs": {"artifact_root": str(args.artifact_root)},
        "metrics": {
            "ledger_files_with_4a696b_sites": len(ledger_records),
            "raw_logs_with_4a696b_sites": len(raw_records),
            "ledger_4a696b_entries": ledger_aggregate.get("entry", 0),
            "raw_log_4a696b_entries": raw_aggregate.get("entry", 0),
            "combined_4a696b_entries": combined.get("entry", 0),
            "combined_source_relation_match_hits": combined.get("source_relation_match", 0),
            "combined_candidate_append_hits": combined.get("candidate_append", 0),
            "combined_candidate_path_hits": combined.get("candidate_path", 0),
            "combined_direct_mutation_hits": combined.get("direct_mutation_test", 0)
            + combined.get("direct_mutation_after", 0),
        },
        "aggregate_site_counts": {
            "ledgers": dict(sorted(ledger_aggregate.items())),
            "raw_logs": dict(sorted(raw_aggregate.items())),
            "combined": dict(sorted(combined.items())),
        },
        "static_call_refs": static_refs,
        "ledger_records": compact_records(ledger_records),
        "raw_log_records": compact_records(raw_records),
        "deep_hit_records": {
            "ledgers": compact_records(ledger_deep),
            "raw_logs": compact_records(raw_deep),
        },
        "invariants": invariants,
        "source_backed_conclusion": (
            "The current recovery corpus contains 0x4a696b execution evidence, but no ledger or "
            "raw-log event reaches the source/relation-match checkpoint at 0x4a6a81, the candidate "
            "append/path, or the direct GeneratedCell+0x28 mutation block. Static Ghidra references "
            "found in the corpus place direct 0x4a696b calls at 0x4a79a3 call sites 0x4a7c04 and "
            "0x4a7dfa."
        ),
        "remaining_gap": (
            "This is corpus-wide negative evidence, not a global unreachability proof. End-to-end "
            "recovery still needs either a natural 0x4a696b sample that reaches 0x4a6a81 and then "
            "the candidate/direct-mutation path, or a stronger static/data proof that the required "
            "GeneratedCell+0x20 source/relation byte pair cannot occur in the target one-level land "
            "mode. Live 0x4add76/0x4adef7 cleanup/uncommit behavior remains unrecovered unless a "
            "natural path enters it."
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifact-root", type=Path, default=DEFAULT_ARTIFACT_ROOT)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    summary = summarize(args)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"RMG_H3MAPED_4A696B_CORPUS_REACHABILITY_SUMMARY status={summary['status']} out={args.out}")
    return 0 if summary["status"].endswith("_no_source_match_or_direct_mutation_hits") else 1


if __name__ == "__main__":
    raise SystemExit(main())
