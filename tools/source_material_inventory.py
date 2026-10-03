#!/usr/bin/env python3
"""Read-only storage map. Classifications are review inputs, never deletion lists.

Default output is a compact JSON summary. --files emits exact file records;
--category and --path-prefix restrict that output. No files are written.
The export-filter calculation matches prepare_lossless_texture_imports.py;
it describes configured exclusions, not the contents of a newly built PCK.
"""
from __future__ import annotations

import argparse
import collections
import configparser
import fnmatch
import json
import os
from pathlib import Path
import re
import stat
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SOURCE_METADATA_KEYS = {
    "provenance", "source_path", "emblem_source_path", "seal_source_path",
    "trimmed_path", "prompt_path", "reference_inputs", "curated_source",
    "pose_provenance",
}
SOURCE_BINARY_SUFFIXES = {
    ".png", ".jpg", ".jpeg", ".webp", ".gif", ".bmp", ".tif", ".tiff",
    ".svg", ".mp4", ".mkv", ".mov", ".avi", ".webm", ".latent", ".npy",
    ".npz", ".wav", ".ogg", ".mp3", ".flac", ".aiff", ".blend", ".psd",
    ".kra", ".ora", ".exr", ".zip", ".7z", ".tar", ".gz", ".safetensors",
}
SOURCE_TEXT_SUFFIXES = {
    ".json", ".txt", ".md", ".py", ".gd", ".sh", ".ps1", ".bat", ".cmd",
    ".cfg", ".ini", ".toml", ".yaml", ".yml", ".csv", ".tsv", ".html", ".sha256",
}
EDITOR_SOURCE_PREFIXES = (
    "art/towns/source/buildings/curated/",
    "art/campaigns/source/generated/emblems/",
    "art/campaigns/source/generated/chapter_seals/",
)
POLICY = {
    "archive_source_binary": "Candidate for a verified external archive; not needed in normal Git or release payload. Restore for source-dependent rebuilds/tests.",
    "keep_source_metadata": "Keep small recipes, scripts, selections, prompts and provenance versioned; also include them in source archives.",
    "keep_editor_source": "Keep locally/in Git until editor validation supports archived sources; export presets exclude it.",
    "source_generated_sidecar": "Source import/UID sidecar. Review tracking with its source; not a release asset or original master.",
    "review_source_unknown": "Unrecognized source type: retain until reviewed.",
    "review_live_reference": "A live-code literal or unrecognized content field references this source. Retain pending dependency review.",
    "review_excluded_art": "Outside the standard source folders but excluded from release. Retain pending reference/ownership review.",
    "keep_runtime_art": "Runtime/export-eligible art, including portraits/icons and art outside folders named runtime. Keep.",
    "keep_build_source": "Code, content, tests, tools, dependencies and packaging inputs remain versioned even when excluded from game exports.",
    "keep_native_binary": "Native library required by the platform extension. Keep available for game/build; release and debug outputs have separate packaging roles.",
    "local_build_output": "Generated native helper/debug/linker output. Not production art or original source; review Git tracking and preserve rebuild tooling.",
    "keep_rmg_recovery": "Native RMG/source-reference recovery material is protected, regardless of export or Git status.",
    "keep_save_or_backup": "Save, map or backup material: preserve; not an archive-removal candidate.",
    "keep_cache": "Rebuildable local cache; excluded from ordinary source control. Preserve under current owner policy.",
    "review_local_artifact": "Ignored local output; inspect ownership, rebuildability and live use before any cleanup. Not automatically disposable.",
    "keep_git_storage": "Git history/object storage; a separate migration, not an art-archive input.",
    "review_other": "Retain pending classification; no deletion implied.",
}


def enumerate_files(root: Path):
    stack = [root]
    files, skipped, errors = [], [], []
    while stack:
        folder = stack.pop()
        try:
            with os.scandir(folder) as entries:
                for entry in entries:
                    try:
                        info = entry.stat(follow_symlinks=False)
                        relative = Path(entry.path).relative_to(root).as_posix()
                        if stat.S_ISLNK(info.st_mode) or getattr(info, "st_file_attributes", 0) & 0x400:
                            skipped.append(relative)
                        elif stat.S_ISDIR(info.st_mode):
                            stack.append(Path(entry.path))
                        elif stat.S_ISREG(info.st_mode):
                            files.append((relative, info.st_size))
                    except OSError as exc:
                        errors.append({"path": entry.path, "error": str(exc)})
        except OSError as exc:
            errors.append({"path": str(folder), "error": str(exc)})
    return sorted(files), skipped, errors


