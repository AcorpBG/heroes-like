#!/usr/bin/env python3
"""Create controlled h3maped.exe RMG reference artifacts.

The phase-drift audit needs reference maps with known generation identity. A
shipped `.h3m` can be parsed as corpus evidence, but it cannot prove the seed
and template identity used by h3maped.exe. This tool enforces that boundary:
reference generation must come from a committed controlled h3maped runner.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import rmg_fast_audit as fast_audit  # noqa: E402


DEFAULT_H3MAPED_EXE = Path("/root/Downloads/h3maped.exe")
EXPECTED_H3MAPED_SHA256 = "4480fba145c9f885942cc668d4bce430fe39c0fa482d1a6e58f96318ab857a37"
DEFAULT_OUT_ROOT = Path(".artifacts/rmg_h3maped_controlled_reference")
DEFAULT_WINEPREFIX = Path(".artifacts/wine/h3maped")
REQUIRED_RESOURCE_LODS = ("h3bitmap.lod", "h3sprite.lod", "h3ab_bmp.lod", "h3ab_spr.lod")
HOMM3_RE_TEMPLATE_CATALOG = Path("/root/.openclaw/workspace/tasks/10184/artifacts/homm3-re/rmg-template-catalog.json")

SEED_PATCH_WRITE_FILE_OFFSET = 0x9D9C4
SEED_PATCH_SECOND_POP_FILE_OFFSET = 0x9D9D2
SEED_PATCH_ORIGINAL_BYTES = bytes.fromhex("57 e8 c3 9d 04 00 ff 37")
SEED_PATCH_ORIGINAL_SECOND_POP = 0x59

SIZE_COORDS = {
    "small": (341, 413),
    "medium": (341, 432),
    "large": (439, 413),
    "extra_large": (439, 432),
}
SIZE_DIMENSIONS = {
    "small": 36,
    "medium": 72,
    "large": 108,
    "extra_large": 144,
}
WATER_COORDS = {
    "random": (340, 647),
    "land": (449, 647),
    "mixed": (557, 647),
    "water": (665, 647),
}
MONSTER_COORDS = {
    "random": (340, 697),
    "weak": (449, 697),
    "normal": (557, 697),
    "strong": (665, 697),
}


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_markdown(manifest: dict[str, Any], path: Path) -> None:
    inputs = manifest.get("inputs", {})
    identity = manifest.get("controlled_identity", {})
    lines = [
        "# Controlled h3maped Reference",
        "",
        f"- Status: `{manifest.get('status')}`",
        f"- Case: `{manifest.get('case_id')}`",
        f"- Mode: `{manifest.get('mode')}`",
        f"- h3maped SHA-256: `{manifest.get('h3maped', {}).get('sha256', '')}`",
        f"- Seed: `{inputs.get('seed', '')}`",
        f"- Players: `{inputs.get('players', '')}`",
        f"- Size: `{inputs.get('size', '')}`",
        f"- Water: `{inputs.get('water', '')}`",
        f"- Source template: `{identity.get('source_template_id', '')}`",
        f"- Source catalog index: `{identity.get('source_catalog_index', '')}`",
        f"- Same-seed parity supported: `{identity.get('same_seed_parity_supported', '')}`",
        "",
    ]
    seed_control = manifest.get("seed_control", {})
    if seed_control:
        lines.extend(
            [
                "## Seed Control",
                "",
                f"- Status: `{seed_control.get('status', '')}`",
                f"- Reason: {seed_control.get('reason', '')}",
                "",
            ]
        )
    if manifest.get("status") != "ready":
        lines.extend([
            "## Blocker",
            "",
            str(manifest.get("blocker", manifest.get("error", ""))),
            "",
        ])
    metrics = manifest.get("metrics", {})
    compact = metrics.get("compact", {}) if isinstance(metrics, dict) else {}
    required = metrics.get("required", {}) if isinstance(metrics, dict) else {}
    if compact:
        lines.extend(["## Compact Metrics", ""])
        for key in ["object_count", "counts_by_category", "road_cell_count_total", "nearest_town_manhattan_min"]:
            lines.append(f"- `{key}`: `{compact.get(key)}`")
        lines.append("")
    if required:
        lines.extend(["## Required Corpus Metrics", ""])
        for key in [
            "object_count",
            "town_count",
            "road_cell_count",
            "guard_count",
            "reward_count",
            "blocker_like_object_count",
            "body_tile_count_total",
            "block_tile_count_total",
            "visit_tile_count_total",
            "guard_control_tile_count_total",
        ]:
            lines.append(f"- `{key}`: `{required.get(key)}`")
        route = required.get("route_topology", {}) if isinstance(required.get("route_topology"), dict) else {}
        if route:
            lines.append(f"- `route_topology`: `{route}`")
        lines.append("")
    path.write_text("\n".join(lines) + "\n")


def backend_report() -> dict[str, Any]:
    return {
        "host_platform": platform.platform(),
        "os_name": os.name,
        "is_windows_host": os.name == "nt",
        "wine": shutil.which("wine"),
        "wineboot": shutil.which("wineboot"),
        "wineserver": shutil.which("wineserver"),
        "xvfb_run": shutil.which("xvfb-run"),
        "xdotool": shutil.which("xdotool"),
        "scrot": shutil.which("scrot"),
        "automation_backend": "wine_xvfb_xdotool_mfc_dialog_v1",
    }


def verify_exe(path: Path) -> dict[str, Any]:
    result: dict[str, Any] = {
        "path": str(path),
        "exists": path.exists(),
        "expected_sha256": EXPECTED_H3MAPED_SHA256,
    }
    if not path.exists():
        result["status"] = "missing"
        return result
    data = path.read_bytes()[:2]
    result["mz_header"] = data == b"MZ"
    result["size_bytes"] = path.stat().st_size
    result["sha256"] = sha256_file(path)
    result["status"] = "verified" if result["mz_header"] and result["sha256"] == EXPECTED_H3MAPED_SHA256 else "mismatch"
    return result


def build_base_manifest(args: argparse.Namespace, out_dir: Path, mode: str) -> dict[str, Any]:
    h3maped = verify_exe(args.h3maped_exe)
    return {
        "schema_id": "rmg_h3maped_controlled_reference_manifest_v1",
        "status": "initializing",
        "mode": mode,
        "case_id": args.case,
        "created_at": utc_now(),
        "tool": "tools/rmg_h3maped_controlled_reference.py",
        "output_dir": str(out_dir),
        "h3maped": h3maped,
        "inputs": {
            "seed": str(args.seed),
            "players": int(args.players),
            "human_players": int(args.human_players),
            "computer_only_players": int(args.computer_only_players),
            "size": args.size,
            "width": int(args.width),
            "height": int(args.height),
            "level_count": int(args.level_count),
            "water": args.water,
            "template_id": args.template_id,
            "monster_strength": args.monster_strength,
        },
        "controlled_identity": {
            "requested_seed": str(args.seed),
            "seed": "",
            "players": int(args.players),
            "source_template_id": args.source_template_id,
            "source_catalog_index": args.source_catalog_index,
            "same_seed_parity_supported": False,
            "identity_authority": "h3maped_gui_generated_output_observed_seed_unavailable",
        },
        "seed_control": {
            "mode": args.seed_control_mode,
            "status": "pending",
            "reason": "",
        },
        "backend": backend_report(),
    }


def write_manifest(manifest: dict[str, Any], out_dir: Path, pretty: bool) -> tuple[Path, Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = out_dir / "controlled_reference_manifest.json"
    md_path = out_dir / "controlled_reference_manifest.md"
    manifest_path.write_text(json.dumps(manifest, indent=2 if pretty else None, sort_keys=True) + "\n")
    write_markdown(manifest, md_path)
    return manifest_path, md_path


def command_output(command: list[str]) -> str:
    probe = subprocess.run(command, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False)
    return probe.stdout.strip()


def find_lod(source_dir: Path, name: str) -> Path | None:
    candidates = [source_dir / "Data", source_dir / "data", source_dir]
    lowered = name.lower()
    for base in candidates:
        if not base.exists():
            continue
        direct = base / name
        if direct.exists():
            return direct
        for child in base.iterdir():
            if child.name.lower() == lowered and child.is_file():
                return child
    return None


def symlink_or_copy(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists() or destination.is_symlink():
        destination.unlink()
    try:
        destination.symlink_to(source)
    except OSError:
        shutil.copy2(source, destination)


def parse_requested_seed(seed: str) -> int:
    value = int(str(seed), 0)
    if value < -(2**31) or value > 0xFFFFFFFF:
        raise ValueError(f"seed out of 32-bit range: {seed}")
    return value & 0xFFFFFFFF


def patch_h3maped_seed(runtime_exe: Path, seed: int) -> dict[str, Any]:
    data = bytearray(runtime_exe.read_bytes())
    original = bytes(data[SEED_PATCH_WRITE_FILE_OFFSET : SEED_PATCH_WRITE_FILE_OFFSET + len(SEED_PATCH_ORIGINAL_BYTES)])
    original_second_pop = data[SEED_PATCH_SECOND_POP_FILE_OFFSET]
    if original != SEED_PATCH_ORIGINAL_BYTES or original_second_pop != SEED_PATCH_ORIGINAL_SECOND_POP:
        return {
            "status": "blocked_unexpected_seed_patch_bytes",
            "write_file_offset": hex(SEED_PATCH_WRITE_FILE_OFFSET),
            "expected_bytes": SEED_PATCH_ORIGINAL_BYTES.hex(" "),
            "actual_bytes": original.hex(" "),
            "second_pop_file_offset": hex(SEED_PATCH_SECOND_POP_FILE_OFFSET),
            "expected_second_pop": hex(SEED_PATCH_ORIGINAL_SECOND_POP),
            "actual_second_pop": hex(original_second_pop),
        }

    patch = b"\xc7\x07" + seed.to_bytes(4, "little", signed=False) + b"\xff\x37"
    data[SEED_PATCH_WRITE_FILE_OFFSET : SEED_PATCH_WRITE_FILE_OFFSET + len(patch)] = patch
    data[SEED_PATCH_SECOND_POP_FILE_OFFSET] = 0x90
    runtime_exe.write_bytes(data)
    return {
        "status": "patched",
        "strategy": "artifact_pe_patch_type_random_map_generator_seed_ctor",
        "requested_seed_uint32": seed,
        "patched_exe": str(runtime_exe),
        "patched_sha256": sha256_file(runtime_exe),
        "write_virtual_address": "0x49d9c4",
        "write_file_offset": hex(SEED_PATCH_WRITE_FILE_OFFSET),
        "write_patch_bytes": patch.hex(" "),
        "second_pop_virtual_address": "0x49d9d2",
        "second_pop_file_offset": hex(SEED_PATCH_SECOND_POP_FILE_OFFSET),
        "second_pop_patch_byte": "90",
        "evidence": (
            "Replaces push/call to 0x4e778d seed source with mov dword ptr [edi], seed; "
            "push dword ptr [edi], then preserves h3maped's own 0x4e7269 RNG seed setter."
        ),
    }


def template_identity_from_observed_name(name: str) -> dict[str, Any]:
    if not name or not HOMM3_RE_TEMPLATE_CATALOG.exists():
        return {}
    parsed = json.loads(HOMM3_RE_TEMPLATE_CATALOG.read_text())
    templates = parsed.get("templates", parsed if isinstance(parsed, list) else [])
    for index, entry in enumerate(templates):
        if str(entry.get("name", "")) == name:
            return {
                "observed_source_template_id": f"h3maped_template_{index:03d}",
                "observed_source_catalog_index": index,
                "observed_template_name": name,
            }
    return {"observed_template_name": name, "observed_template_catalog_lookup": "not_found"}


def prepare_runtime_layout(args: argparse.Namespace, out_dir: Path) -> dict[str, Any]:
    runtime_dir = out_dir / "runtime"
    data_dir = runtime_dir / "Data"
    runtime_dir.mkdir(parents=True, exist_ok=True)
    data_dir.mkdir(parents=True, exist_ok=True)
    runtime_exe = runtime_dir / "h3maped.exe"
    shutil.copy2(args.h3maped_exe.resolve(), runtime_exe)
    seed_patch: dict[str, Any] = {"status": "not_requested", "mode": args.seed_control_mode}
    if args.seed_control_mode == "pe-patch":
        seed_patch = patch_h3maped_seed(runtime_exe, parse_requested_seed(args.seed))

    resource_source_dir = args.resource_dir or args.h3maped_exe.parent
    resources: dict[str, str] = {}
    missing: list[str] = []
    for name in REQUIRED_RESOURCE_LODS:
        source = find_lod(resource_source_dir, name)
        if source is None:
            missing.append(name)
            continue
        target = data_dir / name
        symlink_or_copy(source.resolve(), target)
        resources[name] = str(source.resolve())
    return {
        "runtime_dir": runtime_dir,
        "data_dir": data_dir,
        "resources": resources,
        "missing": missing,
        "resource_source_dir": str(resource_source_dir),
        "runtime_exe": runtime_exe,
        "seed_patch": seed_patch,
    }


def repeat_key(key: str, count: int) -> str:
    return "\n".join(f"xdotool key {key}" for _ in range(max(0, count)))


def automation_script(args: argparse.Namespace, out_dir: Path, runtime: dict[str, Any], save_name: str) -> str:
    runtime_dir = Path(runtime["runtime_dir"]).resolve()
    output_h3m = (out_dir / save_name).resolve()
    artifact_root = Path(".artifacts").resolve()
    wine_output_dir = args.wineprefix.resolve() / "drive_c" / "h3maped_refs"
    wine_output_h3m = wine_output_dir / save_name
    screenshot_dir = (out_dir / "screenshots").resolve()
    screenshot_dir.mkdir(parents=True, exist_ok=True)
    size_x, size_y = SIZE_COORDS[args.size]
    water_x, water_y = WATER_COORDS[args.water]
    monster_x, monster_y = MONSTER_COORDS[args.monster_strength]
    computer_only_players = args.computer_only_players
    player_downs = repeat_key("Down", args.players)
    computer_downs = repeat_key("Down", computer_only_players + 1)
    level_click = "xdotool mousemove 328 466 click 1" if args.level_count == 1 else ":"
    backspaces = repeat_key("BackSpace", 80)
    return f"""#!/usr/bin/env bash
