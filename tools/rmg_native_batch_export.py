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


def monster_strength_raw_0x48_from_reference(value: str) -> int:
    normalized = value.strip().lower()
    # Recovered 0x49ecf2 arg8 values are 2, 2, 3, and 4 for the dialog's
    # Random, Weak, Normal, and Strong choices. 0x4adfe1 supplies raw + 3.
    return {
        "random": -1,
        "weak": -1,
        "normal": 0,
        "strong": 1,
    }.get(normalized, -1)


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
    monster_strength_raw_0x48 = monster_strength_raw_0x48_from_reference(
        str(inputs.get("monster_strength") or "random")
    )
    level_count = int(inputs.get("level_count") or parsed_summary.get("levels") or 1)
    return (
        f"{case_id}:{size_class}:{players}:{seed}:{water_mode}:{level_count}:"
        f"{humans}:{computers}:0:2:{monster_strength_raw_0x48}"
    )


def run_native_cli_export(args: argparse.Namespace) -> int:
    native_cli = find_native_cli(args.native_cli)
    output_dir = args.out or default_output_dir()
    output_dir = output_dir if output_dir.is_absolute() else ROOT / output_dir
    output_dir.mkdir(parents=True, exist_ok=True)
    log_file = output_dir / LOG_NAME
    if args.emit_native_map_json or args.native_map_json_only:
        wrapper = {
            "schema_id": "rmg_native_batch_export_python_wrapper_v7",
            "status": "blocked",
            "runner": "standalone_native_cli_no_godot",
            "native_cli": str(native_cli),
            "godot_process_started": False,
            "output_dir": str(output_dir),
            "log_path": str(log_file),
            "returncode": None,
            "error": "native_map_json_public_api_removed",
            "blocked_reason": "deprecated_native_map_json_output_remains_disabled; use the parity-gated runtime package projection instead",
            "required_mode": "--emit-final-h3m-payload or --emit-runtime-package",
            "control_policy": "python_wrapper_refuses_native_map_json_but_allows_owned_final_h3m_payload_and_parity_gated_runtime_package_output",
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
            "RMG_NATIVE_BATCH_EXPORT_PY status=blocked error=native_map_json_public_api_removed "
            f"output_dir={output_dir} required_mode=--emit-final-h3m-payload_or_--emit-runtime-package log={log_file}",
            file=sys.stderr,
        )
        return 1

    if not args.phase_snapshot_only and not args.emit_final_h3m_payload and not args.emit_runtime_package:
        wrapper = {
            "schema_id": "rmg_native_batch_export_python_wrapper_v7",
            "status": "blocked",
            "runner": "standalone_native_cli_no_godot",
            "native_cli": str(native_cli),
            "godot_process_started": False,
            "output_dir": str(output_dir),
            "log_path": str(log_file),
            "returncode": None,
            "error": "native_output_plain_cpp_core_not_available",
            "blocked_reason": "native_output_requires_phase_snapshot_diagnostics, owned final H3M payload export, or parity-gated runtime package output",
            "required_mode": "--phase-snapshot-only, --emit-final-h3m-payload, or --emit-runtime-package",
            "control_policy": "python_wrapper_refuses_native_map_json_but_allows_owned_final_h3m_payload_and_parity_gated_runtime_package_output",
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
            f"output_dir={output_dir} required_mode=--phase-snapshot-only_or_--emit-final-h3m-payload_or_--emit-runtime-package log={log_file}",
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
    shared_input_source = args.shared_input_source
    shared_rng_state_after_template_selection = args.shared_rng_state_after_template_selection
    shared_generator_mode_0x10b8 = args.shared_generator_mode_0x10b8
    shared_runtime_zone_seed_args = list(args.shared_runtime_zone_seed)
    shared_runtime_link_args = list(args.shared_runtime_link)
    if shared_input_source:
        command.extend(["--shared-input-source", shared_input_source])
    if shared_rng_state_after_template_selection is not None:
        command.extend(["--shared-rng-state-after-template-selection", str(shared_rng_state_after_template_selection)])
    if shared_generator_mode_0x10b8 is not None:
        command.extend(["--shared-generator-mode-0x10b8", str(shared_generator_mode_0x10b8)])
    if args.same_run_tile_payload_authority:
        command.extend(["--same-run-tile-payload-authority", str(args.same_run_tile_payload_authority)])
    if args.same_run_object_payload_authority:
        command.extend(["--same-run-object-payload-authority", str(args.same_run_object_payload_authority)])
    if args.same_run_full_payload_authority:
        command.extend(["--same-run-full-payload-authority", str(args.same_run_full_payload_authority)])
    if args.same_run_payload_summary:
        command.extend(["--same-run-payload-summary", str(args.same_run_payload_summary)])
    if args.same_run_ordered_writeout_spine_summary:
        command.extend(
            [
                "--same-run-ordered-writeout-spine-summary",
                str(args.same_run_ordered_writeout_spine_summary),
            ]
        )
    if args.same_run_preobject_trace_ledger:
        command.extend(["--same-run-preobject-trace-ledger", str(args.same_run_preobject_trace_ledger)])
    if args.same_run_setup_stack_boundary_ledger:
        command.extend(
            [
                "--same-run-setup-stack-boundary-ledger",
                str(args.same_run_setup_stack_boundary_ledger),
            ]
        )
    if args.same_run_river_entry_args_ledger:
        command.extend(
            [
                "--same-run-river-entry-args-ledger",
                str(args.same_run_river_entry_args_ledger),
            ]
        )
    if args.same_run_river_overlay_write_ledger:
        command.extend(
            [
                "--same-run-river-overlay-write-ledger",
                str(args.same_run_river_overlay_write_ledger),
            ]
        )
    if args.same_run_road_type_rng_ledger:
        command.extend(
            [
                "--same-run-road-type-rng-ledger",
                str(args.same_run_road_type_rng_ledger),
            ]
        )
    if args.same_run_road_coordinate_vector_ledger:
        command.extend(
            [
                "--same-run-road-coordinate-vector-ledger",
                str(args.same_run_road_coordinate_vector_ledger),
            ]
        )
    if args.same_run_road_callstream_ledger:
        command.extend(
            [
                "--same-run-road-callstream-ledger",
                str(args.same_run_road_callstream_ledger),
            ]
        )
    if args.same_run_road_type_write_ledger:
        command.extend(
            [
                "--same-run-road-type-write-ledger",
                str(args.same_run_road_type_write_ledger),
            ]
        )
    if args.same_run_road_art_write_ledger:
        command.extend(
            [
                "--same-run-road-art-write-ledger",
                str(args.same_run_road_art_write_ledger),
            ]
        )
    for runtime_zone_seed in shared_runtime_zone_seed_args:
        command.extend(["--shared-runtime-zone-seed", runtime_zone_seed])
    for runtime_link in shared_runtime_link_args:
        command.extend(["--shared-runtime-link", runtime_link])
    if args.include_unsupported:
        command.append("--include-unsupported")
    if args.phase_snapshot_only:
        command.append("--phase-snapshot-only")
    if args.emit_final_h3m_payload:
        command.append("--emit-final-h3m-payload")
    if args.emit_runtime_package:
        command.append("--emit-runtime-package")
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
    manifest_status = str(manifest.get("status", "blocked"))
    base_status = "pass" if process.returncode == 0 and manifest_status == "complete" else "blocked"
    if process.returncode not in (0, 2):
        base_status = "failed"
    wrapper = {
        "schema_id": "rmg_native_batch_export_python_wrapper_v7",
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
        "emit_final_h3m_payload": manifest.get("emit_final_h3m_payload", False),
        "emit_runtime_package": manifest.get("emit_runtime_package", False),
        "native_map_json_only": manifest.get("native_map_json_only", False),
        "native_map_json_exported_count": manifest.get("native_map_json_exported_count", 0),
        "native_map_json_failed_count": manifest.get("native_map_json_failed_count", 0),
        "native_h3m_payload_exported_count": manifest.get("native_h3m_payload_exported_count", 0),
        "native_h3m_payload_ready_count": manifest.get("native_h3m_payload_ready_count", 0),
        "native_h3m_payload_failed_count": manifest.get("native_h3m_payload_failed_count", 0),
        "runtime_package_exported_count": manifest.get("runtime_package_exported_count", 0),
        "runtime_package_failed_count": manifest.get("runtime_package_failed_count", 0),
        "runtime_payload_projection_applied_count": manifest.get("runtime_payload_projection_applied_count", 0),
        "phase_snapshot_exported_count": manifest.get("phase_snapshot_exported_count", 0),
        "phase_snapshot_written_count": manifest.get("phase_snapshot_written_count", 0),
        "phase_snapshot_failed_count": manifest.get("phase_snapshot_failed_count", 0),
        "final_payload_binary_written_count": manifest.get("final_payload_binary_written_count", 0),
        "final_payload_sections_written_count": manifest.get("final_payload_sections_written_count", 0),
        "shared_input_source": manifest.get("shared_input_source", ""),
        "shared_runtime_zone_seed_count": manifest.get("shared_runtime_zone_seed_count", 0),
        "shared_runtime_link_count": manifest.get("shared_runtime_link_count", 0),
        "shared_rng_state_after_template_selection_known": manifest.get("shared_rng_state_after_template_selection_known", False),
        "shared_generator_mode_0x10b8_known": manifest.get("shared_generator_mode_0x10b8_known", False),
        "shared_coordinate_owner_grid_chain_executed_count": manifest.get("shared_coordinate_owner_grid_chain_executed_count", 0),
        "generation_core_stage": manifest.get("generation_core_stage", ""),
        "phase_snapshot_schema_id": manifest.get("phase_snapshot_schema_id", ""),
        "native_map_json_schema_id": manifest.get("native_map_json_schema_id", ""),
        "native_h3m_payload_schema_id": manifest.get("native_h3m_payload_schema_id", ""),
        "runtime_map_package_schema_id": manifest.get("runtime_map_package_schema_id", ""),
        "runtime_scenario_package_schema_id": manifest.get("runtime_scenario_package_schema_id", ""),
        "control_policy": "python_invokes_standalone_native_cli_no_godot_refuses_godot_and_allows_owned_final_h3m_payload_and_parity_gated_runtime_package_output",
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
        "exported={exported_count} native_map_json={native_map_json_exported_count} native_h3m_payload={native_h3m_payload_exported_count} runtime_packages={runtime_package_exported_count} phase_snapshots={phase_snapshot_exported_count} "
        "phase_snapshots_written={phase_snapshot_written_count} final_payload_binaries={final_payload_binary_written_count} "
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
        help="Explicit native case as id:size_class:players:seed:water_mode:level_count[:human_count[:computer_count[:setup_object_0x44[:setup_object_0x4c[:setup_object_0x48]]]]]. Bypasses owner filename inference.",
    )
    parser.add_argument(
        "--controlled-reference-manifest",
        action="append",
        type=Path,
        default=[],
        help="Build a controlled native case from a h3maped controlled_reference_manifest.json using the observed saved H3M identity.",
    )
    parser.add_argument("--include-unsupported", action="store_true", help="Export unsupported owner cases too; failures are expected for modes outside strict Small/Medium one-level land.")
    parser.add_argument("--shared-input-source", default="", help="Label for explicit recovered runtime inputs passed to the shared H3MapEd chain.")
    parser.add_argument("--shared-rng-state-after-template-selection", type=int, default=None, help="Exact H3MapEd RNG state after template selection for the shared coordinate/owner-grid chain.")
    parser.add_argument("--shared-generator-mode-0x10b8", type=int, default=None, help="Exact generator mode field consumed by the shared 0x4a2777/0x4a325d chain.")
    parser.add_argument("--same-run-tile-payload-authority", type=Path, default=None, help="Recovered same-run H3MapEd 0x49b2b6 tile payload bytes for final compare.")
    parser.add_argument("--same-run-object-payload-authority", type=Path, default=None, help="Recovered same-run H3MapEd 0x4ad1e3 generated-object payload bytes for final compare.")
    parser.add_argument("--same-run-full-payload-authority", type=Path, default=None, help="Recovered same-run complete H3MapEd 0x4ac857..0x4ad3db payload bytes for the decisive eight-section compare.")
    parser.add_argument("--same-run-payload-summary", type=Path, default=None, help="Recovered same-run H3MapEd final tile/object payload summary for authority profile and counts.")
    parser.add_argument("--same-run-ordered-writeout-spine-summary", type=Path, default=None, help="Recovered same-run ordered writeout spine summary used for 0x49ecf2 setup-stack identity.")
    parser.add_argument("--same-run-preobject-trace-ledger", type=Path, default=None, help="Recovered same-run 0x4a4c8e preobject trace ledger used for generator setup +0x4c.")
    parser.add_argument("--same-run-setup-stack-boundary-ledger", type=Path, default=None, help="Recovered same-run 0x49ecf2 setup-stack boundary ledger used for final payload authority identity.")
    parser.add_argument("--same-run-river-entry-args-ledger", type=Path, default=None, help="Recovered same-run 0x4ab6ac/0x4abd5f river entry stack-argument ledger used for river post-pass authority.")
    parser.add_argument("--same-run-river-overlay-write-ledger", type=Path, default=None, help="Recovered same-run 0x49b1bc/0x49b170 river overlay write ledger used for river post-pass authority.")
    parser.add_argument("--same-run-road-type-rng-ledger", type=Path, default=None, help="Recovered same-run 0x4ab53a road-type RNG ledger used for road type selection authority.")
    parser.add_argument("--same-run-road-coordinate-vector-ledger", type=Path, default=None, help="Recovered same-run 0x4ab52a road coordinate-vector ledger used for road adjacency authority.")
    parser.add_argument("--same-run-road-callstream-ledger", type=Path, default=None, help="Recovered same-run 0x4ab37f road helper callstream ledger used for road candidate invocation authority.")
    parser.add_argument("--same-run-road-type-write-ledger", type=Path, default=None, help="Recovered same-run 0x49aec5 road type write ledger used for internal road materialization authority.")
    parser.add_argument("--same-run-road-art-write-ledger", type=Path, default=None, help="Recovered same-run 0x49ae47 road art write ledger used for internal road art/flip authority.")
    parser.add_argument(
        "--shared-runtime-zone-seed",
        action="append",
        default=[],
        help="Repeatable exact runtime-zone seed tuple: runtime_zone_index,source_zone_id,source_index,h3maped_zone_word_id,source_bucket,actual_player_color,source_base_size[,allowed_town_mask,selected_town_choice,terrain_match,allowed_terrain_mask,source_owner_index,fixed_town_choice,source_order_selector_field_0x40].",
    )
    parser.add_argument(
        "--shared-runtime-link",
        action="append",
        default=[],
        help="Repeatable exact runtime link tuple: from_runtime_zone_index,to_runtime_zone_index[,guard_value,wide,border_guard].",
    )
    parser.add_argument("--emit-phase-snapshot", action="store_true", help="Ask the native runner to write per-case private h3maped phase snapshots for source-behavior debugging.")
    parser.add_argument("--phase-snapshot-only", action="store_true", help="Write supported controlled-case diagnostic snapshots through the standalone CLI and exit blocked until the shared recovered H3MapEd RMG core owns payload generation.")
    parser.add_argument("--emit-final-h3m-payload", action="store_true", help="Export the owned final H3M payload bytes only after the shared recovered H3MapEd RMG core proves final payload parity for the controlled case.")
    parser.add_argument("--emit-runtime-package", action="store_true", help="Export paired .amap/.ascenario packages only after no-replay final payload parity and exact runtime projection succeed for the controlled case.")
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
