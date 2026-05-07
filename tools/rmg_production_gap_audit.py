#!/usr/bin/env python3
"""Production-readiness gap audit for native RMG without starting Godot.

This is not the tight correctness gate. It consumes the same owner H3M and
native AMAP evidence, then makes the broader production-parity gaps explicit:
where the generalized Python gates pass, where owner diagnostics still differ,
and which cases/subsystems should drive the next implementation slice.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import rmg_export_timing_summary
import rmg_fast_validation


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_REPORT_JSON = ROOT / ".artifacts" / "rmg_production_gap_audit_report.json"


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


def category_gap_summary(comparison: dict[str, Any], ratio: float) -> dict[str, Any]:
    category_delta = comparison.get("category_delta", {})
    severe: list[dict[str, Any]] = []
    absolute_total = 0
    if not isinstance(category_delta, dict):
        return {"absolute_delta_total": 0, "severe_categories": severe}
    for category, record in category_delta.items():
        if not isinstance(record, dict):
            continue
        owner_count = int(record.get("owner_count", 0))
        native_count = int(record.get("native_count", 0))
        delta = int(record.get("delta", native_count - owner_count))
        absolute = abs(delta)
        absolute_total += absolute
        floor = max(3, int(round(owner_count * ratio)))
        if absolute > floor:
            severe.append(
                {
                    "category": category,
                    "owner_count": owner_count,
                    "native_count": native_count,
                    "delta": delta,
                    "severe_gap_floor": floor,
                }
            )
    return {"absolute_delta_total": absolute_total, "severe_categories": severe}


def diagnostic_case_summaries(comparisons: list[dict[str, Any]], category_gap_ratio: float) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for comparison in comparisons:
        deltas = comparison.get("deltas_vs_owner", {})
        category_summary = category_gap_summary(comparison, category_gap_ratio)
        object_delta = int(deltas.get("object_count_delta", 0)) if isinstance(deltas, dict) else 0
        road_delta = int(deltas.get("road_cell_count_delta", 0)) if isinstance(deltas, dict) else 0
        terrain_delta = int(deltas.get("terrain_blocked_tile_count_delta", 0)) if isinstance(deltas, dict) else 0
        object_route_delta = int(deltas.get("object_route_reachable_pair_delta", 0)) if isinstance(deltas, dict) else 0
        guarded_route_delta = int(deltas.get("guarded_route_reachable_pair_delta", 0)) if isinstance(deltas, dict) else 0
        severity = (
            abs(object_delta)
            + abs(road_delta)
            + abs(terrain_delta)
            + abs(object_route_delta) * 25
            + abs(guarded_route_delta) * 25
            + int(category_summary.get("absolute_delta_total", 0))
        )
        result.append(
            {
                "case_id": comparison.get("case_id", ""),
                "status": comparison.get("status", ""),
                "severity_score": severity,
                "object_count_delta": object_delta,
                "road_cell_count_delta": road_delta,
                "terrain_blocked_tile_count_delta": terrain_delta,
                "object_route_reachable_pair_delta": object_route_delta,
                "guarded_route_reachable_pair_delta": guarded_route_delta,
                "road_component_sizes_match": bool(comparison.get("road_component_sizes_match", False)),
                "category_absolute_delta_total": int(category_summary.get("absolute_delta_total", 0)),
                "severe_category_gaps": category_summary.get("severe_categories", []),
            }
        )
    return sorted(result, key=lambda item: int(item["severity_score"]), reverse=True)


def latest_full_timing_summary(artifact_root: Path, minimum_case_count: int) -> dict[str, Any]:
    if not artifact_root.exists():
        return {"status": "missing", "reason": "artifact_root_missing", "artifact_root": str(artifact_root)}
    candidates: list[tuple[float, Path, dict[str, Any]]] = []
    for path in artifact_root.iterdir():
        manifest_path = path / "manifest.json"
        if not path.is_dir() or not path.name.startswith(rmg_fast_validation.NATIVE_EXPORT_DIR_PREFIX) or not manifest_path.exists():
            continue
        try:
            manifest = rmg_export_timing_summary.load_manifest(manifest_path)
            summary = rmg_export_timing_summary.build_summary(manifest, 6)
        except Exception:
            continue
        if int(summary.get("case_count", 0)) >= minimum_case_count:
            candidates.append((manifest_path.stat().st_mtime, manifest_path, summary))
    if not candidates:
        return {
            "status": "missing",
            "reason": "no_manifest_with_required_case_count",
            "minimum_case_count": minimum_case_count,
        }
    _, manifest_path, summary = max(candidates, key=lambda item: item[0])
    return {"status": "pass", "manifest_path": str(manifest_path), "summary": summary}


def checklist_item(item_id: str, satisfied: bool, evidence: dict[str, Any], missing: str = "") -> dict[str, Any]:
    return {
        "id": item_id,
        "satisfied": satisfied,
        "evidence": evidence,
        "missing": missing if not satisfied else "",
    }


def build_checklist(
    fast_report: dict[str, Any],
    diagnostic_cases: list[dict[str, Any]],
    timing: dict[str, Any],
    severe_category_case_count: int,
) -> list[dict[str, Any]]:
    summary = fast_report.get("summary", {})
    inputs = fast_report.get("inputs", {})
    exact_diagnostic_failures = [case for case in diagnostic_cases if str(case.get("status", "")) != "pass"]
    road_shape_mismatches = [case for case in diagnostic_cases if not bool(case.get("road_component_sizes_match", False))]
    town_gap_cases = [
        case for case in diagnostic_cases
        if any(gap.get("category") == "town" for gap in case.get("severe_category_gaps", []))
    ]
    route_shape_gap_cases = [
        case for case in diagnostic_cases
        if int(case.get("object_route_reachable_pair_delta", 0)) != 0
        or int(case.get("guarded_route_reachable_pair_delta", 0)) != 0
    ]
    terrain_shape_gap_cases = [
        case for case in diagnostic_cases
        if abs(int(case.get("terrain_blocked_tile_count_delta", 0))) > 50
    ]
    full_timing_summary = timing.get("summary", {}) if isinstance(timing.get("summary", {}), dict) else {}
    return [
        checklist_item(
            "owner_h3m_corpus_parses",
            int(summary.get("owner_parsed_count", 0)) > 0 and int(summary.get("parse_failure_count", 0)) == 0,
            {
                "owner_parsed_count": summary.get("owner_parsed_count", 0),
                "owner_sample_count": summary.get("owner_sample_count", 0),
                "parse_failure_count": summary.get("parse_failure_count", 0),
                "h3m_dir": inputs.get("h3m_dir", ""),
            },
            "Owner H3M evidence must parse fully before it can support a production audit.",
        ),
        checklist_item(
            "native_amap_full_owner_coverage",
            int(summary.get("coverage_gap_count", 0)) == 0 and int(summary.get("matched_comparison_count", 0)) == int(summary.get("owner_parsed_count", 0)),
            {
                "native_parsed_count": summary.get("native_parsed_count", 0),
                "matched_comparison_count": summary.get("matched_comparison_count", 0),
                "coverage_gap_count": summary.get("coverage_gap_count", 0),
                "amap_dir": inputs.get("amap_dir", ""),
            },
            "Every parsed owner H3M needs a matched native AMAP evidence package.",
        ),
        checklist_item(
            "generalized_python_structural_gates",
            fast_report.get("status") == "pass",
            {
                "status": fast_report.get("status", ""),
                "native_rule_failure_count": summary.get("native_rule_failure_count", 0),
                "density_gap_count": summary.get("density_gap_count", 0),
                "policy_gap_count": summary.get("policy_gap_count", 0),
                "topology_gap_count": summary.get("topology_gap_count", 0),
                "closure_shape_gap_count": summary.get("closure_shape_gap_count", 0),
            },
            "The generalized Python gates must pass before production-readiness gaps are meaningful.",
        ),
        checklist_item(
            "owner_diagnostic_similarity",
            len(exact_diagnostic_failures) == 0,
            {
                "matched_comparison_count": summary.get("matched_comparison_count", 0),
                "diagnostic_failure_count": len(exact_diagnostic_failures),
            },
            "Matched owner/native diagnostics still differ materially; this is not byte/art parity, but it proves current output is not close enough to call production-ready.",
        ),
        checklist_item(
            "road_shape_similarity",
            len(road_shape_mismatches) == 0,
            {
                "road_component_size_mismatch_count": len(road_shape_mismatches),
                "matched_comparison_count": summary.get("matched_comparison_count", 0),
            },
            "Road topology passes the loose generalized gate but still differs in exact component shape across matched owner samples.",
        ),
        checklist_item(
            "terrain_blocker_shape_similarity",
            len(terrain_shape_gap_cases) == 0,
            {
                "terrain_shape_gap_case_count": len(terrain_shape_gap_cases),
                "case_ids": [case.get("case_id", "") for case in terrain_shape_gap_cases],
            },
            "Terrain blocker counts still diverge materially from owner evidence in some matched cases.",
        ),
        checklist_item(
            "town_density_and_distribution_similarity",
            len(town_gap_cases) == 0,
            {
                "severe_town_gap_case_count": len(town_gap_cases),
                "case_ids": [case.get("case_id", "") for case in town_gap_cases],
            },
            "Several matched cases still have severe town-count/distribution gaps versus owner evidence.",
        ),
        checklist_item(
            "object_guard_reward_category_similarity",
            severe_category_case_count == 0,
            {
                "severe_category_gap_case_count": severe_category_case_count,
            },
            "Object, decoration, guard, and reward categories still have large case-level shape gaps despite group floor gates passing.",
        ),
        checklist_item(
            "route_shape_similarity",
            len(route_shape_gap_cases) == 0,
            {
                "route_shape_gap_case_count": len(route_shape_gap_cases),
                "case_ids": [case.get("case_id", "") for case in route_shape_gap_cases],
            },
            "Object-only and guarded town-route pair counts still differ from owner evidence in many matched cases.",
        ),
        checklist_item(
            "full_export_timing_evidence",
            timing.get("status") == "pass",
            {
                "status": timing.get("status", ""),
                "manifest_path": timing.get("manifest_path", ""),
                "case_count": full_timing_summary.get("case_count", 0),
                "total_wall_msec": full_timing_summary.get("total_wall_msec", 0),
                "top_cases": full_timing_summary.get("top_cases", []),
            },
            "A full native export timing manifest is needed to judge production performance for supported sizes.",
        ),
    ]


def write_report(path: Path, report: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")


def compact_summary(report: dict[str, Any], limit: int) -> str:
    summary = report.get("summary", {})
    lines = [
        "RMG_PRODUCTION_GAP_AUDIT status=%s production_ready=%s" % (report.get("status", ""), str(report.get("production_ready", False)).lower()),
        "evidence owner=%s native=%s matched=%s fast_gate=%s"
        % (
            summary.get("owner_parsed_count", 0),
            summary.get("native_parsed_count", 0),
            summary.get("matched_comparison_count", 0),
            summary.get("fast_validation_status", ""),
        ),
        "missing_requirements=%s" % summary.get("missing_requirement_count", 0),
        "diagnostics exact_failures=%s road_shape_mismatches=%s terrain_shape_gap_cases=%s severe_category_gap_cases=%s route_shape_gap_cases=%s"
        % (
            summary.get("diagnostic_failure_count", 0),
            summary.get("road_component_size_mismatch_count", 0),
            summary.get("terrain_shape_gap_case_count", 0),
            summary.get("severe_category_gap_case_count", 0),
            summary.get("route_shape_gap_case_count", 0),
        ),
        "top_gap_cases:",
    ]
    for case in report.get("top_gap_cases", [])[: max(0, limit)]:
        lines.append(
            "  {case_id} severity={severity_score} object_delta={object_count_delta} road_delta={road_cell_count_delta} terrain_delta={terrain_blocked_tile_count_delta} route_delta={object_route_reachable_pair_delta}/{guarded_route_reachable_pair_delta} category_abs_delta={category_absolute_delta_total}".format(
                **case
            )
        )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--h3m-dir", "--owner-dir", dest="h3m_dir", type=Path, default=rmg_fast_validation.DEFAULT_OWNER_DIR)
    parser.add_argument("--amap-dir", "--native-dir", dest="amap_dir", type=Path, default=rmg_fast_validation.DEFAULT_NATIVE_DIR)
    parser.add_argument("--artifact-root", type=Path, default=rmg_fast_validation.DEFAULT_ARTIFACT_ROOT)
    parser.add_argument("--no-latest-amap-artifact", action="store_true")
    parser.add_argument("--density-floor-ratio", type=float, default=rmg_fast_validation.DEFAULT_DENSITY_FLOOR_RATIO)
    parser.add_argument("--road-floor-ratio", type=float, default=rmg_fast_validation.DEFAULT_ROAD_FLOOR_RATIO)
    parser.add_argument("--guard-reward-ratio-floor-ratio", type=float, default=rmg_fast_validation.DEFAULT_GUARD_REWARD_RATIO_FLOOR_RATIO)
    parser.add_argument("--road-largest-share-multiplier", type=float, default=rmg_fast_validation.DEFAULT_ROAD_LARGEST_SHARE_MULTIPLIER)
    parser.add_argument("--road-largest-share-absolute-cap", type=float, default=rmg_fast_validation.DEFAULT_ROAD_LARGEST_SHARE_ABSOLUTE_CAP)
    parser.add_argument("--road-component-count-floor-ratio", type=float, default=rmg_fast_validation.DEFAULT_ROAD_COMPONENT_COUNT_FLOOR_RATIO)
    parser.add_argument("--guard-closure-min-owner-open-pair-count", type=int, default=rmg_fast_validation.DEFAULT_GUARD_CLOSURE_MIN_OWNER_OPEN_PAIR_COUNT)
    parser.add_argument("--severe-category-gap-ratio", type=float, default=0.20)
    parser.add_argument("--allow-partial-native-batch", action="store_true", help="Audit a targeted native AMAP batch without failing the fast gate for missing unrelated owner cases")
    parser.add_argument("--report-json", type=Path, default=DEFAULT_REPORT_JSON)
    parser.add_argument("--summary", action="store_true")
    parser.add_argument("--gap-limit", type=int, default=8)
    args = parser.parse_args()

    fast_report = rmg_fast_validation.build_report(validation_args(args))
    comparisons = fast_report.get("matched_comparisons", [])
    diagnostic_cases = diagnostic_case_summaries(comparisons if isinstance(comparisons, list) else [], args.severe_category_gap_ratio)
    severe_category_case_count = len([case for case in diagnostic_cases if case.get("severe_category_gaps")])
    route_shape_gap_count = len([
        case for case in diagnostic_cases
        if int(case.get("object_route_reachable_pair_delta", 0)) != 0
        or int(case.get("guarded_route_reachable_pair_delta", 0)) != 0
    ])
    terrain_shape_gap_count = len([
        case for case in diagnostic_cases
        if abs(int(case.get("terrain_blocked_tile_count_delta", 0))) > 50
    ])
    timing = latest_full_timing_summary(
        args.artifact_root,
        int(fast_report.get("summary", {}).get("owner_parsed_count", 0)),
    )
    checklist = build_checklist(fast_report, diagnostic_cases, timing, severe_category_case_count)
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
    report = {
        "schema_id": "rmg_production_gap_audit_v1",
        "status": "pass" if fast_report.get("summary", {}).get("parse_failure_count", 0) == 0 else "fail",
        "production_ready": len(missing) == 0,
        "objective": "Native GDExtension RMG should be production-ready and HoMM3-style across template breadth, zone semantics, roads, obstacles, guards, rewards, validation, runtime adoption, and replay boundaries using original content.",
        "summary": summary,
        "checklist": checklist,
        "missing_requirements": missing,
        "top_gap_cases": diagnostic_cases[: max(0, args.gap_limit)],
        "fast_validation": fast_report,
        "timing": timing,
    }
    write_report(args.report_json, report)
    if args.summary:
        print(compact_summary(report, args.gap_limit))
        print("report_json=%s" % args.report_json)
    else:
        print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if report.get("status") == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
