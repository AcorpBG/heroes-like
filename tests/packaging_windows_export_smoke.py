#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACT_DIR = Path(
    os.environ.get(
        "HEROES_PACKAGING_WINDOWS_ARTIFACT_DIR",
        ROOT / ".artifacts" / "packaging_windows_export_smoke",
    )
).resolve()
EXPORT_DIR = ARTIFACT_DIR / "export"
REPORT_PATH = ARTIFACT_DIR / "report.json"
EXE_PATH = EXPORT_DIR / "heroes-like.exe"
PCK_PATH = EXPORT_DIR / "heroes-like.pck"
REPORT_ID = "PACKAGING_WINDOWS_EXPORT_SMOKE"
SCHEMA_ID = "packaging_windows_export_smoke_v1"
PRESET_NAME = "Windows Release"
MIN_EXE_BYTES = 500_000
MIN_PCK_BYTES = 10_000_000
EXPORT_TIMEOUT_SECONDS = 360
REQUIRED_WINDOWS_DLLS = (
    "aurelion_map_persistence.windows.template_release.x86_64.dll",
)
FATAL_EXPORT_PATTERNS = (
    "SCRIPT ERROR",
    "Parse Error",
    "ERROR:",
    "Failed loading resource",
    "No loader found",
    "Cannot open file",
    "No export template",
    "Template file not found",
)


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def relative(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def output_summary(output: str) -> dict:
    lines = output.splitlines()
    error_like = [line for line in lines if "ERROR:" in line or "SCRIPT ERROR" in line or "Parse Error" in line]
    return {
        "line_count": len(lines),
        "warning_count": sum(1 for line in lines if "WARNING:" in line),
        "error_like_count": len(error_like),
        "fatal_pattern_matches": [pattern for pattern in FATAL_EXPORT_PATTERNS if pattern in output],
        "head": lines[:20],
        "tail": lines[-80:],
        "error_like_tail": error_like[-20:],
    }


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


def file_summary(path: Path, min_size_bytes: int) -> dict:
    exists = path.exists()
    size = path.stat().st_size if exists else 0
    return {
        "path": relative(path),
        "exists": exists,
        "size_bytes": size,
        "min_size_bytes": min_size_bytes,
        "large_enough": size >= min_size_bytes,
    }


def exe_header_summary() -> dict:
    if not EXE_PATH.exists():
        return {"checked": False, "mz_header": False, "pe_header": False}
    data = EXE_PATH.read_bytes()[:4096]
    pe_offset = int.from_bytes(data[0x3C:0x40], byteorder="little", signed=False) if len(data) >= 0x40 else 0
    pe_header = pe_offset + 4 <= len(data) and data[pe_offset : pe_offset + 4] == b"PE\x00\x00"
    return {
        "checked": True,
        "mz_header": data[:2] == b"MZ",
        "pe_offset": pe_offset,
        "pe_header": pe_header,
    }


def dll_summary() -> dict:
    rows = []
    for dll_name in REQUIRED_WINDOWS_DLLS:
        path = EXPORT_DIR / dll_name
        source_path = ROOT / "bin" / dll_name
        rows.append(
            {
                "name": dll_name,
                "export_path": relative(path),
                "source_path": relative(source_path),
                "export_exists": path.exists(),
                "export_size_bytes": path.stat().st_size if path.exists() else 0,
                "source_exists": source_path.exists(),
                "source_size_bytes": source_path.stat().st_size if source_path.exists() else 0,
            }
        )
    return {
        "required": list(REQUIRED_WINDOWS_DLLS),
        "rows": rows,
        "all_exported": all(row["export_exists"] and row["export_size_bytes"] > 0 for row in rows),
        "all_sources_exist": all(row["source_exists"] and row["source_size_bytes"] > 0 for row in rows),
    }


def artifact_listing() -> list[dict]:
    if not EXPORT_DIR.exists():
        return []
    rows: list[dict] = []
    for path in sorted(EXPORT_DIR.rglob("*")):
        if not path.is_file():
            continue
        rows.append(
            {
                "path": str(path.relative_to(EXPORT_DIR)),
                "size_bytes": path.stat().st_size,
            }
        )
    return rows


def main() -> int:
    ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
    if EXPORT_DIR.exists():
        shutil.rmtree(EXPORT_DIR)
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    if REPORT_PATH.exists():
        REPORT_PATH.unlink()

    export_command = [
        "godot",
        "--headless",
        "--path",
        ".",
        "--export-release",
        PRESET_NAME,
        str(EXE_PATH),
    ]
    export_result = run_command(export_command, EXPORT_TIMEOUT_SECONDS)
    exe = file_summary(EXE_PATH, MIN_EXE_BYTES)
    pck = file_summary(PCK_PATH, MIN_PCK_BYTES)
    header = exe_header_summary()
    dlls = dll_summary()
    fatal_matches = list(export_result.get("output_summary", {}).get("fatal_pattern_matches", []))
    ok = (
        export_result["returncode"] == 0
        and not export_result["timed_out"]
        and not fatal_matches
        and bool(exe["exists"])
        and bool(exe["large_enough"])
        and bool(header["mz_header"])
        and bool(header["pe_header"])
        and bool(pck["exists"])
        and bool(pck["large_enough"])
        and bool(dlls["all_exported"])
    )

    report = {
        "schema_id": SCHEMA_ID,
        "report_id": REPORT_ID,
        "generated_at": utc_now(),
        "ok": bool(ok),
        "scope": {
            "preset": PRESET_NAME,
            "export_exe": relative(EXE_PATH),
            "claims": [
                "The Windows Release preset can export a real executable artifact in this local Godot environment.",
                "The exported executable has a Windows MZ/PE header.",
                "The sidecar PCK and required Windows native GDExtension DLLs are present beside the executable.",
            ],
            "does_not_claim": [
                "Windows runtime execution",
                "Wine runtime execution",
                "installer readiness",
                "clean-machine smoke coverage",
                "release readiness",
            ],
        },
        "export_binary": export_result,
        "exe": exe,
        "pck": pck,
        "exe_header": header,
        "windows_native_dlls": dlls,
        "artifact_listing": artifact_listing(),
        "fatal_export_patterns": list(FATAL_EXPORT_PATTERNS),
        "fatal_export_matches": fatal_matches,
    }
    REPORT_PATH.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    summary = {
        "ok": report["ok"],
        "export_returncode": export_result["returncode"],
        "exe_size_bytes": exe["size_bytes"],
        "pck_size_bytes": pck["size_bytes"],
        "mz_header": header.get("mz_header", False),
        "pe_header": header.get("pe_header", False),
        "windows_dlls_exported": dlls["all_exported"],
        "fatal_export_matches": fatal_matches,
        "report": relative(REPORT_PATH),
    }
    print(f"{REPORT_ID} {json.dumps(summary, sort_keys=True)}")
    if not report["ok"]:
        print(f"Report written to {relative(REPORT_PATH)}", file=sys.stderr)
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
