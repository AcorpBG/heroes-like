#!/usr/bin/env python3
"""Create and verify external ZIP64 snapshots; never remove or modify sources."""
from __future__ import annotations

import argparse
import collections
import datetime as dt
import fnmatch
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import time
import zipfile

sys.dont_write_bytecode = True
import source_material_inventory as inventory

CHUNK = 4 * 1024 * 1024
MANIFEST_MEMBER = "__source_archive__/manifest.json"


def emit(event, **values):
    print(json.dumps({"event": event, **values}), flush=True)


def json_bytes(value):
    return (json.dumps(value, indent=2, ensure_ascii=False) + "\n").encode("utf-8")


def regular_stat(path):
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode) or getattr(info, "st_file_attributes", 0) & 0x400:
        raise ValueError(f"Not an ordinary source file: {path}")
    return info


def unchanged(root, row):
    path = root / row["path"]
    if not path.resolve().is_relative_to(root):
        raise ValueError(f"Source escaped repository: {path}")
    info = regular_stat(path)
    if (info.st_size, info.st_mtime_ns) != (row["bytes"], row["mtime_ns"]):
        raise ValueError(f"Source changed during archival: {path}")


def collect(root):
    filters = inventory.export_filters(root)
    if filters["Linux Release"] != filters["Windows Release"]:
        raise ValueError("Review changed platform exclusions before archiving")
    content, live, errors = inventory.references(root)
    if errors:
        raise ValueError(errors)
    tracked = set(subprocess.check_output(
        ["git", "-c", "gc.auto=0", "-c", "maintenance.auto=false", "ls-files", "-z"],
        cwd=root).decode("utf-8").split("\0"))
    rows = []
    for source in sorted((root / "art").glob("*/source")):
        if source.is_symlink() or not source.resolve().is_relative_to(root):
            raise ValueError(f"Linked source directory: {source}")
        files, skipped, errors = inventory.enumerate_files(source)
        if errors or skipped:
            raise ValueError({"errors": errors, "skipped_links": skipped})
        for relative, size in files:
            path = source / relative
            name = path.relative_to(root).as_posix()
            info = regular_stat(path)
            if info.st_size != size:
                raise ValueError(f"Source changed during inventory: {name}")
            excluded = {key: any(fnmatch.fnmatchcase(name, p) for p in patterns)
                        for key, patterns in filters.items()}
            rows.append({"path": name, "bytes": size, "mtime_ns": info.st_mtime_ns,
                         "tracked": name in tracked, "group": inventory.group_for(name),
                         "category": inventory.classify(name, excluded, content.get(name, []), live.get(name, []))})
    if not rows:
        raise ValueError("No art source files found")
    return rows


def verify_archive(archive, expected):
    expected_names = [row["path"] for row in expected["files"]]
    verified = 0
    last = time.monotonic()
    with zipfile.ZipFile(archive) as zf:
        names = zf.namelist()
        if len(names) != len(set(names)) or set(names) != set(expected_names + [MANIFEST_MEMBER]):
            raise ValueError(f"Archive file set mismatch: {archive}")
        if json.loads(zf.read(MANIFEST_MEMBER)) != expected:
            raise ValueError(f"Embedded manifest mismatch: {archive}")
        for row in expected["files"]:
            digest = hashlib.sha256()
            size = 0
            with zf.open(row["path"]) as member:
                while block := member.read(CHUNK):
                    digest.update(block)
                    size += len(block)
            if size != row["bytes"] or digest.hexdigest() != row["sha256"]:
                raise ValueError(f"Archive payload mismatch: {row['path']}")
            verified += size
            if time.monotonic() - last >= 20:
                emit("verify_progress", archive=archive.name, verified_bytes=verified)
                last = time.monotonic()
    return verified


