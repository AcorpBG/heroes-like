#!/usr/bin/env python3
from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPORT_ID = "SEVENFOLD_HIGH_ARCANUM_SMOKE"
REPORT_PATH = ROOT / ".artifacts" / "sevenfold_high_arcanum_smoke" / "report.json"
SCENE = "res://tests/sevenfold_high_arcanum_smoke.tscn"


def main() -> int:
    godot = shutil.which("godot4")
    xvfb = shutil.which("xvfb-run")
    if not godot or not xvfb:
        print(f"{REPORT_ID} missing godot4 or xvfb-run", file=sys.stderr)
        return 2
    completed = subprocess.run(
        [xvfb, "-a", godot, "--path", str(ROOT), "--scene", SCENE],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=300,
        check=False,
    )
    print(completed.stdout, end="")
    if completed.returncode != 0:
        return completed.returncode
    if not REPORT_PATH.is_file():
        print(f"{REPORT_ID} missing report: {REPORT_PATH}", file=sys.stderr)
        return 1
    report = json.loads(REPORT_PATH.read_text(encoding="utf-8"))
    expected = {"ok": True, "case_count": 7, "claim_count": 7, "battle_resolution_count": 7, "save_version": 9, "single_consolidated_smoke": True}
    failures = [f"{key}={report.get(key)!r}, expected {value!r}" for key, value in expected.items() if report.get(key) != value]
    if failures:
        print(f"{REPORT_ID} report mismatch: {'; '.join(failures)}", file=sys.stderr)
        return 1
    print(f"{REPORT_ID} VERIFIED {json.dumps(expected, sort_keys=True)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
