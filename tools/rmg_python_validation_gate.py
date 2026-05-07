#!/usr/bin/env python3
"""Python-only RMG correctness gate.

This is the default fast loop for validating generated map packages against the
owner H3M corpus after a native export exists. It deliberately does not start
Godot; Godot should be reserved for fresh generation/export and runtime/editor
integration smokes.
"""

from __future__ import annotations

import argparse
import json
import py_compile
import sys
from pathlib import Path
from typing import Any

import rmg_fast_validation


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_REPORT_JSON = ROOT / ".artifacts" / "rmg_python_validation_gate_report.json"
PYTHON_GATE_MODULES = [
    ROOT / "tools" / "rmg_fast_audit.py",
    ROOT / "tools" / "rmg_fast_validation.py",
    ROOT / "tools" / "rmg_export_timing_summary.py",
]


def compile_gate_modules() -> list[dict[str, Any]]:
    results: list[dict[str, Any]] = []
    for path in PYTHON_GATE_MODULES:
        record: dict[str, Any] = {"path": str(path.relative_to(ROOT)), "status": "pass"}
        try:
            py_compile.compile(str(path), doraise=True)
        except py_compile.PyCompileError as exc:
            record["status"] = "fail"
            record["error"] = str(exc)
        results.append(record)
    return results


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
        no_density_gate=args.no_density_gate,
        no_policy_gate=args.no_policy_gate,
        no_topology_gate=args.no_topology_gate,
        closure_shape_gate=args.closure_shape_gate,
        guard_closure_min_owner_open_pair_count=args.guard_closure_min_owner_open_pair_count,
        latest_amap_artifact=not args.no_latest_amap_artifact,
        artifact_root=args.artifact_root,
        require_all_owner_matches=not args.allow_partial_native_batch,
    )


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
    parser.add_argument("--no-density-gate", action="store_true")
    parser.add_argument("--no-policy-gate", action="store_true")
    parser.add_argument("--no-topology-gate", action="store_true")
    parser.add_argument("--closure-shape-gate", action="store_true", help="Enable the optional guard-mediated town-route closure shape gate")
    parser.add_argument("--guard-closure-min-owner-open-pair-count", type=int, default=rmg_fast_validation.DEFAULT_GUARD_CLOSURE_MIN_OWNER_OPEN_PAIR_COUNT)
    parser.add_argument("--allow-partial-native-batch", action="store_true", help="Allow targeted native AMAP batches that do not cover every parsed owner H3M")
    parser.add_argument("--skip-py-compile", action="store_true", help="Skip parser/gate syntax compilation")
    parser.add_argument("--report-json", type=Path, default=DEFAULT_REPORT_JSON, help="Write full JSON report here")
    parser.add_argument("--failure-limit", type=int, default=8)
    parser.add_argument("--allow-failures", action="store_true", help="Return success while still reporting failures")
    args = parser.parse_args()

    compile_results = [] if args.skip_py_compile else compile_gate_modules()
    compile_ok = all(result.get("status") == "pass" for result in compile_results)
    report = rmg_fast_validation.build_report(validation_args(args))
    combined = {
        "schema_id": "rmg_python_validation_gate_v1",
        "status": "pass" if compile_ok and report.get("status") == "pass" else "fail",
        "compile": {
            "enabled": not args.skip_py_compile,
            "status": "pass" if compile_ok else "fail",
            "modules": compile_results,
        },
        "fast_validation": report,
    }
    write_report(args.report_json, combined)

    print("RMG_PYTHON_VALIDATION_GATE status=%s" % combined["status"])
    print("checks python_compile=%s fast_validation=%s" % (combined["compile"]["status"], report.get("status", "unknown")))
    print("report_json=%s" % args.report_json)
    print(rmg_fast_validation.compact_summary(report, args.failure_limit))

    if combined["status"] == "pass" or args.allow_failures:
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
