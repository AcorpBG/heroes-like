#!/usr/bin/env python3
"""Summarize overworld interaction profile JSONL logs."""
from __future__ import annotations

import argparse
import json
from collections import defaultdict
from pathlib import Path
from statistics import mean


def load_records(path: Path) -> list[dict]:
    records: list[dict] = []
    with path.open("r", encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, 1):
            line = line.strip()
            if not line:
                continue
            try:
                value = json.loads(line)
            except json.JSONDecodeError as exc:
                raise SystemExit(f"{path}:{line_number}: invalid JSON: {exc}") from exc
            if isinstance(value, dict):
                records.append(value)
    return records


def offender_name(offender: object) -> str:
    if isinstance(offender, dict):
        return str(offender.get("name", "unknown"))
    return "unknown"


def offender_ms(offender: object) -> float:
    if isinstance(offender, dict):
        try:
            return float(offender.get("ms", 0.0))
        except (TypeError, ValueError):
            return 0.0
    return 0.0


def summarize(records: list[dict], slowest_limit: int, offender_limit: int) -> None:
    by_command: dict[str, list[float]] = defaultdict(list)
    offender_totals: dict[str, float] = defaultdict(float)
    offender_counts: dict[str, int] = defaultdict(int)

    for record in records:
        command = str(record.get("command_type", "unknown"))
        by_command[command].append(float(record.get("total_command_ms", 0.0) or 0.0))
        offenders = record.get("top_offenders", [])
        if isinstance(offenders, list):
            for offender in offenders:
                name = offender_name(offender)
                ms = offender_ms(offender)
                offender_totals[name] += ms
                offender_counts[name] += 1

    print(f"records: {len(records)}")
    print("by_command:")
    for command, values in sorted(by_command.items()):
        values_sorted = sorted(values)
        p95_index = min(len(values_sorted) - 1, int(round((len(values_sorted) - 1) * 0.95)))
        print(
            f"  {command}: count={len(values)} "
            f"avg_ms={mean(values):.3f} max_ms={max(values):.3f} p95_ms={values_sorted[p95_index]:.3f}"
        )

    print("top_offenders:")
    ranked_offenders = sorted(offender_totals.items(), key=lambda item: item[1], reverse=True)
    for name, total_ms in ranked_offenders[:offender_limit]:
        print(f"  {name}: total_ms={total_ms:.3f} samples={offender_counts[name]}")

    print("slowest_records:")
    slowest = sorted(records, key=lambda record: float(record.get("total_command_ms", 0.0) or 0.0), reverse=True)
    for record in slowest[:slowest_limit]:
        session = record.get("session", {}) if isinstance(record.get("session", {}), dict) else {}
        target = record.get("selected_target", {}) if isinstance(record.get("selected_target", {}), dict) else {}
        route_bfs = record.get("route_bfs", {}) if isinstance(record.get("route_bfs", {}), dict) else {}
        route_cache = record.get("route_cache", {}) if isinstance(record.get("route_cache", {}), dict) else {}
        print(
            "  "
            f"{record.get('timestamp_utc', '')} command={record.get('command_type', 'unknown')} "
            f"total_ms={float(record.get('total_command_ms', 0.0) or 0.0):.3f} "
            f"scenario={session.get('scenario_id', '')} map={session.get('map_size', {})} "
            f"target={target} bfs_status={route_bfs.get('status', '')} "
            f"bfs_calls={route_bfs.get('calls', 0)} cache_h={route_cache.get('hits', 0)} "
            f"cache_m={route_cache.get('misses', 0)} top={record.get('top_offenders', [])[:3]}"
        )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log", type=Path, help="Path to overworld_profile.jsonl")
    parser.add_argument("--slowest", type=int, default=10, help="Number of slowest records to print.")
    parser.add_argument("--offenders", type=int, default=12, help="Number of aggregate offender buckets to print.")
    args = parser.parse_args()

    if not args.log.exists():
        raise SystemExit(f"Log not found: {args.log}")
    summarize(load_records(args.log), max(0, args.slowest), max(0, args.offenders))


if __name__ == "__main__":
    main()
