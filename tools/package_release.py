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
import struct
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
SCHEMA_ID = "heroes_like_release_index_v3"
PLATFORM_MANIFEST_SCHEMA_ID = "heroes_like_platform_release_manifest_v2"
BUILD_INFO_SCHEMA_ID = "heroes_like_build_info_v1"
MAX_ARCHIVE_MEMBER_BYTES = 2 * 1024 * 1024 * 1024
MAX_ARCHIVE_PAYLOAD_BYTES = 4 * 1024 * 1024 * 1024
INSTALLER_ROOT = ROOT / "packaging" / "installers"
WINDOWS_INSTALLER_HELPER_SOURCE = ROOT / "tools" / "windows_installer_helper.c"
WINDOWS_INSTALLER_HELPER_NAME = "heroes-like-installer-helper.exe"
WINDOWS_UNINSTALL_REGISTRY_PARENT = r"Software\Microsoft\Windows\CurrentVersion\Uninstall"
WINDOWS_UNINSTALL_REGISTRY_KEY = r"Software\Microsoft\Windows\CurrentVersion\Uninstall\Heroes Like"
WINDOWS_TECHNICAL_NAME = "Heroes Like"
WINDOWS_PRODUCT_NAME = "Aurelion Reach"
WINDOWS_PUBLISHER = "Aurelion Reach contributors"
WINDOWS_PUBLIC_GAME_SHORTCUT = "Aurelion Reach.lnk"
WINDOWS_PUBLIC_UNINSTALL_SHORTCUT = "Uninstall Aurelion Reach.lnk"
WINDOWS_LEGACY_GAME_SHORTCUT = "Heroes Like.lnk"
WINDOWS_LEGACY_UNINSTALL_SHORTCUT = "Uninstall Heroes Like.lnk"
WINDOWS_VERSION_CHANNEL_BASES = {
    "alpha": 1000,
    "beta": 2000,
    "rc": 3000,
}


@dataclass(frozen=True)
class PlatformSpec:
    platform_id: str
    preset: str
    binary_name: str
    native_name: str
    archive_suffix: str
    installer_names: tuple[str, str]

    @property
    def runnable_installer_suffix(self) -> str:
        return "run" if self.platform_id.startswith("linux") else "setup.exe"

    def runnable_installer_name(self, version: str) -> str:
        return f"{PRODUCT_ID}-{version}-{self.platform_id}.{self.runnable_installer_suffix}"

    @property
    def required_names(self) -> tuple[str, ...]:
        return self.binary_name, f"{PRODUCT_ID}.pck", self.native_name

    @property
    def staged_names(self) -> tuple[str, ...]:
        platform_helpers = (WINDOWS_INSTALLER_HELPER_NAME,) if self.platform_id.startswith("windows") else ()
        return (*self.required_names, "README.txt", "build-info.json", *self.installer_names, *platform_helpers)


