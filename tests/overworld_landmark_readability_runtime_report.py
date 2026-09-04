#!/usr/bin/env python3
"""Run the focused Overworld semantic-scale and town-landmark report."""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPORT_ID = "OVERWORLD_LANDMARK_READABILITY_RUNTIME_REPORT"
SCENE = "res://tests/overworld_landmark_readability_runtime_report.tscn"


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
        timeout=300,
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
        "semantic_scale_exact": True,
        "interactive_silhouette_exact": True,
        "decoration_subordinate_exact": True,
        "town_asset_count": 7,
        "town_painted_bounds_exact": True,
        "town_click_routing_exact": True,
        "session_authority_exact": True,
    }
    failures = [f"{key}={payload.get(key)!r}, expected {value!r}" for key, value in expected.items() if payload.get(key) != value]
    if failures:
        print(f"{REPORT_ID} mismatch: {'; '.join(failures)}", file=sys.stderr)
        return 1
    print(f"{REPORT_ID} VERIFIED {json.dumps(expected, sort_keys=True)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
