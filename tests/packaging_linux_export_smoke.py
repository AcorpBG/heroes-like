#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import shutil
import stat
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACT_DIR = ROOT / ".artifacts" / "packaging_linux_export_smoke"
EXPORT_DIR = ARTIFACT_DIR / "export"
REPORT_PATH = ARTIFACT_DIR / "report.json"
BINARY_PATH = EXPORT_DIR / "heroes-like.x86_64"
PCK_PATH = EXPORT_DIR / "heroes-like.pck"
REPORT_ID = "PACKAGING_LINUX_EXPORT_SMOKE"
SCHEMA_ID = "packaging_linux_export_smoke_v1"
PRESET_NAME = "Linux Release"
MIN_BINARY_BYTES = 500_000
MIN_PCK_BYTES = 10_000_000
EXPORT_TIMEOUT_SECONDS = 360
BOOT_TIMEOUT_SECONDS = 90
BOOT_QUIT_AFTER_SECONDS = 20
REQUIRED_LINUX_LIBRARIES = (
    "libaurelion_map_persistence.linux.template_release.x86_64.so",
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


def output_summary(output: str, fatal_patterns: tuple[str, ...]) -> dict:
    lines = output.splitlines()
    error_like = [line for line in lines if "ERROR:" in line or "SCRIPT ERROR" in line or "Parse Error" in line]
    return {
        "line_count": len(lines),
        "warning_count": sum(1 for line in lines if "WARNING:" in line),
        "error_like_count": len(error_like),
        "fatal_pattern_matches": [pattern for pattern in fatal_patterns if pattern in output],
        "head": lines[:20],
        "tail": lines[-80:],
        "error_like_tail": error_like[-20:],
    }


def run_command(args: list[str], timeout_seconds: int, fatal_patterns: tuple[str, ...]) -> dict:
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
            "output_summary": output_summary(output, fatal_patterns),
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
            "output_summary": output_summary(output, fatal_patterns),
        }


def file_summary(path: Path, min_size_bytes: int) -> dict:
    exists = path.exists()
    size = path.stat().st_size if exists else 0
    mode = path.stat().st_mode if exists else 0
    return {
        "path": str(path.relative_to(ROOT)),
        "exists": exists,
        "size_bytes": size,
        "min_size_bytes": min_size_bytes,
        "large_enough": size >= min_size_bytes,
        "mode_octal": oct(stat.S_IMODE(mode)) if exists else "",
        "executable": exists and bool(mode & stat.S_IXUSR),
    }


def elf_header_summary() -> dict:
    if not BINARY_PATH.exists():
        return {"checked": False, "elf_header": False, "elf_class": "", "machine": ""}
    data = BINARY_PATH.read_bytes()[:64]
    elf_class = "64-bit" if len(data) > 4 and data[4] == 2 else ("32-bit" if len(data) > 4 and data[4] == 1 else "")
    endian = "little" if len(data) > 5 and data[5] == 1 else ("big" if len(data) > 5 and data[5] == 2 else "")
    machine = int.from_bytes(data[18:20], byteorder="little", signed=False) if len(data) >= 20 else 0
    return {
        "checked": True,
        "elf_header": data[:4] == b"\x7fELF",
        "elf_class": elf_class,
        "endian": endian,
        "machine": machine,
        "machine_label": "x86_64" if machine == 62 else str(machine),
        "x86_64": machine == 62,
    }


