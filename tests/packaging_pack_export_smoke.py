#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACT_DIR = ROOT / ".artifacts" / "packaging_pack_export_smoke"
REPORT_PATH = ARTIFACT_DIR / "report.json"
PACK_PATH = ARTIFACT_DIR / "heroes-like.pck"
REPORT_ID = "PACKAGING_PACK_EXPORT_SMOKE"
SCHEMA_ID = "packaging_pack_export_smoke_v1"
PRESET_NAME = "Linux Release"
MIN_PACK_BYTES = 10_000_000
EXPORT_TIMEOUT_SECONDS = 300
BOOT_TIMEOUT_SECONDS = 90
BOOT_QUIT_AFTER_SECONDS = 30
FATAL_BOOT_PATTERNS = (
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
    warning_lines = [line for line in lines if "WARNING:" in line]
    error_lines = [line for line in lines if "ERROR:" in line or "SCRIPT ERROR" in line or "Parse Error" in line]
    return {
        "line_count": len(lines),
        "warning_count": len(warning_lines),
        "error_like_count": len(error_lines),
        "fatal_pattern_matches": [pattern for pattern in FATAL_BOOT_PATTERNS if pattern in output],
        "head": lines[:20],
        "tail": lines[-80:],
        "error_like_tail": error_lines[-20:],
    }


def fatal_matches(output_summary_payload: dict) -> list[str]:
    full_output_matches = output_summary_payload.get("fatal_pattern_matches", [])
    if full_output_matches:
        return list(full_output_matches)
    haystack_lines: list[str] = []
    haystack_lines.extend(output_summary_payload.get("head", []))
    haystack_lines.extend(output_summary_payload.get("tail", []))
    haystack_lines.extend(output_summary_payload.get("error_like_tail", []))
    haystack = "\n".join(haystack_lines)
    return [pattern for pattern in FATAL_BOOT_PATTERNS if pattern in haystack]


def godot_version() -> str:
    result = run_command(["godot", "--version"], 30)
    lines = result.get("output_summary", {}).get("head", [])
    return str(lines[0]) if lines else "unknown"


def binary_export_template_status(version: str) -> dict:
    version_match = re.match(r"(\d+\.\d+(?:\.\d+)?)", version)
    version_prefix = version_match.group(1) if version_match else ""
    candidate_roots = [
        Path.home() / ".local" / "share" / "godot" / "export_templates",
        Path.home() / ".var" / "app" / "org.godotengine.Godot" / "data" / "godot" / "export_templates",
    ]
    matches: list[str] = []
    existing_roots: list[str] = []
    for root in candidate_roots:
        if not root.exists():
            continue
        existing_roots.append(str(root))
        for child in root.iterdir():
            if child.is_dir() and (version_prefix == "" or child.name.startswith(version_prefix)):
                matches.append(str(child))
    return {
        "godot_version": version,
        "candidate_roots": [str(path) for path in candidate_roots],
        "existing_roots": existing_roots,
        "matching_template_dirs": matches,
        "binary_export_templates_available": len(matches) > 0,
        "binary_export_template_status": "available" if matches else "missing",
        "note": "Pack export smoke does not require binary export templates; release binary export remains separate evidence.",
    }


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
    if PACK_PATH.exists():
        PACK_PATH.unlink()

    version = godot_version()
    export_command = [
        "godot",
        "--headless",
        "--path",
        ".",
        "--export-pack",
        PRESET_NAME,
        str(PACK_PATH),
    ]
    export_result = run_command(export_command, EXPORT_TIMEOUT_SECONDS)
    pack = pack_summary()
    export_ok = export_result["returncode"] == 0 and not export_result["timed_out"] and pack["exists"] and pack["large_enough"]

    boot_result: dict | None = None
    boot_fatal_matches: list[str] = []
    boot_ok = False
    if export_ok:
        boot_command = [
            "godot",
            "--headless",
            "--main-pack",
            str(PACK_PATH),
            "--quit-after",
            str(BOOT_QUIT_AFTER_SECONDS),
        ]
        boot_result = run_command(boot_command, BOOT_TIMEOUT_SECONDS)
        boot_fatal_matches = fatal_matches(boot_result.get("output_summary", {}))
        boot_ok = boot_result["returncode"] == 0 and not boot_result["timed_out"] and not boot_fatal_matches

    report = {
        "schema_id": SCHEMA_ID,
        "report_id": REPORT_ID,
        "generated_at": utc_now(),
        "ok": bool(export_ok and boot_ok),
        "scope": {
            "preset": PRESET_NAME,
            "pack_path": str(PACK_PATH.relative_to(ROOT)),
            "claims": [
                "Linux Release preset can export a real external PCK through --export-pack.",
                "The exported PCK can boot through --main-pack in this local Godot environment.",
            ],
            "does_not_claim": [
                "binary export readiness",
                "installer readiness",
                "Windows packaged smoke coverage",
                "clean-machine smoke coverage",
                "release readiness",
            ],
        },
        "binary_export_templates": binary_export_template_status(version),
        "export_pack": export_result,
        "pack": pack,
        "main_pack_boot": boot_result,
        "fatal_boot_patterns": list(FATAL_BOOT_PATTERNS),
        "boot_fatal_matches": boot_fatal_matches,
    }
    REPORT_PATH.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    summary = {
        "ok": report["ok"],
        "pack_size_bytes": pack["size_bytes"],
        "export_returncode": export_result["returncode"],
        "boot_returncode": None if boot_result is None else boot_result["returncode"],
        "boot_fatal_matches": boot_fatal_matches,
        "binary_export_template_status": report["binary_export_templates"]["binary_export_template_status"],
        "report": str(REPORT_PATH.relative_to(ROOT)),
    }
    print(f"{REPORT_ID} {json.dumps(summary, sort_keys=True)}")
    if not report["ok"]:
        print(f"Report written to {REPORT_PATH.relative_to(ROOT)}", file=sys.stderr)
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
