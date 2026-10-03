#!/usr/bin/env python3
"""Verify the local, ignored RMG evidence manifest without modifying evidence."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import sys

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = Path('.artifacts/rmg_recovery/storage/consolidation-20261003/manifest.json')


def evidence_path(root: Path, relative: str) -> Path:
    """Accept only ordinary files inside the protected recovery tree."""
    parts = PurePosixPath(relative).parts
    if (not parts or PurePosixPath(relative).is_absolute()
            or any(p in ('.', '..') or '\\' in p or ':' in p for p in parts)
            or parts[:2] != ('.artifacts', 'rmg_recovery')):
        raise ValueError(f'Invalid recovery path: {relative}')
    path = root.joinpath(*parts)
    if not path.resolve().is_relative_to(root.resolve()):
        raise ValueError(f'Recovery path escapes repository: {relative}')
    for parent in (path, *path.parents):
        if parent == root:
            break
        if parent.is_symlink() or (hasattr(parent, 'is_junction') and parent.is_junction()):
            raise ValueError(f'Recovery path uses a filesystem link: {relative}')
    return path


def verify(root: Path, manifest: dict) -> dict:
    if manifest.get('schema_version') != 1:
        raise ValueError('Unsupported RMG evidence manifest version')
    failures = []
    verified = total_bytes = 0
    seen = set()
    for index, row in enumerate(manifest['files'], 1):
        relative = row['path']
        try:
            if relative.casefold() in seen:
                raise ValueError(f'Duplicate manifest path: {relative}')
            seen.add(relative.casefold())
            path = evidence_path(root, relative)
            if path.stat().st_size != row['size']:
                raise ValueError('File size differs')
            digest = hashlib.sha256()
            with path.open('rb') as stream:
                for chunk in iter(lambda: stream.read(4 * 1024 * 1024), b''):
                    digest.update(chunk)
            if digest.hexdigest() != row['sha256']:
                raise ValueError('SHA-256 differs')
            verified += 1
            total_bytes += row['size']
        except (OSError, ValueError) as error:
            failures.append({'path': relative, 'error': str(error)})
        if index % 2000 == 0:
            print(f'Checked {index}/{len(manifest["files"])} evidence files', file=sys.stderr, flush=True)
    return {'verified_files': verified, 'verified_bytes': total_bytes, 'failures': failures}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo-root', type=Path, default=ROOT)
    parser.add_argument('--manifest', type=Path, default=DEFAULT_MANIFEST)
    args = parser.parse_args()
    root = args.repo_root.resolve()
    manifest = args.manifest if args.manifest.is_absolute() else root / args.manifest
    result = verify(root, json.loads(manifest.read_text(encoding='utf-8')))
    print(json.dumps(result, indent=2))
    return 1 if result['failures'] else 0


if __name__ == '__main__':
    raise SystemExit(main())
