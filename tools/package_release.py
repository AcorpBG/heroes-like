#!/usr/bin/env python3
from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
import zipfile
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT_DIR = ROOT / ".artifacts" / "release"
DEFAULT_SOURCE_DATE_EPOCH = 315532800
PRODUCT_ID = "heroes-like"
SCHEMA_ID = "heroes_like_release_index_v1"


@dataclass(frozen=True)
class PlatformSpec:
    platform_id: str
    preset: str
    binary_name: str
    native_name: str
    archive_suffix: str

    @property
    def required_names(self) -> tuple[str, ...]:
        return self.binary_name, f"{PRODUCT_ID}.pck", self.native_name


PLATFORMS = (
    PlatformSpec(
        platform_id="linux-x86_64",
        preset="Linux Release",
        binary_name="heroes-like.x86_64",
        native_name="libaurelion_map_persistence.linux.template_release.x86_64.so",
        archive_suffix="tar.gz",
    ),
    PlatformSpec(
        platform_id="windows-x86_64",
        preset="Windows Release",
        binary_name="heroes-like.exe",
        native_name="aurelion_map_persistence.windows.template_release.x86_64.dll",
        archive_suffix="zip",
    ),
)


def project_version() -> str:
    match = re.search(
        r'^config/version="([^"]+)"$',
        (ROOT / "project.godot").read_text(encoding="utf-8"),
        flags=re.MULTILINE,
    )
    if match is None:
        raise ValueError("project.godot must define application config/version")
    return match.group(1)


def safe_version(value: str) -> str:
    normalized = value.strip()
    if not re.fullmatch(r"[0-9A-Za-z][0-9A-Za-z._+-]*", normalized):
        raise ValueError(f"invalid release version: {value!r}")
    return normalized


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def run(args: list[str], timeout: int = 900) -> None:
    env = os.environ.copy()
    env["GODOT_SILENCE_ROOT_WARNING"] = "1"
    completed = subprocess.run(args, cwd=ROOT, env=env, check=False, timeout=timeout)
    if completed.returncode != 0:
        raise RuntimeError(f"command failed ({completed.returncode}): {' '.join(args)}")


def export_platform(spec: PlatformSpec, export_dir: Path, godot: str) -> None:
    if export_dir.exists():
        shutil.rmtree(export_dir)
    export_dir.mkdir(parents=True)
    run(
        [godot, "--headless", "--path", str(ROOT), "--export-release", spec.preset, str(export_dir / spec.binary_name)]
    )


