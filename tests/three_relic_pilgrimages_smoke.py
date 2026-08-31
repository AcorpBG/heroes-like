#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPORT_ID = "THREE_RELIC_PILGRIMAGES_SMOKE"
REPORT_PATH = ROOT / ".artifacts" / "three_relic_pilgrimages_smoke" / "report.json"
CAPTURE_DIR = ROOT / ".artifacts" / "three_relic_pilgrimages_smoke" / "captures"
SCENE = "res://tests/three_relic_pilgrimages_smoke.tscn"
TIMEOUT_SECONDS = 420


def main() -> int:
    godot = shutil.which("godot4")
    xvfb = shutil.which("xvfb-run")
    if not godot or not xvfb:
        print(f"{REPORT_ID} missing godot4 or xvfb-run", file=sys.stderr)
        return 2
    environment = os.environ.copy()
    environment["THREE_RELIC_PILGRIMAGE_CAPTURE_DIR"] = str(CAPTURE_DIR)
    try:
        completed = subprocess.run(
            [xvfb, "-a", godot, "--path", str(ROOT), "--scene", SCENE],
            cwd=ROOT,
            env=environment,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=TIMEOUT_SECONDS,
            check=False,
        )
    except subprocess.TimeoutExpired as exc:
        if exc.stdout:
            output = exc.stdout.decode(errors="replace") if isinstance(exc.stdout, bytes) else exc.stdout
            print(output, end="")
        print(f"{REPORT_ID} timed out after {TIMEOUT_SECONDS} seconds", file=sys.stderr)
        return 124
    if completed.stdout:
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
        "direct_lead_count": 6,
        "artifact_collection_count": 18,
        "scoped_dependency_count": 18,
        "battle_victory_count": 18,
        "exact_guardian_art_count": 6,
        "exact_artifact_art_count": 18,
        "missing_relic_control_count": 6,
        "transferred_relic_count": 6,
        "scenario_victory_count": 6,
        "save_version": 9,
        "single_consolidated_smoke": True,
    }
    failures = [f"{key}={report.get(key)!r}, expected {value!r}" for key, value in expected.items() if report.get(key) != value]
    rows = report.get("rows", [])
    if len(rows) != 6 or any(not row.get("save_round_trip_exact") for row in rows):
        failures.append("all six rows must be exact save-version-9 round-trips")
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
