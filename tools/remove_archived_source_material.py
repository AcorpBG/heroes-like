#!/usr/bin/env python3
"""Remove only mapped media with verified external backups. Dry-run by default.

Apply uses Windows exclusive handles for this D: cleanup. ZIP verification and
archive restoration remain portable; this tool never changes Git history.
"""
from __future__ import annotations
import argparse
import collections
import contextlib
import ctypes
import datetime as dt
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import sys
import time
import zipfile

sys.dont_write_bytecode = True
os.environ["GIT_OPTIONAL_LOCKS"] = "0"
import archive_source_material as archive
import prepare_lossless_texture_imports as textures


def source_path(root, name):
    parts = PurePosixPath(name).parts
    if (len(parts) < 4 or parts[0] != "art" or parts[2] != "source"
            or "\\" in name or ":" in name or any(p in ("", ".", "..") for p in name.split("/"))):
        raise ValueError(f"Outside art source scope: {name}")
    path = root / name
    if not path.resolve().is_relative_to(root):
        raise ValueError(f"Path escaped repository: {name}")
    for parent in (path, *path.parents):
        if parent == root:
            break
        info = parent.lstat()
        if parent.is_symlink() or getattr(info, "st_file_attributes", 0) & 0x400:
            raise ValueError(f"Linked source path: {name}")
    archive.regular_stat(path)
    return path


def digest_stream(handle):
    digest = hashlib.sha256()
    size = 0
    while block := handle.read(archive.CHUNK):
        digest.update(block)
        size += len(block)
    return size, digest.hexdigest()


@contextlib.contextmanager
def locked_file(path, *, delete=False):
    if os.name != "nt":
        raise RuntimeError("Apply requires Windows exclusive file handles; no portable deletion fallback")
    import msvcrt
    from ctypes import wintypes
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    create = kernel.CreateFileW
    create.argtypes = (wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD, ctypes.c_void_p,
                       wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE)
    create.restype = wintypes.HANDLE
    # Delete candidates are opened exclusively; archive readers deny writes/deletes.
    handle = create("\\\\?\\" + str(path.resolve()), 0x80000000 | (0x10000 if delete else 0),
                    0 if delete else 1, None, 3, 0x08000000, None)
    if handle == ctypes.c_void_p(-1).value:
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        fd = msvcrt.open_osfhandle(handle, os.O_RDONLY | os.O_BINARY)
    except Exception:
        close = kernel.CloseHandle
        close.argtypes = (wintypes.HANDLE,)
        close(handle)
        raise
    with os.fdopen(fd, "rb") as stream:
        yield stream


def remove_verified(root, row):
    path = source_path(root, row["path"])
    import msvcrt
    from ctypes import wintypes
    with locked_file(path, delete=True) as handle:
        size, digest = digest_stream(handle)
        if size != row["bytes"] or digest != row["sha256"]:
            raise ValueError(f"Local file differs from verified backup: {row['path']}")
        kernel = ctypes.WinDLL("kernel32", use_last_error=True)
        disposition = kernel.SetFileInformationByHandle
        disposition.argtypes = (wintypes.HANDLE, ctypes.c_int, ctypes.c_void_p, wintypes.DWORD)
        disposition.restype = wintypes.BOOL
        delete_flag = ctypes.c_ubyte(1)
        if not disposition(msvcrt.get_osfhandle(handle.fileno()), 4, ctypes.byref(delete_flag), 1):
            raise ctypes.WinError(ctypes.get_last_error())
    if path.exists():
        raise ValueError(f"File was not removed: {row['path']}")


