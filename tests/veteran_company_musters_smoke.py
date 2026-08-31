#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPORT_ID = "VETERAN_COMPANY_MUSTERS_SMOKE"
OUTPUT_DIR = ROOT / ".artifacts" / "veteran_company_musters_smoke"
REPORT_PATH = OUTPUT_DIR / "report.json"
CAPTURE_DIR = OUTPUT_DIR / "captures"
CONTACT_SHEET = OUTPUT_DIR / "veteran_company_musters_contact_sheet.png"
SCENE = "res://tests/veteran_company_musters_smoke.tscn"
TIMEOUT_SECONDS = 420


def main() -> int:
    godot = shutil.which("godot4")
    xvfb = shutil.which("xvfb-run")
    montage = shutil.which("montage")
    if not godot or not xvfb or not montage:
        print(f"{REPORT_ID} missing godot4, xvfb-run, or montage", file=sys.stderr)
        return 2
    environment = os.environ.copy()
    environment["VETERAN_COMPANY_MUSTER_CAPTURE_DIR"] = str(CAPTURE_DIR)
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
        "battle_victory_count": 18,
        "target_unit_count": 18,
        "blocked_claim_count": 6,
        "live_claim_count": 6,
        "weekly_delivery_count": 6,
        "exact_two_state_art_count": 6,
        "scenario_victory_count": 6,
        "save_round_trip_count": 6,
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
    if not failures:
        contact = subprocess.run(
            [montage, *map(str, captures), "-tile", "3x2", "-geometry", "640x360+8+8", str(CONTACT_SHEET)],
            cwd=ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            check=False,
        )
        if contact.returncode != 0 or not CONTACT_SHEET.is_file():
            failures.append(f"contact sheet failed: {contact.stdout.strip()}")
    if failures:
        print(f"{REPORT_ID} report mismatch: {'; '.join(failures)}", file=sys.stderr)
        return 1
    print(f"{REPORT_ID} VERIFIED {json.dumps(expected, sort_keys=True)}")
    print(f"{REPORT_ID} CONTACT_SHEET {CONTACT_SHEET}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
