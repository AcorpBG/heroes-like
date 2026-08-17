#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import shutil
import struct
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
SCHEMA_ID = "packaging_windows_export_smoke_v2"
PRESET_NAME = "Windows Release"
MIN_EXE_BYTES = 500_000
MIN_PCK_BYTES = 10_000_000
EXPORT_TIMEOUT_SECONDS = 360
RUNTIME_TIMEOUT_SECONDS = 180
WINE_CLEANUP_TIMEOUT_SECONDS = 30
WINE_PREFIX = ARTIFACT_DIR / "wine-prefix"
WINE_BINARY = os.environ.get("WINE", shutil.which("wine") or "")
WINESERVER_BINARY = shutil.which("wineserver") or ""
REQUIRED_WINDOWS_DLLS = (
    "aurelion_map_persistence.windows.template_release.x86_64.dll",
)
FORBIDDEN_TERRAIN_PCK_PREFIXES = (
    "art/overworld/runtime/homm3_local_prototype/",
    "art/overworld/runtime/terrain_tiles/generated/",
)
REQUIRED_TERRAIN_PCK_PREFIXES = (
    "art/overworld/runtime/terrain_tiles/base/",
    "art/overworld/runtime/terrain_tiles/roads/",
)
REQUIRED_ARTIFACT_FIELD_NAMES = (
    "trailsinger_boots", "quarry_tally_rod", "warcrest_pennon", "bastion_gorget",
    "waymark_compass", "milepost_lantern", "tollstone_ring", "mudglass_beads",
    "choir_tuning_fork", "living_bridge_knot", "pressure_gauge_reliquary", "black_sail_compass",
)
REQUIRED_ARTIFACT_FIELD_PCK_IMPORT_ENTRIES = tuple(
    f"art/overworld/runtime/objects/artifacts/{artifact_name}.png.import"
    for artifact_name in REQUIRED_ARTIFACT_FIELD_NAMES
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
FATAL_RUNTIME_PATTERNS = (
    "SCRIPT ERROR",
    "Parse Error",
    "ERROR:",
    "Failed loading resource",
    "No loader found",
    "Cannot open file",
    "GDExtension library not found",
    "Failed to open GDExtension library",
    "Error loading GDExtension",
    "Unhandled page fault",
)
RUNTIME_MARKERS = {
    "godot_started": "Godot Engine v",
    "boot_scene_loaded": "Boot.scn",
    "main_menu_loaded": "MainMenu.scn",
    "native_dll_loaded": REQUIRED_WINDOWS_DLLS[0],
}


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def relative(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def output_summary(
    output: str,
    fatal_patterns: tuple[str, ...] = FATAL_EXPORT_PATTERNS,
    markers: dict[str, str] | None = None,
) -> dict:
    lines = output.splitlines()
    error_like = [line for line in lines if "ERROR:" in line or "SCRIPT ERROR" in line or "Parse Error" in line]
    summary = {
        "line_count": len(lines),
        "warning_count": sum(1 for line in lines if "WARNING:" in line),
        "error_like_count": len(error_like),
        "fatal_pattern_matches": [pattern for pattern in fatal_patterns if pattern in output],
        "head": lines[:20],
        "tail": lines[-80:],
        "error_like_tail": error_like[-20:],
    }
    if markers:
        summary["markers"] = {name: token in output for name, token in markers.items()}
    return summary


def run_command(
    args: list[str],
    timeout_seconds: int,
    *,
    env_overrides: dict[str, str] | None = None,
    fatal_patterns: tuple[str, ...] = FATAL_EXPORT_PATTERNS,
    markers: dict[str, str] | None = None,
) -> dict:
    env = os.environ.copy()
    env["GODOT_SILENCE_ROOT_WARNING"] = "1"
    if env_overrides:
        env.update(env_overrides)
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
            "output_summary": output_summary(output, fatal_patterns, markers),
        }
    except FileNotFoundError as exc:
        return {
            "args": args,
            "started_at": started,
            "finished_at": utc_now(),
            "timeout_seconds": timeout_seconds,
            "timed_out": False,
            "returncode": None,
            "launch_error": str(exc),
            "output_summary": output_summary(str(exc), fatal_patterns, markers),
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
            "output_summary": output_summary(output, fatal_patterns, markers),
        }


def unavailable_runtime_result(reason: str) -> dict:
    return {
        "args": [],
        "started_at": utc_now(),
        "finished_at": utc_now(),
        "timeout_seconds": RUNTIME_TIMEOUT_SECONDS,
        "timed_out": False,
        "returncode": None,
        "launch_error": reason,
        "output_summary": output_summary(reason, FATAL_RUNTIME_PATTERNS, RUNTIME_MARKERS),
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


def pck_terrain_payload_summary() -> dict:
    summary = {
        "checked": False,
        "valid_directory": False,
        "entry_count": 0,
        "forbidden_prefixes": list(FORBIDDEN_TERRAIN_PCK_PREFIXES),
        "forbidden_entries": [],
        "required_prefix_counts": {prefix: 0 for prefix in REQUIRED_TERRAIN_PCK_PREFIXES},
        "required_entries_present": False,
        "required_artifact_field_import_entries": list(REQUIRED_ARTIFACT_FIELD_PCK_IMPORT_ENTRIES),
        "artifact_field_import_entries": [],
        "artifact_field_texture_names": [],
        "artifact_field_entries_present": False,
    }
    if not PCK_PATH.exists():
        return summary
    file_size = PCK_PATH.stat().st_size
    try:
        with PCK_PATH.open("rb") as handle:
            header = handle.read(112)
            if len(header) != 112 or header[:4] != b"GDPC" or struct.unpack_from("<I", header, 4)[0] != 3:
                return summary
            directory_offset = struct.unpack_from("<Q", header, 32)[0]
            if directory_offset < 112 or directory_offset + 4 > file_size:
                return summary
            handle.seek(directory_offset)
            entry_count = struct.unpack("<I", handle.read(4))[0]
            if entry_count <= 0 or entry_count > 1_000_000:
                return summary
            summary["checked"] = True
            summary["entry_count"] = entry_count
            for _ in range(entry_count):
                path_length_data = handle.read(4)
                if len(path_length_data) != 4:
                    return summary
                path_length = struct.unpack("<I", path_length_data)[0]
                if path_length <= 0 or path_length > 1_048_576:
                    return summary
                padded_length = (path_length + 3) & ~3
                path_data = handle.read(padded_length)
                metadata = handle.read(36)
                if len(path_data) != padded_length or len(metadata) != 36:
                    return summary
                entry_path = path_data[:path_length].rstrip(b"\0").decode("utf-8", errors="replace")
                for prefix in FORBIDDEN_TERRAIN_PCK_PREFIXES:
                    if entry_path.startswith(prefix):
                        summary["forbidden_entries"].append(entry_path)
                for prefix in REQUIRED_TERRAIN_PCK_PREFIXES:
                    if entry_path.startswith(prefix):
                        summary["required_prefix_counts"][prefix] += 1
                if entry_path in REQUIRED_ARTIFACT_FIELD_PCK_IMPORT_ENTRIES:
                    summary["artifact_field_import_entries"].append(entry_path)
                if entry_path.startswith(".godot/imported/") and entry_path.endswith(".ctex"):
                    imported_name = Path(entry_path).name.split(".png-", 1)[0]
                    if imported_name in REQUIRED_ARTIFACT_FIELD_NAMES:
                        summary["artifact_field_texture_names"].append(imported_name)
            summary["valid_directory"] = handle.tell() == file_size
    except (OSError, struct.error, UnicodeError):
        return summary
    summary["required_entries_present"] = all(
        count > 0 for count in summary["required_prefix_counts"].values()
    )
    summary["artifact_field_entries_present"] = set(summary["artifact_field_import_entries"]) == set(REQUIRED_ARTIFACT_FIELD_PCK_IMPORT_ENTRIES) and set(summary["artifact_field_texture_names"]) == set(REQUIRED_ARTIFACT_FIELD_NAMES)
    return summary


def main() -> int:
    ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
    if EXPORT_DIR.exists():
        shutil.rmtree(EXPORT_DIR)
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    if REPORT_PATH.exists():
        REPORT_PATH.unlink()
    if WINE_PREFIX.exists():
        shutil.rmtree(WINE_PREFIX)

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
    terrain_payload = pck_terrain_payload_summary()
    fatal_matches = list(export_result.get("output_summary", {}).get("fatal_pattern_matches", []))
    export_ok = (
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
        and bool(terrain_payload["valid_directory"])
        and not terrain_payload["forbidden_entries"]
        and bool(terrain_payload["required_entries_present"])
        and bool(terrain_payload["artifact_field_entries_present"])
    )

    wine_version_result = (
        run_command([WINE_BINARY, "--version"], 30, env_overrides={"WINEDEBUG": "-all"})
        if WINE_BINARY
        else unavailable_runtime_result("wine executable not found")
    )
    runtime_env = {
        "WINEPREFIX": str(WINE_PREFIX),
        "WINEARCH": "win64",
        "WINEDEBUG": "-all,+loaddll",
        # Wine 9's builtin DirectInput crashes this Godot executable before project startup.
        "WINEDLLOVERRIDES": "dinput8=",
    }
    runtime_command = [
        WINE_BINARY,
        str(EXE_PATH),
        "--headless",
        "--audio-driver",
        "Dummy",
        "--rendering-method",
        "gl_compatibility",
        "--quit-after",
        "30",
        "--verbose",
    ]
    runtime_result = (
        run_command(
            runtime_command,
            RUNTIME_TIMEOUT_SECONDS,
            env_overrides=runtime_env,
            fatal_patterns=FATAL_RUNTIME_PATTERNS,
            markers=RUNTIME_MARKERS,
        )
        if export_ok and WINE_BINARY
        else unavailable_runtime_result(
            "Windows export failed before runtime launch" if not export_ok else "wine executable not found"
        )
    )
    cleanup_result = (
        run_command(
            [WINESERVER_BINARY, "-k"],
            WINE_CLEANUP_TIMEOUT_SECONDS,
            env_overrides={"WINEPREFIX": str(WINE_PREFIX), "WINEDEBUG": "-all"},
        )
        if WINESERVER_BINARY and WINE_PREFIX.exists()
        else None
    )
    runtime_summary = runtime_result.get("output_summary", {})
    runtime_markers = runtime_summary.get("markers", {})
    runtime_fatal_matches = list(runtime_summary.get("fatal_pattern_matches", []))
    runtime_ok = (
        runtime_result["returncode"] == 0
        and not runtime_result["timed_out"]
        and not runtime_fatal_matches
        and all(runtime_markers.get(name, False) for name in RUNTIME_MARKERS)
    )
    ok = export_ok and runtime_ok

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
                "The packaged executable starts under Wine in a fresh isolated prefix and initializes Godot plus Boot and MainMenu resources.",
                "Wine loader output proves the packaged Windows release GDExtension DLL is loaded during startup.",
            ],
            "does_not_claim": [
                "clean native Windows execution",
                "DirectInput or controller behavior because Wine dinput8 is disabled for this harness",
                "hardware graphics or audio behavior because the run is headless with dummy audio",
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
        "terrain_pck_payload": terrain_payload,
        "artifact_listing": artifact_listing(),
        "fatal_export_patterns": list(FATAL_EXPORT_PATTERNS),
        "fatal_export_matches": fatal_matches,
        "windows_runtime": {
            "runner": "wine",
            "wine_binary": WINE_BINARY,
            "wine_version": wine_version_result,
            "fresh_prefix": relative(WINE_PREFIX),
            "directinput_override": "dinput8=",
            "headless": True,
            "dummy_audio": True,
            "result": runtime_result,
            "markers": runtime_markers,
            "fatal_runtime_patterns": list(FATAL_RUNTIME_PATTERNS),
            "fatal_runtime_matches": runtime_fatal_matches,
            "cleanup": cleanup_result,
            "ok": runtime_ok,
        },
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
        "terrain_pck_forbidden_entry_count": len(terrain_payload["forbidden_entries"]),
        "terrain_pck_required_entries_present": terrain_payload["required_entries_present"],
        "artifact_field_pck_import_entry_count": len(terrain_payload["artifact_field_import_entries"]),
        "artifact_field_pck_texture_count": len(set(terrain_payload["artifact_field_texture_names"])),
        "artifact_field_pck_entries_present": terrain_payload["artifact_field_entries_present"],
        "fatal_export_matches": fatal_matches,
        "wine_runtime_returncode": runtime_result["returncode"],
        "wine_runtime_markers": runtime_markers,
        "fatal_runtime_matches": runtime_fatal_matches,
        "report": relative(REPORT_PATH),
    }
    print(f"{REPORT_ID} {json.dumps(summary, sort_keys=True)}")
    if not report["ok"]:
        print(f"Report written to {relative(REPORT_PATH)}", file=sys.stderr)
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
