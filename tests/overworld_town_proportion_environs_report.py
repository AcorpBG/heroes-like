#!/usr/bin/env python3
"""Run the focused #10236 town proportion and environs visual report."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPORT_ID = "OVERWORLD_TOWN_PROPORTION_ENVIRONS_REPORT"
SCENE = "res://tests/overworld_town_proportion_environs_report.tscn"
ARTIFACT_DIR = ROOT / ".artifacts" / "overworld_town_proportion_environs_10236"
REPORT_PATH = ARTIFACT_DIR / "report.json"


def main() -> int:
    godot = shutil.which("godot4") or shutil.which("godot")
    xvfb = shutil.which("xvfb-run")
    if not godot or not xvfb:
        print(f"{REPORT_ID}: godot4 and xvfb-run are required", file=sys.stderr)
        return 2
    ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
    completed = subprocess.run(
        [xvfb, "-a", "-s", "-screen 0 2200x1200x24", godot, "--path", str(ROOT), "--scene", SCENE],
        cwd=ROOT,
        env=os.environ.copy(),
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=300,
        check=False,
    )
    print(completed.stdout, end="")
    marker = next((line for line in completed.stdout.splitlines() if line.startswith(f"{REPORT_ID} {{")), "")
    if completed.returncode or not marker:
        return completed.returncode or 1
    payload = json.loads(marker.removeprefix(f"{REPORT_ID} "))
    captures = [Path(path) for path in payload.get("captures", [])]
    expected = {
        "ok": True,
        "session_authority_exact": True,
        "native_rmg_output_changed": False,
    }
    failures = [f"{key}={payload.get(key)!r}, expected {value!r}" for key, value in expected.items() if payload.get(key) != value]
    if payload.get("town", {}).get("all_aspects_preserved") is not True:
        failures.append("town aspects are not preserved")
    if payload.get("town", {}).get("riverwatch_landset_exact") is not True:
        failures.append("Riverwatch land-set identity is not exact")
    if payload.get("environs", {}).get("exact") is not True:
        failures.append("Riverwatch environs are not exact")
    if len(captures) != 2 or any(not path.is_file() or path.stat().st_size < 10_000 for path in captures):
        failures.append(f"capture evidence incomplete: {captures}")
    if failures:
        print(f"{REPORT_ID}: {'; '.join(failures)}", file=sys.stderr)
        return 1
    REPORT_PATH.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"{REPORT_ID}: PASS towns={payload['town']['profile_count']} environs={payload['environs']['placement_count']} captures={len(captures)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
