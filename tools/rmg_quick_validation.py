#!/usr/bin/env python3
"""One-pass Python RMG validation and production-gap comparison.

Use this after a native export already exists. It parses owner `.h3m` evidence
and native `.amap` packages directly, then emits both the fast correctness gate
and the broader production-gap audit without starting Godot or reparsing the
same corpus in two separate commands.
"""

from __future__ import annotations

import argparse
import json
import time
from pathlib import Path
from typing import Any

import rmg_fast_validation
import rmg_production_gap_audit


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_REPORT_JSON = ROOT / ".artifacts" / "rmg_quick_validation_report.json"


def validation_args(args: argparse.Namespace) -> argparse.Namespace:
    return argparse.Namespace(
        h3m_dir=args.h3m_dir,
        amap_dir=args.amap_dir,
        density_floor_ratio=args.density_floor_ratio,
        road_floor_ratio=args.road_floor_ratio,
        guard_reward_ratio_floor_ratio=args.guard_reward_ratio_floor_ratio,
        road_largest_share_multiplier=args.road_largest_share_multiplier,
        road_largest_share_absolute_cap=args.road_largest_share_absolute_cap,
        road_component_count_floor_ratio=args.road_component_count_floor_ratio,
        no_density_gate=False,
        no_policy_gate=False,
        no_topology_gate=False,
        closure_shape_gate=True,
        guard_closure_min_owner_open_pair_count=args.guard_closure_min_owner_open_pair_count,
        latest_amap_artifact=not args.no_latest_amap_artifact,
        artifact_root=args.artifact_root,
        require_all_owner_matches=not args.allow_partial_native_batch,
    )


def build_production_report(fast_report: dict[str, Any], args: argparse.Namespace) -> dict[str, Any]:
    comparisons = fast_report.get("matched_comparisons", [])
    diagnostic_cases = rmg_production_gap_audit.diagnostic_case_summaries(
        comparisons if isinstance(comparisons, list) else [],
        args.severe_category_gap_ratio,
    )
    severe_category_case_count = len([case for case in diagnostic_cases if case.get("severe_category_gaps")])
    route_shape_gap_count = len(
        [
            case for case in diagnostic_cases
            if int(case.get("object_route_reachable_pair_delta", 0)) != 0
            or int(case.get("guarded_route_reachable_pair_delta", 0)) != 0
        ]
    )
    terrain_shape_gap_count = len(
        [
            case for case in diagnostic_cases
            if abs(int(case.get("terrain_blocked_tile_count_delta", 0))) > 50
        ]
    )
    timing = rmg_production_gap_audit.latest_full_timing_summary(
        args.artifact_root,
        int(fast_report.get("summary", {}).get("owner_parsed_count", 0)),
    )
    checklist = rmg_production_gap_audit.build_checklist(
        fast_report,
        diagnostic_cases,
        timing,
        severe_category_case_count,
    )
    missing = [item for item in checklist if not bool(item.get("satisfied", False))]
    summary = dict(fast_report.get("summary", {}))
    summary.update(
        {
            "fast_validation_status": fast_report.get("status", ""),
            "diagnostic_failure_count": len([case for case in diagnostic_cases if str(case.get("status", "")) != "pass"]),
            "road_component_size_mismatch_count": len([case for case in diagnostic_cases if not bool(case.get("road_component_sizes_match", False))]),
            "severe_category_gap_case_count": severe_category_case_count,
            "route_shape_gap_case_count": route_shape_gap_count,
            "terrain_shape_gap_case_count": terrain_shape_gap_count,
            "missing_requirement_count": len(missing),
        }
    )
    return {
        "schema_id": "rmg_quick_production_gap_audit_v1",
        "status": "pass" if int(summary.get("parse_failure_count", 0)) == 0 else "fail",
        "production_ready": len(missing) == 0,
        "summary": summary,
        "checklist": checklist,
        "missing_requirements": missing,
        "top_gap_cases": diagnostic_cases[: max(0, args.gap_limit)],
        "timing": timing,
    }


