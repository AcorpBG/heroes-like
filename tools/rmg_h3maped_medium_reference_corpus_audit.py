#!/usr/bin/env python3
"""Audit the strict Medium H3MapEd reference corpus.

This is a Goal-1 reference-corpus gate. It validates controlled h3maped.exe
outputs and records whether native phase snapshots are available for later
drift comparison. It does not accept translated Medium output as runtime
completion evidence.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


EXPECTED_H3MAPED_SHA256 = "4480fba145c9f885942cc668d4bce430fe39c0fa482d1a6e58f96318ab857a37"
DEFAULT_REFERENCE_ROOT = Path(".artifacts/rmg_h3maped_controlled_reference_medium")
DEFAULT_OUT = Path(".artifacts/rmg_h3maped_medium_reference_corpus_audit")
REQUIRED_PLAYER_COUNTS = {2, 3, 4}


def as_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text())


def get_path(source: dict[str, Any], path: str, default: Any = None) -> Any:
    current: Any = source
    for part in path.split("."):
        if not isinstance(current, dict) or part not in current:
            return default
        current = current[part]
    return current


def manifest_paths(reference_root: Path) -> list[Path]:
    return sorted(reference_root.glob("*/controlled_reference_manifest.json"))


def snapshot_path_for_manifest(path: Path) -> Path:
    return path.parent / "native_phase_snapshot" / "phase_snapshot.json"


def required_metric_failures(manifest: dict[str, Any]) -> list[str]:
    failures: list[str] = []
    inputs = manifest.get("inputs", {}) if isinstance(manifest.get("inputs"), dict) else {}
    required = get_path(manifest, "metrics.required", {})
    if not isinstance(required, dict):
        return ["missing_required_metrics"]
    checks = {
        "status_ready": manifest.get("status") == "ready",
        "h3maped_sha_pinned": get_path(manifest, "h3maped.sha256", "") == EXPECTED_H3MAPED_SHA256,
        "same_seed_parity_supported": bool(get_path(manifest, "controlled_identity.same_seed_parity_supported", False)),
        "numeric_seed_recorded": str(inputs.get("seed", "")).isdigit(),
        "size_medium": inputs.get("size") == "medium",
        "width_72": as_int(inputs.get("width")) == 72,
        "height_72": as_int(inputs.get("height")) == 72,
        "level_count_1": as_int(inputs.get("level_count")) == 1,
        "water_land": inputs.get("water") == "land",
        "required_metrics_parsed": required.get("status") == "parsed",
        "object_count_positive": as_int(required.get("object_count")) > 0,
        "town_count_positive": as_int(required.get("town_count")) > 0,
        "road_cell_count_positive": as_int(required.get("road_cell_count")) > 0,
        "guard_count_positive": as_int(required.get("guard_count")) > 0,
        "reward_count_positive": as_int(required.get("reward_count")) > 0,
        "blocker_like_object_count_positive": as_int(required.get("blocker_like_object_count")) > 0,
        "body_tiles_positive": as_int(required.get("body_tile_count_total")) > 0,
        "block_tiles_equal_body_tiles": as_int(required.get("block_tile_count_total")) == as_int(required.get("body_tile_count_total")),
        "visit_tiles_positive": as_int(required.get("visit_tile_count_total")) > 0,
        "route_topology_present": isinstance(required.get("route_topology"), dict),
    }
    return [key for key, ok in checks.items() if not ok]


def case_record(path: Path) -> dict[str, Any]:
    manifest = load_json(path)
    inputs = manifest.get("inputs", {}) if isinstance(manifest.get("inputs"), dict) else {}
    required = get_path(manifest, "metrics.required", {})
    if not isinstance(required, dict):
        required = {}
    snapshot_path = snapshot_path_for_manifest(path)
    snapshot: dict[str, Any] = load_json(snapshot_path) if snapshot_path.exists() else {}
    phase_summaries = snapshot.get("phase_summaries", {}) if isinstance(snapshot.get("phase_summaries"), dict) else {}
    runtime_zone = phase_summaries.get("runtime_zone_records", {}) if isinstance(phase_summaries.get("runtime_zone_records"), dict) else {}
    validator = phase_summaries.get("fast_structural_validator", {}) if isinstance(phase_summaries.get("fast_structural_validator"), dict) else {}
    failures = required_metric_failures(manifest)
    return {
        "case_id": str(manifest.get("case_id", path.parent.name)),
        "manifest": str(path),
        "h3m_path": str(get_path(manifest, "outputs.h3m_path", "")),
        "status": "pass" if not failures else "fail",
        "failures": failures,
        "seed": str(inputs.get("seed", "")),
        "players": as_int(inputs.get("players")),
        "dimensions": {
            "width": as_int(inputs.get("width")),
            "height": as_int(inputs.get("height")),
            "level_count": as_int(inputs.get("level_count")),
            "water": str(inputs.get("water", "")),
        },
        "source_template": {
            "observed_template": get_path(manifest, "controlled_identity.observed_template", ""),
            "observed_source_template_id": get_path(manifest, "controlled_identity.observed_source_template_id", ""),
            "observed_source_catalog_index": get_path(manifest, "controlled_identity.observed_source_catalog_index", None),
        },
        "required_metrics": {
            "object_count": as_int(required.get("object_count")),
            "town_count": as_int(required.get("town_count")),
            "road_cell_count": as_int(required.get("road_cell_count")),
            "guard_count": as_int(required.get("guard_count")),
            "reward_count": as_int(required.get("reward_count")),
            "blocker_like_object_count": as_int(required.get("blocker_like_object_count")),
            "body_tile_count_total": as_int(required.get("body_tile_count_total")),
            "block_tile_count_total": as_int(required.get("block_tile_count_total")),
            "visit_tile_count_total": as_int(required.get("visit_tile_count_total")),
            "guard_control_tile_count_total": as_int(required.get("guard_control_tile_count_total")),
            "route_topology": required.get("route_topology", {}),
        },
        "native_phase_snapshot": {
            "path": str(snapshot_path) if snapshot_path.exists() else "",
            "exists": snapshot_path.exists(),
            "status": str(snapshot.get("status", "missing")),
            "inspection_ok": bool(snapshot.get("inspection_ok", False)),
            "generation_ok": bool(snapshot.get("generation_ok", False)),
            "generation_status": str(snapshot.get("generation_status", "")),
            "config_size_class_id": get_path(snapshot, "config.size.size_class_id", ""),
            "expected_tile_count": get_path(validator, "metrics.expected_tile_count", None),
            "first_medium_blocker": str(runtime_zone.get("status", "")),
        },
        "phase_drift_comparison_status": "ready" if bool(snapshot.get("generation_ok", False)) else "blocked_native_amap_missing",
    }


def build_report(reference_root: Path) -> dict[str, Any]:
    paths = manifest_paths(reference_root)
    cases = [case_record(path) for path in paths]
    medium_cases = [case for case in cases if case["dimensions"]["width"] == 72 and case["dimensions"]["height"] == 72]
    seen_players = {as_int(case.get("players")) for case in medium_cases if case.get("status") == "pass"}
    missing_players = sorted(REQUIRED_PLAYER_COUNTS - seen_players)
    failed_cases = [case for case in medium_cases if case.get("status") != "pass"]
    snapshot_missing_cases = [
        case for case in medium_cases
        if not case.get("native_phase_snapshot", {}).get("exists", False)
    ]
    status = "pass" if not missing_players and not failed_cases and not snapshot_missing_cases else "fail"
    return {
        "schema_id": "rmg_h3maped_medium_reference_corpus_audit_v1",
        "status": status,
        "reference_root": str(reference_root),
        "required_scope": {
            "size": "homm3_medium",
            "width": 72,
            "height": 72,
            "level_count": 1,
            "water": "land",
            "player_counts": sorted(REQUIRED_PLAYER_COUNTS),
        },
        "case_count": len(medium_cases),
        "ready_case_count": sum(1 for case in medium_cases if case.get("status") == "pass"),
        "native_snapshot_count": sum(1 for case in medium_cases if case.get("native_phase_snapshot", {}).get("exists", False)),
        "phase_drift_ready_count": sum(1 for case in medium_cases if case.get("phase_drift_comparison_status") == "ready"),
        "phase_drift_blocked_count": sum(1 for case in medium_cases if case.get("phase_drift_comparison_status") != "ready"),
        "missing_required_player_counts": missing_players,
        "failed_cases": [{"case_id": case.get("case_id"), "failures": case.get("failures", [])} for case in failed_cases],
        "snapshot_missing_cases": [case.get("case_id") for case in snapshot_missing_cases],
        "cases": medium_cases,
        "non_claims": [
            "Native Medium runtime generation is not complete in this reference-corpus audit.",
            "Translated/proxy Medium output is not accepted as strict H3MapEd completion evidence.",
            "Phase drift comparison remains blocked for cases whose native snapshot has no AMAP output.",
        ],
    }


def write_markdown(report: dict[str, Any], path: Path) -> None:
    lines = [
        "# Medium H3MapEd Reference Corpus Audit",
        "",
        f"- Status: `{report.get('status')}`",
        f"- Cases: `{report.get('ready_case_count')}` ready / `{report.get('case_count')}` Medium references",
        f"- Native snapshots: `{report.get('native_snapshot_count')}`",
        f"- Phase drift ready/blocked: `{report.get('phase_drift_ready_count')}` / `{report.get('phase_drift_blocked_count')}`",
        "",
        "## Cases",
        "",
    ]
    for case in report.get("cases", []):
        metrics = case.get("required_metrics", {}) if isinstance(case.get("required_metrics"), dict) else {}
        snapshot = case.get("native_phase_snapshot", {}) if isinstance(case.get("native_phase_snapshot"), dict) else {}
        template = case.get("source_template", {}) if isinstance(case.get("source_template"), dict) else {}
        lines.append(
            "- `%s`: status `%s`, seed `%s`, players `%s`, template `%s` index `%s`, objects `%s`, towns `%s`, roads `%s`, guards `%s`, rewards `%s`, body/block `%s/%s`, snapshot `%s` `%s`"
            % (
                case.get("case_id", ""),
                case.get("status", ""),
                case.get("seed", ""),
                case.get("players", ""),
                template.get("observed_template", ""),
                template.get("observed_source_catalog_index", ""),
                metrics.get("object_count", 0),
                metrics.get("town_count", 0),
                metrics.get("road_cell_count", 0),
                metrics.get("guard_count", 0),
                metrics.get("reward_count", 0),
                metrics.get("body_tile_count_total", 0),
                metrics.get("block_tile_count_total", 0),
                snapshot.get("status", ""),
                case.get("phase_drift_comparison_status", ""),
            )
        )
    lines.extend(["", "## Non-Claims", ""])
    for item in report.get("non_claims", []):
        lines.append(f"- {item}")
    path.write_text("\n".join(lines) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--reference-root", type=Path, default=DEFAULT_REFERENCE_ROOT)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--pretty", action="store_true")
    args = parser.parse_args()
    report = build_report(args.reference_root)
    args.out.mkdir(parents=True, exist_ok=True)
    json_path = args.out / "medium_reference_corpus_audit.json"
    md_path = args.out / "medium_reference_corpus_audit.md"
    json_path.write_text(json.dumps(report, indent=2 if args.pretty else None, sort_keys=True) + "\n")
    write_markdown(report, md_path)
    print(json.dumps({"status": report["status"], "json": str(json_path), "markdown": str(md_path)}, sort_keys=True))
    return 0 if report["status"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
