#!/usr/bin/env python3
"""Export fresh native RMG `.amap` packages through a native headless runner.

This is the Python-owned replacement for the old GDScript batch exporter. The
Godot process is still required because the map package service is a
GDExtension API, but the scene entry point is a native C++ Node and no GDScript
is used for export/test/report control.
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SCENE = Path("tools/rmg_native_batch_export_native.tscn")
DEFAULT_ARTIFACT_ROOT = Path(".artifacts")
LOG_NAME = "rmg_native_batch_export.log"


def find_godot(explicit: str) -> str:
    candidates = [explicit, os.environ.get("GODOT_BIN", ""), "godot4", "godot"]
    for candidate in candidates:
        if not candidate:
            continue
        resolved = shutil.which(candidate) if not Path(candidate).exists() else candidate
        if resolved:
            return resolved
    raise FileNotFoundError("Could not find Godot. Pass --godot or set GODOT_BIN.")


def default_output_dir() -> Path:
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return DEFAULT_ARTIFACT_ROOT / f"rmg_native_batch_export_fresh_{stamp}"


def load_manifest(output_dir: Path) -> dict[str, Any]:
    manifest_path = output_dir / "manifest.json"
    if not manifest_path.exists():
        return {
            "schema_id": "rmg_native_batch_export_python_wrapper_v1",
            "status": "failed",
            "error": "manifest_missing",
            "manifest_path": str(manifest_path),
        }
    with manifest_path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def size_class_from_reference(value: str) -> str:
    normalized = value.strip().lower()
    if normalized in {"small", "s", "homm3_small"}:
        return "small"
    if normalized in {"medium", "m", "homm3_medium"}:
        return "medium"
    if normalized in {"large", "l", "homm3_large"}:
        return "large"
    if normalized in {"extra_large", "xl", "homm3_extra_large"}:
        return "extra_large"
    return normalized or "small"


def water_mode_from_reference(value: str) -> str:
    normalized = value.strip().lower()
    if normalized in {"none", "land", "nowater", "no_water"}:
        return "land"
    if normalized in {"normal", "normal_water", "mixed"}:
        return "normal_water"
    if normalized in {"islands", "water"}:
        return "islands"
    return normalized or "land"


def controlled_case_from_reference_manifest(path: Path) -> str:
    manifest = json.loads(path.read_text())
    inputs = manifest.get("inputs", {}) if isinstance(manifest.get("inputs"), dict) else {}
    identity = manifest.get("controlled_identity", {}) if isinstance(manifest.get("controlled_identity"), dict) else {}
    summary = manifest.get("generation_summary", {}) if isinstance(manifest.get("generation_summary"), dict) else {}
    parsed_summary = summary.get("parsed", {}) if isinstance(summary.get("parsed"), dict) else {}

    case_id = str(manifest.get("case_id") or path.parent.name).strip()
    seed = str(inputs.get("seed") or identity.get("seed") or parsed_summary.get("seed") or identity.get("requested_seed") or "0")
    humans = int(
        inputs.get("human_computer_players")
        or identity.get("requested_humans")
        or parsed_summary.get("humans")
        or identity.get("observed_humans")
        or inputs.get("human_players")
        or inputs.get("players")
        or 1
    )
    computers = int(inputs.get("computer_only_players") or parsed_summary.get("computers") or identity.get("observed_computers") or 0)
    players = int(inputs.get("players") or max(2, humans + computers))
    players = max(2, min(8, players))
    size_class = size_class_from_reference(str(inputs.get("size") or parsed_summary.get("size") or "small"))
    water_mode = water_mode_from_reference(str(inputs.get("water") or parsed_summary.get("water") or "land"))
    level_count = int(inputs.get("level_count") or parsed_summary.get("levels") or 1)
    return f"{case_id}:{size_class}:{players}:{seed}:{water_mode}:{level_count}:{humans}:{computers}"


def run_export(args: argparse.Namespace) -> int:
    godot = find_godot(args.godot)
    output_dir = args.out or default_output_dir()
    output_dir = output_dir if output_dir.is_absolute() else ROOT / output_dir
    output_dir.parent.mkdir(parents=True, exist_ok=True)
    log_path = output_dir.with_suffix("")
    output_dir.mkdir(parents=True, exist_ok=True)
    log_file = output_dir / LOG_NAME

    scene = args.scene
    scene_path = scene if scene.is_absolute() else ROOT / scene
    if not scene_path.exists():
        raise FileNotFoundError(f"Missing native export scene: {scene_path}")

    command = [
        godot,
        "--headless",
        "--path",
        str(ROOT),
        str(scene),
        "--",
        "--out",
        str(output_dir),
    ]
    if args.limit > 0:
        command.extend(["--limit", str(args.limit)])
    if args.case:
        command.extend(["--case", args.case])
    controlled_cases = list(args.controlled_case)
    for reference_manifest in args.controlled_reference_manifest:
        controlled_cases.append(controlled_case_from_reference_manifest(reference_manifest))
    for controlled_case in controlled_cases:
        command.extend(["--controlled-case", controlled_case])
    if args.include_unsupported:
        command.append("--include-unsupported")
    if args.emit_phase_snapshot:
        command.append("--emit-phase-snapshot")

    env = os.environ.copy()
    env.setdefault("GODOT_SILENCE_ROOT_WARNING", "1")
    with log_file.open("w", encoding="utf-8") as handle:
        process = subprocess.run(
            command,
            cwd=ROOT,
            env=env,
            stdout=handle,
            stderr=subprocess.STDOUT,
            text=True,
            check=False,
        )

    manifest = load_manifest(output_dir)
    wrapper = {
        "schema_id": "rmg_native_batch_export_python_wrapper_v1",
        "status": "pass" if process.returncode == 0 and manifest.get("status") == "exported" else "fail",
        "godot": godot,
        "scene": str(scene),
        "output_dir": str(output_dir),
        "log_path": str(log_file),
        "returncode": process.returncode,
        "manifest_status": manifest.get("status", ""),
        "exported_count": manifest.get("exported_count", 0),
        "failed_count": manifest.get("failed_count", 0),
        "case_count": manifest.get("case_count", 0),
        "control_policy": "python_invokes_native_gdextension_node_no_gdscript_exporter",
        "case_scope": manifest.get("case_scope", ""),
    }
    wrapper_path = output_dir / "wrapper_manifest.json"
    with wrapper_path.open("w", encoding="utf-8") as handle:
        json.dump(wrapper, handle, indent=2, sort_keys=True)

    print(
        "RMG_NATIVE_BATCH_EXPORT_PY status={status} output_dir={output_dir} "
        "exported={exported_count} failed={failed_count} log={log_path}".format(**wrapper)
    )
    if args.print_manifest:
        print(json.dumps(wrapper, indent=2, sort_keys=True))
    return 0 if wrapper["status"] == "pass" else 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="", help="Godot executable path, otherwise GODOT_BIN/godot4/godot.")
    parser.add_argument("--out", type=Path, default=None, help="Output directory for fresh .amap files and manifests.")
    parser.add_argument("--limit", type=int, default=0, help="Maximum owner cases to export.")
    parser.add_argument("--case", default="", help="Comma-separated case id filter.")
    parser.add_argument(
        "--controlled-case",
        action="append",
        default=[],
        help="Explicit native case as id:size_class:players:seed:water_mode:level_count[:human_count[:computer_count]]. Bypasses owner filename inference.",
    )
    parser.add_argument(
        "--controlled-reference-manifest",
        action="append",
        type=Path,
        default=[],
        help="Build a controlled native case from a h3maped controlled_reference_manifest.json using the observed saved H3M identity.",
    )
    parser.add_argument("--scene", type=Path, default=DEFAULT_SCENE, help="Native runner scene path.")
    parser.add_argument("--include-unsupported", action="store_true", help="Export unsupported owner cases too; failures are expected for modes outside strict Small/Medium one-level land.")
    parser.add_argument("--emit-phase-snapshot", action="store_true", help="Ask the native runner to write per-case private h3maped phase snapshots for source-behavior debugging.")
    parser.add_argument("--print-manifest", action="store_true", help="Print wrapper manifest JSON.")
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        return run_export(args)
    except Exception as exc:
        print(f"RMG_NATIVE_BATCH_EXPORT_PY status=fail error={exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