set -euo pipefail
export WINEPREFIX={str(args.wineprefix.resolve())!r}
export WINEARCH=win32
cd {str(runtime_dir)!r}
mkdir -p {str(wine_output_dir)!r}
rm -f {save_name!r} /{save_name!r} {str(output_h3m)!r} {str(wine_output_h3m)!r}
find {str(artifact_root)!r} {str(args.wineprefix.resolve())!r} -type f -name {save_name!r} -delete 2>/dev/null || true

screen() {{
  scrot {str(screenshot_dir)!r}/"$1".png || true
}}

wait_for_main() {{
  rm -f /tmp/h3maped_window_ids
  for _ in $(seq 1 80); do
    if xdotool search --onlyvisible --name 'Heroes of Might' | tail -n 1 >/tmp/h3maped_window_ids 2>/dev/null; then
      if [[ -s /tmp/h3maped_window_ids ]]; then
        return 0
      fi
    fi
    sleep 0.25
  done
  return 1
}}

wait_for_generated() {{
  for _ in $(seq 1 80); do
    if ! xdotool search --onlyvisible --name 'Generating map' >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.25
  done
  return 1
}}

wait_for_named() {{
  local name="$1"
  for _ in $(seq 1 40); do
    if xdotool search --onlyvisible --name "$name" >/tmp/h3maped_named_window_ids 2>/dev/null; then
      return 0
    fi
    sleep 0.25
  done
  return 1
}}

