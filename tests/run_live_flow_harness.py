#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_FLOW = "boot_to_skirmish_resolved_outcome"
DEFEAT_OUTCOME_FLOW = "boot_to_skirmish_defeat_outcome"
CAMPAIGN_OUTCOME_FLOW = "boot_to_campaign_resolved_outcome"
CAMPAIGN_DEFEAT_OUTCOME_FLOW = "boot_to_campaign_defeat_outcome"
DEFAULT_DISPLAY = ":99"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run the repo-local live Godot validation harness.")
    parser.add_argument(
        "--flow",
        default=DEFAULT_FLOW,
        help=f"Harness flow id to run. Use {DEFEAT_OUTCOME_FLOW} for skirmish defeat, {CAMPAIGN_OUTCOME_FLOW} for campaign victory, or {CAMPAIGN_DEFEAT_OUTCOME_FLOW} for campaign defeat validation.",
    )
    parser.add_argument("--campaign", default="campaign_reedfall", help="Campaign id to select through the real campaign browser.")
    parser.add_argument("--scenario", default="river-pass", help="Scenario id to launch through the real menu.")
    parser.add_argument("--difficulty", default="normal", help="Difficulty id to select before launch.")
    parser.add_argument("--manual-slot", type=int, default=2, help="Manual slot id to use for routed save/resume validation.")
    parser.add_argument("--display", default=os.environ.get("DISPLAY", DEFAULT_DISPLAY), help="Display to use for the live Godot client.")
    parser.add_argument("--godot-bin", default=os.environ.get("GODOT_BIN", ""), help="Path to the Godot executable.")
    parser.add_argument(
        "--output-root",
        default=str(ROOT / ".artifacts" / "live_flow_smoke"),
        help="Base directory for logs, report JSON, screenshots, and isolated user data.",
    )
    return parser.parse_args()


def find_godot(explicit: str) -> str:
    candidates = [explicit, "godot4", "godot"]
    for candidate in candidates:
        if not candidate:
            continue
        resolved = shutil.which(candidate) if os.sep not in candidate else candidate
        if resolved and Path(resolved).exists():
            return resolved
    raise FileNotFoundError("Could not find a Godot executable. Use --godot-bin or set GODOT_BIN.")


def make_run_dir(root: Path) -> Path:
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    run_dir = root / stamp
    run_dir.mkdir(parents=True, exist_ok=False)
    return run_dir


def main() -> int:
    args = parse_args()
    godot_bin = find_godot(args.godot_bin)
    run_dir = make_run_dir(Path(args.output_root))
    env = os.environ.copy()
    env["DISPLAY"] = args.display
    env["XDG_DATA_HOME"] = str((run_dir / "xdg_data").resolve())

    command = [
        godot_bin,
        "--path",
        str(ROOT),
        "--",
        f"--live-validation-flow={args.flow}",
        f"--live-validation-campaign={args.campaign}",
        f"--live-validation-scenario={args.scenario}",
        f"--live-validation-difficulty={args.difficulty}",
        f"--live-validation-manual-slot={args.manual_slot}",
        f"--live-validation-output={run_dir}",
    ]
    print("Running:", " ".join(command))
    result = subprocess.run(command, cwd=ROOT, env=env)

    report_path = run_dir / "live_validation_report.json"
    if not report_path.exists():
        print(f"Live validation report not found at {report_path}", file=sys.stderr)
        return result.returncode or 1

    report = json.loads(report_path.read_text())
    print(f"Report: {report_path}")
    print(f"Log: {run_dir / 'live_validation.log'}")
    print(f"OK: {report.get('ok', False)}")
    print(f"Flow: {report.get('flow', '')}")
    print(f"Campaign: {report.get('campaign_id', '')}")
    print(f"Scenario: {report.get('scenario_id', '')} @ {report.get('difficulty', '')}")
    print(f"Manual slot: {report.get('manual_slot', 0)}")
    print(f"Steps: {len(report.get('steps', []))}")
    for step in report.get("steps", []):
        print(f"- {step.get('id', '')}: {step.get('scene_path', '')} :: {step.get('screenshot', '')}")
    for error in report.get("errors", []):
        print(f"ERROR: {error.get('message', '')}", file=sys.stderr)

    if result.returncode != 0:
        return result.returncode
    return 0 if report.get("ok", False) else 1


if __name__ == "__main__":
    raise SystemExit(main())
