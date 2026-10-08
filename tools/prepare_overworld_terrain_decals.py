#!/usr/bin/env python3
"""Package approved original terrain decal sheets into the runtime atlas.

Each source is a generated 4x4 sheet of ground details for one ground type
(rows 1-2 tiny, row 3 medium, row 4 large), painted against that ground's
material as reference. Packaging only cuts, cleans, grades and packs: every
decal is cut from its cell, stray neighbour fragments and haze are dropped,
the colours are pulled part of the way toward the ground material's own tone
and contrast (so details belong to the ground), edges are feathered, the
colour under transparent pixels is bled outward (no dark mip fringes), and the
result is packed into a 16x16 atlas of 128 px cells with a 4 px margin.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter, ImageStat

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art/overworld/source/generated/terrain/decals_v4'
RUNTIME = ROOT / 'art/overworld/runtime/terrain_tiles/detail/terrain_decals_v4.png'
GROUND_ATLAS = ROOT / 'art/overworld/runtime/terrain_tiles/ground_materials_v3.png'
CELL = 128
INNER = 120
GRID = 16
# How far a decal's mean colour moves toward its ground, and the contrast floor.
TONE_PULL = 0.12
CONTRAST_RANGE = (0.9, 1.0)


def ground_stats(slot):
    with Image.open(GROUND_ATLAS) as atlas:
        x, y = (slot % 4) * 512, (slot // 4) * 512
        stat = ImageStat.Stat(atlas.convert('RGB').crop((x + 16, y + 16, x + 496, y + 496)))
    return stat.mean, stat.stddev


def cut_cell(sheet, row, col):
    width, height = sheet.size
    cell = sheet.crop((col * width // 4, row * height // 4, (col + 1) * width // 4, (row + 1) * height // 4))
    alpha = cell.getchannel('A').point(lambda a: 0 if a < 12 else a)
    # Fragments of a neighbouring detail can reach a cell's border; keep only
    # what lies inside a 3% margin.
    margin = max(2, cell.size[0] * 3 // 100)
    mask = Image.new('L', cell.size, 0)
    mask.paste(255, (margin, margin, cell.size[0] - margin, cell.size[1] - margin))
    alpha = Image.composite(alpha, Image.new('L', cell.size, 0), mask)
    cell.putalpha(alpha)
    box = alpha.point(lambda a: 255 if a > 24 else 0).getbbox()
    if box is None:
        raise ValueError(f'empty decal cell {row},{col}')
    cell = cell.crop(box)
    side = max(cell.size)
    square = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    square.paste(cell, ((side - cell.size[0]) // 2, (side - cell.size[1]) // 2))
    return square


def grade(decal, ground_mean, ground_std):
    rgb = decal.convert('RGB')
    alpha = decal.getchannel('A')
    stat = ImageStat.Stat(rgb, alpha.point(lambda a: 255 if a > 128 else 0))
    bands = []
    for index, band in enumerate(rgb.split()):
        mean, std = stat.mean[index], max(stat.stddev[index], 1.0)
        target = mean + (ground_mean[index] - mean) * TONE_PULL
        gain = min(max(ground_std[index] / std, CONTRAST_RANGE[0]), CONTRAST_RANGE[1])
        bands.append(band.point(lambda v, m=mean, t=target, g=gain: int(max(0, min(255, t + (v - m) * g)))))
    graded = Image.merge('RGB', bands)
    graded.putalpha(alpha)
    return graded


def feather(decal):
    # A light blur only: an erosion would wipe out blades, twigs and cracks.
    alpha = decal.getchannel('A').filter(ImageFilter.GaussianBlur(0.7))
    decal.putalpha(alpha)
    return decal


def bleed(decal):
    # Spread opaque colour into transparent pixels (average of known
    # neighbours, ring by ring) so filtering and mipmaps never pull in black.
    pixels = np.asarray(decal.convert('RGBA'), dtype=np.float32).copy()
    known = pixels[..., 3] > 8
    rgb = pixels[..., :3]
    for _ in range(INNER):
        if known.all():
            break
        total = np.zeros_like(rgb)
        count = np.zeros(known.shape, dtype=np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            neighbour = np.roll(known, (dy, dx), (0, 1))
            total += np.roll(rgb, (dy, dx), (0, 1)) * neighbour[..., None]
            count += neighbour
        grow = (~known) & (count > 0)
        rgb[grow] = total[grow] / count[grow][:, None]
        known |= grow
    pixels[..., :3] = rgb
    return Image.fromarray(np.clip(pixels + 0.5, 0, 255).astype(np.uint8), 'RGBA')


def packed_bytes(manifest):
    atlas = Image.new('RGBA', (GRID * CELL, GRID * CELL), (0, 0, 0, 0))
    for set_index, source in enumerate(manifest['sources']):
        path = ROOT / source['path'].removeprefix('res://')
        assert hashlib.sha256(path.read_bytes()).hexdigest() == source['sha256'], path
        mean, std = ground_stats(int(source['ground_material_slot']))
        with Image.open(path) as sheet:
            sheet = sheet.convert('RGBA')
            for index in range(16):
                row, col = index // 4, index % 4
                decal = cut_cell(sheet, row, col).resize((INNER, INNER), Image.Resampling.LANCZOS)
                decal = bleed(feather(grade(decal, mean, std)))
                slot = set_index * 16 + index
                atlas.paste(decal, ((slot % GRID) * CELL + (CELL - INNER) // 2, (slot // GRID) * CELL + (CELL - INNER) // 2))
    output = io.BytesIO()
    atlas.save(output, format='PNG', optimize=True)
    return output.getvalue()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    manifest = json.loads((SOURCE / 'manifest.json').read_text(encoding='utf-8'))
    result = packed_bytes(manifest)
    if args.check:
        assert RUNTIME.read_bytes() == result, 'Runtime decal atlas is not reproducible'
        assert hashlib.sha256(result).hexdigest() == manifest['runtime']['sha256']
    else:
        RUNTIME.write_bytes(result)
    print(f"Decal atlas: {len(result)} bytes, sha256={hashlib.sha256(result).hexdigest()}")


if __name__ == '__main__':
    main()