open_new_dialog() {{
  xdotool key Alt+f
  sleep 0.2
  xdotool key n
  if wait_for_named 'New Map'; then
    return 0
  fi
  xdotool mousemove 18 41 click 1
  sleep 0.2
  xdotool mousemove 35 61 click 1
  wait_for_named 'New Map'
}}

wineboot -u >/dev/null 2>&1 || true
wine ./h3maped.exe >{str((out_dir / "h3maped_wine.log").resolve())!r} 2>&1 &
H3MAPED_PID=$!
cleanup() {{
  kill "$H3MAPED_PID" >/dev/null 2>&1 || true
  wineserver -k >/dev/null 2>&1 || true
}}
trap cleanup EXIT

wait_for_main
sleep 3
screen 01_main

open_new_dialog
sleep 0.2
screen 02_new_dialog
xdotool mousemove {size_x} {size_y} click 1
{level_click}
xdotool mousemove 328 486 click 1
sleep 0.1

xdotool mousemove 528 538 click 1
sleep 0.1
{player_downs}
xdotool key Return
sleep 0.1

xdotool mousemove 744 538 click 1
sleep 0.1
{computer_downs}
xdotool key Return
sleep 0.1

xdotool mousemove {water_x} {water_y} click 1
xdotool mousemove {monster_x} {monster_y} click 1
screen 03_random_options

