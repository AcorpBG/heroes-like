#!/usr/bin/env python3
"""Restore selected archived art sources from the verified ZIP snapshot. Dry-run by default.

Source-dependent authoring, repacking and art regression tests need originals
that live in the external archive (see docs/source-material-storage-map.md).
This restores only the requested repository-relative paths, checks every
payload against the archive manifest SHA-256 and never overwrites a local
file whose content differs. Remove restored files again with
tools/remove_archived_source_material.py.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import sys
import zipfile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]


def safe_target(root, name):
    parts = PurePosixPath(name).parts
    if (len(parts) < 4 or parts[0] != "art" or parts[2] != "source" or "\\" in name
            or ":" in name or any(p in ("", ".", "..") for p in name.split("/"))):
        raise ValueError(f"Outside art source scope: {name}")
    path = root.joinpath(*parts)
    if not path.resolve().is_relative_to(root.resolve()):
        raise ValueError(f"Path escaped repository: {name}")
    return path


def load_index(archive_dir):
    index = json.loads((archive_dir / "archive-index.json").read_text(encoding="utf-8"))
    rows = {}
    for entry in index["archives"]:
        manifest = json.loads((archive_dir / entry["manifest"]).read_text(encoding="utf-8"))
        for row in manifest["files"]:
            rows[row["path"]] = {**row, "archive": entry["archive"]}
    return rows


def select(rows, paths, prefixes):
    chosen, unknown = [], []
    for path in paths:
        (chosen if path in rows else unknown).append(path)
    for prefix in prefixes:
        matches = [p for p in rows if p.startswith(prefix)]
        if matches:
            chosen.extend(matches)
        else:
            unknown.append(prefix + "*")
    return sorted(set(chosen)), unknown


def file_sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def restore(root, archive_dir, rows, names, apply):
    counts = {"restored": 0, "would_restore": 0, "present": 0, "conflict": 0}
    by_archive = {}
    for name in names:
        target = safe_target(root, name)
        if target.exists():
            if target.is_file() and file_sha256(target) == rows[name]["sha256"]:
                counts["present"] += 1
            else:
                counts["conflict"] += 1
                print(f"CONFLICT local file differs from archive, left untouched: {name}")
            continue
        by_archive.setdefault(rows[name]["archive"], []).append((name, target))
    for archive_name, items in sorted(by_archive.items()):
        if not apply:
            counts["would_restore"] += len(items)
            continue
        with zipfile.ZipFile(archive_dir / archive_name) as archive:
            for name, target in items:
                row = rows[name]
                target.parent.mkdir(parents=True, exist_ok=True)
                partial = target.with_name(target.name + ".restore-partial")
                digest = hashlib.sha256()
                with archive.open(name) as source, partial.open("xb") as output:
                    for block in iter(lambda: source.read(1 << 20), b""):
                        digest.update(block)
                        output.write(block)
                if digest.hexdigest() != row["sha256"] or partial.stat().st_size != row["bytes"]:
                    partial.unlink()
                    raise RuntimeError(f"Archive payload failed SHA-256/size check: {name}")
                if target.exists():
                    partial.unlink()
                    counts["conflict"] += 1
                    print(f"CONFLICT file appeared during restore, left untouched: {name}")
                    continue
                os.replace(partial, target)
                counts["restored"] += 1
    return counts


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--archive-dir", required=True, type=Path, help="Snapshot directory holding archive-index.json and the ZIPs")
    parser.add_argument("--path", action="append", default=[], help="Repository-relative source path to restore (repeatable)")
    parser.add_argument("--prefix", action="append", default=[], help="Restore every archived path starting with this prefix (repeatable)")
    parser.add_argument("--paths-file", type=Path, help="Text file with one repository-relative path per line")
    parser.add_argument("--root", type=Path, default=ROOT, help="Repository root to restore into")
    parser.add_argument("--apply", action="store_true", help="Write files; without it only report what would be restored")
    args = parser.parse_args(argv)
    paths = list(args.path)
    if args.paths_file:
        paths += [line.strip() for line in args.paths_file.read_text(encoding="utf-8").splitlines() if line.strip()]
    if not paths and not args.prefix:
        parser.error("give at least one --path, --prefix or --paths-file")
    rows = load_index(args.archive_dir)
    names, unknown = select(rows, paths, args.prefix)
    for name in unknown:
        print(f"NOT_IN_ARCHIVE {name}")
    counts = restore(args.root.resolve(), args.archive_dir, rows, names, args.apply)
    print("RESTORE " + " ".join(f"{k}={v}" for k, v in counts.items()) + f" not_in_archive={len(unknown)} apply={args.apply}")
    return 1 if unknown or counts["conflict"] else 0


if __name__ == "__main__":
    sys.exit(main())