PLATFORMS = (
    PlatformSpec(
        platform_id="linux-x86_64",
        preset="Linux Release",
        binary_name="heroes-like.x86_64",
        native_name="libaurelion_map_persistence.linux.template_release.x86_64.so",
        archive_suffix="tar.gz",
        installer_names=("install.sh", "uninstall.sh"),
    ),
    PlatformSpec(
        platform_id="windows-x86_64",
        preset="Windows Release",
        binary_name="heroes-like.exe",
        native_name="aurelion_map_persistence.windows.template_release.x86_64.dll",
        archive_suffix="zip",
        installer_names=("install.cmd", "uninstall.cmd"),
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


def windows_numeric_version(value: str) -> str:
    """Map the canonical release SemVer to an ordered Windows four-part version."""
    normalized = safe_version(value)
    match = re.fullmatch(
        r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-(alpha|beta|rc)\.([1-9][0-9]*))?",
        normalized,
    )
    if match is None:
        raise ValueError(f"unsupported Windows release version: {value!r}")
    major, minor, patch = (int(match.group(index)) for index in range(1, 4))
    if any(part > 65535 for part in (major, minor, patch)):
        raise ValueError(f"Windows release version component exceeds 65535: {value!r}")
    channel = match.group(4)
    if channel is None:
        revision = 65535
    else:
        sequence = int(match.group(5))
        if sequence > 999:
            raise ValueError(f"Windows prerelease sequence exceeds 999: {value!r}")
        revision = WINDOWS_VERSION_CHANNEL_BASES[channel] + sequence
    return f"{major}.{minor}.{patch}.{revision}"


def _aligned_offset(offset: int) -> int:
    return (offset + 3) & ~3


def _decode_utf16_key(data: bytes, offset: int, limit: int) -> tuple[str, int]:
    cursor = offset
    while cursor + 1 < limit and data[cursor : cursor + 2] != b"\x00\x00":
        cursor += 2
    if cursor + 1 >= limit:
        raise ValueError("unterminated PE version-resource key")
    return data[offset:cursor].decode("utf-16le"), cursor + 2


def _read_windows_version_block(data: bytes, offset: int, limit: int) -> dict[str, object]:
    if offset + 6 > limit:
        raise ValueError("truncated PE version-resource block")
    length, value_length, value_type = struct.unpack_from("<HHH", data, offset)
    block_end = offset + length
    if length < 6 or block_end > limit:
        raise ValueError("invalid PE version-resource block length")
    key, key_end = _decode_utf16_key(data, offset + 6, block_end)
    value_offset = _aligned_offset(key_end)
    value_size = value_length * 2 if value_type == 1 else value_length
    value_end = value_offset + value_size
    if value_end > block_end:
        raise ValueError("invalid PE version-resource value length")
    children = []
    cursor = _aligned_offset(value_end)
    while cursor + 6 <= block_end:
        child_length = int.from_bytes(data[cursor : cursor + 2], "little")
        if child_length == 0:
            break
        child = _read_windows_version_block(data, cursor, block_end)
        children.append(child)
        cursor = _aligned_offset(cursor + child_length)
    return {
        "key": key,
        "value_length": value_length,
        "value_type": value_type,
        "value_offset": value_offset,
        "value_end": value_end,
        "children": children,
    }


def _windows_version_quad(ms: int, ls: int) -> str:
    return f"{ms >> 16}.{ms & 0xFFFF}.{ls >> 16}.{ls & 0xFFFF}"


def _pe_rva_to_offset(data: bytes, section_table: int, section_count: int, rva: int, size: int) -> int:
    for index in range(section_count):
        section = section_table + index * 40
        if section + 40 > len(data):
            break
        virtual_size, virtual_address, raw_size, raw_offset = struct.unpack_from("<IIII", data, section + 8)
        mapped_size = max(virtual_size, raw_size)
        if virtual_address <= rva and rva + size <= virtual_address + mapped_size:
            delta = rva - virtual_address
            offset = raw_offset + delta
            if delta + size <= raw_size and offset + size <= len(data):
                return offset
    raise ValueError(f"PE RVA 0x{rva:x} is not backed by a section")


def _pe_resource_entries(data: bytes, resource_root: int, directory_offset: int, resource_limit: int) -> list[tuple[int, int]]:
    directory = resource_root + directory_offset
    if directory < resource_root or directory + 16 > resource_limit:
        raise ValueError("PE resource directory is out of bounds")
    named_count, id_count = struct.unpack_from("<HH", data, directory + 12)
    count = named_count + id_count
    entries_offset = directory + 16
    if entries_offset + count * 8 > resource_limit:
        raise ValueError("PE resource entries are out of bounds")
    return [struct.unpack_from("<II", data, entries_offset + index * 8) for index in range(count)]


def _pe_version_resource_blob(path: Path) -> bytes:
    data = path.read_bytes()
    if len(data) < 0x40 or data[:2] != b"MZ":
        raise ValueError("missing DOS header")
    pe_offset = int.from_bytes(data[0x3C:0x40], "little")
    if pe_offset + 24 > len(data) or data[pe_offset : pe_offset + 4] != b"PE\x00\x00":
        raise ValueError("missing PE header")
    section_count = int.from_bytes(data[pe_offset + 6 : pe_offset + 8], "little")
    optional_size = int.from_bytes(data[pe_offset + 20 : pe_offset + 22], "little")
    optional = pe_offset + 24
    if optional + optional_size > len(data):
        raise ValueError("truncated PE optional header")
    magic = int.from_bytes(data[optional : optional + 2], "little")
    if magic == 0x20B:
        directory_offset = optional + 112
    elif magic == 0x10B:
        directory_offset = optional + 96
    else:
        raise ValueError("unsupported PE optional-header format")
    resource_entry = directory_offset + 2 * 8
    if resource_entry + 8 > optional + optional_size:
        raise ValueError("PE resource data directory is missing")
    resource_rva, resource_size = struct.unpack_from("<II", data, resource_entry)
    if resource_rva == 0 or resource_size < 16:
        raise ValueError("PE resource directory is empty")
    section_table = optional + optional_size
    resource_root = _pe_rva_to_offset(data, section_table, section_count, resource_rva, resource_size)
    resource_limit = resource_root + resource_size

    type_entries = [
        entry
        for entry in _pe_resource_entries(data, resource_root, 0, resource_limit)
        if entry[0] & 0x80000000 == 0 and entry[0] & 0xFFFF == 16
    ]
    if len(type_entries) != 1 or type_entries[0][1] & 0x80000000 == 0:
        raise ValueError("PE must contain exactly one RT_VERSION resource directory")
    name_directory = type_entries[0][1] & 0x7FFFFFFF
    name_entries = _pe_resource_entries(data, resource_root, name_directory, resource_limit)
    if len(name_entries) != 1 or name_entries[0][1] & 0x80000000 == 0:
        raise ValueError("PE RT_VERSION must contain exactly one name entry")
    language_directory = name_entries[0][1] & 0x7FFFFFFF
    language_entries = _pe_resource_entries(data, resource_root, language_directory, resource_limit)
    if len(language_entries) != 1 or language_entries[0][1] & 0x80000000:
        raise ValueError("PE RT_VERSION must contain exactly one language entry")
    data_entry = resource_root + language_entries[0][1]
    if data_entry < resource_root or data_entry + 16 > resource_limit:
        raise ValueError("PE RT_VERSION data entry is out of bounds")
    version_rva, version_size = struct.unpack_from("<II", data, data_entry)
    if version_size < 6 or version_size > resource_size:
        raise ValueError("PE RT_VERSION payload size is invalid")
    version_offset = _pe_rva_to_offset(data, section_table, section_count, version_rva, version_size)
    return data[version_offset : version_offset + version_size]


def read_windows_version_resource(path: Path) -> dict[str, object]:
    try:
        data = _pe_version_resource_blob(path)
        root = _read_windows_version_block(data, 0, len(data))
    except (OSError, UnicodeDecodeError, ValueError) as exc:
        raise RuntimeError(f"Windows PE version resource is invalid: {path.name}: {exc}") from exc
    if root.get("key") != "VS_VERSION_INFO":
        raise RuntimeError(f"Windows PE version resource root is invalid: {path.name}")
    fixed_offset = int(root["value_offset"])
    fixed_end = int(root["value_end"])
    if fixed_end - fixed_offset < 52:
        raise RuntimeError(f"Windows PE fixed version info is missing: {path.name}")
    fixed = struct.unpack_from("<13I", data, fixed_offset)
    if fixed[0] != 0xFEEF04BD:
        raise RuntimeError(f"Windows PE fixed version signature is invalid: {path.name}")
    strings: dict[str, str] = {}

    def collect(block: dict[str, object]) -> None:
        key = str(block.get("key", ""))
        if int(block.get("value_type", 0)) == 1 and int(block.get("value_length", 0)) > 0:
            start = int(block["value_offset"])
            end = int(block["value_end"])
            value = data[start:end].decode("utf-16le").rstrip("\x00")
            if key in strings and strings[key] != value:
                raise RuntimeError(f"Windows PE version resource has conflicting {key} strings: {path.name}")
            strings[key] = value
        for child in block.get("children", []):
            collect(child)

    collect(root)
    return {
        "file_version": _windows_version_quad(fixed[2], fixed[3]),
        "product_version": _windows_version_quad(fixed[4], fixed[5]),
        "strings": strings,
    }


def verify_windows_pe_version(
    path: Path,
    semantic_version: str,
    string_version: str | None = None,
    product_name: str = WINDOWS_PRODUCT_NAME,
    file_description: str = WINDOWS_PRODUCT_NAME,
) -> dict[str, object]:
    expected = windows_numeric_version(semantic_version)
    expected_string = expected if string_version is None else string_version
    result = read_windows_version_resource(path)
    strings = result.get("strings", {})
    if result.get("file_version") != expected or result.get("product_version") != expected:
        raise RuntimeError(f"Windows PE fixed version mismatch for {path.name}: expected {expected}, got {result}")
    if strings.get("FileVersion") != expected_string or strings.get("ProductVersion") != expected_string:
        raise RuntimeError(
            f"Windows PE string version mismatch for {path.name}: expected {expected_string}, got {strings}"
        )
    if strings.get("ProductName") != product_name or strings.get("FileDescription") != file_description:
        raise RuntimeError(f"Windows PE product identity mismatch for {path.name}: {strings}")
    return result


def validate_windows_export_preset_version(semantic_version: str) -> str:
    expected = windows_numeric_version(semantic_version)
    preset_text = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
    preset_headers = list(re.finditer(r"(?m)^\[preset\.([0-9]+)\]\s*$", preset_text))
    windows_ids: list[str] = []
    for header in preset_headers:
        next_header = re.search(r"(?m)^\[", preset_text[header.end() :])
        body_end = header.end() + next_header.start() if next_header is not None else len(preset_text)
        body = preset_text[header.end() : body_end]
        if re.search(r'(?m)^name="Windows Release"\s*$', body):
            windows_ids.append(header.group(1))
    if len(windows_ids) != 1:
        raise RuntimeError(f"Windows export preset application/file_version must equal {expected}")
    options_match = re.search(
        rf"(?ms)^\[preset\.{windows_ids[0]}\.options\]\s*$(.*?)(?=^\[|\Z)",
        preset_text,
    )
    if options_match is None:
        raise RuntimeError(f"Windows export preset application/file_version must equal {expected}")
    options = options_match.group(1)
    required = {
        "application/file_version": expected,
        "application/product_version": expected,
        "application/company_name": WINDOWS_PUBLISHER,
        "application/product_name": WINDOWS_PRODUCT_NAME,
        "application/file_description": WINDOWS_PRODUCT_NAME,
        "application/copyright": "Copyright 2026 Aurelion Reach contributors",
    }
    for key, value in required.items():
        if re.search(rf'(?m)^{re.escape(key)}="{re.escape(value)}"\s*$', options) is None:
            raise RuntimeError(f"Windows export preset {key} must equal {value}")
    return expected


def safe_source_revision(value: str) -> str:
    normalized = value.strip()
    if not re.fullmatch(r"(?:[0-9a-f]{40}|[0-9a-f]{64})", normalized):
        raise ValueError("source revision must be a full lowercase Git object id")
    return normalized


def resolve_source_revision(explicit_revision: str) -> str:
    if explicit_revision:
        return safe_source_revision(explicit_revision)
    status = subprocess.run(
        ["git", "status", "--porcelain", "--untracked-files=no"],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    if status.returncode != 0:
        raise RuntimeError(f"cannot inspect release source worktree: {status.stderr.strip()}")
    if status.stdout.strip():
        raise RuntimeError("release source has tracked changes; commit them or provide --source-revision from CI")
    revision = subprocess.run(
        ["git", "rev-parse", "--verify", "HEAD"],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    if revision.returncode != 0:
        raise RuntimeError(f"cannot resolve release source revision: {revision.stderr.strip()}")
    return safe_source_revision(revision.stdout)


def build_info(spec: PlatformSpec, version: str, source_revision: str, epoch: int) -> dict:
    return {
        "schema_id": BUILD_INFO_SCHEMA_ID,
        "product_id": PRODUCT_ID,
        "version": version,
        "platform": spec.platform_id,
        "source_revision": source_revision,
        "source_date_epoch": epoch,
    }


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


def build_windows_installer_helper(destination: Path) -> None:
    compiler = os.environ.get("MINGW_CC", shutil.which("x86_64-w64-mingw32-gcc") or "")
    if not compiler:
        raise RuntimeError("x86_64-w64-mingw32-gcc is required for the Windows installer helper")
    if not WINDOWS_INSTALLER_HELPER_SOURCE.is_file():
        raise RuntimeError(f"missing Windows installer helper source: {WINDOWS_INSTALLER_HELPER_SOURCE}")
    run([
        compiler,
        "-Os",
        "-s",
        "-Wl,--no-insert-timestamp",
        "-municode",
        str(WINDOWS_INSTALLER_HELPER_SOURCE),
        "-o",
        str(destination),
        "-lbcrypt",
    ])
    if not destination.is_file() or destination.stat().st_size <= 0:
        raise RuntimeError("Windows installer helper build produced no executable")
    verify_binary_header(PLATFORMS[1], destination.read_bytes()[:4096], destination.name)


def export_platform(spec: PlatformSpec, export_dir: Path, godot: str) -> None:
    if export_dir.exists():
        shutil.rmtree(export_dir)
    export_dir.mkdir(parents=True)
    run(
        [godot, "--headless", "--path", str(ROOT), "--export-release", spec.preset, str(export_dir / spec.binary_name)]
    )


def validate_platform_files(spec: PlatformSpec, export_dir: Path, version: str) -> list[Path]:
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
    if spec.platform_id.startswith("windows"):
        verify_windows_pe_version(binary, version)
    return files


def release_readme(spec: PlatformSpec, version: str) -> str:
    launch = "./heroes-like.x86_64" if spec.platform_id.startswith("linux") else "heroes-like.exe"
    install = "./install.sh" if spec.platform_id.startswith("linux") else "install.cmd"
    uninstall = "./uninstall.sh" if spec.platform_id.startswith("linux") else "uninstall.cmd"
    return (
        f"heroes-like {version}\n"
        f"Platform: {spec.platform_id}\n\n"
        f"Keep every file in this directory together and launch with: {launch}\n"
        f"Install for the current user with: {install}\n"
        f"Remove installed program files with: {uninstall}\n"
        "Settings, saves, generated maps, and runtime issue logs are stored in the platform user-data directory.\n"
        "Uninstalling program files does not remove that user data.\n"
    )


def stage_platform(
    spec: PlatformSpec,
    export_dir: Path,
    stage_dir: Path,
    version: str,
    source_revision: str,
    epoch: int,
) -> tuple[Path, dict]:
    bundle_name = f"{PRODUCT_ID}-{version}-{spec.platform_id}"
    bundle_root = stage_dir / bundle_name
    bundle_root.mkdir(parents=True)
    source_files = validate_platform_files(spec, export_dir, version)
    for source in source_files:
        shutil.copy2(source, bundle_root / source.name)
    (bundle_root / "README.txt").write_text(release_readme(spec, version), encoding="utf-8", newline="\n")
    (bundle_root / "build-info.json").write_text(
        json.dumps(build_info(spec, version, source_revision, epoch), indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    installer_dir = INSTALLER_ROOT / ("linux" if spec.platform_id.startswith("linux") else "windows")
    for installer_name in spec.installer_names:
        source = installer_dir / installer_name
        if not source.is_file() or source.stat().st_size <= 0:
            raise RuntimeError(f"missing installer payload for {spec.platform_id}: {source}")
        shutil.copy2(source, bundle_root / installer_name)
    if spec.platform_id.startswith("windows"):
        build_windows_installer_helper(bundle_root / WINDOWS_INSTALLER_HELPER_NAME)
    payload_files = sorted(path for path in bundle_root.iterdir() if path.is_file())
    manifest = {
        "schema_id": PLATFORM_MANIFEST_SCHEMA_ID,
        "product_id": PRODUCT_ID,
        "version": version,
        "platform": spec.platform_id,
        "source_revision": source_revision,
        "source_date_epoch": epoch,
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
    executable = path.name == spec.binary_name or path.name in spec.installer_names
    return 0o755 if executable and spec.platform_id.startswith("linux") else 0o644


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


LINUX_INSTALLER_MARKER = b"__HEROES_LIKE_ARCHIVE_BELOW__\n"


def create_linux_runnable_installer(
    archive_path: Path,
    destination: Path,
    bundle_root_name: str,
) -> None:
    archive_digest = sha256(archive_path)
    header = f"""#!/bin/sh
set -eu
umask 077

ARCHIVE_SHA256='{archive_digest}'
BUNDLE_ROOT='{bundle_root_name}'
MARKER='__HEROES_LIKE_ARCHIVE_BELOW__'
SELF=$0
WORK_DIR=$(mktemp -d "${{TMPDIR:-/tmp}}/heroes-like-installer.XXXXXX")
cleanup() {{ rm -rf "$WORK_DIR"; }}
trap cleanup EXIT HUP INT TERM
MARKER_LINE=$(awk -v marker="$MARKER" '$0 == marker {{ print NR; exit }}' "$SELF")
if [ -z "$MARKER_LINE" ]; then
	echo "heroes-like installer: embedded payload marker is missing" >&2
	exit 1
fi
PAYLOAD_LINE=$((MARKER_LINE + 1))
tail -n +"$PAYLOAD_LINE" "$SELF" > "$WORK_DIR/release.tar.gz"
printf '%s  %s\n' "$ARCHIVE_SHA256" "$WORK_DIR/release.tar.gz" | sha256sum -c - >/dev/null
tar -xzf "$WORK_DIR/release.tar.gz" -C "$WORK_DIR"
if [ ! -f "$WORK_DIR/$BUNDLE_ROOT/install.sh" ]; then
	echo "heroes-like installer: verified payload is missing install.sh" >&2
	exit 1
fi
sh "$WORK_DIR/$BUNDLE_ROOT/install.sh"
exit 0
__HEROES_LIKE_ARCHIVE_BELOW__
""".encode("ascii")
    with destination.open("wb") as handle:
        handle.write(header)
        with archive_path.open("rb") as archive:
            shutil.copyfileobj(archive, handle, length=1024 * 1024)
    destination.chmod(0o755)


def nsis_string(value: str) -> str:
    return value.replace("$", "$$").replace('"', '$\\"')


def windows_nsis_payload_rows(bundle_root: Path, platform_manifest: dict) -> list[dict[str, object]]:
    values = platform_manifest.get("files")
    if not isinstance(values, list):
        raise RuntimeError("Windows setup platform manifest has no file rows")
    rows: list[dict[str, object]] = []
    seen: set[str] = set()
    for value in values:
        if not isinstance(value, dict):
            raise RuntimeError("Windows setup platform manifest has invalid file rows")
        name = str(value.get("path", ""))
        folded = name.casefold()
        if not name or "/" in name or "\\" in name or Path(name).name != name or folded in seen:
            raise RuntimeError("Windows setup platform manifest has invalid or duplicate file rows")
        size_bytes = value.get("size_bytes")
        digest = str(value.get("sha256", "")).lower()
        if not isinstance(size_bytes, int) or size_bytes <= 0 or not re.fullmatch(r"[0-9a-f]{64}", digest):
            raise RuntimeError(f"Windows setup platform manifest has invalid file identity: {name}")
        path = bundle_root / name
        if not path.is_file() or path.stat().st_size <= 0:
            raise RuntimeError(f"missing Windows setup payload: {path}")
        if path.stat().st_size != size_bytes or sha256(path) != digest:
            raise RuntimeError(f"Windows setup platform manifest identity mismatch: {name}")
        seen.add(folded)
        rows.append({"path": name, "size_bytes": size_bytes, "sha256": digest})
    manifest_path = bundle_root / "release-manifest.json"
    if not manifest_path.is_file() or manifest_path.stat().st_size <= 0:
        raise RuntimeError(f"missing Windows setup payload: {manifest_path}")
    if manifest_path.name.casefold() in seen:
        raise RuntimeError("Windows setup platform manifest must not own release-manifest.json")
    rows.append({
        "path": manifest_path.name,
        "size_bytes": manifest_path.stat().st_size,
        "sha256": sha256(manifest_path),
    })
    return sorted(rows, key=lambda row: str(row["path"]).casefold())


def create_windows_nsis_installer(
    bundle_root: Path,
    destination: Path,
    version: str,
    makensis: str,
    platform_manifest: dict,
) -> None:
    if not makensis:
        raise RuntimeError("makensis is required to build the Windows setup executable")
    numeric_version = windows_numeric_version(version)
    arp_parent = nsis_string(WINDOWS_UNINSTALL_REGISTRY_PARENT)
    arp_key = nsis_string(WINDOWS_UNINSTALL_REGISTRY_KEY)
    payload_rows = windows_nsis_payload_rows(bundle_root, platform_manifest)
    payload_names = [str(row["path"]) for row in payload_rows]
    helper_row = next(
        (row for row in payload_rows if str(row["path"]) == WINDOWS_INSTALLER_HELPER_NAME),
        None,
    )
    if helper_row is None:
        raise RuntimeError("Windows setup payload is missing the installer helper")
    script_path = bundle_root.parent / "heroes-like-installer.nsi"
    ownership_path = bundle_root.parent / "heroes-like-ownership.ini"
    ownership_lines = [
        "[Ownership]",
        "Schema=heroes-like-windows-install-ownership-v1",
        "Product=heroes-like",
        "Platform=windows-x86_64",
        "Marker=heroes-like-user-local-install-v1",
        f"FileCount={len(payload_rows)}",
    ]
    for index, row in enumerate(payload_rows):
        ownership_lines.extend([
            "",
            f"[File{index}]",
            f"Path={row['path']}",
            f"Size={row['size_bytes']}",
            f"Sha256={row['sha256']}",
        ])
    ownership_path.write_text("\n".join(ownership_lines) + "\n", encoding="ascii", newline="\n")
    ownership_size = ownership_path.stat().st_size
    ownership_sha256 = sha256(ownership_path)
    file_rows = "\n".join(
        f'  File /oname={nsis_string(name)} "{nsis_string(str(bundle_root / name))}"\n'
        "  IfErrors commit_candidate_metadata_failed"
        for name in payload_names
    )
    script = f"""Unicode True
!include "LogicLib.nsh"
Name "{WINDOWS_PRODUCT_NAME} {nsis_string(version)}"
OutFile "{nsis_string(str(destination))}"
VIProductVersion "{numeric_version}"
VIAddVersionKey /LANG=1033 "FileVersion" "{numeric_version}"
VIAddVersionKey /LANG=1033 "ProductVersion" "{numeric_version}"
VIAddVersionKey /LANG=1033 "ProductName" "{WINDOWS_PRODUCT_NAME}"
VIAddVersionKey /LANG=1033 "FileDescription" "{WINDOWS_PRODUCT_NAME}"
VIAddVersionKey /LANG=1033 "CompanyName" "{WINDOWS_PUBLISHER}"
VIAddVersionKey /LANG=1033 "LegalCopyright" "Copyright 2026 Aurelion Reach contributors"
InstallDir "$LOCALAPPDATA\\Heroes Like"
RequestExecutionLevel user
SetCompressor zlib
SetCompress off
CRCCheck off
SetDateSave off
SilentInstall normal
SilentUnInstall normal

Var TxPath
Var TxSize
Var TxHash
Var TxActual
Var TxHandle
Var TxOutput
Var TxIndex
Var TxCount
Var TxName
Var TxFind
Var RegistrationResult
Var ArpKeyPresent
Var LegacyKeyPresent
Var LegacyOwnershipSha
Var LegacyOwnershipShaPresent
Var LegacyOwnershipSize
Var LegacyOwnershipSizePresent
Var ArpDisplayName
Var ArpDisplayNamePresent
Var ArpDisplayVersion
Var ArpDisplayVersionPresent
Var ArpPublisher
Var ArpPublisherPresent
Var ArpInstallLocation
Var ArpInstallLocationPresent
Var ArpDisplayIcon
Var ArpDisplayIconPresent
Var ArpUninstallString
Var ArpUninstallStringPresent
Var ArpQuietUninstallString
Var ArpQuietUninstallStringPresent
Var ArpNoModify
Var ArpNoModifyPresent
Var ArpNoRepair
Var ArpNoRepairPresent
Var LegacyGameShortcutPresent
Var LegacyUninstallShortcutPresent
Var PublicGameShortcutPresent
Var PublicUninstallShortcutPresent

!macro VERIFY_FILE ROOT NAME SIZE HASH FAILURE
  StrCpy $TxPath "${{ROOT}}\\${{NAME}}"
  StrCpy $TxSize "${{SIZE}}"
  StrCpy $TxHash "${{HASH}}"
  Call VerifyFileIdentity
  StrCmp $TxActual "ok" +2
  Goto ${{FAILURE}}
!macroend

!macro SNAPSHOT_REG_STR ROOT KEY NAME VALUE PRESENT
  StrCpy ${{PRESENT}} "0"
  ClearErrors
  ReadRegStr ${{VALUE}} ${{ROOT}} "${{KEY}}" "${{NAME}}"
  IfErrors +2
  StrCpy ${{PRESENT}} "1"
!macroend

!macro SNAPSHOT_REG_DWORD ROOT KEY NAME VALUE PRESENT
  StrCpy ${{PRESENT}} "0"
  ClearErrors
  ReadRegDWORD ${{VALUE}} ${{ROOT}} "${{KEY}}" "${{NAME}}"
  IfErrors +2
  StrCpy ${{PRESENT}} "1"
!macroend

!macro RESTORE_REG_STR ROOT KEY NAME VALUE PRESENT
  DeleteRegValue ${{ROOT}} "${{KEY}}" "${{NAME}}"
  StrCmp ${{PRESENT}} "1" 0 +2
  WriteRegStr ${{ROOT}} "${{KEY}}" "${{NAME}}" ${{VALUE}}
!macroend

!macro RESTORE_REG_DWORD ROOT KEY NAME VALUE PRESENT
  DeleteRegValue ${{ROOT}} "${{KEY}}" "${{NAME}}"
  StrCmp ${{PRESENT}} "1" 0 +2
  WriteRegDWORD ${{ROOT}} "${{KEY}}" "${{NAME}}" ${{VALUE}}
!macroend

Function SnapshotRegistration
  SetRegView 32
  Call LegacyKeyExists
  StrCpy $LegacyKeyPresent $TxActual
  !insertmacro SNAPSHOT_REG_STR HKCU "Software\\Heroes Like" "OwnershipSha256" $LegacyOwnershipSha $LegacyOwnershipShaPresent
  !insertmacro SNAPSHOT_REG_STR HKCU "Software\\Heroes Like" "OwnershipSize" $LegacyOwnershipSize $LegacyOwnershipSizePresent
  SetRegView 64
  Call ArpKeyExists
  StrCpy $ArpKeyPresent $TxActual
  !insertmacro SNAPSHOT_REG_STR HKCU "{arp_key}" "DisplayName" $ArpDisplayName $ArpDisplayNamePresent
  !insertmacro SNAPSHOT_REG_STR HKCU "{arp_key}" "DisplayVersion" $ArpDisplayVersion $ArpDisplayVersionPresent
  !insertmacro SNAPSHOT_REG_STR HKCU "{arp_key}" "Publisher" $ArpPublisher $ArpPublisherPresent
  !insertmacro SNAPSHOT_REG_STR HKCU "{arp_key}" "InstallLocation" $ArpInstallLocation $ArpInstallLocationPresent
  !insertmacro SNAPSHOT_REG_STR HKCU "{arp_key}" "DisplayIcon" $ArpDisplayIcon $ArpDisplayIconPresent
  !insertmacro SNAPSHOT_REG_STR HKCU "{arp_key}" "UninstallString" $ArpUninstallString $ArpUninstallStringPresent
  !insertmacro SNAPSHOT_REG_STR HKCU "{arp_key}" "QuietUninstallString" $ArpQuietUninstallString $ArpQuietUninstallStringPresent
  !insertmacro SNAPSHOT_REG_DWORD HKCU "{arp_key}" "NoModify" $ArpNoModify $ArpNoModifyPresent
  !insertmacro SNAPSHOT_REG_DWORD HKCU "{arp_key}" "NoRepair" $ArpNoRepair $ArpNoRepairPresent
  SetRegView 32
FunctionEnd

Function RestoreRegistration
  SetRegView 32
  !insertmacro RESTORE_REG_STR HKCU "Software\\Heroes Like" "OwnershipSha256" $LegacyOwnershipSha $LegacyOwnershipShaPresent
  !insertmacro RESTORE_REG_STR HKCU "Software\\Heroes Like" "OwnershipSize" $LegacyOwnershipSize $LegacyOwnershipSizePresent
  StrCmp $LegacyKeyPresent "1" +2
  DeleteRegKey HKCU "Software\\Heroes Like"
  SetRegView 64
  StrCmp $ArpKeyPresent "1" restore_arp_values
  DeleteRegKey HKCU "{arp_key}"
  Goto restore_registration_done
restore_arp_values:
  !insertmacro RESTORE_REG_STR HKCU "{arp_key}" "DisplayName" $ArpDisplayName $ArpDisplayNamePresent
  !insertmacro RESTORE_REG_STR HKCU "{arp_key}" "DisplayVersion" $ArpDisplayVersion $ArpDisplayVersionPresent
  !insertmacro RESTORE_REG_STR HKCU "{arp_key}" "Publisher" $ArpPublisher $ArpPublisherPresent
  !insertmacro RESTORE_REG_STR HKCU "{arp_key}" "InstallLocation" $ArpInstallLocation $ArpInstallLocationPresent
  !insertmacro RESTORE_REG_STR HKCU "{arp_key}" "DisplayIcon" $ArpDisplayIcon $ArpDisplayIconPresent
  !insertmacro RESTORE_REG_STR HKCU "{arp_key}" "UninstallString" $ArpUninstallString $ArpUninstallStringPresent
  !insertmacro RESTORE_REG_STR HKCU "{arp_key}" "QuietUninstallString" $ArpQuietUninstallString $ArpQuietUninstallStringPresent
  !insertmacro RESTORE_REG_DWORD HKCU "{arp_key}" "NoModify" $ArpNoModify $ArpNoModifyPresent
  !insertmacro RESTORE_REG_DWORD HKCU "{arp_key}" "NoRepair" $ArpNoRepair $ArpNoRepairPresent
restore_registration_done:
  SetRegView 32
FunctionEnd

Function SnapshotShortcuts
  StrCpy $RegistrationResult "ok"
  StrCpy $LegacyGameShortcutPresent "0"
  StrCpy $LegacyUninstallShortcutPresent "0"
  StrCpy $PublicGameShortcutPresent "0"
  StrCpy $PublicUninstallShortcutPresent "0"
  CreateDirectory "$PLUGINSDIR\\shortcut-backup\\legacy"
  CreateDirectory "$PLUGINSDIR\\shortcut-backup\\public"
  IfFileExists "$SMPROGRAMS\\{WINDOWS_TECHNICAL_NAME}\\{WINDOWS_LEGACY_GAME_SHORTCUT}" 0 snapshot_legacy_uninstall_shortcut
  CopyFiles /SILENT "$SMPROGRAMS\\{WINDOWS_TECHNICAL_NAME}\\{WINDOWS_LEGACY_GAME_SHORTCUT}" "$PLUGINSDIR\\shortcut-backup\\legacy"
  IfFileExists "$PLUGINSDIR\\shortcut-backup\\legacy\\{WINDOWS_LEGACY_GAME_SHORTCUT}" 0 snapshot_shortcuts_failed
  StrCpy $LegacyGameShortcutPresent "1"
snapshot_legacy_uninstall_shortcut:
  IfFileExists "$SMPROGRAMS\\{WINDOWS_TECHNICAL_NAME}\\{WINDOWS_LEGACY_UNINSTALL_SHORTCUT}" 0 snapshot_public_game_shortcut
  CopyFiles /SILENT "$SMPROGRAMS\\{WINDOWS_TECHNICAL_NAME}\\{WINDOWS_LEGACY_UNINSTALL_SHORTCUT}" "$PLUGINSDIR\\shortcut-backup\\legacy"
  IfFileExists "$PLUGINSDIR\\shortcut-backup\\legacy\\{WINDOWS_LEGACY_UNINSTALL_SHORTCUT}" 0 snapshot_shortcuts_failed
  StrCpy $LegacyUninstallShortcutPresent "1"
snapshot_public_game_shortcut:
  IfFileExists "$SMPROGRAMS\\{WINDOWS_PRODUCT_NAME}\\{WINDOWS_PUBLIC_GAME_SHORTCUT}" 0 snapshot_public_uninstall_shortcut
  CopyFiles /SILENT "$SMPROGRAMS\\{WINDOWS_PRODUCT_NAME}\\{WINDOWS_PUBLIC_GAME_SHORTCUT}" "$PLUGINSDIR\\shortcut-backup\\public"
  IfFileExists "$PLUGINSDIR\\shortcut-backup\\public\\{WINDOWS_PUBLIC_GAME_SHORTCUT}" 0 snapshot_shortcuts_failed
  StrCpy $PublicGameShortcutPresent "1"
snapshot_public_uninstall_shortcut:
  IfFileExists "$SMPROGRAMS\\{WINDOWS_PRODUCT_NAME}\\{WINDOWS_PUBLIC_UNINSTALL_SHORTCUT}" 0 snapshot_shortcuts_done
  CopyFiles /SILENT "$SMPROGRAMS\\{WINDOWS_PRODUCT_NAME}\\{WINDOWS_PUBLIC_UNINSTALL_SHORTCUT}" "$PLUGINSDIR\\shortcut-backup\\public"
  IfFileExists "$PLUGINSDIR\\shortcut-backup\\public\\{WINDOWS_PUBLIC_UNINSTALL_SHORTCUT}" 0 snapshot_shortcuts_failed
  StrCpy $PublicUninstallShortcutPresent "1"
  Goto snapshot_shortcuts_done
snapshot_shortcuts_failed:
  StrCpy $RegistrationResult "failed"
snapshot_shortcuts_done:
FunctionEnd

Function RestoreShortcuts
  Delete "$SMPROGRAMS\\{WINDOWS_PRODUCT_NAME}\\{WINDOWS_PUBLIC_GAME_SHORTCUT}"
  Delete "$SMPROGRAMS\\{WINDOWS_PRODUCT_NAME}\\{WINDOWS_PUBLIC_UNINSTALL_SHORTCUT}"
  Delete "$SMPROGRAMS\\{WINDOWS_TECHNICAL_NAME}\\{WINDOWS_LEGACY_GAME_SHORTCUT}"
  Delete "$SMPROGRAMS\\{WINDOWS_TECHNICAL_NAME}\\{WINDOWS_LEGACY_UNINSTALL_SHORTCUT}"
  RMDir "$SMPROGRAMS\\{WINDOWS_PRODUCT_NAME}"
  RMDir "$SMPROGRAMS\\{WINDOWS_TECHNICAL_NAME}"
  StrCmp $LegacyGameShortcutPresent "1" 0 +3
  CreateDirectory "$SMPROGRAMS\\{WINDOWS_TECHNICAL_NAME}"
  CopyFiles /SILENT "$PLUGINSDIR\\shortcut-backup\\legacy\\{WINDOWS_LEGACY_GAME_SHORTCUT}" "$SMPROGRAMS\\{WINDOWS_TECHNICAL_NAME}"
  StrCmp $LegacyUninstallShortcutPresent "1" 0 +3
  CreateDirectory "$SMPROGRAMS\\{WINDOWS_TECHNICAL_NAME}"
  CopyFiles /SILENT "$PLUGINSDIR\\shortcut-backup\\legacy\\{WINDOWS_LEGACY_UNINSTALL_SHORTCUT}" "$SMPROGRAMS\\{WINDOWS_TECHNICAL_NAME}"
  StrCmp $PublicGameShortcutPresent "1" 0 +3
  CreateDirectory "$SMPROGRAMS\\{WINDOWS_PRODUCT_NAME}"
  CopyFiles /SILENT "$PLUGINSDIR\\shortcut-backup\\public\\{WINDOWS_PUBLIC_GAME_SHORTCUT}" "$SMPROGRAMS\\{WINDOWS_PRODUCT_NAME}"
  StrCmp $PublicUninstallShortcutPresent "1" 0 +3
  CreateDirectory "$SMPROGRAMS\\{WINDOWS_PRODUCT_NAME}"
  CopyFiles /SILENT "$PLUGINSDIR\\shortcut-backup\\public\\{WINDOWS_PUBLIC_UNINSTALL_SHORTCUT}" "$SMPROGRAMS\\{WINDOWS_PRODUCT_NAME}"
  RMDir /r "$PLUGINSDIR\\shortcut-backup"
FunctionEnd

Function DiscardShortcutBackup
  RMDir /r "$PLUGINSDIR\\shortcut-backup"
FunctionEnd

Function PublishRegistration
  StrCpy $RegistrationResult "failed"
  SetRegView 32
  ClearErrors
  WriteRegStr HKCU "Software\\Heroes Like" "OwnershipSha256" "{ownership_sha256}"
  WriteRegStr HKCU "Software\\Heroes Like" "OwnershipSize" "{ownership_size}"
  IfErrors publish_registration_done
  ReadRegStr $TxOutput HKCU "Software\\Heroes Like" "OwnershipSha256"
  StrCmp $TxOutput "{ownership_sha256}" 0 publish_registration_done
  ReadRegStr $TxOutput HKCU "Software\\Heroes Like" "OwnershipSize"
  StrCmp $TxOutput "{ownership_size}" 0 publish_registration_done
  SetRegView 64
  ClearErrors
  WriteRegStr HKCU "{arp_key}" "DisplayName" "{WINDOWS_PRODUCT_NAME}"
  WriteRegStr HKCU "{arp_key}" "DisplayVersion" "{nsis_string(version)}"
  WriteRegStr HKCU "{arp_key}" "Publisher" "{WINDOWS_PUBLISHER}"
  WriteRegStr HKCU "{arp_key}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "{arp_key}" "DisplayIcon" '"$INSTDIR\\heroes-like.exe",0'
  WriteRegStr HKCU "{arp_key}" "UninstallString" '"$INSTDIR\\uninstall.exe"'
  WriteRegStr HKCU "{arp_key}" "QuietUninstallString" '"$INSTDIR\\uninstall.exe" /S'
  WriteRegDWORD HKCU "{arp_key}" "NoModify" 1
  WriteRegDWORD HKCU "{arp_key}" "NoRepair" 1
  IfErrors publish_registration_done
  ReadRegStr $TxOutput HKCU "{arp_key}" "DisplayName"
  StrCmp $TxOutput "{WINDOWS_PRODUCT_NAME}" 0 publish_registration_done
  ReadRegStr $TxOutput HKCU "{arp_key}" "DisplayVersion"
  StrCmp $TxOutput "{nsis_string(version)}" 0 publish_registration_done
  ReadRegStr $TxOutput HKCU "{arp_key}" "Publisher"
  StrCmp $TxOutput "{WINDOWS_PUBLISHER}" 0 publish_registration_done
  ReadRegStr $TxOutput HKCU "{arp_key}" "InstallLocation"
  StrCmp $TxOutput "$INSTDIR" 0 publish_registration_done
  ReadRegStr $TxOutput HKCU "{arp_key}" "DisplayIcon"
  StrCmp $TxOutput '"$INSTDIR\\heroes-like.exe",0' 0 publish_registration_done
  ReadRegStr $TxOutput HKCU "{arp_key}" "UninstallString"
  StrCmp $TxOutput '"$INSTDIR\\uninstall.exe"' 0 publish_registration_done
  ReadRegStr $TxOutput HKCU "{arp_key}" "QuietUninstallString"
  StrCmp $TxOutput '"$INSTDIR\\uninstall.exe" /S' 0 publish_registration_done
  ReadRegDWORD $TxOutput HKCU "{arp_key}" "NoModify"
  IntCmp $TxOutput 1 +2 0 0
  Goto publish_registration_done
  ReadRegDWORD $TxOutput HKCU "{arp_key}" "NoRepair"
  IntCmp $TxOutput 1 +2 0 0
  Goto publish_registration_done
  StrCpy $RegistrationResult "ok"
publish_registration_done:
  SetRegView 32
FunctionEnd

Function LegacyKeyExists
  StrCpy $TxActual "0"
  StrCpy $TxIndex 0
legacy_key_exists_loop:
  IntCmp $TxIndex 4096 legacy_key_exists_done legacy_key_exists_query legacy_key_exists_done
legacy_key_exists_query:
  ClearErrors
  EnumRegKey $TxName HKCU "Software" $TxIndex
  IfErrors legacy_key_exists_done
  StrCmp $TxName "" legacy_key_exists_done
  StrCmp $TxName "Heroes Like" legacy_key_exists_found
  IntOp $TxIndex $TxIndex + 1
  Goto legacy_key_exists_loop
legacy_key_exists_found:
  StrCpy $TxActual "1"
legacy_key_exists_done:
FunctionEnd

Function VerifyCommittedRoot
  StrCpy $TxActual "invalid"
  StrCpy $TxPath "$INSTDIR\\.heroes-like-install"
  Call VerifyMarker
  StrCmp $TxActual "ok" 0 verify_committed_root_invalid
  IfFileExists "$INSTDIR\\release-manifest.json" +2
  Goto verify_committed_root_invalid
  IfFileExists "$1\\*.*" verify_committed_root_invalid
  StrCpy $TxActual "ok"
  Goto verify_committed_root_done
verify_committed_root_invalid:
  StrCpy $TxActual "invalid"
verify_committed_root_done:
FunctionEnd

Function VerifyFileIdentity
  StrCpy $TxActual "invalid"
  IfFileExists "$TxPath" 0 verify_file_done
  ClearErrors
  FileOpen $TxHandle "$TxPath" r
  IfErrors verify_file_done
  FileSeek $TxHandle 0 END $TxOutput
  FileClose $TxHandle
  StrCmp $TxOutput $TxSize 0 verify_file_done
  nsExec::ExecToStack '"$PLUGINSDIR\\payload\\{WINDOWS_INSTALLER_HELPER_NAME}" sha256 "$TxPath"'
  Pop $TxOutput
  Pop $TxActual
  StrCmp $TxOutput "0" 0 verify_file_invalid
  StrCpy $TxActual $TxActual 64
  StrCmp $TxActual $TxHash 0 verify_file_invalid
  StrCpy $TxActual "ok"
  Goto verify_file_done
verify_file_invalid:
  StrCpy $TxActual "invalid"
verify_file_done:
FunctionEnd

Function VerifyMarker
  StrCpy $TxActual "invalid"
  ClearErrors
  FileOpen $TxHandle "$TxPath" r
  IfErrors verify_marker_done
  FileRead $TxHandle $TxOutput
  FileClose $TxHandle
  StrCmp $TxOutput "heroes-like-user-local-install-v1$\\r$\\n" marker_ok
  StrCmp $TxOutput "heroes-like-user-local-install-v1$\\n" marker_ok
  Goto verify_marker_done
marker_ok:
  StrCpy $TxActual "ok"
verify_marker_done:
FunctionEnd

Function VerifyOwnedRoot
  StrCpy $TxActual "invalid"
  StrCpy $TxPath "$INSTDIR\\.heroes-like-install"
  Call VerifyMarker
  StrCmp $TxActual "ok" 0 verify_owned_invalid
  StrCpy $TxActual "invalid"
  ReadINIStr $TxOutput "$INSTDIR\\install-ownership.ini" "Ownership" "Schema"
  StrCmp $TxOutput "heroes-like-windows-install-ownership-v1" 0 verify_owned_invalid
  ReadINIStr $TxOutput "$INSTDIR\\install-ownership.ini" "Ownership" "Product"
  StrCmp $TxOutput "heroes-like" 0 verify_owned_invalid
  ReadINIStr $TxOutput "$INSTDIR\\install-ownership.ini" "Ownership" "Platform"
  StrCmp $TxOutput "windows-x86_64" 0 verify_owned_invalid
  ReadINIStr $TxCount "$INSTDIR\\install-ownership.ini" "Ownership" "FileCount"
  IntCmp $TxCount 0 verify_owned_invalid verify_owned_invalid verify_owned_count_upper
verify_owned_count_upper:
  IntCmp $TxCount 64 verify_owned_rows verify_owned_rows verify_owned_invalid
verify_owned_rows:
  StrCpy $TxIndex 0
verify_owned_loop:
  IntCmp $TxIndex $TxCount verify_owned_entries verify_owned_row verify_owned_entries
verify_owned_row:
  StrCpy $TxActual "invalid"
  ReadINIStr $TxName "$INSTDIR\\install-ownership.ini" "File$TxIndex" "Path"
  ReadINIStr $TxSize "$INSTDIR\\install-ownership.ini" "File$TxIndex" "Size"
  ReadINIStr $TxHash "$INSTDIR\\install-ownership.ini" "File$TxIndex" "Sha256"
  StrCmp $TxName "" verify_owned_invalid
  StrCpy $TxPath "$INSTDIR\\$TxName"
  Call VerifyFileIdentity
  StrCmp $TxActual "ok" 0 verify_owned_invalid
  IntOp $TxIndex $TxIndex + 1
  Goto verify_owned_loop
verify_owned_entries:
  ; Entry enumeration is a new proof phase. Never carry a prior file's "ok"
  ; result into an unexpected directory or exact-count failure.
  StrCpy $TxActual "invalid"
  IntOp $TxCount $TxCount + 3
  StrCpy $TxIndex 0
  FindFirst $TxFind $TxName "$INSTDIR\\*.*"
verify_owned_entry_loop:
  StrCmp $TxName "" verify_owned_entry_count
  StrCmp $TxName "." verify_owned_entry_next
  StrCmp $TxName ".." verify_owned_entry_next
  IfFileExists "$INSTDIR\\$TxName\\*.*" verify_owned_invalid
  IntOp $TxIndex $TxIndex + 1
verify_owned_entry_next:
  FindNext $TxFind $TxName
  Goto verify_owned_entry_loop
verify_owned_entry_count:
  FindClose $TxFind
  IntCmp $TxIndex $TxCount verify_owned_exact verify_owned_invalid verify_owned_invalid
verify_owned_exact:
  nsExec::ExecToStack '"$PLUGINSDIR\\payload\\{WINDOWS_INSTALLER_HELPER_NAME}" verify "$INSTDIR\\release-manifest.json" "$INSTDIR" windows-x86_64 release-manifest.json .heroes-like-install install-ownership.ini uninstall.exe'
  Pop $TxOutput
  Pop $TxActual
  StrCmp $TxOutput "0" 0 verify_owned_invalid
  StrCpy $TxActual "ok"
  Goto verify_owned_done
verify_owned_invalid:
  StrCpy $TxActual "invalid"
verify_owned_done:
FunctionEnd

Function ArpKeyExists
  StrCpy $TxActual "0"
  StrCpy $TxIndex 0
arp_key_exists_loop:
  IntCmp $TxIndex 4096 arp_key_exists_done arp_key_exists_query arp_key_exists_done
arp_key_exists_query:
  ClearErrors
  EnumRegKey $TxName HKCU "{arp_parent}" $TxIndex
  IfErrors arp_key_exists_done
  StrCmp $TxName "" arp_key_exists_done
  StrCmp $TxName "Heroes Like" arp_key_exists_found
  IntOp $TxIndex $TxIndex + 1
  Goto arp_key_exists_loop
arp_key_exists_found:
  StrCpy $TxActual "1"
arp_key_exists_done:
FunctionEnd

Section "Install"
  InitPluginsDir
  SetRegView 32
  SetOutPath "$PLUGINSDIR\\payload"
  ClearErrors
  File /oname={WINDOWS_INSTALLER_HELPER_NAME} "{nsis_string(str(bundle_root / WINDOWS_INSTALLER_HELPER_NAME))}"
  IfErrors staged_verification_failed
  !insertmacro VERIFY_FILE "$PLUGINSDIR\\payload" "{WINDOWS_INSTALLER_HELPER_NAME}" "{helper_row["size_bytes"]}" "{helper_row["sha256"]}" staged_verification_failed

  IfFileExists "$INSTDIR\\*.*" prior_live_root
  IfFileExists "$INSTDIR.backup\\*.*" recovery_backup_refused
  IfFileExists "$INSTDIR.backup" recovery_backup_refused
  Goto prior_verified
prior_live_root:
  ; Legacy v1 roots are accepted only after dynamic bounded manifest/hash/exact-root verification.
  IfFileExists "$INSTDIR\\install-ownership.ini" 0 legacy_prior
  ReadRegStr $TxHash HKCU "Software\\Heroes Like" "OwnershipSha256"
  ReadRegStr $TxSize HKCU "Software\\Heroes Like" "OwnershipSize"
  StrCpy $TxPath "$INSTDIR\\install-ownership.ini"
  Call VerifyFileIdentity
  StrCmp $TxActual "ok" 0 ownership_refused
  Call VerifyOwnedRoot
  StrCmp $TxActual "ok" 0 ownership_refused
  Goto prior_verified
legacy_prior:
  StrCpy $TxPath "$INSTDIR\\.heroes-like-install"
  Call VerifyMarker
  StrCmp $TxActual "ok" 0 ownership_refused
  nsExec::ExecToStack '"$PLUGINSDIR\\payload\\{WINDOWS_INSTALLER_HELPER_NAME}" verify "$INSTDIR\\release-manifest.json" "$INSTDIR" windows-x86_64 .heroes-like-install release-manifest.json'
  Pop $TxOutput
  Pop $TxActual
  StrCmp $TxOutput "0" 0 ownership_refused
prior_verified:
  Call SnapshotRegistration
  Call SnapshotShortcuts
  StrCmp $RegistrationResult "ok" 0 staged_verification_failed
  StrCpy $1 "$INSTDIR.commit"
  StrCpy $2 "$INSTDIR.backup"
  RMDir /r "$1"
  RMDir /r "$INSTDIR.backup"
  CreateDirectory "$1"
  SetOutPath "$1"
  ClearErrors
{file_rows}
  File /oname=install-ownership.ini "{nsis_string(str(ownership_path))}"
  IfErrors commit_candidate_metadata_failed
  ClearErrors
  FileOpen $TxHandle "$1\\.heroes-like-install" w
  IfErrors commit_candidate_metadata_failed
  FileWrite $TxHandle "heroes-like-user-local-install-v1$\\r$\\n"
  FileClose $TxHandle
  WriteUninstaller "$1\\uninstall.exe"
  IfErrors commit_candidate_metadata_failed
  !insertmacro VERIFY_FILE "$1" "install-ownership.ini" "{ownership_size}" "{ownership_sha256}" commit_candidate_metadata_failed
  StrCpy $TxPath "$1\\.heroes-like-install"
  Call VerifyMarker
  StrCmp $TxActual "ok" 0 commit_candidate_metadata_failed
  IfFileExists "$1\\uninstall.exe" +2
  Goto commit_candidate_metadata_failed
  ; This is the one authoritative full-payload hash and exact-membership pass.
  ; A same-volume atomic rename publishes these verified bytes unchanged.
  nsExec::ExecToStack '"$PLUGINSDIR\\payload\\{WINDOWS_INSTALLER_HELPER_NAME}" verify "$1\\release-manifest.json" "$1" windows-x86_64 release-manifest.json .heroes-like-install install-ownership.ini uninstall.exe'
  Pop $TxOutput
  Pop $TxActual
  StrCmp $TxOutput "0" +2
  Goto commit_candidate_metadata_failed
  SetOutPath "$TEMP"
  ReadEnvStr $3 "HEROES_LIKE_INSTALL_FAIL_PHASE"
  StrCmp $3 "" failure_phase_ok
  StrCmp $3 "precommit" injected_precommit
  StrCmp $3 "after_backup" failure_phase_ok
  Goto commit_failed
failure_phase_ok:
  IfFileExists "$INSTDIR\\*.*" 0 no_backup
  ClearErrors
  Rename "$INSTDIR" "$2"
  IfErrors backup_rename_failed
  StrCmp $3 "after_backup" injected_after_backup
no_backup:
  RMDir "$INSTDIR"
  ClearErrors
  Rename "$1" "$INSTDIR"
  IfErrors commit_rename_failed
  Call VerifyCommittedRoot
  StrCmp $TxActual "ok" 0 registration_publish_failed
  ; User data is external to this manifest-owned root. Publish shortcuts and
  ; registration only while the prior exact root is still rollback-capable.
  CreateDirectory "$SMPROGRAMS\\{WINDOWS_PRODUCT_NAME}"
  ClearErrors
  CreateShortcut "$SMPROGRAMS\\{WINDOWS_PRODUCT_NAME}\\{WINDOWS_PUBLIC_GAME_SHORTCUT}" "$INSTDIR\\heroes-like.exe"
  IfErrors registration_publish_failed
  ClearErrors
  CreateShortcut "$SMPROGRAMS\\{WINDOWS_PRODUCT_NAME}\\{WINDOWS_PUBLIC_UNINSTALL_SHORTCUT}" "$INSTDIR\\uninstall.exe"
  IfErrors registration_publish_failed
  Call PublishRegistration
  StrCmp $RegistrationResult "ok" 0 registration_publish_failed
  IfFileExists "$SMPROGRAMS\\{WINDOWS_TECHNICAL_NAME}\\{WINDOWS_LEGACY_GAME_SHORTCUT}" 0 legacy_game_shortcut_removed
  ClearErrors
  Delete "$SMPROGRAMS\\{WINDOWS_TECHNICAL_NAME}\\{WINDOWS_LEGACY_GAME_SHORTCUT}"
  IfErrors registration_publish_failed
legacy_game_shortcut_removed:
  IfFileExists "$SMPROGRAMS\\{WINDOWS_TECHNICAL_NAME}\\{WINDOWS_LEGACY_UNINSTALL_SHORTCUT}" 0 legacy_uninstall_shortcut_removed
  ClearErrors
  Delete "$SMPROGRAMS\\{WINDOWS_TECHNICAL_NAME}\\{WINDOWS_LEGACY_UNINSTALL_SHORTCUT}"
  IfErrors registration_publish_failed
legacy_uninstall_shortcut_removed:
  RMDir "$SMPROGRAMS\\{WINDOWS_TECHNICAL_NAME}"
  RMDir /r "$2"
  Call DiscardShortcutBackup
  Goto install_done
injected_precommit:
  DetailPrint "Injected precommit failure; live root was not mutated."
  Goto commit_failed
injected_after_backup:
  DetailPrint "Injected after_backup failure; restoring prior exact program root."
  RMDir /r "$INSTDIR"
  IfFileExists "$2\\*.*" 0 commit_failed
  ClearErrors
  Rename "$2" "$INSTDIR"
  IfErrors rollback_restore_failed
  IfFileExists "$INSTDIR\\*.*" +2
  Goto rollback_restore_failed
  Goto commit_failed
commit_candidate_metadata_failed:
  SetOutPath "$TEMP"
  RMDir /r "$1"
  SetErrorLevel 39
  Quit
backup_rename_failed:
  RMDir /r "$1"
  SetErrorLevel 25
  Quit
commit_rename_failed:
  RMDir /r "$INSTDIR"
  IfFileExists "$2\\*.*" 0 commit_rename_failed_done
  ClearErrors
  Rename "$2" "$INSTDIR"
  IfErrors rollback_restore_failed
  IfFileExists "$INSTDIR\\*.*" +2
  Goto rollback_restore_failed
commit_rename_failed_done:
  RMDir /r "$1"
  SetErrorLevel 26
  Quit
registration_publish_failed:
  DetailPrint "Install publication failed; restoring prior exact program root and registration."
  ClearErrors
  RMDir /r "$INSTDIR"
  IfErrors registration_rollback_failed
  IfFileExists "$INSTDIR\\*.*" registration_rollback_failed
  IfFileExists "$INSTDIR" registration_rollback_failed
  IfFileExists "$2\\*.*" 0 registration_restore_no_backup
  ClearErrors
  Rename "$2" "$INSTDIR"
  IfErrors registration_rollback_failed
  IfFileExists "$INSTDIR\\*.*" +2
  Goto registration_rollback_failed
registration_restore_no_backup:
  Call RestoreShortcuts
  Call RestoreRegistration
  RMDir /r "$1"
  SetErrorLevel 27
  Quit
registration_rollback_failed:
  DetailPrint "Install publication failed and the prior program root could not be restored; recovery artifacts were preserved."
  SetErrorLevel 28
  Quit
rollback_restore_failed:
  DetailPrint "Install rollback could not restore the prior program root; the recovery backup was preserved."
  RMDir /r "$1"
  SetErrorLevel 29
  Quit
commit_failed:
  RMDir /r "$1"
  SetErrorLevel 22
  Quit
staged_verification_failed:
  DetailPrint "Staged payload hash or size verification failed before live mutation."
  SetErrorLevel 20
  Quit
ownership_refused:
  DetailPrint "Existing nonempty root lacks valid owned manifest state."
  SetErrorLevel 21
  Quit
recovery_backup_refused:
  DetailPrint "Install refused because a prior recovery backup exists without a live program root; the backup was preserved."
  SetErrorLevel 30
  Quit
install_done:
SectionEnd

Section "Uninstall"
  InitPluginsDir
  SetRegView 32
  SetOutPath "$PLUGINSDIR\\payload"
  File /oname={WINDOWS_INSTALLER_HELPER_NAME} "{nsis_string(str(bundle_root / WINDOWS_INSTALLER_HELPER_NAME))}"
  StrCpy $TxPath "$INSTDIR\\.heroes-like-install"
  Call VerifyMarker
  StrCmp $TxActual "ok" 0 uninstall_refused
  ReadRegStr $TxHash HKCU "Software\\Heroes Like" "OwnershipSha256"
  ReadRegStr $TxSize HKCU "Software\\Heroes Like" "OwnershipSize"
  StrCpy $TxPath "$INSTDIR\\install-ownership.ini"
  Call VerifyFileIdentity
  StrCmp $TxActual "ok" 0 uninstall_refused
  Call VerifyOwnedRoot
  StrCmp $TxActual "ok" 0 uninstall_refused
  ReadINIStr $TxCount "$INSTDIR\\install-ownership.ini" "Ownership" "FileCount"
  StrCpy $TxIndex 0
uninstall_owned_loop:
  IntCmp $TxIndex $TxCount uninstall_owned_done uninstall_owned_row uninstall_owned_done
uninstall_owned_row:
  ReadINIStr $TxName "$INSTDIR\\install-ownership.ini" "File$TxIndex" "Path"
  Delete "$INSTDIR\\$TxName"
  IntOp $TxIndex $TxIndex + 1
  Goto uninstall_owned_loop
uninstall_owned_done:
  Delete "$INSTDIR\\install-ownership.ini"
  Delete "$INSTDIR\\.heroes-like-install"
  IfFileExists "$SMPROGRAMS\\{WINDOWS_PRODUCT_NAME}\\{WINDOWS_PUBLIC_GAME_SHORTCUT}" 0 uninstall_game_shortcut_done
  ClearErrors
  Delete "$SMPROGRAMS\\{WINDOWS_PRODUCT_NAME}\\{WINDOWS_PUBLIC_GAME_SHORTCUT}"
  IfErrors uninstall_remove_failed
uninstall_game_shortcut_done:
  IfFileExists "$SMPROGRAMS\\{WINDOWS_PRODUCT_NAME}\\{WINDOWS_PUBLIC_UNINSTALL_SHORTCUT}" 0 uninstall_shortcut_done
  ClearErrors
  Delete "$SMPROGRAMS\\{WINDOWS_PRODUCT_NAME}\\{WINDOWS_PUBLIC_UNINSTALL_SHORTCUT}"
  IfErrors uninstall_remove_failed
uninstall_shortcut_done:
  IfFileExists "$SMPROGRAMS\\{WINDOWS_PRODUCT_NAME}\\{WINDOWS_PUBLIC_GAME_SHORTCUT}" uninstall_remove_failed
  IfFileExists "$SMPROGRAMS\\{WINDOWS_PRODUCT_NAME}\\{WINDOWS_PUBLIC_UNINSTALL_SHORTCUT}" uninstall_remove_failed
  IfFileExists "$SMPROGRAMS\\{WINDOWS_TECHNICAL_NAME}\\{WINDOWS_LEGACY_GAME_SHORTCUT}" 0 uninstall_legacy_game_shortcut_done
  ClearErrors
  Delete "$SMPROGRAMS\\{WINDOWS_TECHNICAL_NAME}\\{WINDOWS_LEGACY_GAME_SHORTCUT}"
  IfErrors uninstall_remove_failed
uninstall_legacy_game_shortcut_done:
  IfFileExists "$SMPROGRAMS\\{WINDOWS_TECHNICAL_NAME}\\{WINDOWS_LEGACY_UNINSTALL_SHORTCUT}" 0 uninstall_legacy_shortcut_done
  ClearErrors
  Delete "$SMPROGRAMS\\{WINDOWS_TECHNICAL_NAME}\\{WINDOWS_LEGACY_UNINSTALL_SHORTCUT}"
  IfErrors uninstall_remove_failed
uninstall_legacy_shortcut_done:
  RMDir "$SMPROGRAMS\\{WINDOWS_PRODUCT_NAME}"
  RMDir "$SMPROGRAMS\\{WINDOWS_TECHNICAL_NAME}"
  SetOutPath "$TEMP"
  Delete "$INSTDIR\\uninstall.exe"
  ClearErrors
  RMDir "$INSTDIR"
  IfErrors uninstall_remove_failed
  IfFileExists "$INSTDIR\\*.*" uninstall_remove_failed
  IfFileExists "$INSTDIR" uninstall_remove_failed
  SetRegView 64
  ClearErrors
  DeleteRegKey HKCU "{arp_key}"
  IfErrors uninstall_remove_failed_64
  Call un.ArpKeyExists
  StrCmp $TxActual "0" +2
  Goto uninstall_remove_failed_64
  SetRegView 32
  ClearErrors
  DeleteRegKey HKCU "Software\\Heroes Like"
  IfErrors uninstall_remove_failed
  Goto uninstall_done
uninstall_remove_failed_64:
  SetRegView 32
  Goto uninstall_remove_failed
uninstall_remove_failed:
  DetailPrint "Uninstall could not fully remove the verified owned install files or registration."
  SetErrorLevel 24
  Quit
uninstall_refused:
  DetailPrint "Uninstall refused invalid or unexpected unowned install entries."
  SetErrorLevel 23
  Quit
uninstall_done:
SectionEnd
"""
    function_start = script.index("Function VerifyFileIdentity")
    install_section = script.index('Section "Install"')
    uninstall_functions = script[function_start:install_section]
    for function_name in ("VerifyFileIdentity", "VerifyMarker", "VerifyOwnedRoot", "ArpKeyExists"):
        uninstall_functions = uninstall_functions.replace(
            f"Function {function_name}", f"Function un.{function_name}"
        ).replace(f"Call {function_name}", f"Call un.{function_name}")
    script = script[:install_section] + uninstall_functions + script[install_section:]
    uninstall_section = script.index('Section "Uninstall"')
    uninstall_head = script[:uninstall_section]
    uninstall_tail = script[uninstall_section:]
    for function_name in ("VerifyFileIdentity", "VerifyMarker", "VerifyOwnedRoot", "ArpKeyExists"):
        uninstall_tail = uninstall_tail.replace(f"Call {function_name}", f"Call un.{function_name}")
    script = uninstall_head + uninstall_tail
    script_path.write_text(script, encoding="utf-8", newline="\n")
    run([makensis, "-V2", str(script_path)])
    if not destination.is_file() or destination.stat().st_size <= 0:
        raise RuntimeError("makensis did not produce the Windows setup executable")


def create_runnable_installer(
    spec: PlatformSpec,
    archive_path: Path,
    bundle_root: Path,
    destination: Path,
    version: str,
    makensis: str,
    platform_manifest: dict,
) -> None:
    if spec.platform_id.startswith("linux"):
        create_linux_runnable_installer(archive_path, destination, bundle_root.name)
        return
    create_windows_nsis_installer(bundle_root, destination, version, makensis, platform_manifest)


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


def verified_manifest_rows(
    manifest: dict,
    spec: PlatformSpec,
    version: str,
    source_revision: str,
    epoch: int,
) -> dict[str, dict]:
    if manifest.get("schema_id") != PLATFORM_MANIFEST_SCHEMA_ID:
        raise RuntimeError(f"invalid platform manifest schema for {spec.platform_id}")
    if manifest.get("product_id") != PRODUCT_ID or manifest.get("version") != version:
        raise RuntimeError(f"platform manifest product/version mismatch for {spec.platform_id}")
    if manifest.get("platform") != spec.platform_id:
        raise RuntimeError(f"platform manifest target mismatch for {spec.platform_id}")
    if manifest.get("source_revision") != source_revision:
        raise RuntimeError(f"platform manifest source revision mismatch for {spec.platform_id}")
    if manifest.get("source_date_epoch") != epoch:
        raise RuntimeError(f"platform manifest source-date epoch mismatch for {spec.platform_id}")
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
    expected = set(spec.staged_names)
    if set(rows) != expected:
        raise RuntimeError(f"platform manifest payload differs from required files for {spec.platform_id}: {sorted(rows)}")
    return rows


def verify_platform_archive(
    spec: PlatformSpec,
    archive_path: Path,
    version: str,
    source_revision: str,
    epoch: int,
    indexed_manifest: dict,
) -> dict:
    bundle_root = f"{PRODUCT_ID}-{version}-{spec.platform_id}"
    archive_summary = archive_file_summaries(spec, archive_path, bundle_root)
    archive_rows = archive_summary["files"]
    expected_archive_files = {*spec.staged_names, "release-manifest.json"}
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
    manifest_rows = verified_manifest_rows(embedded_manifest, spec, version, source_revision, epoch)

    for name, manifest_row in manifest_rows.items():
        archive_row = archive_rows[name]
        if int(archive_row["size_bytes"]) != int(manifest_row["size_bytes"]):
            raise RuntimeError(f"archive payload size mismatch for {spec.platform_id}/{name}")
        if str(archive_row["sha256"]) != str(manifest_row["sha256"]):
            raise RuntimeError(f"archive payload hash mismatch for {spec.platform_id}/{name}")

    build_info_head = archive_rows["build-info.json"]["head"]
    build_info_size = int(archive_rows["build-info.json"]["size_bytes"])
    if build_info_size > len(build_info_head):
        raise RuntimeError("build-info.json exceeds the bounded manifest size")
    try:
        embedded_build_info = json.loads(bytes(build_info_head).decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise RuntimeError(f"invalid embedded build info for {spec.platform_id}: {exc}") from exc
    expected_build_info = build_info(spec, version, source_revision, epoch)
    if embedded_build_info != expected_build_info:
        raise RuntimeError(f"embedded build info identity mismatch for {spec.platform_id}")

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
        "source_revision": source_revision,
        "root_entry_present": bool(archive_summary["root_entry_present"]),
        "payload_verified": True,
    }


def verify_windows_installer_header(head: bytes, name: str) -> None:
    pe_offset = int.from_bytes(head[0x3C:0x40], "little") if len(head) >= 0x40 else 0
    if (
        head[:2] != b"MZ"
        or pe_offset + 6 > len(head)
        or head[pe_offset : pe_offset + 4] != b"PE\x00\x00"
        or int.from_bytes(head[pe_offset + 4 : pe_offset + 6], "little") not in {0x014C, 0x8664}
    ):
        raise RuntimeError(f"Windows setup payload is not an x86/x86_64 PE executable: {name}")


def verify_linux_installer_payload(installer_path: Path, source_archive_path: Path) -> None:
    payload = installer_path.read_bytes()
    marker_offset = payload.find(LINUX_INSTALLER_MARKER)
    if marker_offset <= 0 or payload.find(LINUX_INSTALLER_MARKER, marker_offset + 1) >= 0:
        raise RuntimeError("Linux runnable installer payload marker is missing or duplicated")
    header = payload[: marker_offset + len(LINUX_INSTALLER_MARKER)]
    if len(header) > 64 * 1024 or not header.startswith(b"#!/bin/sh\n") or b"\x00" in header:
        raise RuntimeError("Linux runnable installer header is invalid")
    expected_digest = sha256(source_archive_path)
    digest_token = f"ARCHIVE_SHA256='{expected_digest}'".encode("ascii")
    if digest_token not in header:
        raise RuntimeError("Linux runnable installer source-archive identity is missing")
    embedded_archive = payload[marker_offset + len(LINUX_INSTALLER_MARKER) :]
    if hashlib.sha256(embedded_archive).hexdigest() != expected_digest:
        raise RuntimeError("Linux runnable installer embedded archive hash mismatch")


def verify_installer_artifact(
    spec: PlatformSpec,
    installer_path: Path,
    version: str,
    row: dict,
    source_archive_path: Path,
    source_archive_digest: str,
) -> dict:
    expected_name = spec.runnable_installer_name(version)
    if str(row.get("path", "")) != expected_name or installer_path.name != expected_name:
        raise RuntimeError(f"release index installer name mismatch for {spec.platform_id}")
    if str(row.get("platform", "")) != spec.platform_id:
        raise RuntimeError(f"release index installer platform mismatch for {spec.platform_id}")
    expected_format = "self_extracting_tar_gz" if spec.platform_id.startswith("linux") else "nsis"
    if str(row.get("format", "")) != expected_format:
        raise RuntimeError(f"release index installer format mismatch for {spec.platform_id}")
    if str(row.get("source_archive_path", "")) != source_archive_path.name:
        raise RuntimeError(f"release index installer source archive name mismatch for {spec.platform_id}")
    if str(row.get("source_archive_sha256", "")) != source_archive_digest:
        raise RuntimeError(f"release index installer source archive hash mismatch for {spec.platform_id}")
    if int(row.get("size_bytes", -1)) != installer_path.stat().st_size:
        raise RuntimeError(f"release index installer size mismatch for {spec.platform_id}")
    installer_digest = sha256(installer_path)
    if str(row.get("sha256", "")) != installer_digest:
        raise RuntimeError(f"release index installer hash mismatch for {spec.platform_id}")
    if spec.platform_id.startswith("linux"):
        if (installer_path.stat().st_mode & 0o777) != 0o755:
            raise RuntimeError("Linux runnable installer mode is not 0755")
        verify_linux_installer_payload(installer_path, source_archive_path)
    else:
        with installer_path.open("rb") as handle:
            verify_windows_installer_header(handle.read(4096), installer_path.name)
        verify_windows_pe_version(installer_path, version)
    return {
        "platform": spec.platform_id,
        "installer": installer_path.name,
        "format": expected_format,
        "size_bytes": installer_path.stat().st_size,
        "source_archive": source_archive_path.name,
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
    source_revision = safe_source_revision(str(release_index.get("source_revision", "")))
    epoch = release_index.get("source_date_epoch")
    if not isinstance(epoch, int) or epoch < 0:
        raise RuntimeError("release index source_date_epoch is invalid")
    archive_values = release_index.get("archives")
    if not isinstance(archive_values, list) or len(archive_values) != len(PLATFORMS):
        raise RuntimeError("release index must contain exactly one archive per supported platform")
    installer_values = release_index.get("installers")
    if not isinstance(installer_values, list) or len(installer_values) != len(PLATFORMS):
        raise RuntimeError("release index must contain exactly one runnable installer per supported platform")
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
    indexed_installer_rows: dict[str, dict] = {}
    for value in installer_values:
        if not isinstance(value, dict):
            raise RuntimeError("release index installer row is invalid")
        platform_id = str(value.get("platform", ""))
        if platform_id in indexed_installer_rows:
            raise RuntimeError(f"duplicate release index installer platform: {platform_id}")
        indexed_installer_rows[platform_id] = value
    if set(indexed_installer_rows) != {spec.platform_id for spec in PLATFORMS}:
        raise RuntimeError(f"release index installer platform set is invalid: {sorted(indexed_installer_rows)}")

    expected_output_names = {
        "release-index.json",
        "SHA256SUMS",
        *(f"{PRODUCT_ID}-{version}-{spec.platform_id}.{spec.archive_suffix}" for spec in PLATFORMS),
        *(spec.runnable_installer_name(version) for spec in PLATFORMS),
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
    verified_installers = []
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
        verified_platforms.append(
            verify_platform_archive(spec, archive_path, version, source_revision, epoch, manifest)
        )
        installer_row = indexed_installer_rows[spec.platform_id]
        installer_path = archives_dir / spec.runnable_installer_name(version)
        if not installer_path.is_file():
            raise RuntimeError(f"missing runnable installer: {installer_path}")
        installer_digest = sha256(installer_path)
        if checksum_rows.get(installer_path.name) != installer_digest:
            raise RuntimeError(f"SHA256SUMS installer hash mismatch for {spec.platform_id}")
        verified_installers.append(
            verify_installer_artifact(
                spec,
                installer_path,
                version,
                installer_row,
                archive_path,
                archive_digest,
            )
        )
    indexed_artifact_names = {
        *(str(row["path"]) for row in archive_values),
        *(str(row["path"]) for row in installer_values),
    }
    if set(checksum_rows) != indexed_artifact_names:
        raise RuntimeError("SHA256SUMS contains missing or unexpected release artifact rows")
    return {
        "ok": True,
        "schema_id": SCHEMA_ID,
        "product_id": PRODUCT_ID,
        "version": version,
        "source_revision": source_revision,
        "archives_dir": str(archives_dir),
        "platforms": verified_platforms,
        "installers": verified_installers,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build reproducible Linux and Windows heroes-like release archives and installers.")
    parser.add_argument("--version", default=project_version())
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--makensis", default=os.environ.get("MAKENSIS", shutil.which("makensis") or ""))
    parser.add_argument(
        "--source-revision",
        default=os.environ.get("RELEASE_SOURCE_REVISION", ""),
        help="Full Git object id supplied by CI; otherwise require and use a clean local HEAD.",
    )
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
    source_revision = resolve_source_revision(args.source_revision)
    exports_dir = output_dir / "exports"
    archives_dir = output_dir / "archives"
    if archives_dir.exists():
        shutil.rmtree(archives_dir)
    archives_dir.mkdir(parents=True, exist_ok=True)
    epoch = int(os.environ.get("SOURCE_DATE_EPOCH", DEFAULT_SOURCE_DATE_EPOCH))
    if epoch < 0:
        raise ValueError("SOURCE_DATE_EPOCH must be non-negative")
    os.environ["SOURCE_DATE_EPOCH"] = str(epoch)

    archive_rows = []
    installer_rows = []
    with tempfile.TemporaryDirectory(prefix="heroes-like-release-") as temp:
        stage_dir = Path(temp)
        for spec in PLATFORMS:
            export_dir = exports_dir / spec.platform_id
            if not args.skip_export:
                export_platform(spec, export_dir, args.godot)
            bundle_root, platform_manifest = stage_platform(
                spec,
                export_dir,
                stage_dir,
                version,
                source_revision,
                epoch,
            )
            archive_name = f"{bundle_root.name}.{spec.archive_suffix}"
            archive_path = archives_dir / archive_name
            if archive_path.exists():
                archive_path.unlink()
            if spec.archive_suffix == "tar.gz":
                create_tar_gz(bundle_root, archive_path, spec, epoch)
            else:
                create_zip(bundle_root, archive_path, spec, epoch)
            archive_digest = sha256(archive_path)
            archive_rows.append(
                {
                    "platform": spec.platform_id,
                    "path": archive_path.name,
                    "size_bytes": archive_path.stat().st_size,
                    "sha256": archive_digest,
                    "payload_manifest": platform_manifest,
                }
            )
            installer_path = archives_dir / spec.runnable_installer_name(version)
            create_runnable_installer(
                spec,
                archive_path,
                bundle_root,
                installer_path,
                version,
                args.makensis,
                platform_manifest,
            )
            installer_rows.append(
                {
                    "platform": spec.platform_id,
                    "path": installer_path.name,
                    "format": "self_extracting_tar_gz" if spec.platform_id.startswith("linux") else "nsis",
                    "size_bytes": installer_path.stat().st_size,
                    "sha256": sha256(installer_path),
                    "source_archive_path": archive_path.name,
                    "source_archive_sha256": archive_digest,
                }
            )

    release_index = {
        "schema_id": SCHEMA_ID,
        "product_id": PRODUCT_ID,
        "version": version,
        "source_revision": source_revision,
        "source_date_epoch": epoch,
        "archives": archive_rows,
        "installers": installer_rows,
    }
    index_path = archives_dir / "release-index.json"
    index_path.write_text(json.dumps(release_index, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    checksum_path = archives_dir / "SHA256SUMS"
    checksum_path.write_text(
        "".join(
            f"{row['sha256']}  {row['path']}\n"
            for row in sorted([*archive_rows, *installer_rows], key=lambda value: str(value["path"]))
        ),
        encoding="ascii",
    )
    verification = verify_release_archives(output_dir)
    print(json.dumps({"ok": True, "version": version, "output": str(archives_dir), "archives": archive_rows, "installers": installer_rows, "verification": verification}, sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, ValueError, subprocess.TimeoutExpired, tarfile.TarError, zipfile.BadZipFile) as exc:
        print(f"package_release: {exc}", file=sys.stderr)
        raise SystemExit(1)
