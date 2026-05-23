#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT_DIR = ROOT / ".artifacts" / "headless_balance_harness_cli"

SUITES = {
    "standard": [
        {
            "id": "battle_autoplay_combat_balance",
            "marker": "BATTLE_AUTOPLAY_COMBAT_BALANCE_REPORT",
            "scene": "res://tests/battle_autoplay_combat_balance_report.tscn",
            "timeout": 180,
        },
        {
            "id": "balance_regression_suite",
            "marker": "BALANCE_REGRESSION_REPORT_SUITE",
            "scene": "res://tests/balance_regression_report_suite.tscn",
            "timeout": 180,
        },
        {
            "id": "headless_simulation_harness",
            "marker": "HEADLESS_SIMULATION_HARNESS_REPORT",
            "scene": "res://tests/headless_simulation_harness_report.tscn",
            "timeout": 240,
        },
    ],
    "full": [
        {
            "id": "battle_autoplay_combat_balance",
            "marker": "BATTLE_AUTOPLAY_COMBAT_BALANCE_REPORT",
            "scene": "res://tests/battle_autoplay_combat_balance_report.tscn",
            "timeout": 180,
        },
        {
            "id": "battle_autoplay_difficulty_sweep",
            "marker": "BATTLE_AUTOPLAY_DIFFICULTY_SWEEP_REPORT",
            "scene": "res://tests/battle_autoplay_difficulty_sweep_report.tscn",
            "timeout": 180,
        },
        {
            "id": "battle_autoplay_runtime_consequence_matrix",
            "marker": "BATTLE_AUTOPLAY_RUNTIME_CONSEQUENCE_MATRIX_REPORT",
            "scene": "res://tests/battle_autoplay_runtime_consequence_matrix_report.tscn",
            "timeout": 180,
        },
        {
            "id": "battle_autoplay_tuning_queue",
            "marker": "BATTLE_AUTOPLAY_BALANCE_TUNING_QUEUE_REPORT",
            "scene": "res://tests/battle_autoplay_balance_tuning_queue_report.tscn",
            "timeout": 180,
        },
        {
            "id": "balance_regression_suite",
            "marker": "BALANCE_REGRESSION_REPORT_SUITE",
            "scene": "res://tests/balance_regression_report_suite.tscn",
            "timeout": 180,
        },
        {
            "id": "headless_simulation_harness",
            "marker": "HEADLESS_SIMULATION_HARNESS_REPORT",
            "scene": "res://tests/headless_simulation_harness_report.tscn",
            "timeout": 240,
        },
    ],
}

FORBIDDEN_POLICY_FLAGS = (
    "automatic_tuning",
    "runtime_balance_changes",
    "authored_content_writeback",
    "manual_play_replacement",
    "alpha_or_parity_claim",
)


