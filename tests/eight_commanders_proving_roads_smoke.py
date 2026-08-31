#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPORT_ID = "EIGHT_COMMANDERS_PROVING_ROADS_SMOKE"
REPORT_PATH = ROOT / ".artifacts/eight_commanders_proving_roads_smoke/report.json"
CAPTURE_DIR = ROOT / ".artifacts/eight_commanders_proving_roads_smoke/captures"
SCENE = "res://tests/eight_commanders_proving_roads_smoke.tscn"


def main() -> int:
    godot = shutil.which("godot4")
    xvfb = shutil.which("xvfb-run")
    if not godot or not xvfb:
        print(f"{REPORT_ID} missing godot4 or xvfb-run", file=sys.stderr)
        return 2
    environment = os.environ.copy()
    environment["EIGHT_COMMANDERS_PROVING_ROADS_CAPTURE_DIR"] = str(CAPTURE_DIR)
    completed = subprocess.run([xvfb, "-a", godot, "--path", str(ROOT), "--scene", SCENE], cwd=ROOT, env=environment, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=600, check=False)
    print(completed.stdout, end="")
    if completed.returncode != 0:
        return completed.returncode
    if not REPORT_PATH.is_file():
        print(f"{REPORT_ID} missing report: {REPORT_PATH}", file=sys.stderr)
        return 1
    report = json.loads(REPORT_PATH.read_text(encoding="utf-8"))
    expected = {"ok": True, "case_count": 8, "exact_art_count": 8, "wrong_hero_control_count": 8, "level_three_control_count": 8, "pending_choice_control_count": 8, "production_claim_count": 8, "production_battle_count": 24, "specialty_choice_count": 24, "scoped_dependency_count": 8, "scenario_victory_count": 8, "save_version": 9, "single_consolidated_smoke": True}
    failures = [f"{key}={report.get(key)!r}, expected {value!r}" for key, value in expected.items() if report.get(key) != value]
    rows = report.get("rows", [])
    if len(rows) != 8 or any(not row.get("save_round_trip_exact") or int(row.get("completion_day", 99)) >= 16 for row in rows):
        failures.append("all eight rows must be exact pre-Day-16 save-version-9 round-trips")
    captures = sorted(CAPTURE_DIR.glob("*.png")) if CAPTURE_DIR.is_dir() else []
    if len(captures) != 8:
        failures.append(f"capture_count={len(captures)}, expected 8")
    if failures:
        print(f"{REPORT_ID} report mismatch: {'; '.join(failures)}", file=sys.stderr)
        return 1
    print(f"{REPORT_ID} VERIFIED {json.dumps(expected, sort_keys=True)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
