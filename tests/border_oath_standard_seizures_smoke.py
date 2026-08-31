#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPORT_ID = "BORDER_OATH_STANDARD_SEIZURES_SMOKE"
REPORT_PATH = ROOT / ".artifacts/border_oath_standard_seizures_smoke/report.json"
CAPTURE_DIR = ROOT / ".artifacts/border_oath_standard_seizures_smoke/captures"
SCENE = "res://tests/border_oath_standard_seizures_smoke.tscn"


def main() -> int:
    godot = shutil.which("godot4")
    xvfb = shutil.which("xvfb-run")
    if not godot or not xvfb:
        print(f"{REPORT_ID} missing godot4 or xvfb-run", file=sys.stderr)
        return 2
    environment = os.environ.copy()
    environment["BORDER_OATH_CAPTURE_DIR"] = str(CAPTURE_DIR)
    completed = subprocess.run(
        [xvfb, "-a", godot, "--path", str(ROOT), "--scene", SCENE],
        cwd=ROOT, env=environment, text=True, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, timeout=600, check=False,
    )
    print(completed.stdout, end="")
    if completed.returncode != 0:
        return completed.returncode
    if not REPORT_PATH.is_file():
        print(f"{REPORT_ID} missing report: {REPORT_PATH}", file=sys.stderr)
        return 1
    report = json.loads(REPORT_PATH.read_text(encoding="utf-8"))
    expected = {
        "ok": True, "case_count": 6, "exact_standard_art_count": 6,
        "exact_cordon_art_count": 6, "initially_pending_count": 6,
        "wrong_site_control_count": 6, "two_of_three_pending_count": 6,
        "enemy_recapture_pending_count": 6, "scoped_dependency_count": 6,
        "unrelated_resource_skip_count": 6, "production_battle_count": 18,
        "production_claim_count": 18, "control_objective_count": 6,
        "scenario_victory_count": 6, "save_version": 9,
        "single_consolidated_smoke": True,
    }
    failures = [f"{key}={report.get(key)!r}, expected {value!r}" for key, value in expected.items() if report.get(key) != value]
    rows = report.get("rows", [])
    if len(rows) != 6 or any(not row.get("save_round_trip_exact") for row in rows):
        failures.append("all six rows must preserve exact save-version-9 control state")
    captures = sorted(CAPTURE_DIR.glob("*.png")) if CAPTURE_DIR.is_dir() else []
    if len(captures) != 6:
        failures.append(f"capture_count={len(captures)}, expected 6")
    if failures:
        print(f"{REPORT_ID} report mismatch: {'; '.join(failures)}", file=sys.stderr)
        return 1
    print(f"{REPORT_ID} VERIFIED {json.dumps(expected, sort_keys=True)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
