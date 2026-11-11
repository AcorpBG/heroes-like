"""Mends building mattes that BiRefNet cannot get right, from hand-drawn shapes.

tools/town_plot_mattes.py lets BiRefNet mark each painted building. It fails on a few
kinds: a moss roof looks like mossy ground to it, a palisade far off in the haze is no
object at all, and of a ring of posts it keeps the creature inside and a post or two.
More looks (matte_passes) do not help those. For such a building the file
<packet>_matte_patches.json, next to the packet, lists shapes in master pixels:

  add      outlines; what lies inside joins the matte. An outline given as
           {"outline": [...], "fade": n} fades out over n pixels at its left and right
           ends (a wall that runs on past the plot)
  lines    chains and ropes: a line through points, of a width
  seal     closes seams up to this wide between the shapes and what BiRefNet found, and
           fills what they enclose (0: off; a ring of posts must stay open)
  remove   outlines; what lies inside leaves the matte (ground taken for building)
  window   a larger window for the matte, when the shapes reach past the one it has

Run once after town_plot_mattes.py wrote these buildings' mattes, then package the
layers; it rewrites the matte files and puts their new hashes in the packet.

Needs numpy, scipy, opencv and Pillow.

usage: python tools/town_plot_matte_patches.py art/towns/source/generated/overhaul/faction_thornwake/root_ravine.json [building ids]
"""
import argparse
import hashlib
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
EDGE_SOFT = 1.0    # blur of a shape's edge
SEAL = 9           # seams up to this wide are closed, unless the building says otherwise


def filled(shape, window, points):
    mask = np.zeros(shape, np.uint8)
    cv2.fillPoly(mask, [np.array([(px - window[0], py - window[1]) for px, py in points], np.int32)], 255)
    return mask


def soft(mask):
    return cv2.GaussianBlur(mask.astype(np.float32) / 255.0, (0, 0), EDGE_SOFT)


def mend(matte, item, patch):
    window = item['matte']['window']
    grown = False
    for shape in patch.get('add', []):
        points = shape['outline'] if isinstance(shape, dict) else shape
        mask = filled(matte.shape, window, points)
        weight = soft(mask)
        if isinstance(shape, dict) and shape.get('fade'):
            xs = np.flatnonzero(mask.any(axis=0))
            columns = np.arange(matte.shape[1])
            weight = weight * np.clip(np.minimum(columns - xs.min(), xs.max() - columns) / float(shape['fade']), 0.0, 1.0)[None, :]
        matte = np.maximum(matte, weight)
        grown = True
    for line in patch.get('lines', []):
        mask = np.zeros(matte.shape, np.uint8)
        points = np.array([(px - window[0], py - window[1]) for px, py in line['points']], np.int32)
        cv2.polylines(mask, [points], False, 255, int(line['width']), cv2.LINE_AA)
        matte = np.maximum(matte, soft(mask))
    seal = int(patch.get('seal', SEAL))
    if grown and seal > 0:
        sealed = cv2.morphologyEx((matte > 0.5).astype(np.uint8), cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (seal, seal)))
        sealed = ndimage.binary_fill_holes(sealed).astype(np.float32)
        matte = np.maximum(matte, cv2.GaussianBlur(sealed, (0, 0), EDGE_SOFT) * (sealed > 0))
    for points in patch.get('remove', []):
        matte = np.minimum(matte, 1.0 - soft(filled(matte.shape, window, points)))
    return matte


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    parser.add_argument('packet')
    parser.add_argument('ids', nargs='*', help='only these buildings')
    args = parser.parse_args()
    packet_path = (ROOT / args.packet).resolve()
    patches_path = packet_path.with_name(packet_path.stem + '_matte_patches.json')
    packet = json.loads(packet_path.read_text(encoding='utf-8'))
    patches = json.loads(patches_path.read_text(encoding='utf-8'))['buildings']
    for item in packet['buildings']:
        patch = patches.get(item['id'])
        if not patch or (args.ids and item['id'] not in args.ids):
            continue
        path = ROOT / item['matte']['path']
        with Image.open(path) as image:
            matte = np.asarray(image.convert('L')).astype(np.float32) / 255.0
        if patch.get('window'):
            # A matte that has to reach past what BiRefNet looked at gets a larger window first.
            nx, ny, nw, nh = patch['window']
            ox, oy, ow, oh = item['matte']['window']
            if nx > ox or ny > oy or nx + nw < ox + ow or ny + nh < oy + oh:
                raise ValueError('the new window must hold the old one: ' + item['id'])
            larger = np.zeros((nh, nw), np.float32)
            larger[oy - ny:oy - ny + oh, ox - nx:ox - nx + ow] = matte
            matte, item['matte']['window'] = larger, [nx, ny, nw, nh]
        before = matte.mean()
        matte = mend(matte, item, patch)
        Image.fromarray(np.clip(matte * 255.0 + 0.5, 0, 255).astype(np.uint8), 'L').save(path)
        item['matte']['sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
        item['matte']['tool'] = 'tools/town_plot_matte_patches.py with ' + patches_path.relative_to(ROOT).as_posix()
        print('%s: matte %.1f%% -> %.1f%% of its window' % (item['id'], before * 100, matte.mean() * 100))
    packet_path.write_bytes((json.dumps(packet, indent=2, ensure_ascii=False) + '\n').encode('utf-8'))


if __name__ == '__main__':
    main()