xdotool mousemove 592 311 click 1
sleep {args.generation_wait_seconds}
screen 04_generated

xdotool mousemove 18 41 click 1
sleep 0.2
xdotool mousemove 45 114 click 1
sleep 0.6
screen 05_save_as
xdotool mousemove 469 466 click 1
xdotool key ctrl+a
xdotool key End
{backspaces}
xdotool type --clearmodifiers {save_name!r}
screen 05b_filename_entered
xdotool mousemove 642 467 click 1
for _ in $(seq 1 20); do
  if [[ -f {save_name!r} || -f /{save_name!r} || -f {str(output_h3m)!r} || -f {str(wine_output_h3m)!r} ]]; then
    break
  fi
  candidate="$(find {str(artifact_root)!r} {str(args.wineprefix.resolve())!r} -type f -name {save_name!r} 2>/dev/null | head -n 1 || true)"
  if [[ -n "$candidate" && -f "$candidate" ]]; then
    break
  fi
  active_window="$(xdotool getactivewindow 2>/dev/null || true)"
  if [[ -n "$active_window" ]]; then
    xdotool windowactivate --sync "$active_window" key Return || true
    sleep 0.2
    xdotool windowactivate --sync "$active_window" key space || true
  fi
  xdotool mousemove 642 467 click --delay 200 1 || true
  xdotool key Alt+y || true
  sleep 0.5
