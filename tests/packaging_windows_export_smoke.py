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
MAX_RELEASE_PCK_BYTES = 250_000_000
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
REQUIRED_SPECIALIST_HERO_IDS = (
    "hero_torren",
    "hero_mireclaw_brakka_mudkeel",
    "hero_varis",
    "hero_thornwake_veyra_seedseer",
    "hero_brasshollow_selka_pitmarshal",
    "hero_veilmourn_morwen_wakeoracle",
)
REQUIRED_SPECIALIST_HERO_PCK_IMPORT_ENTRIES = tuple(
    f"art/overworld/runtime/heroes/tavern_specialists/{hero_id}.png.import"
    for hero_id in REQUIRED_SPECIALIST_HERO_IDS
)
REQUIRED_FIELD_COMMANDER_HERO_IDS = (
    "hero_embercourt_helva_tollbrand",
    "hero_tarn",
    "hero_sunvault_ilyr_glassmarshal",
    "hero_thornwake_halen_thorncart",
    "hero_brasshollow_kuld_varn",
    "hero_veilmourn_jessa_keelwarden",
)
REQUIRED_FIELD_COMMANDER_HERO_PCK_IMPORT_ENTRIES = tuple(
    f"art/overworld/runtime/heroes/tavern_field_commanders/{hero_id}.png.import"
    for hero_id in REQUIRED_FIELD_COMMANDER_HERO_IDS
)
REQUIRED_STRATEGIC_OFFICER_HERO_IDS = (
    "hero_embercourt_saren_lockmaster",
    "hero_orrik",
    "hero_thalen",
    "hero_thornwake_nara_graftsibyl",
    "hero_brasshollow_harro_debtrune",
    "hero_veilmourn_orso_nightchart",
)
REQUIRED_STRATEGIC_OFFICER_HERO_PCK_IMPORT_ENTRIES = tuple(
    f"art/overworld/runtime/heroes/tavern_strategic_officers/{hero_id}.png.import"
    for hero_id in REQUIRED_STRATEGIC_OFFICER_HERO_IDS
)
REQUIRED_RITUAL_SCHOLAR_HERO_IDS = (
    "hero_embercourt_orra_cinderquill",
    "hero_mireclaw_nix_votivejaw",
    "hero_sunvault_essa_daynote",
    "hero_thornwake_osmund_pollenglass",
    "hero_brasshollow_odrik_heatpriest",
    "hero_veilmourn_thir_obituaryink",
)
REQUIRED_RITUAL_SCHOLAR_HERO_PCK_IMPORT_ENTRIES = tuple(
    f"art/overworld/runtime/heroes/tavern_ritual_scholars/{hero_id}.png.import"
    for hero_id in REQUIRED_RITUAL_SCHOLAR_HERO_IDS
)
REQUIRED_ARCANE_CONTROLLER_HERO_IDS = (
    "hero_embercourt_jorun_beaconscribe",
    "hero_mireclaw_edda_rotlamp",
    "hero_sunvault_mirro_halometer",
    "hero_thornwake_elian_loamchant",
    "hero_brasshollow_lina_gaugesavant",
    "hero_veilmourn_sael_mirrorbell",
)
REQUIRED_ARCANE_CONTROLLER_HERO_PCK_IMPORT_ENTRIES = tuple(
    f"art/overworld/runtime/heroes/tavern_arcane_controllers/{hero_id}.png.import"
    for hero_id in REQUIRED_ARCANE_CONTROLLER_HERO_IDS
)
REQUIRED_FINAL_ROSTER_HERO_IDS = (
    "hero_mireclaw_pell_reedscript", "hero_mireclaw_zhorra_fenwake",
    "hero_sunvault_dovan_lenscaptain", "hero_sunvault_renn_facetlane",
    "hero_thornwake_merek_greenbarrow", "hero_thornwake_ralka_mossvein",
    "hero_brasshollow_pava_ashmeter", "hero_brasshollow_vellum_quench",
    "hero_veilmourn_damar_oriflag", "hero_veilmourn_nacre_vowless",
)
REQUIRED_FINAL_ROSTER_HERO_PCK_IMPORT_ENTRIES = tuple(
    f"art/overworld/runtime/heroes/tavern_final_roster/{hero_id}.png.import"
    for hero_id in REQUIRED_FINAL_ROSTER_HERO_IDS
)
REQUIRED_FACTION_ENCOUNTER_NAMES = (
    "embercourt", "mireclaw", "sunvault", "thornwake", "brasshollow", "veilmourn",
)
REQUIRED_FACTION_ENCOUNTER_PCK_IMPORT_ENTRIES = tuple(
    f"art/overworld/runtime/objects/encounters/factions/{faction_name}.png.import"
    for faction_name in REQUIRED_FACTION_ENCOUNTER_NAMES
)
REQUIRED_CAMPAIGN_EMBLEM_NAMES = (
    "reedfall_lantern", "stonewake_watchstone", "bogbound_oath_drum",
    "daybreak_shards", "ninefold_survey_compass", "frontier_claims_cairn",
)
REQUIRED_CAMPAIGN_EMBLEM_PCK_IMPORT_ENTRIES = tuple(
    f"art/campaigns/runtime/emblems/{emblem_name}.png.import"
    for emblem_name in REQUIRED_CAMPAIGN_EMBLEM_NAMES
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


def imported_payload_paths_for(import_entries: tuple[str, ...]) -> set[str]:
    payload_paths: set[str] = set()
    for entry in import_entries:
        import_path = ROOT / entry
        if not import_path.is_file():
            continue
        for line in import_path.read_text(encoding="utf-8").splitlines():
            value = line.strip()
            if value.startswith('path="res://') and value.endswith('"'):
                payload_paths.add(value.removeprefix('path="res://').removesuffix('"'))
                break
    return payload_paths


def pck_terrain_payload_summary() -> dict:
    source_art_metadata_paths, source_art_imported_payload_paths = source_art_import_payload_paths()
    required_faction_encounter_texture_entries = imported_payload_paths_for(REQUIRED_FACTION_ENCOUNTER_PCK_IMPORT_ENTRIES)
    required_campaign_emblem_texture_entries = imported_payload_paths_for(REQUIRED_CAMPAIGN_EMBLEM_PCK_IMPORT_ENTRIES)
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
        "required_specialist_hero_import_entries": list(REQUIRED_SPECIALIST_HERO_PCK_IMPORT_ENTRIES),
        "specialist_hero_import_entries": [],
        "specialist_hero_texture_names": [],
        "specialist_hero_entries_present": False,
        "required_field_commander_hero_import_entries": list(REQUIRED_FIELD_COMMANDER_HERO_PCK_IMPORT_ENTRIES),
        "field_commander_hero_import_entries": [],
        "field_commander_hero_texture_names": [],
        "field_commander_hero_entries_present": False,
        "required_strategic_officer_hero_import_entries": list(REQUIRED_STRATEGIC_OFFICER_HERO_PCK_IMPORT_ENTRIES),
        "strategic_officer_hero_import_entries": [],
        "strategic_officer_hero_texture_names": [],
        "strategic_officer_hero_entries_present": False,
        "required_ritual_scholar_hero_import_entries": list(REQUIRED_RITUAL_SCHOLAR_HERO_PCK_IMPORT_ENTRIES),
        "ritual_scholar_hero_import_entries": [],
        "ritual_scholar_hero_texture_names": [],
        "ritual_scholar_hero_entries_present": False,
        "required_arcane_controller_hero_import_entries": list(REQUIRED_ARCANE_CONTROLLER_HERO_PCK_IMPORT_ENTRIES),
        "arcane_controller_hero_import_entries": [],
        "arcane_controller_hero_texture_names": [],
        "arcane_controller_hero_entries_present": False,
        "required_final_roster_hero_import_entries": list(REQUIRED_FINAL_ROSTER_HERO_PCK_IMPORT_ENTRIES),
        "final_roster_hero_import_entries": [],
        "final_roster_hero_texture_names": [],
        "final_roster_hero_entries_present": False,
        "required_faction_encounter_import_entries": list(REQUIRED_FACTION_ENCOUNTER_PCK_IMPORT_ENTRIES),
        "required_faction_encounter_texture_entries": sorted(required_faction_encounter_texture_entries),
        "faction_encounter_import_entries": [],
        "faction_encounter_texture_entries": [],
        "faction_encounter_entries_present": False,
        "required_campaign_emblem_import_entries": list(REQUIRED_CAMPAIGN_EMBLEM_PCK_IMPORT_ENTRIES),
        "required_campaign_emblem_texture_entries": sorted(required_campaign_emblem_texture_entries),
        "campaign_emblem_import_entries": [],
        "campaign_emblem_texture_entries": [],
        "campaign_emblem_entries_present": False,
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
                if entry_path in REQUIRED_SPECIALIST_HERO_PCK_IMPORT_ENTRIES:
                    summary["specialist_hero_import_entries"].append(entry_path)
                if entry_path in REQUIRED_FIELD_COMMANDER_HERO_PCK_IMPORT_ENTRIES:
                    summary["field_commander_hero_import_entries"].append(entry_path)
                if entry_path in REQUIRED_STRATEGIC_OFFICER_HERO_PCK_IMPORT_ENTRIES:
                    summary["strategic_officer_hero_import_entries"].append(entry_path)
                if entry_path in REQUIRED_RITUAL_SCHOLAR_HERO_PCK_IMPORT_ENTRIES:
                    summary["ritual_scholar_hero_import_entries"].append(entry_path)
                if entry_path in REQUIRED_ARCANE_CONTROLLER_HERO_PCK_IMPORT_ENTRIES:
                    summary["arcane_controller_hero_import_entries"].append(entry_path)
                if entry_path in REQUIRED_FINAL_ROSTER_HERO_PCK_IMPORT_ENTRIES:
                    summary["final_roster_hero_import_entries"].append(entry_path)
                if entry_path in REQUIRED_FACTION_ENCOUNTER_PCK_IMPORT_ENTRIES:
                    summary["faction_encounter_import_entries"].append(entry_path)
                if entry_path in required_faction_encounter_texture_entries:
                    summary["faction_encounter_texture_entries"].append(entry_path)
                if entry_path in REQUIRED_CAMPAIGN_EMBLEM_PCK_IMPORT_ENTRIES:
                    summary["campaign_emblem_import_entries"].append(entry_path)
                if entry_path in required_campaign_emblem_texture_entries:
                    summary["campaign_emblem_texture_entries"].append(entry_path)
                if entry_path.startswith(".godot/imported/") and entry_path.endswith(".ctex"):
                    imported_name = Path(entry_path).name.split(".png-", 1)[0]
                    if imported_name in REQUIRED_ARTIFACT_FIELD_NAMES:
                        summary["artifact_field_texture_names"].append(imported_name)
                    if imported_name in REQUIRED_TAVERN_HERO_IDS:
                        summary["tavern_hero_texture_names"].append(imported_name)
                    if imported_name in REQUIRED_SPECIALIST_HERO_IDS:
                        summary["specialist_hero_texture_names"].append(imported_name)
                    if imported_name in REQUIRED_FIELD_COMMANDER_HERO_IDS:
                        summary["field_commander_hero_texture_names"].append(imported_name)
                    if imported_name in REQUIRED_STRATEGIC_OFFICER_HERO_IDS:
                        summary["strategic_officer_hero_texture_names"].append(imported_name)
                    if imported_name in REQUIRED_RITUAL_SCHOLAR_HERO_IDS:
                        summary["ritual_scholar_hero_texture_names"].append(imported_name)
                    if imported_name in REQUIRED_ARCANE_CONTROLLER_HERO_IDS:
                        summary["arcane_controller_hero_texture_names"].append(imported_name)
                    if imported_name in REQUIRED_FINAL_ROSTER_HERO_IDS:
                        summary["final_roster_hero_texture_names"].append(imported_name)
            summary["valid_directory"] = handle.tell() == file_size
    except (OSError, struct.error, UnicodeError):
        return summary
    summary["required_entries_present"] = all(
        count > 0 for count in summary["required_prefix_counts"].values()
    )
    summary["artifact_field_entries_present"] = set(summary["artifact_field_import_entries"]) == set(REQUIRED_ARTIFACT_FIELD_PCK_IMPORT_ENTRIES) and set(summary["artifact_field_texture_names"]) == set(REQUIRED_ARTIFACT_FIELD_NAMES)
    summary["tavern_hero_entries_present"] = set(summary["tavern_hero_import_entries"]) == set(REQUIRED_TAVERN_HERO_PCK_IMPORT_ENTRIES) and set(summary["tavern_hero_texture_names"]) == set(REQUIRED_TAVERN_HERO_IDS)
    summary["specialist_hero_entries_present"] = set(summary["specialist_hero_import_entries"]) == set(REQUIRED_SPECIALIST_HERO_PCK_IMPORT_ENTRIES) and set(summary["specialist_hero_texture_names"]) == set(REQUIRED_SPECIALIST_HERO_IDS)
    summary["field_commander_hero_entries_present"] = set(summary["field_commander_hero_import_entries"]) == set(REQUIRED_FIELD_COMMANDER_HERO_PCK_IMPORT_ENTRIES) and set(summary["field_commander_hero_texture_names"]) == set(REQUIRED_FIELD_COMMANDER_HERO_IDS)
    summary["strategic_officer_hero_entries_present"] = set(summary["strategic_officer_hero_import_entries"]) == set(REQUIRED_STRATEGIC_OFFICER_HERO_PCK_IMPORT_ENTRIES) and set(summary["strategic_officer_hero_texture_names"]) == set(REQUIRED_STRATEGIC_OFFICER_HERO_IDS)
    summary["ritual_scholar_hero_entries_present"] = set(summary["ritual_scholar_hero_import_entries"]) == set(REQUIRED_RITUAL_SCHOLAR_HERO_PCK_IMPORT_ENTRIES) and set(summary["ritual_scholar_hero_texture_names"]) == set(REQUIRED_RITUAL_SCHOLAR_HERO_IDS)
    summary["arcane_controller_hero_entries_present"] = set(summary["arcane_controller_hero_import_entries"]) == set(REQUIRED_ARCANE_CONTROLLER_HERO_PCK_IMPORT_ENTRIES) and set(summary["arcane_controller_hero_texture_names"]) == set(REQUIRED_ARCANE_CONTROLLER_HERO_IDS)
    summary["final_roster_hero_entries_present"] = set(summary["final_roster_hero_import_entries"]) == set(REQUIRED_FINAL_ROSTER_HERO_PCK_IMPORT_ENTRIES) and set(summary["final_roster_hero_texture_names"]) == set(REQUIRED_FINAL_ROSTER_HERO_IDS)
    summary["faction_encounter_entries_present"] = len(required_faction_encounter_texture_entries) == len(REQUIRED_FACTION_ENCOUNTER_NAMES) and set(summary["faction_encounter_import_entries"]) == set(REQUIRED_FACTION_ENCOUNTER_PCK_IMPORT_ENTRIES) and set(summary["faction_encounter_texture_entries"]) == required_faction_encounter_texture_entries
    summary["campaign_emblem_entries_present"] = len(required_campaign_emblem_texture_entries) == len(REQUIRED_CAMPAIGN_EMBLEM_NAMES) and set(summary["campaign_emblem_import_entries"]) == set(REQUIRED_CAMPAIGN_EMBLEM_PCK_IMPORT_ENTRIES) and set(summary["campaign_emblem_texture_entries"]) == required_campaign_emblem_texture_entries
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
        and int(pck["size_bytes"]) <= MAX_RELEASE_PCK_BYTES
        and bool(dlls["all_exported"])
        and bool(terrain_payload["valid_directory"])
        and not terrain_payload["forbidden_entries"]
        and bool(terrain_payload["required_entries_present"])
        and bool(terrain_payload["artifact_field_entries_present"])
        and bool(terrain_payload["tavern_hero_entries_present"])
        and bool(terrain_payload["specialist_hero_entries_present"])
        and bool(terrain_payload["field_commander_hero_entries_present"])
        and bool(terrain_payload["strategic_officer_hero_entries_present"])
        and bool(terrain_payload["ritual_scholar_hero_entries_present"])
        and bool(terrain_payload["arcane_controller_hero_entries_present"])
        and bool(terrain_payload["final_roster_hero_entries_present"])
        and bool(terrain_payload["faction_encounter_entries_present"])
        and bool(terrain_payload["campaign_emblem_entries_present"])
        and bool(terrain_payload["source_art_excluded"])
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
                "The release PCK excludes development source-art metadata and imported source textures while retaining runtime assets.",
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
        "tavern_hero_pck_import_entry_count": len(terrain_payload["tavern_hero_import_entries"]),
        "tavern_hero_pck_texture_count": len(set(terrain_payload["tavern_hero_texture_names"])),
        "tavern_hero_pck_entries_present": terrain_payload["tavern_hero_entries_present"],
        "specialist_hero_pck_import_entry_count": len(terrain_payload["specialist_hero_import_entries"]),
        "specialist_hero_pck_texture_count": len(set(terrain_payload["specialist_hero_texture_names"])),
        "specialist_hero_pck_entries_present": terrain_payload["specialist_hero_entries_present"],
        "field_commander_hero_pck_import_entry_count": len(terrain_payload["field_commander_hero_import_entries"]),
        "field_commander_hero_pck_texture_count": len(set(terrain_payload["field_commander_hero_texture_names"])),
        "field_commander_hero_pck_entries_present": terrain_payload["field_commander_hero_entries_present"],
        "strategic_officer_hero_pck_import_entry_count": len(terrain_payload["strategic_officer_hero_import_entries"]),
        "strategic_officer_hero_pck_texture_count": len(set(terrain_payload["strategic_officer_hero_texture_names"])),
        "strategic_officer_hero_pck_entries_present": terrain_payload["strategic_officer_hero_entries_present"],
        "ritual_scholar_hero_pck_import_entry_count": len(terrain_payload["ritual_scholar_hero_import_entries"]),
        "ritual_scholar_hero_pck_texture_count": len(set(terrain_payload["ritual_scholar_hero_texture_names"])),
        "ritual_scholar_hero_pck_entries_present": terrain_payload["ritual_scholar_hero_entries_present"],
        "arcane_controller_hero_pck_import_entry_count": len(terrain_payload["arcane_controller_hero_import_entries"]),
        "arcane_controller_hero_pck_texture_count": len(set(terrain_payload["arcane_controller_hero_texture_names"])),
        "arcane_controller_hero_pck_entries_present": terrain_payload["arcane_controller_hero_entries_present"],
        "final_roster_hero_pck_import_entry_count": len(terrain_payload["final_roster_hero_import_entries"]),
        "final_roster_hero_pck_texture_count": len(set(terrain_payload["final_roster_hero_texture_names"])),
        "final_roster_hero_pck_entries_present": terrain_payload["final_roster_hero_entries_present"],
        "faction_encounter_pck_import_entry_count": len(terrain_payload["faction_encounter_import_entries"]),
        "faction_encounter_pck_texture_count": len(terrain_payload["faction_encounter_texture_entries"]),
        "faction_encounter_pck_entries_present": terrain_payload["faction_encounter_entries_present"],
        "campaign_emblem_pck_import_entry_count": len(terrain_payload["campaign_emblem_import_entries"]),
        "campaign_emblem_pck_texture_count": len(terrain_payload["campaign_emblem_texture_entries"]),
        "campaign_emblem_pck_entries_present": terrain_payload["campaign_emblem_entries_present"],
        "source_art_pck_metadata_entry_count": len(terrain_payload["source_art_metadata_entries"]),
        "source_art_pck_imported_payload_count": len(terrain_payload["source_art_imported_payload_entries"]),
        "source_art_pck_imported_payload_bytes": terrain_payload["source_art_imported_payload_bytes"],
        "source_art_pck_excluded": terrain_payload["source_art_excluded"],
        "pck_within_release_size_ceiling": int(pck["size_bytes"]) <= MAX_RELEASE_PCK_BYTES,
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
