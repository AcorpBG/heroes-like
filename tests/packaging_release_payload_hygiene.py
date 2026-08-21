#!/usr/bin/env python3
from __future__ import annotations

import configparser
import json
import os
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACT_DIR = Path(
    os.environ.get(
        "HEROES_PACKAGING_ARTIFACT_DIR",
        ROOT / ".artifacts" / "packaging_release_payload_hygiene",
    )
).resolve()
PACK_PATH = ARTIFACT_DIR / "linux-release-resources.zip"
PRESETS = ("preset.0", "preset.1")
FORBIDDEN_PREFIXES = (
    "archive/",
    "art/overworld/source/",
    "build/",
    "docs/",
    "maps/",
    "ops/",
    "src/gdextension/build/",
    "src/gdextension/include/",
    "src/gdextension/src/",
    "tests/",
    "third_party/",
    "tmp/",
    "tools/",
)
FORBIDDEN_NAMES = {
    "AGENTS.md",
    "GOALS.md",
    "PLAN.md",
    "project.md",
    "rmg-slices.md",
}
REQUIRED_PREFIXES = ("art/", "content/", "scenes/", "scripts/")
REQUIRED_FILES = (
    "project.binary",
    "src/gdextension/map_persistence.gdextension",
    "content/terrain_grammar.json",
    "content/third_party_notices.json",
    "art/overworld/runtime/terrain_tiles/base/grass_open.png.import",
    "art/animation/runtime/units/unit_neutral_cliffhawk_wardens.png.import",
)


def load_presets() -> configparser.ConfigParser:
    parser = configparser.ConfigParser(interpolation=None, strict=True)
    parser.optionxform = str
    parser.read(ROOT / "export_presets.cfg", encoding="utf-8")
    return parser


def main() -> int:
    presets = load_presets()
    filters = []
    failures: list[str] = []
    for section in PRESETS:
        if section not in presets:
            failures.append(f"missing preset section {section}")
            continue
        filters.append(presets[section].get("exclude_filter", "").strip('"'))
    if len(filters) == 2 and filters[0] != filters[1]:
        failures.append("Linux and Windows release filters differ")

    if ARTIFACT_DIR.exists():
        shutil.rmtree(ARTIFACT_DIR)
    ARTIFACT_DIR.mkdir(parents=True)
    env = os.environ.copy()
    env["GODOT_SILENCE_ROOT_WARNING"] = "1"
    completed = subprocess.run(
        ["godot", "--headless", "--path", str(ROOT), "--export-pack", "Linux Release", str(PACK_PATH)],
        cwd=ROOT,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        errors="replace",
        timeout=600,
        check=False,
    )
    if completed.returncode != 0:
        failures.append(f"resource export failed with {completed.returncode}")
    names: list[str] = []
    if PACK_PATH.exists() and zipfile.is_zipfile(PACK_PATH):
        with zipfile.ZipFile(PACK_PATH) as archive:
            names = sorted(archive.namelist())
    else:
        failures.append("release resource ZIP was not produced")

    forbidden = [
        name
        for name in names
        if name in FORBIDDEN_NAMES or any(name.startswith(prefix) for prefix in FORBIDDEN_PREFIXES)
    ]
    if forbidden:
        failures.append(f"forbidden release payload paths: {forbidden[:20]}")
    for prefix in REQUIRED_PREFIXES:
        if not any(name.startswith(prefix) for name in names):
            failures.append(f"missing runtime resource prefix {prefix}")
    for path in REQUIRED_FILES:
        if path not in names:
            failures.append(f"missing required release resource {path}")

    report = {
        "ok": not failures,
        "schema_id": "packaging_release_payload_hygiene_v1",
        "pack_size_bytes": PACK_PATH.stat().st_size if PACK_PATH.exists() else 0,
        "file_count": len(names),
        "forbidden_paths": forbidden,
        "failures": failures,
        "export_returncode": completed.returncode,
        "export_output_tail": completed.stdout.splitlines()[-40:],
    }
    print(f"PACKAGING_RELEASE_PAYLOAD_HYGIENE {json.dumps(report, sort_keys=True)}")
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