def linux_library_summary() -> dict:
    rows = []
    for library_name in REQUIRED_LINUX_LIBRARIES:
        path = EXPORT_DIR / library_name
        source_path = ROOT / "bin" / library_name
        rows.append(
            {
                "name": library_name,
                "export_path": str(path.relative_to(ROOT)),
                "source_path": str(source_path.relative_to(ROOT)),
                "export_exists": path.exists(),
                "export_size_bytes": path.stat().st_size if path.exists() else 0,
                "source_exists": source_path.exists(),
                "source_size_bytes": source_path.stat().st_size if source_path.exists() else 0,
            }
        )
    return {
        "required": list(REQUIRED_LINUX_LIBRARIES),
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
        str(BINARY_PATH),
    ]
    export_result = run_command(export_command, EXPORT_TIMEOUT_SECONDS, FATAL_EXPORT_PATTERNS)
    binary = file_summary(BINARY_PATH, MIN_BINARY_BYTES)
    pck = file_summary(PCK_PATH, MIN_PCK_BYTES)
    header = elf_header_summary()
    libraries = linux_library_summary()
    export_fatal_matches = list(export_result.get("output_summary", {}).get("fatal_pattern_matches", []))
    export_ok = (
        export_result["returncode"] == 0
        and not export_result["timed_out"]
        and not export_fatal_matches
        and bool(binary["exists"])
        and bool(binary["large_enough"])
        and bool(binary["executable"])
        and bool(header["elf_header"])
        and bool(header["x86_64"])
        and bool(pck["exists"])
        and bool(pck["large_enough"])
        and bool(libraries["all_exported"])
    )

    boot_result: dict | None = None
    boot_fatal_matches: list[str] = []
    boot_ok = False
    if export_ok:
        boot_command = [
            str(BINARY_PATH),
            "--headless",
            "--quit-after",
            str(BOOT_QUIT_AFTER_SECONDS),
        ]
        boot_result = run_command(boot_command, BOOT_TIMEOUT_SECONDS, FATAL_BOOT_PATTERNS)
        boot_fatal_matches = list(boot_result.get("output_summary", {}).get("fatal_pattern_matches", []))
        boot_ok = boot_result["returncode"] == 0 and not boot_result["timed_out"] and not boot_fatal_matches

    report = {
        "schema_id": SCHEMA_ID,
        "report_id": REPORT_ID,
        "generated_at": utc_now(),
        "ok": bool(export_ok and boot_ok),
        "scope": {
            "preset": PRESET_NAME,
            "export_binary": str(BINARY_PATH.relative_to(ROOT)),
            "claims": [
                "The Linux Release preset can export a real executable artifact in this local Godot environment.",
                "The exported executable has an ELF x86_64 header and executable permission bits.",
                "The sidecar PCK and required Linux native GDExtension shared library are present beside the executable.",
                "The exported Linux binary can start headlessly in this local environment.",
            ],
            "does_not_claim": [
                "installer readiness",
                "clean-machine smoke coverage",
                "package signing",
                "distribution channel metadata",
                "release readiness",
            ],
        },
        "export_binary": export_result,
        "binary": binary,
        "pck": pck,
        "elf_header": header,
        "linux_native_libraries": libraries,
        "binary_headless_boot": boot_result,
        "artifact_listing": artifact_listing(),
        "fatal_export_patterns": list(FATAL_EXPORT_PATTERNS),
        "fatal_export_matches": export_fatal_matches,
        "fatal_boot_patterns": list(FATAL_BOOT_PATTERNS),
        "boot_fatal_matches": boot_fatal_matches,
    }
    REPORT_PATH.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    summary = {
        "ok": report["ok"],
        "export_returncode": export_result["returncode"],
        "boot_returncode": boot_result["returncode"] if boot_result else None,
        "binary_size_bytes": binary["size_bytes"],
        "pck_size_bytes": pck["size_bytes"],
        "elf_header": header.get("elf_header", False),
        "elf_machine": header.get("machine_label", ""),
        "binary_executable": binary["executable"],
        "linux_libraries_exported": libraries["all_exported"],
        "fatal_export_matches": export_fatal_matches,
        "boot_fatal_matches": boot_fatal_matches,
        "report": str(REPORT_PATH.relative_to(ROOT)),
    }
    print(f"{REPORT_ID} {json.dumps(summary, sort_keys=True)}")
    if not report["ok"]:
        print(f"Report written to {REPORT_PATH.relative_to(ROOT)}", file=sys.stderr)
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
