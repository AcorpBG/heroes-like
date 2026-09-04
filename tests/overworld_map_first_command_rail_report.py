#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACT_DIR = ROOT / ".artifacts" / "overworld_map_first_command_rail"
CAPTURE_DIR = ARTIFACT_DIR / "captures"
REPORT_PATH = ARTIFACT_DIR / "report.json"
REPORT_ID = "OVERWORLD_MAP_FIRST_COMMAND_RAIL_REPORT"


def main() -> int:
    CAPTURE_DIR.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env["OVERWORLD_MAP_FIRST_CAPTURE_DIR"] = str(CAPTURE_DIR)
    godot = shutil.which("godot4")
    xvfb = shutil.which("xvfb-run")
    if not godot or not xvfb:
        print(f"{REPORT_ID}: godot4 and xvfb-run are required")
        return 1
    process = subprocess.run(
        [xvfb, "-a", "-s", "-screen 0 2200x1200x24", godot, "--path", str(ROOT), "--scene", "res://tests/overworld_map_first_command_rail_report.tscn"],
        cwd=ROOT,
        env=env,
        text=True,
        capture_output=True,
        timeout=240,
    )
    combined = "\n".join(part for part in (process.stdout, process.stderr) if part)
    marker = f"{REPORT_ID} "
    payload = None
    for line in combined.splitlines():
        if line.startswith(marker):
            payload = json.loads(line[len(marker) :])
            break
    if process.returncode != 0 or not isinstance(payload, dict) or not payload.get("ok"):
        print(combined)
        return 1
    captures = [Path(path) for path in payload.get("captures", [])]
    if len(captures) != 2 or any(not path.is_file() or path.stat().st_size < 10_000 for path in captures):
        print(f"{REPORT_ID}: capture evidence is incomplete: {captures}")
        return 1
    ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"{REPORT_ID}: PASS rows={len(payload.get('rows', []))} captures={len(captures)} session_exact={payload.get('session_exact')}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
