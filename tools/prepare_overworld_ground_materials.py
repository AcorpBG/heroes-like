#!/usr/bin/env python3
"""Package approved original ground paintings; never synthesize replacement art."""
import argparse
import hashlib
import io
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art/overworld/source/generated/terrain/ground_materials_v3'
RUNTIME = ROOT / 'art/overworld/runtime/terrain_tiles/ground_materials_v3.png'


def packed_bytes(manifest):
    # Four 2x2 originals -> 4x4 runtime atlas. A two-pixel duplicated gutter
    # prevents adjacent materials leaking through bilinear filtering. No flips,
    # mirrors, painted pixels, colour substitutions or lossy image encoding.
    atlas = Image.new('RGB', (2048, 2048))
    for sheet_index, sheet in enumerate(manifest['sources']):
        path = ROOT / sheet['path'].removeprefix('res://')
        assert hashlib.sha256(path.read_bytes()).hexdigest() == sheet['sha256'], path
        with Image.open(path) as original:
            assert list(original.size) == sheet['size']
            width, height = original.size
            for quadrant in range(4):
                x, y = quadrant % 2, quadrant // 2
                tile = original.crop((x * width // 2, y * height // 2,
                                      (x + 1) * width // 2, (y + 1) * height // 2))
                tile = tile.convert('RGB').resize((508, 508), Image.Resampling.LANCZOS)
                cell = Image.new('RGB', (512, 512))
                cell.paste(tile, (2, 2))
                cell.paste(tile.crop((0, 0, 1, 508)).resize((2, 508)), (0, 2))
                cell.paste(tile.crop((507, 0, 508, 508)).resize((2, 508)), (510, 2))
                cell.paste(cell.crop((0, 2, 512, 3)).resize((512, 2)), (0, 0))
                cell.paste(cell.crop((0, 509, 512, 510)).resize((512, 2)), (0, 510))
                slot = sheet_index * 4 + quadrant
                atlas.paste(cell, ((slot % 4) * 512, (slot // 4) * 512))
    output = io.BytesIO()
    atlas.save(output, format='PNG', optimize=True)
    return output.getvalue()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    manifest = json.loads((SOURCE / 'manifest.json').read_text())
    result = packed_bytes(manifest)
    if args.check:
        assert RUNTIME.read_bytes() == result, 'Runtime atlas is not reproducible'
        assert hashlib.sha256(result).hexdigest() == manifest['runtime']['sha256']
    else:
        RUNTIME.write_bytes(result)
    print(f"Ground atlas: {len(result)} bytes, sha256={hashlib.sha256(result).hexdigest()}")


if __name__ == '__main__':
    main()
