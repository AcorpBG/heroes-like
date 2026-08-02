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
from pathlib import Path, PurePosixPath
from typing import BinaryIO


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT_DIR = ROOT / ".artifacts" / "release"
DEFAULT_SOURCE_DATE_EPOCH = 315532800
PRODUCT_ID = "heroes-like"
SCHEMA_ID = "heroes_like_release_index_v1"
PLATFORM_MANIFEST_SCHEMA_ID = "heroes_like_platform_release_manifest_v1"
MAX_ARCHIVE_MEMBER_BYTES = 2 * 1024 * 1024 * 1024
MAX_ARCHIVE_PAYLOAD_BYTES = 4 * 1024 * 1024 * 1024


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
    native = export_dir / spec.native_name
    if spec.platform_id.startswith("linux"):
        binary.chmod(binary.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    verify_binary_header(spec, binary.read_bytes()[:4096], spec.binary_name)
    verify_binary_header(spec, native.read_bytes()[:4096], spec.native_name)
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
        "schema_id": PLATFORM_MANIFEST_SCHEMA_ID,
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


def validate_archive_member_path(name: str, expected_root: str) -> tuple[str, ...]:
    if not name or "\x00" in name or "\\" in name or name.startswith("/"):
        raise RuntimeError(f"unsafe archive member path: {name!r}")
    stripped = name.rstrip("/")
    raw_parts = stripped.split("/")
    if any(part in {"", ".", ".."} for part in raw_parts):
        raise RuntimeError(f"unsafe archive member path: {name!r}")
    path = PurePosixPath(stripped)
    parts = path.parts
    if not parts or any(part in {"", ".", ".."} for part in parts):
        raise RuntimeError(f"unsafe archive member path: {name!r}")
    if parts[0] != expected_root or len(parts) > 2:
        raise RuntimeError(f"archive member escapes expected bundle root {expected_root!r}: {name!r}")
    return parts


def stream_summary(handle: BinaryIO) -> dict[str, object]:
    digest = hashlib.sha256()
    size = 0
    head = bytearray()
    for chunk in iter(lambda: handle.read(1024 * 1024), b""):
        size += len(chunk)
        if size > MAX_ARCHIVE_MEMBER_BYTES:
            raise RuntimeError("release archive member exceeds safety size limit")
        digest.update(chunk)
        if len(head) < 4096:
            head.extend(chunk[: 4096 - len(head)])
    return {"size_bytes": size, "sha256": digest.hexdigest(), "head": bytes(head)}


def archive_file_summaries(spec: PlatformSpec, archive_path: Path, bundle_root: str) -> dict[str, object]:
    rows: dict[str, dict[str, object]] = {}
    seen_names: set[str] = set()
    root_seen = False
    total_size = 0

    if spec.archive_suffix == "tar.gz":
        with tarfile.open(archive_path, "r:gz") as archive:
            for member in archive.getmembers():
                parts = validate_archive_member_path(member.name, bundle_root)
                normalized_name = "/".join(parts)
                if normalized_name in seen_names:
                    raise RuntimeError(f"duplicate archive member: {member.name}")
                seen_names.add(normalized_name)
                if len(parts) == 1:
                    if not member.isdir() or member.issym() or member.islnk():
                        raise RuntimeError(f"bundle root is not a plain directory: {member.name}")
                    if (member.mode & 0o777) != 0o755:
                        raise RuntimeError(f"bundle root mode is not 0755: {member.name}")
                    root_seen = True
                    continue
                if not member.isfile() or member.issym() or member.islnk():
                    raise RuntimeError(f"release archive contains a non-regular payload: {member.name}")
                extracted = archive.extractfile(member)
                if extracted is None:
                    raise RuntimeError(f"release archive payload cannot be read: {member.name}")
                with extracted:
                    summary = stream_summary(extracted)
                summary["mode"] = member.mode & 0o777
                rows[parts[1]] = summary
                total_size += int(summary["size_bytes"])
    elif spec.archive_suffix == "zip":
        with zipfile.ZipFile(archive_path, "r") as archive:
            for member in archive.infolist():
                parts = validate_archive_member_path(member.filename, bundle_root)
                normalized_name = "/".join(parts)
                if normalized_name in seen_names:
                    raise RuntimeError(f"duplicate archive member: {member.filename}")
                seen_names.add(normalized_name)
                mode = (member.external_attr >> 16) & 0xFFFF
                file_type = stat.S_IFMT(mode)
                if member.flag_bits & 0x1:
                    raise RuntimeError(f"encrypted release archive member is not supported: {member.filename}")
                if len(parts) == 1:
                    if not member.is_dir():
                        raise RuntimeError(f"bundle-root archive entry is not a directory: {member.filename}")
                    if file_type not in {0, stat.S_IFDIR}:
                        raise RuntimeError(f"bundle root has an unsafe file type: {member.filename}")
                    root_seen = True
                    continue
                if member.is_dir() or file_type not in {0, stat.S_IFREG}:
                    raise RuntimeError(f"release archive contains a non-regular payload: {member.filename}")
                with archive.open(member, "r") as handle:
                    summary = stream_summary(handle)
                if int(summary["size_bytes"]) != member.file_size:
                    raise RuntimeError(f"ZIP member size changed while reading: {member.filename}")
                summary["mode"] = mode & 0o777
                rows[parts[1]] = summary
                total_size += int(summary["size_bytes"])
    else:
        raise RuntimeError(f"unsupported release archive format: {spec.archive_suffix}")

    if spec.archive_suffix == "tar.gz" and not root_seen:
        raise RuntimeError(f"Linux release archive is missing its bundle root directory: {bundle_root}")
    if total_size > MAX_ARCHIVE_PAYLOAD_BYTES:
        raise RuntimeError(f"release archive payload exceeds safety size limit: {archive_path.name}")
    return {"files": rows, "root_entry_present": root_seen, "total_payload_bytes": total_size}


def verify_binary_header(spec: PlatformSpec, head: bytes, name: str) -> None:
    if spec.platform_id.startswith("linux"):
        if (
            len(head) < 20
            or head[:4] != b"\x7fELF"
            or head[4] != 2
            or head[5] != 1
            or int.from_bytes(head[18:20], "little") != 0x3E
        ):
            raise RuntimeError(f"Linux release payload is not x86_64 ELF: {name}")
        return
    pe_offset = int.from_bytes(head[0x3C:0x40], "little") if len(head) >= 0x40 else 0
    if (
        head[:2] != b"MZ"
        or pe_offset + 6 > len(head)
        or head[pe_offset : pe_offset + 4] != b"PE\x00\x00"
        or int.from_bytes(head[pe_offset + 4 : pe_offset + 6], "little") != 0x8664
    ):
        raise RuntimeError(f"Windows release payload is not x86_64 PE: {name}")


def verified_manifest_rows(manifest: dict, spec: PlatformSpec, version: str) -> dict[str, dict]:
    if manifest.get("schema_id") != PLATFORM_MANIFEST_SCHEMA_ID:
        raise RuntimeError(f"invalid platform manifest schema for {spec.platform_id}")
    if manifest.get("product_id") != PRODUCT_ID or manifest.get("version") != version:
        raise RuntimeError(f"platform manifest product/version mismatch for {spec.platform_id}")
    if manifest.get("platform") != spec.platform_id:
        raise RuntimeError(f"platform manifest target mismatch for {spec.platform_id}")
    values = manifest.get("files")
    if not isinstance(values, list):
        raise RuntimeError(f"platform manifest files are invalid for {spec.platform_id}")
    rows: dict[str, dict] = {}
    for value in values:
        if not isinstance(value, dict):
            raise RuntimeError(f"platform manifest file row is invalid for {spec.platform_id}")
        name = str(value.get("path", ""))
        if not name or "/" in name or "\\" in name or Path(name).name != name or name in rows:
            raise RuntimeError(f"platform manifest contains unsafe or duplicate path: {name!r}")
        digest = str(value.get("sha256", ""))
        size = int(value.get("size_bytes", 0))
        if not re.fullmatch(r"[0-9a-f]{64}", digest) or size <= 0:
            raise RuntimeError(f"platform manifest contains invalid file identity: {name!r}")
        rows[name] = value
    expected = {*spec.required_names, "README.txt"}
    if set(rows) != expected:
        raise RuntimeError(f"platform manifest payload differs from required files for {spec.platform_id}: {sorted(rows)}")
    return rows


def verify_platform_archive(spec: PlatformSpec, archive_path: Path, version: str, indexed_manifest: dict) -> dict:
    bundle_root = f"{PRODUCT_ID}-{version}-{spec.platform_id}"
    archive_summary = archive_file_summaries(spec, archive_path, bundle_root)
    archive_rows = archive_summary["files"]
    expected_archive_files = {*spec.required_names, "README.txt", "release-manifest.json"}
    if set(archive_rows) != expected_archive_files:
        raise RuntimeError(f"{spec.platform_id} archive payload differs from required files: {sorted(archive_rows)}")

    manifest_head = archive_rows["release-manifest.json"]["head"]
    manifest_size = int(archive_rows["release-manifest.json"]["size_bytes"])
    if manifest_size > len(manifest_head):
        raise RuntimeError("release-manifest.json exceeds the bounded manifest size")
    try:
        embedded_manifest = json.loads(manifest_head.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise RuntimeError(f"invalid embedded platform manifest for {spec.platform_id}: {exc}") from exc
    if not isinstance(embedded_manifest, dict) or embedded_manifest != indexed_manifest:
        raise RuntimeError(f"embedded and indexed platform manifests differ for {spec.platform_id}")
    manifest_rows = verified_manifest_rows(embedded_manifest, spec, version)

    for name, manifest_row in manifest_rows.items():
        archive_row = archive_rows[name]
        if int(archive_row["size_bytes"]) != int(manifest_row["size_bytes"]):
            raise RuntimeError(f"archive payload size mismatch for {spec.platform_id}/{name}")
        if str(archive_row["sha256"]) != str(manifest_row["sha256"]):
            raise RuntimeError(f"archive payload hash mismatch for {spec.platform_id}/{name}")

    for name, row in archive_rows.items():
        expected_mode = normalized_mode(Path(name), spec)
        if int(row["mode"]) != expected_mode:
            raise RuntimeError(f"archive payload mode mismatch for {spec.platform_id}/{name}")
    verify_binary_header(spec, bytes(archive_rows[spec.binary_name]["head"]), spec.binary_name)
    verify_binary_header(spec, bytes(archive_rows[spec.native_name]["head"]), spec.native_name)
    return {
        "platform": spec.platform_id,
        "archive": archive_path.name,
        "file_count": len(archive_rows),
        "payload_bytes": int(archive_summary["total_payload_bytes"]),
        "root_entry_present": bool(archive_summary["root_entry_present"]),
        "payload_verified": True,
    }


def parse_checksum_file(path: Path) -> dict[str, str]:
    if not path.is_file():
        raise RuntimeError(f"missing release checksum file: {path}")
    rows: dict[str, str] = {}
    for line in path.read_text(encoding="ascii").splitlines():
        match = re.fullmatch(r"([0-9a-f]{64})  ([^/\\]+)", line)
        if match is None or match.group(2) in rows:
            raise RuntimeError(f"invalid or duplicate SHA256SUMS row: {line!r}")
        rows[match.group(2)] = match.group(1)
    return rows


def verify_release_archives(output_dir: Path) -> dict:
    archives_dir = output_dir.resolve() / "archives"
    index_path = archives_dir / "release-index.json"
    if not index_path.is_file():
        raise RuntimeError(f"missing release index: {index_path}")
    try:
        release_index = json.loads(index_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise RuntimeError(f"invalid release index: {exc}") from exc
    if not isinstance(release_index, dict) or release_index.get("schema_id") != SCHEMA_ID:
        raise RuntimeError("invalid release index schema")
    if release_index.get("product_id") != PRODUCT_ID:
        raise RuntimeError("release index product mismatch")
    version = safe_version(str(release_index.get("version", "")))
    if not isinstance(release_index.get("source_date_epoch"), int):
        raise RuntimeError("release index source_date_epoch is invalid")
    archive_values = release_index.get("archives")
    if not isinstance(archive_values, list) or len(archive_values) != len(PLATFORMS):
        raise RuntimeError("release index must contain exactly one archive per supported platform")
    indexed_rows: dict[str, dict] = {}
    for value in archive_values:
        if not isinstance(value, dict):
            raise RuntimeError("release index archive row is invalid")
        platform_id = str(value.get("platform", ""))
        if platform_id in indexed_rows:
            raise RuntimeError(f"duplicate release index platform: {platform_id}")
        indexed_rows[platform_id] = value
    if set(indexed_rows) != {spec.platform_id for spec in PLATFORMS}:
        raise RuntimeError(f"release index platform set is invalid: {sorted(indexed_rows)}")

    expected_output_names = {
        "release-index.json",
        "SHA256SUMS",
        *(f"{PRODUCT_ID}-{version}-{spec.platform_id}.{spec.archive_suffix}" for spec in PLATFORMS),
    }
    output_entries = list(archives_dir.iterdir())
    unsafe_entries = [path.name for path in output_entries if path.is_symlink() or not path.is_file()]
    actual_output_names = {path.name for path in output_entries}
    if unsafe_entries or actual_output_names != expected_output_names:
        raise RuntimeError(
            "release output directory contains unsafe, missing, or unexpected entries: "
            f"actual={sorted(actual_output_names)} unsafe={sorted(unsafe_entries)}"
        )

    checksum_rows = parse_checksum_file(archives_dir / "SHA256SUMS")
    verified_platforms = []
    for spec in PLATFORMS:
        row = indexed_rows[spec.platform_id]
        expected_name = f"{PRODUCT_ID}-{version}-{spec.platform_id}.{spec.archive_suffix}"
        if str(row.get("path", "")) != expected_name:
            raise RuntimeError(f"release index archive name mismatch for {spec.platform_id}")
        archive_path = archives_dir / expected_name
        if not archive_path.is_file():
            raise RuntimeError(f"missing release archive: {archive_path}")
        archive_digest = sha256(archive_path)
        if int(row.get("size_bytes", -1)) != archive_path.stat().st_size:
            raise RuntimeError(f"release index archive size mismatch for {spec.platform_id}")
        if str(row.get("sha256", "")) != archive_digest:
            raise RuntimeError(f"release index archive hash mismatch for {spec.platform_id}")
        if checksum_rows.get(expected_name) != archive_digest:
            raise RuntimeError(f"SHA256SUMS archive hash mismatch for {spec.platform_id}")
        manifest = row.get("payload_manifest")
        if not isinstance(manifest, dict):
            raise RuntimeError(f"release index payload manifest is invalid for {spec.platform_id}")
        verified_platforms.append(verify_platform_archive(spec, archive_path, version, manifest))
    if set(checksum_rows) != {str(row["path"]) for row in archive_values}:
        raise RuntimeError("SHA256SUMS contains missing or unexpected archive rows")
    return {
        "ok": True,
        "schema_id": SCHEMA_ID,
        "product_id": PRODUCT_ID,
        "version": version,
        "archives_dir": str(archives_dir),
        "platforms": verified_platforms,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build reproducible Linux and Windows heroes-like release archives.")
    parser.add_argument("--version", default=project_version())
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--skip-export", action="store_true", help="Package existing files under <output-dir>/exports.")
    parser.add_argument("--verify-only", action="store_true", help="Verify existing final archives without exporting or packaging.")
    args = parser.parse_args()
    if args.verify_only and args.skip_export:
        parser.error("--verify-only cannot be combined with --skip-export")
    return args


def main() -> int:
    args = parse_args()
    output_dir = args.output_dir.resolve()
    if args.verify_only:
        print(json.dumps(verify_release_archives(output_dir), sort_keys=True))
        return 0
    version = safe_version(args.version)
    exports_dir = output_dir / "exports"
    archives_dir = output_dir / "archives"
    if archives_dir.exists():
        shutil.rmtree(archives_dir)
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
    verification = verify_release_archives(output_dir)
    print(json.dumps({"ok": True, "version": version, "output": str(archives_dir), "archives": archive_rows, "verification": verification}, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, ValueError, subprocess.TimeoutExpired, tarfile.TarError, zipfile.BadZipFile) as exc:
        print(f"package_release: {exc}", file=sys.stderr)
        raise SystemExit(1)