def main() -> int:
    parser = argparse.ArgumentParser(description="Run the Godot headless balance harness and write artifact reports.")
    parser.add_argument("--suite", choices=sorted(SUITES), default="standard")
    parser.add_argument("--godot", default=os.environ.get("GODOT_BIN", "godot"))
    parser.add_argument("--out", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--list", action="store_true", help="List selected suite cases without running Godot.")
    parser.add_argument("--keep-going", action="store_true", help="Run remaining cases after a failure and return non-zero at the end.")
    args = parser.parse_args()

    cases = SUITES[args.suite]
    if args.list:
        for case in cases:
            print(f"{case['id']} {case['scene']} {case['marker']}")
        return 0

    output_dir = args.out.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    manifest = {
        "schema": "headless_balance_harness_cli_v1",
        "suite": args.suite,
        "started_at": utc_now(),
        "project_root": str(ROOT),
        "godot": args.godot,
        "report_only_policy": {
            "automatic_tuning": False,
            "runtime_balance_changes": False,
            "authored_content_writeback": False,
            "manual_play_replacement": False,
            "alpha_or_parity_claim": False,
        },
        "cases": [],
    }
    failed = False
    for case in cases:
        result = run_case(args.godot, case, output_dir)
        manifest["cases"].append(result)
        if result["status"] != "pass":
            failed = True
            if not args.keep_going:
                break
    manifest["finished_at"] = utc_now()
    manifest["case_count"] = len(manifest["cases"])
    manifest["passed_count"] = sum(1 for case in manifest["cases"] if case.get("status") == "pass")
    manifest["failed_count"] = sum(1 for case in manifest["cases"] if case.get("status") != "pass")
    manifest["ok"] = not failed
    manifest["manifest_path"] = str(output_dir / "manifest.json")
    (output_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(compact_manifest(manifest), indent=2))
    return 0 if manifest["ok"] else 1


def run_case(godot_bin: str, case: dict[str, object], output_dir: Path) -> dict[str, object]:
    case_id = str(case["id"])
    marker = str(case["marker"])
    command = [
        godot_bin,
        "--headless",
        "--path",
        str(ROOT),
        "--quit-after",
        str(int(case["timeout"])),
        "--scene",
        str(case["scene"]),
    ]
    env = os.environ.copy()
    env.setdefault("GODOT_SILENCE_ROOT_WARNING", "1")
    started = time.monotonic()
    completed = subprocess.run(command, cwd=ROOT, env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    duration_msec = int((time.monotonic() - started) * 1000.0)
    output = completed.stdout or ""
    output_path = output_dir / f"{case_id}.log"
    output_path.write_text(output, encoding="utf-8")
    marker_payload = extract_marker_payload(output, marker)
    policy_violations = policy_violations_for(marker_payload)
    status = "pass"
    failure_reasons: list[str] = []
    if completed.returncode != 0:
        status = "fail"
        failure_reasons.append(f"exit_code_{completed.returncode}")
    if not marker_payload:
        status = "fail"
        failure_reasons.append("missing_marker_payload")
    if policy_violations:
        status = "fail"
        failure_reasons.append("report_only_policy_violation")
    return {
        "id": case_id,
        "scene": str(case["scene"]),
        "marker": marker,
        "status": status,
        "exit_code": completed.returncode,
        "duration_msec": duration_msec,
        "command": command,
        "output_path": str(output_path),
        "summary": marker_payload,
        "report_signature": signature_from_payload(marker_payload),
        "report_status": report_status_from_payload(marker_payload),
        "policy_violations": policy_violations,
        "failure_reasons": failure_reasons,
    }


def extract_marker_payload(output: str, marker: str) -> dict[str, object]:
    prefix = f"{marker} "
    for line in reversed(output.splitlines()):
        if line.startswith(prefix):
            payload_text = line[len(prefix) :].strip()
            try:
                parsed = json.loads(payload_text)
            except json.JSONDecodeError:
                return {}
            return parsed if isinstance(parsed, dict) else {}
    return {}


def policy_violations_for(payload: dict[str, object]) -> list[str]:
    policy = payload.get("reporting_policy", {})
    if not isinstance(policy, dict):
        policy = {}
    violations: list[str] = []
    for flag in FORBIDDEN_POLICY_FLAGS:
        if bool(policy.get(flag, False)):
            violations.append(flag)
    return violations


def signature_from_payload(payload: dict[str, object]) -> str:
    for key in ("harness_signature", "suite_signature", "report_signature", "sweep_signature", "queue_signature"):
        value = payload.get(key)
        if isinstance(value, str) and value:
            return value
    if payload:
        serialized = json.dumps(payload, sort_keys=True, separators=(",", ":"))
        return hashlib.sha256(serialized.encode("utf-8")).hexdigest()[:8]
    return ""


def report_status_from_payload(payload: dict[str, object]) -> str:
    if not payload:
        return ""
    value = payload.get("status")
    if isinstance(value, str) and value:
        return value
    return "pass" if bool(payload.get("ok", False)) else "fail"


def compact_manifest(manifest: dict[str, object]) -> dict[str, object]:
    return {
        "ok": manifest.get("ok", False),
        "schema": manifest.get("schema", ""),
        "suite": manifest.get("suite", ""),
        "case_count": manifest.get("case_count", 0),
        "passed_count": manifest.get("passed_count", 0),
        "failed_count": manifest.get("failed_count", 0),
        "manifest_path": manifest.get("manifest_path", ""),
        "cases": [
            {
                "id": case.get("id", ""),
                "status": case.get("status", ""),
                "report_status": case.get("report_status", ""),
                "report_signature": case.get("report_signature", ""),
                "duration_msec": case.get("duration_msec", 0),
            }
            for case in manifest.get("cases", [])
            if isinstance(case, dict)
        ],
    }


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


if __name__ == "__main__":
    sys.exit(main())
