#!/usr/bin/env python3
"""Run the focused generated-Medium raster terrain and blocker-mass report."""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPORT_ID = "OVERWORLD_RASTER_TERRAIN_BLOCKER_MASS_REPORT"
SCENE = "res://tests/overworld_raster_terrain_blocker_mass_report.tscn"


def main() -> int:
    godot = shutil.which("godot4") or shutil.which("godot")
    xvfb = shutil.which("xvfb-run")
    if not godot or not xvfb:
        print(f"{REPORT_ID} requires Godot 4 and xvfb-run", file=sys.stderr)
        return 2
    completed = subprocess.run(
        [xvfb, "-a", "-s", "-screen 0 1920x1080x24", godot, "--path", str(ROOT), "--scene", SCENE],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=420,
        check=False,
    )
    print(completed.stdout, end="")
    if completed.returncode:
        return completed.returncode
    marker = next((line for line in completed.stdout.splitlines() if line.startswith(f"{REPORT_ID} {{")), "")
    if not marker:
        print(f"{REPORT_ID} did not publish a result", file=sys.stderr)
        return 1
    payload = json.loads(marker.removeprefix(f"{REPORT_ID} "))
    expected = {
        "ok": True,
        "uncovered_body_tile_count": 0,
        "all_body_cells_visually_covered": True,
        "all_body_assets_loaded": True,
        "all_body_assets_terrain_matched": True,
        "session_authority_exact": True,
        "collision_authority_exact": True,
        "native_rmg_output_changed": False,
    }
    failures = [f"{key}={payload.get(key)!r}, expected {value!r}" for key, value in expected.items() if payload.get(key) != value]
    terrain = payload.get("terrain", {})
    if terrain.get("procedural_microtexture_tile_count") != 0 or terrain.get("procedural_microtexture_draw_calls") != 0:
        failures.append("procedural terrain scratches remain active")
    rows = payload.get("rows", [])
    if len(rows) != 2 or not all(row.get("capture_written") for row in rows):
        failures.append("responsive screenshot evidence is incomplete")
    if failures:
        print(f"{REPORT_ID} mismatch: {'; '.join(failures)}", file=sys.stderr)
        return 1
    print(f"{REPORT_ID} VERIFIED {json.dumps(expected, sort_keys=True)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
