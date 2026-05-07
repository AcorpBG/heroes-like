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

import rmg_export_timing_summary
import rmg_fast_validation


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_REPORT_JSON = ROOT / ".artifacts" / "rmg_python_validation_gate_report.json"
PYTHON_GATE_MODULES = [
    ROOT / "tools" / "rmg_fast_audit.py",
    ROOT / "tools" / "rmg_fast_validation.py",
    ROOT / "tools" / "rmg_export_timing_summary.py",
    ROOT / "tools" / "rmg_production_gap_audit.py",
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
        closure_shape_gate=not args.no_closure_shape_gate,
        guard_closure_min_owner_open_pair_count=args.guard_closure_min_owner_open_pair_count,
        latest_amap_artifact=not args.no_latest_amap_artifact,
        artifact_root=args.artifact_root,
        require_all_owner_matches=not args.allow_partial_native_batch,
    )


def write_report(path: Path, report: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")


def build_timing_summary(manifest_path: Path, limit: int, status: str = "pass") -> dict[str, Any]:
    try:
        manifest = rmg_export_timing_summary.load_manifest(manifest_path)
        summary = rmg_export_timing_summary.build_summary(manifest, limit)
    except Exception as exc:
        return {
            "enabled": True,
            "status": "fail",
            "manifest_path": str(manifest_path),
            "error": str(exc),
        }
    return {
        "enabled": True,
        "status": status if str(summary.get("status", "unknown")) == "pass" else str(summary.get("status", "unknown")),
        "manifest_path": str(manifest_path),
        "summary": summary,
    }


def timing_summary_for_validation(report: dict[str, Any], limit: int, enabled: bool) -> dict[str, Any]:
    if not enabled:
        return {"enabled": False, "status": "skipped"}
    inputs = report.get("inputs", {})
    native_dir = Path(str(inputs.get("amap_dir", "")))
    artifact_root = Path(str(inputs.get("artifact_root", DEFAULT_REPORT_JSON.parents[1] / ".artifacts")))
    manifest_path = native_dir / "manifest.json"
    if not native_dir or not manifest_path.exists():
        fallback_dir = rmg_export_timing_summary.latest_manifest_export_dir(artifact_root)
        if fallback_dir is not None:
            fallback_manifest = fallback_dir / "manifest.json"
            timing = build_timing_summary(fallback_manifest, limit, "fallback")
            timing["validated_amap_dir"] = str(native_dir)
            timing["reason"] = "selected_native_amap_dir_has_no_manifest"
            return timing
        return {
            "enabled": True,
            "status": "missing",
            "manifest_path": str(manifest_path),
            "reason": "native_amap_manifest_not_found",
        }
    return build_timing_summary(manifest_path, limit)


def timing_summary_lines(timing: dict[str, Any]) -> list[str]:
    if not timing.get("enabled", False):
        return ["timing_summary=skipped"]
    if timing.get("status") == "missing":
        return ["timing_summary=missing manifest=%s" % timing.get("manifest_path", "")]
    if timing.get("status") == "fail":
        return [
            "timing_summary=fail manifest=%s error=%s"
            % (timing.get("manifest_path", ""), timing.get("error", ""))
        ]
    summary = timing.get("summary", {})
    totals = summary.get("phase_wall_msec_totals", {}) if isinstance(summary, dict) else {}
    lines = [
        "timing_summary=%s manifest=%s" % (timing.get("status", "unknown"), timing.get("manifest_path", "")),
        "timing cases=%s exported=%s failed=%s total_wall_msec=%s"
        % (
            summary.get("case_count", 0),
            summary.get("exported_count", 0),
            summary.get("failed_count", 0),
            summary.get("total_wall_msec", 0),
        ),
        "timing_phase_totals generation=%sms conversion=%sms save=%sms"
        % (totals.get("generation", 0), totals.get("conversion", 0), totals.get("save", 0)),
    ]
    top_cases = summary.get("top_cases", []) if isinstance(summary, dict) else []
    if top_cases:
        lines.append("timing_top_cases:")
        for case in top_cases:
            lines.append(
                "  {id} case={case_wall_msec}ms gen={generation_wall_msec}ms conv={conversion_wall_msec}ms save={save_wall_msec}ms ext={extension_top} conv_top={conversion_top} obj={object_top} town_guard={town_guard_top}".format(
                    **case
                )
            )
    if timing.get("status") == "fallback":
        lines.append(
            "timing_note=validated_amap_dir_has_no_manifest validated_amap_dir=%s"
            % timing.get("validated_amap_dir", "")
        )
    return lines


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
    parser.add_argument("--no-closure-shape-gate", action="store_true", help="Disable the default guard-mediated town-route closure shape gate for targeted diagnostics")
    parser.add_argument("--guard-closure-min-owner-open-pair-count", type=int, default=rmg_fast_validation.DEFAULT_GUARD_CLOSURE_MIN_OWNER_OPEN_PAIR_COUNT)
    parser.add_argument("--allow-partial-native-batch", action="store_true", help="Allow targeted native AMAP batches that do not cover every parsed owner H3M")
    parser.add_argument("--skip-py-compile", action="store_true", help="Skip parser/gate syntax compilation")
    parser.add_argument("--skip-timing-summary", action="store_true", help="Do not summarize the native batch export manifest")
    parser.add_argument("--require-timing-summary", action="store_true", help="Fail if no readable native export timing summary can be found")
    parser.add_argument("--timing-limit", type=int, default=6, help="Number of slowest cases to include from the export timing manifest")
    parser.add_argument("--report-json", type=Path, default=DEFAULT_REPORT_JSON, help="Write full JSON report here")
    parser.add_argument("--failure-limit", type=int, default=8)
    parser.add_argument("--allow-failures", action="store_true", help="Return success while still reporting failures")
    args = parser.parse_args()

    compile_results = [] if args.skip_py_compile else compile_gate_modules()
    compile_ok = all(result.get("status") == "pass" for result in compile_results)
    report = rmg_fast_validation.build_report(validation_args(args))
    timing = timing_summary_for_validation(report, args.timing_limit, not args.skip_timing_summary)
    timing_required_ok = not args.require_timing_summary or timing.get("status") in {"pass", "fallback"}
    timing_ok = timing.get("status") != "fail" and timing_required_ok
    combined = {
        "schema_id": "rmg_python_validation_gate_v1",
        "status": "pass" if compile_ok and report.get("status") == "pass" and timing_ok else "fail",
        "compile": {
            "enabled": not args.skip_py_compile,
            "status": "pass" if compile_ok else "fail",
            "modules": compile_results,
        },
        "fast_validation": report,
        "timing": timing,
    }
    write_report(args.report_json, combined)

    print("RMG_PYTHON_VALIDATION_GATE status=%s" % combined["status"])
    print("checks python_compile=%s fast_validation=%s" % (combined["compile"]["status"], report.get("status", "unknown")))
    print("report_json=%s" % args.report_json)
    print(rmg_fast_validation.compact_summary(report, args.failure_limit))
    for line in timing_summary_lines(timing):
        print(line)

    if combined["status"] == "pass" or args.allow_failures:
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
