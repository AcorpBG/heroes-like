#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import shutil
import stat
import struct
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACT_DIR = Path(
    os.environ.get(
        "HEROES_PACKAGING_LINUX_ARTIFACT_DIR",
        ROOT / ".artifacts" / "packaging_linux_export_smoke",
    )
).resolve()
EXPORT_DIR = ARTIFACT_DIR / "export"
REPORT_PATH = ARTIFACT_DIR / "report.json"
BINARY_PATH = EXPORT_DIR / "heroes-like.x86_64"
PCK_PATH = EXPORT_DIR / "heroes-like.pck"
REPORT_ID = "PACKAGING_LINUX_EXPORT_SMOKE"
SCHEMA_ID = "packaging_linux_export_smoke_v1"
PRESET_NAME = "Linux Release"
MIN_BINARY_BYTES = 500_000
MIN_PCK_BYTES = 10_000_000
MAX_RELEASE_PCK_BYTES = 250_000_000
EXPORT_TIMEOUT_SECONDS = 360
BOOT_TIMEOUT_SECONDS = 90
BOOT_QUIT_AFTER_SECONDS = 20
REQUIRED_LINUX_LIBRARIES = (
    "libaurelion_map_persistence.linux.template_release.x86_64.so",
)
FORBIDDEN_TERRAIN_PCK_PREFIXES = (
    "art/overworld/runtime/homm3_local_prototype/",
    "art/overworld/runtime/terrain_tiles/generated/",
)
REQUIRED_TERRAIN_PCK_PREFIXES = (
    "art/overworld/runtime/terrain_tiles/base/",
    "art/overworld/runtime/terrain_tiles/detail/",
    "art/overworld/runtime/terrain_tiles/roads/",
)
REQUIRED_ARTIFACT_FIELD_NAMES = (
    "trailsinger_boots", "quarry_tally_rod", "warcrest_pennon", "bastion_gorget",
    "waymark_compass", "milepost_lantern", "tollstone_ring", "mudglass_beads",
    "choir_tuning_fork", "living_bridge_knot", "pressure_gauge_reliquary", "black_sail_compass",
    "rainstar_sextant", "asterfall_mantle", "cometwake_pennon",
    "bridgefire_standard", "reedshadow_waders", "prismward_mantle",
    "graftbark_cuirass", "quenchplate_vambrace", "fogwake_deckboots",
)
REQUIRED_ARTIFACT_FIELD_PCK_IMPORT_ENTRIES = tuple(
    f"art/overworld/runtime/objects/artifacts/{artifact_name}.png.import"
    for artifact_name in REQUIRED_ARTIFACT_FIELD_NAMES
)
REQUIRED_TAVERN_HERO_IDS = (
    "hero_embercourt_belis_rainledger",
    "hero_sable",
    "hero_sunvault_calis_sunvein",
    "hero_thornwake_ardren_briarmarshal",
    "hero_brasshollow_daxis_chaincaptain",
    "hero_veilmourn_cela_mistcorsair",
)
REQUIRED_TAVERN_HERO_PCK_IMPORT_ENTRIES = tuple(
    f"art/overworld/runtime/heroes/tavern_vanguard/{hero_id}.png.import"
    for hero_id in REQUIRED_TAVERN_HERO_IDS
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
    "does not exist.",
    "file is missing:",
)


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def relative(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


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
        "path": relative(path),
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
                "export_path": relative(path),
                "source_path": relative(source_path),
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


def source_art_import_payload_paths() -> tuple[set[str], set[str]]:
    metadata_paths: set[str] = set()
    imported_payload_paths: set[str] = set()
    for import_path in sorted((ROOT / "art").glob("*/source/**/*.import")):
        if not import_path.is_file():
            continue
        metadata_paths.add(import_path.relative_to(ROOT).as_posix())
        for line in import_path.read_text(encoding="utf-8").splitlines():
            value = line.strip()
            if value.startswith('path="res://') and value.endswith('"'):
                imported_payload_paths.add(value.removeprefix('path="res://').removesuffix('"'))
                break
    return metadata_paths, imported_payload_paths


def pck_terrain_payload_summary() -> dict:
    source_art_metadata_paths, source_art_imported_payload_paths = source_art_import_payload_paths()
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
        "required_tavern_hero_import_entries": list(REQUIRED_TAVERN_HERO_PCK_IMPORT_ENTRIES),
        "tavern_hero_import_entries": [],
        "tavern_hero_texture_names": [],
        "tavern_hero_entries_present": False,
        "repository_source_art_metadata_count": len(source_art_metadata_paths),
        "repository_source_art_imported_payload_count": len(source_art_imported_payload_paths),
        "source_art_metadata_entries": [],
        "source_art_imported_payload_entries": [],
        "source_art_imported_payload_bytes": 0,
        "source_art_excluded": False,
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
                entry_size = struct.unpack_from("<Q", metadata, 8)[0]
                if entry_path.startswith("art/") and "/source/" in entry_path:
                    summary["source_art_metadata_entries"].append(entry_path)
                if entry_path in source_art_imported_payload_paths:
                    summary["source_art_imported_payload_entries"].append(entry_path)
                    summary["source_art_imported_payload_bytes"] += entry_size
                for prefix in FORBIDDEN_TERRAIN_PCK_PREFIXES:
                    if entry_path.startswith(prefix):
                        summary["forbidden_entries"].append(entry_path)
                for prefix in REQUIRED_TERRAIN_PCK_PREFIXES:
                    if entry_path.startswith(prefix):
                        summary["required_prefix_counts"][prefix] += 1
                if entry_path in REQUIRED_ARTIFACT_FIELD_PCK_IMPORT_ENTRIES:
                    summary["artifact_field_import_entries"].append(entry_path)
                if entry_path in REQUIRED_TAVERN_HERO_PCK_IMPORT_ENTRIES:
                    summary["tavern_hero_import_entries"].append(entry_path)
                if entry_path.startswith(".godot/imported/") and entry_path.endswith(".ctex"):
                    imported_name = Path(entry_path).name.split(".png-", 1)[0]
                    if imported_name in REQUIRED_ARTIFACT_FIELD_NAMES:
                        summary["artifact_field_texture_names"].append(imported_name)
                    if imported_name in REQUIRED_TAVERN_HERO_IDS:
                        summary["tavern_hero_texture_names"].append(imported_name)
            summary["valid_directory"] = handle.tell() == file_size
    except (OSError, struct.error, UnicodeError):
        return summary
    summary["required_entries_present"] = all(
        count > 0 for count in summary["required_prefix_counts"].values()
    )
    summary["artifact_field_entries_present"] = set(summary["artifact_field_import_entries"]) == set(REQUIRED_ARTIFACT_FIELD_PCK_IMPORT_ENTRIES) and set(summary["artifact_field_texture_names"]) == set(REQUIRED_ARTIFACT_FIELD_NAMES)
    summary["tavern_hero_entries_present"] = set(summary["tavern_hero_import_entries"]) == set(REQUIRED_TAVERN_HERO_PCK_IMPORT_ENTRIES) and set(summary["tavern_hero_texture_names"]) == set(REQUIRED_TAVERN_HERO_IDS)
    summary["source_art_excluded"] = (
        len(source_art_metadata_paths) > 0
        and len(source_art_imported_payload_paths) > 0
        and not summary["source_art_metadata_entries"]
        and not summary["source_art_imported_payload_entries"]
    )
    return summary


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
    terrain_payload = pck_terrain_payload_summary()
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
        and int(pck["size_bytes"]) <= MAX_RELEASE_PCK_BYTES
        and bool(libraries["all_exported"])
        and bool(terrain_payload["valid_directory"])
        and not terrain_payload["forbidden_entries"]
        and bool(terrain_payload["required_entries_present"])
        and bool(terrain_payload["artifact_field_entries_present"])
        and bool(terrain_payload["tavern_hero_entries_present"])
        and bool(terrain_payload["source_art_excluded"])
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
            "export_binary": relative(BINARY_PATH),
            "claims": [
                "The Linux Release preset can export a real executable artifact in this local Godot environment.",
                "The exported executable has an ELF x86_64 header and executable permission bits.",
                "The sidecar PCK and required Linux native GDExtension shared library are present beside the executable.",
                "The release PCK excludes development source-art metadata and imported source textures while retaining runtime assets.",
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
        "terrain_pck_payload": terrain_payload,
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
        "terrain_pck_forbidden_entry_count": len(terrain_payload["forbidden_entries"]),
        "terrain_pck_required_entries_present": terrain_payload["required_entries_present"],
        "artifact_field_pck_import_entry_count": len(terrain_payload["artifact_field_import_entries"]),
        "artifact_field_pck_texture_count": len(set(terrain_payload["artifact_field_texture_names"])),
        "artifact_field_pck_entries_present": terrain_payload["artifact_field_entries_present"],
        "tavern_hero_pck_import_entry_count": len(terrain_payload["tavern_hero_import_entries"]),
        "tavern_hero_pck_texture_count": len(set(terrain_payload["tavern_hero_texture_names"])),
        "tavern_hero_pck_entries_present": terrain_payload["tavern_hero_entries_present"],
        "source_art_pck_metadata_entry_count": len(terrain_payload["source_art_metadata_entries"]),
        "source_art_pck_imported_payload_count": len(terrain_payload["source_art_imported_payload_entries"]),
        "source_art_pck_imported_payload_bytes": terrain_payload["source_art_imported_payload_bytes"],
        "source_art_pck_excluded": terrain_payload["source_art_excluded"],
        "pck_within_release_size_ceiling": int(pck["size_bytes"]) <= MAX_RELEASE_PCK_BYTES,
        "fatal_export_matches": export_fatal_matches,
        "boot_fatal_matches": boot_fatal_matches,
        "report": relative(REPORT_PATH),
    }
    print(f"{REPORT_ID} {json.dumps(summary, sort_keys=True)}")
    if not report["ok"]:
        print(f"Report written to {relative(REPORT_PATH)}", file=sys.stderr)
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