def export_filters(root: Path):
    config = configparser.ConfigParser(interpolation=None)
    config.read(root / "export_presets.cfg", encoding="utf-8")
    result = {}
    for section in config.sections():
        if re.fullmatch(r"preset\.\d+", section):
            if config[section].get("export_filter") != '"all_resources"':
                raise ValueError("Inventory requires the reviewed all_resources export mode")
            name = json.loads(config[section]["name"])
            result[name] = json.loads(config[section].get("exclude_filter", '""')).split(",")
    if set(result) != {"Linux Release", "Windows Release"}:
        raise ValueError("Review changed platform presets before mapping archive eligibility")
    return result


def references(root: Path):
    content = collections.defaultdict(list)
    live = collections.defaultdict(list)
    errors = []

    def visit(value, document, location, key=""):
        if isinstance(value, dict):
            for child_key, child in value.items():
                visit(child, document, location + "." + child_key, child_key)
        elif isinstance(value, list):
            for index, child in enumerate(value):
                visit(child, document, f"{location}[{index}]", key)
        elif isinstance(value, str) and value.startswith("res://art/"):
            content[value[6:]].append({"file": document, "location": location, "key": key})

    for path in sorted((root / "content").rglob("*.json")):
        try:
            visit(json.loads(path.read_text(encoding="utf-8")), path.relative_to(root).as_posix(), "$")
        except (OSError, ValueError) as exc:
            errors.append({"path": str(path), "error": str(exc)})
    for folder in ("scripts", "scenes"):
        for path in sorted((root / folder).rglob("*")):
            if path.suffix not in {".gd", ".tscn", ".tres"}:
                continue
            try:
                for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
                    for match in re.finditer(r'''res://art/[^\s"'\)\],]+''', line):
                        live[match[0][6:]].append({"file": path.relative_to(root).as_posix(), "line": number})
            except (OSError, UnicodeError) as exc:
                errors.append({"path": str(path), "error": str(exc)})
    return content, live, errors


def group_for(path: str):
    parts = path.split("/")
    if parts[0] == "art" and "source" in parts:
        if path.startswith("art/units/source/generated/fluid_animation/"):
            return "/".join(parts[:6] if len(parts) > 6 else parts[:5])
        if path.startswith("art/units/source/generated/video_trials/"):
            return "art/units/source/generated/video_trials"
        return "/".join(parts[:parts.index("source") + 1])
    if parts[0] == "art":
        return "/".join(parts[:min(4, len(parts) - 1)])
    if parts[0] == ".artifacts":
        return "/".join(parts[:2])
    return parts[0] if len(parts) > 1 else "[root files]"


def classify(path: str, excluded: dict, content_refs: list, live_refs: list):
    parts = path.split("/")
    suffix = Path(path).suffix.lower()
    base = path.removesuffix(".import").removesuffix(".uid")
    if parts[0] == ".git":
        return "keep_git_storage"
    if parts[0] == ".godot" or "__pycache__" in parts:
        return "keep_cache"
    if path.startswith(".artifacts/map_persistence_native_build_") or path.startswith(".artifacts/audio-production/export-tools/"):
        return "keep_cache"
    if any(part.lower() in {"saves", "save", "backups", "backup"} for part in parts) or suffix in {".amap", ".ascenario", ".save", ".bak"}:
        return "keep_save_or_backup"
    if re.search(r"(^|[/_.-])(rmg|h3maped|homm3)([/_.-]|$)", path.lower()) or any(token in path.lower() for token in ("reverse-engineer", "disassembly")):
        return "keep_rmg_recovery"
    if parts[0] == "art" and "source" in parts:
        if live_refs or any(ref["key"] not in SOURCE_METADATA_KEYS for ref in content_refs):
            return "review_live_reference"
        if base.startswith(EDITOR_SOURCE_PREFIXES):
            return "keep_editor_source"
        if suffix in {".import", ".uid"}:
            return "source_generated_sidecar"
        if suffix in SOURCE_TEXT_SUFFIXES or parts[-1] in {".gdignore", ".gitignore", ".gitattributes", "LICENSE"}:
            return "keep_source_metadata"
        if suffix in SOURCE_BINARY_SUFFIXES and all(excluded.values()):
            return "archive_source_binary"
        return "review_source_unknown"
    if parts[0] == "art":
        return "review_excluded_art" if all(excluded.values()) else "keep_runtime_art"
    if parts[0] == ".artifacts":
        return "review_local_artifact"
    if parts[0] == "bin":
        return "keep_native_binary" if suffix in {".dll", ".so", ".dylib", ".gdextension"} else "local_build_output"
    if parts[0] in {"src", "scripts", "scenes", "content", "tools", "tests", "docs", "packaging", "third_party", ".github", "ops", "archive"} or len(parts) == 1 and (suffix in {".md", ".cfg", ".godot", ".py", ".bat", ".svg", ".import"} or path in {".gitattributes", ".gitignore", ".gitmodules"}):
        return "keep_build_source"
    return "review_other"