done
screen 06_after_save

if [[ ! -f {save_name!r} && ! -f /{save_name!r} && ! -f {str(output_h3m)!r} && ! -f {str(wine_output_h3m)!r} ]]; then
  xdotool mousemove 642 467 click 1
  sleep 0.4
  xdotool mousemove 642 467 click --delay 200 1 || true
  sleep 1
  screen 07_after_save_retry
fi

candidate="$(find {str(artifact_root)!r} {str(args.wineprefix.resolve())!r} -type f -name {save_name!r} 2>/dev/null | head -n 1 || true)"
if [[ -f {str(output_h3m)!r} ]]; then
  :
elif [[ -f {str(wine_output_h3m)!r} ]]; then
  cp {str(wine_output_h3m)!r} {str((out_dir / save_name).resolve())!r}
elif [[ -f /{save_name!r} ]]; then
  mv /{save_name!r} {str((out_dir / save_name).resolve())!r}
elif [[ -f {save_name!r} ]]; then
  cp {save_name!r} {str((out_dir / save_name).resolve())!r}
elif [[ -n "$candidate" && -f "$candidate" ]]; then
  cp "$candidate" {str((out_dir / save_name).resolve())!r}
else
  exit 42
fi
"""


def extract_generation_summary(h3m_path: Path) -> dict[str, Any]:
    data = fast_audit.load_bytes(h3m_path)
    text = data.decode("latin-1", "ignore")
    marker = "Map created by the Random Map Generator"
    offset = text.find(marker)
    if offset < 0:
        return {
            "status": "missing",
            "reason": "No plaintext h3maped random-map description string was found in the saved H3M.",
        }
    end = text.find("\x00", offset)
    if end < 0:
        end = min(len(text), offset + 512)
    summary_text = text[offset:end]
    parsed: dict[str, Any] = {}
    match = re.search(
        r"Template was (?P<template>.*?), Random seed was (?P<seed>-?\d+), size (?P<size>\d+), "
        r"levels (?P<levels>\d+), humans (?P<humans>\d+), computers (?P<computers>\d+), "
        r"water (?P<water>.*?), monsters (?P<monsters>-?\d+)",
        summary_text,
    )
    if match:
        parsed = {
            "template": match.group("template"),
            "seed": int(match.group("seed")),
            "size": int(match.group("size")),
            "levels": int(match.group("levels")),
            "humans": int(match.group("humans")),
            "computers": int(match.group("computers")),
            "water": match.group("water"),
            "monsters": int(match.group("monsters")),
        }
    return {"status": "found", "text": summary_text, "parsed": parsed}


def h3m_records_for_metrics(h3m_path: Path) -> list[dict[str, Any]]:
    data = fast_audit.load_bytes(h3m_path)
    width = fast_audit.u32(data, 5)
    level_count = 2 if len(data) > 9 and data[9] != 0 else 1
    metadata = fast_audit.load_object_metadata()
    for def_offset in fast_audit.find_object_definition_offsets(data):
        tile_offset = def_offset - width * width * level_count * fast_audit.H3M_TILE_BYTES_PER_CELL
        if tile_offset <= 0:
            continue
        templates = fast_audit.parse_h3m_object_templates(data, def_offset, metadata)
        if templates.get("status") != "parsed":
            continue
        objects = fast_audit.parse_h3m_object_instances(
            data,
            int(templates.get("next_offset", 0)),
            templates["templates"],
            width,
            level_count,
        )
        if objects.get("status") == "parsed":
            return list(objects.get("records", []))
    return []


def h3m_required_corpus_metrics(h3m_path: Path, metrics: dict[str, Any]) -> dict[str, Any]:
    width = int(metrics.get("width", 0))
    height = int(metrics.get("height", width))
    records = h3m_records_for_metrics(h3m_path)
    semantic = metrics.get("semantic_layout", {}) if isinstance(metrics.get("semantic_layout"), dict) else {}
    by_level = semantic.get("by_level", {}) if isinstance(semantic.get("by_level"), dict) else {}
    category_counts = metrics.get("counts_by_category", {}) if isinstance(metrics.get("counts_by_category"), dict) else {}
    body_tile_count_total = 0
    visit_tile_count_total = 0
    guard_control_tile_count_total = 0
    blocker_like_object_count = 0
    blocker_like_body_tile_count = 0
    guard_records: list[dict[str, Any]] = []
    reward_records: list[dict[str, Any]] = []
    town_records: list[dict[str, Any]] = []
    blocker_like_records: list[dict[str, Any]] = []
    for record in records:
        category = fast_audit.h3m_category(record)
        body_points = fast_audit.mask_points(record, False, width, height)
        visit_points = fast_audit.mask_points(record, True, width, height)
        guard_control_points = fast_audit.guard_control_points(record, width, height) if category == "guard" else []
        body_tile_count_total += len(body_points)
        visit_tile_count_total += len(visit_points)
        guard_control_tile_count_total += len(guard_control_points)
        summary_record = {
            "object_index": int(record.get("object_index", -1)),
            "type_id": int(record.get("type_id", -1)),
            "subtype": int(record.get("subtype", -1)),
            "type_name": str(record.get("type_name", "")),
            "def_name": str(record.get("def_name", "")),
            "x": int(record.get("x", -1)),
            "y": int(record.get("y", -1)),
            "level": int(record.get("level", 0)),
            "body_tile_count": len(body_points),
            "visit_tile_count": len(visit_points),
            "guard_control_tile_count": len(guard_control_points),
        }
        if category == "guard":
            guard_records.append(summary_record)
        elif category == "reward":
            reward_records.append(summary_record)
        elif category == "town":
            town_records.append(summary_record)
        elif body_points:
            blocker_like_object_count += 1
            blocker_like_body_tile_count += len(body_points)
            blocker_like_records.append(summary_record)
    object_blocked_tile_count_total = sum(
        int(level.get("object_blocked_tile_count", 0))
        for level in by_level.values()
        if isinstance(level, dict)
    )
    movement_blocked_tile_count_total = sum(
        int(level.get("movement_blocked_tile_count", 0))
        for level in by_level.values()
        if isinstance(level, dict)
    )
    guarded_blocked_tile_count_total = sum(
        int(level.get("guarded_blocked_tile_count", 0))
        for level in by_level.values()
        if isinstance(level, dict)
    )
    guarded_movement_blocked_tile_count_total = sum(
        int(level.get("guarded_movement_blocked_tile_count", 0))
        for level in by_level.values()
        if isinstance(level, dict)
    )
    guard_controlled_tile_count_total = int(semantic.get("guard_controlled_tile_count_total", guard_control_tile_count_total))
    return {
        "schema_id": "rmg_h3maped_controlled_reference_required_metrics_v1",
        "status": "parsed" if records else "not_parsed",
        "width": width,
        "height": height,
        "level_count": int(metrics.get("level_count", 1)),
        "object_count": int(metrics.get("object_count", 0)),
        "town_count": int(category_counts.get("town", 0)),
        "road_cell_count": int(metrics.get("road_cell_count_total", 0)),
        "guard_count": int(category_counts.get("guard", 0)),
        "reward_count": int(category_counts.get("reward", 0)),
        "decoration_count": int(category_counts.get("decoration", 0)),
        "object_category_count": int(category_counts.get("object", 0)),
        "blocker_like_object_count": blocker_like_object_count,
        "blocker_like_body_tile_count": blocker_like_body_tile_count,
        "body_tile_count_total": body_tile_count_total,
        "block_tile_count_total": body_tile_count_total,
        "block_tile_source": "h3m_non_passable_body_mask",
        "visit_tile_count_total": visit_tile_count_total,
        "guard_control_tile_count_total": guard_control_tile_count_total,
        "object_blocked_tile_count_total": object_blocked_tile_count_total,
        "movement_blocked_tile_count_total": movement_blocked_tile_count_total,
        "guarded_blocked_tile_count_total": guarded_blocked_tile_count_total,
        "guarded_movement_blocked_tile_count_total": guarded_movement_blocked_tile_count_total,
        "guard_controlled_tile_count_total": guard_controlled_tile_count_total,
        "route_topology": {
            "object_route_reachable_pair_count_total": int(semantic.get("object_route_reachable_pair_count_total", 0)),
            "guarded_route_reachable_pair_count_total": int(semantic.get("guarded_route_reachable_pair_count_total", 0)),
            "movement_route_reachable_pair_count_total": int(semantic.get("movement_route_reachable_pair_count_total", 0)),
            "guarded_movement_route_reachable_pair_count_total": int(semantic.get("guarded_movement_route_reachable_pair_count_total", 0)),
            "nearest_town_manhattan_min": int(semantic.get("nearest_town_manhattan_min", 0)),
        },
        "sample_towns": town_records[:12],
        "sample_guards": guard_records[:12],
        "sample_rewards": reward_records[:12],
        "sample_blocker_like_objects": blocker_like_records[:12],
    }


def run_automation(args: argparse.Namespace, out_dir: Path, runtime: dict[str, Any]) -> dict[str, Any]:
    save_name = f"h3maped_{args.case}.h3m"
    script_path = out_dir / "run_h3maped_gui.sh"
    script_path.write_text(automation_script(args, out_dir, runtime, save_name))
    script_path.chmod(0o755)
    env = os.environ.copy()
    env["WINEPREFIX"] = str(args.wineprefix.resolve())
    env["WINEARCH"] = "win32"
    proc = subprocess.run(
        ["xvfb-run", "-a", "-s", "-screen 0 1280x1024x24", "bash", str(script_path.resolve())],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        env=env,
        timeout=args.timeout_seconds,
        check=False,
    )
    output_h3m = out_dir / save_name
    return {
        "returncode": proc.returncode,
        "stdout": proc.stdout,
        "script": str(script_path),
        "output_h3m": output_h3m,
        "screenshots": sorted(str(path) for path in (out_dir / "screenshots").glob("*.png")),
    }


def run_generate(args: argparse.Namespace, out_dir: Path) -> dict[str, Any]:
    manifest = build_base_manifest(args, out_dir, "generate")
    if manifest["h3maped"].get("status") != "verified":
        manifest["status"] = "blocked_h3maped_exe_unverified"
        manifest["blocker"] = "h3maped.exe must exist, have an MZ header, and match the pinned SHA-256 before controlled output can be generated."
        return manifest

    backend = manifest["backend"]
    if backend.get("wine"):
        backend["wine_version"] = command_output([str(backend["wine"]), "--version"])
    missing_tools = [name for name in ["wine", "wineboot", "wineserver", "xvfb_run", "xdotool", "scrot"] if not backend.get(name)]
    if missing_tools:
        manifest["status"] = "blocked_missing_runner_prerequisite"
        manifest["blocker"] = f"Missing required h3maped GUI automation tools: {', '.join(missing_tools)}."
        return manifest

    try:
        runtime = prepare_runtime_layout(args, out_dir)
    except ValueError as exc:
        manifest["status"] = "blocked_invalid_seed"
        manifest["blocker"] = str(exc)
        return manifest
    manifest["runtime_layout"] = {
        "runtime_dir": str(runtime["runtime_dir"]),
        "data_dir": str(runtime["data_dir"]),
        "runtime_exe": str(runtime["runtime_exe"]),
        "resources": runtime["resources"],
        "resource_source_dir": runtime["resource_source_dir"],
    }
    manifest["seed_control"]["patch"] = runtime["seed_patch"]
    if runtime["seed_patch"].get("status", "").startswith("blocked_"):
        manifest["status"] = runtime["seed_patch"]["status"]
        manifest["blocker"] = "The artifact h3maped.exe seed-control patch did not match the pinned executable bytes."
        return manifest
    if runtime["missing"]:
        manifest["status"] = "blocked_missing_h3maped_resources"
        manifest["blocker"] = (
            "h3maped.exe launched from Wine requires HoMM3 LOD resources under a Data/ directory. "
            f"Missing resources: {', '.join(runtime['missing'])}."
        )
        return manifest

    try:
        automation = run_automation(args, out_dir, runtime)
    except subprocess.TimeoutExpired as exc:
        manifest["status"] = "blocked_h3maped_automation_timeout"
        manifest["blocker"] = f"h3maped GUI automation exceeded {args.timeout_seconds} seconds."
        manifest["automation"] = {"timeout_seconds": args.timeout_seconds, "stdout": exc.stdout or ""}
        return manifest

    manifest["automation"] = {
        "returncode": automation["returncode"],
        "script": automation["script"],
        "screenshots": automation["screenshots"],
        "stdout": automation["stdout"],
    }
    h3m_path = Path(automation["output_h3m"])
    if automation["returncode"] != 0 or not h3m_path.exists():
        manifest["status"] = "blocked_h3maped_output_missing"
        manifest["blocker"] = "h3maped GUI automation completed without a generated H3M output."
        return manifest

    metrics = fast_audit.parse_h3m(h3m_path)
    compact = fast_audit.compact_metrics(metrics)
    validation = {
        "parsed": metrics.get("status") == "parsed",
        "width_matches": int(metrics.get("width", 0)) == int(args.width),
        "height_matches": int(metrics.get("height", 0)) == int(args.height),
        "level_count_matches": int(metrics.get("level_count", 0)) == int(args.level_count),
        "object_count_positive": int(metrics.get("object_count", 0)) > 0,
    }
    if not all(validation.values()):
        manifest["status"] = "blocked_generated_h3m_validation_failed"
        manifest["blocker"] = "The h3maped-generated H3M exists but failed structural validation."
        manifest["validation"] = validation
        manifest["metrics"] = {"compact": compact}
        return manifest

    manifest["status"] = "ready"
    manifest["outputs"] = {
        "h3m_path": str(h3m_path),
        "h3m_sha256": sha256_file(h3m_path),
        "automation_script": automation["script"],
        "screenshots": automation["screenshots"],
    }
    manifest["validation"] = validation
    generation_summary = extract_generation_summary(h3m_path)
    manifest["generation_summary"] = generation_summary
    parsed_summary = generation_summary.get("parsed", {}) if isinstance(generation_summary, dict) else {}
    if parsed_summary:
        manifest["controlled_identity"]["seed"] = str(parsed_summary.get("seed", ""))
        manifest["controlled_identity"]["observed_template"] = parsed_summary.get("template", "")
        manifest["controlled_identity"]["observed_humans"] = parsed_summary.get("humans", 0)
        manifest["controlled_identity"]["observed_computers"] = parsed_summary.get("computers", 0)
        manifest["controlled_identity"].update(template_identity_from_observed_name(str(parsed_summary.get("template", ""))))

    observed_seed = str(manifest["controlled_identity"].get("seed", ""))
    requested_seed = str(parse_requested_seed(args.seed))
    if args.seed_control_mode == "pe-patch":
        if observed_seed != requested_seed:
            manifest["status"] = "blocked_seed_control_mismatch"
            manifest["blocker"] = (
                f"Seed-control patch ran, but saved H3M summary seed `{observed_seed}` did not match requested seed `{requested_seed}`."
            )
            manifest["seed_control"]["status"] = "mismatch"
            manifest["seed_control"]["reason"] = manifest["blocker"]
            manifest["metrics"] = {"compact": compact}
            return manifest
        manifest["controlled_identity"]["same_seed_parity_supported"] = True
        manifest["controlled_identity"]["identity_authority"] = "artifact_pe_patch_verified_by_saved_h3m_summary"
        manifest["seed_control"]["status"] = "controlled"
        manifest["seed_control"]["reason"] = "Artifact copy of h3maped.exe was patched at the recovered generator seed initialization site and the saved H3M summary seed matched the requested seed."
    else:
        manifest["seed_control"]["status"] = "observed_only"
        manifest["seed_control"]["reason"] = (
            "The public h3maped GUI has no seed entry; this manifest records the observed generated seed only."
        )
    manifest["metrics"] = {
        "compact": compact,
        "required": h3m_required_corpus_metrics(h3m_path, metrics),
    }
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--case", required=True, help="Stable case id for the artifact directory")
    parser.add_argument("--seed", required=True)
    parser.add_argument("--players", type=int, required=True)
    parser.add_argument("--human-players", type=int, default=1)
    parser.add_argument("--size", default="small", choices=sorted(SIZE_COORDS))
    parser.add_argument("--width", type=int)
    parser.add_argument("--height", type=int)
    parser.add_argument("--level-count", type=int, default=1)
    parser.add_argument("--water", default="land", choices=sorted(WATER_COORDS))
    parser.add_argument("--monster-strength", default="random", choices=sorted(MONSTER_COORDS))
    parser.add_argument("--computer-only-players", type=int, default=0)
    parser.add_argument("--template-id", default="")
    parser.add_argument("--source-template-id", default="")
    parser.add_argument("--source-catalog-index", type=int)
    parser.add_argument("--h3maped-exe", type=Path, default=DEFAULT_H3MAPED_EXE)
    parser.add_argument("--resource-dir", type=Path, help="Directory containing HoMM3 LOD resources, defaulting to the h3maped.exe directory")
    parser.add_argument("--wineprefix", type=Path, default=DEFAULT_WINEPREFIX)
    parser.add_argument("--timeout-seconds", type=int, default=90)
    parser.add_argument("--generation-wait-seconds", type=int, default=12)
    parser.add_argument("--seed-control-mode", choices=["pe-patch", "observed-gui"], default="pe-patch")
    parser.add_argument("--out-root", type=Path, default=DEFAULT_OUT_ROOT)
    parser.add_argument("--allow-blocked", action="store_true", help="Return success while writing a blocked manifest")
    parser.add_argument("--pretty", action="store_true")
    args = parser.parse_args()
    canonical_dimension = SIZE_DIMENSIONS[args.size]
    if args.width is None:
        args.width = canonical_dimension
    if args.height is None:
        args.height = canonical_dimension

    out_dir = args.out_root / args.case
    manifest = run_generate(args, out_dir)
    manifest_path, md_path = write_manifest(manifest, out_dir, args.pretty)
    print(json.dumps({"status": manifest["status"], "manifest": str(manifest_path), "markdown": str(md_path)}, sort_keys=True))
    if manifest["status"] == "ready" or (args.allow_blocked and str(manifest["status"]).startswith("blocked_")):
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
