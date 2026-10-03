#!/usr/bin/env python3
"""Reject archived production media in Git; runtime/editor/provenance inputs stay."""
from __future__ import annotations

import argparse
from pathlib import Path
import subprocess

from source_material_inventory import SOURCE_BINARY_SUFFIXES, classify

ROOT = Path(__file__).resolve().parents[1]


def archived_media(path: str) -> bool:
    parts = path.split("/")
    base = path.removesuffix(".import").removesuffix(".uid")
    if len(parts) < 4 or parts[0] != "art" or parts[2] != "source":
        return False
    if Path(base).suffix.lower() not in SOURCE_BINARY_SUFFIXES:
        return False
    return classify(base, {"Linux Release": True, "Windows Release": True}, [], []) == "archive_source_binary"


def violations(root: Path, revision: str = "HEAD") -> list[str]:
    result = subprocess.run(
        ["git", "ls-tree", "-r", "--name-only", "-z", revision],
        cwd=root, capture_output=True, check=True,
    )
    return [p for p in result.stdout.decode("utf8").split("\0") if p and archived_media(p)]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--revision", default="HEAD")
    args = parser.parse_args()
    bad = violations(ROOT, args.revision)
    if bad:
        print(f"FAIL: {len(bad)} archived-media paths are tracked. Keep production media in the external source archive.")
        for path in bad[:20]:
            print(path)
        return 1
    print("PASS: no archived production media is tracked; editor and provenance exceptions are retained.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
