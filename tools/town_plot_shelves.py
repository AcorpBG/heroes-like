"""Level ground for a town's plots: marks for the painter, and the repainted ground blended in.

A building painted into the empty town scene brings its own footing: the painter draws a
shelf under it. The layer keeps the building alone, so on a slope or a cliff face the
building is left hanging over ground that was never level. The ground has to carry the
shelf itself, for every stage of the plot and for the empty plot too.

  marks   Draws, over the backdrop master, a red band where each plot's buildings stand:
          the foot of all its stages' mattes, smoothed. The band is the markup image of one
          unmasked edit of the master that asks for level natural ground in every band and
          for nothing else to change. Also writes the bands as a mask, next to the markup.

  blend   Takes that edit only near the bands; the rest of the master stays as it was, and
          so does protected paint (white in a keep mask: water, falls, lamps, a foreground
          tree), so effect masks and foreground masks keep fitting.

The buildings stay as they are: they are cut against the master they were painted on
(the packet's painted_on) and drawn over the new one.

Needs numpy, scipy and Pillow.

usage: python tools/town_plot_shelves.py marks <packet> <markup.png> [--skip plot_id ...]
       python tools/town_plot_shelves.py blend <packet> <edit.png> <bands.png> <new master.png> [--keep mask.png ...]
"""
import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
FOOT_SHARE, FOOT_LEAST = 0.38, 50   # the foot of a building: this share of its height, at least this many pixels
BAND_DEPTH = (0.16, 18, 46)         # how far the band reaches up behind the foot: share of the width, least, most
BAND_BELOW, BAND_SIDE = 12, 16      # and below the foot and past its ends
REACH, SOFT = 70, 14.0              # the edit is taken this far round a band, fading over this blur


def bands_of(packet, skip):
    master = ROOT / packet['backdrop']['source_path']
    with Image.open(master) as image:
        width, height = image.size
    plots = {}
    for item in packet['buildings']:
        if item['plot_id'] in skip:
            continue
        wx, wy, ww, wh = item['matte']['window']
        solid = np.zeros((height, width), bool)
        with Image.open(ROOT / item['matte']['path']) as matte:
            solid[wy:wy + wh, wx:wx + ww] = np.asarray(matte.convert('L')) > 127
        labels, count = ndimage.label(solid)
        if count > 1:
            sizes = ndimage.sum(solid, labels, range(1, count + 1))
            solid = np.isin(labels, [i + 1 for i, size in enumerate(sizes) if size >= 0.05 * sizes.max()])
        plots[item['plot_id']] = plots.get(item['plot_id'], False) | ndimage.binary_fill_holes(solid)
    bands = np.zeros((height, width), bool)
    for union in plots.values():
        # The foot only: a tower's wide top or a roof's overhang is not where it stands.
        rows = np.flatnonzero(union.any(axis=1))
        union = union.copy()
        union[:max(0, rows.max() - max(FOOT_LEAST, int(FOOT_SHARE * (rows.max() - rows.min() + 1))))] = False
        columns = union.sum(axis=0)
        union[:, columns < 0.15 * columns.max()] = False
        xs = np.flatnonzero(union.any(axis=0))
        x0, x1 = xs.min(), xs.max()
        low = (height - 1 - np.argmax(union[::-1], axis=0)).astype(np.float32)[x0:x1 + 1]
        low = np.pad(low, BAND_SIDE, mode='edge')
        low = ndimage.uniform_filter1d(ndimage.median_filter(low, size=61, mode='nearest'), size=41, mode='nearest')
        share, least, most = BAND_DEPTH
        depth = int(np.clip(share * (x1 - x0 + 1), least, most))
        band = np.zeros((height, width), bool)
        for i, x in enumerate(range(x0 - BAND_SIDE, x1 + BAND_SIDE + 1)):
            if 0 <= x < width:
                band[max(0, int(low[i]) - depth):min(height, int(low[i]) + BAND_BELOW), x] = True
        bands |= ndimage.binary_opening(band, iterations=5)
    return bands


def marks(args):
    packet = json.loads((ROOT / args.packet).read_text(encoding='utf-8'))
    bands = bands_of(packet, set(args.skip))
    edge = bands & ~ndimage.binary_erosion(bands, iterations=4)
    markup = np.zeros(bands.shape + (4,), np.uint8)
    markup[bands] = (255, 0, 0, 70)
    markup[edge] = (255, 0, 0, 255)
    out = Path(args.markup)
    Image.fromarray(markup, 'RGBA').save(out)
    Image.fromarray(bands.astype(np.uint8) * 255, 'L').save(out.with_name(out.stem.removesuffix('_markup') + '_bands.png'))
    print('bands cover %.1f%% of the picture' % (bands.mean() * 100))


def blend(args):
    packet = json.loads((ROOT / args.packet).read_text(encoding='utf-8'))
    with Image.open(ROOT / packet['backdrop']['source_path']) as image:
        size = image.size
        current = np.asarray(image.convert('RGB')).astype(np.float32)
    with Image.open(args.edit) as image:
        edit = np.asarray(image.convert('RGB').resize(size, Image.Resampling.LANCZOS)).astype(np.float32)
    with Image.open(args.bands) as image:
        bands = np.asarray(image.convert('L')) > 127
    weight = ndimage.gaussian_filter((ndimage.distance_transform_edt(~bands) < REACH).astype(np.float32), SOFT)
    for path in args.keep:
        with Image.open(path) as image:
            keep = np.asarray(image.convert('L').resize(size, Image.Resampling.LANCZOS)) > 100
        keep = ndimage.maximum_filter(ndimage.gaussian_filter(keep.astype(np.float32), 3.0), size=7)
        weight *= 1.0 - np.clip(keep, 0.0, 1.0)
    out = current * (1.0 - weight[..., None]) + edit * weight[..., None]
    Image.fromarray(np.clip(out + 0.5, 0, 255).astype(np.uint8), 'RGB').save(args.out)
    print('the edit covers %.1f%% of the picture; %.1f%% of it changed visibly'
          % (weight.mean() * 100, (np.abs(out - current).mean(axis=2) > 12).mean() * 100))


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    commands = parser.add_subparsers(dest='command', required=True)
    command = commands.add_parser('marks')
    command.add_argument('packet')
    command.add_argument('markup')
    command.add_argument('--skip', nargs='*', default=[], help='plots that stand on water or on their own piles')
    command.set_defaults(run=marks)
    command = commands.add_parser('blend')
    command.add_argument('packet')
    command.add_argument('edit')
    command.add_argument('bands')
    command.add_argument('out')
    command.add_argument('--keep', nargs='*', default=[], help='masks whose white stays as the current master paints it')
    command.set_defaults(run=blend)
    args = parser.parse_args()
    args.run(args)


if __name__ == '__main__':
    main()
