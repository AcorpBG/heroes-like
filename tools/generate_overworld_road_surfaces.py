"""Generate the original gravel and cobblestone road surfaces for the overworld.

Each surface is a seamless 512x512 painting that covers 4x4 map tiles, like
the dirt ground the dirt road samples. Stones are cells of a wrapped Voronoi
pattern, lit from the upper left like the rest of the map, with earth showing
between them. Deterministic: the same seed gives the same file. Owner picks
(2026-10-15) from in-game comparison sheets: grey crushed stone for gravel,
rounded cobbles for cobblestone.

Usage: python tools/generate_overworld_road_surfaces.py [--only NAME]
"""
import argparse
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / 'art/overworld/runtime/terrain_tiles/roads'
SIZE = 512

# cells: stones across the painting; gap: earth between stones (cell units);
# dome: how rounded; light: shading strength; coverage: share of cells that
# are stones (the rest show the earth).
SURFACES = {
    'road_gravel': dict(cells=112, jitter=0.95, gap=0.14, dome=0.55, colors=[(118, 116, 110), (134, 130, 122), (104, 102, 98), (146, 140, 128)],
                        base=(82, 72, 60), coverage=0.9, spread=0.12, grain=0.07, light=0.35, seed=12),
    'road_cobblestone': dict(cells=40, jitter=0.7, gap=0.09, dome=1.0, colors=[(132, 128, 120), (150, 144, 132), (118, 114, 110), (140, 130, 114)],
                             base=(58, 50, 40), coverage=1.0, spread=0.10, grain=0.06, light=0.6, seed=21),
}


def value_noise(size, cells, rng):
    """Seamless smooth noise in [0, 1]."""
    grid = rng.random((cells, cells))
    coords = np.arange(size) / size * cells
    i0 = np.floor(coords).astype(int)
    f = coords - i0
    f = f * f * (3.0 - 2.0 * f)
    i1 = (i0 + 1) % cells
    a = grid[np.ix_(i0, i0)]
    b = grid[np.ix_(i0, i1)]
    c = grid[np.ix_(i1, i0)]
    d = grid[np.ix_(i1, i1)]
    fy = f[:, None]
    fx = f[None, :]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def voronoi(size, cells, jitter, rng):
    """Wrapped Voronoi: distance to nearest and second nearest site, nearest id."""
    sites = (np.stack(np.meshgrid(np.arange(cells), np.arange(cells), indexing='ij'), -1)
             + 0.5 + (rng.random((cells, cells, 2)) - 0.5) * jitter)
    coords = (np.arange(size) + 0.5) / size * cells
    py, px = np.meshgrid(coords, coords, indexing='ij')
    cy = np.floor(py).astype(int)
    cx = np.floor(px).astype(int)
    f1 = np.full((size, size), 1e9)
    f2 = np.full((size, size), 1e9)
    ident = np.zeros((size, size), dtype=int)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            ny = cy + dy
            nx = cx + dx
            site = sites[ny % cells, nx % cells]
            sy = site[..., 0] + (ny - ny % cells)
            sx = site[..., 1] + (nx - nx % cells)
            d = np.hypot(py - sy, px - sx)
            cell_id = (ny % cells) * cells + (nx % cells)
            closer = d < f1
            f2 = np.where(closer, f1, np.minimum(f2, d))
            ident = np.where(closer, cell_id, ident)
            f1 = np.where(closer, d, f1)
    return f1, f2, ident


def surface(name, spec):
    rng = np.random.default_rng(spec['seed'])
    f1, f2, ident = voronoi(SIZE, spec['cells'], spec['jitter'], rng)
    edge = f2 - f1  # 0 on the boundary between two stones
    stone = np.clip((edge - spec['gap']) / 0.08, 0.0, 1.0)
    count = spec['cells'] * spec['cells']
    present = rng.random(count) < spec['coverage']
    stone = stone * present[ident]
    # Height: a dome over each stone, flat in the mortar.
    height = np.clip(edge / 0.5, 0.0, 1.0) ** 0.6 * spec['dome'] + value_noise(SIZE, 32, rng) * 0.15
    gy, gx = np.gradient(height * spec['cells'] / 8.0)
    shade = 1.0 + spec['light'] * (-gx - gy) / np.sqrt(1.0 + gx * gx + gy * gy)
    palette = np.array(spec['colors'], dtype=float)
    pick = rng.integers(0, len(palette), count)
    tint = 1.0 + (rng.random(count) - 0.5) * 2.0 * spec['spread']
    stone_rgb = palette[pick][ident] * tint[ident][..., None]
    grain = 1.0 + (rng.random((SIZE, SIZE)) - 0.5) * 2.0 * spec['grain']
    grain *= 1.0 + (value_noise(SIZE, 16, rng) - 0.5) * 0.18
    stone_rgb = stone_rgb * (shade * grain)[..., None]
    base = np.array(spec['base'], dtype=float) * (0.85 + 0.3 * value_noise(SIZE, 24, rng))[..., None]
    # Earth darkens toward the stone edge: a contact shadow.
    contact = np.clip(edge / (spec['gap'] + 0.06), 0.0, 1.0)
    base = base * (0.7 + 0.3 * contact)[..., None]
    rgb = base * (1.0 - stone[..., None]) + stone_rgb * stone[..., None]
    image = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8), 'RGB')
    image.save(OUT_DIR / f'{name}.png')
    return image


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--only')
    args = parser.parse_args()
    for name, spec in SURFACES.items():
        if args.only and name != args.only:
            continue
        surface(name, spec)
        print('wrote', OUT_DIR / f'{name}.png')


if __name__ == '__main__':
    main()
