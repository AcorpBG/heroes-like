#!/usr/bin/env python3
"""Remove only JSON formatting from newly exported standalone Godot v3 PCKs.

Container layout: Godot 4.6 core/io/{pck_packer,file_access_pack}.cpp.
No source files, image encodings, resource paths or JSON token bytes are changed.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
from decimal import Decimal
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import struct
import tempfile


HEADER_BYTES = 104
MAX_PACK_BYTES = 2_000_000_000
JSON_SPANS = re.compile(rb'"(?:[^"\\]|\\.)*"|[ \t\r\n]+')


def digest(data: bytes | memoryview) -> bytes:
    return hashlib.md5(data, usedforsecurity=False).digest()


def compact_json(data: bytes) -> bytes:
    def invalid_constant(value: str):
        raise ValueError("Non-JSON numeric constant: " + value)

    # Validate without a float round trip or serializing/reordering authored data.
    json.loads(data.decode("utf-8"), parse_int=Decimal, parse_float=Decimal,
               parse_constant=invalid_constant)
    return JSON_SPANS.sub(lambda m: m[0] if m[0].startswith(b'"') else b"", data)


def eligible(path: str) -> bool:
    return path.endswith(".json") and (
        path.startswith("content/") or
        (path.startswith("art/") and "/source/" not in path)
    )


@dataclass(frozen=True)
class Entry:
    path: str
    name: bytes  # Original padded UTF-8 name, retained exactly.
    offset: int
    size: int
    md5: bytes


def read_directory(data: bytes) -> tuple[int, list[Entry]]:
    """Fail closed on everything outside the repo's plain standalone v3 export."""
    if not HEADER_BYTES <= len(data) <= MAX_PACK_BYTES or data[:4] != b"GDPC":
        raise ValueError("Not a bounded standalone PCK")
    version, major, minor, patch, flags = struct.unpack_from("<5I", data, 4)
    if version != 3 or major != 4 or minor != 6 or flags != 2:
        raise ValueError("Unsupported PCK version/engine/flags (plain Godot 4.6 v3 only)")
    base, directory = struct.unpack_from("<QQ", data, 24)
    if not HEADER_BYTES <= base <= directory <= len(data) - 4 or base > 1_048_576:
        raise ValueError("Invalid PCK payload/directory bounds")
    if any(data[40:base]):
        raise ValueError("Unsupported PCK reserved header or padding")
    count = struct.unpack_from("<I", data, directory)[0]
    if not 0 < count <= 100_000:
        raise ValueError("Invalid PCK entry count")
    cursor = directory + 4
    entries, names = [], set()
    for _ in range(count):
        if cursor + 4 > len(data):
            raise ValueError("Truncated PCK name length")
        length = struct.unpack_from("<I", data, cursor)[0]
        cursor += 4
        if not 0 < length <= 4096 or length % 4 or cursor + length + 36 > len(data):
            raise ValueError("Invalid/truncated PCK directory entry")
        name = data[cursor:cursor + length]
        cursor += length
        raw_name = name.rstrip(b"\0")
        path = raw_name.decode("utf-8")
        if (not path or b"\0" in raw_name or "\\" in path or ":" in path or
                PurePosixPath(path).is_absolute() or
                any(part in ("", ".", "..") for part in path.split("/")) or path in names):
            raise ValueError("Unsafe/duplicate PCK resource path")
        names.add(path)
        offset, size, md5, entry_flags = struct.unpack_from("<QQ16sI", data, cursor)
        cursor += 36
        offset += base
        if entry_flags or not base <= offset <= directory or size > directory - offset:
            raise ValueError("Unsupported flags or out-of-range PCK payload: " + path)
        if digest(memoryview(data)[offset:offset + size]) != md5:
            raise ValueError("PCK payload digest mismatch: " + path)
        entries.append(Entry(path, name, offset, size, md5))
    if len(data) - cursor > 15 or any(data[cursor:]):
        raise ValueError("Unexpected trailing PCK data")
    previous_end = base
    for entry in sorted(entries, key=lambda e: (e.offset, e.size)):
        if entry.offset < previous_end:
            raise ValueError("Overlapping PCK payloads")
        previous_end = entry.offset + entry.size
    return base, entries


