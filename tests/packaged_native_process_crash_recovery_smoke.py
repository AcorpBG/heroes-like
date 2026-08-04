#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACT_DIR = ROOT / ".artifacts" / "packaged_native_process_crash_recovery_smoke"
PACK_PATH = ARTIFACT_DIR / "heroes-like.pck"
REPORT_PATH = ARTIFACT_DIR / "report.json"
SCENE_REPORT_PATH = ARTIFACT_DIR / "scene_report.json"
USER_DATA_ROOT = ARTIFACT_DIR / "user-data"
REPORT_ID = "PACKAGED_NATIVE_PROCESS_CRASH_RECOVERY_SMOKE"
SCHEMA_ID = "packaged_native_process_crash_recovery_smoke_v1"
PRESET_NAME = "Linux Release"
CRASH_SCENE = "res://tests/native_process_crash_fixture.tscn"
RECOVERY_SCENE = "res://tests/native_process_crash_recovery_report.tscn"
CRASH_MARKER = "NATIVE_PROCESS_CRASH_FIXTURE_MARKER"
MIN_PACK_BYTES = 10_000_000
FATAL_PATTERNS = (
    "SCRIPT ERROR",
    "Parse Error",
    "Failed loading resource",
    "No loader found",
    "Cannot open file",
)


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def run_command(args: list[str], *, timeout: int, env: dict[str, str]) -> dict:
    process_env = os.environ.copy()
    process_env.update(env)
    process_env["GODOT_SILENCE_ROOT_WARNING"] = "1"
    try:
        completed = subprocess.run(
            args,
            cwd=ROOT,
            env=process_env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            errors="replace",
            check=False,
            timeout=timeout,
        )
        output = completed.stdout or ""
        return {
            "args": args,
            "returncode": completed.returncode,
            "timed_out": False,
            "output_contains_crash_marker": CRASH_MARKER in output,
            "fatal_matches": [pattern for pattern in FATAL_PATTERNS if pattern in output],
            "output_tail": output.splitlines()[-80:],
        }
    except (OSError, subprocess.TimeoutExpired) as exc:
        return {
            "args": args,
            "returncode": None,
            "timed_out": isinstance(exc, subprocess.TimeoutExpired),
            "output_contains_crash_marker": False,
            "fatal_matches": [],
            "output_tail": [str(exc)],
        }


def main() -> int:
    if ARTIFACT_DIR.exists():
        shutil.rmtree(ARTIFACT_DIR)
    ARTIFACT_DIR.mkdir(parents=True)
    env = {"XDG_DATA_HOME": str(USER_DATA_ROOT)}
    export = run_command(
        ["godot", "--headless", "--path", ".", "--export-pack", PRESET_NAME, str(PACK_PATH)],
        timeout=300,
        env=env,
    )
    pack_ok = PACK_PATH.is_file() and PACK_PATH.stat().st_size >= MIN_PACK_BYTES

    crash: dict = {}
    recovery: dict = {}
    scene_report: dict = {}
    marker_removed_after_clean_exit = False
    engine_log_paths: list[str] = []
    if export.get("returncode") == 0 and pack_ok:
        crash = run_command(
            [
                "godot",
                "--headless",
                "--main-pack",
                str(PACK_PATH),
                "--scene",
                CRASH_SCENE,
                "--quit-after",
                "120",
            ],
            timeout=90,
            env=env,
        )
        crash_ok = (
            crash.get("returncode") not in (None, 0)
            and not crash.get("timed_out", False)
            and crash.get("output_contains_crash_marker", False)
        )
        if crash_ok:
            recovery = run_command(
                [
                    "godot",
                    "--headless",
                    "--main-pack",
                    str(PACK_PATH),
                    "--scene",
                    RECOVERY_SCENE,
                    "--quit-after",
                    "120",
                    "--",
                    f"--report-json={SCENE_REPORT_PATH}",
                ],
                timeout=120,
                env=env,
            )
            if SCENE_REPORT_PATH.is_file():
                scene_report = json.loads(SCENE_REPORT_PATH.read_text(encoding="utf-8"))
                user_data_dir = Path(str(scene_report.get("user_data_dir_absolute", "")))
                marker_removed_after_clean_exit = not (
                    user_data_dir / "debug" / "heroes_runtime_session.json"
                ).exists()
                engine_log_paths = sorted(
                    path.name for path in (user_data_dir / "logs").glob("*.log") if path.is_file()
                )

    recovery_ok = (
        recovery.get("returncode") == 0
        and not recovery.get("timed_out", False)
        and not recovery.get("fatal_matches", [])
        and bool(scene_report.get("ok", False))
        and int(scene_report.get("recovered_issue_count", 0)) == 1
        and marker_removed_after_clean_exit
        and 1 <= len(engine_log_paths) <= 5
    )
    report = {
        "schema_id": SCHEMA_ID,
        "report_id": REPORT_ID,
        "generated_at": utc_now(),
        "ok": bool(export.get("returncode") == 0 and pack_ok and recovery_ok),
        "scope": {
            "preset": PRESET_NAME,
            "crash_scene": CRASH_SCENE,
            "recovery_scene": RECOVERY_SCENE,
            "claims": [
                "An exported PCK preserves an unclean desktop runtime-session marker across a forced native process crash.",
                "The next packaged launch records exactly one bounded, support-safe previous-session issue.",
                "A normal packaged exit removes the current process marker.",
            ],
            "does_not_claim": [
                "native minidump generation or symbolication",
                "remote telemetry or automatic upload",
                "clean native Windows hardware certification",
                "overall release readiness",
            ],
        },
        "export_pack": export,
        "pack": {
            "path": str(PACK_PATH.relative_to(ROOT)),
            "size_bytes": PACK_PATH.stat().st_size if PACK_PATH.is_file() else 0,
            "min_size_bytes": MIN_PACK_BYTES,
        },
        "forced_crash": crash,
        "recovery_launch": recovery,
        "scene_report": scene_report,
        "marker_removed_after_clean_exit": marker_removed_after_clean_exit,
        "engine_log_paths": engine_log_paths,
        "engine_log_count": len(engine_log_paths),
        "engine_log_limit": 5,
    }
    REPORT_PATH.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    summary = {
        "ok": report["ok"],
        "crash_returncode": crash.get("returncode"),
        "crash_marker_seen": crash.get("output_contains_crash_marker", False),
        "recovery_returncode": recovery.get("returncode"),
        "recovered_issue_count": scene_report.get("recovered_issue_count", 0),
        "marker_removed_after_clean_exit": marker_removed_after_clean_exit,
        "engine_log_count": len(engine_log_paths),
        "report": str(REPORT_PATH.relative_to(ROOT)),
    }
    print(f"{REPORT_ID} {json.dumps(summary, sort_keys=True)}")
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
