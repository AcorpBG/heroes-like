#!/usr/bin/env python3
"""Summarize native RMG batch export timings without starting Godot."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import rmg_fast_validation


def latest_manifest_export_dir(artifact_root: Path) -> Path | None:
    if not artifact_root.exists() or not artifact_root.is_dir():
        return None
    candidates: list[Path] = []
    for path in artifact_root.iterdir():
        if not path.is_dir() or not path.name.startswith(rmg_fast_validation.NATIVE_EXPORT_DIR_PREFIX):
            continue
        if (path / "manifest.json").exists():
            candidates.append(path)
    if not candidates:
        return None
    return max(candidates, key=lambda path: (path / "manifest.json").stat().st_mtime)


def load_manifest(path: Path) -> dict[str, Any]:
    if path.is_dir():
        path = path / "manifest.json"
    if not path.exists():
        raise FileNotFoundError(path)
    parsed = json.loads(path.read_text())
    if not isinstance(parsed, dict):
        raise ValueError("manifest root is not an object")
    return parsed


def msec(value: Any) -> int:
    try:
        return int(round(float(value)))
    except (TypeError, ValueError):
        return 0


def profile_label(profile: Any) -> str:
    if not isinstance(profile, dict) or not profile:
        return ""
    phase_id = str(profile.get("top_phase_id", ""))
    elapsed = msec(profile.get("top_phase_elapsed_msec", 0))
    return "%s:%sms" % (phase_id, elapsed) if phase_id else "%sms" % elapsed


def case_summary(record: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": str(record.get("id", "")),
        "status": str(record.get("status", "")),
        "case_wall_msec": msec(record.get("case_wall_msec", 0)),
        "generation_wall_msec": msec(record.get("generation_wall_msec", 0)),
        "conversion_wall_msec": msec(record.get("conversion_wall_msec", 0)),
        "save_wall_msec": msec(record.get("save_wall_msec", 0)),
        "extension_top": profile_label(record.get("extension_profile", {})),
        "conversion_top": profile_label(record.get("conversion_profile", {})),
        "object_top": profile_label(record.get("object_runtime_profile", {})),
        "town_guard_top": profile_label(record.get("town_guard_runtime_profile", {})),
    }


def build_summary(manifest: dict[str, Any], limit: int) -> dict[str, Any]:
    cases = [case for case in manifest.get("cases", []) if isinstance(case, dict)]
    case_summaries = [case_summary(case) for case in cases]
    sorted_cases = sorted(case_summaries, key=lambda case: int(case["case_wall_msec"]), reverse=True)
    return {
        "schema_id": "rmg_export_timing_summary_v1",
        "status": "pass" if cases else "fail",
        "manifest_status": manifest.get("status", ""),
        "case_count": len(cases),
        "exported_count": int(manifest.get("exported_count", 0)),
        "failed_count": int(manifest.get("failed_count", 0)),
        "total_wall_msec": msec(manifest.get("total_wall_msec", 0)),
        "phase_wall_msec_totals": {
            "generation": sum(int(case["generation_wall_msec"]) for case in case_summaries),
            "conversion": sum(int(case["conversion_wall_msec"]) for case in case_summaries),
            "save": sum(int(case["save_wall_msec"]) for case in case_summaries),
        },
        "top_cases": sorted_cases[: max(0, limit)],
    }


def print_summary(summary: dict[str, Any], manifest_path: Path) -> None:
    print("RMG_EXPORT_TIMING_SUMMARY status=%s manifest=%s" % (summary.get("status", ""), manifest_path))
    print(
        "cases exported=%s/%s failed=%s total_wall_msec=%s"
        % (
            summary.get("exported_count", 0),
            summary.get("case_count", 0),
            summary.get("failed_count", 0),
            summary.get("total_wall_msec", 0),
        )
    )
    totals = summary.get("phase_wall_msec_totals", {})
    print(
        "phase_totals generation=%sms conversion=%sms save=%sms"
        % (totals.get("generation", 0), totals.get("conversion", 0), totals.get("save", 0))
    )
    print("top_cases:")
    for case in summary.get("top_cases", []):
        print(
            "  {id} case={case_wall_msec}ms gen={generation_wall_msec}ms conv={conversion_wall_msec}ms save={save_wall_msec}ms ext={extension_top} conv_top={conversion_top} obj={object_top} town_guard={town_guard_top}".format(
                **case
            )
        )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", nargs="?", type=Path, help="Manifest path or native batch export directory")
    parser.add_argument("--latest-amap-artifact", action="store_true", help="Use the newest .artifacts/rmg_native_batch_export* directory containing a timing manifest")
    parser.add_argument("--artifact-root", type=Path, default=rmg_fast_validation.DEFAULT_ARTIFACT_ROOT)
    parser.add_argument("--limit", type=int, default=8)
    parser.add_argument("--json", action="store_true", help="Print JSON instead of compact text")
    args = parser.parse_args()

    manifest_path = args.manifest
    if args.latest_amap_artifact:
        latest = latest_manifest_export_dir(args.artifact_root)
        if latest is None:
            raise SystemExit("No native batch export artifact with a manifest found under %s" % args.artifact_root)
        manifest_path = latest / "manifest.json"
    if manifest_path is None:
        raise SystemExit("Provide a manifest path/directory or --latest-amap-artifact")

    manifest = load_manifest(manifest_path)
    summary = build_summary(manifest, args.limit)
    if args.json:
        print(json.dumps(summary, indent=2, sort_keys=True))
    else:
        print_summary(summary, manifest_path)
    return 0 if summary.get("status") == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