def inventory(root: Path):
    root = root.resolve()
    files, skipped, errors = enumerate_files(root)
    filters = export_filters(root)
    patterns = {name: [re.compile(fnmatch.translate(p)) for p in pats] for name, pats in filters.items()}
    content, live, reference_errors = references(root)
    errors.extend(reference_errors)
    proc = subprocess.run(["git", "ls-files", "-z"], cwd=root, capture_output=True, check=True)
    tracked = set(proc.stdout.decode("utf-8").split("\0"))
    rows = []
    for path, size in files:
        excluded = {name: any(regex.fullmatch(path) for regex in pats) for name, pats in patterns.items()}
        content_refs, live_refs = content.get(path, []), live.get(path, [])
        rows.append({"path": path, "bytes": size, "tracked": path in tracked,
                     "category": classify(path, excluded, content_refs, live_refs),
                     "group": group_for(path), "excluded_by_preset": excluded,
                     "content_references": content_refs, "live_literal_references": live_refs})
    summary = collections.defaultdict(lambda: {"bytes": 0, "files": 0, "tracked_bytes": 0, "tracked_files": 0})
    groups = collections.defaultdict(lambda: {"bytes": 0, "files": 0, "categories": collections.defaultdict(lambda: {"bytes": 0, "files": 0})})
    for row in rows:
        bucket = summary[row["category"]]
        bucket["bytes"] += row["bytes"]
        bucket["files"] += 1
        bucket["tracked_bytes"] += row["bytes"] if row["tracked"] else 0
        bucket["tracked_files"] += int(row["tracked"])
        group = groups[row["group"]]
        group["bytes"] += row["bytes"]
        group["files"] += 1
        group["categories"][row["category"]]["bytes"] += row["bytes"]
        group["categories"][row["category"]]["files"] += 1
    known = {path for path, size in files}
    missing = [{"path": path, "references": refs} for path, refs in content.items()
               if "/source/" in path and path not in known]
    result = {"schema": "heroes_source_material_inventory_v1", "root": str(root),
              "scope": "Current checkout only; exact Git historical blobs and external N:/H: sources are not enumerated.",
              "method": "Static paths/content references plus configured export exclusions. No PCK build, game launch, archive verification or removal safety proof.",
              "total_bytes": sum(row["bytes"] for row in rows), "total_files": len(rows),
              "platform_exclusion_parity": filters["Linux Release"] == filters["Windows Release"],
              "policy": POLICY, "categories": dict(sorted(summary.items())),
              "groups": dict(sorted(groups.items())), "missing_source_references": missing,
              "skipped_links": skipped, "errors": errors}
    return result, rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--files", action="store_true", help="Include exact file records; no file contents or binary hashes are read")
    parser.add_argument("--category", choices=sorted(POLICY))
    parser.add_argument("--path-prefix", default="")
    args = parser.parse_args()
    result, rows = inventory(args.root)
    if args.files or args.category or args.path_prefix:
        selected = [row for row in rows if (not args.category or row["category"] == args.category)
                    and row["path"].startswith(args.path_prefix)]
        result["selected_files"] = selected
        result["selected_bytes"] = sum(row["bytes"] for row in selected)
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return 1 if result["errors"] or not result["platform_exclusion_parity"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