def write_report(path: Path, report: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--h3m-dir", "--owner-dir", dest="h3m_dir", type=Path, default=rmg_fast_validation.DEFAULT_OWNER_DIR)
    parser.add_argument("--amap-dir", "--native-dir", dest="amap_dir", type=Path, default=rmg_fast_validation.DEFAULT_NATIVE_DIR)
    parser.add_argument("--artifact-root", type=Path, default=rmg_fast_validation.DEFAULT_ARTIFACT_ROOT)
    parser.add_argument("--no-latest-amap-artifact", action="store_true", help="Use --amap-dir exactly instead of selecting the newest native batch export artifact")
    parser.add_argument("--density-floor-ratio", type=float, default=rmg_fast_validation.DEFAULT_DENSITY_FLOOR_RATIO)
    parser.add_argument("--road-floor-ratio", type=float, default=rmg_fast_validation.DEFAULT_ROAD_FLOOR_RATIO)
    parser.add_argument("--guard-reward-ratio-floor-ratio", type=float, default=rmg_fast_validation.DEFAULT_GUARD_REWARD_RATIO_FLOOR_RATIO)
    parser.add_argument("--road-largest-share-multiplier", type=float, default=rmg_fast_validation.DEFAULT_ROAD_LARGEST_SHARE_MULTIPLIER)
    parser.add_argument("--road-largest-share-absolute-cap", type=float, default=rmg_fast_validation.DEFAULT_ROAD_LARGEST_SHARE_ABSOLUTE_CAP)
    parser.add_argument("--road-component-count-floor-ratio", type=float, default=rmg_fast_validation.DEFAULT_ROAD_COMPONENT_COUNT_FLOOR_RATIO)
    parser.add_argument("--guard-closure-min-owner-open-pair-count", type=int, default=rmg_fast_validation.DEFAULT_GUARD_CLOSURE_MIN_OWNER_OPEN_PAIR_COUNT)
    parser.add_argument("--severe-category-gap-ratio", type=float, default=0.20)
    parser.add_argument("--allow-partial-native-batch", action="store_true", help="Allow targeted native AMAP batches that do not cover every parsed owner H3M")
    parser.add_argument("--report-json", type=Path, default=DEFAULT_REPORT_JSON)
    parser.add_argument("--summary", action="store_true", help="Print compact summaries instead of JSON")
    parser.add_argument("--failure-limit", type=int, default=8)
    parser.add_argument("--gap-limit", type=int, default=8)
    parser.add_argument("--allow-failures", action="store_true", help="Return success while still reporting validation failures")
    args = parser.parse_args()

    started = time.perf_counter()
    fast_report = rmg_fast_validation.build_report(validation_args(args))
    production_report = build_production_report(fast_report, args)
    elapsed_seconds = round(time.perf_counter() - started, 3)
    status = "pass" if fast_report.get("status") == "pass" and production_report.get("status") == "pass" else "fail"
    report = {
        "schema_id": "rmg_quick_validation_v1",
        "status": status,
        "production_ready": bool(production_report.get("production_ready", False)),
        "elapsed_seconds": elapsed_seconds,
        "fast_validation": fast_report,
        "production_gap_audit": production_report,
    }
    write_report(args.report_json, report)

    if args.summary:
        print("RMG_QUICK_VALIDATION status=%s production_ready=%s elapsed_seconds=%.3f" % (status, str(report["production_ready"]).lower(), elapsed_seconds))
        print("report_json=%s" % args.report_json)
        print(rmg_fast_validation.compact_summary(fast_report, args.failure_limit))
        print(rmg_production_gap_audit.compact_summary(production_report, args.gap_limit))
    else:
        print(json.dumps(report, indent=2, sort_keys=True))

    if status == "pass" or args.allow_failures:
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