def load_plan(root, destination):
    index = json.loads((destination / "archive-index.json").read_bytes())
    if index.get("status") != "verified" or Path(index["source_root"]).resolve() != root:
        raise ValueError("Verified archive for this exact repository is required")
    groups, recorded = [], {}
    for entry in index["archives"]:
        for key in ("archive", "manifest"):
            if Path(entry[key]).name != entry[key]:
                raise ValueError("Archive member filename must be a basename")
        raw = (destination / entry["manifest"]).read_bytes()
        if hashlib.sha256(raw).hexdigest() != entry["manifest_sha256"]:
            raise ValueError("Archive manifest checksum mismatch")
        manifest = json.loads(raw)
        if (destination / entry["archive"]).stat().st_size != entry["archive_bytes"]:
            raise ValueError("Archive size changed")
        for row in manifest["files"]:
            if row["path"] in recorded:
                raise ValueError("Duplicate source record")
            source_path(root, row["path"])
            recorded[row["path"]] = row
        groups.append((entry, manifest))
    if len(recorded) != index["source_files"] or sum(r["bytes"] for r in recorded.values()) != index["source_bytes"]:
        raise ValueError("Archive aggregate mismatch")
    current = {row["path"]: row for row in archive.collect(root)}
    if set(current) != set(recorded):
        raise ValueError("Source file set changed since archival; review before cleanup")
    candidates = {p for p, row in recorded.items() if row["category"] == "archive_source_binary"
                  and current[p]["category"] == "archive_source_binary"}
    candidates.update(p for p, row in recorded.items()
                      if row["category"] == "source_generated_sidecar"
                      and current[p]["category"] == "source_generated_sidecar"
                      and p.removesuffix(".import").removesuffix(".uid") in candidates)
    export_pngs = {p.relative_to(root).as_posix() for p in textures.exported_pngs(root)}
    if candidates & export_pngs:
        raise ValueError("Candidate overlaps game export images")
    return groups, recorded, candidates, current, export_pngs


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=archive.inventory.ROOT)
    parser.add_argument("--archive", type=Path, required=True)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    root, destination = args.root.resolve(), args.archive.resolve()
    groups, recorded, candidates, current, exports = load_plan(root, destination)
    by_category = collections.Counter(recorded[p]["category"] for p in candidates)
    planned_bytes = sum(recorded[p]["bytes"] for p in candidates)
    archive.emit("cleanup_plan", files=len(candidates), bytes=planned_bytes, categories=dict(by_category),
                 export_pngs_retained=len(exports), apply=args.apply)
    if not args.apply:
        return
    receipt = destination / ("local-cleanup-" + dt.datetime.now().strftime("%Y%m%d-%H%M%S") + ".json")
    if receipt.exists():
        raise FileExistsError(receipt)
    free_before = shutil.disk_usage(root).free
    runtime_rows, links, errors = archive.inventory.enumerate_files(root / "art")
    if errors or links:
        raise ValueError({"errors": errors, "links": links})
    runtime_hashes = {}
    for name, size in runtime_rows:
        if "source" not in PurePosixPath(name).parts:
            with (root / "art" / name).open("rb") as handle:
                runtime_hashes[name] = digest_stream(handle)
    result = {"schema": "heroes_archived_source_cleanup_v1", "status": "in_progress",
              "started_utc": dt.datetime.now(dt.timezone.utc).isoformat(), "root": str(root),
              "archive": str(destination), "planned_files": len(candidates), "planned_bytes": planned_bytes,
              "candidate_categories": dict(by_category), "removed_files": 0, "removed_bytes": 0,
              "groups": [], "retained_errors": [], "runtime_art_files": len(runtime_hashes),
              "free_before": free_before, "git_history_changed": False}
    receipt.write_bytes(archive.json_bytes(result))
    last = time.monotonic()
    for entry, manifest in groups:
        selected = [r for r in manifest["files"] if r["path"] in candidates]
        if not selected:
            continue
        archive_path = destination / entry["archive"]
        archive.emit("backup_recheck", archive=archive_path.name, candidate_files=len(selected))
        # Keep the archive write/delete protected until this group's removals finish.
        with locked_file(archive_path) as backup:
            archive.verify_archive(backup, manifest)
            for row in selected:
                try:
                    remove_verified(root, row)
                except (OSError, ValueError) as exc:
                    result["retained_errors"].append({"path": row["path"], "error": str(exc)})
                else:
                    result["removed_files"] += 1
                    result["removed_bytes"] += row["bytes"]
                if time.monotonic() - last >= 20:
                    receipt.write_bytes(archive.json_bytes(result))
                    archive.emit("cleanup_progress", removed_files=result["removed_files"], removed_bytes=result["removed_bytes"])
                    last = time.monotonic()
        result["groups"].append(entry["archive"])
        receipt.write_bytes(archive.json_bytes(result))
        archive.emit("group_completed", archive=entry["archive"], removed_files=result["removed_files"], removed_bytes=result["removed_bytes"])
    for p, row in current.items():
        if p not in candidates:
            archive.unchanged(root, row)
    for name, expected in runtime_hashes.items():
        with (root / "art" / name).open("rb") as handle:
            if digest_stream(handle) != expected:
                raise ValueError(f"Runtime/non-source art changed: {name}")
    if {p.relative_to(root).as_posix() for p in textures.exported_pngs(root)} != exports:
        raise ValueError("Export image set changed")
    result["free_after"] = shutil.disk_usage(root).free
    result["measured_free_increase"] = result["free_after"] - free_before
    result["finished_utc"] = dt.datetime.now(dt.timezone.utc).isoformat()
    result["status"] = "completed" if not result["retained_errors"] else "partial_retained_changed_or_busy_files"
    result["runtime_art_hashes_unchanged"] = True
    result["retained_source_metadata_unchanged"] = True
    result["export_pngs_unchanged"] = len(exports)
    receipt.write_bytes(archive.json_bytes(result))
    archive.emit("cleanup_completed", **result, receipt=str(receipt))
    if result["retained_errors"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