def write_archive(root, destination, group, rows):
    name = group.replace("/", "__") + ".zip"
    partial = destination / (name + ".partial")
    target = destination / name
    manifest_path = destination / (name + ".manifest.json")
    if any(p.exists() for p in (partial, target, manifest_path)):
        raise FileExistsError(name)
    copied = 0
    last = time.monotonic()
    manifest = {"schema": "heroes_source_zip_v1", "group": group,
                "paths_relative_to": "repository root", "files": []}
    emit("archive_started", archive=name, files=len(rows), source_bytes=sum(r["bytes"] for r in rows))
    with zipfile.ZipFile(partial, "x", allowZip64=True) as zf:
        for row in rows:
            unchanged(root, row)
            path = root / row["path"]
            info = zipfile.ZipInfo.from_file(path, arcname=row["path"], strict_timestamps=False)
            info.compress_type = (zipfile.ZIP_DEFLATED if path.suffix.lower() in inventory.SOURCE_TEXT_SUFFIXES
                                  or path.suffix.lower() in {".import", ".uid"} else zipfile.ZIP_STORED)
            digest = hashlib.sha256()
            read_bytes = 0
            with path.open("rb") as source, zf.open(info, "w", force_zip64=True) as output:
                while block := source.read(CHUNK):
                    output.write(block)
                    digest.update(block)
                    read_bytes += len(block)
            unchanged(root, row)
            if read_bytes != row["bytes"]:
                raise ValueError(f"Short source read: {path}")
            manifest["files"].append({**row, "sha256": digest.hexdigest()})
            copied += read_bytes
            if time.monotonic() - last >= 20:
                emit("copy_progress", archive=name, copied_bytes=copied)
                last = time.monotonic()
        zf.writestr(MANIFEST_MEMBER, json_bytes(manifest), compress_type=zipfile.ZIP_DEFLATED)
    with partial.open("r+b") as handle:
        handle.flush()
        os.fsync(handle.fileno())
    emit("verification_started", archive=name)
    verify_archive(partial, manifest)
    for row in rows:
        unchanged(root, row)
    partial.rename(target)
    with manifest_path.open("xb") as handle:
        handle.write(json_bytes(manifest))
    emit("archive_verified", archive=name, files=len(rows), source_bytes=copied, archive_bytes=target.stat().st_size)
    return {"archive": name, "manifest": manifest_path.name, "files": len(rows),
            "source_bytes": copied, "archive_bytes": target.stat().st_size,
            "manifest_sha256": hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
            "verification": "Every extracted payload SHA-256 and ZIP CRC matched the source read; exact member set and embedded manifest checked."}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=inventory.ROOT)
    parser.add_argument("--destination", type=Path, required=True)
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()
    root = args.root.resolve()
    destination = args.destination.resolve()
    if args.verify_only:
        index = json.loads((destination / "archive-index.json").read_text(encoding="utf-8"))
        for entry in index["archives"]:
            raw = (destination / entry["manifest"]).read_bytes()
            if hashlib.sha256(raw).hexdigest() != entry["manifest_sha256"]:
                raise ValueError("Manifest checksum mismatch")
            verify_archive(destination / entry["archive"], json.loads(raw))
        emit("all_archives_verified", archives=len(index["archives"]))
        return
    if destination.is_relative_to(root) or root.is_relative_to(destination):
        raise ValueError("Archive destination must be outside the repository")
    rows = collect(root)
    total_bytes = sum(row["bytes"] for row in rows)
    ancestor = destination.parent
    while not ancestor.exists():
        ancestor = ancestor.parent
    if shutil.disk_usage(ancestor).free < total_bytes + 2 * 1024**3:
        raise ValueError("Insufficient archive destination space")
    groups = collections.defaultdict(list)
    for row in rows:
        groups[row["group"]].append(row)
    destination.mkdir(parents=True, exist_ok=False)
    revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
    index = {"schema": "heroes_source_archive_set_v1", "status": "in_progress",
             "created_utc": dt.datetime.now(dt.timezone.utc).isoformat(), "git_head": revision,
             "source_root": str(root), "scope": "All regular files in art/*/source, including provenance, editor exceptions, sidecars and small existing caches. No runtime folders or Git history.",
             "source_files": len(rows), "source_bytes": total_bytes, "archives": []}
    index_path = destination / "archive-index.json"
    index_path.write_bytes(json_bytes(index))
    emit("inventory_ready", destination=str(destination), files=len(rows), bytes=total_bytes, archives=len(groups))
    for name, group in sorted(groups.items()):
        index["archives"].append(write_archive(root, destination, name, group))
        index_path.write_bytes(json_bytes(index))
    for row in rows:
        unchanged(root, row)
    after = collect(root)
    if [(r["path"], r["bytes"], r["mtime_ns"]) for r in rows] != [(r["path"], r["bytes"], r["mtime_ns"]) for r in after]:
        raise ValueError("Source file set changed during archival")
    for name in ("archive_source_material.py", "source_material_inventory.py"):
        shutil.copyfile(root / "tools" / name, destination / name)
    shutil.copyfile(root / "docs/source-material-storage-map.md", destination / "source-material-storage-map.md")
    (destination / "README.txt").write_text(
        "Heroes-like art source snapshot\n\n"
        "Each ZIP preserves repository-relative paths. Extract selected ZIPs into a chosen repository root to restore those source groups. Review existing files before overwriting.\n"
        "Original source files were retained. Metadata/editor sources/caches in these ZIPs are backup copies, not removal candidates. The per-file category preserves the mapped distinction.\n"
        "Every member was read back and its SHA-256 compared with the original source stream; ZIP CRCs and exact entry sets were checked.\n"
        "Reverify on Windows or Linux: python archive_source_material.py --destination <this directory> --verify-only\n"
        "archive-index.json records the Git base revision, but this is a working-copy snapshot including uncommitted/untracked sources.\n",
        encoding="utf-8")
    index["status"] = "verified"
    index["verified_utc"] = dt.datetime.now(dt.timezone.utc).isoformat()
    index["archive_bytes"] = sum(entry["archive_bytes"] for entry in index["archives"])
    index["originals_retained"] = True
    index_path.write_bytes(json_bytes(index))
    emit("completed", destination=str(destination), files=len(rows), source_bytes=total_bytes,
         archive_bytes=index["archive_bytes"], archives=len(index["archives"]))


if __name__ == "__main__":
    main()
