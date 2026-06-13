#!/usr/bin/env python3
"""Python-only RMG correctness gate.

This is the default fast loop for validating generated map packages against the
owner H3M corpus after a native export exists. It deliberately does not start
Godot. Fresh native RMG export tooling must use the standalone no-Godot CLI
boundary; Godot runs are reserved for explicit runtime/editor integration
smokes on hosts where engine launch is permitted.
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
    ROOT / "tools" / "rmg_native_batch_export.py",
    ROOT / "tools" / "rmg_production_gap_audit.py",
    ROOT / "tools" / "rmg_quick_validation.py",
]
NATIVE_FRESHNESS_SOURCE_INPUTS = [
    ROOT / "src" / "gdextension" / "include" / "rmg_native_batch_export_runner.hpp",
    ROOT / "src" / "gdextension" / "src" / "h3maped_small_rmg.cpp",
    ROOT / "src" / "gdextension" / "src" / "h3maped_small_rmg_embedded_data.cpp",
    ROOT / "src" / "gdextension" / "src" / "map_package_service.cpp",
    ROOT / "src" / "gdextension" / "src" / "rmg_native_batch_export_cli.cpp",
    ROOT / "src" / "gdextension" / "src" / "rmg_native_batch_export_runner.cpp",
    ROOT / "tools" / "rmg_native_batch_export.py",
    ROOT / "tools" / "rmg_native_batch_export_native.tscn",
]
NATIVE_FRESHNESS_LINUX_BINARY_INPUTS = [
    ROOT / "bin" / "rmg_native_batch_export_cli",
    ROOT / "bin" / "libaurelion_map_persistence.linux.template_debug.x86_64.so",
    ROOT / "bin" / "libaurelion_map_persistence.linux.template_release.x86_64.so",
]
NATIVE_FRESHNESS_WINDOWS_BINARY_INPUTS = [
    ROOT / "bin" / "aurelion_map_persistence.windows.template_debug.x86_64.dll",
    ROOT / "bin" / "aurelion_map_persistence.windows.template_release.x86_64.dll",
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


def native_freshness_inputs(include_windows: bool) -> list[Path]:
    inputs = NATIVE_FRESHNESS_SOURCE_INPUTS + NATIVE_FRESHNESS_LINUX_BINARY_INPUTS
    if include_windows:
        inputs += NATIVE_FRESHNESS_WINDOWS_BINARY_INPUTS
    return inputs


def native_export_freshness(report: dict[str, Any], include_windows: bool) -> dict[str, Any]:
    inputs = report.get("inputs", {})
    native_dir = Path(str(inputs.get("amap_dir", "")))
    if not native_dir:
        return {"status": "missing", "reason": "native_amap_dir_missing"}
    if not native_dir.is_absolute():
        native_dir = ROOT / native_dir
    if not native_dir.exists() or not native_dir.is_dir():
        return {"status": "missing", "native_dir": str(native_dir), "reason": "native_amap_dir_not_found"}

    export_files = [path for path in native_dir.glob("*.amap")]
    manifest = native_dir / "manifest.json"
    if manifest.exists():
        export_files.append(manifest)
    if not export_files:
        return {"status": "missing", "native_dir": str(native_dir), "reason": "native_export_files_not_found"}

    expected_inputs = native_freshness_inputs(include_windows)
    existing_inputs = [path for path in expected_inputs if path.exists()]
    if not existing_inputs:
        return {"status": "unknown", "native_dir": str(native_dir), "reason": "native_freshness_inputs_missing"}

    export_mtime = max(path.stat().st_mtime for path in export_files)
    newest_input = max(existing_inputs, key=lambda path: path.stat().st_mtime)
    newest_input_mtime = newest_input.stat().st_mtime
    return {
        "status": "pass" if export_mtime >= newest_input_mtime else "stale",
        "native_dir": str(native_dir.relative_to(ROOT) if native_dir.is_relative_to(ROOT) else native_dir),
        "export_mtime": export_mtime,
        "newest_native_input": str(newest_input.relative_to(ROOT)),
        "newest_native_input_mtime": newest_input_mtime,
        "freshness_policy": (
            "selected native AMAP batch must be newer than native RMG sources and Linux native binaries; "
            "Windows DLL freshness is opt-in after Linux parity is verified"
            if not include_windows
            else "selected native AMAP batch must be newer than native RMG sources plus Linux and Windows native binaries"
        ),
        "windows_native_freshness_included": include_windows,
    }


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


def freshness_summary_line(freshness: dict[str, Any]) -> str:
    return (
        "native_export_freshness=%s native_dir=%s newest_native_input=%s"
        % (
            freshness.get("status", "unknown"),
            freshness.get("native_dir", ""),
            freshness.get("newest_native_input", ""),
        )
    )


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
    parser.add_argument(
        "--include-windows-native-freshness",
        action="store_true",
        help="Include Windows DLL mtimes in native export freshness checks. Keep this off for the RMG parity inner loop; use it only for final cross-platform checkpoints.",
    )
    parser.add_argument("--timing-limit", type=int, default=6, help="Number of slowest cases to include from the export timing manifest")
    parser.add_argument("--report-json", type=Path, default=DEFAULT_REPORT_JSON, help="Write full JSON report here")
    parser.add_argument("--failure-limit", type=int, default=8)
    parser.add_argument("--allow-failures", action="store_true", help="Return success while still reporting failures")
    args = parser.parse_args()

    compile_results = [] if args.skip_py_compile else compile_gate_modules()
    compile_ok = all(result.get("status") == "pass" for result in compile_results)
    report = rmg_fast_validation.build_report(validation_args(args))
    freshness = native_export_freshness(report, args.include_windows_native_freshness)
    timing = timing_summary_for_validation(report, args.timing_limit, not args.skip_timing_summary)
    timing_required_ok = not args.require_timing_summary or timing.get("status") in {"pass", "fallback"}
    timing_ok = timing.get("status") != "fail" and timing_required_ok
    freshness_ok = freshness.get("status") == "pass"
    combined = {
        "schema_id": "rmg_python_validation_gate_v1",
        "status": "pass" if compile_ok and report.get("status") == "pass" and timing_ok and freshness_ok else "fail",
        "compile": {
            "enabled": not args.skip_py_compile,
            "status": "pass" if compile_ok else "fail",
            "modules": compile_results,
        },
        "fast_validation": report,
        "native_export_freshness": freshness,
        "timing": timing,
    }
    write_report(args.report_json, combined)

    print("RMG_PYTHON_VALIDATION_GATE status=%s" % combined["status"])
    print("checks python_compile=%s fast_validation=%s" % (combined["compile"]["status"], report.get("status", "unknown")))
    print("report_json=%s" % args.report_json)
    print(freshness_summary_line(freshness))
    print(rmg_fast_validation.compact_summary(report, args.failure_limit))
    for line in timing_summary_lines(timing):
        print(line)

    if combined["status"] == "pass" or args.allow_failures:
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
