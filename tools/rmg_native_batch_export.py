#!/usr/bin/env python3
"""Export fresh native RMG artifacts through the no-Godot native runner.

This wrapper never launches Godot. Native RMG parity/export work must use the
standalone CLI boundary so memory-constrained hosts cannot accidentally start
the engine.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import rmg_no_godot_guard


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_NATIVE_CLI = Path("bin/rmg_native_batch_export_cli")
DEFAULT_ARTIFACT_ROOT = Path(".artifacts")
LOG_NAME = "rmg_native_batch_export.log"


def godot_processes() -> list[dict[str, str]]:
    return rmg_no_godot_guard.active_godot_processes()


def find_native_cli(explicit: str) -> Path:
    candidates = [Path(explicit)] if explicit else []
    candidates.extend(
        [
            ROOT / DEFAULT_NATIVE_CLI,
            ROOT / ".artifacts" / "map_persistence_native_build" / "rmg_native_batch_export_cli",
            ROOT / "src" / "gdextension" / "build" / "linux-debug" / "rmg_native_batch_export_cli",
        ]
    )
    for candidate in candidates:
        if candidate and candidate.exists() and os.access(candidate, os.X_OK):
            return candidate
    raise FileNotFoundError(
        "Could not find rmg_native_batch_export_cli. Build the native target first: "
        "cmake --build .artifacts/map_persistence_native_build --target rmg_native_batch_export_cli --parallel 2"
    )


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


def run_native_cli_export(args: argparse.Namespace) -> int:
    native_cli = find_native_cli(args.native_cli)
    output_dir = args.out or default_output_dir()
    output_dir = output_dir if output_dir.is_absolute() else ROOT / output_dir
    output_dir.mkdir(parents=True, exist_ok=True)
    log_file = output_dir / LOG_NAME
    if not args.phase_snapshot_only:
        wrapper = {
            "schema_id": "rmg_native_batch_export_python_wrapper_v6",
            "status": "blocked",
            "runner": "standalone_native_cli_no_godot",
            "native_cli": str(native_cli),
            "godot_process_started": False,
            "output_dir": str(output_dir),
            "log_path": str(log_file),
            "returncode": None,
            "error": "native_output_plain_cpp_core_not_available",
            "blocked_reason": "native_map_json_and_full_amap_export_require_final_payload_generation_to_come_from_the_shared_recovered_h3maped_rmg_core",
            "required_mode": "--phase-snapshot-only",
            "control_policy": "python_wrapper_refuses_native_output_before_spawning_cli_until_shared_recovered_core_owns_final_payload_generation",
            "godot_process_guard": {
                "status": "not_checked_native_output_refused_before_spawn",
                "preexisting_processes": [],
                "post_run_processes": [],
            },
        }
        wrapper_path = output_dir / "wrapper_manifest.json"
        with wrapper_path.open("w", encoding="utf-8") as handle:
            json.dump(wrapper, handle, indent=2, sort_keys=True)
        print(
            "RMG_NATIVE_BATCH_EXPORT_PY status=blocked error=native_output_plain_cpp_core_not_available "
            f"output_dir={output_dir} required_mode=--phase-snapshot-only log={log_file}",
            file=sys.stderr,
        )
        return 1

    preexisting_godot = godot_processes()
    if preexisting_godot:
        wrapper = {
            "schema_id": "rmg_native_batch_export_python_wrapper_v5",
            "status": "failed",
            "runner": "standalone_native_cli_no_godot",
            "native_cli": str(native_cli),
            "godot_process_started": False,
            "output_dir": str(output_dir),
            "log_path": str(log_file),
            "returncode": None,
            "error": "godot_process_running",
            "blocked_reason": "refusing_native_rmg_export_while_godot_process_is_running_on_memory_constrained_host",
            "godot_process_guard": {
                "status": "fail",
                "preexisting_processes": preexisting_godot,
                "post_run_processes": [],
            },
            "control_policy": "python_invokes_standalone_native_cli_no_godot_and_refuses_when_godot_is_already_running",
        }
        wrapper_path = output_dir / "wrapper_manifest.json"
        with wrapper_path.open("w", encoding="utf-8") as handle:
            json.dump(wrapper, handle, indent=2, sort_keys=True)
        print(
            "RMG_NATIVE_BATCH_EXPORT_PY status=fail error=godot_process_running "
            f"output_dir={output_dir} matches={len(preexisting_godot)} log={log_file}",
            file=sys.stderr,
        )
        return 1

    command = [
        str(native_cli),
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
    if args.phase_snapshot_only:
        command.append("--phase-snapshot-only")
    if args.native_map_json_only:
        command.append("--native-map-json-only")
    if args.emit_phase_snapshot:
        command.append("--emit-phase-snapshot")
    if args.emit_native_map_json:
        command.append("--emit-native-map-json")
    if args.print_manifest:
        command.append("--print-manifest")

    with log_file.open("w", encoding="utf-8") as handle:
        process = subprocess.run(
            command,
            cwd=ROOT,
            stdout=handle,
            stderr=subprocess.STDOUT,
            text=True,
            check=False,
        )

    manifest = load_manifest(output_dir)
    post_run_godot = godot_processes()
    pass_statuses = {"phase_snapshot_exported"}
    base_status = "pass" if process.returncode == 0 and manifest.get("status") in pass_statuses else "blocked"
    wrapper = {
        "schema_id": "rmg_native_batch_export_python_wrapper_v5",
        "status": "failed" if post_run_godot else base_status,
        "runner": "standalone_native_cli_no_godot",
        "native_cli": str(native_cli),
        "godot_process_started": bool(post_run_godot),
        "output_dir": str(output_dir),
        "log_path": str(log_file),
        "returncode": process.returncode,
        "manifest_status": manifest.get("status", ""),
        "blocked_reason": manifest.get("blocked_reason", ""),
        "exported_count": manifest.get("exported_count", 0),
        "failed_count": manifest.get("failed_count", 0),
        "case_count": manifest.get("case_count", 0),
        "blocked_count": manifest.get("blocked_count", 0),
        "unsupported_count": manifest.get("unsupported_count", 0),
        "skipped_count": manifest.get("skipped_count", 0),
        "phase_snapshot_only": manifest.get("phase_snapshot_only", False),
        "native_map_json_only": manifest.get("native_map_json_only", False),
        "native_map_json_exported_count": manifest.get("native_map_json_exported_count", 0),
        "native_map_json_failed_count": manifest.get("native_map_json_failed_count", 0),
        "phase_snapshot_exported_count": manifest.get("phase_snapshot_exported_count", 0),
        "phase_snapshot_failed_count": manifest.get("phase_snapshot_failed_count", 0),
        "generation_core_stage": manifest.get("generation_core_stage", ""),
        "phase_snapshot_schema_id": manifest.get("phase_snapshot_schema_id", ""),
        "native_map_json_schema_id": manifest.get("native_map_json_schema_id", ""),
        "control_policy": "python_invokes_standalone_native_cli_no_godot_and_refuses_when_godot_is_already_running",
        "case_scope": manifest.get("case_scope", ""),
        "godot_process_guard": {
            "status": "pass" if not post_run_godot else "fail",
            "preexisting_processes": [],
            "post_run_processes": post_run_godot,
        },
    }
    wrapper_path = output_dir / "wrapper_manifest.json"
    with wrapper_path.open("w", encoding="utf-8") as handle:
        json.dump(wrapper, handle, indent=2, sort_keys=True)

    print(
        "RMG_NATIVE_BATCH_EXPORT_PY status={status} output_dir={output_dir} "
        "exported={exported_count} native_map_json={native_map_json_exported_count} phase_snapshots={phase_snapshot_exported_count} "
        "failed={failed_count} log={log_path}".format(**wrapper)
    )
    if args.print_manifest:
        print(json.dumps(wrapper, indent=2, sort_keys=True))
    return 0 if wrapper["status"] == "pass" else 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runner", choices=["native-cli"], default="native-cli", help="Export runner. The only supported runner is the standalone native CLI.")
    parser.add_argument("--native-cli", default="", help="Standalone native CLI path, otherwise bin/rmg_native_batch_export_cli.")
    parser.add_argument("--out", type=Path, default=None, help="Output directory for native no-Godot artifacts and manifests.")
    parser.add_argument("--limit", type=int, default=0, help="Maximum owner cases to export.")
    parser.add_argument("--case", default="", help="Comma-separated case id filter.")
    parser.add_argument(
        "--controlled-case",
        action="append",
        default=[],
        help="Explicit native case as id:size_class:players:seed:water_mode:level_count[:human_count[:computer_count[:setup_object_0x44]]]. Bypasses owner filename inference.",
    )
    parser.add_argument(
        "--controlled-reference-manifest",
        action="append",
        type=Path,
        default=[],
        help="Build a controlled native case from a h3maped controlled_reference_manifest.json using the observed saved H3M identity.",
    )
    parser.add_argument("--include-unsupported", action="store_true", help="Export unsupported owner cases too; failures are expected for modes outside strict Small/Medium one-level land.")
    parser.add_argument("--emit-phase-snapshot", action="store_true", help="Ask the native runner to write per-case private h3maped phase snapshots for source-behavior debugging.")
    parser.add_argument("--phase-snapshot-only", action="store_true", help="Write supported controlled-case private-state snapshots through the standalone CLI and exit successfully without attempting .amap generation.")
    parser.add_argument("--emit-native-map-json", action="store_true", help="Deprecated blocked mode. Native map JSON output is disabled until final payload generation uses the shared recovered H3MapEd RMG core.")
    parser.add_argument("--native-map-json-only", action="store_true", help="Deprecated blocked mode. Use --phase-snapshot-only until final payload generation uses the shared recovered H3MapEd RMG core.")
    parser.add_argument("--print-manifest", action="store_true", help="Print wrapper manifest JSON.")
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        return run_native_cli_export(args)
    except Exception as exc:
        print(f"RMG_NATIVE_BATCH_EXPORT_PY status=fail error={exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
