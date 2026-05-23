#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACT_DIR = ROOT / ".artifacts" / "packaged_settings_persistence_smoke"
PACK_PATH = ARTIFACT_DIR / "heroes-like.pck"
REPORT_PATH = ARTIFACT_DIR / "report.json"
SCENE_REPORT_PATH = ARTIFACT_DIR / "scene_report.json"
REPORT_ID = "PACKAGED_SETTINGS_PERSISTENCE_SMOKE"
SCHEMA_ID = "packaged_settings_persistence_smoke_v1"
PRESET_NAME = "Linux Release"
PACKAGED_SCENE = "res://tests/packaged_settings_persistence_report.tscn"
MIN_PACK_BYTES = 10_000_000
EXPORT_TIMEOUT_SECONDS = 300
BOOT_TIMEOUT_SECONDS = 120
FATAL_PATTERNS = (
    "SCRIPT ERROR",
    "Parse Error",
    "ERROR:",
    "Failed loading resource",
    "No loader found",
    "Cannot open file",
)


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def run_command(args: list[str], timeout_seconds: int) -> dict:
    env = os.environ.copy()
    env["GODOT_SILENCE_ROOT_WARNING"] = "1"
    started = utc_now()
    try:
        completed = subprocess.run(
            args,
            cwd=ROOT,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            errors="replace",
            timeout=timeout_seconds,
            check=False,
        )
        output = completed.stdout or ""
        return {
            "args": args,
            "started_at": started,
            "finished_at": utc_now(),
            "timeout_seconds": timeout_seconds,
            "timed_out": False,
            "returncode": completed.returncode,
            "output_summary": output_summary(output),
        }
    except subprocess.TimeoutExpired as exc:
        output = ""
        if exc.stdout:
            output += exc.stdout if isinstance(exc.stdout, str) else exc.stdout.decode("utf-8", errors="replace")
        if exc.stderr:
            output += exc.stderr if isinstance(exc.stderr, str) else exc.stderr.decode("utf-8", errors="replace")
        return {
            "args": args,
            "started_at": started,
            "finished_at": utc_now(),
            "timeout_seconds": timeout_seconds,
            "timed_out": True,
            "returncode": None,
            "output_summary": output_summary(output),
        }


def output_summary(output: str) -> dict:
    lines = output.splitlines()
    error_like = [line for line in lines if "ERROR:" in line or "SCRIPT ERROR" in line or "Parse Error" in line]
    return {
        "line_count": len(lines),
        "warning_count": sum(1 for line in lines if "WARNING:" in line),
        "error_like_count": len(error_like),
        "fatal_pattern_matches": [pattern for pattern in FATAL_PATTERNS if pattern in output],
        "head": lines[:20],
        "tail": lines[-80:],
        "error_like_tail": error_like[-20:],
    }


def load_scene_report() -> dict:
    if not SCENE_REPORT_PATH.exists():
        return {}
    return json.loads(SCENE_REPORT_PATH.read_text(encoding="utf-8"))


def pack_summary() -> dict:
    exists = PACK_PATH.exists()
    size = PACK_PATH.stat().st_size if exists else 0
    return {
        "path": str(PACK_PATH.relative_to(ROOT)),
        "exists": exists,
        "size_bytes": size,
        "min_size_bytes": MIN_PACK_BYTES,
        "large_enough": size >= MIN_PACK_BYTES,
    }


def main() -> int:
    ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
    for path in (PACK_PATH, REPORT_PATH, SCENE_REPORT_PATH):
        if path.exists():
            path.unlink()

    export_result = run_command(
        [
            "godot",
            "--headless",
            "--path",
            ".",
            "--export-pack",
            PRESET_NAME,
            str(PACK_PATH),
        ],
        EXPORT_TIMEOUT_SECONDS,
    )
    pack = pack_summary()
    export_ok = export_result["returncode"] == 0 and not export_result["timed_out"] and pack["exists"] and pack["large_enough"]

    scene_result: dict | None = None
    scene_report: dict = {}
    fatal_matches: list[str] = []
    scene_ok = False
    if export_ok:
        scene_result = run_command(
            [
                "godot",
                "--headless",
                "--main-pack",
                str(PACK_PATH),
                "--scene",
                PACKAGED_SCENE,
                "--quit-after",
                "120",
                "--",
                f"--report-json={SCENE_REPORT_PATH}",
            ],
            BOOT_TIMEOUT_SECONDS,
        )
        fatal_matches = list(scene_result.get("output_summary", {}).get("fatal_pattern_matches", []))
        scene_report = load_scene_report()
        scene_ok = (
            scene_result["returncode"] == 0
            and not scene_result["timed_out"]
            and not fatal_matches
            and bool(scene_report.get("ok", False))
            and bool(scene_report.get("ran_from_pack_scene", False))
            and bool(scene_report.get("restored_original_settings", False))
        )

    report = {
        "schema_id": SCHEMA_ID,
        "report_id": REPORT_ID,
        "generated_at": utc_now(),
        "ok": bool(export_ok and scene_ok),
        "scope": {
            "preset": PRESET_NAME,
            "packaged_scene": PACKAGED_SCENE,
            "claims": [
                "A focused settings scene can run from an exported PCK through --main-pack.",
                "SettingsService can write user://config/settings.cfg and reload persisted values during that packaged-scene run.",
            ],
            "does_not_claim": [
                "binary export readiness",
                "installer readiness",
                "Windows packaged smoke coverage",
                "clean-machine smoke coverage",
                "release readiness",
            ],
        },
        "export_pack": export_result,
        "pack": pack,
        "packaged_scene_run": scene_result,
        "scene_report": scene_report,
        "fatal_patterns": list(FATAL_PATTERNS),
        "fatal_matches": fatal_matches,
    }
    REPORT_PATH.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    summary = {
        "ok": report["ok"],
        "pack_size_bytes": pack["size_bytes"],
        "export_returncode": export_result["returncode"],
        "scene_returncode": None if scene_result is None else scene_result["returncode"],
        "settings_file": scene_report.get("settings_file", ""),
        "restored_original_settings": scene_report.get("restored_original_settings", False),
        "fatal_matches": fatal_matches,
        "report": str(REPORT_PATH.relative_to(ROOT)),
    }
    print(f"{REPORT_ID} {json.dumps(summary, sort_keys=True)}")
    if not report["ok"]:
        print(f"Report written to {REPORT_PATH.relative_to(ROOT)}", file=sys.stderr)
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