def validate_platform_files(spec: PlatformSpec, export_dir: Path) -> list[Path]:
    files = sorted(path for path in export_dir.rglob("*") if path.is_file())
    relative_names = [path.relative_to(export_dir).as_posix() for path in files]
    if relative_names != sorted(spec.required_names):
        raise RuntimeError(
            f"{spec.platform_id} export payload differs from required files: {relative_names}"
        )
    for path in files:
        if path.stat().st_size <= 0:
            raise RuntimeError(f"empty release artifact: {path}")
    binary = export_dir / spec.binary_name
    header = binary.read_bytes()[:4096]
    if spec.platform_id.startswith("linux"):
        if header[:4] != b"\x7fELF":
            raise RuntimeError(f"Linux executable is not ELF: {binary}")
        binary.chmod(binary.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    else:
        pe_offset = int.from_bytes(header[0x3C:0x40], "little") if len(header) >= 0x40 else 0
        if header[:2] != b"MZ" or header[pe_offset : pe_offset + 4] != b"PE\x00\x00":
            raise RuntimeError(f"Windows executable is not PE: {binary}")
    return files


def release_readme(spec: PlatformSpec, version: str) -> str:
    launch = "./heroes-like.x86_64" if spec.platform_id.startswith("linux") else "heroes-like.exe"
    return (
        f"heroes-like {version}\n"
        f"Platform: {spec.platform_id}\n\n"
        f"Keep every file in this directory together and launch with: {launch}\n"
        "Settings, saves, generated maps, and runtime issue logs are stored in the platform user-data directory.\n"
    )


def stage_platform(spec: PlatformSpec, export_dir: Path, stage_dir: Path, version: str) -> tuple[Path, dict]:
    bundle_name = f"{PRODUCT_ID}-{version}-{spec.platform_id}"
    bundle_root = stage_dir / bundle_name
    bundle_root.mkdir(parents=True)
    source_files = validate_platform_files(spec, export_dir)
    for source in source_files:
        shutil.copy2(source, bundle_root / source.name)
    (bundle_root / "README.txt").write_text(release_readme(spec, version), encoding="utf-8", newline="\n")
    payload_files = sorted(path for path in bundle_root.iterdir() if path.is_file())
    manifest = {
        "schema_id": "heroes_like_platform_release_manifest_v1",
        "product_id": PRODUCT_ID,
        "version": version,
        "platform": spec.platform_id,
        "files": [
            {
                "path": path.name,
                "size_bytes": path.stat().st_size,
                "sha256": sha256(path),
            }
            for path in payload_files
        ],
    }
    manifest_path = bundle_root / "release-manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return bundle_root, manifest


def normalized_mode(path: Path, spec: PlatformSpec) -> int:
    return 0o755 if path.name == spec.binary_name and spec.platform_id.startswith("linux") else 0o644


def create_tar_gz(bundle_root: Path, destination: Path, spec: PlatformSpec, epoch: int) -> None:
    with destination.open("wb") as raw:
        with gzip.GzipFile(filename="", mode="wb", fileobj=raw, mtime=epoch) as compressed:
            with tarfile.open(fileobj=compressed, mode="w") as archive:
                for path in [bundle_root, *sorted(bundle_root.iterdir())]:
                    arcname = path.relative_to(bundle_root.parent).as_posix()
                    info = archive.gettarinfo(str(path), arcname=arcname)
                    info.uid = 0
                    info.gid = 0
                    info.uname = ""
                    info.gname = ""
                    info.mtime = epoch
                    info.mode = 0o755 if path.is_dir() else normalized_mode(path, spec)
                    if path.is_file():
                        with path.open("rb") as handle:
                            archive.addfile(info, handle)
                    else:
                        archive.addfile(info)


def create_zip(bundle_root: Path, destination: Path, spec: PlatformSpec, epoch: int) -> None:
    import datetime

    stamp = datetime.datetime.fromtimestamp(max(epoch, DEFAULT_SOURCE_DATE_EPOCH), tz=datetime.timezone.utc)
    date_time = (stamp.year, stamp.month, stamp.day, stamp.hour, stamp.minute, stamp.second)
    with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(bundle_root.iterdir()):
            info = zipfile.ZipInfo(f"{bundle_root.name}/{path.name}", date_time=date_time)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.create_system = 3
            info.external_attr = normalized_mode(path, spec) << 16
            archive.writestr(info, path.read_bytes(), compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build reproducible Linux and Windows heroes-like release archives.")
    parser.add_argument("--version", default=project_version())
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--skip-export", action="store_true", help="Package existing files under <output-dir>/exports.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    version = safe_version(args.version)
    output_dir = args.output_dir.resolve()
    exports_dir = output_dir / "exports"
    archives_dir = output_dir / "archives"
    archives_dir.mkdir(parents=True, exist_ok=True)
    epoch = int(os.environ.get("SOURCE_DATE_EPOCH", DEFAULT_SOURCE_DATE_EPOCH))

    archive_rows = []
    with tempfile.TemporaryDirectory(prefix="heroes-like-release-") as temp:
        stage_dir = Path(temp)
        for spec in PLATFORMS:
            export_dir = exports_dir / spec.platform_id
            if not args.skip_export:
                export_platform(spec, export_dir, args.godot)
            bundle_root, platform_manifest = stage_platform(spec, export_dir, stage_dir, version)
            archive_name = f"{bundle_root.name}.{spec.archive_suffix}"
            archive_path = archives_dir / archive_name
            if archive_path.exists():
                archive_path.unlink()
            if spec.archive_suffix == "tar.gz":
                create_tar_gz(bundle_root, archive_path, spec, epoch)
            else:
                create_zip(bundle_root, archive_path, spec, epoch)
            archive_rows.append(
                {
                    "platform": spec.platform_id,
                    "path": archive_path.name,
                    "size_bytes": archive_path.stat().st_size,
                    "sha256": sha256(archive_path),
                    "payload_manifest": platform_manifest,
                }
            )

    release_index = {
        "schema_id": SCHEMA_ID,
        "product_id": PRODUCT_ID,
        "version": version,
        "source_date_epoch": epoch,
        "archives": archive_rows,
    }
    index_path = archives_dir / "release-index.json"
    index_path.write_text(json.dumps(release_index, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    checksum_path = archives_dir / "SHA256SUMS"
    checksum_path.write_text(
        "".join(f"{row['sha256']}  {row['path']}\n" for row in archive_rows),
        encoding="ascii",
    )
    print(json.dumps({"ok": True, "version": version, "output": str(archives_dir), "archives": archive_rows}, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, ValueError, subprocess.TimeoutExpired) as exc:
        print(f"package_release: {exc}", file=sys.stderr)
        raise SystemExit(1)
