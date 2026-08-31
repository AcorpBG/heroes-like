#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPORT_ID = "GARRISON_WARRANT_MUSTERS_SMOKE"
REPORT_PATH = ROOT / ".artifacts" / "garrison_warrant_musters_smoke" / "report.json"
CAPTURE_DIR = ROOT / ".artifacts" / "garrison_warrant_musters_smoke" / "captures"
SCENE = "res://tests/garrison_warrant_musters_smoke.tscn"


def main() -> int:
    godot = shutil.which("godot4")
    xvfb = shutil.which("xvfb-run")
    if not godot or not xvfb:
        print(f"{REPORT_ID} missing godot4 or xvfb-run", file=sys.stderr)
        return 2
    environment = os.environ.copy()
    environment["GARRISON_WARRANT_MUSTERS_CAPTURE_DIR"] = str(CAPTURE_DIR)
    try:
        completed = subprocess.run(
            [xvfb, "-a", godot, "--path", str(ROOT), "--scene", SCENE],
            cwd=ROOT,
            env=environment,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=600,
            check=False,
        )
    except subprocess.TimeoutExpired as error:
        print(error.stdout or "", end="")
        print(f"{REPORT_ID} timed out after 600 seconds", file=sys.stderr)
        return 1
    print(completed.stdout, end="")
    if completed.returncode != 0:
        return completed.returncode
    if not REPORT_PATH.is_file():
        print(f"{REPORT_ID} missing report: {REPORT_PATH}", file=sys.stderr)
        return 1
    report = json.loads(REPORT_PATH.read_text(encoding="utf-8"))
    expected = {
        "ok": True,
        "case_count": 6,
        "exact_art_count": 6,
        "wrong_town_control_count": 6,
        "enemy_owned_town_control_count": 6,
        "hero_carried_control_count": 6,
        "partial_garrison_control_count": 6,
        "production_battle_count": 18,
        "production_claim_count": 6,
        "production_transfer_count": 18,
        "scoped_dependency_count": 6,
        "unrelated_event_skip_count": 6,
        "scenario_victory_count": 6,
        "save_version": 9,
        "single_consolidated_smoke": True,
    }
    failures = [f"{key}={report.get(key)!r}, expected {value!r}" for key, value in expected.items() if report.get(key) != value]
    rows = report.get("rows", [])
    if len(rows) != 6 or any(not row.get("save_round_trip_exact") or int(row.get("completion_day", 99)) >= 18 for row in rows):
        failures.append("all six rows must be exact pre-Day-18 save-version-9 round-trips")
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
