#!/usr/bin/env python3
"""Prove lossless import transfer and complete same-platform PCK preservation."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from compact_export_pck import read_directory


def members(path):
    data = path.read_bytes()
    _, rows = read_directory(data)  # Verifies every digest/path/range first.
    return {r.path: data[r.offset:r.offset + r.size] for r in rows}


def verify(before, after, windows, proofs):
    original, result, win = map(members, (before, after, windows))
    if original.keys() != result.keys() or result.keys() != win.keys():
        raise ValueError("Exported member set changed")
    allowed = {row["proof"]["cache"]: row["proof"] for row in proofs.values()}
    missing = set(allowed) - set(result)
    if missing:
        raise ValueError("Prepared texture omitted from PCK: " + repr(sorted(missing)[:10]))
    changed = []
    for path, payload in result.items():
        if path in allowed:
            proof = allowed[path]
            if hashlib.sha256(original[path]).hexdigest() not in (proof["before_sha256"], proof["after_sha256"]):
                raise ValueError("Baseline texture is not covered by the decoded proof: " + path)
            if hashlib.sha256(payload).hexdigest() != proof["after_sha256"]:
                raise ValueError("Export did not use verified texture: " + path)
        elif payload != original[path]:
            raise ValueError("Non-target exported member changed: " + path)
        if payload != original[path]:
            changed.append(path)
        if path != "project.binary" and payload != win[path]:
            raise ValueError("Linux/Windows payload drift: " + path)
    saved = before.stat().st_size - after.stat().st_size
    if saved <= 0:
        raise ValueError("No measured lossless package saving")
    return {"ok": True, "members": len(result), "verified_texture_members": len(allowed),
            "changed_texture_members": len(changed), "unchanged_members": len(result)-len(changed),
            "platform_equal_members": len(result)-1, "platform_specific_member": "project.binary",
            "before_bytes": before.stat().st_size, "after_bytes": after.stat().st_size,
            "windows_bytes": windows.stat().st_size, "saved_bytes": saved,
            "pack_sha256": {str(p): hashlib.sha256(p.read_bytes()).hexdigest() for p in (before, after, windows)}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("before", type=Path)
    parser.add_argument("after", type=Path)
    parser.add_argument("windows", type=Path)
    parser.add_argument("--proofs", type=Path, default=ROOT / ".godot/lossless-imports.json")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    report = verify(args.before, args.after, args.windows, json.loads(args.proofs.read_text()))
    report["proofs_sha256"] = hashlib.sha256(args.proofs.read_bytes()).hexdigest()
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
