#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACT_DIR = ROOT / ".artifacts" / "overworld_town_vision_command_roster_10234"
REPORT_PATH = ARTIFACT_DIR / "report.json"
REPORT_ID = "OVERWORLD_TOWN_VISION_COMMAND_ROSTER_REPORT"


def main() -> int:
    godot = shutil.which("godot4")
    xvfb = shutil.which("xvfb-run")
    if not godot or not xvfb:
        print(f"{REPORT_ID}: godot4 and xvfb-run are required", file=sys.stderr)
        return 1
    ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
    process = subprocess.run(
        [
            xvfb,
            "-a",
            "-s",
            "-screen 0 2200x1200x24",
            godot,
            "--path",
            str(ROOT),
            "--scene",
            "res://tests/overworld_town_vision_command_roster_report.tscn",
        ],
        cwd=ROOT,
        env=os.environ.copy(),
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
    captures = [Path(path) for path in payload.get("command_roster", {}).get("captures", [])]
    if len(captures) != 2 or any(not path.is_file() or path.stat().st_size < 10_000 for path in captures):
        print(f"{REPORT_ID}: capture evidence is incomplete: {captures}", file=sys.stderr)
        return 1
    REPORT_PATH.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    vision = payload.get("town_vision", {})
    roster = payload.get("command_roster", {}).get("initial", {})
    print(
        f"{REPORT_ID}: PASS radius={vision.get('radius')} "
        f"heroes={roster.get('hero_count')} towns={roster.get('town_count')} captures={len(captures)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