def verify_payloads(original: bytes, candidate: bytes) -> dict:
    """Read both directories afresh and compare every member before replacement."""
    base, before = read_directory(original)
    after_base, after = read_directory(candidate)
    if base != after_base or original[:32] != candidate[:32] or original[40:base] != candidate[40:base]:
        raise ValueError("PCK header changed beyond directory offset")
    if [e.path for e in before] != [e.path for e in after]:
        raise ValueError("PCK resource inventory/order changed")
    changed = []
    non_json = 0
    inventory = hashlib.sha256()
    for left, right in zip(before, after):
        old = original[left.offset:left.offset + left.size]
        new = candidate[right.offset:right.offset + right.size]
        expected = compact_json(old) if eligible(left.path) else old
        if left.name != right.name or new != expected:
            raise ValueError("Unexpected PCK member change: " + left.path)
        if not eligible(left.path):
            non_json += 1
        if old != new:
            changed.append({"path": left.path, "before_bytes": len(old), "after_bytes": len(new),
                            "before_sha256": hashlib.sha256(old).hexdigest(),
                            "after_sha256": hashlib.sha256(new).hexdigest()})
        inventory.update(left.path.encode() + b"\0" + hashlib.sha256(new).digest())
    return {"ok": True, "entries_verified": len(before), "unchanged_non_json_entries": non_json,
            "json_entries": len(before) - non_json, "changed_json": changed,
            "verified_inventory_sha256": inventory.hexdigest(),
            "before_bytes": len(original), "after_bytes": len(candidate),
            "saved_bytes": len(original) - len(candidate)}


def compact_export(path: Path) -> dict:
    """Verify then atomically replace only a caller-selected disposable export."""
    path = Path(path)
    if path.is_symlink() or not path.is_file() or path.suffix != ".pck":
        raise ValueError("Expected a regular exported .pck, not a link or directory")
    if path.stat().st_size > MAX_PACK_BYTES:
        raise ValueError("PCK exceeds supported tool bound")
    original = path.read_bytes()
    base, entries = read_directory(original)
    payloads = {}
    for e in entries:
        if eligible(e.path):
            old = original[e.offset:e.offset + e.size]
            compacted = compact_json(old)
            if old != compacted:
                payloads[e.path] = compacted
    if not payloads:
        return verify_payloads(original, original)
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(prefix=path.name + ".compact-", dir=path.parent, delete=False) as output:
            temporary = Path(output.name)
            output.write(original[:base])
            directory_rows = []
            for e in entries:
                body = payloads.get(e.path)
                if body is None:
                    body = memoryview(original)[e.offset:e.offset + e.size]
                offset = output.tell() - base
                output.write(body)
                output.write(b"\0" * (-output.tell() % 16))
                directory_rows.append((e.name, offset, len(body), digest(body)))
            directory = output.tell()
            output.write(struct.pack("<I", len(entries)))
            for name, offset, size, md5 in directory_rows:
                output.write(struct.pack("<I", len(name)) + name + struct.pack("<QQ16sI", offset, size, md5, 0))
            output.seek(32)
            output.write(struct.pack("<Q", directory))
            output.flush()
            os.fsync(output.fileno())
        candidate = temporary.read_bytes()
        report = verify_payloads(original, candidate)
        if report["saved_bytes"] <= 0:
            raise ValueError("Compaction did not reduce the exported PCK")
        if path.is_symlink() or path.read_bytes() != original:
            raise ValueError("Export changed during compaction; refusing replacement")
        os.chmod(temporary, path.stat().st_mode & 0o777)
        os.replace(temporary, path)
        temporary = None
        return report
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pack", type=Path, help="new disposable standalone export; replaced only after verification")
    args = parser.parse_args()
    print(json.dumps(compact_export(args.pack), indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
