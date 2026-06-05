#!/usr/bin/env python3
"""Audit native Small RMG divergence from h3maped.exe references.

This is diagnostic tooling only. It does not change generator behavior and does
not promote exact h3maped byte parity to a runtime acceptance gate.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any


DEFAULT_OUT_DIR = Path(".artifacts/rmg_h3maped_small_divergence_audit")
DEFAULT_NATIVE_SNAPSHOT = DEFAULT_OUT_DIR / "native_broad_snapshot.json"
DEFAULT_REFERENCE_ROOT = Path(".artifacts/rmg_h3maped_controlled_reference")


def as_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def run_command(command: list[str], timeout_seconds: int) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
        timeout=timeout_seconds,
    )


def command_tail(output: str, line_count: int = 80) -> str:
    return "\n".join(output.splitlines()[-line_count:])


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text())


def write_json(path: Path, payload: dict[str, Any], pretty: bool) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2 if pretty else None, sort_keys=True) + "\n")


def run_native_export(args: argparse.Namespace) -> Path:
    if args.native_snapshot:
        return args.native_snapshot
    raise RuntimeError(
        "native broad snapshot is required. GDScript report/export launchers are disabled for this audit; "
        "provide --native-snapshot from a Python/native export artifact."
    )


def metrics(case: dict[str, Any]) -> dict[str, Any]:
    value = case.get("metrics", {})
    return value if isinstance(value, dict) else {}


def score_case(case: dict[str, Any]) -> dict[str, Any]:
    m = metrics(case)
    reasons: list[str] = []
    score = 0

    def add(condition: bool, points: int, reason: str) -> None:
        nonlocal score
        if condition:
            score += points
            reasons.append(reason)

    add(not bool(case.get("ok")), 100, "native_validation_not_green")
    add(as_int(m.get("route_link_count")) <= 0, 40, "route_links_missing")
    add(as_int(m.get("unguarded_route_link_count"), -1) != 0, 35, "unguarded_route_links")
    add(as_int(m.get("route_link_without_blocker_count"), -1) != 0, 30, "route_links_without_blockers")
    add(as_int(m.get("route_link_without_guard_count"), -1) != 0, 30, "route_links_without_guards")
    add(as_int(m.get("road_segment_disconnected_count"), -1) != 0, 30, "road_segments_disconnected")
    add(as_int(m.get("road_segment_missing_metadata_count"), -1) != 0, 25, "road_metadata_missing")
    add(as_int(m.get("owned_player_town_count")) != as_int(case.get("players")), 35, "owned_town_count_mismatch")
    add(as_int(m.get("town_count")) < as_int(case.get("players")), 35, "town_count_below_player_count")
    add(as_int(m.get("mine_count")) <= 0, 25, "mines_missing")
    add(as_int(m.get("reward_count")) <= 0, 25, "rewards_missing")
    add(as_int(m.get("connection_guard_count")) <= 0, 25, "connection_guards_missing")
    add(as_int(m.get("connection_blocker_count")) <= 0, 25, "connection_blockers_missing")
    add(as_int(m.get("road_overlay_type_nonzero_count")) < 35, 20, "road_tiles_below_small_floor")
    add(as_int(m.get("road_overlay_type_nonzero_count")) > 200, 12, "road_tiles_high_for_small")
    add(as_int(m.get("package_object_count")) < 120, 18, "object_density_low_for_small")
    add(as_int(m.get("package_object_count")) > 500, 18, "object_density_high_for_small")
    add(as_int(m.get("duplicate_placement_id_count"), -1) != 0, 40, "duplicate_placement_ids")
    add(as_int(m.get("out_of_bounds_object_count"), -1) != 0, 40, "out_of_bounds_objects")

    return {
        "case_id": case.get("case_id", ""),
        "seed": case.get("seed", ""),
        "players": as_int(case.get("players")),
        "source_template_id": case.get("source_template_id", ""),
        "score": score,
        "reasons": reasons,
        "key_metrics": {
            "package_object_count": as_int(m.get("package_object_count")),
            "town_count": as_int(m.get("town_count")),
            "owned_player_town_count": as_int(m.get("owned_player_town_count")),
            "mine_count": as_int(m.get("mine_count")),
            "reward_count": as_int(m.get("reward_count")),
            "connection_guard_count": as_int(m.get("connection_guard_count")),
            "connection_blocker_count": as_int(m.get("connection_blocker_count")),
            "route_link_count": as_int(m.get("route_link_count")),
            "road_record_count": as_int(m.get("road_record_count")),
            "road_overlay_type_nonzero_count": as_int(m.get("road_overlay_type_nonzero_count")),
            "unguarded_route_link_count": as_int(m.get("unguarded_route_link_count"), -1),
        },
    }


def aggregate_native(cases: list[dict[str, Any]], scored: list[dict[str, Any]]) -> dict[str, Any]:
    by_template: dict[str, int] = {}
    by_players: dict[str, int] = {}
    totals: dict[str, int] = {
        "package_object_count": 0,
        "town_count": 0,
        "mine_count": 0,
        "reward_count": 0,
        "connection_guard_count": 0,
        "connection_blocker_count": 0,
        "road_overlay_type_nonzero_count": 0,
    }
    for case in cases:
        m = metrics(case)
        template_id = str(case.get("source_template_id", ""))
        by_template[template_id] = by_template.get(template_id, 0) + 1
        players = str(case.get("players", ""))
        by_players[players] = by_players.get(players, 0) + 1
        for key in totals:
            totals[key] += as_int(m.get(key))
    count = max(1, len(cases))
    return {
        "case_count": len(cases),
        "ok_case_count": sum(1 for case in cases if bool(case.get("ok"))),
        "templates_seen": dict(sorted(by_template.items())),
        "cases_by_player_count": dict(sorted(by_players.items())),
        "averages": {key: round(value / count, 2) for key, value in totals.items()},
        "highest_risk_cases": sorted(scored, key=lambda item: (-as_int(item.get("score")), str(item.get("case_id"))))[:12],
    }


def selected_controlled_cases(
    cases: list[dict[str, Any]],
    scored: list[dict[str, Any]],
    limit: int,
    reference_root: Path | None = None,
) -> list[dict[str, Any]]:
    selected: dict[str, dict[str, Any]] = {}
    for players in [2, 3, 4]:
        for case in cases:
            if as_int(case.get("players")) == players:
                selected[str(case.get("case_id"))] = case
                break
    by_case_id = {str(case.get("case_id")): case for case in cases}
    for item in sorted(scored, key=lambda score: (-as_int(score.get("score")), str(score.get("case_id")))):
        case_id = str(item.get("case_id"))
        if case_id in by_case_id:
            selected[case_id] = by_case_id[case_id]
        if len(selected) >= max(0, limit) + 3:
            break
    if reference_root is not None:
        for case in cases:
            case_id = str(case.get("case_id"))
            if case_id not in selected and find_existing_manifest(case, reference_root) is not None:
                selected[case_id] = case
    return list(selected.values())


def manifest_matches_case(manifest: dict[str, Any], case: dict[str, Any]) -> bool:
    inputs = manifest.get("inputs", {}) if isinstance(manifest.get("inputs"), dict) else {}
    return (
        str(inputs.get("seed", "")) == str(case.get("seed", ""))
        and as_int(inputs.get("players")) == as_int(case.get("players"))
        and str(inputs.get("size", "small")) == "small"
        and str(inputs.get("water", "land")) == "land"
        and as_int(inputs.get("level_count"), 1) == 1
    )


def find_existing_manifest(case: dict[str, Any], reference_root: Path) -> Path | None:
    if not reference_root.exists():
        return None
    for path in sorted(reference_root.glob("*/controlled_reference_manifest.json")):
        try:
            manifest = load_json(path)
        except (OSError, json.JSONDecodeError):
            continue
        if manifest.get("status") == "ready" and manifest_matches_case(manifest, case):
            return path
    return None


def generate_controlled_manifest(args: argparse.Namespace, case: dict[str, Any], case_dir: Path) -> Path | None:
    reference_case_id = f"small_divergence_{case['case_id']}"
    command = [
        sys.executable,
        "tools/rmg_h3maped_controlled_reference.py",
        "--case",
        reference_case_id,
        "--seed",
        str(case.get("seed", "")),
        "--players",
        str(case.get("players", "")),
        "--human-players",
        "1",
        "--size",
        "small",
        "--width",
        "36",
        "--height",
        "36",
        "--level-count",
        "1",
        "--water",
        "land",
        "--out-root",
        str(args.reference_root),
        "--allow-blocked",
    ]
    if args.pretty:
        command.append("--pretty")
    result = run_command(command, args.controlled_timeout_seconds)
    log_path = case_dir / "controlled_reference_command.log"
    log_path.write_text(result.stdout)
    manifest_path = args.reference_root / reference_case_id / "controlled_reference_manifest.json"
    if not manifest_path.exists():
        return None
    return manifest_path


def run_deep_drift(args: argparse.Namespace, case: dict[str, Any], manifest_path: Path, case_dir: Path) -> dict[str, Any]:
    manifest = load_json(manifest_path)
    if manifest.get("status") != "ready":
        return {
            "case_id": case.get("case_id", ""),
            "status": "controlled_reference_not_ready",
            "manifest": str(manifest_path),
            "manifest_status": manifest.get("status", ""),
            "blocker": manifest.get("blocker", manifest.get("error", "")),
        }
    snapshot_path = Path(str(case.get("phase_snapshot_path", "")))
    if not snapshot_path.exists() and args.phase_snapshot_root:
        snapshot_path = args.phase_snapshot_root / str(case.get("case_id", "")) / "phase_snapshot.json"
    if not snapshot_path.exists():
        return {
            "case_id": case.get("case_id", ""),
            "status": "phase_snapshot_missing",
            "manifest": str(manifest_path),
            "blocker": "GDScript phase snapshot export is disabled; provide phase_snapshot_path in the native snapshot or --phase-snapshot-root.",
        }
    drift_dir = case_dir / "phase_drift"
    drift_command = [
        sys.executable,
        "tools/rmg_phase_drift_audit.py",
        "--phase-snapshot",
        str(snapshot_path),
        "--controlled-reference-manifest",
        str(manifest_path),
        "--out-dir",
        str(drift_dir),
    ]
    if args.pretty:
        drift_command.append("--pretty")
    drift_result = run_command(drift_command, args.timeout_seconds)
    (case_dir / "phase_drift_command.log").write_text(drift_result.stdout)
    if drift_result.returncode != 0:
        return {
            "case_id": case.get("case_id", ""),
            "status": "phase_drift_failed",
            "manifest": str(manifest_path),
            "log_tail": command_tail(drift_result.stdout),
        }
    report_path = drift_dir / "phase_drift_report.json"
    report = load_json(report_path)
    return {
        "case_id": case.get("case_id", ""),
        "seed": case.get("seed", ""),
        "players": as_int(case.get("players")),
        "status": str(report.get("status", "")),
        "manifest": str(manifest_path),
        "phase_drift_report": str(report_path),
        "reference_alignment": report.get("reference_alignment", {}).get("classification", ""),
        "final_deltas": report.get("final_deltas", {}),
        "root_cause_findings": [
            {
                "id": finding.get("id", ""),
                "severity": finding.get("severity", ""),
                "classification": finding.get("classification", ""),
                "metric": finding.get("metric", ""),
            }
            for finding in report.get("root_cause_findings", [])
            if isinstance(finding, dict)
        ],
    }


def controlled_deep_dives(args: argparse.Namespace, cases: list[dict[str, Any]]) -> list[dict[str, Any]]:
    results: list[dict[str, Any]] = []
    if args.skip_controlled:
        return [
            {
                "case_id": case.get("case_id", ""),
                "seed": case.get("seed", ""),
                "players": as_int(case.get("players")),
                "status": "skipped_by_flag",
            }
            for case in cases
        ]
    for case in cases:
        case_dir = args.out / "controlled_cases" / str(case.get("case_id", "case"))
        case_dir.mkdir(parents=True, exist_ok=True)
        manifest_path = find_existing_manifest(case, args.reference_root) if args.reuse_existing_references else None
        if manifest_path is None and args.existing_references_only:
            results.append({
                "case_id": case.get("case_id", ""),
                "seed": case.get("seed", ""),
                "players": as_int(case.get("players")),
                "status": "controlled_reference_not_preexisting",
            })
            continue
        if manifest_path is None:
            manifest_path = generate_controlled_manifest(args, case, case_dir)
        if manifest_path is None:
            results.append({
                "case_id": case.get("case_id", ""),
                "seed": case.get("seed", ""),
                "players": as_int(case.get("players")),
                "status": "controlled_reference_missing",
            })
            continue
        results.append(run_deep_drift(args, case, manifest_path, case_dir))
    return results


def write_markdown(report: dict[str, Any], path: Path) -> None:
    lines = [
        "# Small h3maped Divergence Audit",
        "",
        f"- Status: `{report.get('status')}`",
        f"- Scope: {report.get('scope')}",
        f"- Native cases: `{report.get('native_broad', {}).get('case_count')}`",
        f"- Controlled cases: `{len(report.get('controlled_deep_dives', []))}`",
        "",
        "## Native Broad Survey",
        "",
    ]
    native = report.get("native_broad", {})
    lines.append(f"- Green native cases: `{native.get('ok_case_count')}` / `{native.get('case_count')}`")
    lines.append(f"- Templates seen: `{native.get('templates_seen')}`")
    lines.append(f"- Averages: `{native.get('averages')}`")
    lines.extend(["", "## Highest Risk Native Cases", ""])
    for item in native.get("highest_risk_cases", [])[:12]:
        lines.append(
            "- `{case_id}` p`{players}` seed `{seed}` template `{template}` score `{score}` reasons `{reasons}`".format(
                case_id=item.get("case_id"),
                players=item.get("players"),
                seed=item.get("seed"),
                template=item.get("source_template_id"),
                score=item.get("score"),
                reasons=", ".join(item.get("reasons", [])) or "none",
            )
        )
    lines.extend(["", "## Controlled Deep Dives", ""])
    for item in report.get("controlled_deep_dives", []):
        lines.append(
            "- `{case_id}` p`{players}` seed `{seed}`: `{status}` alignment `{alignment}` report `{report}`".format(
                case_id=item.get("case_id"),
                players=item.get("players"),
                seed=item.get("seed"),
                status=item.get("status"),
                alignment=item.get("reference_alignment", ""),
                report=item.get("phase_drift_report", ""),
            )
        )
    lines.extend(["", "## Notes", ""])
    for note in report.get("notes", []):
        lines.append(f"- {note}")
    path.write_text("\n".join(lines) + "\n")


def build_report(args: argparse.Namespace) -> dict[str, Any]:
    snapshot_path = run_native_export(args)
    snapshot = load_json(snapshot_path)
    cases = list(snapshot.get("cases", []))
    scored = [score_case(case) for case in cases]
    reference_root = args.reference_root if args.reuse_existing_references else None
    selected = selected_controlled_cases(cases, scored, args.controlled_limit, reference_root)
    deep = controlled_deep_dives(args, selected)
    return {
        "schema_id": "rmg_h3maped_small_divergence_audit_v1",
        "status": "complete",
        "scope": "diagnostic native Small 36x36 one-level land divergence audit; exact h3maped parity is not a runtime acceptance gate",
        "inputs": {
            "native_snapshot": str(snapshot_path),
            "skip_controlled": bool(args.skip_controlled),
            "reuse_existing_references": bool(args.reuse_existing_references),
            "existing_references_only": bool(args.existing_references_only),
            "controlled_limit": args.controlled_limit,
            "reference_root": str(args.reference_root),
        },
        "native_broad": aggregate_native(cases, scored),
        "native_cases": cases,
        "native_risk_scores": sorted(scored, key=lambda item: (-as_int(item.get("score")), str(item.get("case_id")))),
        "controlled_selection": [
            {"case_id": case.get("case_id", ""), "seed": case.get("seed", ""), "players": as_int(case.get("players"))}
            for case in selected
        ],
        "controlled_deep_dives": deep,
        "notes": [
            "Broad survey scores are native structural risk indicators, not direct h3maped deltas.",
            "Controlled deep dives use real h3maped.exe manifests when available and keep seed/template alignment separate from output deltas.",
            "This audit is read-only with respect to generator behavior and should not be used for count fitting.",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT_DIR)
    parser.add_argument("--native-snapshot", type=Path)
    parser.add_argument("--controlled-limit", type=int, default=6)
    parser.add_argument("--skip-controlled", action="store_true")
    parser.add_argument("--reuse-existing-references", action="store_true")
    parser.add_argument("--existing-references-only", action="store_true")
    parser.add_argument("--reference-root", type=Path, default=DEFAULT_REFERENCE_ROOT)
    parser.add_argument("--phase-snapshot-root", type=Path)
    parser.add_argument("--timeout-seconds", type=int, default=180)
    parser.add_argument("--controlled-timeout-seconds", type=int, default=180)
    parser.add_argument("--pretty", action="store_true")
    args = parser.parse_args()
    if args.existing_references_only:
        args.reuse_existing_references = True

    args.out.mkdir(parents=True, exist_ok=True)
    report = build_report(args)
    json_path = args.out / "small_divergence_report.json"
    markdown_path = args.out / "small_divergence_report.md"
    write_json(json_path, report, args.pretty)
    write_markdown(report, markdown_path)
    print(json.dumps({"status": report["status"], "json": str(json_path), "markdown": str(markdown_path)}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
